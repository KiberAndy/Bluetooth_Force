//! winmm.dll entry points and the wave structures for the silent keepalive.

use super::*;

pub const WAVE_MAPPER: u32 = 0xFFFF_FFFF;
pub const CALLBACK_NULL: u32 = 0;
pub const WAVE_FORMAT_PCM: u16 = 1;
pub const WHDR_DONE: u32 = 0x0000_0001;
pub const WHDR_BEGINLOOP: u32 = 0x0000_0004;
pub const WHDR_ENDLOOP: u32 = 0x0000_0008;

#[repr(C)]
#[derive(Clone, Copy, Default)]
pub struct WAVEFORMATEX {
    pub wFormatTag: u16,
    pub nChannels: u16,
    pub nSamplesPerSec: u32,
    pub nAvgBytesPerSec: u32,
    pub nBlockAlign: u16,
    pub wBitsPerSample: u16,
    pub cbSize: u16,
}

#[repr(C)]
pub struct WAVEHDR {
    pub lpData: *mut u8,
    pub dwBufferLength: u32,
    pub dwBytesRecorded: u32,
    pub dwUser: usize,
    pub dwFlags: u32,
    pub dwLoops: u32,
    pub lpNext: *mut WAVEHDR,
    pub reserved: usize,
}

impl Default for WAVEHDR {
    fn default() -> Self {
        // SAFETY: trailing bookkeeping fields are all "null / zero" by contract.
        unsafe { std::mem::zeroed() }
    }
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct WAVEOUTCAPSW {
    pub wMid: u16,
    pub wPid: u16,
    pub vDriverVersion: u32,
    pub szPname: [u16; 32],
    pub dwFormats: u32,
    pub wChannels: u16,
    pub wReserved1: u16,
    pub dwSupport: u32,
}

impl Default for WAVEOUTCAPSW {
    fn default() -> Self {
        // SAFETY: POD.
        unsafe { std::mem::zeroed() }
    }
}

#[link(name = "winmm")]
unsafe extern "system" {
    pub fn waveOutOpen(
        phwo: *mut HANDLE,
        uDeviceID: u32,
        pwfx: *const WAVEFORMATEX,
        dwCallback: usize,
        dwInstance: usize,
        fdwOpen: u32,
    ) -> u32;
    pub fn waveOutPrepareHeader(hwo: HANDLE, pwh: *mut WAVEHDR, cbwh: u32) -> u32;
    pub fn waveOutWrite(hwo: HANDLE, pwh: *mut WAVEHDR, cbwh: u32) -> u32;
    pub fn waveOutUnprepareHeader(hwo: HANDLE, pwh: *mut WAVEHDR, cbwh: u32) -> u32;
    pub fn waveOutClose(hwo: HANDLE) -> u32;
    pub fn waveOutReset(hwo: HANDLE) -> u32;
    pub fn waveOutGetNumDevs() -> u32;
    pub fn waveOutGetDevCapsW(uDeviceID: usize, pwoc: *mut WAVEOUTCAPSW, cbwoc: u32) -> u32;
}
