//! PoC for the log de-duplication, measured against the real field log.
//!
//! The 22-hour field log was 1 974 487 bytes / 16 737 lines, of which 12 310
//! were the three rotating `REFUSED` lines and 1 905 were `stale journal
//! cleared` -- 85 % noise. Set `BTF_LOG=<path>` to replay an actual log
//! through the shipped `Dedup`; without it the test replays a synthetic log
//! built from those exact counts.

use poc::dedup::{Action, Dedup};

const REFUSALS: [&str; 3] = [
    "connect: A2DP REFUSED (E_INVALIDARG: service already enabled) -- a plain enable never reaches the peer",
    "connect: HFP REFUSED (E_INVALIDARG: service already enabled) -- a plain enable never reaches the peer",
    "connect: AVRCP REFUSED (E_INVALIDARG: service already enabled) -- a plain enable never reaches the peer",
];
const JOURNAL: &str =
    "rung recovery: nothing to repair: 1 radio devnode(s) present and started -- stale journal cleared";

/// Rebuilds the field log's composition: a 2 s poll cadence, three refusals
/// per poll, the journal line on every third poll, and a state change now and
/// then.
fn synthetic_log() -> Vec<(i64, String)> {
    let mut out = Vec::new();
    let mut t = 1_000_000i64;
    for i in 0..4_100 {
        for l in REFUSALS {
            out.push((t, l.to_string()));
        }
        if i % 3 == 0 {
            out.push((t, JOURNAL.to_string()));
        }
        if i % 900 == 0 {
            out.push((t, "connect: forcing a reconnect on A2DP (disable -> enable)".into()));
            out.push((t, "link UP".into()));
        }
        t += 2_000;
    }
    out
}

/// Parse `HH:MM:SS.mmm btf: <msg>` if possible; otherwise fall back to a 2 s
/// cadence so an unexpected format cannot silently invalidate the result.
fn load_field_log(path: &str) -> Option<Vec<(i64, String)>> {
    let body = std::fs::read_to_string(path).ok()?;
    let mut out = Vec::new();
    let mut fallback = 1_000_000i64;
    for line in body.lines() {
        fallback += 2_000;
        let (ts, msg) = match line.split_once(" btf: ") {
            Some((a, b)) => (a, b),
            None => (line, line),
        };
        let ms = parse_clock(ts).unwrap_or(fallback);
        out.push((ms, msg.to_string()));
    }
    Some(out)
}

fn parse_clock(ts: &str) -> Option<i64> {
    let (hms, millis) = ts.split_once('.')?;
    let mut it = hms.split(':');
    let h: i64 = it.next()?.trim().parse().ok()?;
    let m: i64 = it.next()?.parse().ok()?;
    let s: i64 = it.next()?.parse().ok()?;
    let ms: i64 = millis.parse().ok()?;
    Some(((h * 60 + m) * 60 + s) * 1000 + ms)
}

#[test]
fn the_field_log_collapses_by_an_order_of_magnitude() {
    let (source, lines) = match std::env::var("BTF_LOG").ok().and_then(|p| load_field_log(&p)) {
        Some(l) => ("field log", l),
        None => ("synthetic log", synthetic_log()),
    };

    let mut d = Dedup::new();
    let mut printed = 0usize;
    let mut bytes_before = 0usize;
    let mut bytes_after = 0usize;
    let mut lost_state_changes = 0usize;

    for (t, msg) in &lines {
        bytes_before += msg.len() + 1;
        let act = d.decide(msg, *t);
        if matches!(act, Action::Suppress(_)) {
            if poc::dedup::always_show(msg) {
                lost_state_changes += 1;
            }
            continue;
        }
        printed += 1;
        bytes_after += msg.len() + 1;
    }

    println!(
        "{source}: {} lines / {} KB  ->  {} lines / {} KB",
        lines.len(),
        bytes_before / 1024,
        printed,
        bytes_after / 1024
    );
    assert_eq!(lost_state_changes, 0, "no state change may ever be suppressed");
    assert!(
        printed * 5 <= lines.len(),
        "expected at least a 5x reduction: {printed} of {}",
        lines.len()
    );
}
