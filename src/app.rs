//! Daemon orchestration: singleton guard, startup evidence, window/worker
//! lifetime and orderly shutdown.

use std::ptr;
use std::sync::atomic::Ordering;
use std::thread;

use crate::audio::SilentKeepalive;
use crate::bluetooth::BthApi;
use crate::btlog;
use crate::config;
use crate::output::HealthOut;
use crate::pnp::devnode::is_user_admin;
use crate::pnp::recovery;
use crate::state::SharedState;
use crate::sys::kernel32::{self, ERROR_ALREADY_EXISTS};
use crate::sys::INVALID_HANDLE_VALUE;
use crate::util;
use crate::window::MessageWindow;

pub fn run_daemon(target_mac: u64, audio_override: Option<String>) {
    let mac_str = crate::mac::format_mac(target_mac);

    // Singleton: two daemons racing the same radio fight over the link, so a
    // second instance refuses to start. The handle is intentionally never
    // closed: it dies with the process, which is the mutex lifetime we want.
    // Fail-open on creation errors; only a PROVEN duplicate exits.
    {
        let name = util::wide(config::SINGLETON_MUTEX);
        let mtx = unsafe { kernel32::CreateMutexW(ptr::null_mut(), 0, name.as_ptr()) };
        if mtx.is_null() || mtx == INVALID_HANDLE_VALUE {
            btlog!(
                "singleton mutex unavailable (err=0x{:x}) -- running WITHOUT instance protection",
                unsafe { kernel32::GetLastError() }
            );
        } else if unsafe { kernel32::GetLastError() } == ERROR_ALREADY_EXISTS {
            crate::exit_err(
                "another bluetooth_force.exe daemon is already running (singleton mutex Global\\BluetoothForceDaemon is held) -- refusing a second instance",
            );
        }
    }

    // First evidence line, after the durable log is open so it lands in btf.log.
    crate::log::init();
    let exe = util::module_file_name().unwrap_or_else(|| "?".to_string());
    btlog!(
        "start: build=rust3.0 mac={mac_str} exe={exe} admin={} log={}",
        is_user_admin(),
        if crate::log::is_active() { config::LOG_NAME } else { "NONE (file log unavailable)" }
    );
    btlog!(
        "policy: automatic rungs are radio repair -> native connect (BluetoothSetServiceState) -> page-scan toggle -> earbud-devnode restart -> usb-cycle -> hub port power-cycle. ToothTray is no longer required. The radio is never left un-started, a deliberate user disable is respected, and the usb-cycle and hub-port-cycle rungs mute themselves after two attempts that leave the radio not started / the link down."
    );

    // A persistent disable outlives the process that made it, so the very first
    // thing a new run does is account for one.
    if recovery::journal_present() {
        btlog!("startup: a pending disable journal was found -- repairing the radio BEFORE the ladder starts");
        let out = HealthOut::debug_only("startup recovery");
        let _ = recovery::recover_disabled_radio(&out, false, false);
    }
    if recovery::freeze_present() {
        btlog!("escalation FROZEN at startup by btf_freeze.txt — earbud-restart and usb-cycle are disabled; delete that file to re-enable");
    }

    let bth = match BthApi::load() {
        Ok(b) => b,
        Err(e) => crate::exit_err(e),
    };
    let resume_event = unsafe { kernel32::CreateEventW(ptr::null_mut(), 0, 0, ptr::null()) };
    if resume_event.is_null() {
        crate::exit_err("CreateEventW failed");
    }

    let keepalive = SilentKeepalive::new(audio_override);
    let mut state = Box::new(SharedState::new(target_mac, resume_event, bth, keepalive));

    // Create the window BEFORE spawning the worker: any failure here exits
    // while no worker/keepalive is running.
    let window = match MessageWindow::create(resume_event) {
        Ok(w) => w,
        Err(e) => crate::exit_err(e),
    };

    let state_ptr = state.as_mut() as *mut SharedState as usize;
    let worker = match thread::Builder::new().name("poll".into()).spawn(move || unsafe {
        crate::worker::run(&mut *(state_ptr as *mut SharedState))
    }) {
        Ok(h) => h,
        Err(e) => crate::exit_err(&format!("worker thread spawn failed: {e}")),
    };

    window.run_loop();

    // Orderly shutdown: stop the worker first, then the keepalive (the worker
    // is the sole owner of keepalive start/stop).
    state.running.store(false, Ordering::Release);
    unsafe { kernel32::SetEvent(resume_event) };
    let _ = worker.join();
    state.keepalive.stop();
    drop(window);
}
