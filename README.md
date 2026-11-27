# Panther Thermal Detector v2.1.5 — FIELD TEST

Lua thermal hint and confirmation widgets for FrSky ETHOS. This snapshot is tuned for one FrSky X20R / F5J Panther installation and is published to invite field testing by the wider ETHOS community. It is experimental; it does not control the aircraft and does not guarantee that a detected climb is thermal lift.

## Version and package

- Current source: **v2.1.5 FIELD TEST**
- Installation archive: `PantherThermalDetector_v2_1_5_CONFIRMED_RELIABILITY_INSTALL.zip`
- The archive contains the same `scripts/` and `audio/` layout as this repository.
- Detailed setup notes and the test record are in [`SETUP_SK.md`](SETUP_SK.md) and [`TEST_STATUS.md`](TEST_STATUS.md).

## Development and tuning history

### v2.0 — core lift detection

The initial detector used GPS altitude and GPS vario as its primary lift evidence. It combined filtered vertical-speed signals with persistence and GPS-altitude trend, waited for motor-off settling, and applied a 50 m altitude gate and motor lock. The later versions retain this core approach.

### v2.1 — first flight-tested Elevator and GPS-speed layer

The v2.1 field-test build added the native ETHOS `Elevator` input and GPS Logger 3 ground speed as supporting evidence. Elevator movement was filtered into activity; GPS speed was used as a cross-check. Their combination was intended to help distinguish a pilot-induced pull-up from sustained lift, while keeping GPS altitude and vario as the primary thermal evidence.

Two v2.1 flights on 2026-10-05 were reviewed. The pilot confirmed a logged interval as real thermal lift. In the reviewed logs the detector reached a maximum score of 69%, remained at zero during motor runs and below 50 m, and did not enter CONFIRMED. The result was encouraging and showed a meaningful lift signal, while also identifying refinements needed to the state timing and diagnostics. See [`TEST_STATUS.md`](TEST_STATUS.md) for the recorded figures and limitations.

### v2.1b — allow normal corrections, recognize stronger pull-up evidence

The flight review showed why any Elevator movement should not be treated as evidence against thermal lift: a pilot may make small corrections while working weak lift. The tuning therefore reduced the effect of Elevator activity alone and reserved stronger suppression for the combination of strong pitch input and a simultaneous GPS-speed drop.

The documented v2.1b tuning was:

- Elevator deadband: **5 → 10 RAW**
- Elevator activity threshold: **80 → 120 RAW**
- activity filter time constant: **0.80 → 0.60 s**
- maximum penalty from Elevator activity alone: **35% → 15%**, with a nonlinear ramp
- GPS speed was corrected to the unit present in the ETHOS logs: **km/h**
- test thresholds for the paired pull-up signal: meaningful speed drop from about **2 km/h over ~1 s**, full contribution at **8 km/h**
- HINT blocking at `PUp ≥ 80%`; CONFIRM blocking at `PUp ≥ 65%`

These were field-test settings, not universal model-independent values. The v2.1b change kept the v2.0 GPS altitude, GPS vario, motor-off settling, persistence, and altitude-trend foundation.

### v2.1.5 — current refinement for more accurate and sensitive detection

The current build continues that tuning goal: make early real lift easier to recognize while reducing false indications from pilot-induced climbs. The implementation keeps GPS altitude and vario as the main evidence, uses filtered GPS-speed changes to adjust confidence, treats light Elevator corrections gently, and gives the CONFIRMED state a continuous-evidence dwell. It also uses a sustained release interval and refractory period to reduce state chatter.

The current source uses a 50 m altitude gate, a 3 A motor lock, a 4–12 s motor-off settling window, a 3 s continuous confirmation dwell, a 6 s release hold, and a 20 s refractory interval. Light Elevator activity has at most a 5% score effect; stronger Elevator activity paired with filtered GPS slowdown can contribute a larger temporary penalty. The score penalty is held briefly and then recovers gradually.

These values describe the published implementation; they are not a claim that v2.1.5 has already been flown or proven more accurate. The previous flight-tested version produced an encouraging result. The current v2.1.5 build is the next refinement and still needs flight validation.

## Community field testing

The repository is public so ETHOS pilots can inspect and test the detector when their aircraft, sensors, weather, and flying conditions allow. The current source mapping and switch numbers are tailored to one X20R / F5J Panther installation. Before using it on another setup, verify every source, switch, sensor, audio action, and motor/ARM interaction in that model's own configuration.

For feedback, report the exact script and ETHOS versions, transmitter and sensor setup, test conditions, observed lift, and relevant `TScore`, `TState`, altitude, vario, GPS speed, current, and Elevator values. State clearly whether the result comes from a flight or bench/simulator check. Do not include account tokens, credentials, or personal information in logs or issues.

The author's next flight test of v2.1.5 on the Panther is planned for the **2027 flying season, weather permitting**. Community field tests and reports are welcome earlier when suitable conditions are available.

## What it uses

GPS altitude and GPS vario are the primary lift evidence. GPS Logger 3 ground speed is a cross-check. Native `Elevator` activity adjusts the score and, together with a speed drop, delays confirmation. The original Panther vario sounds, ARM logic, and motor control are intended to remain separate.

## Install

Extract the installation ZIP to the radio's storage root (`RADIO:/`). It provides:

```text
scripts/PantherThermalSource/main.lua
scripts/PantherThermalDetector/main.lua
audio/cs/default/pan_therm_hint.wav
audio/cs/default/pan_therm_confirm.wav
```

The repository root contains these same `scripts/` and `audio/` folders for review. The exact source mapping, logical switches, sounds, and logging setup are documented in `SETUP_SK.md`.

## License

No reuse license is included in this test snapshot. Public visibility permits review; it does not grant permission to redistribute or incorporate the code into another product.
