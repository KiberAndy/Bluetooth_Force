//! Ask the Windows A2DP driver to connect, not a raw HFP socket or driver install.
use crate::btlog;
use crate::sys::core_audio::{Apartment, Com, KS_IID, TOPOLOGY_IID};

/// Match the paired address AND the A2DP sink profile in the adapter identity.
/// Friendly names are not identities; multiple Bluetooth headsets may coexist.
fn target_adapter(id: &str, mac: u64) -> bool {
    let id = id.to_ascii_lowercase();
    id.contains("bthenum#{0000110b-0000-1000-8000-00805f9b34fb}")
        && id.split(['#', '&', '_', '\\']).any(|part| part == format!("{mac:012x}"))
}

pub fn due(now: i64, last: i64) -> bool {
    last == 0 || now.saturating_sub(last) >= crate::config::AUDIO_CONNECT_CADENCE_MS
}

/// None: no supported target filter. Some(hr): a request was issued.
/// S_OK is only a receipt; endpoint streaming is still checked independently.
pub fn request(mac: u64) -> Option<i32> {
    let _apartment = Apartment::init().ok()?;
    let enumerator = Com::enumerator().ok()?;
    let endpoints = enumerator.endpoints().ok()?;
    for i in 0..endpoints.count().ok()? {
        let attempt = || -> Result<Option<i32>, i32> {
            let endpoint = endpoints.item(i)?;
            let topology = endpoint.activate(&TOPOLOGY_IID)?;
            let connector = topology.item(0)?;
            let id = connector.adapter_id()?;
            if !target_adapter(&String::from_utf16_lossy(&id), mac) {
                return Ok(None);
            }
            let adapter = enumerator.device(&id)?;
            let ks = adapter.activate(&KS_IID)?;
            let hr = ks.reconnect();
            btlog!("audio-connect: A2DP ONESHOT_RECONNECT hr=0x{:08x} (request only; waiting for target audio)", hr as u32);
            Ok(Some(hr))
        };
        if let Ok(Some(hr)) = attempt() { return Some(hr); }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    const ID: &str = "{2}.\\\\?\\bthenum#{0000110b-0000-1000-8000-00805f9b34fb}_vid&000102b0_pid&0000#7&837fa7a&0&948b93b1e4a1_c00000000#{6994ad04-93ef-11d0-a3cc-00a0c9223196}\\src";
    #[test]
    fn selects_target_a2dp_not_hfp_or_another_headset() {
        assert!(target_adapter(ID, 0x948b93b1e4a1));
        assert!(target_adapter(&ID.to_uppercase(), 0x948b93b1e4a1));
        assert!(!target_adapter(&ID.replace("0000110b", "0000111e"), 0x948b93b1e4a1));
        assert!(!target_adapter(ID, 0x948b93b1e4a2));
        assert!(!target_adapter(&ID.replace("&948b", "&1948b"), 0x948b93b1e4a1));
    }
    #[test]
    fn short_transport_flaps_do_not_reset_the_audio_request_clock() {
        assert!(due(1000, 0));
        assert!(!due(7000, 1000)); // the observed six-second control-only link
        assert!(!due(10999, 1000));
        assert!(due(11000, 1000));
    }
}
