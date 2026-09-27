//! Log redaction: strips device-identifying data out of every line before it is
//! written, so a log can be shared as-is.
//!
//! What is masked:
//!   * Bluetooth addresses, in every spelling that appears in the log
//!     (`94:8B:93:B1:E4:A1`, and the bare `948b93b1e4a1` inside PnP instance
//!     IDs) -> one stable `mac#xxxx` tag per address.
//!   * Device and audio-endpoint names -> `name#xxxx`.
//!   * Absolute paths -> the file name only.
//!
//! What is deliberately kept, because it is what makes a log diagnosable and
//! carries nothing personal: timestamps, return codes, profile GUIDs, rung
//! names, VID/PID and devnode status.
//!
//! Tags are a non-reversible 16-bit FNV-1a digest: the same device keeps the
//! same tag inside one log (so lines can still be correlated) while the address
//! itself cannot be read back out.

/// FNV-1a, folded to 16 bits and rendered as 4 hex digits.
fn tag(bytes: &[u8]) -> String {
    let mut h: u32 = 0x811c_9dc5;
    for &b in bytes {
        h ^= b.to_ascii_lowercase() as u32;
        h = h.wrapping_mul(0x0100_0193);
    }
    format!("{:04x}", ((h >> 16) ^ h) & 0xffff)
}

/// One tag per address, whatever the spelling: separators are dropped and the
/// hex is lowercased before hashing.
fn mac_tag(raw: &str) -> String {
    let hex: Vec<u8> = raw
        .bytes()
        .filter(|b| b.is_ascii_hexdigit())
        .map(|b| b.to_ascii_lowercase())
        .collect();
    format!("mac#{}", tag(&hex))
}

fn name_tag(raw: &str) -> String {
    // Trim the decoration Windows puts around endpoint names so the same
    // endpoint hashes to the same tag wherever it is printed.
    let core = raw.trim().trim_end_matches(')').trim();
    format!("name#{}", tag(core.as_bytes()))
}

fn is_hex(b: u8) -> bool {
    b.is_ascii_hexdigit()
}

/// `AA:BB:CC:DD:EE:FF` at `i`?
fn dotted_mac_at(b: &[u8], i: usize) -> bool {
    if i + 17 > b.len() {
        return false;
    }
    for group in 0..6 {
        let p = i + group * 3;
        if !is_hex(b[p]) || !is_hex(b[p + 1]) {
            return false;
        }
        if group < 5 && b[p + 2] != b':' {
            return false;
        }
    }
    // Do not bite into a longer run of hex/colons.
    if i > 0 && (is_hex(b[i - 1]) || b[i - 1] == b':') {
        return false;
    }
    !matches!(b.get(i + 17), Some(&c) if is_hex(c) || c == b':')
}

/// Mask every Bluetooth address: the dotted form, and any bare run of 12 or
/// more hex digits. A run that follows a `-` is a GUID group (for example the
/// `00805f9b34fb` tail of a profile GUID) and is left alone.
fn redact_addresses(line: &str) -> String {
    let b = line.as_bytes();
    let mut out = String::with_capacity(line.len());
    let mut i = 0;
    while i < b.len() {
        if dotted_mac_at(b, i) {
            out.push_str(&mac_tag(&line[i..i + 17]));
            i += 17;
            continue;
        }
        if is_hex(b[i]) && (i == 0 || !is_hex(b[i - 1])) {
            let start = i;
            let mut end = i;
            while end < b.len() && is_hex(b[end]) {
                end += 1;
            }
            let long_enough = end - start >= 12;
            let guid_group = start > 0 && b[start - 1] == b'-';
            if long_enough && !guid_group {
                out.push_str(&mac_tag(&line[start..end]));
                i = end;
                continue;
            }
            out.push_str(&line[start..end]);
            i = end;
            continue;
        }
        out.push(b[i] as char);
        i += 1;
    }
    out
}

/// `G:\dir\bluetooth_force.exe` -> `bluetooth_force.exe`.
fn file_name_of(path: &str) -> &str {
    path.rsplit(['\\', '/']).next().unwrap_or(path)
}

/// Byte offset of a `X:\` / `X:/` drive letter inside `token`, if any.
fn drive_prefix_at(token: &str) -> Option<usize> {
    let b = token.as_bytes();
    for i in 1..b.len().saturating_sub(1) {
        if b[i] == b':'
            && matches!(b[i + 1], b'\\' | b'/')
            && b[i - 1].is_ascii_alphabetic()
            && (i == 1 || !b[i - 2].is_ascii_alphanumeric())
        {
            return Some(i - 1);
        }
    }
    None
}

/// Replace whitespace-separated tokens that look like absolute paths with their
/// file name.
fn redact_paths(line: &str) -> String {
    let mut out = String::with_capacity(line.len());
    let mut token = String::new();
    // A path can sit behind a key, as in `exe=G:\dir\file.exe`: keep the key,
    // shrink the path.
    let flush = |out: &mut String, token: &mut String| {
        match drive_prefix_at(token) {
            Some(drive) => {
                out.push_str(&token[..drive]);
                out.push_str(file_name_of(&token[drive..]));
            }
            None => out.push_str(token),
        }
        token.clear();
    };
    for ch in line.chars() {
        if ch.is_whitespace() {
            flush(&mut out, &mut token);
            out.push(ch);
        } else {
            token.push(ch);
        }
    }
    flush(&mut out, &mut token);
    out
}

/// Mask the value that follows `marker` up to `end` (or end of line).
fn mask_after(line: &str, marker: &str, end: Option<char>) -> Option<String> {
    let at = line.find(marker)?;
    let value_start = at + marker.len();
    let rest = &line[value_start..];
    let value_len = match end {
        Some(c) => rest.find(c)?,
        None => rest.len(),
    };
    let value = &rest[..value_len];
    if value.trim().is_empty() {
        return None;
    }
    Some(format!(
        "{}{}{}",
        &line[..value_start],
        name_tag(value),
        &rest[value_len..]
    ))
}

/// Mask the free-form device names this tool prints.
fn redact_names(line: &str) -> String {
    // `waveOut[2] = Наушники (...)` — the whole tail is the endpoint name.
    if line.contains("waveOut[") {
        if let Some(masked) = mask_after(line, "] = ", None) {
            return masked;
        }
    }
    // `keepalive -> endpoint #2 (Наушники ...)` -- the name runs to the LAST
    // closing paren, so the masked name matches the `waveOut[i]` line and both
    // get the same tag.
    if line.contains("endpoint #") {
        if let (Some(open), Some(close)) = (line.find(" ("), line.rfind(')')) {
            let value_start = open + 2;
            if close > value_start {
                return format!(
                    "{}{}{}",
                    &line[..value_start],
                    name_tag(&line[value_start..close]),
                    &line[close..]
                );
            }
        }
    }
    // Quoted names, as printed by the health probe: `name="WF-1000XM5"`.
    if let Some(open) = line.find("name=\"") {
        let value_start = open + 6;
        if let Some(rel_end) = line[value_start..].find('"') {
            let value = &line[value_start..value_start + rel_end];
            return format!(
                "{}{}{}",
                &line[..value_start],
                name_tag(value),
                &line[value_start + rel_end..]
            );
        }
    }
    line.to_string()
}

/// Full redaction pass for one log line.
pub fn redact_line(line: &str) -> String {
    redact_addresses(&redact_paths(&redact_names(line)))
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Real lines from a field log.
    const MAC_DOTTED: &str = "94:8B:93:B1:E4:A1";
    const MAC_HEX12: &str = "948b93b1e4a1";

    #[test]
    fn the_address_never_survives_in_any_spelling() {
        let lines = [
            "start: build=rust3.0 mac=94:8B:93:B1:E4:A1 exe=G:\\Projects\\Bluetooth_Force\\target\\release\\bluetooth_force.exe admin=true log=btf.log",
            "rung earbud-restart: begin (mac=948b93b1e4a1)",
            "rung earbud-restart: skip (non-audio, left untouched) bthenum\\dev_948b93b1e4a1\\7&1d4ec691&0&bluetoothdevice_948b93b1e4a1",
            "rung earbud-restart: node bthenum\\{0000110b-0000-1000-8000-00805f9b34fb}_vid&000102b0_pid&0000\\7&1d4ec691&0&948B93B1E4A1_c00000000",
            "radio[0]: addr=94:8B:93:B1:E4:A1 name=\"CSR dongle\" manufacturer=15",
        ];
        for line in lines {
            let red = redact_line(line);
            let lower = red.to_ascii_lowercase();
            assert!(!lower.contains(MAC_HEX12), "hex12 leaked: {red}");
            assert!(!lower.contains(&MAC_DOTTED.to_ascii_lowercase()), "dotted leaked: {red}");
        }
    }

    #[test]
    fn one_device_keeps_one_tag_across_spellings() {
        let a = redact_line("mac=94:8B:93:B1:E4:A1");
        let b = redact_line("begin (mac=948b93b1e4a1)");
        let c = redact_line("node bthenum\\x\\7&1d4ec691&0&948B93B1E4A1_c00000000");
        let t = &a[a.find("mac#").unwrap()..];
        assert!(b.contains(t) && c.contains(t), "{a} / {b} / {c}");
    }

    #[test]
    fn diagnosable_detail_is_kept() {
        let line = redact_line(
            "rung earbud-restart: node bthenum\\{0000110b-0000-1000-8000-00805f9b34fb}_vid&000102b0_pid&0000\\7&1d4ec691&0&948b93b1e4a1_c00000000",
        );
        assert!(line.contains("{0000110b-0000-1000-8000-00805f9b34fb}"), "GUID mangled: {line}");
        assert!(line.contains("vid&000102b0"), "VID mangled: {line}");
        assert!(line.contains("7&1d4ec691"), "short hex mangled: {line}");
        assert!(line.contains("rung earbud-restart"));

        let rc = redact_line("connect: A2DP enable failed rc=0x57 (last error 0x80070057)");
        assert_eq!(rc, "connect: A2DP enable failed rc=0x57 (last error 0x80070057)");
    }

    #[test]
    fn paths_shrink_to_the_file_name() {
        let line = redact_line("start: exe=G:\\Projects\\Bluetooth_Force\\target\\release\\bluetooth_force.exe admin=true");
        assert!(line.contains("exe=bluetooth_force.exe"), "{line}");
        assert!(!line.contains("G:\\"), "{line}");
        assert!(line.contains("admin=true"));
    }

    #[test]
    fn endpoint_and_device_names_are_masked() {
        let w = redact_line("waveOut[2] = Наушники (Redmi Buds 6 Lite Ste");
        assert!(w.starts_with("waveOut[2] = name#"), "{w}");
        assert!(!w.contains("Redmi"), "{w}");

        let k = redact_line("keepalive -> endpoint #2 (Наушники (Redmi Buds 6 Lite Ste)");
        assert!(k.starts_with("keepalive -> endpoint #2 (name#"), "{k}");
        assert!(!k.contains("Redmi"), "{k}");

        let q = redact_line("radio[0]: name=\"Redmi Buds 6 Lite\" manufacturer=15");
        assert!(!q.contains("Redmi"), "{q}");
        assert!(q.contains("manufacturer=15"), "{q}");
    }

    /// The same endpoint must carry the same tag in both lines that print it.
    #[test]
    fn one_endpoint_keeps_one_tag() {
        let w = redact_line("waveOut[2] = Наушники (Redmi Buds 6 Lite Ste");
        let k = redact_line("keepalive -> endpoint #2 (Наушники (Redmi Buds 6 Lite Ste)");
        let tag_w = &w[w.find("name#").unwrap()..];
        assert!(k.contains(tag_w.trim_end_matches(')')), "{w} / {k}");
        assert!(k.ends_with(')'), "the closing paren must survive: {k}");
    }

    #[test]
    fn plain_lines_are_untouched() {
        for line in [
            "connect: forcing a reconnect on A2DP (disable -> enable)",
            "R1: incoming connections were already OFF (0x80070057) -- the radio is not connectable; re-enabling",
            "flap 1/3: lone connected poll inside an armed episode -- episode stays armed",
        ] {
            assert_eq!(redact_line(line), line, "line was altered: {line}");
        }
    }
}
