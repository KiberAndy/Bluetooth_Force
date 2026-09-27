//! End-to-end PoC: "earbuds do not reconnect after the case is opened".
//!
//! A fake Bluetooth stack implements the documented BluetoothSetServiceState
//! contract (Microsoft Learn, bluetoothapis.h):
//!   ERROR_SUCCESS                -> state changed (driver installed/removed)
//!   E_INVALIDARG                 -> ENABLE asked for an ALREADY ENABLED service
//!   ERROR_SERVICE_DOES_NOT_EXIST -> peer does not offer the profile
//! and the Remarks: "Enabling a service installs the corresponding device
//! driver and disabling a service removes the corresponding device driver."
//!
//! Modelling assumption (stated, not hidden): a fresh driver install makes the
//! stack page the peer, so it brings the link up iff the earbuds are reachable.
//! That is the same assumption the original code already relied on -- its whole
//! connect path was a single ENABLE call.

use poc::config::*;
use poc::connect_fsm::*;

const POLL_MS: i64 = POLL_INTERVAL_MS as i64;
const CASE_OPEN_MS: i64 = 60_000;
const HORIZON_MS: i64 = 15 * 60 * 1000;

/// The refusal code the field log actually shows: `0x57`
/// (`HRESULT_CODE(E_INVALIDARG)`).
const FIELD_RC_ALREADY: u32 = 0x57;

struct FakeStack {
    /// The export cannot change the service state at all (worst case that is
    /// still consistent with the field log: every call answers 0x57).
    inert: bool,
    in_case: bool,
    enabled: [bool; 3],
    supported: [bool; 3],
    link_up: bool,
    installs: u32,
    removals: u32,
    enable_calls: u32,
}

impl FakeStack {
    /// Steady state of a paired device after one successful connect: every
    /// audio service is enabled and the link is currently down.
    fn new() -> Self {
        Self {
            inert: false,
            in_case: true,
            enabled: [true, true, true],
            supported: [true, true, true],
            link_up: false,
            installs: 0,
            removals: 0,
            enable_calls: 0,
        }
    }
    fn idx(p: Profile) -> usize {
        Profile::ORDER.iter().position(|&q| q == p).unwrap()
    }
    fn raw_set(&mut self, p: Profile, enable: bool) -> u32 {
        let i = Self::idx(p);
        if enable {
            self.enable_calls += 1;
        }
        if !self.supported[i] {
            return ERROR_SERVICE_DOES_NOT_EXIST;
        }
        if self.inert || enable == self.enabled[i] {
            return FIELD_RC_ALREADY;
        }
        self.enabled[i] = enable;
        if enable {
            self.installs += 1;
            if !self.in_case {
                self.link_up = true;
            }
        } else {
            self.removals += 1;
            self.link_up = false;
        }
        RC_SUCCESS
    }
}

impl ServiceStateIo for FakeStack {
    fn set_state(&mut self, p: Profile, enable: bool) -> u32 {
        self.raw_set(p, enable)
    }
    fn wait(&mut self, _ms: u32) {}
    fn log(&mut self, _m: &str) {}
    fn debt_arm(&mut self, _p: Profile) -> bool {
        true
    }
    fn debt_clear(&mut self) {}
}

/// Exponential backoff with a cap: the shipped `ladder::backoff_ms`, inlined so
/// this harness does not need the Win32-bound ladder module.
fn backoff_ms(fails: u32, base: i64, cap: i64) -> i64 {
    if fails == 0 {
        return 0;
    }
    let mut v = base;
    let mut i = 1;
    while i < fails {
        v *= 2;
        if v >= cap {
            return cap;
        }
        i += 1;
    }
    v.min(cap)
}

/// The ORIGINAL connect path, transcribed verbatim from the shipped
/// `src/connect.rs` before the fix: enable A2DP, then HFP, then AVRCP; return
/// on the first ERROR_SUCCESS; "not offered" everywhere means absent; anything
/// else is a failure.
fn legacy_connect(stack: &mut FakeStack) -> ConnectOutcome {
    let mut any_not_found = false;
    let mut any_other_error = false;
    for p in Profile::ORDER {
        match stack.raw_set(p, true) {
            RC_SUCCESS => return ConnectOutcome::Connected,
            ERROR_SERVICE_DOES_NOT_EXIST => any_not_found = true,
            _ => any_other_error = true,
        }
    }
    if any_other_error || !any_not_found {
        ConnectOutcome::Failed
    } else {
        ConnectOutcome::NotFound
    }
}

/// Model of the R3 rung as the field log shows it: `pnputil /restart-device` on
/// the 110b/110c profile devnodes, verified STARTED, which re-installs the
/// profile drivers and pages the peer.
fn r3_restart_audio_devnodes(stack: &mut FakeStack) {
    stack.removals += 1;
    stack.installs += 1;
    if !stack.in_case {
        stack.link_up = true;
    }
}

struct Run {
    connected_at: Option<i64>,
    installs_while_in_case: u32,
    stack_installs: u32,
    stack_removals: u32,
    enable_calls: u32,
}

/// One worker-style poll loop. `fixed = false` runs the original code path.
fn simulate(fixed: bool) -> Run {
    simulate_stack(fixed, FakeStack::new())
}

fn simulate_stack(fixed: bool, start: FakeStack) -> Run {
    let mut stack = start;
    let mut r3_force_at: Option<i64> = None;
    let mut next_connect_ms: i64 = 0;
    let mut fails: u32 = 0;
    let mut toggle_last_ms: i64 = 0;
    let mut toggle_fails: u32 = 0;
    let mut connected_at = None;
    let mut installs_while_in_case = 0;

    let mut now = 0i64;
    while now <= HORIZON_MS {
        if now >= CASE_OPEN_MS && stack.in_case {
            stack.in_case = false;
            installs_while_in_case = stack.installs;
        }

        if stack.link_up {
            // The poll sees fConnected == 1.
            if connected_at.is_none() {
                connected_at = Some(now);
            }
            break;
        }

        // The ladder's R3 rung, queued by an Inert verdict, runs before connect.
        if let Some(at) = r3_force_at {
            if now >= at {
                r3_force_at = None;
                r3_restart_audio_devnodes(&mut stack);
                now += POLL_MS;
                continue;
            }
        }

        if now >= next_connect_ms {
            if fixed {
                let allow_toggle = should_toggle(now, toggle_last_ms, toggle_fails);
                let res = drive_connect(&mut stack, allow_toggle);
                if res.toggled {
                    toggle_last_ms = now;
                    toggle_fails += 1;
                }
                match res.outcome {
                    ConnectOutcome::Connected => {
                        fails = 0;
                        next_connect_ms = 0;
                    }
                    ConnectOutcome::Reconnecting => {
                        fails = 0;
                        next_connect_ms = now + CONNECT_TOGGLE_SETTLE_MS;
                    }
                    ConnectOutcome::Refused | ConnectOutcome::ServiceDebt => {
                        next_connect_ms = now + CONNECT_REFUSED_RETRY_MS;
                    }
                    ConnectOutcome::Inert => {
                        if allow_toggle && r3_force_at.is_none() {
                            r3_force_at = Some(now);
                            toggle_last_ms = now;
                            toggle_fails += 1;
                        }
                        next_connect_ms = now + CONNECT_REFUSED_RETRY_MS;
                    }
                    ConnectOutcome::NotFound | ConnectOutcome::Failed => {
                        fails += 1;
                        next_connect_ms = now
                            + backoff_ms(
                                fails,
                                CONNECT_BACKOFF_BASE_MS as i64,
                                CONNECT_BACKOFF_CAP_MS as i64,
                            );
                    }
                }
            } else {
                match legacy_connect(&mut stack) {
                    ConnectOutcome::Connected => {
                        fails = 0;
                        next_connect_ms = 0;
                    }
                    _ => {
                        fails += 1;
                        next_connect_ms = now
                            + backoff_ms(
                                fails,
                                CONNECT_BACKOFF_BASE_MS as i64,
                                CONNECT_BACKOFF_CAP_MS as i64,
                            );
                    }
                }
            }
        }
        now += POLL_MS;
    }

    Run {
        connected_at,
        installs_while_in_case,
        stack_installs: stack.installs,
        stack_removals: stack.removals,
        enable_calls: stack.enable_calls,
    }
}

#[test]
fn legacy_never_reconnects_after_the_case_opens() {
    let r = simulate(false);
    println!(
        "LEGACY : connected_at={:?} enable_calls={} driver_installs={} driver_removals={}",
        r.connected_at, r.enable_calls, r.stack_installs, r.stack_removals
    );
    assert!(r.enable_calls > 500, "the loop really did keep trying: {}", r.enable_calls);
    assert_eq!(r.stack_installs, 0, "not one enable ever changed anything");
    assert_eq!(
        r.connected_at, None,
        "REPRODUCED: 15 minutes of polling, 5 minutes with the case open, link still down"
    );
}

#[test]
fn fixed_reconnects_quickly_after_the_case_opens() {
    let r = simulate(true);
    println!(
        "FIXED  : connected_at={:?} ms (case opened at {} ms) enable_calls={} driver_installs={} driver_removals={}",
        r.connected_at, CASE_OPEN_MS, r.enable_calls, r.stack_installs, r.stack_removals
    );
    let at = r.connected_at.expect("the link must come up after the case is opened");
    assert!(at >= CASE_OPEN_MS);
    let delay = at - CASE_OPEN_MS;
    assert!(
        delay <= CONNECT_TOGGLE_MAX_INTERVAL_MS + CONNECT_TOGGLE_SETTLE_MS + POLL_MS,
        "reconnect took {delay} ms after the case opened"
    );
}

#[test]
fn fixed_does_not_churn_drivers_while_the_earbuds_are_away() {
    let r = simulate(true);
    // 60 s with the case closed, floor of 15 s between toggles.
    let max_expected = (CASE_OPEN_MS / CONNECT_TOGGLE_MIN_INTERVAL_MS) as u32 + 1;
    println!(
        "FIXED  : driver re-installs during the 60 s the case stayed closed = {} (cap {})",
        r.installs_while_in_case, max_expected
    );
    assert!(
        r.installs_while_in_case <= max_expected,
        "the toggle must stay rate limited while the peer is unreachable"
    );
}

/// Worst case still consistent with the field log: the export answers 0x57 in
/// both directions, so no toggle is possible. The verdict must escalate to the
/// devnode restart, which is the rung that actually reconnected the earbuds at
/// 19:39:45 in btf.log.
#[test]
fn inert_export_escalates_and_still_reconnects_fast() {
    let mut stack = FakeStack::new();
    stack.inert = true;
    let r = simulate_stack(true, stack);
    println!(
        "INERT  : connected_at={:?} ms (case opened at {} ms) devnode_restarts={}",
        r.connected_at, CASE_OPEN_MS, r.stack_installs
    );
    let at = r.connected_at.expect("the devnode restart must bring the link up");
    let delay = at - CASE_OPEN_MS;
    assert!(
        delay <= CONNECT_TOGGLE_MAX_INTERVAL_MS + 2 * POLL_MS,
        "reconnect took {delay} ms after the case opened"
    );
    let max_expected = (CASE_OPEN_MS / CONNECT_TOGGLE_MIN_INTERVAL_MS) as u32 + 2;
    assert!(
        r.stack_installs <= max_expected,
        "devnode restarts must stay rate limited: {} > {}",
        r.stack_installs,
        max_expected
    );
}
