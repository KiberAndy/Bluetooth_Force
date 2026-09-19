//! setupapi.dll entry points, SetupAPI structures and the GUIDs/classes the
//! PnP rungs query.

use super::*;

pub const DIGCF_PRESENT: u32 = 0x0000_0002;
pub const DIGCF_ALLCLASSES: u32 = 0x0000_0004;
pub const DIGCF_DEVICEINTERFACE: u32 = 0x0000_0010;

#[repr(C)]
#[derive(Clone, Copy)]
pub struct SP_DEVICE_INTERFACE_DATA {
    pub cbSize: u32,
    pub InterfaceClassGuid: GUID,
    pub Flags: u32,
    pub Reserved: usize,
}

impl Default for SP_DEVICE_INTERFACE_DATA {
    fn default() -> Self {
        // SAFETY: POD.
        unsafe { std::mem::zeroed() }
    }
}

/// Win32 layout: ONLY `cbSize` + `InstallFunction` — 8 bytes. An extra `DevInst`
/// field here shifts every downstream offset and makes
/// `SetupDiSetClassInstallParamsW` reject the blob outright; the devnode is
/// identified by the `SP_DEVINFO_DATA` passed alongside.
#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct SP_CLASSINSTALL_HEADER {
    pub cbSize: u32,
    pub InstallFunction: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct SP_PROPCHANGE_PARAMS {
    pub ClassInstallHeader: SP_CLASSINSTALL_HEADER,
    pub StateChange: u32,
    pub Scope: u32,
    pub HwProfile: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct SP_DEVINFO_DATA {
    pub cbSize: u32,
    pub InterfaceClassGuid: GUID,
    pub DevInst: DEVINST,
    pub Reserved: usize,
}

impl Default for SP_DEVINFO_DATA {
    fn default() -> Self {
        // SAFETY: POD.
        unsafe { std::mem::zeroed() }
    }
}

pub const DIF_PROPERTYCHANGE: u32 = 0x0000_0012;
pub const DICS_ENABLE: u32 = 1;
pub const DICS_DISABLE: u32 = 2;
pub const DICS_FLAG_GLOBAL: u32 = 1;

/// USB device class `{36FC9E60-C465-11CF-8056-444553540000}`.
pub const GUID_DEVCLASS_USB: GUID =
    GUID::from_parts(0x36fc_9e60, 0xc465, 0x11cf, [0x80, 0x56, 0x44, 0x45, 0x53, 0x54, 0x00, 0x00]);

/// AudioEndpoint device setup class `{CD171DE3-70E5-41C9-8AC9-8FF103BA2AA1}`.
pub const GUID_DEVCLASS_AUDIOENDPOINT: GUID =
    GUID::from_parts(0xcd17_1de3, 0x70e5, 0x41c9, [0x8a, 0xc9, 0x8f, 0xf1, 0x03, 0xba, 0x2a, 0xa1]);

/// USB hub device interface `{F18A0E88-C30C-11D0-8815-00A0C906BED8}`.
pub const GUID_DEVINTERFACE_USB_HUB: GUID =
    GUID::from_parts(0xf18a_0e88, 0xc30c, 0x11d0, [0x88, 0x15, 0x00, 0xa0, 0xc9, 0x06, 0xbe, 0xd8]);

/// `SetupDiGetDeviceInterfaceDetailW` reports failure through this.
pub const IFDETAIL_CB_SIZE_X64: u32 = 8;
pub const IFDETAIL_PATH_OFFSET: usize = 4;

pub const ENUMERATOR_USB: [u16; 4] = [b'U' as u16, b'S' as u16, b'B' as u16, 0];
pub const ENUMERATOR_BTHENUM: [u16; 8] =
    [b'B' as u16, b'T' as u16, b'H' as u16, b'E' as u16, b'N' as u16, b'U' as u16, b'M' as u16, 0];

#[link(name = "setupapi")]
unsafe extern "system" {
    pub fn SetupDiGetClassDevsW(
        ClassGuid: *const GUID,
        Enumerator: *const u16,
        hwndParent: HWND,
        Flags: u32,
    ) -> HDEVINFO;
    pub fn SetupDiEnumDeviceInfo(
        DeviceInfoSet: HDEVINFO,
        MemberIndex: u32,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
    ) -> BOOL;
    pub fn SetupDiGetDeviceInstanceIdW(
        DeviceInfoSet: HDEVINFO,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
        DeviceInstanceId: *mut u16,
        DeviceInstanceIdSize: u32,
        RequiredSize: *mut u32,
    ) -> BOOL;
    pub fn SetupDiSetClassInstallParamsW(
        DeviceInfoSet: HDEVINFO,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
        ClassInstallParams: *mut SP_CLASSINSTALL_HEADER,
        ClassInstallParamsSize: u32,
    ) -> BOOL;
    pub fn SetupDiCallClassInstaller(
        InstallFunction: u32,
        DeviceInfoSet: HDEVINFO,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
    ) -> BOOL;
    pub fn SetupDiDestroyDeviceInfoList(DeviceInfoSet: HDEVINFO) -> BOOL;
    pub fn SetupDiEnumDeviceInterfaces(
        DeviceInfoSet: HDEVINFO,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
        InterfaceClassGuid: *const GUID,
        MemberIndex: u32,
        DeviceInterfaceData: *mut SP_DEVICE_INTERFACE_DATA,
    ) -> BOOL;
    pub fn SetupDiGetDeviceInterfaceDetailW(
        DeviceInfoSet: HDEVINFO,
        DeviceInterfaceData: *mut SP_DEVICE_INTERFACE_DATA,
        DeviceInterfaceDetailData: *mut c_void,
        DeviceInterfaceDetailDataSize: u32,
        RequiredSize: *mut u32,
        DeviceInfoData: *mut SP_DEVINFO_DATA,
    ) -> BOOL;
}
