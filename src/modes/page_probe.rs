//! `--page-probe <MAC> [out-path]`: transport discriminator for Winsock paging.
//!
//! Tries the same peer over three transports (L2CAP direct-PSM, L2CAP via the
//! stack's own SDP lookup, RFCOMM via Hands-Free UUID) and reports each
//! verdict. Run while the link is UP: if a transport fails with the peer
//! connected, that transport is blocked locally, not the radio.

use crate::mac;
use crate::output::HealthOut;
use crate::page::{self, PageResult};
use crate::pnp::devnode::is_user_admin;

pub fn run(args: &[String]) {
    let Some(mac_arg) = args.first().filter(|s| !s.is_empty()) else {
        crate::exit_err("--page-probe <MAC> [out-path]");
    };
    let addr = match mac::parse_mac(mac_arg) {
        Ok(m) => m,
        Err(e) => crate::exit_err(&e.to_string()),
    };
    let out_path = args
        .get(1)
        .filter(|s| !s.is_empty())
        .cloned()
        .unwrap_or_else(|| "btf_page_probe.txt".to_string());

    let out = HealthOut::to_file("page-probe", &out_path);
    out.line_fmt(format!("build=rust3.0 admin={} target={mac_arg}", is_user_admin()));
    for (name, outcome, err, stage) in page::probe_transports(addr) {
        let verdict = match outcome {
            PageResult::Attempted => "Attempted (page went out)".to_string(),
            PageResult::Unreachable => "Unreachable (peer did not answer)".to_string(),
            PageResult::Failed => format!("Failed ({stage} error {err})"),
        };
        out.line_fmt(format!("transport {name}: {verdict}"));
    }
    // One-shot: a successful page has no episode to hold it, so the socket
    // is closed immediately (the daemon path keeps it via `close_held`).
    let (daemon_outcome, daemon_held) = page::page_hold(addr);
    if let Some(s) = daemon_held {
        page::close_held(s);
    }
    let verdict = match daemon_outcome {
        PageResult::Attempted => "Attempted (page went out)",
        PageResult::Unreachable => "Unreachable (peer did not answer)",
        PageResult::Failed => "Failed (Winsock call failed, see btf.log for stage+error)",
    };
    out.line_fmt(format!("verdict: {verdict}"));
}
