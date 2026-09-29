//! Embeds the application manifest and version info.
//!
//! Why: a stripped, unsigned, GUI-subsystem executable with no company name,
//! no product name and no manifest is the exact shape generic antivirus
//! heuristics punish (Kaspersky's `VHO:Trojan.Win32.Agentb.gen` among them).
//! Metadata does not make a binary trustworthy, but its absence is a real
//! part of the score, and it is the only part of that score not required by
//! what this daemon actually does.
//!
//! One path, no crates: a `.rc` is generated and handed to whichever resource
//! compiler belongs to the target's toolchain -- `windres` for the mingw
//! (`-gnu`) targets, `rc.exe` for MSVC. If neither is found the build still
//! succeeds; the binary is just anonymous, and the warning says so.
//!
//! Rejected alternative, recorded so nobody tries it again: writing a `.res`
//! by hand and letting the linker take it. MSVC accepts that, but the mingw
//! linker rejects a `.res` outright ("file format not recognized"), and
//! converting it with `windres -J res -O coff` crashes with "unexpected
//! version string" -- on windres's own output as well as on a hand-written
//! file. Compiling a `.rc` is the path that works on both.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const COMPANY: &str = "Bluetooth Force";
const PRODUCT: &str = "Bluetooth Force";
const DESCRIPTION: &str = "Keeps paired Bluetooth earbuds connected";
const COMMENTS: &str = "Local-only utility. Makes no network connections.";
const COPYRIGHT: &str = "Provided as-is, without warranty.";
const INTERNAL_NAME: &str = "bluetooth_force";
const ORIGINAL_FILENAME: &str = "bluetooth_force.exe";

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=res/bluetooth_force.manifest");
    println!("cargo:rerun-if-env-changed=BTF_RC");

    if env::var("CARGO_CFG_TARGET_OS").as_deref() != Ok("windows") {
        return; // e.g. `cargo check` on a non-Windows host
    }

    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let manifest = manifest_dir.join("res/bluetooth_force.manifest");
    if !manifest.exists() {
        println!("cargo:warning=res/bluetooth_force.manifest is missing; the exe will be anonymous");
        return;
    }

    let version = env::var("CARGO_PKG_VERSION").unwrap_or_else(|_| "0.0.0".into());
    let rc_path = out_dir.join("bluetooth_force.rc");
    if fs::write(&rc_path, rc_source(&version, &manifest)).is_err() {
        println!("cargo:warning=could not write the resource script; the exe will be anonymous");
        return;
    }

    let gnu = env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("gnu");
    let obj = out_dir.join(if gnu { "bluetooth_force_res.o" } else { "bluetooth_force.res" });

    let mut tools: Vec<String> = Vec::new();
    if let Ok(v) = env::var("BTF_RC") {
        if !v.is_empty() {
            tools.push(v);
        }
    }
    if gnu {
        tools.push("x86_64-w64-mingw32-windres".into());
        tools.push("windres".into());
    } else {
        tools.push("rc.exe".into());
        tools.push("llvm-rc.exe".into());
    }

    for tool in &tools {
        let run = if tool.contains("windres") {
            Command::new(tool).arg("-O").arg("coff").arg("-i").arg(&rc_path).arg("-o").arg(&obj).status()
        } else {
            Command::new(tool).arg("/nologo").arg("/fo").arg(&obj).arg(&rc_path).status()
        };
        if run.map(|s| s.success()).unwrap_or(false) {
            println!("cargo:rustc-link-arg-bins={}", obj.display());
            return;
        }
    }

    println!(
        "cargo:warning=no resource compiler found (tried {}): building without version info and manifest. The binary works, it is just anonymous, which makes heuristic antivirus false positives more likely. Set BTF_RC to windres or rc.exe to fix.",
        tools.join(", ")
    );
}

fn version_parts(version: &str) -> (u16, u16, u16, u16) {
    let mut it = version.split('.').map(|p| p.parse::<u16>().unwrap_or(0));
    (it.next().unwrap_or(0), it.next().unwrap_or(0), it.next().unwrap_or(0), it.next().unwrap_or(0))
}

/// The resource script: manifest (`RT_MANIFEST`, id 1) plus a version block.
pub fn rc_source(version: &str, manifest: &Path) -> String {
    let (a, b, c, d) = version_parts(version);
    let four = format!("{a}.{b}.{c}.{d}");
    // Both resource compilers read the path with C escaping.
    let manifest = manifest.display().to_string().replace('\\', "\\\\");
    format!(
        "1 24 \"{manifest}\"\n\
         1 VERSIONINFO\n\
         FILEVERSION {a},{b},{c},{d}\n\
         PRODUCTVERSION {a},{b},{c},{d}\n\
         FILEOS 0x4L\n\
         FILETYPE 0x1L\n\
         BEGIN\n\
         BLOCK \"StringFileInfo\"\n\
         BEGIN\n\
         BLOCK \"040904B0\"\n\
         BEGIN\n\
         VALUE \"CompanyName\", \"{COMPANY}\"\n\
         VALUE \"FileDescription\", \"{DESCRIPTION}\"\n\
         VALUE \"FileVersion\", \"{four}\"\n\
         VALUE \"InternalName\", \"{INTERNAL_NAME}\"\n\
         VALUE \"LegalCopyright\", \"{COPYRIGHT}\"\n\
         VALUE \"OriginalFilename\", \"{ORIGINAL_FILENAME}\"\n\
         VALUE \"ProductName\", \"{PRODUCT}\"\n\
         VALUE \"ProductVersion\", \"{four}\"\n\
         VALUE \"Comments\", \"{COMMENTS}\"\n\
         END\n\
         END\n\
         BLOCK \"VarFileInfo\"\n\
         BEGIN\n\
         VALUE \"Translation\", 0x409, 1200\n\
         END\n\
         END\n"
    )
}
