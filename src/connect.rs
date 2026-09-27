//! Native reconnect path (Win32 glue).
//!
//! The decision logic lives in [`crate::connect_fsm`]; this file only binds it
//! to `BluetoothSetServiceState` (exported by the same `bthprops.cpl` already
//! loaded for the poll loop), so there is no helper binary and no
//! attacker-controlled command line.
//!
//! Why the profile driver is toggled instead of just enabled: per the Win32
//! contract, `BLUETOOTH_SERVICE_ENABLE` on a service that is ALREADY ENABLED
//! returns `E_INVALIDARG` and does nothing at all. A paired device's audio
//! services stay enabled across a disconnect, so a plain enable can never pull
//! the link back up. Removing and re-installing the driver (DISABLE -> quiet ->
//! ENABLE) is what makes the stack page the earbuds again.

use std::fs;

use crate::bluetooth::{BthApi, FnSetServiceState};
use crate::btlog;
use crate::config::SERVICE_DEBT_NAME;
use crate::connect_fsm::{self, ConnectResult, Profile, ServiceStateIo};
use crate::sys::bluetooth::{
    BLUETOOTH_DEVICE_INFO, BLUETOOTH_SERVICE_DISABLE, BLUETOOTH_SERVICE_ENABLE,
};
use crate::sys::kernel32;
use crate::sys::GUID;
use crate::sys::HANDLE;
use crate::util;

pub use crate::connect_fsm::ConnectOutcome;

/// `{0000110B-0000-1000-8000-00805F9B34FB}` — Advanced Audio Distribution
/// Profile sink (the earbuds' playback endpoint).
const A2DP_SINK: GUID =
    GUID::from_parts(0x0000_110b, 0x0000, 0x1000, [0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb]);
/// `{0000111E-0000-1000-8000-00805F9B34FB}` — Handsfree profile.
const HANDSFREE: GUID =
    GUID::from_parts(0x0000_111e, 0x0000, 0x1000, [0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb]);
/// `{0000110C-0000-1000-8000-00805F9B34FB}` — A/V Remote Control target.
const AVRCP: GUID =
    GUID::from_parts(0x0000_110c, 0x0000, 0x1000, [0x80, 0x00, 0x00, 0x80, 0x5f, 0x9b, 0x34, 0xfb]);

fn profile_guid(profile: Profile) -> &'static GUID {
    match profile {
        Profile::A2dp => &A2DP_SINK,
        Profile::Hfp => &HANDSFREE,
        Profile::Avrcp => &AVRCP,
    }
}

struct Win32ServiceState<'a> {
    set_service_state: FnSetServiceState,
    radio: HANDLE,
    info: &'a BLUETOOTH_DEVICE_INFO,
}

impl ServiceStateIo for Win32ServiceState<'_> {
    fn set_state(&mut self, profile: Profile, enable: bool) -> u32 {
        let flags = if enable { BLUETOOTH_SERVICE_ENABLE } else { BLUETOOTH_SERVICE_DISABLE };
        // SAFETY: `radio` is a live radio handle from the poll loop and `info`
        // is the record that same enumeration produced, which is exactly what
        // the API requires.
        unsafe { (self.set_service_state)(self.radio, self.info, profile_guid(profile), flags) }
    }

    fn wait(&mut self, ms: u32) {
        unsafe { kernel32::Sleep(ms) };
    }

    fn log(&mut self, msg: &str) {
        crate::log::write_line(msg);
    }

    fn debt_arm(&mut self, profile: Profile) -> bool {
        debt_arm(profile)
    }

    fn debt_clear(&mut self) {
        debt_clear();
    }
}

/// Write the "we removed this profile's driver" marker and verify it is really
/// on disk. Same crash-safety contract as the devnode recovery journal: the
/// promise to undo has to outlive the process before the damage is done.
fn debt_arm(profile: Profile) -> bool {
    let Some(path) = util::self_dir_path(SERVICE_DEBT_NAME) else {
        return false;
    };
    let write = || -> std::io::Result<()> {
        use std::io::Write;
        let mut f = fs::File::create(&path)?;
        f.write_all(profile.name().as_bytes())?;
        f.write_all(b"\r\n")?;
        f.sync_all()
    };
    if write().is_err() {
        return false;
    }
    path.exists()
}

fn debt_clear() {
    if let Some(path) = util::self_dir_path(SERVICE_DEBT_NAME) {
        let _ = fs::remove_file(path);
    }
}

/// Which profile, if any, is currently owed a driver. Read on every poll and
/// at startup, so a crash between DISABLE and ENABLE cannot strand the stack.
pub fn debt_profile() -> Option<Profile> {
    let path = util::self_dir_path(SERVICE_DEBT_NAME)?;
    let body = fs::read_to_string(path).ok()?;
    let name = body.trim();
    Profile::ORDER.into_iter().find(|p| p.name() == name)
}

/// Put an owed driver back before anything else is attempted. Returns true
/// when the debt is settled (marker gone).
pub fn repay_debt(
    api: &BthApi,
    radio: HANDLE,
    info: &BLUETOOTH_DEVICE_INFO,
    profile: Profile,
) -> bool {
    let Some(set_service_state) = api.set_service_state else {
        btlog!("connect: BluetoothSetServiceState unavailable — cannot repay the profile-driver debt");
        return false;
    };
    let mut io = Win32ServiceState { set_service_state, radio, info };
    connect_fsm::reenable_profile(&mut io, profile)
}

/// Bring `info`'s audio profile up on `radio`.
///
/// `allow_toggle` is the caller's rate limit for the driver re-install; when it
/// is false, an already-enabled service is reported as
/// [`ConnectOutcome::Refused`] and nothing is touched.
///
/// The return value is a receipt, not a state change: only the next poll's
/// `fConnected` proves the link actually came up, which is why the worker never
/// treats a receipt as a cure.
pub fn connect(
    api: &BthApi,
    radio: HANDLE,
    info: &BLUETOOTH_DEVICE_INFO,
    allow_toggle: bool,
) -> ConnectResult {
    let Some(set_service_state) = api.set_service_state else {
        btlog!("connect: BluetoothSetServiceState unavailable in bthprops.cpl — native connect disabled");
        return ConnectResult {
            outcome: ConnectOutcome::Failed,
            toggled: false,
            service_left_disabled: false,
        };
    };

    let mut io = Win32ServiceState { set_service_state, radio, info };
    connect_fsm::drive_connect(&mut io, allow_toggle)
}
