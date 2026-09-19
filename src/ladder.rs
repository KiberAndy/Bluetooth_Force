//! The pure decision layer: every timing gate, the circuit breaker and the
//! escalation predicates. Keeping these free of I/O means the ladder's
//! behaviour is exhaustively testable and cannot drift from what actually
//! runs.

use crate::config::*;
use crate::sys::cfgmgr32::{CM_PROB_DISABLED, DN_HAS_PROBLEM, DN_STARTED};

/// L3 — exponential backoff with a hard cap. `failures == 0` means no delay.
pub fn backoff_ms(consecutive_failures: u32, base_ms: u32, cap_ms: u32) -> u32 {
    if consecutive_failures == 0 {
        return 0;
    }
    let mut v = base_ms as u64;
    let mut i = 1;
    while i < consecutive_failures {
        v = v.wrapping_mul(2);
        if v >= cap_ms as u64 {
            return cap_ms;
        }
        i += 1;
    }
    v.min(cap_ms as u64) as u32
}

/// L5 — a tumbling-window circuit breaker. `allow()` counts expensive OS calls
/// and trips once `max_events` is exceeded in a window, after which it refuses
/// until `cooldown_ms` elapses. Makes a runaway storm physically impossible.
#[derive(Debug, Clone, Copy)]
pub struct CircuitBreaker {
    pub window_ms: i64,
    pub max_events: u32,
    pub cooldown_ms: i64,
    count: u32,
    window_start_ms: i64,
    tripped_until_ms: i64,
    pub trip_count: u32,
}

impl CircuitBreaker {
    pub const fn new(window_ms: i64, max_events: u32, cooldown_ms: i64) -> Self {
        Self {
            window_ms,
            max_events,
            cooldown_ms,
            count: 0,
            window_start_ms: 0,
            tripped_until_ms: 0,
            trip_count: 0,
        }
    }

    pub fn allow(&mut self, now_ms: i64) -> bool {
        if now_ms < self.tripped_until_ms {
            return false;
        }
        if now_ms - self.window_start_ms >= self.window_ms {
            self.window_start_ms = now_ms;
            self.count = 0;
        }
        self.count += 1;
        if self.count > self.max_events {
            self.tripped_until_ms = now_ms + self.cooldown_ms;
            self.trip_count += 1;
            self.count = 0;
            self.window_start_ms = now_ms;
            return false;
        }
        true
    }

    // Used by unit tests; production code only needs `allow()`.
    #[cfg_attr(not(test), allow(dead_code))]
    pub fn is_tripped(&self, now_ms: i64) -> bool {
        now_ms < self.tripped_until_ms
    }
}

/// L6 — trip the paged-pool watchdog when usage exceeds the lowest-seen
/// baseline by more than `threshold_bytes`.
pub fn watchdog_tripped(min_baseline_bytes: u64, current_bytes: u64, threshold_bytes: u64) -> bool {
    current_bytes > min_baseline_bytes
        && (current_bytes - min_baseline_bytes) > threshold_bytes
}

/// Devnode is software-disabled: `DN_HAS_PROBLEM` + `CM_PROB_DISABLED`.
pub fn devnode_status_means_disabled(status: u32, problem: u32) -> bool {
    (status & DN_HAS_PROBLEM) != 0 && problem == CM_PROB_DISABLED
}

/// Devnode is running: `DN_STARTED`, no problem bit and a clean problem code.
pub fn devnode_status_means_started(status: u32, problem: u32) -> bool {
    (status & DN_STARTED) != 0 && (status & DN_HAS_PROBLEM) == 0 && problem == 0
}

/// Should the worker perform the programmatic radio reset now?
/// `armed_ms == 0` is the "not armed" sentinel; `last_reset_ms == 0` means
/// "no reset yet".
pub fn should_radio_reset(armed_ms: i64, now_ms: i64, last_reset_ms: i64) -> bool {
    if armed_ms == 0 {
        return false;
    }
    if now_ms - armed_ms < R1_ARM_MS {
        return false;
    }
    if last_reset_ms != 0 && now_ms - last_reset_ms < R1_COOLDOWN_MS {
        return false;
    }
    true
}

/// Should the worker escalate to the usb-cycle rung now? Only after the softer
/// page-scan rung has already been exercised in this episode.
pub fn should_usb_cycle(
    armed_ms: i64,
    now_ms: i64,
    r1_reset_in_episode: bool,
    last_cycle_ms: i64,
) -> bool {
    if armed_ms == 0 || !r1_reset_in_episode {
        return false;
    }
    if now_ms - armed_ms < R2_ARM_MS {
        return false;
    }
    if last_cycle_ms != 0 && now_ms - last_cycle_ms < R2_MIN_INTERVAL_MS {
        return false;
    }
    true
}

/// Should the worker power-cycle the dongle's hub port now? Only after a
/// verified R2 completion left the link down.
pub fn should_hub_port_cycle(
    armed_ms: i64,
    now_ms: i64,
    r2_cycled_in_episode: bool,
    last_portcycle_ms: i64,
) -> bool {
    if armed_ms == 0 || !r2_cycled_in_episode {
        return false;
    }
    if now_ms - armed_ms < R4_ARM_MS {
        return false;
    }
    if last_portcycle_ms != 0 && now_ms - last_portcycle_ms < R4_MIN_INTERVAL_MS {
        return false;
    }
    true
}

/// Should the worker restart the earbuds' own function devnodes now?
///
/// `force_after_ms != 0` is the one-shot refresh queued after a verified
/// usb-cycle; it bypasses the arm/interval/episode gates but never the breaker.
pub fn should_earbud_restart(
    armed_ms: i64,
    now_ms: i64,
    last_restart_ms: i64,
    restarts_in_episode: u32,
    force_after_ms: i64,
) -> bool {
    if armed_ms == 0 {
        return false;
    }
    if force_after_ms != 0 {
        return now_ms >= force_after_ms;
    }
    if now_ms - armed_ms < R3_ARM_MS {
        return false;
    }
    if restarts_in_episode >= R3_MAX_PER_EPISODE {
        return false;
    }
    if last_restart_ms != 0 && now_ms - last_restart_ms < R3_MIN_INTERVAL_MS {
        return false;
    }
    true
}

/// The usb-cycle stays quiet for a window after a verified earbud restart.
/// `0` means "no restart yet" (nothing to wait for).
pub fn usb_cycle_quiet_after_restart(now_ms: i64, last_restart_done_ms: i64) -> bool {
    if last_restart_done_ms == 0 {
        return true;
    }
    now_ms - last_restart_done_ms >= R2_POST_R3_QUIET_MS
}

/// Is the page-scan rung provably dead on this radio?
pub fn radio_reset_rung_dead(consecutive_rejects: u32) -> bool {
    consecutive_rejects >= R1_DEAD_REJECTIONS
}

/// Is the usb-cycle rung muted after proven-harmful attempts?
pub fn usb_cycle_rung_dead(consecutive_failures: u32) -> bool {
    consecutive_failures >= R2_DEAD_FAILURES
}

/// Is the hub-port-cycle rung provably useless on this machine?
pub fn hub_port_cycle_rung_dead(portcycle_fails: u32) -> bool {
    portcycle_fails >= R4_DEAD_FAILURES
}

/// A repair is retried with exponential backoff and is deliberately NOT subject
/// to a circuit breaker: giving up on the user's Bluetooth is never safer.
/// A backwards clock must not be able to park a disabled radio, so a negative
/// delta means "go now".
pub fn should_retry_recovery(now: i64, last_attempt_ms: i64, delay_ms: i64) -> bool {
    if last_attempt_ms == 0 {
        return true;
    }
    if now < last_attempt_ms {
        return true;
    }
    now - last_attempt_ms >= delay_ms
}

/// Exponential slowdown for consecutive failed repair passes, capped.
pub fn recovery_retry_delay_ms(consec_fails: u32) -> i64 {
    let mut d = RECOVERY_RETRY_MS;
    let mut i = 0;
    while i < consec_fails {
        if d >= RECOVERY_BACKOFF_CAP_MS / 2 {
            return RECOVERY_BACKOFF_CAP_MS;
        }
        d *= 2;
        i += 1;
    }
    d
}

/// A streak of "device not found" verdicts freezes the radio-destructive rungs.
pub fn peer_absent_freeze(consec_not_found: u32) -> bool {
    consec_not_found >= PEER_ABSENT_FREEZE_AFTER
}

/// The repair is complete only when the radio is present and nothing is left
/// disabled. `present == 0` means the dongle is unplugged: the journal is kept.
pub fn radio_recovery_done(present_nodes: u32, still_disabled: u32) -> bool {
    present_nodes > 0 && still_disabled == 0
}

/// Repair before escalate.
pub fn recovery_blocks_escalation(recovery_armed: bool) -> bool {
    recovery_armed
}

/// Does this radio devnode need repairing?
///
/// A deliberate user disable (`CM_PROB_DISABLED`) is only ours to undo when the
/// journal says we own it; any other unhealthy state is a fault.
pub fn radio_needs_repair(status: u32, problem: u32, journal_armed: bool) -> bool {
    if devnode_status_means_started(status, problem) {
        return false;
    }
    if devnode_status_means_disabled(status, problem) {
        return journal_armed;
    }
    true
}

/// The only action the poll loop can take for the target device.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PollAction {
    /// Device was not found on this radio — keep scanning.
    None,
    /// Connected — start/keep the silent keepalive so the earbuds never idle.
    StartKeepalive,
    /// Known but not connected — stop any stale keepalive and reconnect.
    StopAndConnect,
}

/// The sole entry point for sound playback: exhaustively testable.
pub fn decide_poll_action(found: bool, f_connected: i32) -> PollAction {
    if !found {
        return PollAction::None;
    }
    if f_connected != 0 {
        PollAction::StartKeepalive
    } else {
        PollAction::StopAndConnect
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backoff_grows_and_caps() {
        assert_eq!(backoff_ms(0, 500, 4000), 0);
        assert_eq!(backoff_ms(1, 500, 4000), 500);
        assert_eq!(backoff_ms(2, 500, 4000), 1000);
        assert_eq!(backoff_ms(3, 500, 4000), 2000);
        assert_eq!(backoff_ms(4, 500, 4000), 4000);
        assert_eq!(backoff_ms(50, 500, 4000), 4000);
    }

    #[test]
    fn breaker_trips_and_recovers() {
        let mut cb = CircuitBreaker::new(10_000, 3, 30_000);
        assert!(cb.allow(1000));
        assert!(cb.allow(1100));
        assert!(cb.allow(1200));
        assert!(!cb.allow(1300));
        assert!(cb.is_tripped(1300));
        assert!(!cb.allow(5000));
        assert_eq!(cb.trip_count, 1);
        assert!(!cb.is_tripped(31_301));
        assert!(cb.allow(31_301));
    }

    #[test]
    fn watchdog_edges() {
        let mb = 1024 * 1024;
        assert!(!watchdog_tripped(100 * mb, 500 * mb, 800 * mb));
        assert!(!watchdog_tripped(100 * mb, 900 * mb, 800 * mb));
        assert!(watchdog_tripped(100 * mb, 901 * mb, 800 * mb));
        assert!(!watchdog_tripped(500 * mb, 100 * mb, 800 * mb));
    }

    #[test]
    fn r1_gate() {
        assert!(!should_radio_reset(0, 86_400_000, 0));
        assert!(!should_radio_reset(1000, 1000 + R1_ARM_MS - 1, 0));
        assert!(should_radio_reset(1000, 1000 + R1_ARM_MS, 0));
        let last = 1000 + R1_ARM_MS;
        assert!(!should_radio_reset(1000, last + R1_COOLDOWN_MS - 1, last));
        assert!(should_radio_reset(1000, last + R1_COOLDOWN_MS, last));
    }

    #[test]
    fn ladder_ordering() {
        assert!(R1_ARM_MS < R3_ARM_MS);
        assert!(R3_ARM_MS < R2_ARM_MS);
        assert!(R3_MIN_INTERVAL_MS > R1_COOLDOWN_MS);
    }

    #[test]
    fn r2_gate() {
        assert!(!should_usb_cycle(0, 86_400_000, true, 0));
        assert!(!should_usb_cycle(1000, 1000 + R2_ARM_MS + 60_000, false, 0));
        assert!(!should_usb_cycle(1000, 1000 + R2_ARM_MS - 1, true, 0));
        assert!(should_usb_cycle(1000, 1000 + R2_ARM_MS, true, 0));
        let last = 1000 + R2_ARM_MS;
        assert!(!should_usb_cycle(1000, last + R2_MIN_INTERVAL_MS - 1, true, last));
        assert!(should_usb_cycle(1000, last + R2_MIN_INTERVAL_MS, true, last));
    }

    #[test]
    fn r4_gate() {
        assert!(!should_hub_port_cycle(0, 1_000_000 + R4_ARM_MS, true, 0));
        assert!(!should_hub_port_cycle(1_000_000, 1_000_000 + R4_ARM_MS, false, 0));
        assert!(!should_hub_port_cycle(1_000_000, 1_000_000 + R4_ARM_MS - 1, true, 0));
        assert!(should_hub_port_cycle(1_000_000, 1_000_000 + R4_ARM_MS, true, 0));
    }

    #[test]
    fn r3_gate() {
        assert!(!should_earbud_restart(0, 10_000_000, 0, 0, 0));
        assert!(!should_earbud_restart(0, 10_000_000, 0, 0, 9_999_999));
        assert!(!should_earbud_restart(100_000, 100_000 + R3_ARM_MS - 1, 0, 0, 0));
        assert!(should_earbud_restart(100_000, 100_000 + R3_ARM_MS, 0, 0, 0));
        assert!(should_earbud_restart(100_000, 200_000, 195_000, 99, 200_000));
        assert!(!should_earbud_restart(100_000, 199_999, 195_000, 99, 200_000));
    }

    #[test]
    fn recovery_backoff_sequence() {
        assert_eq!(recovery_retry_delay_ms(0), 5_000);
        assert_eq!(recovery_retry_delay_ms(1), 10_000);
        assert_eq!(recovery_retry_delay_ms(2), 20_000);
        assert_eq!(recovery_retry_delay_ms(3), 40_000);
        assert_eq!(recovery_retry_delay_ms(4), RECOVERY_BACKOFF_CAP_MS);
        assert_eq!(recovery_retry_delay_ms(100), RECOVERY_BACKOFF_CAP_MS);
    }

    #[test]
    fn devnode_predicates() {
        assert!(devnode_status_means_disabled(DN_HAS_PROBLEM, CM_PROB_DISABLED));
        assert!(!devnode_status_means_disabled(DN_STARTED, 0));
        assert!(devnode_status_means_started(DN_STARTED, 0));
        assert!(!devnode_status_means_started(DN_STARTED, CM_PROB_DISABLED));
        assert!(!devnode_status_means_started(0, 0));
    }

    #[test]
    fn repair_policy() {
        assert!(radio_needs_repair(DN_HAS_PROBLEM, 10, false));
        assert!(radio_needs_repair(0, 0, false));
        assert!(!radio_needs_repair(DN_STARTED, 0, false));
        assert!(!radio_needs_repair(DN_HAS_PROBLEM, CM_PROB_DISABLED, false));
        assert!(radio_needs_repair(DN_HAS_PROBLEM, CM_PROB_DISABLED, true));
    }

    #[test]
    fn recovery_gates() {
        assert!(should_retry_recovery(0, 0, RECOVERY_RETRY_MS));
        assert!(!should_retry_recovery(500_000, 500_000, RECOVERY_RETRY_MS));
        assert!(should_retry_recovery(500_000 - 1, 500_000, RECOVERY_RETRY_MS));
        assert!(should_retry_recovery(500_000 + RECOVERY_RETRY_MS, 500_000, RECOVERY_RETRY_MS));
        assert!(!radio_recovery_done(0, 0));
        assert!(!radio_recovery_done(1, 1));
        assert!(radio_recovery_done(1, 0));
        assert!(recovery_blocks_escalation(true));
        assert!(!recovery_blocks_escalation(false));
    }

    #[test]
    fn poll_decisions() {
        assert_eq!(decide_poll_action(false, 1), PollAction::None);
        assert_eq!(decide_poll_action(true, 0), PollAction::StopAndConnect);
        assert_eq!(decide_poll_action(true, 1), PollAction::StartKeepalive);
        assert_eq!(decide_poll_action(true, -1), PollAction::StartKeepalive);
        assert_eq!(decide_poll_action(true, i32::MAX), PollAction::StartKeepalive);
    }
}
