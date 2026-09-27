//! PoC for the second-order defect the field log exposed at 20:11:07.
//!
//! Field evidence (btf.log, real CSR dongle + Redmi Buds 6 Lite):
//!   20:11:07  connect: forcing a reconnect on A2DP (disable -> enable)
//!   20:11:58  connect: A2DP re-enable attempt 1/5 failed rc=0x424
//!             ... attempts 2/5 and 3/5 failed rc=0x424 ...
//!             attempt 4 succeeded
//! `0x424` == 1060 == ERROR_SERVICE_DOES_NOT_EXIST. So after the DISABLE the
//! stack answers 1060 for SECONDS before the profile can be enabled again.
//!
//! Two consequences, both reproduced below:
//!   1. The old re-enable window (5 tries, one 400 ms settle each) is shorter
//!      than the observed blackout, so A2DP can be left with NO driver.
//!   2. 1060 was classified as "the peer does not offer this profile", so the
//!      next pass reported NotFound -- "peer absent" -- which freezes rungs and
//!      grows the backoff, instead of naming the real state: we owe a driver.
//!
//! Modelling assumption (stated): after a DISABLE, every ENABLE on that
//! profile returns 1060 until `blackout_ms` has passed, then it succeeds.
//! That is exactly the shape of the field log.

use poc::config::*;
use poc::connect_fsm::*;

const FIELD_RC_ALREADY: u32 = 0x57;
const RC_1060: u32 = 0x424;

struct Stack {
    /// Monotonic ms. `wait` advances it, which is also how the harness sees
    /// how long a pass BLOCKS the worker.
    clock: i64,
    enabled: [bool; 3],
    /// When A2DP's driver was removed, and for how long ENABLE answers 1060.
    removed_at: Option<i64>,
    blackout_ms: i64,
    link_up: bool,
    debt: Option<Profile>,
    debt_writes: u32,
    log: Vec<String>,
}

impl Stack {
    fn new(blackout_ms: i64) -> Self {
        Self {
            clock: 0,
            enabled: [true, true, true],
            removed_at: None,
            blackout_ms,
            link_up: false,
            debt: None,
            debt_writes: 0,
            log: Vec::new(),
        }
    }
    fn idx(p: Profile) -> usize {
        Profile::ORDER.iter().position(|&q| q == p).unwrap()
    }
}

impl ServiceStateIo for Stack {
    fn set_state(&mut self, p: Profile, enable: bool) -> u32 {
        let i = Stack::idx(p);
        if enable == self.enabled[i] {
            return FIELD_RC_ALREADY;
        }
        if enable {
            if let Some(at) = self.removed_at {
                if self.clock - at < self.blackout_ms {
                    return RC_1060;
                }
            }
            self.enabled[i] = true;
            self.removed_at = None;
            self.link_up = true;
        } else {
            self.enabled[i] = false;
            self.removed_at = Some(self.clock);
            self.link_up = false;
        }
        RC_SUCCESS
    }
    fn wait(&mut self, ms: u32) {
        self.clock += ms as i64;
    }
    fn log(&mut self, m: &str) {
        self.log.push(m.to_string());
    }
    fn debt_arm(&mut self, p: Profile) -> bool {
        self.debt_writes += 1;
        self.debt = Some(p);
        true
    }
    fn debt_clear(&mut self) {
        self.debt = None;
    }
}

/// The re-enable loop as it shipped before this fix: a fixed 400 ms settle,
/// five tries, and 1060 read as "profile not supported" -> give up.
fn legacy_reenable(io: &mut Stack, profile: Profile) -> bool {
    for _ in 0..5u32 {
        io.wait(CONNECT_TOGGLE_QUIET_MS);
        match io.set_state(profile, true) {
            RC_SUCCESS => return true,
            _ => continue,
        }
    }
    false
}

/// 6 s of 1060 -- the field log's own order of magnitude.
const FIELD_BLACKOUT_MS: i64 = 6_000;

#[test]
fn legacy_reenable_window_is_shorter_than_the_field_blackout() {
    let mut io = Stack::new(FIELD_BLACKOUT_MS);
    assert_eq!(io.set_state(Profile::A2dp, false), RC_SUCCESS);
    let ok = legacy_reenable(&mut io, Profile::A2dp);
    println!(
        "LEGACY : re-enable gave up after {} ms, A2DP enabled={}",
        io.clock, io.enabled[0]
    );
    assert!(!ok, "REPRODUCED: the old ladder cannot outlast a 6 s blackout");
    assert!(!io.enabled[0], "A2DP is left with NO driver and nothing records it");
    assert!(io.clock < FIELD_BLACKOUT_MS);
}

#[test]
fn fixed_reenable_outlasts_the_blackout_and_restores_the_driver() {
    let mut io = Stack::new(FIELD_BLACKOUT_MS);
    assert_eq!(io.set_state(Profile::A2dp, false), RC_SUCCESS);
    let ok = reenable_profile(&mut io, Profile::A2dp);
    println!(
        "FIXED  : re-enable succeeded after {} ms, A2DP enabled={}, link_up={}",
        io.clock, io.enabled[0], io.link_up
    );
    assert!(ok, "1060 is a transient here, so it must be retried through");
    assert!(io.enabled[0] && io.link_up);
}

/// The whole toggle, end to end, against the field blackout: one pass now
/// leaves the profile with its driver back instead of stranded.
#[test]
fn one_pass_survives_the_blackout() {
    let mut io = Stack::new(FIELD_BLACKOUT_MS);
    let res = drive_connect(&mut io, true);
    assert_eq!(res.outcome, ConnectOutcome::Reconnecting);
    assert!(res.toggled && !res.service_left_disabled);
    assert!(io.enabled[0] && io.link_up);
    assert_eq!(io.debt, None, "the debt is settled inside the pass");
    println!("FIXED  : one pass blocked the worker for {} ms", io.clock);
}

/// The blackout that never ends (peer back in the case, SDP unavailable): the
/// driver cannot be restored in this pass. What matters is that the state is
/// NAMED -- the marker is armed before the removal -- so a crash, a restart or
/// an escalation rung cannot lose it.
#[test]
fn an_unrepayable_debt_is_armed_before_the_removal_and_reported() {
    let mut io = Stack::new(i64::MAX / 4);
    let res = drive_connect(&mut io, true);
    assert_eq!(res.outcome, ConnectOutcome::ServiceDebt);
    assert!(res.service_left_disabled);
    assert!(!io.enabled[0]);
    assert_eq!(io.debt, Some(Profile::A2dp), "the marker outlives the process");
    // Armed BEFORE the disable: never after.
    assert_eq!(io.debt_writes, 1);

    // Process restart / next poll: the debt is repaid first, and the blackout
    // is over by then.
    io.blackout_ms = 0;
    assert!(reenable_profile(&mut io, Profile::A2dp));
    assert_eq!(io.debt, None);
    assert!(io.enabled[0] && io.link_up);
}

/// The misdiagnosis the old classification produced: with A2DP's driver gone
/// and the stack still answering 1060, a plain enable pass calls the PEER
/// absent. That verdict freezes the USB rungs and grows the connect backoff --
/// the daemon blames the earbuds for a hole it dug itself.
#[test]
fn a_missing_driver_must_not_be_reported_as_an_absent_peer() {
    let mut io = Stack::new(FIELD_BLACKOUT_MS);
    io.set_state(Profile::A2dp, false);
    let _ = legacy_reenable(&mut io, Profile::A2dp);
    assert!(!io.enabled[0]);

    // This is what the next pass sees: A2DP -> 1060, HFP/AVRCP -> 0x57.
    let res = drive_connect(&mut io, false);
    assert_eq!(
        res.outcome,
        ConnectOutcome::Refused,
        "a refusal is retried soon; NotFound would have frozen the rungs"
    );

    // And with the toggle allowed, the pass repairs A2DP for real once the
    // blackout is over, rather than escalating the ladder.
    io.clock += FIELD_BLACKOUT_MS;
    let res = drive_connect(&mut io, true);
    assert_eq!(res.outcome, ConnectOutcome::Connected);
    assert!(io.enabled[0] && io.link_up);
    assert_eq!(io.debt, None, "no driver was removed, so nothing was owed");
}

#[test]
fn the_blocking_cost_of_a_pass_is_bounded_and_visible() {
    // Worst case: the re-enable ladder runs to the end. The worker is single
    // threaded, so this is exactly how long polling stops -- stated, not
    // hidden, and the reason the rate limit exists.
    let worst: u32 = (0..CONNECT_REENABLE_ATTEMPTS).map(reenable_wait_ms).sum();
    println!("worst-case blocking toggle = {} ms ({} attempts)", worst, CONNECT_REENABLE_ATTEMPTS);
    assert!(worst >= 8_000, "must outlast the observed blackout");
    assert!(worst <= 40_000, "but it may not park the worker for a minute");
}
