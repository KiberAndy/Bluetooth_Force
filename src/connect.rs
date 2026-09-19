//! Native reconnect path.
//!
//! The original build shelled out to `ToothTray.exe connect "<name>"` on every
//! poll. That dependency is gone: `BluetoothSetServiceState` (exported by the
//! same `bthprops.cpl` already loaded for the poll loop) brings a paired
//! device's profile up directly, in-process, with no helper binary and no
//! attacker-controlled command line.
//!
//! Profiles are tried weakest-to-strongest for audio: A2DP sink first (the
//! profile that carries playback), then Handsfree (calls/mic) and finally
//! AVRCP. A device that supports none of them is reported as absent, which is
//! the same verdict ToothTray's exit code 2 used to carry — so the ladder's
//! peer-absent freeze keeps working exactly as before.

use crate::bluetooth::BthApi;
use crate::btlog;
use crate::sys::bluetooth::{
    BLUETOOTH_DEVICE_INFO, BLUETOOTH_SERVICE_ENABLE, ERROR_SERVICE_DOES_NOT_EXIST,
};
use crate::sys::kernel32;
use crate::sys::HANDLE;
use crate::sys::GUID;

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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConnectOutcome {
    /// At least one profile was accepted — the link should come up.
    Connected,
    /// The peer offers none of the audio profiles we know: treat as absent.
    NotFound,
    /// A real failure (or the connect export is unavailable).
    Failed,
}

/// Bring `info`'s audio profile up on `radio`.
///
/// The return value is a receipt, not a state change: only the next poll's
/// `fConnected` proves the link actually came up, which is why the worker never
/// treats `Connected` as a cure on its own.
pub fn connect(api: &BthApi, radio: HANDLE, info: &BLUETOOTH_DEVICE_INFO) -> ConnectOutcome {
    let Some(set_service_state) = api.set_service_state else {
        btlog!("connect: BluetoothSetServiceState unavailable in bthprops.cpl — native connect disabled");
        return ConnectOutcome::Failed;
    };

    let mut any_not_found = false;
    let mut any_other_error = false;

    for (name, guid) in [("A2DP", A2DP_SINK), ("HFP", HANDSFREE), ("AVRCP", AVRCP)] {
        let rc = unsafe { set_service_state(radio, info, &guid, BLUETOOTH_SERVICE_ENABLE) };
        match rc {
            0 => {
                btlog!("connect: {name} enabled on the peer (BluetoothSetServiceState=OK)");
                return ConnectOutcome::Connected;
            }
            ERROR_SERVICE_DOES_NOT_EXIST => {
                any_not_found = true;
            }
            other => {
                any_other_error = true;
                btlog!("connect: {name} enable failed rc=0x{other:x} (last error 0x{:x})", unsafe {
                    kernel32::GetLastError()
                });
            }
        }
    }

    if any_other_error || !any_not_found {
        ConnectOutcome::Failed
    } else {
        // Every profile was rejected as "not offered" -> the peer is not around.
        ConnectOutcome::NotFound
    }
}
