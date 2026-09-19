//! Hidden popup window that receives `WM_POWERBROADCAST`.
//!
//! The worker sleeps on the resume event, and a resume broadcast sets it so the
//! poll cadence restarts immediately instead of waiting out a sleep. The window
//! must be a real top-level popup (a `HWND_MESSAGE` window does not receive
//! broadcasts).

use std::ffi::c_void;
use std::ptr;

use crate::config;
use crate::sys::kernel32;
use crate::sys::user32::*;
use crate::sys::{HANDLE, HINSTANCE, HWND, LPARAM, LRESULT, WPARAM};
use crate::util;

unsafe extern "system" fn window_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    match msg {
        WM_NCCREATE => {
            // Install the resume-event handle as early as possible so a resume
            // broadcast racing window creation is never lost.
            let cs = lparam as *const CREATESTRUCTW;
            if !cs.is_null() {
                let ev = unsafe { (*cs).lpCreateParams } as isize;
                if ev != 0 {
                    unsafe { set_userdata(hwnd, GWLP_USERDATA, ev) };
                }
            }
            unsafe { DefWindowProcW(hwnd, msg, wparam, lparam) }
        }
        WM_POWERBROADCAST => {
            if wparam == PBT_APMRESUMEAUTOMATIC {
                let ev = unsafe { get_userdata(hwnd, GWLP_USERDATA) };
                if ev != 0 {
                    unsafe { kernel32::SetEvent(ev as HANDLE) };
                }
            }
            unsafe { DefWindowProcW(hwnd, msg, wparam, lparam) }
        }
        WM_CLOSE => {
            unsafe { DestroyWindow(hwnd) };
            0
        }
        WM_DESTROY => {
            unsafe { PostQuitMessage(0) };
            0
        }
        _ => unsafe { DefWindowProcW(hwnd, msg, wparam, lparam) },
    }
}

pub struct MessageWindow {
    hwnd: HWND,
}

impl MessageWindow {
    pub fn create(resume_event: HANDLE) -> Result<Self, &'static str> {
        let hinstance: HINSTANCE = unsafe { kernel32::GetModuleHandleW(ptr::null()) };
        if hinstance.is_null() {
            return Err("GetModuleHandleW failed");
        }

        let class_name = util::wide(config::WINDOW_CLASS_NAME);
        let title = util::wide(config::WINDOW_TITLE);

        let wc = WNDCLASSEXW {
            cbSize: std::mem::size_of::<WNDCLASSEXW>() as u32,
            style: 0,
            lpfnWndProc: window_proc,
            cbClsExtra: 0,
            cbWndExtra: 0,
            hInstance: hinstance,
            hIcon: ptr::null_mut(),
            hCursor: ptr::null_mut(),
            hbrBackground: ptr::null_mut(),
            lpszMenuName: ptr::null(),
            lpszClassName: class_name.as_ptr(),
            hIconSm: ptr::null_mut(),
        };
        if unsafe { RegisterClassExW(&wc) } == 0 {
            return Err("RegisterClassExW failed");
        }

        let hwnd = unsafe {
            CreateWindowExW(
                WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
                class_name.as_ptr(),
                title.as_ptr(),
                WS_POPUP,
                0,
                0,
                0,
                0,
                ptr::null_mut(),
                ptr::null_mut(),
                hinstance,
                resume_event as *mut c_void,
            )
        };
        if hwnd.is_null() {
            return Err("CreateWindowExW failed");
        }
        Ok(Self { hwnd })
    }

    /// Pump messages until `WM_QUIT`.
    pub fn run_loop(&self) {
        let mut msg = MSG::default();
        loop {
            let ret = unsafe { GetMessageW(&mut msg, ptr::null_mut(), 0, 0) };
            if ret <= 0 {
                break;
            }
            unsafe {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        }
    }
}

impl Drop for MessageWindow {
    fn drop(&mut self) {
        unsafe { DestroyWindow(self.hwnd) };
    }
}
