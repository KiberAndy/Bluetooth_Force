//! `--recover`: manual repair button.
//!
//! Unlike the automatic rung this one does NOT require the journal: it exists
//! for a machine that is already stuck, including one left disabled by an older
//! build that had no journal at all.
//! Exit codes: 0 = something enabled, 1 = nothing to do / unfixable, 2 = not elevated.

use crate::output::HealthOut;
use crate::pnp::devnode::is_user_admin;
use crate::pnp::recovery::recover_disabled_radio;

pub fn run(_args: &[String]) {
    crate::log::init();
    let out = HealthOut::debug_only("recover");
    out.line_fmt(format!("build=rust3.0 admin={}", is_user_admin()));
    if !is_user_admin() {
        out.line("ABORTED: enabling a devnode requires elevation -- start PowerShell as administrator and run this again");
        std::process::exit(2);
    }

    let ok = recover_disabled_radio(&out, true, false).repaired;
    if ok {
        out.line("result: the radio was disabled and is now enabled -- Bluetooth should be back in Device Manager");
    } else {
        out.line("result: nothing was enabled -- either the radio was already fine, or the dongle is unplugged, or the lines above say why it refused");
    }
    std::process::exit(if ok { 0 } else { 1 });
}
