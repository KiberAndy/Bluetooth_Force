//! Pure page-first decision logic: when to page, and what a socket error means.
//!
//! The field ETW capture (`docs/manual_connect_path.md`) showed the manual
//! path is an outgoing page -- `HCI_Create_Connection` + L2CAP connects --
//! while `BluetoothSetServiceState(ENABLE)` emits zero HCI. So the daemon
//! pages first and escalates only when the page proves the peer unreachable.
//! Everything here is pure and unit-tested; `page.rs` is the Win32 glue.

use crate::config::*;
use crate::sys::ws2_32 as w;

/// What one page attempt proved.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PageOutcome {
    /// Bytes went on the air toward the peer: connected, or the peer answered
    /// and refused the SDP channel (a refusal still proves radio contact).
    /// Either way the stack gets a settle window, not another page.
    Attempted,
    /// The page got no answer (timeout) or the peer is unreachable: paging
    /// harder cannot help, fall through to the ladder.
    Unreachable,
    /// Winsock itself is sick (startup/socket/select failed): fall through,
    /// the rungs may repair what the socket layer cannot name.
    Failed,
}

/// Whether an outgoing page may run on this pass. Own clock, independent of
/// the toggle rate limit: a page emits no device-tree churn, so it needs no
/// echo guard.
pub fn should_page(now_ms: i64, down_since_ms: i64, page_last_ms: i64) -> bool {
    // No down episode (link up, or never armed): nothing to page for.
    if down_since_ms == 0 {
        return false;
    }
    // Fresh outage: the stack may still be settling (or the peer blinking).
    if now_ms - down_since_ms < PAGE_MIN_DOWN_MS {
        return false;
    }
    // Never paged in this episode: go.
    if page_last_ms == 0 {
        return true;
    }
    now_ms - page_last_ms >= PAGE_CADENCE_MS
}

/// Map a Winsock/`SO_ERROR` code to what the page proved.
pub fn classify_socket_error(code: i32) -> PageOutcome {
    match code {
        // Connected, or the L2CAP connect completed with a refusal: the page
        // reached a live peer either way.
        0 | w::WSAECONNREFUSED => PageOutcome::Attempted,
        // No answer, or no route to the peer: paging harder cannot help.
        w::WSAETIMEDOUT | w::WSAEHOSTUNREACH | w::WSAENETUNREACH => PageOutcome::Unreachable,
        _ => PageOutcome::Failed,
    }
}

/// Whether the socket may be held for the episode. A refusal is contact
/// (`Attempted`) but the socket is dead -- holding it would put a corpse in
/// `held_page_socket` and make the "at least one DLC stays open" invariant
/// a lie.
pub fn holds_socket(outcome: PageOutcome, code: i32) -> bool {
    outcome == PageOutcome::Attempted && code == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn no_episode_never_pages() {
        assert!(!should_page(100_000, 0, 0));
    }

    #[test]
    fn fresh_outage_waits_out_settle() {
        let down = 100_000;
        assert!(!should_page(down + PAGE_MIN_DOWN_MS - 1, down, 0));
        assert!(should_page(down + PAGE_MIN_DOWN_MS, down, 0));
    }

    #[test]
    fn cadence_gates_repeat_pages() {
        let down = 100_000;
        let first = down + PAGE_MIN_DOWN_MS;
        assert!(!should_page(first + PAGE_CADENCE_MS - 1, down, first));
        assert!(should_page(first + PAGE_CADENCE_MS, down, first));
    }

    #[test]
    fn refusal_is_still_contact() {
        assert_eq!(classify_socket_error(0), PageOutcome::Attempted);
        assert_eq!(
            classify_socket_error(w::WSAECONNREFUSED),
            PageOutcome::Attempted
        );
    }

    #[test]
    fn refusal_is_contact_but_not_a_hold() {
        assert!(holds_socket(PageOutcome::Attempted, 0));
        assert!(!holds_socket(
            PageOutcome::Attempted,
            w::WSAECONNREFUSED
        ));
        assert!(!holds_socket(PageOutcome::Unreachable, 0));
        assert!(!holds_socket(PageOutcome::Failed, 0));
    }

    #[test]
    fn silence_is_unreachable() {
        assert_eq!(
            classify_socket_error(w::WSAETIMEDOUT),
            PageOutcome::Unreachable
        );
        assert_eq!(
            classify_socket_error(w::WSAEHOSTUNREACH),
            PageOutcome::Unreachable
        );
        assert_eq!(
            classify_socket_error(w::WSAENETUNREACH),
            PageOutcome::Unreachable
        );
    }

    #[test]
    fn unknown_errors_are_failed_not_unreachable() {
        assert_eq!(classify_socket_error(w::WSAENETDOWN), PageOutcome::Failed);
        assert_eq!(classify_socket_error(5), PageOutcome::Failed);
    }
}
