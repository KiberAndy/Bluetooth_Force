//! `--restart-earbuds MAC [report-path]`: one-shot earbud-devnode restart.
//!
//! Runs the SAME core the auto-ladder runs, so what the user verifies by hand
//! during a wedge is exactly what fires automatically later.
//! Exit codes: 0 = at least one node restarted, 1 = nothing restarted, 2 = not elevated.

use crate::mac::parse_mac;
use crate::output::HealthOut;
use crate::pnp::devnode::is_user_admin;
use crate::pnp::restart::earbud_restart_once;
use crate::util::now_ms;

pub fn run(args: &[String]) {
    let t_start = now_ms();

    let Some(mac_arg) = args.first() else {
        crate::exit_err("Usage: bluetooth_force.exe --restart-earbuds AA:BB:CC:DD:EE:FF [report-path]");
    };
    let target_mac = match parse_mac(mac_arg) {
        Ok(m) => m,
        Err(e) => crate::exit_err(&e.to_string()),
    };

    let out_path = args
        .get(1)
        .filter(|s| !s.is_empty())
        .cloned()
        .unwrap_or_else(|| "btf_restart_earbuds_report.txt".to_string());

    let out = HealthOut::to_file("restart-earbuds", &out_path);
    out.line_fmt(format!(
        "build=rust3.0 admin={} mac={mac_arg} report={out_path}",
        is_user_admin()
    ));
    if !is_user_admin() {
        out.line("ABORTED: admin required for devnode restart — run from an elevated shell");
        std::process::exit(2);
    }

    let ok = earbud_restart_once(target_mac, &out);
    if ok {
        out.line_fmt(format!("result: restarted ({} ms) — watch the earbuds link within ~10 s", now_ms() - t_start));
    } else {
        out.line_fmt(format!(
            "result: NOTHING RESTARTED ({} ms) — read the node lines above; if none were listed the earbuds have no present function devnodes right now (open the case first)",
            now_ms() - t_start
        ));
    }
    std::process::exit(if ok { 0 } else { 1 });
}
