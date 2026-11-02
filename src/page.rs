//! Outgoing page: the reconnect path the field ETW proved.
//!
//! The manual "Подключить" path is `HCI_Create_Connection` (the host pages
//! the peer) followed by profile connects (`docs/manual_connect_path.md`).
//! A Winsock `connect()` on an `AF_BTH` socket to one of the peer's profile
//! channels makes the stack emit exactly that page: there is no user-mode
//! HCI API, this socket IS the paging primitive.
//! `BluetoothSetServiceState(ENABLE)` never pages -- the capture showed zero
//! HCI for it -- so this runs BEFORE the toggle ladder.
//!
//! Transport: the field probe (`--page-probe`) proved the stack refuses an
//! L2CAP client connect synchronously (error 10050 on both the zero-UUID+PSM
//! and the UUID variants, no page on the air), while an RFCOMM UUID-based
//! connect goes asynchronous -- a real page, the peer answers or times out.
//! So the daemon pages over RFCOMM to Hands-Free; L2CAP stays only in the
//! probe as a regression tripwire.
//!
//! Bounded by construction: non-blocking socket + `select` with
//! `PAGE_CONNECT_TIMEOUT_MS`. Failed attempts close their socket; a
//! successful page KEEPS its socket open for the whole down episode (the
//! field ETW proved closing it drops the ACL: host `HCI_Disconnect`
//! +3.08 s after the page, exactly the old settle window). WSA is started
//! once per process and never cleaned up: cleaning up while a held socket
//! lives could invalidate it, and the OS reclaims both on process exit.

use std::sync::atomic::{AtomicBool, Ordering};

use crate::btlog;
use crate::config::*;
use crate::mac::format_mac;
use crate::page_fsm::{classify_socket_error, PageOutcome};
use crate::sys::GUID;
use crate::sys::ws2_32 as w;

pub use crate::page_fsm::PageOutcome as PageResult;

/// Process-lifetime WSA: started once, never cleaned up (see module docs).
static WSA_UP: AtomicBool = AtomicBool::new(false);

fn ensure_wsa() -> Result<(), i32> {
    if WSA_UP.load(Ordering::Acquire) {
        return Ok(());
    }
    // SAFETY: valid pointer for the call duration; balanced by design
    // (never cleaned up -- process lifetime, see `WSA_UP`).
    let mut wsadata: w::WSADATA = unsafe { core::mem::zeroed() };
    if unsafe { w::WSAStartup(0x0202, &mut wsadata) } != 0 {
        return Err(unsafe { w::WSAGetLastError() });
    }
    WSA_UP.store(true, Ordering::Release);
    Ok(())
}

/// Page the peer and HOLD the socket on success. Returns the outcome plus
/// the open socket when the page went out; the caller owns it and must
/// pass it to `close_held` (episode close, resume, or a fresher page).
/// Never parks the poll loop past `PAGE_CONNECT_TIMEOUT_MS`.
pub fn page_hold(addr: u64) -> (PageResult, Option<usize>) {
    // SAFETY: every call below passes valid pointers for the call duration;
    // the error code is captured BEFORE any cleanup: after cleanup it is
    // gone. `stage` names the Winsock call that failed (field diagnosis:
    // error 10050 WSAENETDOWN seen 18:05:28 with no stage attached).
    if let Err(err) = ensure_wsa() {
        btlog!(
            "page: Winsock WSAStartup failed, error {} -- falling through to the ladder",
            err
        );
        return (PageOutcome::Failed, None);
    }
    let (out, err, stage, held) = unsafe { page_connected(addr) };
    match out {
        PageOutcome::Attempted => btlog!(
            "page: outgoing RFCOMM page to Hands-Free on {} -- holding the socket open for the episode (closing it drops the ACL, field ETW 18:49)",
            format_mac(addr),
        ),
        PageOutcome::Unreachable => btlog!(
            "page: {} did not answer the page -- falling through to the ladder",
            format_mac(addr)
        ),
        PageOutcome::Failed => btlog!(
            "page: Winsock {stage} failed ({}), error {} -- falling through to the ladder",
            format_mac(addr),
            err
        ),
    }
    (out, held)
}

/// Close a socket previously returned by `page_hold`. Closing is the
/// self-hangup, so this runs only when the link no longer needs OUR DLC:
/// episode close (Windows holds the link), resume (sockets die in sleep),
/// or a fresher page replacing a stale one.
pub fn close_held(s: usize) {
    // SAFETY: `s` came from `page_hold`; WSA is up for the process lifetime.
    let rc = unsafe { w::closesocket(s) };
    if rc != 0 {
        let err = unsafe { w::WSAGetLastError() };
        btlog!("page: closing the held socket failed, error {} (harmless)", err);
    }
}

/// A2DP Sink profile UUID (`0000110B-0000-1000-8000-00805F9B34FB`): the
/// earbuds expose it (BTHENUM `0000110b` devnode in the field log). Used for
/// the second page attempt, where the stack runs its own SDP lookup.
const A2DP_SINK_UUID: GUID =
    GUID::from_parts(0x0000_110B, 0x0000, 0x1000, [0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB]);

/// Hands-Free (HF) profile UUID (`0000111E-...`): an RFCOMM-based service
/// the earbuds expose (HFP connects in the field log). The daemon pages
/// over RFCOMM to this UUID; the probe reuses it as the Winsock-alive check.
const HFP_HF_UUID: GUID =
    GUID::from_parts(0x0000_111E, 0x0000, 0x1000, [0x80, 0x00, 0x00, 0x80, 0x5F, 0x9B, 0x34, 0xFB]);

/// One bounded connect on a fresh socket: `Attempted` (page went out, or an
/// instant accept), `Unreachable` (timeout/refused at peer), `Failed`
/// (rejected locally -- stage+error name the call). With `keep`, a
/// successful socket is returned open (the episode hold); every other path
/// closes it. WSA lifetime stays with the caller.
unsafe fn connect_one(
    proto: i32,
    sa: &w::SOCKADDR_BTH,
    sync_stage: &'static str,
    keep: bool,
) -> (PageOutcome, i32, &'static str, Option<usize>) {
    let s = unsafe { w::socket(w::AF_BTH, w::SOCK_STREAM, proto) };
    if s == w::INVALID_SOCKET {
        let err = unsafe { w::WSAGetLastError() };
        return (PageOutcome::Failed, err, "socket", None);
    }
    // Non-blocking first: a sleeping peer must not park the poll loop.
    let mut nonblock: u32 = 1;
    if unsafe { w::ioctlsocket(s, w::FIONBIO, &mut nonblock) } != 0 {
        let err = unsafe { w::WSAGetLastError() };
        unsafe { w::closesocket(s) };
        return (PageOutcome::Failed, err, "ioctlsocket", None);
    }
    let rc = unsafe {
        w::connect(
            s,
            sa,
            core::mem::size_of::<w::SOCKADDR_BTH>() as i32,
        )
    };
    let out = if rc == 0 {
        (PageOutcome::Attempted, 0, "", None)
    } else {
        let err = unsafe { w::WSAGetLastError() };
        if err == w::WSAEWOULDBLOCK {
            unsafe { wait_writable(s) }
        } else {
            (classify_socket_error(err), err, sync_stage, None)
        }
    };
    match out {
        // The page went out: the socket stays open ONLY when the caller
        // holds it for the episode; the probe and failed paths close.
        (PageOutcome::Attempted, _, _, _) if keep => (PageOutcome::Attempted, 0, "", Some(s)),
        (o, e, st, _) => {
            unsafe { w::closesocket(s) };
            (o, e, st, None)
        }
    }
}

/// Transport probe for `--page-probe`: the same peer over three transports.
/// Discriminates "L2CAP blocked, RFCOMM pages" from "Winsock paging dead".
pub fn probe_transports(addr: u64) -> [(&'static str, PageOutcome, i32, &'static str); 3] {
    // SAFETY: same pointer contract as `page_hold` (see above).
    let direct = w::SOCKADDR_BTH {
        address_family: w::AF_BTH as u16,
        bt_addr: addr,
        service_class_id: GUID::default(),
        port: PAGE_PSM,
    };
    let l2cap_uuid = w::SOCKADDR_BTH {
        address_family: w::AF_BTH as u16,
        bt_addr: addr,
        service_class_id: A2DP_SINK_UUID,
        port: 0,
    };
    let rfcomm_uuid = w::SOCKADDR_BTH {
        address_family: w::AF_BTH as u16,
        bt_addr: addr,
        service_class_id: HFP_HF_UUID,
        port: 0,
    };
    unsafe {
        let mut wsadata = core::mem::zeroed::<w::WSADATA>();
        if w::WSAStartup(0x0202, &mut wsadata) != 0 {
            let err = w::WSAGetLastError();
            return [
                ("l2cap-psm", PageOutcome::Failed, err, "WSAStartup"),
                ("l2cap-uuid", PageOutcome::Failed, err, "WSAStartup"),
                ("rfcomm-uuid", PageOutcome::Failed, err, "WSAStartup"),
            ];
        }
        let a = connect_one(w::BTHPROTO_L2CAP, &direct, "connect-psm", false);
        let b = connect_one(w::BTHPROTO_L2CAP, &l2cap_uuid, "connect-uuid", false);
        let c = connect_one(w::BTHPROTO_RFCOMM, &rfcomm_uuid, "connect-rfcomm", false);
        w::WSACleanup();
        [
            ("l2cap-psm", a.0, a.1, a.2),
            ("l2cap-uuid", b.0, b.1, b.2),
            ("rfcomm-uuid", c.0, c.1, c.2),
        ]
    }
}

unsafe fn page_connected(addr: u64) -> (PageOutcome, i32, &'static str, Option<usize>) {
    // Field evidence (transport probe, --page-probe): the stack refuses
    // L2CAP client connect synchronously (10050 on both direct-PSM and
    // UUID variants -- no page goes out), while an RFCOMM UUID-based
    // connect goes asynchronous (real page, peer answers or times out).
    // So the daemon pages over RFCOMM to the Hands-Free service and lets
    // the stack run its own SDP lookup + page; L2CAP stays only in the
    // probe as a regression tripwire.
    let via_sdp = w::SOCKADDR_BTH {
        address_family: w::AF_BTH as u16,
        bt_addr: addr,
        service_class_id: HFP_HF_UUID,
        port: 0,
    };
    // SAFETY: `connect_one` contract, see `page_hold`. `keep=true`: on
    // success the socket stays open -- the episode hold (see module docs).
    unsafe { connect_one(w::BTHPROTO_RFCOMM, &via_sdp, "connect-rfcomm", true) }
}

/// The connect is in flight: wait writable up to the timeout, then read the
/// real verdict via `SO_ERROR` (a writable socket may still be a refusal).
/// Never returns an open socket (4th element always `None`): keeping is
/// decided by `connect_one`, not here.
unsafe fn wait_writable(s: usize) -> (PageOutcome, i32, &'static str, Option<usize>) {
    let mut wfds = w::FD_SET {
        fd_count: 1,
        fd_array: [s; 64],
    };
    let tv = w::TIMEVAL {
        tv_sec: (PAGE_CONNECT_TIMEOUT_MS / 1000) as i32,
        tv_usec: ((PAGE_CONNECT_TIMEOUT_MS % 1000) * 1000) as i32,
    };
    let n = unsafe {
        w::select(
            0,
            core::ptr::null_mut(),
            &mut wfds,
            core::ptr::null_mut(),
            &tv,
        )
    };
    if n > 0 {
        let mut so_err: i32 = 0;
        let mut len: i32 = core::mem::size_of::<i32>() as i32;
        if unsafe { w::getsockopt(s, w::SOL_SOCKET, w::SO_ERROR, &mut so_err, &mut len) } != 0 {
            let err = unsafe { w::WSAGetLastError() };
            return (PageOutcome::Failed, err, "getsockopt(SO_ERROR)", None);
        }
        let (outcome, code) = (classify_socket_error(so_err), so_err);
        (outcome, code, "SO_ERROR", None)
    } else if n == 0 {
        // Timeout: the page went out and nobody answered.
        (PageOutcome::Unreachable, 0, "", None)
    } else {
        let err = unsafe { w::WSAGetLastError() };
        (PageOutcome::Failed, err, "select", None)
    }
}
