//! `--cycle`: one-shot software replug of the CSR radio.
//!
//! Exit codes for scripting: 0 = cycled, 1 = failed, 2 = not admin.

use std::ptr;

use crate::bluetooth::BthApi;
use crate::output::HealthOut;
use crate::pnp::cycle::cycle_csr_radio_once;
use crate::pnp::devnode::is_user_admin;
use crate::sys::bluetooth::BLUETOOTH_FIND_RADIO_PARAMS;
use crate::sys::HANDLE;
use crate::util::now_ms;

pub fn run(args: &[String]) {
    let t_start = now_ms();
    let out_path = args
        .first()
        .filter(|s| !s.is_empty())
        .cloned()
        .unwrap_or_else(|| "btf_cycle_report.txt".to_string());

    let out = HealthOut::to_file("cycle", &out_path);
    out.line_fmt(format!(
        "build=rust3.0 admin={} report={out_path}",
        is_user_admin()
    ));
    if !is_user_admin() {
        out.line("ABORTED: admin required for device disable/enable — run from an elevated shell");
        std::process::exit(2);
    }

    let ok = cycle_csr_radio_once(&out);

    // Best-effort post-probe: is the radio back on the stack after the re-init?
    match BthApi::load() {
        Ok(api) => {
            let mut params = BLUETOOTH_FIND_RADIO_PARAMS {
                dwSize: std::mem::size_of::<BLUETOOTH_FIND_RADIO_PARAMS>() as u32,
            };
            let mut hradio: HANDLE = ptr::null_mut();
            let t0 = now_ms();
            let find = unsafe { api.first_radio(&mut params, &mut hradio) };
            if find.is_null() {
                out.line_fmt(format!(
                    "probe: stack sees NO radio yet (GetLastError=0x{:x}) — it may need a few more seconds",
                    unsafe { crate::sys::kernel32::GetLastError() }
                ));
            } else {
                let mut n = 0usize;
                while !hradio.is_null() && n < 8 {
                    n += 1;
                    let mut next: HANDLE = ptr::null_mut();
                    if !unsafe { api.next_radio(find, &mut next) } {
                        break;
                    }
                    hradio = next;
                }
                unsafe { api.close_radio_find(find) };
                out.line_fmt(format!("probe: stack sees {n} radio(s) ({} ms) after the re-init", now_ms() - t0));
            }
        }
        Err(_) => out.line("probe: bthprops unavailable, radio re-presence not verified"),
    }

    if ok {
        out.line_fmt(format!(
            "result: cycled ({} ms) — watch the earbuds reconnect within ~10-20 s, then run --health to confirm connected=true",
            now_ms() - t_start
        ));
    } else {
        out.line_fmt(format!(
            "result: FAILED ({} ms) — the dongle may be left DISABLED; follow the Recovery lines above (Enable-PnpDevice / Device Manager / different port)",
            now_ms() - t_start
        ));
    }
    std::process::exit(if ok { 0 } else { 1 });
}
