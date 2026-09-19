//! Rung 0 — crash-safe recovery journal and the repair pass.
//!
//! A devnode disable is PERSISTENT: it survives a replug and a reboot. The
//! journal is a marker file next to the exe whose existence means "a persistent
//! disable of ours is unaccounted for". While it exists every escalation rung is
//! blocked and the repair pass keeps trying to bring the radio back. A
//! deliberate user disable is respected unless `--recover` (or the journal) says
//! the disable is ours.

use std::fs;

use crate::config::*;
use crate::ladder::radio_recovery_done;
use crate::output::HealthOut;
use crate::pnp::devnode::*;
use crate::sys::setupapi::*;
use crate::util;

/// What a repair pass observed, not just whether it fixed. `present` lets the
/// rung notice a replug (0 → >0) and reset the backoff clock.
pub struct RepairOutcome {
    pub repaired: bool,
    pub present: u32,
}

pub fn journal_present() -> bool {
    util::self_dir_path(RECOVERY_JOURNAL_NAME).is_some_and(|p| p.exists())
}

/// Arm the journal BEFORE a disable. Returns false if the marker could not be
/// made durable — the caller must then NOT disable anything: an unrecoverable
/// disable is worse than a wedge that stays wedged.
pub fn journal_arm(id: &str) -> bool {
    let Some(path) = util::self_dir_path(RECOVERY_JOURNAL_NAME) else {
        return false;
    };
    let write = || -> std::io::Result<()> {
        let mut f = fs::File::create(&path)?;
        use std::io::Write;
        f.write_all(id.as_bytes())?;
        f.write_all(b"\r\n")?;
        // Order is what makes this crash-safe: flush, close, then verify the
        // marker is really visible.
        f.sync_all()
    };
    if write().is_err() {
        return false;
    }
    path.exists()
}

pub fn journal_disarm() {
    if let Some(path) = util::self_dir_path(RECOVERY_JOURNAL_NAME) {
        let _ = fs::remove_file(path);
    }
}

/// Is `btf_freeze.txt` present next to the exe?
///
/// The kill switch: after a machine has been crashed by an automatic
/// escalation, the user can disarm the device-level rungs without a rebuild —
/// creating one empty file is the cheapest instruction that survives a bad day.
pub fn freeze_present() -> bool {
    util::self_dir_path("btf_freeze.txt").is_some_and(|p| p.exists())
}

/// Rung 0: re-enable every present CSR radio devnode that is sitting disabled
/// or otherwise not started.
///
/// `forced = false` is the automatic path (only acts when the journal says a
/// disable of ours is outstanding); `forced = true` is `--recover`.
pub fn recover_disabled_radio(out: &HealthOut, forced: bool, quiet: bool) -> RepairOutcome {
    // The marker is no longer a precondition, only an ownership flag: a radio
    // that pnputil stopped (3010) is not "disabled", so it must still be
    // repaired, while a deliberate user disable is only ours to undo when the
    // marker says the disable is ours (or `--recover` was asked for).
    let owns_disable = forced || journal_present();

    if !is_user_admin() {
        out.line("NOT ELEVATED: a disabled radio can only be enabled from an elevated process. Run this in an admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false");
        return RepairOutcome { repaired: false, present: 0 };
    }

    let devs = match class_devs(None, Some(&ENUMERATOR_USB[..]), DIGCF_PRESENT | DIGCF_ALLCLASSES) {
        Ok(d) => d,
        Err(err) => {
            out.line_fmt(format!(
                "SetupDiGetClassDevsW failed 0x{err:x} -- cannot inspect the radio, journal kept"
            ));
            return RepairOutcome { repaired: false, present: 0 };
        }
    };

    let mut present = 0u32;
    let mut repaired = 0u32;
    let mut still_disabled = 0u32;
    let mut index = 0u32;
    loop {
        let mut info = sp_devinfo_data();
        if unsafe { SetupDiEnumDeviceInfo(devs.handle(), index, &mut info) } == 0 {
            break;
        }
        let Some(id) = device_instance_id(devs.handle(), &mut info) else {
            index += 1;
            continue;
        };
        if !crate::mac::is_csr_radio_instance_id(id.as_str()) {
            index += 1;
            continue;
        }

        present += 1;
        if !devnode_needs_repair(info.DevInst, owns_disable) {
            index += 1;
            continue;
        }

        out.line_fmt(format!("UNHEALTHY radio devnode: {} -- bringing it back", id.as_str()));
        let mut ok = enable_devnode_verified(devs.handle(), &mut info, out);
        if !ok {
            if let Some(pnputil) = util::system_path_of("pnputil.exe") {
                // Two failures need two verbs: /enable-device clears a
                // persistent disable, /restart-device restarts a merely stopped
                // node (the 3010 state). Try both before giving up on a pass.
                for verb in ["/enable-device", "/restart-device"] {
                    let cmd = format!("\"{pnputil}\" {verb} \"{}\"", id.as_str());
                    let code = run_hidden_wait(&cmd, PNPUTIL_TIMEOUT_MS);
                    out.line_fmt(format!("  pnputil {verb} exit={code:?}"));
                    ok = wait_devnode_started(info.DevInst, RECOVERY_VERIFY_MS);
                    if ok {
                        break;
                    }
                }
            }
        }
        if ok {
            repaired += 1;
        } else {
            still_disabled += 1;
        }
        index += 1;
    }

    if present == 0 {
        if owns_disable {
            out.line("no CSR radio devnode present right now (dongle unplugged?) -- journal KEPT, the radio is repaired as soon as it reappears");
        } else {
            out.line("no CSR radio devnode present right now (dongle unplugged?)");
        }
        return RepairOutcome { repaired: false, present: 0 };
    }

    if radio_recovery_done(present, still_disabled) {
        if repaired > 0 {
            out.line_fmt(format!(
                "RECOVERED: {repaired} radio devnode(s) enabled and STARTED (of {present} present) -- journal cleared"
            ));
        } else {
            out.line_fmt(format!(
                "nothing to repair: {present} radio devnode(s) present and started -- stale journal cleared"
            ));
        }
        journal_disarm();
        return RepairOutcome { repaired: repaired > 0, present };
    }

    if !quiet {
        out.line_fmt(format!(
            "STILL NOT STARTED: {still_disabled} of {present} node(s) refused to come back -- journal KEPT, retrying with backoff (cap {RECOVERY_BACKOFF_CAP_MS} ms). Manual fix in an admin PowerShell: Get-PnpDevice -PresentOnly | Where-Object InstanceId -like 'USB\\VID_0A12*' | Enable-PnpDevice -Confirm:$false"
        ));
    }
    RepairOutcome { repaired: false, present }
}
