//! Hidden popup window that receives `WM_POWERBROADCAST` and
//! `WM_DEVICECHANGE`.
//!
//! The worker sleeps on two events and this window sets them: a resume
//! broadcast restarts the poll cadence immediately instead of waiting out a
//! sleep, and a device-tree change wakes the poll the moment a Bluetooth audio
//! link appears or disappears (Windows creates/removes BTHENUM devnodes for
//! it). The window must be a real top-level popup: a `HWND_MESSAGE` window
//! receives neither broadcast.
//!
//! `DBT_DEVNODES_CHANGED` needs no `RegisterDeviceNotification` — it is
//! broadcast to all top-level windows — which is why this costs no extra FFI
//! surface.

use std::ffi::c_void;
use std::ptr;

use crate::config;
use crate::sys::kernel32;
use crate::sys::user32::*;
use crate::sys::{HANDLE, HINSTANCE, HWND, LPARAM, LRESULT, WPARAM};
use crate::util;

/// The two events the window signals. Passed to `CreateWindowExW` and kept
/// alive by [`MessageWindow`] for as long as the window can run its proc.
#[repr(C)]
pub struct WakeEvents {
    pub resume: HANDLE,
    pub device: HANDLE,
}

/// Signal one of the wake events, if the window has its pointer installed.
unsafe fn signal(hwnd: HWND, pick: fn(&WakeEvents) -> HANDLE) {
    let p = unsafe { get_userdata(hwnd, GWLP_USERDATA) } as *const WakeEvents;
    if p.is_null() {
        return;
    }
    let ev = pick(unsafe { &*p });
    if !ev.is_null() {
        unsafe { kernel32::SetEvent(ev) };
    }
}

unsafe extern "system" fn window_proc(hwnd: HWND, msg: u32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    match msg {
        WM_NCCREATE => {
            // Install the event pointer as early as possible so a broadcast
            // racing window creation is never lost.
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
                unsafe { signal(hwnd, |e| e.resume) };
            }
            unsafe { DefWindowProcW(hwnd, msg, wparam, lparam) }
        }
        WM_DEVICECHANGE => {
            // Only the detail-free "something appeared or disappeared" event is
            // used. The worker treats it as "poll now", never as a verdict, and
            // debounces the burst Windows sends for a single link change.
            if wparam == DBT_DEVNODES_CHANGED {
                unsafe { signal(hwnd, |e| e.device) };
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
    /// Owned by the window for its whole lifetime: `window_proc` dereferences
    /// this pointer. Dropped only after `DestroyWindow` in `Drop`.
    _events: Box<WakeEvents>,
}

impl MessageWindow {
    pub fn create(resume_event: HANDLE, device_event: HANDLE) -> Result<Self, &'static str> {
        let events = Box::new(WakeEvents { resume: resume_event, device: device_event });
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
                events.as_ref() as *const WakeEvents as *mut c_void,
            )
        };
        if hwnd.is_null() {
            return Err("CreateWindowExW failed");
        }
        Ok(Self { hwnd, _events: events })
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
