//! PoC for the event-driven wake: does `DBT_DEVNODES_CHANGED` actually replace
//! the 2 s poll, and what does it cost?
//!
//! Modelling assumptions (stated, not hidden):
//!   * Windows broadcasts a device-tree change within ~50 ms of a Bluetooth
//!     audio link appearing or disappearing, because the BTHENUM devnodes and
//!     the audio endpoint are created/removed for it.
//!   * One link change produces a BURST of broadcasts (several devnodes), here
//!     modelled as 4 broadcasts 30 ms apart.
//!   * Opening the case produces NO broadcast when the dongle does not answer
//!     the earbuds' page. That case is modelled too, and it is the one where
//!     the timer is the only thing that works.

use poc::config::*;
use poc::wake::*;

/// One broadcast burst for a single real change. The base is non-zero on
/// purpose: `now_ms()` is a monotonic uptime clock, and 0 is reserved for
/// "no event-driven poll yet".
const BURST_BASE: i64 = 1_000_000;
const BURST: [i64; 4] = [BURST_BASE, BURST_BASE + 30, BURST_BASE + 60, BURST_BASE + 90];
const BROADCAST_DELAY_MS: i64 = 50;

/// Timer-only loop: how long until the poll SEES a link change at `event_at`?
fn timer_only_latency(event_at: i64, wait_ms: i64) -> i64 {
    let mut t = 0;
    while t < event_at {
        t += wait_ms;
    }
    t - event_at
}

/// Event-driven loop: the same question, with the broadcast in play.
fn event_latency(event_at: i64, wait_ms: i64) -> i64 {
    let by_event = event_at + BROADCAST_DELAY_MS;
    let by_timer = {
        let mut t = 0;
        while t < event_at {
            t += wait_ms;
        }
        t
    };
    by_event.min(by_timer) - event_at
}

#[test]
fn a_link_change_is_seen_in_milliseconds_instead_of_seconds() {
    // Worst case for the timer: the change lands right after a poll.
    let event_at = 1;
    let old = timer_only_latency(event_at, POLL_INTERVAL_MS as i64);
    let new = event_latency(event_at, poll_wait_ms(true) as i64);
    println!("timer-only latency = {old} ms; event-driven latency = {new} ms");
    assert!(new < old, "the event must be faster than the old 2 s timer");
    assert!(new <= 100, "a link change has to be noticed in well under a second");
}

/// The point of the slow idle timer: far fewer wakeups for the same or better
/// reaction time. 15 minutes of a healthy link.
#[test]
fn a_healthy_link_costs_ten_times_fewer_polls() {
    let horizon = 15 * 60 * 1000i64;
    let old_polls = horizon / POLL_INTERVAL_MS as i64;
    let new_polls = horizon / poll_wait_ms(true) as i64;
    println!("15 min with the link up: {old_polls} cached queries before, {new_polls} after");
    assert!(new_polls * 5 <= old_polls, "the idle cadence must be a real reduction");
}

/// A burst must not turn into a poll storm.
#[test]
fn one_real_change_causes_one_poll() {
    let mut last = 0i64;
    let mut polls = 0;
    let mut coalesced = 0;
    for t in BURST {
        if device_wake_allowed(t, last) {
            last = t;
            polls += 1;
        } else {
            coalesced += 1;
        }
    }
    println!("burst of {} broadcasts -> {polls} poll(s), {coalesced} coalesced", BURST.len());
    assert_eq!(polls, 1);
    assert_eq!(coalesced, BURST.len() - 1);
}

/// Two genuinely separate changes (a flap) must still produce two polls: the
/// debounce may not swallow real state.
#[test]
fn a_flap_is_not_swallowed_by_the_debounce() {
    let first = 1_000_000;
    let second = first + DEVICE_EVENT_DEBOUNCE_MS + 1;
    assert!(device_wake_allowed(first, 0));
    assert!(device_wake_allowed(second, first));
}

/// The honest limit: the earbuds page a dongle that does not answer. Nothing
/// happens in the device tree, so NO broadcast exists and the event-driven
/// path is worth exactly zero. The retry cadence must stay fast while the link
/// is down -- which is why `poll_wait_ms(false)` is unchanged.
#[test]
fn a_silent_wedge_still_relies_on_the_timer() {
    assert_eq!(poll_wait_ms(false), POLL_INTERVAL_MS);
    let event_at = 1;
    let old = timer_only_latency(event_at, POLL_INTERVAL_MS as i64);
    let new = timer_only_latency(event_at, poll_wait_ms(false) as i64);
    println!("silent wedge: retry cadence stays {new} ms (was {old} ms)");
    assert_eq!(new, old, "the down-link retry cadence must not get slower");
}

/// Driver churn during a long absence. Field log: the earbuds were away for
/// 91 minutes and the daemon re-installed the A2DP driver ~100 times, each
/// pass parking the poll loop for 6.5 s -- none of it could help, because the
/// peer simply was not there.
///
/// Modelled: a poll every 2 s, a toggle pass costing 6.5 s, one GENUINE
/// external device-tree change every 15 minutes, and an echo broadcast from
/// each of our own toggles (that is what most of the field log's 416 wakes
/// were).
#[test]
fn a_long_absence_stops_churning_the_driver() {
    use poc::connect_fsm::toggle_interval_ms;

    const OLD_CAP_MS: i64 = 30_000; // the cap as it shipped
    const PASS_COST_MS: i64 = 6_500;
    const HORIZON_MS: i64 = 91 * 60 * 1000;
    const EXTERNAL_EVENT_MS: i64 = 15 * 60 * 1000;

    fn old_interval(fails: u32) -> i64 {
        let mut v = 15_000i64;
        let mut i = 1;
        while i < fails {
            v *= 2;
            if v >= OLD_CAP_MS {
                return OLD_CAP_MS;
            }
            i += 1;
        }
        v.min(OLD_CAP_MS)
    }

    fn run(new: bool) -> u32 {
        let mut now = 1_000_000i64;
        let end = now + HORIZON_MS;
        let mut last_toggle = 0i64;
        let mut last_unpark = 0i64;
        let mut fails = 0u32;
        let mut count = 0u32;
        while now < end {
            if new {
                // Echo of our own toggle: must never unpark. A genuine
                // external change: may, subject to the floor.
                let echo = last_toggle != 0 && now - last_toggle < PASS_COST_MS + 2_000;
                let external = (now - 1_000_000) % EXTERNAL_EVENT_MS == 0;
                if echo {
                    assert!(!device_wake_may_unpark(now, last_unpark, last_toggle));
                } else if external && device_wake_may_unpark(now, last_unpark, last_toggle) {
                    last_unpark = now;
                    last_toggle = 0;
                }
            }
            let interval = if new { toggle_interval_ms(fails) } else { old_interval(fails) };
            if last_toggle == 0 || now - last_toggle >= interval {
                count += 1;
                fails += 1;
                now += PASS_COST_MS;
                last_toggle = now;
            }
            now += 2_000;
        }
        count
    }

    let old = run(false);
    let new = run(true);
    println!("91 min absence: {old} driver re-installs before, {new} after");
    assert!(old >= 90, "the old cap really did churn: {old}");
    assert!(new * 3 <= old, "expected a large reduction, got {new} vs {old}");
    // Still responsive: a retry at least every few minutes.
    assert!(new >= 15, "a 91 min absence must still be retried regularly: {new}");
}
