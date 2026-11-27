# Panther Thermal Detector v2.1.5 — FIELD TEST

Lua thermal hint and confirmation widgets for FrSky ETHOS. This snapshot is tuned for one FrSky X20R / F5J Panther installation and is published to invite field testing. It is experimental; it does not control the aircraft and does not guarantee that a detected climb is thermal lift.

## Version and package

- Current source: **v2.1.5 FIELD TEST**
- Installation archive: `PantherThermalDetector_v2_1_5_CONFIRMED_RELIABILITY_INSTALL.zip`
- The archive contains the same `scripts/` and `audio/` layout as this repository.
- Detailed setup notes and the test record are in [`SETUP_SK.md`](SETUP_SK.md) and [`TEST_STATUS.md`](TEST_STATUS.md).

## What it uses

GPS altitude and GPS vario are the primary lift evidence. GPS Logger 3 ground speed is a cross-check. Native `Elevator` activity adjusts the score and, together with a speed drop, delays confirmation. The original Panther vario sounds, ARM logic, and motor control are intended to remain separate.

The shipped configuration uses names and switch numbers from the author's X20R/Panther setup. Review every source mapping and logical/special function before using it on another model or transmitter.

## Install

Extract the installation ZIP to the radio's storage root (`RADIO:/`). It provides:

```text
scripts/PantherThermalSource/main.lua
scripts/PantherThermalDetector/main.lua
audio/cs/default/pan_therm_hint.wav
audio/cs/default/pan_therm_confirm.wav
```

The repository root contains these same `scripts/` and `audio/` folders for review. The exact source mapping, logical switches, sounds, and logging setup are documented in `SETUP_SK.md`.

## Test status

The last detailed flight-log review in the available project history concerned **v2.1**, not v2.1.5. It found useful lift indications but also a state/logging inconsistency and missing diagnostic fields. The pilot confirmed one logged interval as real thermal lift. Those older results do not validate this v2.1.5 build; see [`TEST_STATUS.md`](TEST_STATUS.md) before testing.

## Feedback

For a useful report, include the exact script version, ETHOS version, transmitter and sensor setup, whether the aircraft was actually in thermal lift, and the relevant `TScore`, `TState`, altitude, vario, GPS speed, current, and Elevator values. Do not include personal account tokens or credentials in logs or issues.

## License

No reuse license is included in this test snapshot. Public visibility permits review; it does not grant permission to redistribute or incorporate the code into another product.

