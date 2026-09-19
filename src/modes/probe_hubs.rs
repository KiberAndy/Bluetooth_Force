//! `--probe-hubs [out-path]`: read-only R4 validation probe.
//!
//! Lists every present USB hub with per-port connected VID/PID. Sends no
//! CYCLE_PORT, touches no devnode, writes no journal: safe to run while the
//! daemon is live.

use crate::output::HealthOut;
use crate::pnp::devnode::is_user_admin;
use crate::pnp::hub::{walk_hub_ports, HubWalkMode};

pub fn run(args: &[String]) {
    let out_path = args
        .first()
        .filter(|s| !s.is_empty())
        .cloned()
        .unwrap_or_else(|| "btf_probe_hubs.txt".to_string());

    let out = HealthOut::to_file("probe-hubs", &out_path);
    out.line_fmt(format!("build=rust3.0 admin={} report={out_path}", is_user_admin()));
    let w = walk_hub_ports(&out, HubWalkMode::Probe);
    out.line_fmt(format!("done: hubs={} ports={}", w.hubs, w.ports));
}
