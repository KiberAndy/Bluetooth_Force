//! R4 — hub port power-cycle.
//!
//! The rung above the usb-cycle. A verified PnP restart that still leaves the
//! link down means the wedge lives below the USB HCI function, where only a VBUS
//! drop reaches. `IOCTL_USB_HUB_CYCLE_PORT` simulates a physical unplug/replug
//! on the CSR dongle's port alone: every other USB device is untouched.

use std::ffi::c_void;
use std::ptr;

use crate::config::*;
use crate::output::HealthOut;
use crate::pnp::devnode::*;
use crate::pnp::recovery;
use crate::state::SharedState;
use crate::sys::kernel32::{self, FILE_SHARE_READ, FILE_SHARE_WRITE, GENERIC_WRITE, OPEN_EXISTING};
use crate::sys::setupapi::*;
use crate::sys::{HANDLE, HDEVINFO};
use crate::btlog;

/// 8-byte aligned stack buffer for the SetupAPI / IOCTL replies.
#[repr(align(8))]
struct Align8<const N: usize>([u8; N]);

/// Minimal prefix of `USB_NODE_INFORMATION` (hub variant).
#[repr(C)]
struct UsbNodeInfoPrefix {
    NodeType: u32,
    bDescLength: u8,
    bDescriptorType: u8,
    bNbrPorts: u8,
}

/// Prefix of `USB_NODE_CONNECTION_INFORMATION_EX` (the `PipeList` tail is
/// variable-length; we only ever read the prefix). Natural C layout, 36 bytes.
#[repr(C)]
struct UsbConnInfoPrefix {
    ConnectionIndex: u32,
    bLength: u8,
    bDescriptorType: u8,
    bcdUSB: u16,
    bDeviceClass: u8,
    bDeviceSubClass: u8,
    bDeviceProtocol: u8,
    bMaxPacketSize0: u8,
    idVendor: u16,
    idProduct: u16,
    bcdDevice: u16,
    iManufacturer: u8,
    iProduct: u8,
    iSerialNumber: u8,
    bNumConfigurations: u8,
    CurrentConfigValue: u8,
    Speed: u8,
    DeviceIsHub: u8,
    DeviceAddress: u16,
    NumberOfOpenPipes: u32,
    ConnectionStatus: u32,
}

const USB_CONN_INFO_SIZE: usize = std::mem::size_of::<UsbConnInfoPrefix>();

#[repr(C)]
struct UsbCyclePortParams {
    ConnectionIndex: u32,
    StatusReturned: u32,
}

/// Close a raw handle on scope exit.
struct HandleGuard(HANDLE);
impl Drop for HandleGuard {
    fn drop(&mut self) {
        if !self.0.is_null() && self.0 != crate::sys::INVALID_HANDLE_VALUE {
            unsafe { kernel32::CloseHandle(self.0) };
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HubWalkMode {
    Probe,
    Cycle,
}

#[derive(Default)]
pub struct HubWalkResult {
    pub hubs: u32,
    pub ports: u32,
    pub cycled: bool,
}

/// Decode the power-switching mode from `wHubCharacteristics`.
///
/// Only "individual" hubs have a per-port switch a program can toggle; "ganged"
/// switches all ports at once; "none" is hard-wired VBUS.
pub fn hub_power_mode(chars: u16) -> &'static str {
    match chars & 3 {
        0 => "ganged",
        1 => "individual",
        _ => "none",
    }
}

/// Auto-ladder entry for R4.
pub fn hub_port_cycle_radio(state: &mut SharedState) -> bool {
    if !is_user_admin() {
        if !state.r4_admin_skip_logged {
            state.r4_admin_skip_logged = true;
            btlog!("rung hub-port-cycle: skipped (admin required) — run from diagnose.ps1 or an elevated shell");
        }
        return false;
    }
    let out = HealthOut::debug_only("rung hub-port-cycle");
    cycle_csr_hub_port_once(&out)
}

/// The port-cycle core, shared by the auto-ladder rung and `--probe-hubs`.
pub fn cycle_csr_hub_port_once(out: &HealthOut) -> bool {
    out.line("begin");
    let Some(id) = find_csr_instance_id() else {
        out.line("CSR radio USB\\VID_0A12&PID_0001 not present, port cycle aborted");
        return false;
    };
    // Journal BEFORE anything that tears the devnode down, so a cycle whose
    // re-enumeration never arrives is still repaired by instance ID.
    if !recovery::journal_arm(id.as_str()) {
        out.line_fmt(format!(
            "cannot write {RECOVERY_JOURNAL_NAME} next to the exe -- REFUSING the port cycle (an unrepairable radio is worse than a wedge)"
        ));
        return false;
    }

    let w = walk_hub_ports(out, HubWalkMode::Cycle);
    if !w.cycled {
        out.line_fmt(format!(
            "dongle present as a devnode but on no scanned hub port (hubs={}, ports={}) -- nothing touched",
            w.hubs, w.ports
        ));
        recovery::journal_disarm();
        return false;
    }

    // The receipt is not the state change: poll for re-enumeration.
    let mut waited = 0u32;
    loop {
        if find_csr_instance_id().is_some() {
            recovery::journal_disarm();
            out.line("complete (hub port cycled, dongle re-enumerated)");
            return true;
        }
        if waited >= R4_REENUM_VERIFY_MS {
            break;
        }
        unsafe { kernel32::Sleep(R4_REENUM_POLL_MS) };
        waited += R4_REENUM_POLL_MS;
    }
    out.line_fmt(format!(
        "port cycled but the dongle did not re-enumerate within {} ms -- journal LEFT ARMED, the repair rung keeps retrying",
        R4_REENUM_VERIFY_MS
    ));
    false // journal deliberately LEFT ARMED
}

/// Walk every present USB hub, port by port, through the hub PDO.
pub fn walk_hub_ports(out: &HealthOut, mode: HubWalkMode) -> HubWalkResult {
    let mut r = HubWalkResult::default();

    let devs = match class_devs(Some(&GUID_DEVINTERFACE_USB_HUB), None, DIGCF_PRESENT | DIGCF_DEVICEINTERFACE) {
        Ok(d) => d,
        Err(err) => {
            out.line_fmt(format!("SetupDiGetClassDevsW(USB_HUB) failed 0x{err:x}"));
            return r;
        }
    };

    let mut index = 0u32;
    loop {
        let mut iface = SP_DEVICE_INTERFACE_DATA::default();
        iface.cbSize = std::mem::size_of::<SP_DEVICE_INTERFACE_DATA>() as u32;
        let ok = unsafe {
            SetupDiEnumDeviceInterfaces(
                devs.handle(),
                ptr::null_mut(),
                &GUID_DEVINTERFACE_USB_HUB,
                index,
                &mut iface,
            )
        };
        if ok == 0 {
            // index 0 failing is either an empty set (benign) or a real
            // rejection — log it, never break silently.
            if index == 0 {
                out.line_fmt(format!("hub enum at index 0 failed 0x{:x}", unsafe { kernel32::GetLastError() }));
            }
            break;
        }

        r.hubs += 1;
        let hub_no = r.hubs;
        if walk_one_hub(devs.handle(), &mut iface, hub_no, out, mode, &mut r) {
            break;
        }
        index += 1;
    }
    r
}

/// Returns `true` when the walk should stop (a port was cycled).
fn walk_one_hub(
    devs: HDEVINFO,
    iface: &mut SP_DEVICE_INTERFACE_DATA,
    hub_no: u32,
    out: &HealthOut,
    mode: HubWalkMode,
    r: &mut HubWalkResult,
) -> bool {
    let mut detail = Align8::<2048>([0u8; 2048]);
    let buf = &mut detail.0;

    let mut req = 0u32;
    unsafe {
        SetupDiGetDeviceInterfaceDetailW(devs, iface, ptr::null_mut(), 0, &mut req, ptr::null_mut());
    }
    if req as usize <= IFDETAIL_PATH_OFFSET || req as usize > buf.len() {
        out.line_fmt(format!("hub #{hub_no}: interface path query failed, skipped"));
        return false;
    }
    buf[0..4].copy_from_slice(&IFDETAIL_CB_SIZE_X64.to_le_bytes());
    let ok = unsafe {
        SetupDiGetDeviceInterfaceDetailW(
            devs,
            iface,
            buf.as_mut_ptr() as *mut c_void,
            req,
            ptr::null_mut(),
            ptr::null_mut(),
        )
    };
    if ok == 0 {
        out.line_fmt(format!(
            "hub #{hub_no}: interface path read failed 0x{:x}, skipped",
            unsafe { kernel32::GetLastError() }
        ));
        return false;
    }

    let path_n = (req as usize - IFDETAIL_PATH_OFFSET) / 2;
    if path_n == 0 || path_n >= 1024 {
        return false;
    }
    let mut path_z = [0u16; 1024];
    for i in 0..path_n {
        let lo = buf[IFDETAIL_PATH_OFFSET + i * 2] as u16;
        let hi = buf[IFDETAIL_PATH_OFFSET + i * 2 + 1] as u16;
        path_z[i] = lo | (hi << 8);
    }
    path_z[path_n] = 0;

    let hub = unsafe {
        kernel32::CreateFileW(
            path_z.as_ptr(),
            GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            ptr::null_mut(),
            OPEN_EXISTING,
            0,
            ptr::null_mut(),
        )
    };
    if hub.is_null() || hub == crate::sys::INVALID_HANDLE_VALUE {
        out.line_fmt(format!(
            "hub #{hub_no}: open failed 0x{:x}, skipped",
            unsafe { kernel32::GetLastError() }
        ));
        return false;
    }
    let _hub_guard = HandleGuard(hub);

    let mut node = Align8::<512>([0u8; 512]);
    let node_buf = &mut node.0;
    let mut ret = 0u32;
    let io = unsafe {
        kernel32::DeviceIoControl(
            hub,
            IOCTL_USB_GET_NODE_INFORMATION,
            ptr::null(),
            0,
            node_buf.as_mut_ptr() as *mut c_void,
            node_buf.len() as u32,
            &mut ret,
            ptr::null_mut(),
        )
    };
    if io == 0 {
        out.line_fmt(format!(
            "hub #{hub_no}: GET_NODE_INFORMATION failed 0x{:x}, skipped",
            unsafe { kernel32::GetLastError() }
        ));
        return false;
    }

    let node_info = unsafe { &*(node_buf.as_ptr() as *const UsbNodeInfoPrefix) };
    if node_info.NodeType != USB_HUB_NODE || node_info.bNbrPorts == 0 || node_info.bNbrPorts > 32 {
        out.line_fmt(format!(
            "hub #{hub_no}: not a hub node (type={}, ports={}), skipped",
            node_info.NodeType, node_info.bNbrPorts
        ));
        return false;
    }

    let hub_chars = u16::from_le_bytes([node_buf[HUB_CHARS_OFFSET], node_buf[HUB_CHARS_OFFSET + 1]]);
    out.line_fmt(format!(
        "hub #{hub_no}: ports={}, power-switching={} (wHubCharacteristics=0x{:x})",
        node_info.bNbrPorts,
        hub_power_mode(hub_chars),
        hub_chars
    ));

    for port in 1..=node_info.bNbrPorts as u32 {
        r.ports += 1;
        let mut conn = Align8::<2048>([0u8; 2048]);
        let conn_buf = &mut conn.0;
        conn_buf[0..4].copy_from_slice(&port.to_le_bytes());

        let mut got = 0u32;
        let mut is_ex = false;
        let ex_ok = unsafe {
            kernel32::DeviceIoControl(
                hub,
                IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX,
                conn_buf.as_ptr() as *const c_void,
                USB_CONN_INFO_SIZE as u32,
                conn_buf.as_mut_ptr() as *mut c_void,
                conn_buf.len() as u32,
                &mut got,
                ptr::null_mut(),
            )
        } != 0
            && got as usize >= USB_CONN_INFO_SIZE;

        let mut ok = ex_ok;
        if ex_ok {
            is_ex = true;
        } else {
            // EX unsupported here (xHCI root hub): retry the non-EX variant.
            got = 0;
            let nonex_ok = unsafe {
                kernel32::DeviceIoControl(
                    hub,
                    IOCTL_USB_GET_NODE_CONNECTION_INFORMATION,
                    conn_buf.as_ptr() as *const c_void,
                    USB_CONN_INFO_SIZE as u32,
                    conn_buf.as_mut_ptr() as *mut c_void,
                    conn_buf.len() as u32,
                    &mut got,
                    ptr::null_mut(),
                )
            } != 0
                && got as usize >= USB_CONN_INFO_SIZE;
            ok = nonex_ok;
            if nonex_ok && mode == HubWalkMode::Probe {
                out.line_fmt(format!("hub #{hub_no} port {port}: EX failed, non-EX reply ({got} bytes)"));
            }
        }

        if !ok {
            if mode == HubWalkMode::Probe {
                out.line_fmt(format!(
                    "hub #{hub_no} port {port}: port query failed 0x{:x}",
                    unsafe { kernel32::GetLastError() }
                ));
            }
            continue;
        }

        let info = unsafe { &*(conn_buf.as_ptr() as *const UsbConnInfoPrefix) };
        // EX replies carry ConnectionStatus at 32; non-EX packs tighter, at 31.
        let status = if is_ex {
            info.ConnectionStatus
        } else {
            u32::from_le_bytes([
                conn_buf[NONEX_CONN_STATUS_OFFSET],
                conn_buf[NONEX_CONN_STATUS_OFFSET + 1],
                conn_buf[NONEX_CONN_STATUS_OFFSET + 2],
                conn_buf[NONEX_CONN_STATUS_OFFSET + 3],
            ])
        };

        if mode == HubWalkMode::Probe {
            let marker = if info.idVendor == CSR_VID && info.idProduct == CSR_PID {
                " <-- CSR DONGLE"
            } else {
                ""
            };
            out.line_fmt(format!(
                "hub #{hub_no} port {port}: status={status} vid_{:04x}&pid_{:04x}{marker}",
                info.idVendor, info.idProduct
            ));
        }

        if status != USB_DEVICE_CONNECTED {
            continue;
        }
        let is_csr = info.idVendor == CSR_VID && info.idProduct == CSR_PID;
        if mode == HubWalkMode::Probe {
            continue;
        }
        if !is_csr {
            continue;
        }

        out.line_fmt(format!(
            "CSR dongle on hub #{hub_no} port {port}: sending IOCTL_USB_HUB_CYCLE_PORT..."
        ));
        let mut params = UsbCyclePortParams { ConnectionIndex: port, StatusReturned: 0 };
        let mut pret = 0u32;
        let cyc = unsafe {
            kernel32::DeviceIoControl(
                hub,
                IOCTL_USB_HUB_CYCLE_PORT,
                &params as *const _ as *const c_void,
                std::mem::size_of::<UsbCyclePortParams>() as u32,
                &mut params as *mut _ as *mut c_void,
                std::mem::size_of::<UsbCyclePortParams>() as u32,
                &mut pret,
                ptr::null_mut(),
            )
        };
        if cyc == 0 {
            out.line_fmt(format!("HUB_CYCLE_PORT failed 0x{:x}", unsafe { kernel32::GetLastError() }));
            return false;
        }
        out.line_fmt(format!("port {port} cycled (status={})", params.StatusReturned));
        r.cycled = true;
        return true;
    }
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ioctl_and_layout_constants() {
        assert_eq!(IOCTL_USB_GET_NODE_INFORMATION, 0x220408);
        assert_eq!(IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX, 0x220484);
        assert_eq!(IOCTL_USB_HUB_CYCLE_PORT, 0x220488);
        assert_eq!(USB_CONN_INFO_SIZE, 36);
        assert_eq!(std::mem::offset_of!(UsbConnInfoPrefix, idVendor), 12);
        assert_eq!(std::mem::offset_of!(UsbConnInfoPrefix, ConnectionStatus), 32);
        assert_eq!(std::mem::offset_of!(UsbNodeInfoPrefix, bNbrPorts), 6);
        assert_eq!(std::mem::size_of::<UsbCyclePortParams>(), 8);
    }

    #[test]
    fn power_modes() {
        assert_eq!(hub_power_mode(0x0000), "ganged");
        assert_eq!(hub_power_mode(0x0001), "individual");
        assert_eq!(hub_power_mode(0x0002), "none");
        assert_eq!(hub_power_mode(0x0003), "none");
    }
}
