//! R2 — usb-cycle ("hardware re-plug") via SetupAPI.
//!
//! Field evidence showed wedges that survive the R1 page-scan toggle and only
//! clear when the dongle loses power. This is that fix, software-driven:
//!  1. enumerate present devnodes on the USB enumerator, match the CSR VID/PID
//!  2. `pnputil /restart-device` (non-persistent) → verified `DN_STARTED`
//!  3. else verified disable → quiet → verified enable, with hard enable retries
//!
//! Success is a *verified* state (`DN_STARTED`, no problem code), never an API
//! receipt. The recovery journal is armed before anything that can stop the
//! radio, so a stranded devnode is always repaired on the next pass.

use crate::config::*;
use crate::output::HealthOut;
use crate::pnp::devnode::*;
use crate::pnp::recovery;
use crate::state::SharedState;
use crate::sys::cfgmgr32::{CM_Disable_DevNode, CM_Enable_DevNode, CR_SUCCESS};
use crate::sys::kernel32;
use crate::sys::setupapi::*;
use crate::btlog;

/// Auto-ladder entry for R2. Elevation is checked here so a non-elevated run
/// logs the reason once and then stays silent.
pub fn usb_cycle_radio(state: &mut SharedState) -> bool {
    if !is_user_admin() {
        if !state.r2_admin_skip_logged {
            state.r2_admin_skip_logged = true;
            btlog!("rung usb-cycle: skipped (admin required) — run from an elevated shell or diagnose.ps1");
        }
        return false;
    }
    let out = HealthOut::debug_only("rung usb-cycle");
    cycle_csr_radio_once(&out)
}

/// The usb-cycle core, shared by the auto-ladder rung and the `--cycle` mode.
pub fn cycle_csr_radio_once(out: &HealthOut) -> bool {
    out.line("begin");

    // Query by PnP enumerator "USB", NOT by GUID_DEVCLASS_USB: the radio's
    // devnode lives in the Bluetooth setup class, so a class-GUID query misses
    // it. ClassGuid=NULL REQUIRES DIGCF_ALLCLASSES.
    let devs = match class_devs(None, Some(&ENUMERATOR_USB[..]), DIGCF_PRESENT | DIGCF_ALLCLASSES) {
        Ok(d) => d,
        Err(err) => {
            out.line_fmt(format!("SetupDiGetClassDevsW failed 0x{err:x}"));
            return false;
        }
    };

    let mut scanned = 0u32;
    let mut target: Option<(SP_DEVINFO_DATA, InstanceId)> = None;
    let mut index = 0u32;
    while target.is_none() {
        let mut info = sp_devinfo_data();
        if unsafe { SetupDiEnumDeviceInfo(devs.handle(), index, &mut info) } == 0 {
            break;
        }
        scanned += 1;
        if let Some(id) = device_instance_id(devs.handle(), &mut info) {
            if crate::mac::is_csr_radio_instance_id(id.as_str()) {
                target = Some((info, id));
            }
        }
        index += 1;
    }

    let Some((mut target, id)) = target else {
        // scanned=0 => the QUERY is broken; scanned>0 without a match => the
        // MATCH is broken. The split is what field forensics needs.
        out.line_fmt(format!(
            "CSR radio USB\\VID_0A12&PID_0001 not present (scanned {scanned} devnodes on the USB enumerator), cycle aborted"
        ));
        return false;
    };

    out.line_fmt(format!("cycling {}...", id.as_str()));

    // Arm the journal BEFORE anything that can stop the radio.
    if !recovery::journal_arm(id.as_str()) {
        out.line_fmt(format!(
            "cannot write {RECOVERY_JOURNAL_NAME} next to the exe -- REFUSING to touch the dongle (an unrepairable radio is worse than a wedge)"
        ));
        return false;
    }

    // Non-persistent path first: it never writes the persistent disabled flag,
    // so if it works the radio cannot be stranded by a crash.
    if let Some(pnputil) = crate::util::system_path_of("pnputil.exe") {
        let cmd = format!("\"{pnputil}\" /restart-device \"{}\"", id.as_str());
        if let Some(code) = run_hidden_wait(&cmd, PNPUTIL_TIMEOUT_MS) {
            if code == 0 && wait_devnode_started(target.DevInst, R2_ENABLE_VERIFY_MS) {
                recovery::journal_disarm();
                out.line("complete (1 cycled via pnputil /restart-device, no persistent disable needed)");
                return true;
            }
            if code == PNPUTIL_REBOOT_REQUIRED {
                out.line(
                    "pnputil /restart-device returned 3010 (REBOOT REQUIRED) -- the radio is STOPPED. \
Not disabling anything; the repair rung takes over and keeps retrying. If it never comes back, \
reboot Windows or run: bluetooth_force.exe --recover",
                );
                return false; // journal deliberately LEFT ARMED
            }
            out.line_fmt(format!(
                "pnputil /restart-device did not verify (exit={code}) -- falling back to the journalled disable/enable pair"
            ));
        }
    }

    // Disable: primary path is DIF_PROPERTYCHANGE; fallback is CM_Disable_DevNode.
    if !usb_prop_change(devs.handle(), &mut target, DICS_DISABLE) {
        let dif_err = unsafe { kernel32::GetLastError() };
        if unsafe { CM_Disable_DevNode(target.DevInst, 0) } == CR_SUCCESS {
            out.line_fmt(format!("DIF disable failed 0x{dif_err:x}, disabled via CM_Disable_DevNode"));
        } else {
            out.line_fmt(format!("disable failed (DIF 0x{dif_err:x}, CM failed too)"));
            if devnode_started(target.DevInst) {
                recovery::journal_disarm();
                out.line("radio verified STARTED, dongle left as-is");
            } else {
                out.line_fmt(format!(
                    "radio is NOT started -- keeping {RECOVERY_JOURNAL_NAME} armed so the repair rung brings it back"
                ));
            }
            return false;
        }
    }

    // Verify the disable actually landed before enabling.
    if !wait_devnode_disabled(target.DevInst, R2_DISABLE_VERIFY_MS) {
        out.line_fmt(format!("disable not observed in {} ms — trying CM_Disable_DevNode", R2_DISABLE_VERIFY_MS));
        let cm_dis = unsafe { CM_Disable_DevNode(target.DevInst, 0) } == CR_SUCCESS;
        if !cm_dis || !wait_devnode_disabled(target.DevInst, R2_DISABLE_VERIFY_MS) {
            out.line("disable did not take effect — aborting WITHOUT enabling");
            if devnode_started(target.DevInst) {
                recovery::journal_disarm();
                out.line("radio verified STARTED, dongle state untouched");
            } else {
                out.line_fmt(format!(
                    "radio is NOT started -- keeping {RECOVERY_JOURNAL_NAME} armed so the repair rung brings it back"
                ));
            }
            return false;
        }
    }
    unsafe { kernel32::Sleep(R2_DISABLE_QUIET_MS) };

    // Enable is the one step that must not fail silently.
    let mut started = false;
    let mut attempt = 0u32;
    while attempt < R1_REENABLE_ATTEMPTS && !started {
        if attempt > 0 {
            unsafe { kernel32::Sleep(R1_REENABLE_RETRY_MS * 2) };
        }
        if usb_prop_change(devs.handle(), &mut target, DICS_ENABLE) {
            started = wait_devnode_started(target.DevInst, R2_ENABLE_VERIFY_MS);
            if started {
                break;
            }
            out.line_fmt(format!(
                "enable attempt {}/{}: DICS_ENABLE accepted but not STARTED in {} ms — trying CM_Enable_DevNode",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                R2_ENABLE_VERIFY_MS
            ));
        } else {
            out.line_fmt(format!(
                "enable attempt {}/{}: DICS_ENABLE rejected 0x{:x} — trying CM_Enable_DevNode",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                unsafe { kernel32::GetLastError() }
            ));
        }
        if unsafe { CM_Enable_DevNode(target.DevInst, 0) } == CR_SUCCESS {
            started = wait_devnode_started(target.DevInst, R2_ENABLE_VERIFY_MS);
            if started {
                break;
            }
            out.line_fmt(format!(
                "enable attempt {}/{}: CM_Enable_DevNode accepted but not STARTED in {} ms",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                R2_ENABLE_VERIFY_MS
            ));
        } else {
            out.line_fmt(format!(
                "enable attempt {}/{}: CM_Enable_DevNode failed 0x{:x}",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                unsafe { kernel32::GetLastError() }
            ));
        }
        attempt += 1;
    }
    if !started {
        out.line_fmt(format!(
            "ENABLE FAILED after {} attempts — dongle is left DISABLED. The repair rung KEEPS RETRYING every {} ms and at every start, because {RECOVERY_JOURNAL_NAME} is still armed. Manual options:",
            R1_REENABLE_ATTEMPTS, RECOVERY_RETRY_MS
        ));
        out.line("  0) elevated: bluetooth_force.exe --recover");
        out.line("  1) admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false");
        out.line("  2) Device Manager: the CSR radio with the down-arrow -> Enable");
        out.line("  3) replug into a DIFFERENT USB port (same-port replug keeps the disabled flag)");
        return false;
    }

    recovery::journal_disarm();
    out.line("complete (1 cycled)");
    true
}
