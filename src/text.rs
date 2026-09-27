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
