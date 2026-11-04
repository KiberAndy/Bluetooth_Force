//! Minimal Core Audio COM ABI. Slots follow mmdeviceapi.h/devicetopology.h.
use std::ffi::c_void;
use std::ptr;
use super::GUID;

pub type Raw = *mut c_void;
pub const ENUMERATOR_CLASS: GUID = GUID::from_parts(0xbcde0395, 0xe52f, 0x467c, [0x8e,0x3d,0xc4,0x57,0x92,0x91,0x69,0x2e]);
pub const ENUMERATOR_IID: GUID = GUID::from_parts(0xa95664d2, 0x9614, 0x4f35, [0xa7,0x46,0xde,0x8d,0xb6,0x36,0x17,0xe6]);
pub const TOPOLOGY_IID: GUID = GUID::from_parts(0x2a07407e, 0x6497, 0x4a18, [0x97,0x87,0x32,0xf7,0x9b,0xd0,0xd9,0x8f]);
pub const KS_IID: GUID = GUID::from_parts(0x28f54685, 0x06fd, 0x11d2, [0xb2,0x7a,0x00,0xa0,0xc9,0x22,0x31,0x96]);
pub const BT_AUDIO: GUID = GUID::from_parts(0x7fa06c40, 0xb8f6, 0x4c7e, [0x85,0x56,0xe8,0xc3,0x3a,0x12,0xe5,0x4d]);

#[repr(C)]
pub struct KsProperty { pub set: GUID, pub id: u32, pub flags: u32 }

#[link(name = "ole32")]
unsafe extern "system" {
    fn CoInitializeEx(reserved: Raw, mode: u32) -> i32;
    fn CoUninitialize();
    fn CoCreateInstance(class: *const GUID, outer: Raw, context: u32, iid: *const GUID, out: *mut Raw) -> i32;
    fn CoTaskMemFree(memory: Raw);
}

pub struct Apartment;
impl Apartment {
    pub fn init() -> Result<Self, i32> {
        let hr = unsafe { CoInitializeEx(ptr::null_mut(), 0) };
        if hr < 0 { Err(hr) } else { Ok(Self) }
    }
}
impl Drop for Apartment { fn drop(&mut self) { unsafe { CoUninitialize() }; } }

/// Owns one counted COM reference. Never crosses worker threads.
pub struct Com(pub Raw);
impl Drop for Com {
    fn drop(&mut self) {
        let release: unsafe extern "system" fn(Raw) -> u32 = unsafe { self.slot(2) };
        unsafe { release(self.0) };
    }
}
impl Com {
    // Callers bind each slot to its exact SDK signature below.
    unsafe fn slot<T: Copy>(&self, index: usize) -> T {
        let table = unsafe { *(self.0 as *const *const Raw) };
        let entry = unsafe { *table.add(index) };
        unsafe { std::mem::transmute_copy(&entry) }
    }
    fn result(hr: i32, raw: Raw) -> Result<Self, i32> {
        if hr < 0 { Err(hr) } else if raw.is_null() { Err(0x80004003u32 as i32) } else { Ok(Self(raw)) }
    }
    pub fn enumerator() -> Result<Self, i32> {
        let mut raw = ptr::null_mut();
        let hr = unsafe { CoCreateInstance(&ENUMERATOR_CLASS, ptr::null_mut(), 1, &ENUMERATOR_IID, &mut raw) };
        Self::result(hr, raw)
    }
    pub fn endpoints(&self) -> Result<Self, i32> {
        let call: unsafe extern "system" fn(Raw, i32, u32, *mut Raw) -> i32 = unsafe { self.slot(3) };
        let mut raw = ptr::null_mut();
        // Render, ACTIVE | UNPLUGGED. Respect user-disabled endpoints.
        Self::result(unsafe { call(self.0, 0, 9, &mut raw) }, raw)
    }
    pub fn count(&self) -> Result<u32, i32> {
        let call: unsafe extern "system" fn(Raw, *mut u32) -> i32 = unsafe { self.slot(3) };
        let mut count = 0;
        let hr = unsafe { call(self.0, &mut count) };
        if hr < 0 { Err(hr) } else { Ok(count) }
    }
    /// Collection::Item (slot 4) or DeviceTopology::GetConnector (slot 4).
    pub fn item(&self, index: u32) -> Result<Self, i32> {
        let call: unsafe extern "system" fn(Raw, u32, *mut Raw) -> i32 = unsafe { self.slot(4) };
        let mut raw = ptr::null_mut();
        Self::result(unsafe { call(self.0, index, &mut raw) }, raw)
    }
    pub fn activate(&self, iid: &GUID) -> Result<Self, i32> {
        let call: unsafe extern "system" fn(Raw, *const GUID, u32, Raw, *mut Raw) -> i32 = unsafe { self.slot(3) };
        let mut raw = ptr::null_mut();
        Self::result(unsafe { call(self.0, iid, 1, ptr::null_mut(), &mut raw) }, raw)
    }
    pub fn adapter_id(&self) -> Result<Vec<u16>, i32> {
        let call: unsafe extern "system" fn(Raw, *mut *mut u16) -> i32 = unsafe { self.slot(10) };
        let mut raw = ptr::null_mut();
        let hr = unsafe { call(self.0, &mut raw) };
        if hr < 0 { return Err(hr); }
        if raw.is_null() { return Err(0x80004003u32 as i32); }
        let mut value = Vec::new();
        unsafe {
            let mut i = 0;
            while *raw.add(i) != 0 { value.push(*raw.add(i)); i += 1; }
            CoTaskMemFree(raw.cast());
        }
        value.push(0);
        Ok(value)
    }
    pub fn device(&self, id: &[u16]) -> Result<Self, i32> {
        let call: unsafe extern "system" fn(Raw, *const u16, *mut Raw) -> i32 = unsafe { self.slot(5) };
        let mut raw = ptr::null_mut();
        Self::result(unsafe { call(self.0, id.as_ptr(), &mut raw) }, raw)
    }
    pub fn reconnect(&self) -> i32 {
        let call: unsafe extern "system" fn(Raw, *const KsProperty, u32, Raw, u32, *mut u32) -> i32 = unsafe { self.slot(3) };
        // ksmedia.h: ONESHOT_RECONNECT=0, KSPROPERTY_TYPE_GET=1, NULL value.
        let property = KsProperty { set: BT_AUDIO, id: 0, flags: 1 };
        let mut returned = 0;
        unsafe { call(self.0, &property, std::mem::size_of::<KsProperty>() as u32, ptr::null_mut(), 0, &mut returned) }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn ks_property_matches_sdk_layout() {
        assert_eq!(std::mem::size_of::<KsProperty>(), 24);
        assert_eq!(std::mem::offset_of!(KsProperty, flags), 20);
    }
}
