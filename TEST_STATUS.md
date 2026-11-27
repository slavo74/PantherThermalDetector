# Test status — Panther Thermal Detector

## Current published build

- **v2.1.5 FIELD TEST**
- Package file: `PantherThermalDetector_v2_1_5_CONFIRMED_RELIABILITY_INSTALL.zip`
- This is the current refinement for more accurate and sensitive thermal-onset detection. It remains experimental and is not a generally validated thermal detector.
- The available flight logs and pilot confirmation belong to the earlier v2.1 flight-tested build. They are encouraging evidence for the project, but are not a flight validation of v2.1.5.
- The author's own next v2.1.5 flight test on the X20R / F5J Panther is planned for the **2027 flying season, weather permitting**.
- Since the repository is public for community testing, other ETHOS pilots may report field results earlier when their equipment and conditions allow.

## Earlier v2.1 flight-test result

Two flights dated 2026-10-05 were reviewed for v2.1:

| Flight | Maximum altitude | Maximum current | Maximum score | SUSPECT | CONFIRMED |
|---|---:|---:|---:|---:|---:|
| 15:46 | 225.7 m | 40.7 A | 69% | 1 | 0 |
| 16:29 | 215.9 m | 40.8 A | 40% | 0 | 0 |

In the reviewed logs, the score remained zero during four motor runs per flight and below 50 m. The pilot confirmed the interval around **16:12:48–16:12:51** in the first flight as real thermal lift: score rose to 69%, vario was about +0.9 to +1.1 m/s, altitude rose from roughly 192.7 to 195.2 m, current was 0 A, and Elevator was neutral.

The pilot described the prior version's result as good. The log review also found no CONFIRMED transition in these two flights; the confirmed thermal event produced a strong candidate score but did not remain long enough to reach CONFIRMED. So the result supports useful lift sensitivity in the earlier build, while leaving the current confirmation behavior and v2.1.5 still to be tested.

## How the detector was refined

### Core retained from v2.0

GPS altitude and GPS vario remain the primary lift evidence. The detector also uses filtered vertical-speed signals, persistence, GPS-altitude trend, motor-off settling, a 50 m altitude gate, and a motor lock.

### v2.1 field-test additions

The v2.1 test added the native ETHOS Elevator input and GPS Logger 3 ground speed as supporting evidence. Elevator activity and short-term GPS-speed changes were used to help distinguish natural lift from a pilot-induced pitch-up. The 2026-10-05 logs showed promising score behavior, including the pilot-confirmed thermal interval above.

The log review exposed two limitations: the files did not contain separate `EAct`, `SpdDn`, and `PUp` diagnostic fields, and one `SUSPECT → NONE` transition appeared to clear while positive evidence remained, followed by renewed score values sooner than expected under the reviewed refractory rule. These findings drove further refinement and remain part of the test history.

### v2.1b tuning step

Following the user's request to allow modest Elevator corrections in weak lift, v2.1b reduced the effect of Elevator activity alone and gave more weight to the paired signature of strong Elevator movement plus a GPS-speed decrease:

- deadband **5 → 10 RAW**
- Elevator activity threshold **80 → 120 RAW**
- activity filter **0.80 → 0.60 s**
- maximum Elevator-only penalty **35% → 15%**, with a nonlinear ramp
- GPS speed interpreted in **km/h**, matching the ETHOS logs
- test settings: about **2 km/h** meaningful drop over ~1 s and **8 km/h** for full contribution
- HINT suppression at `PUp ≥ 80%`; CONFIRM suppression at `PUp ≥ 65%`

These were test settings for the Panther installation, not universal thresholds.

### Current v2.1.5 refinement

The current source retains GPS altitude and vario as primary evidence and uses filtered, unit-independent GPS-speed changes to adjust confidence. Light Elevator activity has a small score effect; stronger activity paired with GPS slowdown contributes a larger temporary penalty. A CONFIRMED transition requires a continuous dwell, and the state has a release hold and refractory interval to reduce chatter.

Published implementation values include: altitude gate **50 m**; motor-on threshold **3 A**; motor-off settling **4–12 s**; confirmation dwell **3 s**; release hold **6 s**; refractory interval **20 s**; fine Elevator penalty capped at **5%**; paired Elevator/speed penalty capped at **45%** within a total penalty cap of **50%**, followed by a brief hold and gradual recovery. These are code settings, not evidence of v2.1.5 flight performance.

## What a flight report should include

When the author's Panther test occurs in the 2027 season, or when a community pilot tests sooner, record:

- exact script version and ETHOS version
- transmitter, model, and sensor configuration
- weather and flight conditions
- `TScore` and `TState` around each HINT/CONFIRM transition
- GPS altitude, GPS vario, GPS speed, current, and Elevator
- whether the pilot independently observed thermal lift
- false, late, repeated, or missing alerts

Keep the prior working scripts and radio configuration backed up before changing the transmitter. The log supports analysis, but pilot observation and flight context are needed to label an event as real thermal lift.
