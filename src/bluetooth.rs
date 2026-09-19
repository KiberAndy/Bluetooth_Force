//! Runtime loader for the Bluetooth Classic API exported by `bthprops.cpl`.
//!
//! The library is loaded strictly from System32 so a same-named hijack in the
//! application directory or CWD can never be picked up instead of the system
//! copy. Optional exports resolve to `None` and only disable the feature they
//! back, never the whole daemon.

use crate::sys::bluetooth::*;
use crate::sys::kernel32;
use crate::sys::{BOOL, FARPROC, HANDLE, HMODULE, LOAD_LIBRARY_SEARCH_SYSTEM32};
use crate::util;

type FnFindFirstRadio = unsafe extern "system" fn(*mut BLUETOOTH_FIND_RADIO_PARAMS, *mut HANDLE) -> HANDLE;
type FnFindNextRadio = unsafe extern "system" fn(HANDLE, *mut HANDLE) -> BOOL;
type FnFindRadioClose = unsafe extern "system" fn(HANDLE) -> BOOL;
type FnFindFirstDevice =
    unsafe extern "system" fn(*mut BLUETOOTH_DEVICE_SEARCH_PARAMS, *mut BLUETOOTH_DEVICE_INFO) -> HANDLE;
type FnFindNextDevice = unsafe extern "system" fn(HANDLE, *mut BLUETOOTH_DEVICE_INFO) -> BOOL;
type FnFindDeviceClose = unsafe extern "system" fn(HANDLE) -> BOOL;
type FnEnableIncoming = unsafe extern "system" fn(HANDLE, i32) -> BOOL;
type FnGetRadioInfo = unsafe extern "system" fn(HANDLE, *mut BLUETOOTH_RADIO_INFO) -> u32;
type FnIsDiscoverable = unsafe extern "system" fn(HANDLE) -> BOOL;
type FnIsConnectable = unsafe extern "system" fn(HANDLE) -> BOOL;
type FnSetServiceState =
    unsafe extern "system" fn(HANDLE, *const BLUETOOTH_DEVICE_INFO, *const crate::sys::GUID, u32) -> u32;

fn load_sym<T: Copy>(module: HMODULE, name: &str) -> Option<T> {
    let cname = format!("{name}\0");
    let p: FARPROC = unsafe { kernel32::GetProcAddress(module, cname.as_ptr()) };
    if p.is_null() {
        None
    } else {
        // SAFETY: the caller asserts (by the `T` it asks for) that the export has
        // this exact signature. Function pointers and `FARPROC` share a width.
        Some(unsafe { std::mem::transmute_copy::<FARPROC, T>(&p) })
    }
}

pub struct BthApi {
    pub module: HMODULE,
    pub find_first_radio: FnFindFirstRadio,
    pub find_next_radio: FnFindNextRadio,
    pub find_radio_close: FnFindRadioClose,
    pub find_first_device: FnFindFirstDevice,
    pub find_next_device: FnFindNextDevice,
    pub find_device_close: FnFindDeviceClose,
    /// Radio reset ("software re-plug") primitive; optional.
    pub enable_incoming: Option<FnEnableIncoming>,
    /// Connect primitive that replaces the old ToothTray dependency; optional.
    pub set_service_state: Option<FnSetServiceState>,
    pub get_radio_info: Option<FnGetRadioInfo>,
    pub is_discoverable: Option<FnIsDiscoverable>,
    pub is_connectable: Option<FnIsConnectable>,
}

impl Drop for BthApi {
    fn drop(&mut self) {
        if !self.module.is_null() {
            unsafe { kernel32::FreeLibrary(self.module) };
        }
    }
}

impl BthApi {
    /// Load `bthprops.cpl` from System32 and resolve its exports.
    pub fn load() -> Result<Self, &'static str> {
        let name = util::wide("bthprops.cpl");
        let module = unsafe {
            kernel32::LoadLibraryExW(name.as_ptr(), std::ptr::null_mut(), LOAD_LIBRARY_SEARCH_SYSTEM32)
        };
        if module.is_null() {
            return Err("Failed to load bthprops.cpl");
        }

        let find_first_radio = load_sym(module, "BluetoothFindFirstRadio")
            .ok_or("BluetoothFindFirstRadio missing")?;
        let find_next_radio =
            load_sym(module, "BluetoothFindNextRadio").ok_or("BluetoothFindNextRadio missing")?;
        let find_radio_close =
            load_sym(module, "BluetoothFindRadioClose").ok_or("BluetoothFindRadioClose missing")?;
        let find_first_device =
            load_sym(module, "BluetoothFindFirstDevice").ok_or("BluetoothFindFirstDevice missing")?;
        let find_next_device =
            load_sym(module, "BluetoothFindNextDevice").ok_or("BluetoothFindNextDevice missing")?;
        let find_device_close =
            load_sym(module, "BluetoothFindDeviceClose").ok_or("BluetoothFindDeviceClose missing")?;

        Ok(Self {
            module,
            find_first_radio,
            find_next_radio,
            find_radio_close,
            find_first_device,
            find_next_device,
            find_device_close,
            enable_incoming: load_sym(module, "BluetoothEnableIncomingConnections"),
            set_service_state: load_sym(module, "BluetoothSetServiceState"),
            get_radio_info: load_sym(module, "BluetoothGetRadioInfo"),
            is_discoverable: load_sym(module, "BluetoothIsDiscoverable"),
            is_connectable: load_sym(module, "BluetoothIsConnectable"),
        })
    }

    // -- thin, safe-ish wrappers around the raw exports ----------------------

    pub unsafe fn first_radio(
        &self,
        params: &mut BLUETOOTH_FIND_RADIO_PARAMS,
        out: &mut HANDLE,
    ) -> HANDLE {
        unsafe { (self.find_first_radio)(params, out) }
    }

    pub unsafe fn next_radio(&self, find: HANDLE, out: &mut HANDLE) -> bool {
        unsafe { (self.find_next_radio)(find, out) != 0 }
    }

    pub unsafe fn close_radio_find(&self, find: HANDLE) {
        unsafe { (self.find_radio_close)(find) };
    }

    pub unsafe fn first_device(
        &self,
        params: &mut BLUETOOTH_DEVICE_SEARCH_PARAMS,
        out: &mut BLUETOOTH_DEVICE_INFO,
    ) -> HANDLE {
        unsafe { (self.find_first_device)(params, out) }
    }

    pub unsafe fn next_device(&self, find: HANDLE, out: &mut BLUETOOTH_DEVICE_INFO) -> bool {
        unsafe { (self.find_next_device)(find, out) != 0 }
    }

    pub unsafe fn close_device_find(&self, find: HANDLE) {
        unsafe { (self.find_device_close)(find) };
    }
}

/// Search parameters used by the poll loop: remembered + authenticated +
/// connected devices, no active inquiry (cached records only).
pub fn default_search_params(radio: HANDLE) -> BLUETOOTH_DEVICE_SEARCH_PARAMS {
    BLUETOOTH_DEVICE_SEARCH_PARAMS {
        dwSize: std::mem::size_of::<BLUETOOTH_DEVICE_SEARCH_PARAMS>() as u32,
        fReturnAuthenticated: 1,
        fReturnRemembered: 1,
        fReturnUnknown: 0,
        fReturnConnected: 1,
        fIssueInquiry: 0,
        cTimeoutMultiplier: 1,
        hRadio: radio,
    }
}

/// A freshly-zeroed device record with `dwSize` set (required by the API).
pub fn empty_device_info() -> BLUETOOTH_DEVICE_INFO {
    let mut info = BLUETOOTH_DEVICE_INFO::default();
    info.dwSize = std::mem::size_of::<BLUETOOTH_DEVICE_INFO>() as u32;
    info
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn abi_sizes_match_win32() {
        assert_eq!(std::mem::size_of::<BLUETOOTH_DEVICE_INFO>(), 560);
        let expected_search_params = if std::mem::size_of::<usize>() == 8 { 40 } else { 32 };
        assert_eq!(
            std::mem::size_of::<BLUETOOTH_DEVICE_SEARCH_PARAMS>(),
            expected_search_params
        );
        assert_eq!(std::mem::size_of::<BLUETOOTH_FIND_RADIO_PARAMS>(), 4);
        assert_eq!(std::mem::size_of::<BLUETOOTH_RADIO_INFO>(), 520);
        assert_eq!(std::mem::offset_of!(BLUETOOTH_RADIO_INFO, ulClassofDevice), 512);
    }
}
