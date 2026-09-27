//! PoC for the second field failure: `link DOWN after 12093 ms (keepalive
//! running=true, failed render sessions=2)`.
//!
//! The endpoint exists and is matched correctly, but every render session
//! fails, so nothing is streamed and the earbuds hit their own idle timer and
//! drop the link. Modelled here with an endpoint that only accepts 48 kHz
//! stereo 16-bit and answers anything else with WAVERR_BADFORMAT (32), which
//! is the documented reply for an unsupported format.

use poc::endpoint::*;

/// `WAVE_FORMAT_48S16` only.
const CAPS_48_ONLY: u32 = 0x8000;
const WAVERR_BADFORMAT: u32 = 32;
/// How long the earbuds tolerate a silent A2DP link (field log: 12–14 s).
const IDLE_DROP_MS: i64 = 12_000;
/// One reconnect costs a disable/enable of the profile driver (field log).
const RECONNECT_MS: i64 = 6_500;
const HORIZON_MS: i64 = 10 * 60 * 1000;

/// The hard-coded format of the original `run_session`.
const LEGACY_FORMAT: WaveFormatSpec = WaveFormatSpec::new(44_100, 2, 16);

fn open_endpoint(caps: u32, spec: WaveFormatSpec) -> u32 {
    match standard_format_bit(spec) {
        Some(bit) if caps & bit != 0 => 0,
        _ => WAVERR_BADFORMAT,
    }
}

struct Session {
    streaming: bool,
    tried: usize,
}

/// Original behaviour: one hard-coded format, no negotiation.
fn legacy_session(caps: u32) -> Session {
    Session { streaming: open_endpoint(caps, LEGACY_FORMAT) == 0, tried: 1 }
}

/// Fixed behaviour: walk the ranked candidates until one opens.
fn fixed_session(caps: u32) -> Session {
    let mut tried = 0;
    for spec in ranked_formats(caps) {
        tried += 1;
        if open_endpoint(caps, spec) == 0 {
            return Session { streaming: true, tried };
        }
    }
    Session { streaming: false, tried }
}

struct Run {
    drops: u32,
    streaming_ms: i64,
    formats_tried: usize,
}

fn simulate(caps: u32, fixed: bool) -> Run {
    let mut now = 0i64;
    let mut drops = 0;
    let mut streaming_ms = 0;
    let mut formats_tried = 0;

    while now < HORIZON_MS {
        // Each cycle: reconnect the profile, then start a render session.
        now += RECONNECT_MS;
        let session = if fixed { fixed_session(caps) } else { legacy_session(caps) };
        formats_tried = session.tried;

        if session.streaming {
            // A live stream keeps the idle timer from ever firing.
            streaming_ms += HORIZON_MS - now;
            break;
        }
        // Nothing is streamed: the earbuds drop the link on their own.
        now += IDLE_DROP_MS;
        drops += 1;
    }

    Run { drops, streaming_ms, formats_tried }
}

#[test]
fn legacy_hardcoded_format_loses_the_link_forever() {
    let r = simulate(CAPS_48_ONLY, false);
    println!(
        "LEGACY : idle drops={} streaming={} ms formats_tried={}",
        r.drops, r.streaming_ms, r.formats_tried
    );
    assert_eq!(r.formats_tried, 1, "the original code tried exactly one format");
    assert_eq!(r.streaming_ms, 0, "nothing was ever streamed");
    assert!(r.drops >= 20, "REPRODUCED: an endless connect / idle-drop cycle ({} drops)", r.drops);
}

#[test]
fn negotiated_format_holds_the_link() {
    let r = simulate(CAPS_48_ONLY, true);
    println!(
        "FIXED  : idle drops={} streaming={} ms formats_tried={}",
        r.drops, r.streaming_ms, r.formats_tried
    );
    assert_eq!(r.drops, 0, "the first session must open and stay open");
    assert!(r.streaming_ms > HORIZON_MS - 2 * RECONNECT_MS);
}

/// The fix must not regress the endpoint that worked before.
#[test]
fn a_441_only_endpoint_still_works() {
    let caps_441 = 0x800;
    assert!(legacy_session(caps_441).streaming);
    let r = simulate(caps_441, true);
    assert_eq!(r.drops, 0);
    assert_eq!(r.formats_tried, 1, "44.1 kHz is promoted by the caps, so it opens first");
}

/// An endpoint that advertises nothing must still be attempted, not skipped.
#[test]
fn unknown_caps_do_not_skip_the_endpoint() {
    assert_eq!(ranked_formats(0).len(), KEEPALIVE_FORMATS.len());
}
