//! Durable, low-friction logging: every line goes to the debugger, to
//! `btf.log` (rotated at [`config::LOG_MAX_BYTES`]) and to stderr when one is
//! attached. The file handle is opened once, append-only, so concurrent lines
//! from the worker and keepalive threads cannot interleave.

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::sync::{Mutex, OnceLock};

use crate::config;
use crate::dedup::{Action, Dedup};
use crate::sys::kernel32;
use crate::sys::SYSTEMTIME;
use crate::util;

static LOG: OnceLock<Option<Mutex<File>>> = OnceLock::new();
/// Repeat suppression. Shared by the worker and keepalive threads, so it lives
/// behind the same kind of lock as the file handle.
static DEDUP: Mutex<Dedup> = Mutex::new(Dedup::new());
/// Redaction is on unless `btf_nocensor.txt` sits next to the exe. Cached: the
/// switch is read once, not on every line.
static CENSOR: OnceLock<bool> = OnceLock::new();

/// Name of the opt-out switch, in the same style as `btf_freeze.txt`.
pub const NOCENSOR_NAME: &str = "btf_nocensor.txt";

fn censor_enabled() -> bool {
    *CENSOR.get_or_init(|| !util::self_dir_path(NOCENSOR_NAME).is_some_and(|p| p.exists()))
}

/// Redact one line unless the opt-out switch is present.
pub fn scrub(msg: &str) -> std::borrow::Cow<'_, str> {
    if censor_enabled() {
        std::borrow::Cow::Owned(crate::redact::redact_line(msg))
    } else {
        std::borrow::Cow::Borrowed(msg)
    }
}

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
///
/// Repeats are collapsed here, in the single choke point every log line goes
/// through, so no call site has to remember to rate limit itself.
pub fn write_line(msg: &str) {
    let msg: &str = &scrub(msg);

    let decision = DEDUP
        .lock()
        .map(|mut d| d.decide(msg, util::now_ms()))
        .unwrap_or(Action::Print);
    let msg: &str = &match decision {
        Action::Suppress(_) => return,
        Action::Print => std::borrow::Cow::Borrowed(msg),
        Action::PrintWithCount(n, since_ms) => std::borrow::Cow::Owned(format!(
            "{msg} [+{n} identical line(s) suppressed in the last {} s]",
            since_ms / 1000
        )),
    };

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
