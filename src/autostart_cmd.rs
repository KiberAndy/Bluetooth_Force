//! Autostart command lines — pure string building, no Win32, fully testable.
//!
//! The daemon needs TWO things at logon that a plain `HKCU\...\Run` entry
//! cannot give it together:
//!   * elevation — `pnputil`, `CM_Enable_DevNode` and the hub-port cycle all
//!     fail without it, so an unelevated autostart would silently amputate
//!     every PnP rung (the log says `rung earbud-restart: skipped (admin
//!     required)`), and
//!   * no UAC prompt at every logon.
//! A Task Scheduler logon task with `/RL HIGHEST` is the only stock mechanism
//! that does both, so the install mode drives `schtasks.exe`.
//!
//! The action string is nested quoting: `schtasks` receives ONE `/TR` argument
//! that itself has to survive a second round of `CommandLineToArgvW` parsing
//! when the task later starts the exe. Both levels are built with the same
//! MSVCRT quoting rules instead of by hand, because an exe path with a space
//! (`C:\Program Files\...`) is the normal case, not the exotic one.

use crate::text::quote_arg;

/// Task name. Visible in Task Scheduler, so it is a human name.
pub const TASK_NAME: &str = "Bluetooth Force";

/// The command the task runs: `"<exe>" <mac> ["<audio substring>"]`.
///
/// This is a command LINE, not a list, because that is what `/TR` takes.
pub fn task_action(exe: &str, mac: &str, audio: Option<&str>) -> String {
    let mut action = quote_arg(exe);
    action.push(' ');
    action.push_str(mac);
    if let Some(a) = audio.filter(|a| !a.is_empty()) {
        action.push(' ');
        action.push_str(&quote_arg(a));
    }
    action
}

/// `schtasks /Create` for a logon task that runs elevated.
///
/// `/F` overwrites an existing task: re-running the install after moving the
/// exe must fix the task, not fail on it. `/RL HIGHEST` is the elevation.
/// `/SC ONLOGON` fires for the logon of the account that creates it.
pub fn create_cmdline(schtasks: &str, exe: &str, mac: &str, audio: Option<&str>) -> String {
    format!(
        "{} /Create /TN {} /TR {} /SC ONLOGON /RL HIGHEST /F",
        quote_arg(schtasks),
        quote_arg(TASK_NAME),
        quote_arg(&task_action(exe, mac, audio))
    )
}

pub fn delete_cmdline(schtasks: &str) -> String {
    format!("{} /Delete /TN {} /F", quote_arg(schtasks), quote_arg(TASK_NAME))
}

pub fn query_cmdline(schtasks: &str) -> String {
    format!("{} /Query /TN {}", quote_arg(schtasks), quote_arg(TASK_NAME))
}

/// Parse a command line back into arguments with the `CommandLineToArgvW`
/// rules, so a test can prove that what `schtasks` will receive is what we
/// meant. Test support only -- the daemon never parses a command line -- but it
/// lives next to the builder it checks, and the PoC harness (an integration
/// test, so `cfg(test)` items are invisible to it) needs it.
#[allow(dead_code)]
pub fn argv_of(cmdline: &str) -> Vec<String> {
    let b: Vec<char> = cmdline.chars().collect();
    let mut args = Vec::new();
    let mut cur = String::new();
    let mut in_quotes = false;
    let mut started = false;
    let mut i = 0;
    while i < b.len() {
        let c = b[i];
        if c == '\\' {
            let mut n = 0;
            while i < b.len() && b[i] == '\\' {
                n += 1;
                i += 1;
            }
            if i < b.len() && b[i] == '"' {
                for _ in 0..n / 2 {
                    cur.push('\\');
                }
                if n % 2 == 1 {
                    cur.push('"'); // escaped quote
                    started = true;
                    i += 1;
                } else {
                    in_quotes = !in_quotes;
                    started = true;
                    i += 1;
                }
            } else {
                for _ in 0..n {
                    cur.push('\\');
                }
            }
            continue;
        }
        if c == '"' {
            in_quotes = !in_quotes;
            started = true;
            i += 1;
            continue;
        }
        if (c == ' ' || c == '\t') && !in_quotes {
            if started {
                args.push(std::mem::take(&mut cur));
                started = false;
            }
            i += 1;
            continue;
        }
        cur.push(c);
        started = true;
        i += 1;
    }
    if started {
        args.push(cur);
    }
    args
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_action_survives_one_argv_parse() {
        let cmd = create_cmdline(
            r"C:\Windows\System32\schtasks.exe",
            r"C:\Program Files\Bluetooth Force\bluetooth_force.exe",
            "AA:BB:CC:DD:EE:FF",
            Some("Redmi Buds"),
        );
        let argv = argv_of(&cmd);
        // /TR must arrive as ONE argument, with the inner quotes intact.
        let tr = argv.iter().position(|a| a == "/TR").expect("/TR present");
        assert_eq!(
            argv[tr + 1],
            r#""C:\Program Files\Bluetooth Force\bluetooth_force.exe" AA:BB:CC:DD:EE:FF "Redmi Buds""#
        );
        // ...and that action, parsed in turn, is the exe plus its two args.
        let inner = argv_of(&argv[tr + 1]);
        assert_eq!(inner.len(), 3);
        assert_eq!(inner[0], r"C:\Program Files\Bluetooth Force\bluetooth_force.exe");
        assert_eq!(inner[1], "AA:BB:CC:DD:EE:FF");
        assert_eq!(inner[2], "Redmi Buds");
    }

    #[test]
    fn the_audio_argument_is_optional() {
        let action = task_action(r"C:\btf\bluetooth_force.exe", "AA:BB:CC:DD:EE:FF", None);
        assert_eq!(argv_of(&action).len(), 2);
        let empty = task_action(r"C:\btf\bluetooth_force.exe", "AA:BB:CC:DD:EE:FF", Some(""));
        assert_eq!(empty, action, "an empty substring must not add a bare pair of quotes");
    }

    #[test]
    fn the_task_is_elevated_and_overwrites() {
        let cmd = create_cmdline("schtasks.exe", "btf.exe", "AA:BB:CC:DD:EE:FF", None);
        let argv = argv_of(&cmd);
        // Without HIGHEST every PnP rung would be dead on arrival.
        assert!(argv.iter().any(|a| a == "/RL"));
        assert!(argv.iter().any(|a| a == "HIGHEST"));
        assert!(argv.iter().any(|a| a == "ONLOGON"));
        assert!(argv.iter().any(|a| a == "/F"), "a re-install must replace the old task");
    }

    #[test]
    fn the_task_name_matches_across_all_three_verbs() {
        for cmd in [
            create_cmdline("s.exe", "btf.exe", "AA:BB:CC:DD:EE:FF", None),
            delete_cmdline("s.exe"),
            query_cmdline("s.exe"),
        ] {
            let argv = argv_of(&cmd);
            let tn = argv.iter().position(|a| a == "/TN").expect("/TN present");
            assert_eq!(argv[tn + 1], TASK_NAME);
        }
    }
}
