//! The resource script is generated in `build.rs`, so its shape is checked
//! here rather than trusted. The real proof is the build itself: the release
//! binary for `x86_64-pc-windows-gnu` links with a `.rsrc` section and the
//! strings below are present in it.

#[path = "../../build.rs"]
#[allow(dead_code)]
mod res;

use std::path::Path;

#[test]
fn the_resource_script_is_balanced_and_carries_the_identity() {
    let rc = res::rc_source("3.0.0", Path::new(r"C:\x\res\bluetooth_force.manifest"));
    println!("{rc}");

    // Backslashes must be escaped or the resource compiler reads \b, \r, ...
    assert!(rc.contains(r"C:\\x\\res\\bluetooth_force.manifest"));
    assert!(rc.starts_with("1 24 "), "RT_MANIFEST as resource id 1");

    let begins = rc.matches("BEGIN").count();
    let ends = rc.matches("END").count();
    assert_eq!(begins, ends, "unbalanced BEGIN/END would fail the build");
    assert_eq!(begins, 4);

    for needed in [
        "FILEVERSION 3,0,0,0",
        "PRODUCTVERSION 3,0,0,0",
        "\"CompanyName\", \"Bluetooth Force\"",
        "\"OriginalFilename\", \"bluetooth_force.exe\"",
        "\"FileVersion\", \"3.0.0.0\"",
        "\"Translation\", 0x409, 1200",
    ] {
        assert!(rc.contains(needed), "missing: {needed}");
    }
}

#[test]
fn a_short_or_odd_version_still_produces_four_fields() {
    let rc = res::rc_source("7", Path::new("m"));
    assert!(rc.contains("FILEVERSION 7,0,0,0"));
    let rc = res::rc_source("", Path::new("m"));
    assert!(rc.contains("FILEVERSION 0,0,0,0"), "a broken version must not break the build");
}
