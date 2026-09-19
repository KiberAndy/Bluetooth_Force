//! Bluetooth address parsing/formatting and the device-instance-ID matchers.

use std::fmt;

use crate::config;
use crate::util::contains_ignore_case;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MacError {
    InvalidFormat,
    InvalidHex,
    Zero,
}

impl fmt::Display for MacError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            MacError::InvalidFormat | MacError::InvalidHex => {
                f.write_str("Invalid MAC address format")
            }
            MacError::Zero => {
                f.write_str("MAC must be non-zero (00:00:00:00:00:00 is not a valid device)")
            }
        }
    }
}

fn hex_nibble(c: u8) -> Result<u8, MacError> {
    match c {
        b'0'..=b'9' => Ok(c - b'0'),
        b'A'..=b'F' => Ok(c - b'A' + 10),
        b'a'..=b'f' => Ok(c - b'a' + 10),
        _ => Err(MacError::InvalidHex),
    }
}

/// Parse `AA:BB:CC:DD:EE:FF` into the raw 48-bit address.
pub fn parse_mac(s: &str) -> Result<u64, MacError> {
    let b = s.as_bytes();
    if b.len() != 17 {
        return Err(MacError::InvalidFormat);
    }
    if b[2] != b':' || b[5] != b':' || b[8] != b':' || b[11] != b':' || b[14] != b':' {
        return Err(MacError::InvalidFormat);
    }
    let mut mac: u64 = 0;
    for i in 0..6 {
        let hi = hex_nibble(b[i * 3])?;
        let lo = hex_nibble(b[i * 3 + 1])?;
        mac = (mac << 8) | ((hi as u64) << 4) | (lo as u64);
    }
    // 00:00:00:00:00:00 is not a valid unicast device address; reject it here
    // so a zero target can never enter the poll loop.
    if mac == 0 {
        return Err(MacError::Zero);
    }
    Ok(mac)
}

fn hex_digit(v: u8) -> u8 {
    if v < 10 { b'0' + v } else { b'A' + (v - 10) }
}

/// `0x948B93B1E4A1` -> `"94:8B:93:B1:E4:A1"` (MSB first, uppercase).
pub fn format_mac(addr: u64) -> String {
    let mut out = String::with_capacity(17);
    for i in 0..6 {
        let b = (addr >> (8 * (5 - i))) as u8;
        out.push(hex_digit(b >> 4) as char);
        out.push(hex_digit(b & 0x0F) as char);
        if i < 5 {
            out.push(':');
        }
    }
    out
}

/// `0x948B93B1E4A1` -> `"948b93b1e4a1"`: the shape a BTHENUM instance ID
/// carries for the remote device address (lowercase, no separators).
pub fn mac_hex12(addr: u64) -> [u8; 12] {
    let mut out = [0u8; 12];
    for i in 0..6 {
        let b = (addr >> (8 * (5 - i))) as u8;
        out[i * 2] = (hex_digit(b >> 4) as char).to_ascii_lowercase() as u8;
        out[i * 2 + 1] = (hex_digit(b & 0x0F) as char).to_ascii_lowercase() as u8;
    }
    out
}

/// Does this device instance ID belong to the target earbuds? Case-insensitive.
pub fn id_contains_mac(id: &str, mac_hex12: &[u8; 12]) -> bool {
    contains_ignore_case(id.as_bytes(), mac_hex12)
}

/// Does this device instance ID belong to the CSR dongle (`VID_0A12`/`PID_0001`)?
pub fn is_csr_radio_instance_id(id: &str) -> bool {
    let lower = id.to_ascii_lowercase();
    contains_ignore_case(lower.as_bytes(), config::R2_MATCH_VID.as_bytes())
        && contains_ignore_case(lower.as_bytes(), config::R2_MATCH_PID.as_bytes())
}

/// Is this one of the earbuds' AUDIO profile nodes (A2DP sink / AVRCP)?
///
/// The rung is deliberately narrowed to these: restarting the container or the
/// non-audio profiles makes Windows re-enumerate the earbuds instead of
/// connecting them, which costs the default-endpoint switch.
pub fn is_earbud_audio_node(id: &str) -> bool {
    let lower = id.to_ascii_lowercase();
    contains_ignore_case(lower.as_bytes(), config::R3_AUDIO_PROFILE_A2DP.as_bytes())
        || contains_ignore_case(lower.as_bytes(), config::R3_AUDIO_PROFILE_AVRCP.as_bytes())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_valid() {
        assert_eq!(parse_mac("AA:BB:CC:DD:EE:FF").unwrap(), 0xAABBCCDDEEFF);
        assert_eq!(parse_mac("aA:bB:cC:dD:eE:fF").unwrap(), 0xAABBCCDDEEFF);
        assert_eq!(parse_mac("12:34:56:78:9A:BC").unwrap(), 0x123456789ABC);
    }

    #[test]
    fn parse_invalid() {
        for bad in ["", "AA:BB:CC:DD:EE", "AA-BB-CC-DD-EE-FF", "AABBCCDDEEFF", " AA:BB:CC:DD:EE:FF"] {
            assert_eq!(parse_mac(bad), Err(MacError::InvalidFormat));
        }
        assert_eq!(parse_mac("XX:BB:CC:DD:EE:FF"), Err(MacError::InvalidHex));
        assert_eq!(parse_mac("00:00:00:00:00:00"), Err(MacError::Zero));
    }

    #[test]
    fn format_round_trip() {
        assert_eq!(format_mac(parse_mac("94:8B:93:B1:E4:A1").unwrap()), "94:8B:93:B1:E4:A1");
        assert_eq!(format_mac(0), "00:00:00:00:00:00");
    }

    #[test]
    fn mac_hex_preserves_leading_zeros() {
        assert_eq!(&mac_hex12(0x948b93b1e4a1), b"948b93b1e4a1");
        assert_eq!(&mac_hex12(0x0a), b"00000000000a");
        assert_eq!(&mac_hex12(0xffffffffffff), b"ffffffffffff");
    }

    #[test]
    fn csr_instance_id_matcher() {
        assert!(is_csr_radio_instance_id("USB\\VID_0A12&PID_0001\\5&127C236B&0&3"));
        assert!(is_csr_radio_instance_id("usb\\vid_0a12&pid_0001\\x"));
        assert!(!is_csr_radio_instance_id("USB\\VID_0A12&PID_0002\\x"));
        assert!(!is_csr_radio_instance_id("USB\\VID_8087&PID_0026\\x"));
        assert!(!is_csr_radio_instance_id(""));
    }

    #[test]
    fn earbud_node_matching() {
        let mac = mac_hex12(0x948b93b1e4a1);
        let a2dp = "BTHENUM\\{0000110b-0000-1000-8000-00805f9b34fb}_VID&00010a12_PID&0001\\8&2f2c9c1&0&948b93b1e4a1_C00000000";
        let avrcp = "BTHENUM\\{0000110c-0000-1000-8000-00805f9b34fb}_LOCALMFG&0000\\8&2F2C9C1&0&948B93B1E4A1_C00000000";
        let dongle = "USB\\VID_0A12&PID_0001\\5&127C236B&0&3";
        assert!(id_contains_mac(a2dp, &mac));
        assert!(id_contains_mac(avrcp, &mac));
        assert!(is_earbud_audio_node(a2dp));
        assert!(is_earbud_audio_node(avrcp));
        assert!(!id_contains_mac(dongle, &mac));
        assert!(!is_earbud_audio_node(dongle));
    }
}
