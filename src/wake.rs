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

use crate::config::{
    DEVICE_EVENT_DEBOUNCE_MS, DEVICE_WAKE_UNPARK_MS, POLL_INTERVAL_IDLE_MS, POLL_INTERVAL_MS,
    SELF_CHURN_ECHO_MS,
};

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

/// Is this device-tree change the echo of our own last action?
///
/// Exposed so the caller can COUNT the rejection with the same rule that makes
/// it, instead of re-implementing the window and drifting from it.
pub fn is_self_echo(now_ms: i64, last_self_churn_ms: i64) -> bool {
    last_self_churn_ms != 0
        && now_ms >= last_self_churn_ms
        && now_ms - last_self_churn_ms < SELF_CHURN_ECHO_MS
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
    fn a_device_change_can_unpark_the_toggle_but_not_on_every_event() {
        let t = 1_000_000;
        assert!(device_wake_may_unpark(t, 0, 0), "the first one always counts");
        assert!(!device_wake_may_unpark(t + 1, t, 0));
        assert!(!device_wake_may_unpark(t + DEVICE_WAKE_UNPARK_MS - 1, t, 0));
        assert!(device_wake_may_unpark(t + DEVICE_WAKE_UNPARK_MS, t, 0));
    }

    /// The feedback loop that would undo the rate limit: our own action
    /// rewrites the device tree, Windows broadcasts it, and the broadcast
    /// cancels the limit that the action was waiting on.
    #[test]
    fn our_own_echo_never_unparks_the_toggle() {
        let churned_at = 2_000_000;
        assert!(!device_wake_may_unpark(churned_at + 10, 0, churned_at));
        assert!(!device_wake_may_unpark(churned_at + SELF_CHURN_ECHO_MS - 1, 0, churned_at));
        assert!(device_wake_may_unpark(churned_at + SELF_CHURN_ECHO_MS, 0, churned_at));
    }

    /// The 2026-09-29 field log: `rung earbud-restart: complete` and the wake
    /// share a millisecond, 17 times. The rung is not the connect toggle, so
    /// the old guard (which only knew about the toggle) let it through.
    #[test]
    fn a_rung_completion_is_our_echo_too() {
        let rung_done = 5_000_000;
        // Unpark floor already satisfied -- only the echo guard can stop this.
        let last_unpark = rung_done - DEVICE_WAKE_UNPARK_MS * 2;
        assert!(!device_wake_may_unpark(rung_done, last_unpark, rung_done));
        assert!(!device_wake_may_unpark(rung_done + 2_200, last_unpark, rung_done));
        assert!(device_wake_may_unpark(rung_done + SELF_CHURN_ECHO_MS, last_unpark, rung_done));
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

/// May a device-tree change cancel the toggle rate limit right now?
///
/// The limit exists because a toggle removes a driver and parks the poll loop
/// for seconds. But when the device tree changes, the peer may genuinely be
/// back, and making it wait out a five-minute limit would be absurd.
///
/// Two guards. `last_self_churn_ms` rejects our OWN echo: every rung rewrites
/// the device tree (profile driver re-install, page-scan toggle, USB cycle,
/// earbud devnode restart), Windows broadcasts that, and acting on it is a
/// feedback loop that re-creates the churn the limit exists to prevent. It is
/// deliberately NOT the same field as the toggle rate-limit clock, which gets
/// zeroed on unpark -- sharing them left the echo guard disarmed exactly when
/// the ladder was churning hardest. `last_unpark_ms` is the floor for
/// everything else.
pub fn device_wake_may_unpark(now_ms: i64, last_unpark_ms: i64, last_self_churn_ms: i64) -> bool {
    if is_self_echo(now_ms, last_self_churn_ms) {
        return false;
    }
    if last_unpark_ms == 0 || now_ms < last_unpark_ms {
        return true;
    }
    now_ms - last_unpark_ms >= DEVICE_WAKE_UNPARK_MS
}
