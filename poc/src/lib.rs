//! PoC harness: includes the PRODUCTION sources verbatim (no copies) so the
//! tests exercise exactly what ships. Both files are Win32-free by design.
#[path = "../../src/config.rs"]
pub mod config;
#[path = "../../src/connect_fsm.rs"]
pub mod connect_fsm;
#[path = "../../src/redact.rs"]
pub mod redact;
#[path = "../../src/text.rs"]
pub mod text;
#[path = "../../src/endpoint.rs"]
pub mod endpoint;
#[path = "../../src/wake.rs"]
pub mod wake;
#[path = "../../src/dedup.rs"]
pub mod dedup;
#[path = "../../src/autostart_cmd.rs"]
pub mod autostart_cmd;
#[path = "../../src/ladder.rs"]
pub mod ladder;
/// Win32 constants `ladder.rs` needs, mirrored so the pure logic runs on Linux.
pub mod sys {
    pub mod cfgmgr32 {
        pub const CM_PROB_DISABLED: u32 = 0x16;
        pub const DN_HAS_PROBLEM: u32 = 0x400;
        pub const DN_STARTED: u32 = 0x8;
    }
}
