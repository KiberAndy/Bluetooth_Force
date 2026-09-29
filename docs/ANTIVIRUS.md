# `VHO:Trojan.Win32.Agentb.gen` on `bluetooth_force.exe`

`VHO` is Kaspersky's *behavioural heuristic*, not a signature: nothing was
recognised, the file merely fit a generic profile. The same verdict lands on
the copy in `target\release\deps\` because it is the same bytes.

## Why this binary fits the profile

Every trait below is required by what the daemon does:

* GUI subsystem with no visible window — needed to receive
  `WM_POWERBROADCAST` and `WM_DEVICECHANGE` broadcasts.
* Spawns `pnputil.exe` hidden, elevated — the recovery rungs restart devnodes.
* Resolves `bthprops.cpl` exports through `LoadLibraryEx` + `GetProcAddress` —
  no import library ships those, and missing exports must degrade, not crash.
* Writes marker files next to itself — crash safety.

One trait was *not* required, and it is the one heuristics weigh heaviest: the
binary was stripped, unsigned and carried no version info and no manifest — an
anonymous executable. That is fixed:

* `build.rs` generates a `.rc` (the manifest from
  `res/bluetooth_force.manifest` plus a version block) and compiles it with
  the resource compiler that already belongs to the toolchain: `windres` for
  the mingw (`-gnu`) targets, `rc.exe` for MSVC. **Plain `cargo build
  --release` is enough**; no crates and nothing to install on a mingw setup.
  If no resource compiler is found the build still succeeds and prints a
  warning (`BTF_RC` overrides the tool path).

  Verified by an actual release link for `x86_64-pc-windows-gnu`: the exe gets
  a `.rsrc` section with the manifest and the version strings in it. Feeding
  the linker a hand-written `.res` does NOT work on mingw -- it rejects it
  with "file format not recognized", and `windres -J res -O coff` crashes on
  it (and on its own output too).
* `Cargo.toml` sets `strip = false`, so symbol names stay readable.

Check it after a build:

```powershell
(Get-Item .\target\release\bluetooth_force.exe).VersionInfo |
    Format-List CompanyName, ProductName, FileDescription, FileVersion
```

## What actually clears the verdict

Metadata lowers the score; it does not overrule a heuristic. In order of
effectiveness:

1. **Report the false positive.** Upload the exe to <https://opentip.kaspersky.com>
   and submit it at <https://www.kaspersky.com/false-positive-detection>. This
   is the only step that fixes it for everyone, usually within days.
2. **Exclude the folder you actually run from** — copy the built exe to e.g.
   `C:\Tools\BluetoothForce\` and exclude that. Excluding `target\` hides
   everything the compiler produces, which is a bad habit.

Code signing was considered and dropped: a self-signed certificate is trusted
only on the machine that installs it and does not change an AV verdict, and a
publicly trusted certificate is not worth buying for a personal tool.
