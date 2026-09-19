//! cfgmgr32.dll entry points: devnode status and the CfgMgr32 enable/disable
//! fallback path.

use super::*;

pub const CR_SUCCESS: u32 = 0;
pub const DN_HAS_PROBLEM: u32 = 0x0000_0400;
pub const DN_STARTED: u32 = 0x0000_0008;
/// Problem code reported while a devnode is software-disabled.
pub const CM_PROB_DISABLED: u32 = 22;

#[link(name = "cfgmgr32")]
unsafe extern "system" {
    pub fn CM_Get_DevNode_Status(
        ulStatus: *mut u32,
        ulProblemNumber: *mut u32,
        dnDevInst: DEVINST,
        ulFlags: u32,
    ) -> CONFIGRET;
    pub fn CM_Disable_DevNode(dnDevInst: DEVINST, ulFlags: u32) -> CONFIGRET;
    pub fn CM_Enable_DevNode(dnDevInst: DEVINST, ulFlags: u32) -> CONFIGRET;
}
