//! Replays representative lines from the real field log through the shipped
//! redaction pass and checks that nothing identifying survives.

use poc::redact::redact_line;

const FIELD_LOG: &[&str] = &[
    "start: build=rust3.0 mac=94:8B:93:B1:E4:A1 exe=G:\\Projects\\Bluetooth_Force\\target\\release\\bluetooth_force.exe admin=true log=btf.log",
    "rung recovery: nothing to repair: 1 radio devnode(s) present and started -- stale journal cleared",
    "connect: A2DP REFUSED (E_INVALIDARG: service already enabled) -- a plain enable never reaches the peer",
    "connect: forcing a reconnect on A2DP (disable -> enable)",
    "connect: A2DP driver re-installed -- reconnect requested",
    "rung earbud-restart: begin (mac=948b93b1e4a1)",
    "rung earbud-restart: skip (non-audio, left untouched) bthenum\\dev_948b93b1e4a1\\7&1d4ec691&0&bluetoothdevice_948b93b1e4a1",
    "rung earbud-restart: node bthenum\\{0000110b-0000-1000-8000-00805f9b34fb}_vid&000102b0_pid&0000\\7&1d4ec691&0&948b93b1e4a1_c00000000",
    "rung earbud-restart:   restarted via pnputil (verified STARTED)",
    "waveOut[2] = Наушники (Redmi Buds 6 Lite Ste",
    "keepalive -> endpoint #2 (Наушники (Redmi Buds 6 Lite Ste)",
    "R1: incoming connections were already OFF (0x80070057) -- the radio is not connectable; re-enabling",
    "link DOWN after 12030 ms (keepalive running=true, failed render sessions=0)",
];

/// Everything that must never reach a shared log.
const SECRETS: &[&str] = &[
    "94:8b:93:b1:e4:a1",
    "948b93b1e4a1",
    "redmi",
    "наушники",
    "g:\\projects",
];

#[test]
fn field_log_is_clean_and_still_readable() {
    for line in FIELD_LOG {
        let red = redact_line(line);
        println!("{red}");
        let lower = red.to_lowercase();
        for secret in SECRETS {
            assert!(!lower.contains(secret), "leaked {secret:?} in: {red}");
        }
    }
    // Readability: the diagnostic vocabulary survives untouched.
    assert_eq!(redact_line(FIELD_LOG[3]), FIELD_LOG[3]);
    assert_eq!(redact_line(FIELD_LOG[11]), FIELD_LOG[11]);
    assert!(redact_line(FIELD_LOG[7]).contains("{0000110b-0000-1000-8000-00805f9b34fb}"));
}
