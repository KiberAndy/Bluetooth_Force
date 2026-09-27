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
use crate::endpoint::{ranked_formats, select_audio_device, WaveFormatSpec};
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

/// State shared with the keepalive worker thread. The buffer lives here so its
/// address stays stable for the driver across the whole session.
struct KeepaliveInner {
    want_run: AtomicBool,
    /// Resolved fresh before every session; only kept for diagnostics.
    device_id: AtomicU32,
    /// Bluetooth name the endpoint is matched against, plus the user override.
    bt_name: Mutex<String>,
    override_name: Option<String>,
    consec_fails: AtomicU32,
    breaker: Mutex<CircuitBreaker>,
    buffer: Box<[u8; KEEPALIVE_BUF_SIZE]>,
}

/// Owns the keepalive worker thread. `start`/`stop` are called only from the
/// worker thread (or, for the final `stop`, from main after the worker joined).
pub struct SilentKeepalive {
    inner: Arc<KeepaliveInner>,
    thread: Option<JoinHandle<()>>,
}

impl SilentKeepalive {
    pub fn new(override_name: Option<String>) -> Self {
        let mut buffer = Box::new([0u8; KEEPALIVE_BUF_SIZE]);
        fill_keepalive_buffer(&mut buffer[..]);
        Self {
            inner: Arc::new(KeepaliveInner {
                want_run: AtomicBool::new(false),
                device_id: AtomicU32::new(WAVE_MAPPER),
                bt_name: Mutex::new(String::new()),
                override_name,
                consec_fails: AtomicU32::new(0),
                breaker: Mutex::new(CircuitBreaker::new(
                    KEEPALIVE_CB_WINDOW_MS,
                    KEEPALIVE_CB_MAX_OPENS,
                    KEEPALIVE_CB_COOLDOWN_MS,
                )),
                buffer,
            }),
            thread: None,
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
        if let Ok(mut n) = self.inner.bt_name.lock() {
            n.clear();
            n.push_str(bt_name);
        }
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
}

/// Enumerate the waveOut endpoints and resolve the earbuds' own device.
///
/// Run before EVERY session: re-installing the A2DP driver renumbers the
/// waveOut list, so a cached index can point at the wrong device -- or at none.
/// `None` means "fall back to WAVE_MAPPER".
fn resolve_endpoint(inner: &KeepaliveInner) -> (u32, u32) {
    let n = unsafe { waveOutGetNumDevs() };
    if n == 0 {
        btlog!("keepalive: no waveOut endpoint exists right now");
        return (WAVE_MAPPER, 0);
    }

    let mut names: Vec<String> = Vec::new();
    let mut formats: Vec<u32> = Vec::new();
    for dev in 0..n {
        let mut caps = WAVEOUTCAPSW::default();
        let rc = unsafe {
            waveOutGetDevCapsW(dev as usize, &mut caps, std::mem::size_of::<WAVEOUTCAPSW>() as u32)
        };
        if rc != 0 {
            continue;
        }
        names.push(util::utf16_field(&caps.szPname));
        formats.push(caps.dwFormats);
    }

    let bt_name = inner.bt_name.lock().map(|n| n.clone()).unwrap_or_default();
    match select_audio_device(&names, &bt_name, inner.override_name.as_deref()) {
        Some(idx) => {
            let previous = inner.device_id.load(Ordering::Acquire);
            if previous != idx as u32 {
                btlog!(
                    "keepalive -> endpoint #{idx} ({}) dwFormats=0x{:x}",
                    names[idx],
                    formats[idx]
                );
            }
            (idx as u32, formats[idx])
        }
        None => {
            btlog!("keepalive -> WAVE_MAPPER (no earbud endpoint matched among {} device(s))", names.len());
            (WAVE_MAPPER, 0)
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

        let (device_id, dw_formats) = resolve_endpoint(&inner);
        inner.device_id.store(device_id, Ordering::Release);
        let opened = run_session(&inner, device_id, dw_formats);
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

/// Build a `WAVEFORMATEX` for one candidate spec.
fn wave_format(spec: WaveFormatSpec) -> WAVEFORMATEX {
    WAVEFORMATEX {
        wFormatTag: WAVE_FORMAT_PCM,
        nChannels: spec.channels,
        nSamplesPerSec: spec.sample_rate,
        nAvgBytesPerSec: spec.avg_bytes_per_sec(),
        nBlockAlign: spec.block_align(),
        wBitsPerSample: spec.bits,
        cbSize: 0,
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
fn run_session(inner: &KeepaliveInner, device_id: u32, dw_formats: u32) -> bool {
    // Negotiate instead of assuming: a 48 kHz-only A2DP endpoint answers
    // 44.1 kHz with WAVERR_BADFORMAT (32), which used to fail the session
    // silently and let the earbuds idle-drop the link.
    let mut hwo: HANDLE = ptr::null_mut();
    let mut opened_spec: Option<WaveFormatSpec> = None;
    for spec in ranked_formats(dw_formats) {
        let fmt = wave_format(spec);
        let rc = unsafe { waveOutOpen(&mut hwo, device_id, &fmt, 0, 0, CALLBACK_NULL) };
        if rc == 0 {
            opened_spec = Some(spec);
            break;
        }
        btlog!(
            "keepalive: waveOutOpen(dev=#{device_id}, {} Hz/{} ch/{} bit) failed mmsys={rc}",
            spec.sample_rate,
            spec.channels,
            spec.bits
        );
    }
    let Some(spec) = opened_spec else {
        btlog!("keepalive: no supported format on endpoint #{device_id} -- session not opened");
        return false;
    };
    btlog!(
        "keepalive: streaming on endpoint #{device_id} at {} Hz/{} ch/{} bit",
        spec.sample_rate,
        spec.channels,
        spec.bits
    );

    let mut hdr = WAVEHDR {
        lpData: inner.buffer.as_ptr() as *mut u8,
        dwBufferLength: KEEPALIVE_BUF_SIZE as u32,
        dwFlags: WHDR_BEGINLOOP | WHDR_ENDLOOP,
        dwLoops: KEEPALIVE_LOOP_COUNT,
        ..Default::default()
    };
    let hdr_ptr: *mut WAVEHDR = &mut hdr;

    let rc = unsafe { waveOutPrepareHeader(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) };
    if rc != 0 {
        btlog!("keepalive: waveOutPrepareHeader failed mmsys={rc}");
        unsafe { waveOutClose(hwo) };
        return false;
    }

    let mut guard = SessionGuard { hwo, hdr: hdr_ptr, queued: false };

    let rc = unsafe { waveOutWrite(hwo, hdr_ptr, std::mem::size_of::<WAVEHDR>() as u32) };
    if rc != 0 {
        btlog!("keepalive: waveOutWrite failed mmsys={rc}");
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
    fn fresh_instance_idle() {
        let ka = SilentKeepalive::new(None);
        assert!(!ka.is_running());
        assert_eq!(ka.consec_fails(), 0);
        assert_eq!(ka.inner.device_id.load(Ordering::Acquire), WAVE_MAPPER);
    }
}
