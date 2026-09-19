//! Silent audio keepalive.
//!
//! Streams an inaudible ±1 LSB dither through the earbuds' own render endpoint
//! so the idle-disconnect timer never fires. One looping buffer per session
//! keeps driver churn near zero, and every wait is bounded so shutdown can
//! never hang.

use std::ptr;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};

use crate::btlog;
use crate::config::*;
use crate::ladder::{backoff_ms, CircuitBreaker};
use crate::sys::kernel32::Sleep;
use crate::sys::HANDLE;
use crate::sys::winmm::*;
use crate::util;

/// Fill the keepalive buffer with an inaudible, *non-zero* dither (alternating
/// ±1 LSB per 16-bit sample). A pure-silence stream can be treated as idle by
/// some audio engines/APOs, which lets the earbuds disconnect anyway.
pub fn fill_keepalive_buffer(buf: &mut [u8]) {
    let mut i = 0;
    while i + 1 < buf.len() {
        let sample: i16 = if (i / 2) % 2 == 0 { 1 } else { -1 };
        let bits = sample as u16;
        buf[i] = (bits & 0xFF) as u8;
        buf[i + 1] = (bits >> 8) as u8;
        i += 2;
    }
    // A trailing odd byte cannot form a 16-bit sample; leave it zeroed.
    if i < buf.len() {
        buf[i] = 0;
    }
}

fn is_fxsound_name(name: &str) -> bool {
    util::contains_ignore_case(name.as_bytes(), b"fxsound")
        || util::contains_ignore_case(name.as_bytes(), b"fx sound")
}

/// Pick the waveOut device that routes the keepalive directly to the earbuds,
/// bypassing FxSound's default-device APO.
///
/// 1. If `override_name` is set, return the first device whose name contains it.
/// 2. Otherwise match any ≥4-char alphanumeric token of the Bluetooth name,
///    skipping FxSound endpoints.
///
/// `None` means "fall back to WAVE_MAPPER".
pub fn select_audio_device(
    names: &[String],
    bt_name: &str,
    override_name: Option<&str>,
) -> Option<usize> {
    if let Some(ov) = override_name {
        if !ov.is_empty() {
            return names.iter().position(|n| util::contains_ignore_case(n.as_bytes(), ov.as_bytes()));
        }
    }

    let bytes = bt_name.as_bytes();
    let mut start = 0usize;
    let mut i = 0usize;
    while i <= bytes.len() {
        let at_end = i == bytes.len();
        let is_sep = at_end || !bytes[i].is_ascii_alphanumeric();
        if is_sep {
            let token = &bytes[start..i];
            if token.len() >= 4 {
                if let Some(idx) = names
                    .iter()
                    .position(|n| !is_fxsound_name(n) && util::contains_ignore_case(n.as_bytes(), token))
                {
                    return Some(idx);
                }
            }
            start = i + 1;
        }
        i += 1;
    }
    None
}

/// State shared with the keepalive worker thread. The buffer lives here so its
/// address stays stable for the driver across the whole session.
struct KeepaliveInner {
    want_run: AtomicBool,
    device_id: AtomicU32,
    consec_fails: AtomicU32,
    breaker: Mutex<CircuitBreaker>,
    buffer: Box<[u8; KEEPALIVE_BUF_SIZE]>,
}

/// Owns the keepalive worker thread. `start`/`stop` are called only from the
/// worker thread (or, for the final `stop`, from main after the worker joined).
pub struct SilentKeepalive {
    inner: Arc<KeepaliveInner>,
    thread: Option<JoinHandle<()>>,
    override_name: Option<String>,
}

impl SilentKeepalive {
    pub fn new(override_name: Option<String>) -> Self {
        let mut buffer = Box::new([0u8; KEEPALIVE_BUF_SIZE]);
        fill_keepalive_buffer(&mut buffer[..]);
        Self {
            inner: Arc::new(KeepaliveInner {
                want_run: AtomicBool::new(false),
                device_id: AtomicU32::new(WAVE_MAPPER),
                consec_fails: AtomicU32::new(0),
                breaker: Mutex::new(CircuitBreaker::new(
                    KEEPALIVE_CB_WINDOW_MS,
                    KEEPALIVE_CB_MAX_OPENS,
                    KEEPALIVE_CB_COOLDOWN_MS,
                )),
                buffer,
            }),
            thread: None,
            override_name,
        }
    }

    /// Consecutive failed render sessions (published for the poll thread).
    pub fn consec_fails(&self) -> u32 {
        self.inner.consec_fails.load(Ordering::Acquire)
    }

    pub fn is_running(&self) -> bool {
        self.thread.is_some()
    }

    /// Resolve the endpoint and start the worker if one is not already live.
    pub fn start(&mut self, bt_name: &str) {
        if self.thread.is_some() {
            return;
        }
        self.resolve_device(bt_name);
        self.inner.want_run.store(true, Ordering::Release);
        let inner = Arc::clone(&self.inner);
        match thread::Builder::new().name("keepalive".into()).spawn(move || run(inner)) {
            Ok(handle) => self.thread = Some(handle),
            Err(e) => {
                self.inner.want_run.store(false, Ordering::Release);
                btlog!("keepalive thread spawn failed: {e}");
            }
        }
    }

    /// Stop and join the worker. Safe to call on a never-started instance.
    pub fn stop(&mut self) {
        self.inner.want_run.store(false, Ordering::Release);
        // The streak belongs to the dead worker; a restarted worker rebuilds it.
        self.inner.consec_fails.store(0, Ordering::Release);
        if let Some(handle) = self.thread.take() {
            let _ = handle.join();
        }
    }

    /// Enumerate waveOut endpoints and pick the earbuds' own device so the
    /// keepalive bypasses the FxSound default-device APO. Best-effort: on any
    /// failure it leaves `device_id = WAVE_MAPPER`.
    fn resolve_device(&mut self, bt_name: &str) {
        let n = unsafe { waveOutGetNumDevs() };
        if n == 0 {
            self.inner.device_id.store(WAVE_MAPPER, Ordering::Release);
            return;
        }

        let mut names: Vec<String> = Vec::new();
        for dev in 0..n {
            let mut caps = WAVEOUTCAPSW::default();
            let rc = unsafe {
                waveOutGetDevCapsW(dev as usize, &mut caps, std::mem::size_of::<WAVEOUTCAPSW>() as u32)
            };
            if rc != 0 {
                continue;
            }
            let name = util::utf16_field(&caps.szPname);
            btlog!("waveOut[{dev}] = {name}");
            names.push(name);
        }

        if let Some(idx) = select_audio_device(&names, bt_name, self.override_name.as_deref()) {
            self.inner.device_id.store(idx as u32, Ordering::Release);
            btlog!("keepalive -> endpoint #{idx} ({})", names[idx]);
        } else {
            self.inner.device_id.store(WAVE_MAPPER, Ordering::Release);
            btlog!("keepalive -> WAVE_MAPPER (no earbud endpoint matched)");
        }
    }
}

/// Outer worker loop: retries a failed session instead of dying, bounded by
/// exponential backoff and the circuit breaker.
fn run(inner: Arc<KeepaliveInner>) {
    let mut fails: u32 = 0;
    while inner.want_run.load(Ordering::Acquire) {
        let now = util::now_ms();
        {
            let mut breaker = inner.breaker.lock().unwrap();
            if !breaker.allow(now) {
                drop(breaker);
                btlog!("keepalive circuit OPEN — cooling down");
                interruptible_sleep(&inner, 1000);
                continue;
            }
        }

        let opened = run_session(&inner);
        if opened {
            fails = 0;
        } else {
            fails = fails.saturating_add(1);
        }
        inner.consec_fails.store(fails, Ordering::Release);

        if inner.want_run.load(Ordering::Acquire) {
            let wait = if opened {
                500
            } else {
                backoff_ms(fails, KEEPALIVE_BACKOFF_BASE_MS, KEEPALIVE_BACKOFF_CAP_MS)
            };
            interruptible_sleep(&inner, wait);
        }
    }
}

fn interruptible_sleep(inner: &KeepaliveInner, total_ms: u32) {
    let mut slept = 0u32;
    while slept < total_ms && inner.want_run.load(Ordering::Acquire) {
        let slice = 50u32.min(total_ms - slept);
        unsafe { Sleep(slice) };
        slept += slice;
    }
}

/// Keeps the driver from referencing our stack header / buffer on unwind.
struct SessionGuard {
    hwo: HANDLE,
    hdr: *mut WAVEHDR,
    queued: bool,
}

impl Drop for SessionGuard {
    fn drop(&mut self) {
        unsafe {
            waveOutReset(self.hwo);
            if self.queued {
                let mut spins = 0u32;
                while read_flags(self.hdr) & WHDR_DONE == 0 && spins < KEEPALIVE_DRAIN_SPINS {
                    Sleep(5);
                    spins += 1;
                }
            }
            waveOutUnprepareHeader(self.hwo, self.hdr, std::mem::size_of::<WAVEHDR>() as u32);
            waveOutClose(self.hwo);
        }
    }
}

fn read_flags(hdr: *mut WAVEHDR) -> u32 {
    // The winmm driver thread writes dwFlags; a volatile read is the polling
    // contract and needs no stronger ordering than "see the write".
    unsafe { ptr::read_volatile(ptr::addr_of!((*hdr).dwFlags)) }
}

/// One open → prepare → play → close session. Returns `true` if the device
/// opened (regardless of how it ended).
fn run_session(inner: &KeepaliveInner) -> bool {
    let fmt = WAVEFORMATEX {
        wFormatTag: WAVE_FORMAT_PCM,
        nChannels: 2,
        nSamplesPerSec: 44_100,
        nAvgBytesPerSec: 176_400,
        nBlockAlign: 4,
        wBitsPerSample: 16,
        cbSize: 0,
    };

    let mut hwo: HANDLE = ptr::null_mut();
    let device_id = inner.device_id.load(Ordering::Acquire);
    if unsafe { waveOutOpen(&mut hwo, device_id, &fmt, 0, 0, CALLBACK_NULL) } != 0 {
        return false;
    }

    let mut hdr = WAVEHDR {
        lpData: inner.buffer.as_ptr() as *mut u8,
        dwBufferLength: KEEPALIVE_BUF_SIZE as u32,
        dwFlags: WHDR_BEGINLOOP | WHDR_ENDLOOP,
        dwLoops: KEEPALIVE_LOOP_COUNT,
        ..Default::default()
    };
    let hdr_ptr: *mut WAVEHDR = &mut hdr;

    if unsafe { waveOutPrepareHeader(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) } != 0 {
        unsafe { waveOutClose(hwo) };
        return false;
    }

    let mut guard = SessionGuard { hwo, hdr: hdr_ptr, queued: false };

    if unsafe { waveOutWrite(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) } != 0 {
        return false;
    }
    guard.queued = true;

    // The looping buffer plays for years; idle until stop is requested. If the
    // loop ever does finish, re-arm it once.
    while inner.want_run.load(Ordering::Acquire) {
        unsafe { Sleep(200) };
        if read_flags(hdr_ptr) & WHDR_DONE != 0 {
            unsafe {
                waveOutUnprepareHeader(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32);
            }
            guard.queued = false;
            // Re-arm through the same pointer the driver sees, so the compiler
            // cannot mistake these live writes for dead local assignments.
            unsafe {
                (*hdr_ptr).dwFlags = WHDR_BEGINLOOP | WHDR_ENDLOOP;
                (*hdr_ptr).dwLoops = KEEPALIVE_LOOP_COUNT;
            }
            if unsafe { waveOutPrepareHeader(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) } != 0 {
                return false;
            }
            if unsafe { waveOutWrite(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) } != 0 {
                return false;
            }
            guard.queued = true;
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn buffer_is_nonzero_dither() {
        let mut ka = SilentKeepalive::new(None);
        let buf = &ka.inner.buffer;
        assert_eq!(buf[0], 1);
        assert_eq!(buf[1], 0);
        assert_eq!(buf[2], 0xFF);
        assert_eq!(buf[3], 0xFF);
        let mut i = 0;
        let mut sum: i64 = 0;
        while i + 1 < buf.len() {
            let bits = u16::from_le_bytes([buf[i], buf[i + 1]]);
            assert!(bits != 0);
            sum += i16::from_le_bytes([buf[i], buf[i + 1]]) as i64;
            i += 2;
        }
        assert_eq!(sum, 0);
        ka.stop(); // no-op, must not hang
    }

    #[test]
    fn odd_buffer_trailing_byte_zero() {
        let mut odd = [0xAAu8; 5];
        fill_keepalive_buffer(&mut odd);
        assert_eq!(odd[4], 0);
        assert_eq!(odd[0], 1);
        assert_eq!(odd[1], 0);
    }

    #[test]
    fn device_selection() {
        let names = vec![
            "Speakers (FxSound Audio Enhancer)".to_string(),
            "Headphones (WF-1000XM5 Stereo)".to_string(),
            "Realtek HD Audio".to_string(),
        ];
        assert_eq!(select_audio_device(&names, "WF-1000XM5", None), Some(1));
        assert_eq!(select_audio_device(&names, "XY", None), None);
        assert_eq!(select_audio_device(&names, "WF-1000XM5", Some("realtek")), Some(2));
        assert_eq!(select_audio_device(&names, "WF-1000XM5", Some("nope")), None);
    }

    #[test]
    fn fresh_instance_idle() {
        let ka = SilentKeepalive::new(None);
        assert!(!ka.is_running());
        assert_eq!(ka.consec_fails(), 0);
        assert_eq!(ka.inner.device_id.load(Ordering::Acquire), WAVE_MAPPER);
    }
}
