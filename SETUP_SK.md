# Panther Thermal Detector — nastavenie pre Panther

Táto konfigurácia bola pripravená pre konkrétnu zostavu **FrSky X20R / ETHOS, F5J Panther, GPS Logger 3 a UniSens-E**. Pred použitím na inom modeli skontroluj zdroje, logické spínače a Special Functions; čísla môžu kolidovať s tvojím vlastným nastavením.

## Vstupy

| Funkcia | Zdroj v ETHOS | Fyzický zdroj |
|---|---|---|
| GPS výška | `Výška` | GPS Logger 3 |
| GPS vario | `Vert.rychlost` | GPS Logger 3 |
| GPS rýchlosť | `GSpd` | GPS Logger 3, rýchlosť voči zemi |
| Prúd | `Proud` | UniSens-E |
| ARM | `LSW17 / ARMED` | existujúca Panther ARM logika |
| Výškovka | `Elevator` | natívny ETHOS vstup |

Nepoužíva sa RX variometer ani `AirSpeed`. GPS speed má byť `GSpd` z GPS Logger 3.

## Inštalácia

Rozbaľ obsah balíka do koreňového adresára SD/eMMC rádia `RADIO:/`. Zálohuj existujúce priečinky pred výmenou súborov. Po rozbalení majú byť k dispozícii `scripts/` a `audio/` podľa stromu uvedeného v README.

Na vysielači skontroluj dostupné čísla pred nastavením týchto predvolených položiek:

- `LSW44` — `THERMAL_HINT`, zdroj `PT Stav termiky > 0`.
- `LSW45` — `THERMAL_CONFIRM`, zdroj `PT Stav termiky > 1`.
- `SF27` — prehrá `pan_therm_hint.wav` cez LSW44, bez opakovania.
- `SF28` — prehrá `pan_therm_confirm.wav` cez LSW45, bez opakovania.

Ak sú čísla obsadené, použi iné voľné položky a nastav príslušné SF podľa nich. Existujúce Panther vario audio a ARM/motor logiku nemeň.

## Logovanie a letové overenie

V existujúcom ETHOS `Write Logs` nastavovaní zachovaj `250 ms`, ak ho už používaš. Pre vyhodnotenie sa hodia tieto zdroje:

- `PT Thermal Score` (`TScore`, 0–100 %)
- `PT Stav termiky` (`TState`: 0 NONE, 1 SUSPECT, 2 CONFIRMED)
- `Výška`, `Vert.rychlost`, GPS Logger 3 `GSpd`, `Proud` a `Elevator`

Pred prvým letom over načítanie skriptov, Lua sources, widgetu a zvukov na vysielači. Po lete porovnaj stav a skóre s telemetriou a vlastným pozorovaním pilota; log sám osebe nedokazuje, že išlo o termiku.

