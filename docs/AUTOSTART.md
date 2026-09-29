# Autostart

There is nothing to install. The first time the daemon is started **from an
elevated shell** it registers a Task Scheduler logon task for itself; every
later start just checks that the task is still there.

```powershell
# elevated PowerShell, in the folder with the exe
.\bluetooth_force.exe AA:BB:CC:DD:EE:FF "Redmi Buds"
```

The result is one line in `btf.log`, one of:

```
btf: autostart: logon task "Bluetooth Force" CREATED -- this exe now starts elevated at your logon. Opt out with btf_no_autostart.txt.
btf: autostart: logon task "Bluetooth Force" is registered
btf: autostart: NOT installed -- a task with /RL HIGHEST needs elevation. ...
btf: autostart: FAILED to register the logon task (schtasks /Create exit=...) ...
```

The exe is a GUI-subsystem binary, so it prints **nothing** to the console —
`btf.log` next to the exe is the only output. `Get-Content .\btf.log -Tail 20`.

## Opting out

Put `btf_no_autostart.txt` next to the exe (same style as `btf_freeze.txt`).
On the next start the daemon removes the task and says so. Or by hand:

```powershell
schtasks /Delete /TN "Bluetooth Force" /F
```

## What gets registered

```
schtasks /Create /TN "Bluetooth Force"
         /TR "\"<full path>\bluetooth_force.exe\" <MAC> \"<audio substring>\""
         /SC ONLOGON /RL HIGHEST /F
```

* `/SC ONLOGON` — fires at the logon of the account that created it.
* `/RL HIGHEST` — elevated, **no UAC prompt**.
* `/F` — overwrite rather than fail.

`/RL HIGHEST` is the reason this is a task and not an `HKCU\...\Run` entry: the
rungs need administrator rights (`pnputil /restart-device`,
`CM_Enable_DevNode`, the hub port cycle). Started from `Run`, the daemon would
come up as a normal user and log `rung earbud-restart: skipped (admin required)`
forever — an autostart that looks installed and repairs nothing. `Run` cannot
elevate at all, so there is no unelevated fallback worth having.

## Honest limits

* Success is verified by re-querying the task, not by the create's exit code.
  That proves the task is **registered** — not that a future logon will work. A
  Group Policy that blocks logon tasks would still win.
* Only the task's EXISTENCE is checked on later starts. Reading back its stored
  command would need schtasks' console output, which a GUI-subsystem process has
  nowhere to capture. So if you **move or rename the exe**, the task keeps
  pointing at the old path and nothing notices. Fix: delete the task and start
  the exe once from its new location.
* Registering does not start the daemon a second time, and the singleton mutex
  would refuse it anyway.
* The task's working directory is `System32`. Harmless: `btf.log`, the recovery
  journal and every marker file are resolved next to the exe.
