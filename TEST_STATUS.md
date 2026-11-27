# Test status — Panther Thermal Detector

## Published build

- **v2.1.5 FIELD TEST**
- Package file: `PantherThermalDetector_v2_1_5_CONFIRMED_RELIABILITY_INSTALL.zip`
- It remains a field-test build, not a generally validated thermal detector.
- The reviewed project history does not contain a confirmed flight-test report for v2.1.5 itself.

## Earlier v2.1 flight-log review

Two flights dated 2026-10-05 were reviewed for v2.1:

| Flight | Maximum altitude | Maximum current | Maximum score | SUSPECT | CONFIRMED |
|---|---:|---:|---:|---:|---:|
| 15:46 | 225.7 m | 40.7 A | 69% | 1 | 0 |
| 16:29 | 215.9 m | 40.8 A | 40% | 0 | 0 |

The review found score remained zero during four motor runs per flight and below 50 m. The pilot confirmed the interval around **16:12:48–16:12:51** as real thermal lift: score rose to 69%, vario was about +0.9 to +1.1 m/s, altitude rose from roughly 192.7 to 195.2 m, current was 0 A, and Elevator was neutral.

## Unresolved evidence from that older build

The v2.1 CSV logs did not contain the new diagnostic outputs `EAct`, `SpdDn`, and `PUp`. The review also noticed score values returning shortly after a `SUSPECT → NONE` transition despite a 20-second refractory rule in the reviewed v2.1 source. The source/log combination therefore was not enough to validate those internal signals.

After that review, the project history records a v2.1b adjustment to soften Elevator-only penalty and combine strong Elevator activity with GPS-speed decrease. The present local package is later, **v2.1.5**, with revised confirmation timing and persistence behavior documented in `SETUP_SK.md` and the source. The older flight results must not be presented as proof that v2.1.5 has passed flight testing.

## What a v2.1.5 test should record

Use the actual X20R and the intended sensors. Record the precise Lua version and ETHOS version, then capture `TScore`, `TState`, altitude, GPS vario, GPS speed, current, and Elevator around each HINT/CONFIRM transition. Compare the log with the pilot's observation and report false, late, repeated, or missing alerts. Keep the prior working scripts and radio configuration backed up before changing the transmitter.

