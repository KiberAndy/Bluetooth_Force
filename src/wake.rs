//! Wake policy for the poll loop — pure logic, no Win32, fully testable.
//!
//! The daemon used to learn about a link change ONLY by polling the cached
//! paired-device list every 2 s. `WM_DEVICECHANGE`/`DBT_DEVNODES_CHANGED` is
//! broadcast to every top-level window whenever the device tree changes, and a
//! Bluetooth audio link coming up or going down creates/removes BTHENUM
//! devnodes — so that broadcast is the event we were missing.
//!
//! Two honest limits, encoded here rather than hidden:
//!   * `DBT_DEVNODES_CHANGED` carries NO detail. It means "go look", never
//!     "the earbuds are back", so it can only ever trigger a poll.
//!   * Opening the case is not an event Windows can see. If the earbuds page a
//!     deaf dongle, nothing is broadcast at all. The timer therefore stays as
//!     the safety net; the event only makes the reaction immediate.

use crate::config::{DEVICE_EVENT_DEBOUNCE_MS, POLL_INTERVAL_IDLE_MS, POLL_INTERVAL_MS};

/// How long to sleep before the next unconditional poll.
///
/// While the link is UP there is nothing to drive, so the timer can be slow:
/// a link drop shows up as a device-tree change within milliseconds. While the
/// link is DOWN the timer IS the retry cadence, because a peer that cannot
/// reach the radio produces no broadcast at all.
pub fn poll_wait_ms(link_up: bool) -> u32 {
    if link_up {
        POLL_INTERVAL_IDLE_MS
    } else {
        POLL_INTERVAL_MS
    }
}

/// May a device-tree change trigger a poll now?
///
/// One user action (a link coming up) makes Windows rebuild several devnodes,
/// so the broadcast arrives in bursts. The auto-reset event already collapses
/// a burst that lands while the loop is awake; this debounce collapses the
/// rest. `last_ms == 0` means "no event-driven poll yet".
pub fn device_wake_allowed(now_ms: i64, last_ms: i64) -> bool {
    if last_ms == 0 || now_ms < last_ms {
        return true; // first event, or the clock went backwards
    }
    now_ms - last_ms >= DEVICE_EVENT_DEBOUNCE_MS
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_timer_is_slow_only_while_the_link_is_up() {
        assert_eq!(poll_wait_ms(false), POLL_INTERVAL_MS);
        assert_eq!(poll_wait_ms(true), POLL_INTERVAL_IDLE_MS);
        assert!(POLL_INTERVAL_IDLE_MS > POLL_INTERVAL_MS);
    }

    #[test]
    fn a_burst_of_device_changes_collapses_into_one_poll() {
        let t = 1_000_000;
        assert!(device_wake_allowed(t, 0), "the first event always polls");
        assert!(!device_wake_allowed(t + 1, t));
        assert!(!device_wake_allowed(t + DEVICE_EVENT_DEBOUNCE_MS - 1, t));
        assert!(device_wake_allowed(t + DEVICE_EVENT_DEBOUNCE_MS, t));
        assert!(device_wake_allowed(t - 5, t), "a backwards clock must not park the loop");
    }
}
