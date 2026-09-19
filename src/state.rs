//! Mutable daemon state shared between the worker thread and the shutdown path.
//!
//! The worker owns every field except `running` (an atomic read/written by
//! main); main only touches the rest after the worker has been joined.

use std::sync::atomic::{AtomicBool, Ordering};

use crate::audio::SilentKeepalive;
use crate::bluetooth::BthApi;
use crate::config::*;
use crate::ladder::CircuitBreaker;
use crate::sys::HANDLE;

pub struct SharedState {
    pub running: AtomicBool,
    pub target_mac: u64,
    pub resume_event: HANDLE,
    pub bth: BthApi,
    pub keepalive: SilentKeepalive,

    // L3 — connect backoff.
    pub connect_fails: u32,
    pub next_connect_ms: i64,
    // L5 — reconnect storm cap.
    pub connect_breaker: CircuitBreaker,

    // L6 — paged-pool watchdog.
    pub pool_min_bytes: u64,
    pub watchdog_tripped: bool,
    pub watchdog_tripped_ms: i64,
    pub watchdog_last_log_ms: i64,

    // R1 — page-scan toggle.
    pub r1_armed_ms: i64,
    pub r1_last_reset_ms: i64,
    pub r1_reset_in_episode: bool,
    pub r1_rejects: u32,
    pub r1_dead_logged: bool,
    pub r1_breaker: CircuitBreaker,

    // Flap hysteresis.
    pub link_stable_polls: u32,
    pub flaps_in_episode: u32,

    // R2 — usb-cycle.
    pub r2_last_cycle_ms: i64,
    pub r2_admin_skip_logged: bool,
    pub r2_fails: u32,
    pub r2_dead_logged: bool,
    pub r2_cycled_in_episode: bool,
    pub r2_breaker: CircuitBreaker,

    // R3 — earbud devnode restart.
    pub r3_last_restart_ms: i64,
    pub r3_restarts_in_episode: u32,
    pub r3_force_after_ms: i64,
    pub r3_admin_skip_logged: bool,
    pub r3_last_complete_ms: i64,
    pub r3_breaker: CircuitBreaker,

    // R4 — hub port power-cycle.
    pub r4_last_ms: i64,
    pub r4_admin_skip_logged: bool,
    pub r4_fails: u32,
    pub r4_dead_logged: bool,
    pub r4_breaker: CircuitBreaker,

    // Rung 0 — repair journal.
    pub recovery_armed: bool,
    pub recovery_last_ms: i64,
    pub recovery_attempts: u32,
    pub recovery_logged: bool,
    pub recovery_fails: u32,
    pub recovery_quiet_logged: bool,
    pub recovery_saw_absent: bool,
    pub recovery_saw_unelevated: bool,

    // Peer-absent freeze.
    pub peer_absent_streak: u32,
    pub peer_absent_logged: bool,

    // Kill switch (`btf_freeze.txt`).
    pub escalation_frozen: bool,
    pub freeze_checked_ms: i64,
}

impl SharedState {
    pub fn new(target_mac: u64, resume_event: HANDLE, bth: BthApi, keepalive: SilentKeepalive) -> Self {
        Self {
            running: AtomicBool::new(true),
            target_mac,
            resume_event,
            bth,
            keepalive,
            connect_fails: 0,
            next_connect_ms: 0,
            connect_breaker: CircuitBreaker::new(
                CONNECT_CB_WINDOW_MS,
                CONNECT_CB_MAX_EVENTS,
                CONNECT_CB_COOLDOWN_MS,
            ),
            pool_min_bytes: u64::MAX,
            watchdog_tripped: false,
            watchdog_tripped_ms: 0,
            watchdog_last_log_ms: 0,
            r1_armed_ms: 0,
            r1_last_reset_ms: 0,
            r1_reset_in_episode: false,
            r1_rejects: 0,
            r1_dead_logged: false,
            r1_breaker: CircuitBreaker::new(R1_CB_WINDOW_MS, R1_CB_MAX_RESETS, R1_CB_COOLDOWN_MS),
            link_stable_polls: 0,
            flaps_in_episode: 0,
            r2_last_cycle_ms: 0,
            r2_admin_skip_logged: false,
            r2_fails: 0,
            r2_dead_logged: false,
            r2_cycled_in_episode: false,
            r2_breaker: CircuitBreaker::new(R2_CB_WINDOW_MS, R2_CB_MAX_CYCLES, R2_CB_COOLDOWN_MS),
            r3_last_restart_ms: 0,
            r3_restarts_in_episode: 0,
            r3_force_after_ms: 0,
            r3_admin_skip_logged: false,
            r3_last_complete_ms: 0,
            r3_breaker: CircuitBreaker::new(R3_CB_WINDOW_MS, R3_CB_MAX_RESTARTS, R3_CB_COOLDOWN_MS),
            r4_last_ms: 0,
            r4_admin_skip_logged: false,
            r4_fails: 0,
            r4_dead_logged: false,
            r4_breaker: CircuitBreaker::new(R4_CB_WINDOW_MS, R4_CB_MAX_PORTCYCLES, R4_CB_COOLDOWN_MS),
            recovery_armed: false,
            recovery_last_ms: 0,
            recovery_attempts: 0,
            recovery_logged: false,
            recovery_fails: 0,
            recovery_quiet_logged: false,
            recovery_saw_absent: false,
            recovery_saw_unelevated: false,
            peer_absent_streak: 0,
            peer_absent_logged: false,
            escalation_frozen: false,
            freeze_checked_ms: 0,
        }
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::Acquire)
    }
}
