//! shell32.dll — only the elevation check the PnP rungs gate on.

use super::*;

#[link(name = "shell32")]
unsafe extern "system" {
    /// Non-zero when the current process token is elevated.
    pub fn IsUserAnAdmin() -> BOOL;
}
