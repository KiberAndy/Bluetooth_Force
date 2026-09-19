//! Hand-written Win32 FFI surface.
//!
//! Everything the daemon talks to on the Windows side lives here, grouped by
//! the DLL that exports it. There are deliberately no crate dependencies:
//! `windows-sys` would hide the exact struct layouts and flag values that this
//! tool's correctness depends on, so they are pinned by hand (and by the unit
//! tests in the sibling modules).

#![allow(non_snake_case, non_camel_case_types, non_upper_case_globals, dead_code)]

use std::ffi::c_void;

pub mod bluetooth;
pub mod cfgmgr32;
pub mod kernel32;
pub mod setupapi;
pub mod shell32;
pub mod user32;
pub mod winmm;

pub type HANDLE = *mut c_void;
pub type HMODULE = *mut c_void;
pub type HWND = *mut c_void;
pub type HINSTANCE = *mut c_void;
pub type HDEVINFO = *mut c_void;
pub type BOOL = i32;
pub type DWORD = u32;
pub type UINT = u32;
pub type WPARAM = usize;
pub type LPARAM = isize;
pub type LRESULT = isize;
pub type ATOM = u16;
pub type DEVINST = u32;
pub type CONFIGRET = u32;

/// `INVALID_HANDLE_VALUE` is `(HANDLE)-1`. Kept as a `const` so `==` compares
/// the address exactly the way the Win32 API means it.
pub const INVALID_HANDLE_VALUE: HANDLE = core::ptr::without_provenance_mut(usize::MAX);

/// A raw `FARPROC` as returned by `GetProcAddress`.
pub type FARPROC = *mut c_void;

/// `SetDefaultDllDirectories` flag: resolve DLLs only from `%SystemRoot%\System32`.
pub const LOAD_LIBRARY_SEARCH_SYSTEM32: u32 = 0x0000_0800;

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct GUID {
    pub data1: u32,
    pub data2: u16,
    pub data3: u16,
    pub data4: [u8; 8],
}

impl GUID {
    pub const fn from_parts(d1: u32, d2: u16, d3: u16, d4: [u8; 8]) -> Self {
        Self { data1: d1, data2: d2, data3: d3, data4: d4 }
    }
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default)]
pub struct SYSTEMTIME {
    pub wYear: u16,
    pub wMonth: u16,
    pub wDayOfWeek: u16,
    pub wDay: u16,
    pub wHour: u16,
    pub wMinute: u16,
    pub wSecond: u16,
    pub wMilliseconds: u16,
}
