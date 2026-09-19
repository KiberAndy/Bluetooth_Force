//! user32.dll entry points plus the userdata helper used by the message window.

use super::*;

pub const WM_CLOSE: u32 = 0x0010;
pub const WM_DESTROY: u32 = 0x0002;
pub const WM_NCCREATE: u32 = 0x0081;
pub const WM_POWERBROADCAST: u32 = 0x0218;
pub const PBT_APMRESUMEAUTOMATIC: usize = 0x0012;

pub const WS_POPUP: u32 = 0x8000_0000;
pub const WS_EX_TOOLWINDOW: u32 = 0x0000_0080;
pub const WS_EX_NOACTIVATE: u32 = 0x0800_0000;
pub const GWLP_USERDATA: i32 = -21;

pub type WNDPROC = unsafe extern "system" fn(HWND, u32, WPARAM, LPARAM) -> LRESULT;

#[repr(C)]
pub struct WNDCLASSEXW {
    pub cbSize: u32,
    pub style: u32,
    pub lpfnWndProc: WNDPROC,
    pub cbClsExtra: i32,
    pub cbWndExtra: i32,
    pub hInstance: HINSTANCE,
    pub hIcon: HANDLE,
    pub hCursor: HANDLE,
    pub hbrBackground: HANDLE,
    pub lpszMenuName: *const u16,
    pub lpszClassName: *const u16,
    pub hIconSm: HANDLE,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct CREATESTRUCTW {
    pub lpCreateParams: *mut c_void,
    pub hInstance: HINSTANCE,
    pub hMenu: HANDLE,
    pub hwndParent: HWND,
    pub cy: i32,
    pub cx: i32,
    pub y: i32,
    pub x: i32,
    pub style: i32,
    pub lpszName: *const u16,
    pub lpszClass: *const u16,
    pub dwExStyle: u32,
}

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct MSG {
    pub hwnd: HWND,
    pub message: u32,
    pub wParam: WPARAM,
    pub lParam: LPARAM,
    pub time: u32,
    pub pt_x: i32,
    pub pt_y: i32,
}

#[link(name = "user32")]
unsafe extern "system" {
    pub fn DefWindowProcW(hWnd: HWND, Msg: u32, wParam: WPARAM, lParam: LPARAM) -> LRESULT;
    pub fn PostQuitMessage(nExitCode: i32);
    pub fn RegisterClassExW(lpWndClassEx: *const WNDCLASSEXW) -> ATOM;
    pub fn CreateWindowExW(
        dwExStyle: u32,
        lpClassName: *const u16,
        lpWindowName: *const u16,
        dwStyle: u32,
        X: i32,
        Y: i32,
        nWidth: i32,
        nHeight: i32,
        hWndParent: HWND,
        hMenu: HANDLE,
        hInstance: HINSTANCE,
        lpParam: *mut c_void,
    ) -> HWND;
    pub fn GetMessageW(
        lpMsg: *mut MSG,
        hWnd: HWND,
        wMsgFilterMin: u32,
        wMsgFilterMax: u32,
    ) -> BOOL;
    pub fn TranslateMessage(lpMsg: *const MSG) -> BOOL;
    pub fn DispatchMessageW(lpMsg: *const MSG) -> LRESULT;
    pub fn DestroyWindow(hWnd: HWND) -> BOOL;
}

// On 64-bit Windows the *Ptr* variants are real exports. On 32-bit Windows they
// are only C macros that alias the LONG-width functions, so binding to
// GetWindowLongPtrW/SetWindowLongPtrW fails to link on x86. Bind the correct
// underlying export per target width and hide it behind pointer-width helpers so
// callers stay identical.
#[cfg(target_pointer_width = "64")]
#[link(name = "user32")]
unsafe extern "system" {
    fn GetWindowLongPtrW(hWnd: HWND, nIndex: i32) -> isize;
    fn SetWindowLongPtrW(hWnd: HWND, nIndex: i32, dwNewLong: isize) -> isize;
}

#[cfg(target_pointer_width = "32")]
#[link(name = "user32")]
unsafe extern "system" {
    fn GetWindowLongW(hWnd: HWND, nIndex: i32) -> i32;
    fn SetWindowLongW(hWnd: HWND, nIndex: i32, dwNewLong: i32) -> i32;
}

/// Read the pointer-width userdata slot (`GWLP_USERDATA`).
pub unsafe fn get_userdata(hwnd: HWND, index: i32) -> isize {
    #[cfg(target_pointer_width = "64")]
    {
        unsafe { GetWindowLongPtrW(hwnd, index) }
    }
    #[cfg(target_pointer_width = "32")]
    {
        unsafe { GetWindowLongW(hwnd, index) as isize }
    }
}

/// Write the pointer-width userdata slot (`GWLP_USERDATA`).
pub unsafe fn set_userdata(hwnd: HWND, index: i32, value: isize) {
    #[cfg(target_pointer_width = "64")]
    {
        unsafe { SetWindowLongPtrW(hwnd, index, value) };
    }
    #[cfg(target_pointer_width = "32")]
    {
        // GWLP_USERDATA stores a pointer; on 32-bit the slot is exactly LONG
        // wide, so truncating isize -> i32 is the documented, lossless behavior.
        unsafe { SetWindowLongW(hwnd, index, value as i32) };
    }
}
