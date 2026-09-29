//! Dependency-free ASCII text helpers shared by the pure modules.

pub fn ascii_lower(c: u8) -> u8 {
    if c.is_ascii_uppercase() { c + 32 } else { c }
}

/// Case-insensitive ASCII substring test (allocation-free). Non-ASCII bytes are
/// compared verbatim; empty needles never match.
pub fn contains_ignore_case(haystack: &[u8], needle: &[u8]) -> bool {
    if needle.is_empty() || needle.len() > haystack.len() {
        return false;
    }
    haystack
        .windows(needle.len())
        .any(|w| w.iter().zip(needle).all(|(a, b)| ascii_lower(*a) == ascii_lower(*b)))
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
}
