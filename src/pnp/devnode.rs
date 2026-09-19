//! Shared PnP primitives: devnode status predicates, the verified enable path,
//! SetupAPI set ownership, instance-ID decoding and hidden process spawning.

use std::ptr;

use crate::config::*;
use crate::ladder::{devnode_status_means_disabled, devnode_status_means_started, radio_needs_repair};
use crate::output::HealthOut;
use crate::sys::cfgmgr32::*;
use crate::sys::kernel32::{self, CREATE_NO_WINDOW, PROCESS_INFORMATION, STARTUPINFOW, WAIT_OBJECT_0};
use crate::sys::setupapi::*;
use crate::sys::shell32;
use crate::sys::{DEVINST, GUID, HDEVINFO, INVALID_HANDLE_VALUE};
use crate::util;

/// Owning wrapper so a `SetupDi*` set is always destroyed on every return path.
pub struct DevInfoSet(HDEVINFO);

impl DevInfoSet {
    pub fn handle(&self) -> HDEVINFO {
        self.0
    }
}

impl Drop for DevInfoSet {
    fn drop(&mut self) {
        unsafe { SetupDiDestroyDeviceInfoList(self.0) };
    }
}

/// `SetupDiGetClassDevsW` reports failure through `INVALID_HANDLE_VALUE`, not
/// null, so an `is_null()` check alone would accept the -1 handle and then fail
/// silently on every enumeration.
pub fn class_devs(
    guid: Option<&GUID>,
    enumerator: Option<&[u16]>,
    flags: u32,
) -> Result<DevInfoSet, u32> {
    let gp = guid.map_or(ptr::null(), |g| g as *const GUID);
    let ep = enumerator.map_or(ptr::null(), |e| e.as_ptr());
    let h = unsafe { SetupDiGetClassDevsW(gp, ep, ptr::null_mut(), flags) };
    if h.is_null() || h == INVALID_HANDLE_VALUE {
        Err(unsafe { kernel32::GetLastError() })
    } else {
        Ok(DevInfoSet(h))
    }
}

pub fn sp_devinfo_data() -> SP_DEVINFO_DATA {
    let mut info = SP_DEVINFO_DATA::default();
    info.cbSize = std::mem::size_of::<SP_DEVINFO_DATA>() as u32;
    info
}

/// A lowercased ASCII device instance ID (PnP IDs are ASCII).
#[derive(Clone, Copy)]
pub struct InstanceId {
    buf: [u8; 220],
    len: usize,
}

impl InstanceId {
    pub fn as_str(&self) -> &str {
        std::str::from_utf8(&self.buf[..self.len]).unwrap_or("")
    }
}

pub fn device_instance_id(devs: HDEVINFO, info: &mut SP_DEVINFO_DATA) -> Option<InstanceId> {
    let mut wide = [0u16; 220];
    let ok = unsafe {
        SetupDiGetDeviceInstanceIdW(devs, info, wide.as_mut_ptr(), wide.len() as u32, ptr::null_mut())
    };
    if ok == 0 {
        return None;
    }
    let n = wide.iter().position(|&c| c == 0).unwrap_or(wide.len());
    if n == 0 || n > 220 {
        return None;
    }
    let mut buf = [0u8; 220];
    for i in 0..n {
        buf[i] = util::ascii_lower(wide[i] as u8);
    }
    Some(InstanceId { buf, len: n })
}

/// Locate the CSR dongle's USB instance ID.
pub fn find_csr_instance_id() -> Option<InstanceId> {
    let devs = class_devs(None, Some(&ENUMERATOR_USB[..]), DIGCF_PRESENT | DIGCF_ALLCLASSES).ok()?;
    let mut index = 0u32;
    loop {
        let mut info = sp_devinfo_data();
        if unsafe { SetupDiEnumDeviceInfo(devs.handle(), index, &mut info) } == 0 {
            break;
        }
        if let Some(id) = device_instance_id(devs.handle(), &mut info) {
            if crate::mac::is_csr_radio_instance_id(id.as_str()) {
                return Some(id);
            }
        }
        index += 1;
    }
    None
}

pub fn is_user_admin() -> bool {
    unsafe { shell32::IsUserAnAdmin() != 0 }
}

pub fn devnode_status(devinst: DEVINST) -> Option<(u32, u32)> {
    let mut status = 0u32;
    let mut problem = 0u32;
    let cr = unsafe { CM_Get_DevNode_Status(&mut status, &mut problem, devinst, 0) };
    if cr == CR_SUCCESS { Some((status, problem)) } else { None }
}

pub fn devnode_started(devinst: DEVINST) -> bool {
    matches!(devnode_status(devinst), Some((s, p)) if devnode_status_means_started(s, p))
}

pub fn devnode_disabled(devinst: DEVINST) -> bool {
    matches!(devnode_status(devinst), Some((s, p)) if devnode_status_means_disabled(s, p))
}

/// A failed status query is treated as "no repair": the node is most likely
/// gone, and guessing would make us enable the wrong device.
pub fn devnode_needs_repair(devinst: DEVINST, journal_armed: bool) -> bool {
    match devnode_status(devinst) {
        Some((s, p)) => radio_needs_repair(s, p, journal_armed),
        None => false,
    }
}

/// Poll until the devnode shows the started state (or the timeout expires).
pub fn wait_devnode_started(devinst: DEVINST, timeout_ms: u32) -> bool {
    let mut waited = 0u32;
    loop {
        if devnode_started(devinst) {
            return true;
        }
        if waited >= timeout_ms {
            return false;
        }
        unsafe { kernel32::Sleep(R2_REENUM_POLL_MS) };
        waited += R2_REENUM_POLL_MS;
    }
}

/// Poll until the devnode shows the software-disabled state (or timeout).
pub fn wait_devnode_disabled(devinst: DEVINST, timeout_ms: u32) -> bool {
    let mut waited = 0u32;
    loop {
        if devnode_disabled(devinst) {
            return true;
        }
        if waited >= timeout_ms {
            return false;
        }
        unsafe { kernel32::Sleep(R2_REENUM_POLL_MS) };
        waited += R2_REENUM_POLL_MS;
    }
}

/// One `DIF_PROPERTYCHANGE` pass (enable or disable) on a devnode.
pub fn usb_prop_change(devs: HDEVINFO, info: &mut SP_DEVINFO_DATA, state_change: u32) -> bool {
    let mut params = SP_PROPCHANGE_PARAMS {
        ClassInstallHeader: SP_CLASSINSTALL_HEADER {
            cbSize: std::mem::size_of::<SP_CLASSINSTALL_HEADER>() as u32,
            InstallFunction: DIF_PROPERTYCHANGE,
        },
        StateChange: state_change,
        Scope: DICS_FLAG_GLOBAL,
        HwProfile: 0,
    };
    let set = unsafe {
        SetupDiSetClassInstallParamsW(
            devs,
            info,
            &mut params.ClassInstallHeader,
            std::mem::size_of::<SP_PROPCHANGE_PARAMS>() as u32,
        )
    };
    if set == 0 {
        return false;
    }
    unsafe { SetupDiCallClassInstaller(DIF_PROPERTYCHANGE, devs, info) != 0 }
}

/// Verified enable of one devnode.
///
/// Both mechanisms run SEQUENTIALLY per attempt (a short-circuit `or` never
/// reaches `CM_Enable_DevNode` exactly when it is needed), and each is judged by
/// the devnode status — a `DICS_ENABLE` receipt is not an enable.
pub fn enable_devnode_verified(
    devs: HDEVINFO,
    info: &mut SP_DEVINFO_DATA,
    out: &HealthOut,
) -> bool {
    let mut attempt = 0u32;
    while attempt < R1_REENABLE_ATTEMPTS {
        if attempt > 0 {
            unsafe { kernel32::Sleep(R1_REENABLE_RETRY_MS * 2) };
        }

        if usb_prop_change(devs, info, DICS_ENABLE) {
            if wait_devnode_started(info.DevInst, R3_VERIFY_MS) {
                return true;
            }
            out.line_fmt(format!(
                "  enable {}/{}: DICS_ENABLE accepted but not STARTED in {} ms — trying CM_Enable_DevNode",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                R3_VERIFY_MS
            ));
        } else {
            out.line_fmt(format!(
                "  enable {}/{}: DICS_ENABLE rejected 0x{:x} — trying CM_Enable_DevNode",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                unsafe { kernel32::GetLastError() }
            ));
        }

        if unsafe { CM_Enable_DevNode(info.DevInst, 0) } == CR_SUCCESS {
            if wait_devnode_started(info.DevInst, R3_VERIFY_MS) {
                return true;
            }
            out.line_fmt(format!(
                "  enable {}/{}: CM_Enable_DevNode accepted but not STARTED in {} ms",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                R3_VERIFY_MS
            ));
        } else {
            out.line_fmt(format!(
                "  enable {}/{}: CM_Enable_DevNode failed 0x{:x}",
                attempt + 1,
                R1_REENABLE_ATTEMPTS,
                unsafe { kernel32::GetLastError() }
            ));
        }
        attempt += 1;
    }
    false
}

/// Run a command line hidden and wait for it. Returns the exit code, or `None`
/// if the spawn failed or the timeout expired.
///
/// NO `TerminateProcess` on timeout: killing `pnputil` mid-PnP-operation is how
/// a devnode gets left half-installed. A timed-out child is reported and left
/// alone; the caller falls back to the in-process path.
pub fn run_hidden_wait(cmdline: &str, timeout_ms: u32) -> Option<u32> {
    let mut cmd: Vec<u16> = cmdline.encode_utf16().collect();
    if cmd.len() > 2046 {
        return None;
    }
    cmd.push(0);

    let mut si = STARTUPINFOW::default();
    si.cb = std::mem::size_of::<STARTUPINFOW>() as u32;
    let mut pi = PROCESS_INFORMATION::default();

    let ok = unsafe {
        kernel32::CreateProcessW(
            ptr::null(),
            cmd.as_mut_ptr(),
            ptr::null_mut(),
            ptr::null_mut(),
            0,
            CREATE_NO_WINDOW,
            ptr::null_mut(),
            ptr::null(),
            &mut si,
            &mut pi,
        )
    };
    if ok == 0 {
        crate::btlog!("R3: CreateProcessW failed 0x{:x}", unsafe { kernel32::GetLastError() });
        return None;
    }
    unsafe { kernel32::CloseHandle(pi.hThread) };

    let wait = unsafe { kernel32::WaitForSingleObject(pi.hProcess, timeout_ms) };
    if wait != WAIT_OBJECT_0 {
        unsafe { kernel32::CloseHandle(pi.hProcess) };
        return None;
    }
    let mut exit_code = 0u32;
    unsafe {
        kernel32::GetExitCodeProcess(pi.hProcess, &mut exit_code);
        kernel32::CloseHandle(pi.hProcess);
    }
    Some(exit_code)
}
