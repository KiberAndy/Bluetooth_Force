//! Winsock2 FFI for the page-first path (`page.rs`).
//!
//! Only the calls an outgoing L2CAP page needs: startup, a non-blocking
//! `AF_BTH`/`SOCK_STREAM` socket, `connect` to the peer's SDP PSM,
//! `select` for the bounded wait, `getsockopt(SO_ERROR)` for the verdict.
//! Layouts pinned by hand like the rest of `sys` (see `sys/mod.rs`).

#![allow(non_snake_case)]

use super::GUID;

pub const AF_BTH: i32 = 32;
/// `SOCK_STREAM`: the only socket type `AF_BTH` accepts for L2CAP/RFCOMM
/// (`SOCK_SEQPACKET` fails at creation with `WSAESOCKTNOSUPPORT` 10044 --
/// seen in the field 18:02:09 before this fix).
pub const SOCK_STREAM: i32 = 1;
pub const BTHPROTO_L2CAP: i32 = 256;
pub const BTHPROTO_RFCOMM: i32 = 3;
pub const INVALID_SOCKET: usize = usize::MAX;
/// `FIONBIO` as `long` (negative as `i32`, hence the cast, not a literal).
pub const FIONBIO: i32 = 0x8004_667Eu32 as i32;
pub const SOL_SOCKET: i32 = 0xffff;
pub const SO_ERROR: i32 = 0x1007;

/// Winsock error codes the page verdict depends on (WinError.h).
pub const WSAEWOULDBLOCK: i32 = 10035;
pub const WSAECONNREFUSED: i32 = 10061;
pub const WSAETIMEDOUT: i32 = 10060;
pub const WSAEHOSTUNREACH: i32 = 10065;
pub const WSAENETUNREACH: i32 = 10051;
pub const WSAENETDOWN: i32 = 10050;

/// Opaque: only its size (408 bytes) matters for `WSAStartup`.
#[repr(C)]
pub struct WSADATA {
    pub _opaque: [u8; 408],
}

/// Bluetooth socket address (ws2bth.h `SOCKADDR_BTH`). The header wraps it
/// in `pshpack1.h`/`poppack.h`: NO padding -- 2 + 8 + 16 + 4 = 30 bytes.
/// `#[repr(C)]` would insert padding (40 bytes, shifted field offsets) and
/// the stack then rejects `connect` synchronously with `WSAENETDOWN`
/// 10050 -- seen in the field before this fix. A zero UUID with the PSM
/// in `port` addresses the L2CAP channel directly (MSDN `SOCKADDR_BTH`
/// remarks: legal when the app does its own SDP resolution; here the page
/// itself is the goal, so no SDP lookup is needed).
#[repr(C, packed(1))]
pub struct SOCKADDR_BTH {
    pub address_family: u16,
    pub bt_addr: u64,
    pub service_class_id: GUID,
    pub port: u32,
}

const _: () = assert!(core::mem::size_of::<SOCKADDR_BTH>() == 30);

/// `fd_set` sized for a single socket: `fd_count` gates how much of
/// `fd_array` `select` looks at, so the 63 spare slots are never touched.
#[repr(C)]
pub struct FD_SET {
    pub fd_count: u32,
    pub fd_array: [usize; 64],
}

#[repr(C)]
pub struct TIMEVAL {
    pub tv_sec: i32,
    pub tv_usec: i32,
}

#[link(name = "ws2_32")]
unsafe extern "system" {
    pub fn WSAStartup(wVersionRequested: u16, lpWSAData: *mut WSADATA) -> i32;
    pub fn WSACleanup() -> i32;
    pub fn socket(af: i32, socket_type: i32, protocol: i32) -> usize;
    pub fn ioctlsocket(s: usize, cmd: i32, argp: *mut u32) -> i32;
    pub fn connect(s: usize, name: *const SOCKADDR_BTH, namelen: i32) -> i32;
    pub fn select(
        nfds: i32,
        readfds: *mut FD_SET,
        writefds: *mut FD_SET,
        exceptfds: *mut FD_SET,
        timeout: *const TIMEVAL,
    ) -> i32;
    pub fn getsockopt(s: usize, level: i32, optname: i32, optval: *mut i32, optlen: *mut i32)
        -> i32;
    pub fn closesocket(s: usize) -> i32;
    pub fn WSAGetLastError() -> i32;
}
