//! PoC for the autostart task: the command line is the whole risk surface.
//!
//! Two failure modes were worth proving against, because both are silent:
//!   1. Quoting. `C:\Program Files\...` is the normal install location, and
//!      `/TR` is parsed TWICE -- once by schtasks, once by the CRT when the
//!      task finally starts the exe. A missed escape gives a task that either
//!      refuses to register or starts `C:\Program` at every logon.
//!   2. Elevation. Without `/RL HIGHEST` the daemon starts unelevated and the
//!      field log's `rung earbud-restart: skipped (admin required)` becomes
//!      permanent -- an autostart that looks installed and cannot recover
//!      anything.

use poc::autostart_cmd::{argv_of, create_cmdline, delete_cmdline, query_cmdline, task_action, TASK_NAME};

const SCHTASKS: &str = r"C:\Windows\System32\schtasks.exe";

/// The realistic install path, end to end: build the schtasks command line,
/// parse it as schtasks will, then parse the action as the CRT will.
#[test]
fn a_path_with_spaces_survives_both_parses() {
    let exe = r"C:\Program Files\Bluetooth Force\bluetooth_force.exe";
    let cmd = create_cmdline(SCHTASKS, exe, "AA:BB:CC:DD:EE:FF", Some("Redmi Buds 6"));
    let argv = argv_of(&cmd);
    assert_eq!(argv[0], SCHTASKS, "schtasks itself is an absolute System32 path");

    let tr = argv.iter().position(|a| a == "/TR").expect("/TR present");
    let action = &argv[tr + 1];
    let inner = argv_of(action);
    println!("action as schtasks sees it: {action}");
    println!("action as the CRT sees it: {inner:?}");
    assert_eq!(
        inner,
        vec![exe.to_string(), "AA:BB:CC:DD:EE:FF".to_string(), "Redmi Buds 6".to_string()],
        "the task must start the exe with exactly the daemon's own two arguments"
    );
}

/// A hostile / sloppy audio substring must not be able to inject an argument
/// into the task action. The endpoint name comes from the system, but it is
/// user-supplied on this command line.
#[test]
fn an_embedded_quote_cannot_inject_an_argument() {
    let action = task_action(
        r"C:\btf\bluetooth_force.exe",
        "AA:BB:CC:DD:EE:FF",
        Some(r#"buds" /RL LIMITED"#),
    );
    let inner = argv_of(&action);
    assert_eq!(inner.len(), 3, "still exactly three arguments: {inner:?}");
    assert_eq!(inner[2], r#"buds" /RL LIMITED"#, "it stays ONE literal argument");
}

/// Trailing backslash is the other classic quoting trap: a directory path
/// ending in `\` would escape the closing quote.
#[test]
fn a_trailing_backslash_does_not_escape_the_closing_quote() {
    let inner = argv_of(&task_action(r"C:\btf dir\", "AA:BB:CC:DD:EE:FF", None));
    assert_eq!(inner, vec![r"C:\btf dir\".to_string(), "AA:BB:CC:DD:EE:FF".to_string()]);
}

#[test]
fn the_task_is_always_created_elevated_at_logon_and_replaceable() {
    let argv = argv_of(&create_cmdline(SCHTASKS, r"C:\btf\bluetooth_force.exe", "AA:BB:CC:DD:EE:FF", None));
    let flag = |name: &str, value: &str| {
        let i = argv.iter().position(|a| a == name).unwrap_or_else(|| panic!("{name} missing"));
        assert_eq!(argv[i + 1], value, "{name}");
    };
    flag("/TN", TASK_NAME);
    flag("/SC", "ONLOGON");
    flag("/RL", "HIGHEST"); // no HIGHEST -> every PnP rung dies with "admin required"
    assert!(argv.iter().any(|a| a == "/F"), "re-install must overwrite, not fail");
}

/// All three verbs must address the SAME task, or uninstall/status would
/// cheerfully report on a task nobody installed.
#[test]
fn install_status_and_uninstall_address_one_task() {
    for cmd in [
        create_cmdline(SCHTASKS, r"C:\btf\bluetooth_force.exe", "AA:BB:CC:DD:EE:FF", None),
        query_cmdline(SCHTASKS),
        delete_cmdline(SCHTASKS),
    ] {
        let argv = argv_of(&cmd);
        let tn = argv.iter().position(|a| a == "/TN").expect("/TN present");
        assert_eq!(argv[tn + 1], TASK_NAME);
    }
    assert!(argv_of(&delete_cmdline(SCHTASKS)).iter().any(|a| a == "/F"), "delete must not prompt");
}

/// `run_hidden_wait` refuses a command line longer than 2046 UTF-16 units.
/// A deep install path must not silently hit that.
#[test]
fn a_deep_install_path_still_fits_the_spawn_limit() {
    let exe = format!(r"C:\{}\bluetooth_force.exe", "sub dir\\".repeat(20));
    let cmd = create_cmdline(SCHTASKS, &exe, "AA:BB:CC:DD:EE:FF", Some("Redmi Buds 6 Lite"));
    println!("{} chars for a {}-char exe path", cmd.chars().count(), exe.chars().count());
    assert!(cmd.encode_utf16().count() < 2046);
}
