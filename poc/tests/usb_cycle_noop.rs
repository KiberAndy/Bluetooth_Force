//! Field log btf.log: 7 real usb-cycles all returned 3010 after ~7.7 s; the
//! other 62 "succeeded" in 20-30 ms without restarting anything, and the rung
//! ran 69 times in one afternoon while the earbuds were not answering.
use poc::ladder::*;

#[test]
fn field_3010_is_reboot_required() {
    for took in [7700, 7830, 7760, 7800, 7950, 5660] {
        assert_eq!(pnputil_restart_verdict(3010, took), RestartVerdict::RebootRequired);
    }
}

#[test]
fn field_20ms_success_is_a_noop() {
    for took in [18, 20, 30] {
        assert_eq!(pnputil_restart_verdict(0, took), RestartVerdict::NoOp);
    }
}

#[test]
fn a_real_restart_still_counts() {
    assert_eq!(pnputil_restart_verdict(0, 4_000), RestartVerdict::Restarted);
    assert_eq!(pnputil_restart_verdict(1, 4_000), RestartVerdict::Failed);
}

#[test]
fn one_cycle_per_outage() {
    let armed = 1_000_000;
    assert!(usb_cycle_left_in_episode(0, armed));
    assert!(!usb_cycle_left_in_episode(armed + 60_000, armed)); // already cycled
    assert!(usb_cycle_left_in_episode(armed + 60_000, armed + 3_600_000)); // next outage
    assert!(!usb_cycle_left_in_episode(0, 0)); // no outage
}
