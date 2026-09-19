//! bluetooth_force — keep paired Bluetooth earbuds connected.
//!
//! A GUI-subsystem daemon that watches for one paired device, streams an
//! inaudible keepalive once it is linked, and — when it is not — drives a
//! verified recovery ladder. The reconnect step is native
//! (`BluetoothSetServiceState`); the old `ToothTray.exe` dependency is gone.

#![cfg_attr(not(test), windows_subsystem = "windows")]
#![allow(non_snake_case)]

mod app;
mod audio;
mod bluetooth;
mod config;
mod connect;
mod health;
mod ladder;
mod log;
mod mac;
mod modes;
mod output;
mod pnp;
mod state;
mod sys;
mod util;
mod window;
mod worker;

fn main() {
    // Harden the whole process against DLL preloading/hijacking: resolve DLLs
    // only from System32 by default.
    unsafe { sys::kernel32::SetDefaultDllDirectories(sys::LOAD_LIBRARY_SEARCH_SYSTEM32) };

    let args: Vec<String> = std::env::args().collect();
    let Some(arg1) = args.get(1) else {
        exit_err(config::USAGE);
    };

    match arg1.as_str() {
        "--health" => {
            health::run(&args[2..]);
            return;
        }
        "--cycle" => {
            modes::cycle::run(&args[2..]);
            return;
        }
        "--restart-earbuds" => {
            modes::restart_earbuds::run(&args[2..]);
            return;
        }
        "--recover" => {
            modes::recover::run(&args[2..]);
            return;
        }
        "--probe-hubs" => {
            modes::probe_hubs::run(&args[2..]);
            return;
        }
        _ => {}
    }

    let target_mac = match mac::parse_mac(arg1) {
        Ok(m) => m,
        Err(e) => exit_err(&e.to_string()),
    };
    let audio_override = args.get(2).filter(|s| !s.is_empty()).cloned();
    app::run_daemon(target_mac, audio_override);
}

/// Print a fatal message and exit. Diverges so it can stand in for `else`
/// branches and `Result` failures.
pub(crate) fn exit_err(msg: &str) -> ! {
    log::write_line(msg);
    unsafe { sys::kernel32::ExitProcess(1) }
}
