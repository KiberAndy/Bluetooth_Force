//! Dual-channel report line used by every PnP rung and one-shot mode.
//!
//! A rung may run with no report file (the auto-ladder), in which case lines
//! land only in the debug log. The one-shot modes open a text report next to
//! the exe and get the identical text in both places.

use std::cell::RefCell;
use std::fs::File;
use std::io::Write;

use crate::btlog;

pub struct HealthOut {
    file: RefCell<Option<File>>,
    pub tag: &'static str,
}

impl HealthOut {
    /// Debug-log only (no report file). Used by the automatic ladder rungs.
    pub fn debug_only(tag: &'static str) -> Self {
        Self { file: RefCell::new(None), tag }
    }

    /// Create (truncate) a report at `path`, exactly as given. A failed open
    /// degrades to debug-log-only evidence instead of failing the mode.
    pub fn to_file(tag: &'static str, path: &str) -> Self {
        let file = File::create(path).ok();
        Self { file: RefCell::new(file), tag }
    }

    pub fn line(&self, body: &str) {
        if let Some(f) = self.file.borrow_mut().as_mut() {
            // The report is shared like the log, so it is redacted the same way.
            let _ = f.write_all(crate::log::scrub(body).as_bytes());
            let _ = f.write_all(b"\r\n");
        }
        btlog!("{}: {}", self.tag, body);
    }

    pub fn line_fmt(&self, body: String) {
        self.line(&body);
    }

    /// Per-item detail (one line per devnode). It goes into an explicitly
    /// requested report in full, but is dropped from the always-on debug log
    /// when the rung runs unattended: in the field log the 38 `skip (non-audio)`
    /// lines were 3% of the file and each one is unique (a different GUID), so
    /// the de-duplicator cannot fold them. The summary line that counts them
    /// stays in the log either way.
    pub fn detail(&self, body: String) {
        if let Some(f) = self.file.borrow_mut().as_mut() {
            let _ = f.write_all(crate::log::scrub(&body).as_bytes());
            let _ = f.write_all(b"\r\n");
            btlog!("{}: {}", self.tag, body);
        }
    }
}
