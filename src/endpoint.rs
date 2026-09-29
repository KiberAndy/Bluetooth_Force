//! Pure endpoint policy for the silent keepalive: which waveOut device to
//! stream to, and in which PCM format.
//!
//! Field evidence (btf.log): right after the A2DP driver is re-installed the
//! endpoint is enumerated and matched correctly, yet every render session
//! fails (`failed render sessions=2..3`) and the earbuds drop the link ~12 s
//! later on their own idle timer. A session that never opens is a keepalive
//! that does not keep anything alive, so the open path must (a) report the
//! `MMSYSERR`/`WAVERR` code instead of failing silently, (b) re-resolve the
//! endpoint on every retry, because a driver re-install renumbers the waveOut
//! list, and (c) negotiate the format instead of hard-coding 44.1 kHz stereo:
//! `WAVERR_BADFORMAT` on a 48 kHz-only A2DP endpoint fails exactly like this.

use crate::config::{ENDPOINT_PROBE_BASE_MS, ENDPOINT_PROBE_CAP_MS};
use crate::text::contains_ignore_case;

fn is_fxsound_name(name: &str) -> bool {
    contains_ignore_case(name.as_bytes(), b"fxsound")
        || contains_ignore_case(name.as_bytes(), b"fx sound")
}

/// Pick the waveOut device that routes the keepalive directly to the earbuds,
/// bypassing FxSound's default-device APO.
///
/// 1. If `override_name` is set, return the first device whose name contains it.
/// 2. Otherwise match any >=4-char alphanumeric token of the Bluetooth name,
///    skipping FxSound endpoints.
///
/// `None` means "fall back to WAVE_MAPPER".
pub fn select_audio_device(
    names: &[String],
    bt_name: &str,
    override_name: Option<&str>,
) -> Option<usize> {
    if let Some(ov) = override_name {
        if !ov.is_empty() {
            return names
                .iter()
                .position(|n| contains_ignore_case(n.as_bytes(), ov.as_bytes()));
        }
    }

    let bytes = bt_name.as_bytes();
    let mut start = 0usize;
    let mut i = 0usize;
    while i <= bytes.len() {
        let at_end = i == bytes.len();
        let is_sep = at_end || !bytes[i].is_ascii_alphanumeric();
        if is_sep {
            let token = &bytes[start..i];
            if token.len() >= 4 {
                if let Some(idx) = names
                    .iter()
                    .position(|n| !is_fxsound_name(n) && contains_ignore_case(n.as_bytes(), token))
                {
                    return Some(idx);
                }
            }
            start = i + 1;
        }
        i += 1;
    }
    None
}

/// One PCM format the keepalive is willing to stream.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WaveFormatSpec {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits: u16,
}

impl WaveFormatSpec {
    pub const fn new(sample_rate: u32, channels: u16, bits: u16) -> Self {
        Self { sample_rate, channels, bits }
    }
    pub const fn block_align(self) -> u16 {
        self.channels * (self.bits / 8)
    }
    pub const fn avg_bytes_per_sec(self) -> u32 {
        self.sample_rate * self.block_align() as u32
    }
}

/// Tried in this order. 48 kHz first: an A2DP endpoint that rejects 44.1 kHz
/// with `WAVERR_BADFORMAT` is the failure mode the field log shows.
pub const KEEPALIVE_FORMATS: [WaveFormatSpec; 4] = [
    WaveFormatSpec::new(48_000, 2, 16),
    WaveFormatSpec::new(44_100, 2, 16),
    WaveFormatSpec::new(48_000, 1, 16),
    WaveFormatSpec::new(44_100, 1, 16),
];

/// `WAVEOUTCAPS.dwFormats` bit for a standard format, if it has one (mmreg.h).
pub fn standard_format_bit(spec: WaveFormatSpec) -> Option<u32> {
    let bit = match (spec.sample_rate, spec.channels, spec.bits) {
        (44_100, 1, 16) => 0x0000_0400, // WAVE_FORMAT_4M16
        (44_100, 2, 16) => 0x0000_0800, // WAVE_FORMAT_4S16
        (48_000, 1, 16) => 0x0000_4000, // WAVE_FORMAT_48M16
        (48_000, 2, 16) => 0x0000_8000, // WAVE_FORMAT_48S16
        _ => return None,
    };
    Some(bit)
}

/// Order the candidate formats for one endpoint: the ones its caps advertise
/// first, the rest after.
///
/// The unadvertised ones are still tried, because a WASAPI-backed endpoint can
/// report `dwFormats == 0` and still open anything the mixer can convert.
pub fn ranked_formats(dw_formats: u32) -> Vec<WaveFormatSpec> {
    let mut advertised = Vec::new();
    let mut rest = Vec::new();
    for spec in KEEPALIVE_FORMATS {
        match standard_format_bit(spec) {
            Some(bit) if dw_formats & bit != 0 => advertised.push(spec),
            _ => rest.push(spec),
        }
    }
    advertised.extend(rest);
    advertised
}

/// How long a WAVE_MAPPER fallback session may run before the endpoint list is
/// re-read (0-based attempt).
///
/// The field log showed the earbuds' render endpoint missing for a moment
/// right after a reconnect: 5 of 8 reconnects started the keepalive on
/// WAVE_MAPPER, which streams to whatever the DEFAULT device happens to be --
/// possibly the speakers, in which case the A2DP link gets no audio at all and
/// the earbuds are free to idle out. The fallback therefore has to be
/// temporary: re-resolve soon, then back off so a machine that genuinely has
/// no earbud endpoint does not reopen a session every second forever.
pub fn probe_wait_ms(attempt: u32) -> u32 {
    let mut v = ENDPOINT_PROBE_BASE_MS;
    let mut i = 0;
    while i < attempt {
        v = v.saturating_mul(2);
        if v >= ENDPOINT_PROBE_CAP_MS {
            return ENDPOINT_PROBE_CAP_MS;
        }
        i += 1;
    }
    v.min(ENDPOINT_PROBE_CAP_MS)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names() -> Vec<String> {
        vec![
            "Speakers (FxSound Audio Enhancer)".to_string(),
            "Headphones (WF-1000XM5 Stereo)".to_string(),
            "Realtek HD Audio".to_string(),
        ]
    }

    #[test]
    fn the_wave_mapper_fallback_is_retried_soon_then_backs_off() {
        assert_eq!(probe_wait_ms(0), ENDPOINT_PROBE_BASE_MS);
        assert_eq!(probe_wait_ms(1), ENDPOINT_PROBE_BASE_MS * 2);
        assert_eq!(probe_wait_ms(99), ENDPOINT_PROBE_CAP_MS);
        // The first re-check has to land within a couple of seconds: that is
        // the window in which the endpoint actually appeared in the field log.
        assert!(probe_wait_ms(0) <= 2_000);
    }

    #[test]
    fn device_selection() {
        let names = names();
        assert_eq!(select_audio_device(&names, "WF-1000XM5", None), Some(1));
        assert_eq!(select_audio_device(&names, "XY", None), None);
        assert_eq!(select_audio_device(&names, "WF-1000XM5", Some("realtek")), Some(2));
        assert_eq!(select_audio_device(&names, "WF-1000XM5", Some("nope")), None);
    }

    /// Regression: a driver re-install renumbers the waveOut list, so the
    /// endpoint must be resolved from a FRESH enumeration, never from a cached
    /// index.
    #[test]
    fn a_renumbered_list_resolves_to_the_new_index() {
        let before = names();
        assert_eq!(select_audio_device(&before, "WF-1000XM5", None), Some(1));

        // The A2DP endpoint disappears and comes back at the end of the list.
        let after = vec![
            "Speakers (FxSound Audio Enhancer)".to_string(),
            "Realtek HD Audio".to_string(),
            "Headphones (WF-1000XM5 Stereo)".to_string(),
        ];
        assert_eq!(select_audio_device(&after, "WF-1000XM5", None), Some(2));

        // And while it is gone there is nothing to stream to.
        let gone = vec!["Realtek HD Audio".to_string()];
        assert_eq!(select_audio_device(&gone, "WF-1000XM5", None), None);
    }

    #[test]
    fn format_bits_match_mmreg() {
        assert_eq!(standard_format_bit(WaveFormatSpec::new(44_100, 2, 16)), Some(0x800));
        assert_eq!(standard_format_bit(WaveFormatSpec::new(48_000, 2, 16)), Some(0x8000));
        assert_eq!(standard_format_bit(WaveFormatSpec::new(96_000, 2, 16)), None);
    }

    #[test]
    fn caps_reorder_the_candidates_but_never_drop_one() {
        // A 48 kHz-only endpoint: 48S16 first.
        let only48 = ranked_formats(0x8000);
        assert_eq!(only48[0], WaveFormatSpec::new(48_000, 2, 16));
        assert_eq!(only48.len(), KEEPALIVE_FORMATS.len());

        // A 44.1 kHz-only endpoint: 44.1 stereo is promoted ahead of 48 kHz.
        let only441 = ranked_formats(0x800);
        assert_eq!(only441[0], WaveFormatSpec::new(44_100, 2, 16));
        assert_eq!(only441.len(), KEEPALIVE_FORMATS.len());

        // Caps unavailable: the default order, nothing dropped.
        assert_eq!(ranked_formats(0).as_slice(), &KEEPALIVE_FORMATS[..]);
    }
}
