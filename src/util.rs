//! Small, dependency-free helpers shared across the crate: string decoding,
//! case-insensitive matching, command-line quoting and Win32 path building.

use std::path::PathBuf;

use crate::sys::kernel32;

/// Monotonic millisecond clock. Used for almost every timing gate in the
/// daemon; `GetTickCount64` never returns 0 for a user-started process, which
/// is why `0` is a safe "not set" sentinel throughout the ladder.
pub fn now_ms() -> i64 {
    unsafe { kernel32::GetTickCount64() as i64 }
}

/// UTF-16, NUL-terminated heap buffer for a `*const u16` Win32 argument.
pub fn wide(s: &str) -> Vec<u16> {
    let mut v: Vec<u16> = s.encode_utf16().collect();
    v.push(0);
    v
}

/// Decode a fixed UTF-16 field (NUL-trimmed). Empty fields decode to an empty
/// string and invalid surrogates are replaced, so a probe never fails on
/// encoding trouble.
pub fn utf16_field(buf: &[u16]) -> String {
    let end = buf.iter().position(|&c| c == 0).unwrap_or(buf.len());
    if end == 0 { String::new() } else { String::from_utf16_lossy(&buf[..end]) }
}

pub fn ascii_lower(c: u8) -> u8 {
    if c.is_ascii_uppercase() { c + 32 } else { c }
}

/// Case-insensitive ASCII substring test (allocation-free). Non-ASCII bytes are
/// compared verbatim; empty needles never match.
pub fn contains_ignore_case(haystack: &[u8], needle: &[u8]) -> bool {
    if needle.is_empty() || needle.len() > haystack.len() {
        return false;
    }
    haystack.windows(needle.len()).any(|w| {
        w.iter().zip(needle).all(|(a, b)| ascii_lower(*a) == ascii_lower(*b))
    })
}

/// Quote one argument for a Windows command line using the
/// `CommandLineToArgvW` / MSVCRT rules. Device names are attacker-controlled,
/// so an embedded quote must not be able to break out and inject arguments.
pub fn quote_arg(arg: &str) -> String {
    let bytes = arg.as_bytes();
    let mut out = String::with_capacity(arg.len() + 2);
    out.push('"');
    let mut i = 0;
    while i < bytes.len() {
        let mut backslashes = 0;
        while i < bytes.len() && bytes[i] == b'\\' {
            backslashes += 1;
            i += 1;
        }
        if i == bytes.len() {
            // Trailing backslashes precede the closing quote: double them.
            for _ in 0..backslashes * 2 {
                out.push('\\');
            }
        } else if bytes[i] == b'"' {
            // Backslashes before a quote are doubled, then the quote escaped.
            for _ in 0..backslashes * 2 + 1 {
                out.push('\\');
            }
            out.push('"');
            i += 1;
        } else {
            for _ in 0..backslashes {
                out.push('\\');
            }
            out.push(bytes[i] as char);
            i += 1;
        }
    }
    out.push('"');
    out
}

/// Full path to the running executable, or `None` when it cannot be read.
pub fn module_file_name() -> Option<String> {
    let mut buf = vec![0u16; 4096];
    let n = unsafe { kernel32::GetModuleFileNameW(std::ptr::null_mut(), buf.as_mut_ptr(), buf.len() as u32) };
    // On truncation GetModuleFileNameW returns nSize and may not NUL-terminate:
    // treat a full buffer as failure rather than resolving a truncated path.
    if n == 0 || n as usize >= buf.len() {
        return None;
    }
    buf.truncate(n as usize);
    Some(String::from_utf16_lossy(&buf))
}

/// Directory that contains the running executable.
pub fn self_dir() -> Option<PathBuf> {
    let exe = module_file_name()?;
    let dir = exe.rsplit_once('\\').map(|(d, _)| d)?.to_string();
    Some(PathBuf::from(dir))
}

/// `<exe dir>\<name>` — used for the log, the recovery journal and the freeze
/// switch, all of which must sit next to the binary.
pub fn self_dir_path(name: &str) -> Option<PathBuf> {
    Some(self_dir()?.join(name))
}

/// Absolute `<System32>\<name>`. `pnputil` must never be resolved through PATH:
/// this process can run elevated, so a writable-directory hijack would be a
/// privilege escalation.
pub fn system_path_of(name: &str) -> Option<String> {
    let mut buf = vec![0u16; 520];
    let n = unsafe { kernel32::GetSystemDirectoryW(buf.as_mut_ptr(), 512) };
    if n == 0 || n >= 512 {
        return None;
    }
    buf.truncate(n as usize);
    let sys = String::from_utf16_lossy(&buf);
    if sys.is_empty() {
        return None;
    }
    Some(format!("{sys}\\{name}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn contains_ignore_case_basics() {
        assert!(contains_ignore_case(b"Speakers (FxSound Audio)", b"fxsound"));
        assert!(contains_ignore_case(b"WF-1000XM5 Stereo", b"xm5"));
        assert!(!contains_ignore_case(b"Realtek", b"fxsound"));
        assert!(!contains_ignore_case(b"abc", b"abcd"));
        assert!(!contains_ignore_case(b"abc", b""));
    }

    #[test]
    fn quote_arg_wraps_and_escapes() {
        assert_eq!(quote_arg("MyBuds"), "\"MyBuds\"");
        let hostile = quote_arg("evil\" --danger");
        assert!(hostile.starts_with('"') && hostile.ends_with('"'));
        let inner = &hostile.as_bytes()[1..hostile.len() - 1];
        for (i, &b) in inner.iter().enumerate() {
            if b == b'"' {
                assert_eq!(inner[i - 1], b'\\');
            }
        }
    }
}
