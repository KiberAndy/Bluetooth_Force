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
