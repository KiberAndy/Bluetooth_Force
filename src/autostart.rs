//! Autostart, checked on every daemon start.
//!
//! Policy, deliberately dumb: the FIRST elevated run registers a Task
//! Scheduler logon task for itself; every later run just checks that the task
//! is still there. No separate install mode, nothing for the user to remember.
//!
//! Why a scheduled task and not `HKCU\...\Run`: the recovery rungs need
//! administrator rights (`pnputil /restart-device`, `CM_Enable_DevNode`, the
//! hub port cycle), so an unelevated autostart would come up permanently
//! crippled -- `rung earbud-restart: skipped (admin required)` forever. A task
//! with `/RL HIGHEST` starts elevated with no UAC prompt, which `Run` cannot do.
//!
//! Opt out by putting `btf_no_autostart.txt` next to the exe, in the same style
//! as `btf_freeze.txt`. If the task is already registered, that file removes it.

use crate::autostart_cmd::{create_cmdline, delete_cmdline, query_cmdline, TASK_NAME};
use crate::btlog;
use crate::config::AUTOSTART_OPT_OUT_NAME;
use crate::pnp::devnode::{is_user_admin, run_hidden_wait};
use crate::util::{self_dir_path, system_path_of};

/// Creating or deleting a task is fast; a longer wait only means the Task
/// Scheduler service itself is wedged, which is worth reporting.
const SCHTASKS_TIMEOUT_MS: u32 = 30_000;

/// Make sure the logon task matches what the user asked for. Called once at
/// startup, before the poll loop; every outcome is one line in `btf.log`.
pub fn ensure(exe: &str, mac_str: &str, audio: Option<&str>) {
    let opted_out = self_dir_path(AUTOSTART_OPT_OUT_NAME).map(|p| p.exists()).unwrap_or(false);

    let Some(schtasks) = system_path_of("schtasks.exe") else {
        btlog!("autostart: System32\\schtasks.exe could not be resolved -- autostart left alone");
        return;
    };
    let present = run_hidden_wait(&query_cmdline(&schtasks), SCHTASKS_TIMEOUT_MS) == Some(0);

    if opted_out {
        if !present {
            btlog!("autostart: disabled by {AUTOSTART_OPT_OUT_NAME} -- no logon task, and none will be created");
            return;
        }
        run_hidden_wait(&delete_cmdline(&schtasks), SCHTASKS_TIMEOUT_MS);
        let gone = run_hidden_wait(&query_cmdline(&schtasks), SCHTASKS_TIMEOUT_MS) != Some(0);
        if gone {
            btlog!("autostart: {AUTOSTART_OPT_OUT_NAME} is present -- the logon task \"{TASK_NAME}\" has been REMOVED");
        } else {
            btlog!("autostart: {AUTOSTART_OPT_OUT_NAME} is present but the logon task could not be removed (elevation required) -- delete it by hand: schtasks /Delete /TN \"{TASK_NAME}\" /F");
        }
        return;
    }

    if present {
        // Only existence can be checked here: reading the task's stored command
        // would need schtasks' output, and this process has no console to
        // capture it into. So a task pointing at an exe that has since MOVED
        // still counts as present -- delete it and restart to re-create it.
        btlog!("autostart: logon task \"{TASK_NAME}\" is registered");
        return;
    }

    if !is_user_admin() {
        btlog!("autostart: NOT installed -- a task with /RL HIGHEST needs elevation. Start this exe once from an elevated shell and it registers itself. (An unelevated autostart would be useless: every PnP rung would die with 'admin required'.)");
        return;
    }

    let code = run_hidden_wait(&create_cmdline(&schtasks, exe, mac_str, audio), SCHTASKS_TIMEOUT_MS);
    // Verified by re-query, not by trusting the create's exit code.
    if run_hidden_wait(&query_cmdline(&schtasks), SCHTASKS_TIMEOUT_MS) == Some(0) {
        btlog!("autostart: logon task \"{TASK_NAME}\" CREATED -- this exe now starts elevated at your logon. Opt out with {AUTOSTART_OPT_OUT_NAME}.");
    } else {
        btlog!("autostart: FAILED to register the logon task (schtasks /Create exit={code:?}) -- the daemon runs normally, it just will not start by itself");
    }
}
