//! Durable, low-friction logging: every line goes to the debugger, to
//! `btf.log` (rotated at [`config::LOG_MAX_BYTES`]) and to stderr when one is
//! attached. The file handle is opened once, append-only, so concurrent lines
//! from the worker and keepalive threads cannot interleave.

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::sync::{Mutex, OnceLock};

use crate::config;
use crate::sys::kernel32;
use crate::sys::SYSTEMTIME;
use crate::util;

static LOG: OnceLock<Option<Mutex<File>>> = OnceLock::new();

/// Open (and rotate) the durable log. Idempotent.
pub fn init() {
    LOG.get_or_init(|| {
        if let Some(path) = util::self_dir_path(config::LOG_NAME) {
            if let Ok(md) = std::fs::metadata(&path) {
                if md.len() >= config::LOG_MAX_BYTES {
                    if let Some(old) = util::self_dir_path(config::LOG_OLD_NAME) {
                        let _ = std::fs::rename(&path, old);
                    }
                }
            }
            if let Ok(f) = OpenOptions::new().create(true).append(true).open(&path) {
                return Some(Mutex::new(f));
            }
        }
        None
    });
}

/// `true` once the durable log has been opened successfully.
pub fn is_active() -> bool {
    matches!(LOG.get(), Some(Some(_)))
}

fn timestamp() -> String {
    let mut st = SYSTEMTIME::default();
    unsafe { kernel32::GetLocalTime(&mut st) };
    format!("{:02}:{:02}:{:02}.{:03}", st.wHour, st.wMinute, st.wSecond, st.wMilliseconds)
}

/// Emit one already-formatted line.
pub fn write_line(msg: &str) {
    // DebugView / attached debugger channel.
    let dbg = format!("btf: {msg}\0");
    unsafe { kernel32::OutputDebugStringA(dbg.as_ptr()) };

    // Durable channel: one buffered write per line.
    if let Some(Some(lock)) = LOG.get() {
        if let Ok(mut f) = lock.lock() {
            let _ = writeln!(f, "{} btf: {}", timestamp(), msg);
            let _ = f.flush();
        }
    }

    // stderr when the process actually has one.
    unsafe {
        let h = kernel32::GetStdHandle(kernel32::STD_ERROR_HANDLE);
        if !h.is_null() && h != crate::sys::INVALID_HANDLE_VALUE {
            let mut line = String::with_capacity(msg.len() + 2);
            line.push_str(msg);
            line.push_str("\r\n");
            let mut written = 0u32;
            kernel32::WriteFile(h, line.as_ptr(), line.len() as u32, &mut written, std::ptr::null_mut());
        }
    }
}

/// `btlog!("fmt {}", arg)` — the crate-wide logging entry point.
#[macro_export]
macro_rules! btlog {
    ($($arg:tt)*) => {
        $crate::log::write_line(&format!($($arg)*))
    };
}
