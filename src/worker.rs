//! The poll worker: finds the target earbuds on every radio, starts the
//! keepalive when connected, and drives the recovery ladder when not.

use std::ptr;

use crate::bluetooth::{default_search_params, empty_device_info, BthApi};
use crate::btlog;
use crate::config::*;
use crate::connect::{self, ConnectOutcome};
use crate::ladder::*;
use crate::output::HealthOut;
use crate::pnp::cycle::usb_cycle_radio;
use crate::pnp::devnode::is_user_admin;
use crate::pnp::hub::hub_port_cycle_radio;
use crate::pnp::recovery::{self, recover_disabled_radio};
use crate::pnp::restart::restart_earbud_devnodes;
use crate::state::SharedState;
use crate::sys::bluetooth::{
    BLUETOOTH_DEVICE_INFO, BLUETOOTH_FIND_RADIO_PARAMS,
};
use crate::sys::kernel32::{self, PERFORMANCE_INFORMATION, WAIT_FAILED, WAIT_OBJECT_0, WAIT_TIMEOUT};
use crate::sys::{HANDLE, INVALID_HANDLE_VALUE};
use crate::util::{now_ms, utf16_field};

/// Main worker loop. Runs until `state.running` is cleared.
pub fn run(state: &mut SharedState) {
    let mut poll_count: u32 = 0;
    while state.is_running() {
        let wait = unsafe { kernel32::WaitForSingleObject(state.resume_event, POLL_INTERVAL_MS) };
        match wait {
            WAIT_OBJECT_0 => {
                if !state.is_running() {
                    break;
                }
                unsafe { kernel32::Sleep(RESUME_DELAY_MS) };
                if !state.is_running() {
                    break;
                }
            }
            WAIT_TIMEOUT => {}
            WAIT_FAILED => {
                // A transient wait failure must NOT permanently kill polling.
                btlog!("WaitForSingleObject FAILED: 0x{:x}", unsafe { kernel32::GetLastError() });
                unsafe { kernel32::Sleep(POLL_INTERVAL_MS) };
                continue;
            }
            other => {
                btlog!("unexpected wait result=0x{other:x}");
                unsafe { kernel32::Sleep(POLL_INTERVAL_MS) };
                continue;
            }
        }

        if !state.is_running() {
            break;
        }

        sample_watchdog(state);
        poll_count += 1;
        perform_poll(state, poll_count);
    }
}

// ---------------------------------------------------------------------------
// Paged-pool watchdog
// ---------------------------------------------------------------------------

fn query_paged_pool_bytes() -> Option<u64> {
    let mut info = PERFORMANCE_INFORMATION::default();
    info.cb = std::mem::size_of::<PERFORMANCE_INFORMATION>() as u32;
    if unsafe { kernel32::K32GetPerformanceInfo(&mut info, info.cb) } == 0 {
        return None;
    }
    Some(info.KernelPaged as u64 * info.PageSize as u64)
}

fn sample_watchdog(state: &mut SharedState) {
    let Some(cur) = query_paged_pool_bytes() else {
        return;
    };
    if cur < state.pool_min_bytes {
        state.pool_min_bytes = cur;
    }
    let now = now_ms();

    if !state.watchdog_tripped {
        if watchdog_tripped(state.pool_min_bytes, cur, WATCHDOG_TRIP_BYTES) {
            state.watchdog_tripped = true;
            state.watchdog_tripped_ms = now;
            state.watchdog_last_log_ms = now;
            btlog!(
                "WATCHDOG TRIPPED: paged pool +{} MB over baseline — pausing keepalive/connects",
                (cur - state.pool_min_bytes) / (1024 * 1024)
            );
            state.keepalive.stop();
        }
        return;
    }

    if cur <= state.pool_min_bytes + WATCHDOG_CLEAR_BYTES {
        state.watchdog_tripped = false;
        btlog!("watchdog cleared: paged pool back near baseline");
        return;
    }

    if now - state.watchdog_tripped_ms >= WATCHDOG_FORCE_CLEAR_MS {
        state.watchdog_tripped = false;
        state.pool_min_bytes = cur;
        btlog!(
            "watchdog force-clear after timeout; re-baselining to {} MB and resuming",
            cur / (1024 * 1024)
        );
        return;
    }

    if now - state.watchdog_last_log_ms >= WATCHDOG_LOG_INTERVAL_MS {
        state.watchdog_last_log_ms = now;
        btlog!(
            "watchdog still tripped: paged pool {} MB (+{} MB over baseline)",
            cur / (1024 * 1024),
            (cur - state.pool_min_bytes) / (1024 * 1024)
        );
    }
}

// ---------------------------------------------------------------------------
// Kill switch
// ---------------------------------------------------------------------------

/// Cached freeze state, re-read every `FREEZE_RECHECK_MS` so the switch works on
/// a running daemon without hitting the filesystem on every poll.
fn escalation_frozen(state: &mut SharedState, now: i64) -> bool {
    if state.freeze_checked_ms == 0 || now - state.freeze_checked_ms >= FREEZE_RECHECK_MS {
        state.freeze_checked_ms = now;
        let frozen_now = recovery::freeze_present();
        if frozen_now != state.escalation_frozen {
            state.escalation_frozen = frozen_now;
            if frozen_now {
                btlog!("escalation FROZEN by btf_freeze.txt — earbud-restart and usb-cycle are disabled; connect and page-scan toggle keep working");
            } else {
                btlog!("escalation UNFROZEN (btf_freeze.txt is gone) — earbud-restart and usb-cycle are armed again");
            }
        }
    }
    state.escalation_frozen
}

// ---------------------------------------------------------------------------
// Radio RAII guards
// ---------------------------------------------------------------------------

// The guards hold a raw `*const BthApi` rather than a reference so they never
// keep a borrow of `state` alive across the ladder's mutable calls. The API
// outlives the whole poll (it lives in `SharedState`).
struct RadioFind {
    api: *const BthApi,
    handle: HANDLE,
}
impl Drop for RadioFind {
    fn drop(&mut self) {
        unsafe { (*self.api).close_radio_find(self.handle) };
    }
}

struct DeviceFind {
    api: *const BthApi,
    handle: HANDLE,
}
impl Drop for DeviceFind {
    fn drop(&mut self) {
        unsafe { (*self.api).close_device_find(self.handle) };
    }
}

struct OwnedHandle(HANDLE);
impl Drop for OwnedHandle {
    fn drop(&mut self) {
        if !self.0.is_null() && self.0 != INVALID_HANDLE_VALUE {
            unsafe { kernel32::CloseHandle(self.0) };
        }
    }
}

// ---------------------------------------------------------------------------
// Poll
// ---------------------------------------------------------------------------

fn perform_poll(state: &mut SharedState, _poll_count: u32) {
    let api: *const BthApi = &state.bth;

    let mut radio_params = BLUETOOTH_FIND_RADIO_PARAMS {
        dwSize: std::mem::size_of::<BLUETOOTH_FIND_RADIO_PARAMS>() as u32,
    };
    let mut radio_handle: HANDLE = ptr::null_mut();
    let radio_find = unsafe { state.bth.first_radio(&mut radio_params, &mut radio_handle) };
    if radio_find.is_null() {
        return;
    }
    let _radio_find_guard = RadioFind { api, handle: radio_find };

    loop {
        if radio_handle.is_null() {
            break;
        }
        {
            let _radio_guard = OwnedHandle(radio_handle);
            let mut search = default_search_params(radio_handle);
            let mut device_info = empty_device_info();
            let device_find = unsafe { state.bth.first_device(&mut search, &mut device_info) };
            if !device_find.is_null() {
                let _device_guard = DeviceFind { api, handle: device_find };
                let mut found = false;
                loop {
                    if device_info.Address.ullRemote == state.target_mac {
                        found = true;
                        break;
                    }
                    device_info = empty_device_info();
                    if !unsafe { state.bth.next_device(device_find, &mut device_info) } {
                        break;
                    }
                }
                if found {
                    handle_found(state, radio_handle, &device_info);
                    return;
                }
            }
        }

        let mut next: HANDLE = ptr::null_mut();
        if !unsafe { state.bth.next_radio(radio_find, &mut next) } {
            break;
        }
        radio_handle = next;
    }
}

fn handle_found(state: &mut SharedState, radio_handle: HANDLE, device_info: &BLUETOOTH_DEVICE_INFO) {
    let name = utf16_field(&device_info.szName);

    // Route through the pure decision function so tested logic and production
    // logic cannot drift.
    let mut action = decide_poll_action(true, device_info.fConnected);

    // H4 audio-dead single-shot: BT says connected but the render sessions keep
    // dying (A2DP torn down under a live control link). Route ONE poll through
    // the ladder so the sensor is rebuilt and the rungs can engage.
    if action == PollAction::StartKeepalive
        && !state.watchdog_tripped
        && state.keepalive.is_running()
        && state.keepalive.consec_fails() >= KEEPALIVE_DEAD_SESSIONS
    {
        btlog!("audio-dead: render sessions failing on a connected link -- one poll through the ladder");
        action = PollAction::StopAndConnect;
    }

    match action {
        PollAction::None => {}
        PollAction::StartKeepalive => on_connected(state, &name),
        PollAction::StopAndConnect => on_disconnected(state, radio_handle, device_info, &name),
    }
}

fn on_connected(state: &mut SharedState, name: &str) {
    state.connect_fails = 0;
    state.next_connect_ms = 0;

    // Flap hysteresis: a lone connected poll is a blip, not a cure.
    state.link_stable_polls = state.link_stable_polls.saturating_add(1);
    if state.link_stable_polls >= LINK_STABLE_POLLS_TO_CLOSE {
        state.r1_armed_ms = 0;
        state.r1_reset_in_episode = false;
        state.r2_cycled_in_episode = false;
        state.r3_restarts_in_episode = 0;
        state.r3_last_restart_ms = 0;
        state.r3_force_after_ms = 0;
        state.r3_last_complete_ms = 0;
        state.flaps_in_episode = 0;
        state.peer_absent_streak = 0;
        state.peer_absent_logged = false;
        state.recovery_fails = 0;
        state.recovery_quiet_logged = false;
    } else if state.r1_armed_ms != 0 {
        state.flaps_in_episode = state.flaps_in_episode.saturating_add(1);
        btlog!(
            "flap {}/{}: lone connected poll inside an armed episode -- episode stays armed",
            state.flaps_in_episode,
            FLAP_FORCE_R1_AFTER
        );
    }

    if !state.watchdog_tripped {
        state.keepalive.start(name);
    }
}

fn on_disconnected(
    state: &mut SharedState,
    radio_handle: HANDLE,
    device_info: &BLUETOOTH_DEVICE_INFO,
    _name: &str,
) {
    state.keepalive.stop();
    state.link_stable_polls = 0;
    if state.watchdog_tripped {
        return;
    }

    let now = now_ms();

    // Elevation comeback: the token check costs no PnP, so a 0 → 1 transition
    // resets the backoff outright.
    if !is_user_admin() {
        state.recovery_saw_unelevated = true;
    } else if state.recovery_saw_unelevated {
        state.recovery_saw_unelevated = false;
        state.recovery_fails = 0;
        state.recovery_quiet_logged = false;
    }

    // RUNG 0: repair before escalate. Deliberately NOT capped by a breaker.
    let rec_delay = recovery_retry_delay_ms(state.recovery_fails);
    if should_retry_recovery(now, state.recovery_last_ms, rec_delay) {
        state.recovery_last_ms = now;
        let journal = recovery::journal_present();
        if journal && !state.recovery_logged {
            state.recovery_logged = true;
            btlog!(
                "rung recovery: a pending disable was left behind ({}) -- every escalation rung is BLOCKED until the radio is healthy again",
                RECOVERY_JOURNAL_NAME
            );
        }
        let out = HealthOut::debug_only("rung recovery");
        let res = recover_disabled_radio(&out, false, state.recovery_quiet_logged);
        let repaired = res.repaired;
        // Replug detector.
        if res.present == 0 {
            state.recovery_saw_absent = true;
        } else if state.recovery_saw_absent {
            state.recovery_saw_absent = false;
            state.recovery_fails = 0;
            state.recovery_quiet_logged = false;
        }
        if journal || repaired {
            state.recovery_attempts = state.recovery_attempts.saturating_add(1);
        }
        state.recovery_armed = recovery::journal_present();
        if repaired || !state.recovery_armed {
            state.recovery_fails = 0;
            state.recovery_quiet_logged = false;
        } else {
            state.recovery_fails = state.recovery_fails.saturating_add(1);
            if state.recovery_fails == RECOVERY_QUIET_AFTER && !state.recovery_quiet_logged {
                state.recovery_quiet_logged = true;
                btlog!(
                    "rung recovery: {} consecutive failed repairs -- REBOOT REQUIRED likely, going quiet (retry every 1 min). Reboot Windows or run: bluetooth_force.exe --recover",
                    state.recovery_fails
                );
            }
        }
        if !state.recovery_armed && state.recovery_logged {
            btlog!(
                "rung recovery: cleared after {} attempt(s) -- the ladder is armed again",
                state.recovery_attempts
            );
            state.recovery_attempts = 0;
            state.recovery_logged = false;
        }
        if repaired {
            state.connect_fails = 0;
            state.next_connect_ms = now_ms() + R2_POST_CYCLE_RECONNECT_MS;
            state.peer_absent_streak = 0;
            state.peer_absent_logged = false;
            return;
        }
    }
    if recovery_blocks_escalation(state.recovery_armed) {
        return;
    }

    // R1 — page-scan toggle.
    if state.r1_armed_ms == 0 {
        state.r1_armed_ms = now;
    }
    if state.flaps_in_episode >= FLAP_FORCE_R1_AFTER && state.r1_armed_ms > now - R1_ARM_MS {
        state.r1_armed_ms = now - R1_ARM_MS;
        btlog!("flap storm ({} blips): forcing the page-scan rung now", state.flaps_in_episode);
    }
    if radio_reset_rung_dead(state.r1_rejects) {
        if !state.r1_dead_logged {
            state.r1_dead_logged = true;
            btlog!(
                "rung page-scan: MUTED for this run after {} consecutive rejections -- escalation goes straight to the PnP rungs",
                state.r1_rejects
            );
        }
        state.r1_reset_in_episode = true;
    } else if should_radio_reset(state.r1_armed_ms, now, state.r1_last_reset_ms)
        && state.r1_breaker.allow(now)
    {
        state.r1_last_reset_ms = now;
        state.r1_reset_in_episode = true;
        if radio_reset(&state.bth, radio_handle) {
            state.r1_rejects = 0;
            state.connect_fails = 0;
            state.next_connect_ms = now + R1_POST_RESET_RECONNECT_MS;
            return;
        }
        state.r1_rejects = state.r1_rejects.saturating_add(1);
        btlog!("R1: reset attempt failed ({} in a row); will retry after cooldown", state.r1_rejects);
    }

    // R3 — earbud-devnode restart (cheaper than the usb-cycle).
    if !escalation_frozen(state, now)
        && should_earbud_restart(
            state.r1_armed_ms,
            now,
            state.r3_last_restart_ms,
            state.r3_restarts_in_episode,
            state.r3_force_after_ms,
        )
        && state.r3_breaker.allow(now)
    {
        state.r3_force_after_ms = 0;
        state.r3_last_restart_ms = now;
        state.r3_restarts_in_episode = state.r3_restarts_in_episode.saturating_add(1);
        if restart_earbud_devnodes(state) {
            let after = now_ms();
            state.connect_fails = 0;
            state.next_connect_ms = after + R3_POST_RESTART_RECONNECT_MS;
            state.r3_last_complete_ms = after;
            return;
        }
        btlog!("R3: earbud-devnode restart did not restart any node; falling through to the next rung");
    }

    // R2 — usb-cycle escalation.
    if usb_cycle_rung_dead(state.r2_fails) {
        if !state.r2_dead_logged {
            state.r2_dead_logged = true;
            btlog!(
                "rung usb-cycle: MUTED for this run after {} attempt(s) that left the radio not started -- this dongle refuses to be cycled, the earbud-devnode rung stays in charge",
                state.r2_fails
            );
        }
    } else if !escalation_frozen(state, now)
        && !peer_absent_freeze(state.peer_absent_streak)
        && should_usb_cycle(
            state.r1_armed_ms,
            now,
            state.r1_reset_in_episode,
            state.r2_last_cycle_ms,
        )
        && usb_cycle_quiet_after_restart(now, state.r3_last_complete_ms)
        && state.r2_breaker.allow(now)
    {
        state.r2_last_cycle_ms = now;
        if usb_cycle_radio(state) {
            state.connect_fails = 0;
            let after = now_ms();
            state.next_connect_ms = after + R2_POST_CYCLE_RECONNECT_MS;
            state.r3_force_after_ms = after + R3_POST_CYCLE_DELAY_MS;
            state.r3_restarts_in_episode = 0;
            state.r3_last_restart_ms = 0;
            state.r2_fails = 0;
            state.r2_cycled_in_episode = true;
            return;
        }
        state.r2_fails = state.r2_fails.saturating_add(1);
    }

    // R4 — hub port power-cycle.
    if hub_port_cycle_rung_dead(state.r4_fails) {
        if !state.r4_dead_logged {
            state.r4_dead_logged = true;
            btlog!(
                "rung hub-port-cycle: MUTED for this run after {} port cycle(s) that left the link down -- the wedge lives deeper than VBUS",
                state.r4_fails
            );
        }
    } else if !escalation_frozen(state, now)
        && !peer_absent_freeze(state.peer_absent_streak)
        && should_hub_port_cycle(
            state.r1_armed_ms,
            now,
            state.r2_cycled_in_episode,
            state.r4_last_ms,
        )
        && state.r4_breaker.allow(now)
    {
        state.r4_last_ms = now;
        if hub_port_cycle_radio(state) {
            state.connect_fails = 0;
            let after = now_ms();
            state.next_connect_ms = after + R4_POST_CYCLE_RECONNECT_MS;
            state.r3_force_after_ms = after + R3_POST_CYCLE_DELAY_MS;
            state.r3_restarts_in_episode = 0;
            state.r3_last_restart_ms = 0;
            state.r4_fails = 0;
            return;
        }
        state.r4_fails = state.r4_fails.saturating_add(1);
    }

    if now < state.next_connect_ms {
        return; // L3 backoff window
    }
    if !state.connect_breaker.allow(now) {
        btlog!("connect circuit OPEN — cooling down");
        return;
    }

    match connect::connect(&state.bth, radio_handle, device_info) {
        ConnectOutcome::Connected => {
            state.connect_fails = 0;
            state.next_connect_ms = 0;
            state.peer_absent_streak = 0;
            state.peer_absent_logged = false;
        }
        ConnectOutcome::NotFound => {
            state.peer_absent_streak = state.peer_absent_streak.saturating_add(1);
            state.connect_fails = state.connect_fails.saturating_add(1);
            state.next_connect_ms = now
                + backoff_ms(state.connect_fails, CONNECT_BACKOFF_BASE_MS, CONNECT_BACKOFF_CAP_MS) as i64;
            if peer_absent_freeze(state.peer_absent_streak) && !state.peer_absent_logged {
                state.peer_absent_logged = true;
                btlog!(
                    "peer absent x{} (no audio profile accepted) -- R2/R4 frozen until the peer returns or the radio proves otherwise; R1/R3 keep running",
                    state.peer_absent_streak
                );
            }
        }
        ConnectOutcome::Failed => {
            state.peer_absent_streak = 0;
            state.peer_absent_logged = false;
            state.connect_fails = state.connect_fails.saturating_add(1);
            state.next_connect_ms = now
                + backoff_ms(state.connect_fails, CONNECT_BACKOFF_BASE_MS, CONNECT_BACKOFF_CAP_MS) as i64;
        }
    }
}

/// R1 — programmatic radio reset ("software re-plug").
///
/// Disabling forces the stack to rewrite the controller's scan-enable state on
/// re-enable, which re-arms page scan. A failed re-enable would leave the
/// adapter non-connectable, so that step is retried hard.
fn radio_reset(api: &BthApi, hradio: HANDLE) -> bool {
    let Some(enable_incoming) = api.enable_incoming else {
        btlog!("R1: BluetoothEnableIncomingConnections unavailable, reset skipped");
        return false;
    };
    btlog!("R1: radio reset begin (page-scan toggle)");
    if unsafe { enable_incoming(hradio, 0) } == 0 {
        btlog!("R1: disable failed 0x{:x}, radio left as-is", unsafe { kernel32::GetLastError() });
        return false;
    }
    unsafe { kernel32::Sleep(R1_TOGGLE_QUIET_MS) };

    let mut reenabled = false;
    let mut attempt = 0u32;
    while attempt < R1_REENABLE_ATTEMPTS {
        if attempt > 0 {
            unsafe { kernel32::Sleep(R1_REENABLE_RETRY_MS) };
        }
        if unsafe { enable_incoming(hradio, 1) } != 0 {
            reenabled = true;
            break;
        }
        btlog!(
            "R1: re-enable attempt {}/{} failed 0x{:x}",
            attempt + 1,
            R1_REENABLE_ATTEMPTS,
            unsafe { kernel32::GetLastError() }
        );
        attempt += 1;
    }
    if !reenabled {
        btlog!("R1: RE-ENABLE FAILED after retries — adapter may stay non-connectable until next reset or replug");
        return false;
    }
    btlog!("R1: radio reset complete");
    true
}
