//! R3 — earbud audio-devnode restart.
//!
//! Restarts only the earbuds' A2DP/AVRCP function devnodes, never the device
//! container and never a service: restarting the container makes Windows
//! re-enumerate the device instead of connecting it, and stopping a Bluetooth
//! service is the exact kernel-crash path this tool must not enter.

use crate::config::*;
use crate::output::HealthOut;
use crate::pnp::devnode::*;
use crate::state::SharedState;
use crate::sys::cfgmgr32::{CM_Disable_DevNode, CR_SUCCESS};
use crate::sys::kernel32;
use crate::sys::setupapi::*;
use crate::sys::HDEVINFO;
use crate::btlog;

/// Auto-ladder entry for R3.
pub fn restart_earbud_devnodes(state: &mut SharedState) -> bool {
    if !is_user_admin() {
        if !state.r3_admin_skip_logged {
            state.r3_admin_skip_logged = true;
            btlog!("rung earbud-restart: skipped (admin required) — run from an elevated shell or diagnose.ps1");
        }
        return false;
    }
    let out = HealthOut::debug_only("rung earbud-restart");
    earbud_restart_once(state.target_mac, &out)
}

/// The R3 core, shared by the auto-ladder rung and `--restart-earbuds`.
///
/// Matching devnodes are SNAPSHOTTED before anything is touched: a restart
/// re-enumerates the node, and iterating a SetupAPI list while mutating it is
/// how you end up acting on a stale index.
pub fn earbud_restart_once(target_mac: u64, out: &HealthOut) -> bool {
    let mac = crate::mac::mac_hex12(target_mac);
    let mac_str = std::str::from_utf8(&mac).unwrap_or("?");
    out.line_fmt(format!("begin (mac={mac_str})"));

    let devs = match class_devs(None, Some(&ENUMERATOR_BTHENUM[..]), DIGCF_PRESENT | DIGCF_ALLCLASSES) {
        Ok(d) => d,
        Err(err) => {
            out.line_fmt(format!("SetupDiGetClassDevsW(BTHENUM) failed 0x{err:x}"));
            return false;
        }
    };

    let mut nodes: Vec<(SP_DEVINFO_DATA, InstanceId, bool)> = Vec::new();
    let mut skipped_non_audio = 0u32;
    let mut scanned = 0u32;
    let mut index = 0u32;
    while (nodes.len() as u32) < R3_MAX_NODES {
        let mut info = sp_devinfo_data();
        if unsafe { SetupDiEnumDeviceInfo(devs.handle(), index, &mut info) } == 0 {
            break;
        }
        scanned += 1;
        let Some(id) = device_instance_id(devs.handle(), &mut info) else {
            index += 1;
            continue;
        };
        if !crate::mac::id_contains_mac(id.as_str(), &mac) {
            index += 1;
            continue;
        }
        if !crate::mac::is_earbud_audio_node(id.as_str()) {
            skipped_non_audio += 1;
            out.line_fmt(format!("skip (non-audio, left untouched) {}", id.as_str()));
            index += 1;
            continue;
        }
        // Single status read (timeout 0 = one probe, no wait).
        let was_started = wait_devnode_started(info.DevInst, 0);
        nodes.push((info, id, was_started));
        index += 1;
    }

    if nodes.is_empty() {
        out.line_fmt(format!(
            "no present BTHENUM AUDIO devnode carries mac {mac_str} (scanned {scanned}, skipped {skipped_non_audio} non-audio) -- nothing to restart"
        ));
        return false;
    }

    let total = nodes.len() as u32;
    out.line_fmt(format!(
        "{total} earbud AUDIO devnode(s) to restart (scanned {scanned} BTHENUM nodes, {skipped_non_audio} non-audio left untouched)"
    ));

    let mut restarted = 0u32;
    for (mut info, id, was_started) in nodes {
        out.line_fmt(format!("node {}", id.as_str()));
        if restart_one_devnode(devs.handle(), &mut info, id.as_str(), was_started, out) {
            restarted += 1;
        }
    }

    out.line_fmt(format!("complete ({restarted}/{total} node(s) restarted)"));
    restarted > 0
}

/// Restart ONE earbud function devnode.
///
/// Path A is `pnputil /restart-device`: one atomic PnP restart with no window in
/// which the node is left disabled. Path B is the in-process fallback: verified
/// disable → quiet → verified enable, aborting WITHOUT enabling if the disable
/// did not take effect.
pub fn restart_one_devnode(
    devs: HDEVINFO,
    info: &mut SP_DEVINFO_DATA,
    id: &str,
    was_started: bool,
    out: &HealthOut,
) -> bool {
    // Path A.
    if let Some(pnputil) = crate::util::system_path_of("pnputil.exe") {
        let cmd = format!("\"{pnputil}\" /restart-device {}", crate::util::quote_arg(id));
        match run_hidden_wait(&cmd, R3_PNPUTIL_TIMEOUT_MS) {
            None => out.line_fmt(format!(
                "  pnputil /restart-device did not complete in {} ms — falling back to disable/enable",
                R3_PNPUTIL_TIMEOUT_MS
            )),
            Some(exit_code) => {
                if exit_code == 0 {
                    if wait_devnode_started(info.DevInst, R3_VERIFY_MS) {
                        out.line("  restarted via pnputil (verified STARTED)");
                        return true;
                    }
                    // A node that was NOT started before the restart (a profile
                    // that only starts while the link is up) cannot be judged by
                    // DN_STARTED afterwards.
                    if !was_started {
                        out.line("  restarted via pnputil (node was not STARTED before either -- accepted)");
                        return true;
                    }
                }
                out.line_fmt(format!(
                    "  pnputil exit {exit_code} but node not verified STARTED — falling back to disable/enable"
                ));
            }
        }
    }

    // Path B.
    let mut disabled = usb_prop_change(devs, info, DICS_DISABLE)
        && wait_devnode_disabled(info.DevInst, R3_VERIFY_MS);
    if !disabled {
        let dif_err = unsafe { kernel32::GetLastError() };
        if unsafe { CM_Disable_DevNode(info.DevInst, 0) } == CR_SUCCESS {
            disabled = wait_devnode_disabled(info.DevInst, R3_VERIFY_MS);
        }
        if !disabled {
            out.line_fmt(format!(
                "  disable did not take effect (DIF 0x{dif_err:x}) — node left exactly as it was"
            ));
            return false;
        }
    }
    unsafe { kernel32::Sleep(R3_QUIET_MS) };

    if enable_devnode_verified(devs, info, out) {
        out.line("  restarted via verified disable/enable");
        return true;
    }

    out.line("  ENABLE FAILED — this node is left DISABLED. Recovery, elevated PowerShell:");
    out.line_fmt(format!("    Enable-PnpDevice -InstanceId '{id}' -Confirm:$false"));
    false
}
