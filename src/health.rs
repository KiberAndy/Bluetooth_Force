//! `--health`: a one-shot forensic probe battery.
//!
//! Answers "what is the BT stack doing right now" with raw, timestamped
//! evidence. The decisive protocol is to run it healthy and again during the
//! wedge, then diff: probes that change are the wedge fingerprint.

use std::ptr;

use crate::bluetooth::{empty_device_info, BthApi};
use crate::config::*;
use crate::mac::{format_mac, parse_mac};
use crate::output::HealthOut;
use crate::pnp::devnode::{class_devs, is_user_admin};
use crate::sys::bluetooth::{
    BLUETOOTH_DEVICE_SEARCH_PARAMS, BLUETOOTH_FIND_RADIO_PARAMS, BLUETOOTH_RADIO_INFO,
};
use crate::sys::kernel32;
use crate::sys::HANDLE;
use crate::sys::setupapi::*;
use crate::util::{now_ms, utf16_field};

pub fn run(args: &[String]) {
    let t_start = now_ms();

    // argv: --health [MAC | out-path] [out-path]
    let mut out_path = "btf_health_report.txt".to_string();
    let mut target_mac: Option<u64> = None;
    if let Some(a) = args.first() {
        if a.len() == 17 {
            target_mac = parse_mac(a).ok();
        }
        if target_mac.is_none() && !a.is_empty() {
            out_path = a.clone();
        }
    }
    if out_path == "btf_health_report.txt" {
        if let Some(a) = args.get(1) {
            if !a.is_empty() {
                out_path = a.clone();
            }
        }
    }

    let out = HealthOut::to_file("health", &out_path);
    let mac_disp = target_mac.map(format_mac).unwrap_or_else(|| "-".to_string());
    out.line_fmt(format!(
        "build=rust3.0 admin={} target=[{mac_disp}] report={out_path}",
        is_user_admin()
    ));

    let Ok(api) = BthApi::load() else {
        out.line("probe bthprops: FAILED TO LOAD — stack-level probes unavailable; PnP-level problem is certain");
        return;
    };

    // --- P1: radios ---------------------------------------------------------
    let mut radios: Vec<HANDLE> = Vec::new();
    {
        let mut params = BLUETOOTH_FIND_RADIO_PARAMS {
            dwSize: std::mem::size_of::<BLUETOOTH_FIND_RADIO_PARAMS>() as u32,
        };
        let mut hradio: HANDLE = ptr::null_mut();
        let t0 = now_ms();
        let find = unsafe { api.first_radio(&mut params, &mut hradio) };
        let dt0 = now_ms() - t0;
        if find.is_null() {
            out.line_fmt(format!(
                "probe radios: NONE (GetLastError=0x{:x}) ({dt0} ms) — the stack sees no radio (PnP/driver branch)",
                unsafe { kernel32::GetLastError() }
            ));
        } else {
            while !hradio.is_null() && radios.len() < 4 {
                radios.push(hradio);
                let mut next: HANDLE = ptr::null_mut();
                if !unsafe { api.next_radio(find, &mut next) } {
                    break;
                }
                hradio = next;
            }
            out.line_fmt(format!(
                "probe radios: found={} ({dt0} ms) — 0 means the stack sees no radio at all (PnP/driver branch)",
                radios.len()
            ));
            unsafe { api.close_radio_find(find) };
        }
    }

    // --- P1b/P2/P3 per radio ------------------------------------------------
    for (idx, &r) in radios.iter().enumerate() {
        if let Some(get_info) = api.get_radio_info {
            let mut info = BLUETOOTH_RADIO_INFO::default();
            info.dwSize = std::mem::size_of::<BLUETOOTH_RADIO_INFO>() as u32;
            let t1 = now_ms();
            let rc = unsafe { get_info(r, &mut info) };
            let dt1 = now_ms() - t1;
            if rc == 0 {
                let nm_raw = utf16_field(&info.szName[0..40]);
                let nm = if nm_raw.is_empty() { "(no name)" } else { nm_raw.as_str() };
                let mfr = if info.manufacturer == 15 { "Cambridge Silicon Radio (CSR)" } else { "other" };
                out.line_fmt(format!(
                    "radio[{idx}]: addr={} name=\"{nm}\" manufacturer={} ({mfr}) lmp_subversion=0x{:x} class_of_device=0x{:x} ({dt1} ms) — transport stack<->HCI alive",
                    format_mac(info.Address.ullRemote),
                    info.manufacturer,
                    info.lmpSubversion,
                    info.ulClassofDevice
                ));
            } else {
                out.line_fmt(format!(
                    "radio[{idx}]: GetRadioInfo FAILED 0x{rc:x} ({dt1} ms) — radio handle dead or controller not answering"
                ));
            }
        } else {
            out.line_fmt(format!("radio[{idx}]: GetRadioInfo export missing (probe skipped)"));
        }

        match (api.is_discoverable, api.is_connectable) {
            (Some(discoverable), Some(connectable)) => {
                let t2 = now_ms();
                let d = unsafe { discoverable(r) };
                let d_err = if d != 0 { 0 } else { unsafe { kernel32::GetLastError() } };
                let c = unsafe { connectable(r) };
                let c_err = if c != 0 { 0 } else { unsafe { kernel32::GetLastError() } };
                let dt2 = now_ms() - t2;
                out.line_fmt(format!(
                    "radio[{idx}]: scan state: discoverable={} (err 0x{d_err:x}) connectable={} (err 0x{c_err:x}) ({dt2} ms)",
                    d != 0,
                    c != 0
                ));
            }
            _ => out.line_fmt(format!("radio[{idx}]: scan-state exports missing (probe skipped)")),
        }

        // P3 — the exact R1 call. THE decisive probe.
        if let Some(enable_incoming) = api.enable_incoming {
            let t3 = now_ms();
            let d_ok = unsafe { enable_incoming(r, 0) } != 0;
            let dt3 = now_ms() - t3;
            let d_err = if d_ok { 0 } else { unsafe { kernel32::GetLastError() } };
            let t4 = now_ms();
            let mut en_ok = false;
            let mut en_err = 0u32;
            let mut tries = 0u32;
            while tries < R1_REENABLE_ATTEMPTS {
                if unsafe { enable_incoming(r, 1) } != 0 {
                    en_ok = true;
                    break;
                }
                en_err = unsafe { kernel32::GetLastError() };
                unsafe { kernel32::Sleep(R1_REENABLE_RETRY_MS) };
                tries += 1;
            }
            let dt4 = now_ms() - t4;
            if d_ok && en_ok {
                out.line_fmt(format!(
                    "radio[{idx}]: probe scan-write: disable=OK ({dt3} ms) enable=OK ({dt4} ms, tries={}) — controller ACCEPTS scan-mode writes (R1 call works NOW)",
                    tries + 1
                ));
            } else {
                out.line_fmt(format!(
                    "radio[{idx}]: probe scan-write: disable={}/0x{d_err:x} ({dt3} ms) enable={en_ok}/0x{en_err:x} ({dt4} ms, tries={}) — REJECTED (0x80070057 here = the field-known CSR signature)",
                    d_ok,
                    tries + 1
                ));
            }
        } else {
            out.line_fmt(format!("radio[{idx}]: BluetoothEnableIncomingConnections missing (probe skipped)"));
        }
    }

    // --- P4: device cache ---------------------------------------------------
    if let Some(tm) = target_mac {
        if let Some(&radio) = radios.first() {
            let mut search = BLUETOOTH_DEVICE_SEARCH_PARAMS {
                dwSize: std::mem::size_of::<BLUETOOTH_DEVICE_SEARCH_PARAMS>() as u32,
                fReturnAuthenticated: 1,
                fReturnRemembered: 1,
                fReturnUnknown: 0,
                fReturnConnected: 1,
                fIssueInquiry: 0,
                cTimeoutMultiplier: 0,
                hRadio: radio,
            };
            let mut di = empty_device_info();
            let t5 = now_ms();
            let find = unsafe { api.first_device(&mut search, &mut di) };
            let dt5 = now_ms() - t5;
            if find.is_null() {
                out.line_fmt(format!(
                    "device cache: EMPTY/unavailable (GetLastError=0x{:x}) ({dt5} ms)",
                    unsafe { kernel32::GetLastError() }
                ));
            } else {
                let mut total: usize = 0;
                let mut matched = false;
                loop {
                    total += 1;
                    if di.Address.ullRemote == tm {
                        matched = true;
                        let nm_raw = utf16_field(&di.szName[0..40]);
                        let nm = if nm_raw.is_empty() { "(no name)" } else { nm_raw.as_str() };
                        out.line_fmt(format!(
                            "device target: connected={} remembered={} authenticated={} name=\"{nm}\" — visible to the stack at BT level",
                            di.fConnected != 0,
                            di.fRemembered != 0,
                            di.fAuthenticated != 0
                        ));
                    }
                    di = empty_device_info();
                    if !unsafe { api.next_device(find, &mut di) } {
                        break;
                    }
                }
                out.line_fmt(format!(
                    "device cache: {total} known devices scanned, target {} ({dt5} ms)",
                    if matched { "FOUND" } else { "NOT-IN-CACHE" }
                ));
                unsafe { api.close_device_find(find) };
            }
        }
    }

    // --- P5: audio endpoints ------------------------------------------------
    match class_devs(Some(&GUID_DEVCLASS_AUDIOENDPOINT), None, DIGCF_PRESENT) {
        Ok(devs) => {
            let mut count = 0usize;
            let mut index = 0u32;
            while index < 256 {
                let mut info = crate::pnp::devnode::sp_devinfo_data();
                if unsafe { SetupDiEnumDeviceInfo(devs.handle(), index, &mut info) } == 0 {
                    break;
                }
                count += 1;
                index += 1;
            }
            out.line_fmt(format!(
                "endpoints: AudioEndpoint devnodes present={count}(+headset when linked) ({} ms) — the CSV column measures the same thing",
                now_ms() - t_start
            ));
        }
        Err(err) => out.line_fmt(format!("endpoints: SetupDiGetClassDevsW failed 0x{err:x}")),
    }

    out.line("verdict: diff healthy-run vs wedged-run — probes that CHANGE are the wedge fingerprint; scan-write 0x80070057 while wedged but OK when healthy => wedge lives in the CSR controller command path (usb-cycle is the cure); 0x80070057 in BOTH runs => R1 is dead on this dongle, usb-cycle is the only software rung; probe latencies >1000 ms => transport stalling");
    out.line("verdict2: wedged-run with ALL probes <100 ms but target connected=false => quiet CSR wedge: the controller answers commands yet will not establish the link; the cure is a radio re-init (--cycle) or physical replug (power cut); a BTHUSB id=3 warning storm in the System log is the usual precursor");
    out.line_fmt(format!("health: done ({} ms total)", now_ms() - t_start));

    for r in radios {
        unsafe { kernel32::CloseHandle(r) };
    }
}
