//! PoC for the 2026-09-29 field defect: the escalation ladder cancelled its
//! own toggle rate limit.
//!
//! What the log shows (191 KB, 15 h, 31 unparks):
//!   * 24 of 31 `device-change wake ... retrying the reconnect now` lines land
//!     within 30 s of one of OUR completions.
//!   * 17 of them share the MILLISECOND with `rung earbud-restart: complete`,
//!     e.g. `20:29:12.134 complete (2/2 node(s) restarted)` followed by
//!     `20:29:12.134 device-change wake` and then
//!     `20:29:20.698 that pass BLOCKED the poll loop for ~8.5 s`.
//!   * 2 more follow `R1: radio reset complete` by 2.2 s and 4.2 s.
//!
//! Cause: the echo guard was anchored on `connect_toggle_last_ms` only. R1/R2/
//! R3/recovery rewrite the device tree too, and worse, an unpark ZEROES that
//! field -- so the guard was disarmed precisely while the ladder churned.
//!
//! This test models the field cadence and compares the old anchor (connect
//! toggle, zeroed on unpark) with the new one (any self-inflicted churn).

use poc::config::{DEVICE_WAKE_UNPARK_MS, SELF_CHURN_ECHO_MS};
use poc::wake::{device_wake_may_unpark, is_self_echo};

const HORIZON_MS: i64 = 4 * 60 * 60 * 1000; // one of the long down episodes
const R3_PERIOD_MS: i64 = 90_000; // rung earbud-restart cadence in the log
const TOGGLE_COST_MS: i64 = 8_500; // what an unparked pass cost in the log
const START: i64 = 1_000_000;

/// Returns (unparks, seconds the poll loop was parked by unparked toggles).
fn run(new_anchor: bool) -> (u32, i64) {
    let mut unparks = 0u32;
    let mut parked_ms = 0i64;
    let mut last_unpark = 0i64;
    // The old code shared one field for "when did the connect toggle run" and
    // "was that us" -- and cleared it on every unpark.
    let mut toggle_anchor = 0i64;

    let mut now = START;
    while now < START + HORIZON_MS {
        // A rung finishes and Windows broadcasts the resulting tree change in
        // the same millisecond. The new anchor is stamped by the rung itself;
        // the old one only ever knew about the connect toggle.
        let rung_done = now;
        let anchor = if new_anchor { rung_done } else { toggle_anchor };
        if !is_self_echo(rung_done, anchor)
            && device_wake_may_unpark(rung_done, last_unpark, anchor)
        {
            unparks += 1;
            last_unpark = rung_done;
            parked_ms += TOGGLE_COST_MS;
            // The unpark runs a connect toggle immediately...
            // The old code cleared its only anchor on unpark, disarming the
            // guard for whatever came next.
            toggle_anchor = if new_anchor { rung_done + TOGGLE_COST_MS } else { 0 };
        }
        now = rung_done + R3_PERIOD_MS;
    }
    (unparks, parked_ms / 1000)
}

#[test]
fn a_rung_completion_no_longer_cancels_the_rate_limit() {
    let (old_unparks, old_parked) = run(false);
    let (new_unparks, new_parked) = run(true);
    println!(
        "4 h down episode, a rung completing every {} s: {old_unparks} unparks / {old_parked} s parked before, {new_unparks} / {new_parked} s after",
        R3_PERIOD_MS / 1000
    );
    // The old anchor was useless here: the rung is not the connect toggle, and
    // the floor was the only thing left, so it unparked once per minute.
    assert!(old_unparks >= 100, "the old anchor really did let them through: {old_unparks}");
    assert_eq!(new_unparks, 0, "our own churn must never unpark the toggle");
    assert!(old_parked > 0 && new_parked == 0);
}

/// The guard must not swallow a GENUINE change: the earbuds coming back is
/// exactly the event that has to skip the rate limit.
#[test]
fn a_genuine_change_still_unparks() {
    let rung_done = START;
    let genuine = rung_done + SELF_CHURN_ECHO_MS;
    assert!(is_self_echo(rung_done + 1, rung_done));
    assert!(!is_self_echo(genuine, rung_done));
    assert!(
        device_wake_may_unpark(genuine, 0, rung_done),
        "a change outside the echo window must still cancel the limit"
    );
}

/// The echo window has to cover the observed spread (0 ms .. 4.2 s) with room
/// for a slow PnP settle, but must stay well under the unpark floor so a real
/// reconnect is never delayed by a whole minute.
#[test]
fn the_echo_window_matches_the_measured_spread() {
    assert!(SELF_CHURN_ECHO_MS >= 5_000, "observed echoes reached 4.2 s");
    assert!(SELF_CHURN_ECHO_MS < DEVICE_WAKE_UNPARK_MS);
}
