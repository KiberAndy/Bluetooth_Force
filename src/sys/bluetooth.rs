//! Bluetooth Classic types shared by the bthprops.cpl loader.
//!
//! The functions themselves are resolved dynamically at runtime (see
//! [`crate::bluetooth`]); only the structures and constants live here.

use super::*;

pub const BLUETOOTH_SERVICE_ENABLE: u32 = 0x0000_0001;
pub const BLUETOOTH_SERVICE_DISABLE: u32 = 0x0000_0000;

/// `ERROR_SERVICE_DOES_NOT_EXIST`: the remote device has no such profile.
pub const ERROR_SERVICE_DOES_NOT_EXIST: u32 = 1060;

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct BLUETOOTH_ADDRESS {
    pub ullRemote: u64,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct BLUETOOTH_DEVICE_INFO {
    pub dwSize: u32,
    pub Address: BLUETOOTH_ADDRESS,
    pub ulClassofDevice: u32,
    pub fConnected: i32,
    pub fRemembered: i32,
    pub fAuthenticated: i32,
    pub stLastSeen: SYSTEMTIME,
    pub stLastUsed: SYSTEMTIME,
    pub szName: [u16; 248],
}

impl Default for BLUETOOTH_DEVICE_INFO {
    fn default() -> Self {
        // SAFETY: POD; the caller sets `dwSize` before every call.
        unsafe { std::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct BLUETOOTH_DEVICE_SEARCH_PARAMS {
    pub dwSize: u32,
    pub fReturnAuthenticated: i32,
    pub fReturnRemembered: i32,
    pub fReturnUnknown: i32,
    pub fReturnConnected: i32,
    pub fIssueInquiry: i32,
    pub cTimeoutMultiplier: u8,
    pub hRadio: HANDLE,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct BLUETOOTH_FIND_RADIO_PARAMS {
    pub dwSize: u32,
}

/// Win32 `BLUETOOTH_RADIO_INFO`. The 8-byte alignment of the address field pads
/// `dwSize` by 4, so `size_of` == 520 (pinned by a test).
#[repr(C)]
#[derive(Clone, Copy)]
pub struct BLUETOOTH_RADIO_INFO {
    pub dwSize: u32,
    pub Address: BLUETOOTH_ADDRESS,
    pub szName: [u16; 248],
    pub ulClassofDevice: u32,
    pub lmpSubversion: u16,
    pub manufacturer: u16,
}

impl Default for BLUETOOTH_RADIO_INFO {
    fn default() -> Self {
        // SAFETY: POD; the caller sets `dwSize` before every call.
        unsafe { std::mem::zeroed() }
    }
}
