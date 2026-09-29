//! Log de-duplication — pure logic, no Win32, no I/O.
//!
//! The field log was 1.9 MB for 22 hours, and 85 % of it was the same handful
//! of lines repeating every 2 s (`A2DP/HFP/AVRCP REFUSED`, `stale journal
//! cleared`). That is not a cosmetic problem: a log nobody can read is a log
//! that hides the one line that mattered.
//!
//! The spam cycles through SEVERAL distinct lines (A, B, C, A, B, C...), so
//! "suppress if equal to the previous line" would catch nothing. Suppression
//! is therefore keyed per message: a line is printed at most once per
//! [`DEDUP_WINDOW_MS`], and when it is printed again it carries the number of
//! copies it stands for.
//!
//! Lines that report a state CHANGE are never suppressed, however often they
//! repeat — losing one of those to save bytes would be a bad trade.

use crate::config::{DEDUP_SLOTS, DEDUP_WINDOW_MS};

/// What the caller should print.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Action {
    /// Print the line unchanged.
    Print,
    /// Print nothing; `n` copies are now pending for this message.
    Suppress(u32),
    /// Print the line plus "(+n identical lines suppressed in the last s s)".
    PrintWithCount(u32, i64),
}

/// Never suppressed: every one of these marks a transition, a decision or a
/// verdict, and they are rare by construction.
pub fn always_show(msg: &str) -> bool {
    const KEEP: [&str; 10] = [
        "link UP",
        "link DOWN",
        "link down for",
        "forcing a reconnect",
        "driver re-installed",
        "RE-ENABLE",
        "debt",
        "btf: start",
        "REBOOT",
        "MUTED",
    ];
    KEEP.iter().any(|k| msg.contains(k))
}

#[derive(Clone, Copy)]
struct Slot {
    key: u64,
    last_print_ms: i64,
    pending: u32,
}

/// Fixed-size, allocation-free table of recently printed messages. The oldest
/// slot is reused when the table is full, so a pathological variety of
/// messages degrades into "print everything", never into unbounded memory.
pub struct Dedup {
    slots: [Slot; DEDUP_SLOTS],
}

impl Default for Dedup {
    fn default() -> Self {
        Self::new()
    }
}

impl Dedup {
    pub const fn new() -> Self {
        Self { slots: [Slot { key: 0, last_print_ms: 0, pending: 0 }; DEDUP_SLOTS] }
    }

    pub fn decide(&mut self, msg: &str, now_ms: i64) -> Action {
        if always_show(msg) {
            return Action::Print;
        }
        let key = hash(msg);

        if let Some(i) = self.slots.iter().position(|s| s.key == key) {
            let since = now_ms - self.slots[i].last_print_ms;
            // A clock that went backwards must not freeze a message forever.
            if since >= DEDUP_WINDOW_MS || since < 0 {
                let pending = self.slots[i].pending;
                self.slots[i].pending = 0;
                self.slots[i].last_print_ms = now_ms;
                return if pending == 0 {
                    Action::Print
                } else {
                    Action::PrintWithCount(pending, since)
                };
            }
            self.slots[i].pending = self.slots[i].pending.saturating_add(1);
            return Action::Suppress(self.slots[i].pending);
        }

        // New message: take a free slot, else the least recently printed one.
        let i = self
            .slots
            .iter()
            .position(|s| s.key == 0)
            .unwrap_or_else(|| {
                let mut oldest = 0;
                for (j, s) in self.slots.iter().enumerate() {
                    if s.last_print_ms < self.slots[oldest].last_print_ms {
                        oldest = j;
                    }
                }
                oldest
            });
        self.slots[i] = Slot { key, last_print_ms: now_ms, pending: 0 };
        Action::Print
    }
}

/// FNV-1a. Collisions only ever cost an extra suppressed line, never
/// correctness of the surrounding state machine.
fn hash(s: &str) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for b in s.as_bytes() {
        h ^= *b as u64;
        h = h.wrapping_mul(0x0000_0100_0000_01b3);
    }
    // 0 is the "empty slot" marker.
    if h == 0 { 1 } else { h }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The exact shape of the field spam: three lines cycling every 2 s.
    #[test]
    fn a_rotating_trio_of_lines_is_collapsed() {
        let lines = [
            "connect: A2DP REFUSED (E_INVALIDARG: service already enabled)",
            "connect: HFP REFUSED (E_INVALIDARG: service already enabled)",
            "connect: AVRCP REFUSED (E_INVALIDARG: service already enabled)",
        ];
        let mut d = Dedup::new();
        let mut printed = 0;
        let mut t = 1_000_000i64;
        // One hour of polling every 2 s.
        for _ in 0..1_800 {
            for l in lines {
                if !matches!(d.decide(l, t), Action::Suppress(_)) {
                    printed += 1;
                }
            }
            t += 2_000;
        }
        let before = 1_800 * 3;
        println!("1 h of refusals: {before} lines before, {printed} after");
        assert!(printed * 20 <= before, "expected a >=20x reduction, got {printed}/{before}");
        assert!(printed > 0, "the state must still be visible periodically");
    }

    #[test]
    fn the_first_copy_always_prints_and_the_count_survives() {
        let mut d = Dedup::new();
        let t = 1_000_000;
        assert_eq!(d.decide("x", t), Action::Print);
        assert_eq!(d.decide("x", t + 1), Action::Suppress(1));
        assert_eq!(d.decide("x", t + 2), Action::Suppress(2));
        match d.decide("x", t + DEDUP_WINDOW_MS) {
            Action::PrintWithCount(n, _) => assert_eq!(n, 2),
            other => panic!("expected the suppressed count to be reported, got {other:?}"),
        }
        // The count resets after it is reported.
        assert_eq!(d.decide("x", t + DEDUP_WINDOW_MS + 1), Action::Suppress(1));
    }

    #[test]
    fn state_changes_are_never_suppressed() {
        let mut d = Dedup::new();
        for i in 0..100 {
            assert_eq!(d.decide("link UP", 1_000_000 + i), Action::Print);
            assert_eq!(d.decide("connect: forcing a reconnect on A2DP", 1_000_000 + i), Action::Print);
        }
    }

    #[test]
    fn a_flood_of_distinct_messages_does_not_break_the_table() {
        let mut d = Dedup::new();
        for i in 0..10_000 {
            let msg = format!("unique message {i}");
            assert_eq!(d.decide(&msg, 1_000_000 + i as i64), Action::Print);
        }
        // And a message that is still hot is still suppressed afterwards.
        let hot = "hot line";
        assert_eq!(d.decide(hot, 2_000_000), Action::Print);
        assert_eq!(d.decide(hot, 2_000_001), Action::Suppress(1));
    }

    #[test]
    fn a_backwards_clock_cannot_mute_a_message_forever() {
        let mut d = Dedup::new();
        let t = 5_000_000;
        assert_eq!(d.decide("y", t), Action::Print);
        assert_eq!(d.decide("y", t + 1), Action::Suppress(1));
        assert!(matches!(d.decide("y", t - 10_000), Action::PrintWithCount(1, _)));
    }
}
