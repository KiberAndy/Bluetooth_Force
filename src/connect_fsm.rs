//! Pure connect state machine: profile order, return-code classification and
//! the "service already enabled" reconnect toggle.
//!
//! Split out of `connect.rs` on purpose: it contains zero Win32 calls, so the
//! whole decision path can be exercised off-Windows against a fake stack that
//! implements the documented `BluetoothSetServiceState` contract.
//!
//! Documented contract (bluetoothapis.h, Microsoft Learn):
//!   * `ERROR_SUCCESS`                 -- the service state was changed
//!   * `ERROR_SERVICE_DOES_NOT_EXIST`  -- the peer does not offer that GUID
//!   * `E_INVALIDARG`                  -- ENABLE was asked for a service that is
//!                                        ALREADY ENABLED (or DISABLE for one
//!                                        that is already disabled)
//!
//! Field evidence (btf.log, CSR dongle + Redmi Buds 6 Lite): the export returns
//! `0x57` for all three profiles while the device is paired and its profile
//! drivers are installed. `0x57` is `HRESULT_CODE(E_INVALIDARG)` -- the same
//! condition reported as a bare Win32 code instead of the HRESULT. It cannot be
//! the documented "dwServiceFlags are not valid" case, because the flag passed
//! is the documented `BLUETOOTH_SERVICE_ENABLE`. Both spellings are therefore
//! treated as the same refusal.
//!   * "Enabling a service installs the corresponding device driver and
//!      disabling a service removes the corresponding device driver."
//!
//! Consequence: for a paired device whose audio services are already enabled —
//! the normal steady state after the first successful connect — a plain ENABLE
//! is a no-op that returns `E_INVALIDARG`. Nothing is sent to the peer, so the
//! link can never come back up that way. The only in-process way to force a
//! fresh connection is to REMOVE and re-INSTALL the profile driver: DISABLE ->
//! quiet -> ENABLE.

use crate::config::*;

pub const RC_SUCCESS: u32 = 0;
/// `ERROR_SERVICE_DOES_NOT_EXIST`: the remote device has no such profile.
pub const ERROR_SERVICE_DOES_NOT_EXIST: u32 = 1060;
/// `E_INVALIDARG`: the service is already in the requested state.
pub const E_INVALIDARG: u32 = 0x8007_0057;
/// The same condition as `E_INVALIDARG`, reported as a bare Win32 code (`0x57`)
/// by the stack this tool runs on.
pub const ERROR_INVALID_PARAMETER: u32 = 87;

/// The audio profiles this tool drives, weakest-to-strongest for playback.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Profile {
    A2dp,
    Hfp,
    Avrcp,
}

impl Profile {
    /// A2DP sink carries playback, so it is tried first.
    pub const ORDER: [Profile; 3] = [Profile::A2dp, Profile::Hfp, Profile::Avrcp];

    pub fn name(self) -> &'static str {
        match self {
            Profile::A2dp => "A2DP",
            Profile::Hfp => "HFP",
            Profile::Avrcp => "AVRCP",
        }
    }
}

/// What one `BluetoothSetServiceState` return code means.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RcClass {
    /// The state was changed (driver installed or removed).
    Changed,
    /// Refusal: the service is already in the state we asked for.
    AlreadyInState,
    /// The peer does not offer this profile.
    NotSupported,
    /// Any other failure.
    Error,
}

/// Classify one return code. `0x57` and `0x80070057` are the same refusal (see
/// the module header): the service is already in the requested state.
pub fn classify(rc: u32) -> RcClass {
    match rc {
        RC_SUCCESS => RcClass::Changed,
        E_INVALIDARG | ERROR_INVALID_PARAMETER => RcClass::AlreadyInState,
        ERROR_SERVICE_DOES_NOT_EXIST => RcClass::NotSupported,
        _ => RcClass::Error,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectOutcome {
    /// A profile driver was installed: the stack will bring the link up.
    Connected,
    /// The profile driver was re-installed (disable -> enable) to force a
    /// reconnect. A receipt, not a link: only the next poll's `fConnected`
    /// proves anything.
    Reconnecting,
    /// Every profile refused with "already enabled" and the toggle was rate
    /// limited this pass. Retry soon; nothing was touched.
    Refused,
    /// The export refuses BOTH directions: it cannot change the service state
    /// on this stack at all, so no reconnect can come from this path. The
    /// caller must escalate to the devnode restart instead of waiting out the
    /// ladder's timers.
    Inert,
    /// The peer offers none of the audio profiles we know: treat as absent.
    NotFound,
    /// The profile driver was removed and could NOT be put back yet. The debt
    /// marker is armed; restoring the driver outranks everything else until it
    /// succeeds.
    ServiceDebt,
    /// A real failure.
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ConnectResult {
    pub outcome: ConnectOutcome,
    /// A profile driver was removed and re-installed during this pass.
    pub toggled: bool,
    /// A DISABLE landed but every re-ENABLE failed: that profile is left
    /// without its driver. The next pass's plain ENABLE repairs it, which is
    /// why this is reported instead of being retried forever in place.
    pub service_left_disabled: bool,
}

/// Everything the state machine needs from the outside world.
pub trait ServiceStateIo {
    /// `BluetoothSetServiceState(radio, device, profile, ENABLE | DISABLE)`.
    fn set_state(&mut self, profile: Profile, enable: bool) -> u32;
    /// Sleep.
    fn wait(&mut self, ms: u32);
    /// Durable log line.
    fn log(&mut self, msg: &str);
    /// Persist "this profile's driver was removed by us" BEFORE removing it.
    /// `false` means the marker could not be made durable, and then nothing
    /// may be removed: a profile stuck without its driver is worse than a link
    /// that stays down.
    fn debt_arm(&mut self, profile: Profile) -> bool;
    /// Drop the marker once the driver is verified back.
    fn debt_clear(&mut self);
}

/// Pause before re-ENABLE attempt `attempt` (0-based).
pub fn reenable_wait_ms(attempt: u32) -> u32 {
    if attempt == 0 {
        return CONNECT_TOGGLE_QUIET_MS;
    }
    let mut v = CONNECT_REENABLE_BASE_MS;
    let mut i = 1;
    while i < attempt {
        v = v.saturating_mul(2);
        if v >= CONNECT_REENABLE_CAP_MS {
            return CONNECT_REENABLE_CAP_MS;
        }
        i += 1;
    }
    v.min(CONNECT_REENABLE_CAP_MS)
}

/// Exponential rate limit for the reconnect toggle: it removes and re-installs
/// a driver, so it must not run on every poll. `fails` is the number of toggles
/// since the last connected poll.
pub fn toggle_interval_ms(fails: u32) -> i64 {
    let mut v = CONNECT_TOGGLE_MIN_INTERVAL_MS;
    let mut i = 1;
    while i < fails {
        v = v.saturating_mul(2);
        if v >= CONNECT_TOGGLE_MAX_INTERVAL_MS {
            return CONNECT_TOGGLE_MAX_INTERVAL_MS;
        }
        i += 1;
    }
    v.min(CONNECT_TOGGLE_MAX_INTERVAL_MS)
}

/// May the toggle run now? `last_toggle_ms == 0` means "never toggled".
pub fn should_toggle(now_ms: i64, last_toggle_ms: i64, fails: u32) -> bool {
    if last_toggle_ms == 0 {
        return true;
    }
    if now_ms < last_toggle_ms {
        return true; // clock went backwards: never park the reconnect
    }
    now_ms - last_toggle_ms >= toggle_interval_ms(fails)
}

/// Bring the paired peer's audio profile up.
///
/// Profiles are tried in `Profile::ORDER`. A profile that the peer does not
/// offer is skipped; a profile that is already enabled is a REFUSAL, and the
/// only cure for it is re-installing the driver, which is what `allow_toggle`
/// permits.
pub fn drive_connect<I: ServiceStateIo>(io: &mut I, allow_toggle: bool) -> ConnectResult {
    let mut any_not_supported = false;
    let mut any_already_enabled = false;
    let mut any_error = false;

    for profile in Profile::ORDER {
        let rc = io.set_state(profile, true);
        match classify(rc) {
            RcClass::Changed => {
                io.log(&format!("connect: {} enabled on the peer (driver installed)", profile.name()));
                return ConnectResult {
                    outcome: ConnectOutcome::Connected,
                    toggled: false,
                    service_left_disabled: false,
                };
            }
            RcClass::NotSupported => {
                any_not_supported = true;
            }
            RcClass::AlreadyInState => {
                any_already_enabled = true;
                io.log(&format!(
                    "connect: {} REFUSED (E_INVALIDARG: service already enabled) -- a plain enable never reaches the peer",
                    profile.name()
                ));
                if !allow_toggle {
                    continue;
                }
                return toggle_profile(io, profile);
            }
            RcClass::Error => {
                any_error = true;
                io.log(&format!("connect: {} enable failed rc=0x{rc:x}", profile.name()));
            }
        }
    }

    let outcome = if any_error {
        ConnectOutcome::Failed
    } else if any_already_enabled {
        // Nothing was touched and nothing reached the peer: retry soon.
        ConnectOutcome::Refused
    } else if any_not_supported {
        ConnectOutcome::NotFound
    } else {
        ConnectOutcome::Failed
    };
    ConnectResult { outcome, toggled: false, service_left_disabled: false }
}

/// Force a reconnect on one profile: remove the driver, settle, re-install it.
///
/// The re-ENABLE is retried hard. If it still fails, the profile is left
/// without a driver and that is reported: the very next pass's plain ENABLE
/// finds a disabled service and repairs it, so the state is self-healing.
fn toggle_profile<I: ServiceStateIo>(io: &mut I, profile: Profile) -> ConnectResult {
    io.log(&format!("connect: forcing a reconnect on {} (disable -> enable)", profile.name()));

    // Removing a driver is only allowed when the promise to put it back is
    // durable first.
    if !io.debt_arm(profile) {
        io.log(&format!(
            "connect: cannot write {SERVICE_DEBT_NAME} next to the exe -- REFUSING to remove the {} driver",
            profile.name()
        ));
        return ConnectResult {
            outcome: ConnectOutcome::Failed,
            toggled: false,
            service_left_disabled: false,
        };
    }

    let rc_off = io.set_state(profile, false);
    match classify(rc_off) {
        RcClass::Changed => {}
        RcClass::AlreadyInState => {
            // ENABLE said "already enabled" and DISABLE says "already
            // disabled": the export is not changing anything on this stack, so
            // no amount of retrying here can reconnect the earbuds.
            io.debt_clear();
            io.log(&format!(
                "connect: {} refuses BOTH enable and disable (rc=0x{rc_off:x}) -- BluetoothSetServiceState is inert on this radio; escalating to the earbud-devnode restart",
                profile.name()
            ));
            return ConnectResult {
                outcome: ConnectOutcome::Inert,
                toggled: false,
                service_left_disabled: false,
            };
        }
        _ => {
            io.debt_clear();
            io.log(&format!(
                "connect: {} disable failed rc=0x{rc_off:x} -- profile left exactly as it was",
                profile.name()
            ));
            return ConnectResult {
                outcome: ConnectOutcome::Failed,
                toggled: false,
                service_left_disabled: false,
            };
        }
    }

    match reenable_profile(io, profile) {
        true => ConnectResult {
            outcome: ConnectOutcome::Reconnecting,
            toggled: true,
            service_left_disabled: false,
        },
        false => ConnectResult {
            outcome: ConnectOutcome::ServiceDebt,
            toggled: true,
            service_left_disabled: true,
        },
    }
}

/// Put a removed profile driver back. Shared by the toggle and by the debt
/// repayment pass, so there is exactly one re-install path.
///
/// `ERROR_SERVICE_DOES_NOT_EXIST` here does NOT mean "the peer has no such
/// profile" -- the profile was there a moment ago. It means the stack cannot
/// see the peer's SDP records yet, so it is retried like any other transient.
pub fn reenable_profile<I: ServiceStateIo>(io: &mut I, profile: Profile) -> bool {
    let mut attempt = 0u32;
    while attempt < CONNECT_REENABLE_ATTEMPTS {
        io.wait(reenable_wait_ms(attempt));
        let rc = io.set_state(profile, true);
        match classify(rc) {
            RcClass::Changed | RcClass::AlreadyInState => {
                io.debt_clear();
                io.log(&format!("connect: {} driver re-installed -- reconnect requested", profile.name()));
                return true;
            }
            _ => io.log(&format!(
                "connect: {} re-enable attempt {}/{} failed rc=0x{rc:x}",
                profile.name(),
                attempt + 1,
                CONNECT_REENABLE_ATTEMPTS
            )),
        }
        attempt += 1;
    }

    io.log(&format!(
        "connect: {} RE-ENABLE FAILED after {} attempts -- the profile has NO driver right now and {SERVICE_DEBT_NAME} stays armed; restoring it outranks every rung until it succeeds",
        profile.name(),
        CONNECT_REENABLE_ATTEMPTS
    ));
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A fake stack that implements the documented contract exactly.
    struct FakeStack {
        /// Earbuds in the closed case: unreachable.
        in_case: bool,
        /// Windows-persisted service state, per `Profile::ORDER`.
        enabled: [bool; 3],
        /// Profiles the peer offers.
        supported: [bool; 3],
        /// Set when a driver install actually reaches a reachable peer.
        link_up: bool,
        enable_fails: bool,
        /// Re-enable fails this many times before it starts working, with
        /// rc=1060, exactly as the field log shows.
        enable_transient_1060: u32,
        /// `debt_arm` cannot make the marker durable (read-only directory).
        debt_unwritable: bool,
        debt: Option<Profile>,
        waits: Vec<u32>,
        calls: Vec<(Profile, bool, u32)>,
    }

    impl FakeStack {
        /// Steady state after one successful connect: services enabled, link down.
        fn paired_and_enabled() -> Self {
            Self {
                in_case: false,
                enabled: [true, true, true],
                supported: [true, true, true],
                link_up: false,
                enable_fails: false,
                enable_transient_1060: 0,
                debt_unwritable: false,
                debt: None,
                waits: Vec::new(),
                calls: Vec::new(),
            }
        }
        fn idx(p: Profile) -> usize {
            Profile::ORDER.iter().position(|&q| q == p).unwrap()
        }
    }

    impl ServiceStateIo for FakeStack {
        fn set_state(&mut self, profile: Profile, enable: bool) -> u32 {
            let i = FakeStack::idx(profile);
            let rc = if !self.supported[i] {
                ERROR_SERVICE_DOES_NOT_EXIST
            } else if enable == self.enabled[i] {
                E_INVALIDARG
            } else if enable && self.enable_fails {
                5 // ERROR_ACCESS_DENIED, stands in for any hard failure
            } else if enable && self.enable_transient_1060 > 0 {
                self.enable_transient_1060 -= 1;
                ERROR_SERVICE_DOES_NOT_EXIST
            } else {
                self.enabled[i] = enable;
                if enable {
                    // "Enabling a service installs the corresponding device
                    // driver": a fresh install pages the peer.
                    if !self.in_case {
                        self.link_up = true;
                    }
                } else {
                    self.link_up = false;
                }
                RC_SUCCESS
            };
            self.calls.push((profile, enable, rc));
            rc
        }
        fn wait(&mut self, ms: u32) {
            self.waits.push(ms);
        }
        fn log(&mut self, _msg: &str) {}
        fn debt_arm(&mut self, profile: Profile) -> bool {
            if self.debt_unwritable {
                return false;
            }
            self.debt = Some(profile);
            true
        }
        fn debt_clear(&mut self) {
            self.debt = None;
        }
    }

    /// The bug: with the toggle unavailable, an already-enabled service can
    /// only be refused. No traffic reaches the peer, so the link stays down.
    #[test]
    fn already_enabled_is_a_refusal_not_a_connect() {
        let mut fake = FakeStack::paired_and_enabled();
        for _ in 0..30 {
            let res = drive_connect(&mut fake, false);
            assert_eq!(res.outcome, ConnectOutcome::Refused);
            assert!(!res.toggled);
        }
        assert!(!fake.link_up, "no enable can reach a peer whose services are already enabled");
        assert!(fake.calls.iter().all(|&(_, enable, rc)| enable && rc == E_INVALIDARG));
    }

    /// The fix: one toggle re-installs the driver and the link comes up.
    #[test]
    fn toggle_reconnects_on_the_first_pass() {
        let mut fake = FakeStack::paired_and_enabled();
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::Reconnecting);
        assert!(res.toggled && !res.service_left_disabled);
        assert!(fake.link_up);
        // A2DP first, and only A2DP: disable then enable.
        assert_eq!(fake.calls[0], (Profile::A2dp, true, E_INVALIDARG));
        assert_eq!(fake.calls[1], (Profile::A2dp, false, RC_SUCCESS));
        assert_eq!(fake.calls[2], (Profile::A2dp, true, RC_SUCCESS));
        assert_eq!(fake.calls.len(), 3);
    }

    /// A peer in the case must not be reported as connected by a receipt.
    #[test]
    fn toggle_in_case_does_not_claim_a_link() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.in_case = true;
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::Reconnecting);
        assert!(!fake.link_up);
    }

    #[test]
    fn peer_without_audio_profiles_is_absent() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.supported = [false, false, false];
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::NotFound);
        assert!(!res.toggled);
    }

    /// A service that is not enabled yet still connects with a plain enable,
    /// without touching any driver.
    #[test]
    fn disabled_service_connects_without_a_toggle() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.enabled = [false, true, true];
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::Connected);
        assert!(!res.toggled);
        assert!(fake.link_up);
        assert_eq!(fake.calls.len(), 1);
    }

    /// A failed re-enable is reported, and the next pass repairs it.
    #[test]
    fn failed_reenable_is_reported_and_self_heals() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.enable_fails = true;
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::ServiceDebt);
        assert!(res.toggled && res.service_left_disabled);
        assert!(!fake.enabled[0], "A2DP is left without its driver");
        assert_eq!(fake.debt, Some(Profile::A2dp), "the debt marker stays armed");
        assert_eq!(
            fake.calls.iter().filter(|&&(p, en, _)| p == Profile::A2dp && en).count() as u32,
            CONNECT_REENABLE_ATTEMPTS + 1
        );

        // The debt repayment pass, with the hard failure gone, puts the driver
        // back and drops the marker.
        fake.enable_fails = false;
        fake.calls.clear();
        assert!(reenable_profile(&mut fake, Profile::A2dp));
        assert_eq!(fake.debt, None);
        assert!(fake.enabled[0] && fake.link_up);
    }

    /// A refusal must not be able to strand the profile: a disable that fails
    /// leaves the service exactly as it was.
    #[test]
    fn failed_disable_changes_nothing() {
        struct DisableFails(Vec<(Profile, bool)>);
        impl ServiceStateIo for DisableFails {
            fn set_state(&mut self, p: Profile, enable: bool) -> u32 {
                self.0.push((p, enable));
                if enable { E_INVALIDARG } else { 5 }
            }
            fn wait(&mut self, _ms: u32) {}
            fn log(&mut self, _m: &str) {}
            fn debt_arm(&mut self, _p: Profile) -> bool {
                true
            }
            fn debt_clear(&mut self) {}
        }
        let mut io = DisableFails(Vec::new());
        let res = drive_connect(&mut io, true);
        assert_eq!(res.outcome, ConnectOutcome::Failed);
        assert!(!res.toggled && !res.service_left_disabled);
        assert_eq!(io.0, vec![(Profile::A2dp, true), (Profile::A2dp, false)]);
    }

    #[test]
    fn rc_classification_covers_both_spellings_of_the_refusal() {
        assert_eq!(classify(0), RcClass::Changed);
        assert_eq!(classify(E_INVALIDARG), RcClass::AlreadyInState);
        // 0x57 is what the field log actually shows on every profile.
        assert_eq!(classify(0x57), RcClass::AlreadyInState);
        assert_eq!(classify(ERROR_SERVICE_DOES_NOT_EXIST), RcClass::NotSupported);
        assert_eq!(classify(5), RcClass::Error);
    }

    /// Replays the exact field log: rc=0x57 on A2DP, HFP and AVRCP.
    #[test]
    fn field_rc_0x57_is_a_refusal_and_triggers_the_toggle() {
        struct FieldStack {
            enabled: bool,
            calls: Vec<(Profile, bool)>,
        }
        impl ServiceStateIo for FieldStack {
            fn set_state(&mut self, p: Profile, enable: bool) -> u32 {
                self.calls.push((p, enable));
                if enable == self.enabled {
                    return 0x57; // exactly what btf.log reported
                }
                self.enabled = enable;
                RC_SUCCESS
            }
            fn wait(&mut self, _ms: u32) {}
            fn log(&mut self, _m: &str) {}
            fn debt_arm(&mut self, _p: Profile) -> bool {
                true
            }
            fn debt_clear(&mut self) {}
        }

        let mut io = FieldStack { enabled: true, calls: Vec::new() };
        // Without the toggle: a refusal, forever, which is the reported symptom.
        assert_eq!(drive_connect(&mut io, false).outcome, ConnectOutcome::Refused);
        // With it: the driver is re-installed on the first pass.
        let res = drive_connect(&mut io, true);
        assert_eq!(res.outcome, ConnectOutcome::Reconnecting);
        assert!(res.toggled);
        assert!(io.enabled, "the profile is enabled again when the pass returns");
    }

    /// A stack whose export refuses both directions cannot reconnect anything:
    /// that must be reported, not retried in place.
    #[test]
    fn inert_export_is_reported_for_escalation() {
        struct InertStack(u32);
        impl ServiceStateIo for InertStack {
            fn set_state(&mut self, _p: Profile, _enable: bool) -> u32 {
                self.0 += 1;
                0x57
            }
            fn wait(&mut self, _ms: u32) {}
            fn log(&mut self, _m: &str) {}
            fn debt_arm(&mut self, _p: Profile) -> bool {
                true
            }
            fn debt_clear(&mut self) {}
        }
        let mut io = InertStack(0);
        let res = drive_connect(&mut io, true);
        assert_eq!(res.outcome, ConnectOutcome::Inert);
        assert!(!res.toggled && !res.service_left_disabled);
        assert_eq!(io.0, 2, "one enable, one disable, then stop -- no storm");
    }

    #[test]
    fn toggle_rate_limit_grows_and_caps() {
        assert_eq!(toggle_interval_ms(0), CONNECT_TOGGLE_MIN_INTERVAL_MS);
        assert_eq!(toggle_interval_ms(1), CONNECT_TOGGLE_MIN_INTERVAL_MS);
        assert_eq!(toggle_interval_ms(2), CONNECT_TOGGLE_MIN_INTERVAL_MS * 2);
        assert_eq!(toggle_interval_ms(9), CONNECT_TOGGLE_MAX_INTERVAL_MS);

        assert!(should_toggle(1_000_000, 0, 0), "never toggled -> go now");
        let last = 1_000_000;
        assert!(!should_toggle(last + CONNECT_TOGGLE_MIN_INTERVAL_MS - 1, last, 1));
        assert!(should_toggle(last + CONNECT_TOGGLE_MIN_INTERVAL_MS, last, 1));
        assert!(should_toggle(last - 1, last, 1), "clock going backwards must not park it");
    }

    /// The field log: after the DISABLE, the re-ENABLE answers rc=0x424
    /// (1060, ERROR_SERVICE_DOES_NOT_EXIST) for several seconds before it
    /// takes. The old code read 1060 as "the peer has no such profile", gave
    /// up after 5 fast tries and left A2DP without a driver -- that is the
    /// "nothing reconnects until I replug the dongle" report.
    #[test]
    fn transient_1060_after_disable_is_retried_not_believed() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.enable_transient_1060 = 3;
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::Reconnecting);
        assert!(res.toggled && !res.service_left_disabled);
        assert!(fake.enabled[0] && fake.link_up);
        assert_eq!(fake.debt, None, "the driver is back, so the marker is gone");
        // The retries have to be spread out, not hammered: 4 attempts, and the
        // pauses grow.
        assert_eq!(fake.waits.len(), 4);
        assert!(fake.waits[3] > fake.waits[1]);
    }

    /// 1060 on the *first* enable still means "the peer does not offer this
    /// profile": that path must not be broken by the retry above.
    #[test]
    fn rc_1060_on_a_plain_enable_still_means_absent() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.supported = [false, false, false];
        assert_eq!(drive_connect(&mut fake, true).outcome, ConnectOutcome::NotFound);
        assert_eq!(fake.debt, None);
    }

    /// No durable marker, no driver removal. A profile stranded without a
    /// driver and no record of it is the one state the daemon cannot recover
    /// from on its own.
    #[test]
    fn a_debt_that_cannot_be_armed_blocks_the_removal() {
        let mut fake = FakeStack::paired_and_enabled();
        fake.debt_unwritable = true;
        let res = drive_connect(&mut fake, true);
        assert_eq!(res.outcome, ConnectOutcome::Failed);
        assert!(!res.toggled && !res.service_left_disabled);
        assert!(fake.enabled.iter().all(|&e| e), "nothing was removed");
        assert!(
            fake.calls.iter().all(|&(_, enable, _)| enable),
            "not a single disable was issued"
        );
    }

    #[test]
    fn reenable_pauses_start_at_the_settle_time_then_back_off_and_cap() {
        assert_eq!(reenable_wait_ms(0), CONNECT_TOGGLE_QUIET_MS);
        assert_eq!(reenable_wait_ms(1), CONNECT_REENABLE_BASE_MS);
        assert_eq!(reenable_wait_ms(2), CONNECT_REENABLE_BASE_MS * 2);
        assert_eq!(reenable_wait_ms(3), CONNECT_REENABLE_BASE_MS * 4);
        assert_eq!(reenable_wait_ms(99), CONNECT_REENABLE_CAP_MS);
        // The whole ladder has to outlast the ~4 s of 1060 seen in the field.
        let total: u32 = (0..CONNECT_REENABLE_ATTEMPTS).map(reenable_wait_ms).sum();
        assert!(total >= 8_000, "re-enable window too short: {total} ms");
    }
}
