//! Central tuning surface. Every magic number from the field-validated ladder
//! lives here so the timing model can be read (and reasoned about) in one place.

// ---------------------------------------------------------------------------
// Poll loop
// ---------------------------------------------------------------------------

/// Worker poll cadence. Worst-case latency from "earbuds connected" to sound.
pub const POLL_INTERVAL_MS: u32 = 2_000;
/// Settle time after a power-resume broadcast before polling.
pub const RESUME_DELAY_MS: u32 = 3_000;

// ---------------------------------------------------------------------------
// Reconnect backoff and storm cap
// ---------------------------------------------------------------------------

pub const CONNECT_BACKOFF_BASE_MS: u32 = 500;
pub const CONNECT_BACKOFF_CAP_MS: u32 = 4_000;

pub const CONNECT_CB_WINDOW_MS: i64 = 10_000;
pub const CONNECT_CB_MAX_EVENTS: u32 = 20;
pub const CONNECT_CB_COOLDOWN_MS: i64 = 30_000;

// ---------------------------------------------------------------------------
// Paged-pool watchdog
// ---------------------------------------------------------------------------

pub const WATCHDOG_TRIP_BYTES: u64 = 800 * 1024 * 1024;
pub const WATCHDOG_CLEAR_BYTES: u64 = 200 * 1024 * 1024;
pub const WATCHDOG_FORCE_CLEAR_MS: i64 = 30 * 60 * 1000;
pub const WATCHDOG_LOG_INTERVAL_MS: i64 = 60 * 1000;

// ---------------------------------------------------------------------------
// R1 — programmatic radio reset ("software re-plug", page-scan toggle)
// ---------------------------------------------------------------------------

pub const R1_ARM_MS: i64 = 20_000;
pub const R1_COOLDOWN_MS: i64 = 60_000;
pub const R1_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R1_CB_MAX_RESETS: u32 = 3;
pub const R1_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
pub const R1_TOGGLE_QUIET_MS: u32 = 300;
pub const R1_REENABLE_ATTEMPTS: u32 = 5;
pub const R1_REENABLE_RETRY_MS: u32 = 100;
pub const R1_POST_RESET_RECONNECT_MS: i64 = 2_000;
/// After this many consecutive rejections the page-scan rung is muted.
pub const R1_DEAD_REJECTIONS: u32 = 3;

/// Flap hysteresis: an episode closes only after this many consecutive
/// connected polls; a lone connected blip counts as a flap.
pub const LINK_STABLE_POLLS_TO_CLOSE: u32 = 3;
pub const FLAP_FORCE_R1_AFTER: u32 = 3;

// ---------------------------------------------------------------------------
// R2 — usb-cycle (devnode disable/enable, "hardware re-plug")
// ---------------------------------------------------------------------------

pub const R2_ARM_MS: i64 = 45_000;
pub const R2_MIN_INTERVAL_MS: i64 = 120_000;
pub const R2_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R2_CB_MAX_CYCLES: u32 = 2;
pub const R2_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
pub const R2_DISABLE_QUIET_MS: u32 = 2_000;
pub const R2_DISABLE_VERIFY_MS: u32 = 3_000;
pub const R2_ENABLE_VERIFY_MS: u32 = 2_500;
pub const R2_REENUM_POLL_MS: u32 = 250;
pub const R2_POST_CYCLE_RECONNECT_MS: i64 = 2_000;
/// After this many attempts that left the radio not started, mute the rung.
pub const R2_DEAD_FAILURES: u32 = 2;
pub const PNPUTIL_TIMEOUT_MS: u32 = 30_000;
pub const PNPUTIL_REBOOT_REQUIRED: u32 = 3010;
/// The dongle this build cycles: CSR-based BT radio.
pub const R2_MATCH_VID: &str = "vid_0a12";
pub const R2_MATCH_PID: &str = "pid_0001";

// ---------------------------------------------------------------------------
// R3 — earbud audio-devnode restart
// ---------------------------------------------------------------------------

pub const R3_ARM_MS: i64 = 30_000;
pub const R3_MIN_INTERVAL_MS: i64 = 90_000;
pub const R3_MAX_PER_EPISODE: u32 = 2;
pub const R3_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R3_CB_MAX_RESTARTS: u32 = 3;
pub const R3_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
pub const R3_POST_CYCLE_DELAY_MS: i64 = 15_000;
pub const R3_POST_RESTART_RECONNECT_MS: i64 = 3_000;
pub const R3_QUIET_MS: u32 = 1_500;
pub const R3_VERIFY_MS: u32 = 4_000;
pub const R3_MAX_NODES: u32 = 16;
pub const R3_PNPUTIL_TIMEOUT_MS: u32 = 20_000;
/// Only these two BTHENUM profile nodes are touched (A2DP sink / AVRCP).
pub const R3_AUDIO_PROFILE_A2DP: &str = "{0000110b";
pub const R3_AUDIO_PROFILE_AVRCP: &str = "{0000110c";
pub const R2_POST_R3_QUIET_MS: i64 = 30_000;

// ---------------------------------------------------------------------------
// R4 — hub port power-cycle (VBUS drop on the dongle's port)
// ---------------------------------------------------------------------------

pub const R4_ARM_MS: i64 = 90_000;
pub const R4_MIN_INTERVAL_MS: i64 = 300_000;
pub const R4_CB_WINDOW_MS: i64 = 10 * 60 * 1000;
pub const R4_CB_MAX_PORTCYCLES: u32 = 2;
pub const R4_CB_COOLDOWN_MS: i64 = 10 * 60 * 1000;
pub const R4_POST_CYCLE_RECONNECT_MS: i64 = 2_000;
pub const R4_REENUM_VERIFY_MS: u32 = 10_000;
pub const R4_REENUM_POLL_MS: u32 = 250;
pub const R4_DEAD_FAILURES: u32 = 2;
pub const CSR_VID: u16 = 0x0A12;
pub const CSR_PID: u16 = 0x0001;

// USB hub IOCTLs (usbioctl.h): FILE_DEVICE_USB=0x22, METHOD_BUFFERED,
// FILE_ANY_ACCESS. CTL_CODE = (0x22<<16)|(Function<<2).
pub const IOCTL_USB_GET_NODE_INFORMATION: u32 = 0x220408; // Function 258
pub const IOCTL_USB_GET_NODE_CONNECTION_INFORMATION_EX: u32 = 0x220484; // Function 289
pub const IOCTL_USB_GET_NODE_CONNECTION_INFORMATION: u32 = 0x22040C; // Function 259
pub const IOCTL_USB_HUB_CYCLE_PORT: u32 = 0x220488; // Function 290
pub const USB_HUB_NODE: u32 = 0;
pub const USB_DEVICE_CONNECTED: u32 = 1;
/// Raw offset of `wHubCharacteristics` in the hub node reply.
pub const HUB_CHARS_OFFSET: usize = 7;
/// Non-EX reply packs one byte tighter: `ConnectionStatus` sits at 31, not 32.
pub const NONEX_CONN_STATUS_OFFSET: usize = 31;

// ---------------------------------------------------------------------------
// Recovery journal + repair rung (rung 0)
// ---------------------------------------------------------------------------

pub const RECOVERY_JOURNAL_NAME: &str = "btf_pending_enable.txt";
pub const RECOVERY_RETRY_MS: i64 = 5_000;
pub const RECOVERY_BACKOFF_CAP_MS: i64 = 60_000;
pub const RECOVERY_QUIET_AFTER: u32 = 10;
pub const RECOVERY_VERIFY_MS: u32 = 3_000;

/// A streak of "device not found" verdicts freezes the radio-destructive rungs.
pub const PEER_ABSENT_FREEZE_AFTER: u32 = 5;
/// How often the freeze kill switch is re-read while running.
pub const FREEZE_RECHECK_MS: i64 = 15_000;

// ---------------------------------------------------------------------------
// Silent audio keepalive
// ---------------------------------------------------------------------------

pub const KEEPALIVE_BUF_SIZE: usize = 8192;
pub const KEEPALIVE_DRAIN_SPINS: u32 = 400; // 400 * 5ms = 2s hard cap
pub const KEEPALIVE_BACKOFF_BASE_MS: u32 = 250;
pub const KEEPALIVE_BACKOFF_CAP_MS: u32 = 5_000;
pub const KEEPALIVE_CB_WINDOW_MS: i64 = 10_000;
pub const KEEPALIVE_CB_MAX_OPENS: u32 = 30;
pub const KEEPALIVE_CB_COOLDOWN_MS: i64 = 30_000;
/// Consecutive failed render sessions that flag the A2DP path as dead.
pub const KEEPALIVE_DEAD_SESSIONS: u32 = 3;
/// Makes one buffer play effectively forever (~46ms * 2^31 ≈ years).
pub const KEEPALIVE_LOOP_COUNT: u32 = 0x7FFF_FFFF;

// ---------------------------------------------------------------------------
// Durable log
// ---------------------------------------------------------------------------

pub const LOG_MAX_BYTES: u64 = 2 * 1024 * 1024;
pub const LOG_NAME: &str = "btf.log";
pub const LOG_OLD_NAME: &str = "btf.log.1";

pub const WINDOW_CLASS_NAME: &str = "BtForceWindow";
pub const WINDOW_TITLE: &str = "BtForce";
pub const SINGLETON_MUTEX: &str = "Global\\BluetoothForceDaemon";

pub const USAGE: &str = "Usage: bluetooth_force.exe AA:BB:CC:DD:EE:FF [audio-name-substring] \
| --health [MAC] [report-path] | --cycle [report-path] \
| --restart-earbuds MAC [report-path] | --recover | --probe-hubs [report-path]";
