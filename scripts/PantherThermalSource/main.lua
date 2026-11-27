-- Panther F5J - Thermal Detector v2.1.4 FIELD TEST
-- FrSky X20R / ETHOS 26.1.x
--
-- Purpose:
--   Early, gentle thermal-onset detection for recreational F5J.
--
-- FIXED INPUT ARCHITECTURE (do not use RX vario):
--   Altitude = GPS Logger 3 -> "Výška"
--   Vario    = GPS Logger 3 -> "Vert.rychlost"
--   Current  = UniSens-E -> "Proud"
--   ARM      = LSW17 -> ARMED
--   Elevator = native ETHOS source -> "Elevator"
--   GPS speed = GPS Logger 3 FrSky telemetry field "GSpd"
--
-- OUTPUTS:
--   TScore = PT Thermal Score, 0..100
--   TState = PT Stav termiky, 0 NONE / 1 SUSPECT / 2 CONFIRMED
-- v2.1 keeps GPS altitude and vario as primary thermal evidence. Elevator
--   activity only softens the score; stronger Elevator movement adds a larger
--   score penalty only when GPS speed is falling at the same time.
--
-- AUDIO / LS ARCHITECTURE:
--   LSW44 THERMAL_HINT    : A = PT Stav termiky, A > 0
--   SF27 -> Play Track pan_therm_hint.wav, Repeat OFF
--   LSW45 THERMAL_CONFIRM : A = PT Stav termiky, A > 1
--   SF28 -> Play Track pan_therm_confirm.wav, Repeat OFF
--
-- Existing Panther VARIO audio is intentionally untouched.

local SCRIPT_VERSION = "2.1.5 FIELD TEST"
local CONFIG_SCHEMA = 3

local ALT_GATE = 50.0
local MOTOR_ON_CURRENT = 3.0
local MIN_MOTOR_SETTLE = 4.0
local MAX_MOTOR_SETTLE = 12.0
local SETTLE_HOLD = 0.6
local FAST_TAU = 0.60
local SLOW_TAU = 3.00
local MIN_DETECT_AGE = 1.50

-- Measured native Elevator scale: -1024..+1024, 2048 counts total; the
-- smallest displayed moving step was 1. Hold raw positions within one count
-- of the last accepted position, then calculate abs(filteredDelta)/dt.
local ELEVATOR_POSITION_DEADBAND = 1.0
local ELEVATOR_ACTIVITY_TAU = 0.20
-- Light pilot corrections have at most a 5% score effect. The stronger
-- penalty ramps in only for faster movement, and only alongside GPS slowdown.
local ELEVATOR_FINE_RATE_START = 20.0
local ELEVATOR_FINE_RATE_FULL = 250.0
local ELEVATOR_STRONG_RATE_START = 250.0
local ELEVATOR_STRONG_RATE_FULL = 800.0
local ELEVATOR_FINE_MAX_PENALTY = 0.05
local ELEVATOR_PAIRED_MAX_PENALTY = 0.45
local ELEVATOR_PENALTY_MAX = 0.50
local ELEVATOR_PENALTY_ATTACK_TAU = 0.20
-- Hold an observed score penalty for one second after input activity, then
-- linearly recover it over three seconds.
local ELEVATOR_PENALTY_HOLD = 1.0
local ELEVATOR_PENALTY_RECOVERY = 3.0
-- HINT uses GPS-speed trust only. CONFIRMED also requires a continuous dwell;
-- simultaneous strong Elevator activity and GPS slowdown restart that dwell.
local HINT_INPUT_TRUST = 0.55
local CONFIRM_INPUT_TRUST = 0.85

-- GPS Logger 3 speed is a second, independent cross-check. Compare fast and
-- slow filtered groundspeed as a unitless fraction so the source can be
-- configured in the ETHOS-preferred speed unit. Strong transients reduce
-- confidence temporarily; GPS speed never creates a thermal detection alone.
local GPS_SPEED_FAST_TAU = 0.65
local GPS_SPEED_SLOW_TAU = 2.50
local GPS_SPEED_TRUST_FULL = 0.08
local GPS_SPEED_TRUST_LOW = 0.25
local GPS_SPEED_MIN_TRUST = 0.55
local GPS_SPEED_TRUST_TAU = 0.35

-- SUSPECT / HINT: early but gentle.
local HINT_FAST = 0.22
local HINT_SLOW = 0.04
local HINT_RISE = 0.04
local HINT_ALT4 = 0.10
local HINT_POS2 = 0.70

-- CONFIRMED: requires multi-second positive evidence including actual GPS altitude rise.
local CONFIRM_FAST = 0.15
local CONFIRM_SLOW = 0.10
local CONFIRM_ALT6 = 0.12
local CONFIRM_POS4 = 0.75
local CONFIRM_HOLD = 3.0

-- State release / anti-chatter.
local RELEASE_SLOW = -0.12
local RELEASE_HOLD = 6.0
local REFRACTORY = 20.0

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function safeNumber(v, fallback)
  if type(v) == "number" and v == v then return v end
  return fallback
end

local function sourceValue(src)
  if not src then return nil end
  local ok, value = pcall(function() return src:value() end)
  if ok and type(value) == "number" and value == value then return value end
  return nil
end

local function sourceState(src)
  if not src then return false end
  local ok, v = pcall(function() return src:state() end)
  if ok and type(v) == "boolean" then return v end
  local n = sourceValue(src)
  return n ~= nil and n > 0.5
end

local function nowSeconds()
  local ok, ticks = pcall(function() return system.getTime() end)
  if ok and type(ticks) == "number" then return ticks / 100.0 end
  local ok2, clock = pcall(function() return os.clock() end)
  if ok2 and type(clock) == "number" then return clock end
  return 0
end

local cfg = {
  altitudeSource = nil,
  varioSource = nil,
  currentSource = nil,
  armSource = nil,
  elevatorSource = nil,
  gpsSpeedSource = nil,
}

local d = {
  fast = nil,
  slow = nil,
  lastT = nil,
  lastUpdateT = -999,
  motorPrev = false,
  motorOffT = -999,
  armPrev = false,
  ready = false,
  settleSince = nil,
  rearmT = -999,
  negPhase = false,
  state = 0,
  candidateSince = nil,
  confirmSince = nil,
  releaseSince = nil,
  refractoryUntil = 0,
  score = 0,
  vario = 0,
  alt = 0,
  current = 0,
  elevatorRaw = 0,
  elevatorFiltered = nil,
  elevatorDelta = 0,
  elevatorTime = nil,
  elevatorActivity = 0.0,
  elevatorPenalty = 0.0,
  elevatorPenaltyHoldUntil = -999,
  elevatorPenaltyRecoveryStart = nil,
  elevatorPenaltyRecoveryValue = 0.0,
  elevatorPenaltyTime = nil,
  elevatorTrust = 1.0,
  gpsSpeed = 0,
  gpsSpeedFast = nil,
  gpsSpeedSlow = nil,
  gpsSpeedTime = nil,
  gpsSpeedTrust = 1.0,
  gpsSpeedTransient = 0.0,
  rise1 = 0,
  alt2 = nil,
  alt4 = nil,
  alt6 = nil,
  pos2 = 0,
  pos4 = 0,
  hist = {},
  fhist = {},
}

local function clearDetection(keepFilters)
  d.ready = false
  d.settleSince = nil
  d.rearmT = -999
  d.negPhase = false
  d.state = 0
  d.candidateSince = nil
  d.confirmSince = nil
  d.releaseSince = nil
  d.refractoryUntil = 0
  d.hist = {}
  d.fhist = {}
  if not keepFilters then
    d.fast = nil
    d.slow = nil
    d.lastT = nil
  end
end

local function armReset(t)
  clearDetection(false)
  d.elevatorFiltered = nil
  d.elevatorTime = nil
  d.elevatorActivity = 0.0
  d.elevatorPenalty = 0.0
  d.elevatorPenaltyHoldUntil = t - ELEVATOR_PENALTY_RECOVERY
  d.elevatorPenaltyRecoveryStart = nil
  d.elevatorPenaltyRecoveryValue = 0.0
  d.elevatorPenaltyTime = t
  d.elevatorTrust = 1.0
  d.gpsSpeedFast = nil
  d.gpsSpeedSlow = nil
  d.gpsSpeedTime = nil
  d.gpsSpeedTrust = 1.0
  d.gpsSpeedTransient = 0.0
  d.armPrev = true
  d.motorPrev = false
  d.motorOffT = t
end

local function enterReady(t, v, alt)
  d.ready = true
  d.rearmT = t
  d.negPhase = (v < -0.03)
  d.state = 0
  d.candidateSince = nil
  d.confirmSince = nil
  d.releaseSince = nil
  d.refractoryUntil = 0
  d.hist = {{t, v, alt}}
  d.fhist = {{t, d.fast or v}}
end

local function appendHistory(t, v, alt, fast)
  d.hist[#d.hist + 1] = {t, v, alt}
  d.fhist[#d.fhist + 1] = {t, fast}
  while #d.hist > 2 and d.hist[1][1] < t - 10.0 do table.remove(d.hist, 1) end
  while #d.fhist > 2 and d.fhist[1][1] < t - 3.0 do table.remove(d.fhist, 1) end
end

local function valueAt(seq, target, index)
  local prev = nil
  local nextItem = nil
  for i = 1, #seq do
    local item = seq[i]
    if item[1] <= target then prev = item end
    if item[1] >= target then nextItem = item; break end
  end
  if prev and nextItem then
    if prev[1] == nextItem[1] then return prev[index] end
    local f = (target - prev[1]) / (nextItem[1] - prev[1])
    return prev[index] + f * (nextItem[index] - prev[index])
  end
  if prev then return prev[index] end
  return nil
end

local function fractionPositive(windowSeconds, threshold, t)
  local total = 0
  local positive = 0
  for i = 1, #d.hist do
    local item = d.hist[i]
    if item[1] >= t - windowSeconds then
      total = total + 1
      if item[2] > threshold then positive = positive + 1 end
    end
  end
  if total == 0 then return 0 end
  return positive / total
end

local function computeScore()
  local gpsTrust = clamp(d.gpsSpeedTrust or 0, 0, 1)
  local elevatorTrust = clamp(d.elevatorTrust or 0, 0, 1)
  local fastPart = clamp((d.fast * gpsTrust - 0.05) / 0.75, 0, 1)
  local slowPart = clamp((d.slow * gpsTrust + 0.02) / 0.35, 0, 1)
  local risePart = clamp((d.rise1 * gpsTrust - 0.02) / 0.40, 0, 1)
  local altPart = clamp(((d.alt4 or 0) - 0.03) / 0.30, 0, 1)
  local persistence = clamp(d.pos2, 0, 1)
  local raw = fastPart * 0.28 + slowPart * 0.22 + risePart * 0.18 + altPart * 0.22 + persistence * 0.10
  local score = clamp(raw * 100.0, 0, 100)
  if d.state == 1 and score < 30 then score = 30 end
  if d.state == 2 and score < 70 then score = 70 end
  -- Keep the GPS modifier's established evidence scaling, but apply the soft
  -- Elevator weight exactly once so fine inputs stay within their 5% cap.
  return clamp(score * gpsTrust * elevatorTrust, 0, 100)
end

local function updateElevator(t, value)
  d.elevatorRaw = value

  if d.elevatorFiltered == nil then
    d.elevatorFiltered = value
    d.elevatorTime = t
    d.elevatorDelta = 0
    d.elevatorActivity = 0.0
    return
  end

  local dt = 0.04
  if d.elevatorTime then dt = clamp(t - d.elevatorTime, 0.01, 1.0) end
  local previousFiltered = d.elevatorFiltered
  local positionError = value - previousFiltered
  if math.abs(positionError) > ELEVATOR_POSITION_DEADBAND then
    d.elevatorFiltered = value - (positionError > 0 and ELEVATOR_POSITION_DEADBAND or -ELEVATOR_POSITION_DEADBAND)
  end
  d.elevatorDelta = d.elevatorFiltered - previousFiltered
  local rate = math.abs(d.elevatorDelta) / dt
  local alpha = 1.0 - math.exp(-dt / ELEVATOR_ACTIVITY_TAU)
  d.elevatorActivity = d.elevatorActivity + alpha * (rate - d.elevatorActivity)
  d.elevatorTime = t
end

local function updateGpsSpeed(t, value)
  d.gpsSpeed = value
  if d.gpsSpeedFast == nil or d.gpsSpeedSlow == nil then
    d.gpsSpeedFast = value
    d.gpsSpeedSlow = value
    d.gpsSpeedTime = t
    d.gpsSpeedTrust = 1.0
    d.gpsSpeedTransient = 0.0
    return
  end

  local dt = 0.05
  if d.gpsSpeedTime then dt = clamp(t - d.gpsSpeedTime, 0.01, 1.0) end
  local af = 1.0 - math.exp(-dt / GPS_SPEED_FAST_TAU)
  local as = 1.0 - math.exp(-dt / GPS_SPEED_SLOW_TAU)
  d.gpsSpeedFast = d.gpsSpeedFast + af * (value - d.gpsSpeedFast)
  d.gpsSpeedSlow = d.gpsSpeedSlow + as * (value - d.gpsSpeedSlow)
  d.gpsSpeedTime = t

  -- Ignore near-zero speed where a percentage change is not meaningful.
  local targetTrust = 1.0
  local transient = 0.0
  if math.abs(d.gpsSpeedSlow) >= 1.0 then
    local relativeDeceleration = math.max(0, d.gpsSpeedSlow - d.gpsSpeedFast) / math.abs(d.gpsSpeedSlow)
    transient = clamp((relativeDeceleration - GPS_SPEED_TRUST_FULL) /
      (GPS_SPEED_TRUST_LOW - GPS_SPEED_TRUST_FULL), 0, 1)
    targetTrust = 1.0 - transient * (1.0 - GPS_SPEED_MIN_TRUST)
  end
  local alpha = 1.0 - math.exp(-dt / GPS_SPEED_TRUST_TAU)
  d.gpsSpeedTrust = d.gpsSpeedTrust + alpha * (targetTrust - d.gpsSpeedTrust)
  -- Use the filtered trust reduction for the Elevator + slowdown interaction,
  -- so both the score and state logic see a smooth GPS-speed signal.
  d.gpsSpeedTransient = clamp((1.0 - d.gpsSpeedTrust) /
    (1.0 - GPS_SPEED_MIN_TRUST), 0, 1)
end

local function updateElevatorPenalty(t)
  local fine = clamp((d.elevatorActivity - ELEVATOR_FINE_RATE_START) /
    (ELEVATOR_FINE_RATE_FULL - ELEVATOR_FINE_RATE_START), 0, 1)
  local strong = clamp((d.elevatorActivity - ELEVATOR_STRONG_RATE_START) /
    (ELEVATOR_STRONG_RATE_FULL - ELEVATOR_STRONG_RATE_START), 0, 1)
  local targetPenalty = clamp(
    fine * ELEVATOR_FINE_MAX_PENALTY +
      strong * d.gpsSpeedTransient * ELEVATOR_PAIRED_MAX_PENALTY,
    0, ELEVATOR_PENALTY_MAX)

  local dt = 0.04
  if d.elevatorPenaltyTime then dt = clamp(t - d.elevatorPenaltyTime, 0.01, 1.0) end
  d.elevatorPenaltyTime = t

  if targetPenalty > d.elevatorPenalty then
    local alpha = 1.0 - math.exp(-dt / ELEVATOR_PENALTY_ATTACK_TAU)
    d.elevatorPenalty = d.elevatorPenalty + alpha * (targetPenalty - d.elevatorPenalty)
    d.elevatorPenaltyRecoveryStart = nil
  end

  if targetPenalty > 0.001 then
    d.elevatorPenaltyHoldUntil = t + ELEVATOR_PENALTY_HOLD
    d.elevatorPenaltyRecoveryStart = nil
  elseif t >= d.elevatorPenaltyHoldUntil and d.elevatorPenalty > 0 then
    if d.elevatorPenaltyRecoveryStart == nil then
      d.elevatorPenaltyRecoveryStart = t
      d.elevatorPenaltyRecoveryValue = d.elevatorPenalty
    end
    local recovered = clamp((t - d.elevatorPenaltyRecoveryStart) /
      ELEVATOR_PENALTY_RECOVERY, 0, 1)
    d.elevatorPenalty = d.elevatorPenaltyRecoveryValue * (1.0 - recovered)
  end

  d.elevatorTrust = clamp(1.0 - d.elevatorPenalty, 0.50, 1.0)
end

local function updateDetector()
  local t = nowSeconds()
  if (t - d.lastUpdateT) < 0.04 then return end
  d.lastUpdateT = t

  local arm = sourceState(cfg.armSource)
  local alt = sourceValue(cfg.altitudeSource)
  local v = sourceValue(cfg.varioSource)
  local current = sourceValue(cfg.currentSource)
  local elevator = sourceValue(cfg.elevatorSource)
  local gpsSpeed = sourceValue(cfg.gpsSpeedSource)

  if not arm then
    if d.armPrev then
      clearDetection(false)
    end
    d.armPrev = false
    d.motorPrev = false
    d.motorOffT = -999
    d.score = 0
    d.state = 0
    return
  end

  if not d.armPrev then
    armReset(t)
  end
  d.armPrev = true

  -- Missing configured inputs are a hard-safe NONE state.
  if alt == nil or v == nil or current == nil or elevator == nil or gpsSpeed == nil then
    clearDetection(false)
    d.score = 0
    d.state = 0
    d.alt = safeNumber(alt, 0)
    d.vario = safeNumber(v, 0)
    d.current = safeNumber(current, 0)
    if elevator == nil then
      d.elevatorFiltered = nil
      d.elevatorTime = nil
      d.elevatorActivity = 0.0
      d.elevatorPenalty = 0.0
      d.elevatorPenaltyHoldUntil = t - ELEVATOR_PENALTY_RECOVERY
      d.elevatorPenaltyRecoveryStart = nil
      d.elevatorPenaltyRecoveryValue = 0.0
      d.elevatorPenaltyTime = t
      d.elevatorTrust = 0.0
    end
    if gpsSpeed == nil then
      d.gpsSpeedFast = nil
      d.gpsSpeedSlow = nil
      d.gpsSpeedTime = nil
      d.gpsSpeedTrust = 0.0
      d.gpsSpeedTransient = 0.0
    end
    return
  end

  alt = safeNumber(alt, 0)
  v = safeNumber(v, 0)
  current = safeNumber(current, 0)
  gpsSpeed = safeNumber(gpsSpeed, 0)
  d.alt, d.vario, d.current, d.gpsSpeed = alt, v, current, gpsSpeed

  updateElevator(t, elevator)
  updateGpsSpeed(t, gpsSpeed)
  updateElevatorPenalty(t)

  local dt = 0.05
  if d.lastT then dt = clamp(t - d.lastT, 0.01, 1.0) end
  if d.fast == nil then
    d.fast = v
    d.slow = v
  else
    local af = 1.0 - math.exp(-dt / FAST_TAU)
    local as = 1.0 - math.exp(-dt / SLOW_TAU)
    d.fast = d.fast + af * (v - d.fast)
    d.slow = d.slow + as * (v - d.slow)
  end

  local motor = current >= MOTOR_ON_CURRENT
  if motor and not d.motorPrev then
    clearDetection(true)
  elseif (not motor) and d.motorPrev then
    d.motorOffT = t
    clearDetection(true)
  end
  d.motorPrev = motor
  d.lastT = t

  -- Strictly no thermal detection below 50 m.
  if alt < ALT_GATE then
    d.score = 0
    clearDetection(true)
    return
  end

  if motor then
    d.score = 0
    d.state = 0
    return
  end

  appendHistory(t, v, alt, d.fast)

  if not d.ready then
    if t >= d.motorOffT + MIN_MOTOR_SETTLE then
      local negativeRecent = false
      for i = 1, #d.hist do
        local item = d.hist[i]
        if item[1] >= t - 3.0 and item[2] < -0.08 then
          negativeRecent = true
          break
        end
      end
      if negativeRecent and d.fast < 0.10 and d.slow < 0.15 then
        if d.settleSince == nil then
          d.settleSince = t
        elseif (t - d.settleSince) >= SETTLE_HOLD then
          enterReady(t, v, alt)
        end
      else
        d.settleSince = nil
      end
    end
    if (not d.ready) and t >= d.motorOffT + MAX_MOTOR_SETTLE then
      enterReady(t, v, alt)
    end
    d.score = 0
    d.state = 0
    return
  end

  if (t - d.rearmT) < MIN_DETECT_AGE then
    d.score = 0
    d.state = 0
    return
  end

  if v < -0.08 or d.fast < -0.03 then d.negPhase = true end

  local oldFast = valueAt(d.fhist, t - 1.0, 2)
  if oldFast then d.rise1 = d.fast - oldFast else d.rise1 = 0 end

  local oldAlt2 = valueAt(d.hist, t - 2.0, 3)
  if oldAlt2 then d.alt2 = (alt - oldAlt2) / 2.0 else d.alt2 = nil end
  local oldAlt4 = valueAt(d.hist, t - 4.0, 3)
  if oldAlt4 and (t - d.rearmT) >= 4.0 then d.alt4 = (alt - oldAlt4) / 4.0 else d.alt4 = nil end
  local oldAlt6 = valueAt(d.hist, t - 6.0, 3)
  if oldAlt6 and (t - d.rearmT) >= 6.0 then d.alt6 = (alt - oldAlt6) / 6.0 else d.alt6 = nil end

  d.pos2 = fractionPositive(2.0, 0.05, t)
  d.pos4 = fractionPositive(4.0, 0.05, t)

  if t < d.refractoryUntil then
    d.score = 0
    d.state = 0
    return
  end

  -- HINT: onset signature.
  local stateTrust = d.gpsSpeedTrust
  local hint = stateTrust >= HINT_INPUT_TRUST
      and d.negPhase
      and d.fast * stateTrust >= HINT_FAST
      and d.slow * stateTrust >= HINT_SLOW
      and d.rise1 * stateTrust >= HINT_RISE
      and d.alt4 ~= nil and d.alt4 >= HINT_ALT4
      and d.pos2 >= HINT_POS2

  -- CONFIRM: 6 s GPS-altitude rise + 4 s positive persistence + filtered vario.
  local confirm = stateTrust >= CONFIRM_INPUT_TRUST
      and d.negPhase
      and d.fast * stateTrust >= CONFIRM_FAST
      and d.slow * stateTrust >= CONFIRM_SLOW
      and d.alt6 ~= nil and d.alt6 >= CONFIRM_ALT6
      and d.pos4 >= CONFIRM_POS4

  -- Strong pitch input paired with a filtered GPS-speed loss may explain a
  -- transient climb. Keep the HINT, but require a fresh continuous interval
  -- of confirmation evidence after this combined pilot-input signature ends.
  local pilotInputWithSpeedLoss = d.elevatorActivity >= ELEVATOR_STRONG_RATE_START
      and d.gpsSpeedTransient > 0.0
  local confirmEvidence = confirm and not pilotInputWithSpeedLoss

  if d.state == 0 then
    d.confirmSince = nil
    if hint then
      d.state = 1
      d.candidateSince = t
    end
  elseif d.state == 1 then
    if confirmEvidence then
      if d.confirmSince == nil then d.confirmSince = t end
    else
      d.confirmSince = nil
    end

    if d.confirmSince ~= nil and (t - d.confirmSince) >= CONFIRM_HOLD then
      d.state = 2
      d.candidateSince = nil
      d.confirmSince = nil
    elseif d.candidateSince ~= nil and (t - d.candidateSince) > 2.0 then
      if not (d.fast > 0.09 and d.slow > 0.015) then
        d.state = 0
        d.candidateSince = nil
        d.confirmSince = nil
        d.refractoryUntil = t + REFRACTORY
      end
    end
  elseif d.state == 2 then
    if d.slow < RELEASE_SLOW then
      if d.releaseSince == nil then
        d.releaseSince = t
      elseif (t - d.releaseSince) >= RELEASE_HOLD then
        d.state = 0
        d.releaseSince = nil
        d.refractoryUntil = t + REFRACTORY
        d.negPhase = false
      end
    else
      d.releaseSince = nil
    end
  end

  d.score = computeScore()
end

local function configureSource()
  local line = form.addLine("GPS Logger 3 Altitude source")
  form.addSourceField(line, nil,
    function() return cfg.altitudeSource end,
    function(v) cfg.altitudeSource = v end)

  line = form.addLine("GPS Logger 3 Vario source")
  form.addSourceField(line, nil,
    function() return cfg.varioSource end,
    function(v) cfg.varioSource = v end)

  line = form.addLine("UniSens-E Current source")
  form.addSourceField(line, nil,
    function() return cfg.currentSource end,
    function(v) cfg.currentSource = v end)

  line = form.addLine("Native Elevator source")
  form.addSourceField(line, nil,
    function() return cfg.elevatorSource end,
    function(v)
      cfg.elevatorSource = v
      d.elevatorFiltered = nil
      d.elevatorTime = nil
      d.elevatorActivity = 0.0
      d.elevatorPenalty = 0.0
      d.elevatorPenaltyHoldUntil = -999
      d.elevatorPenaltyRecoveryStart = nil
      d.elevatorPenaltyRecoveryValue = 0.0
      d.elevatorPenaltyTime = nil
      d.elevatorTrust = 1.0
      clearDetection(false)
    end)

  line = form.addLine("GPS Logger 3 GPS speed (GSpd)")
  form.addSourceField(line, nil,
    function() return cfg.gpsSpeedSource end,
    function(v)
      cfg.gpsSpeedSource = v
      d.gpsSpeedFast = nil
      d.gpsSpeedSlow = nil
      d.gpsSpeedTime = nil
      d.gpsSpeedTrust = 1.0
      d.gpsSpeedTransient = 0.0
      clearDetection(false)
    end)

  -- ARM is a logical-switch input, not a telemetry source.
  -- Use addSwitchField so the ETHOS chooser contains LSW entries.
  line = form.addLine("ARM source")
  form.addSwitchField(line, nil,
    function() return cfg.armSource end,
    function(v) cfg.armSource = v end)

end

local function resetConfig()
  cfg.altitudeSource = nil
  cfg.varioSource = nil
  cfg.currentSource = nil
  cfg.armSource = nil
  cfg.elevatorSource = nil
  cfg.gpsSpeedSource = nil
end

local function readConfig()
  resetConfig()
  local schema = storage.read("pt_schema")
  if schema ~= CONFIG_SCHEMA then return end
  cfg.altitudeSource = storage.read("pt_alt")
  cfg.varioSource = storage.read("pt_var")
  cfg.currentSource = storage.read("pt_cur")
  cfg.armSource = storage.read("pt_arm")
  cfg.elevatorSource = storage.read("pt_elev")
  cfg.gpsSpeedSource = storage.read("pt_spd")
end

local function writeConfig()
  storage.write("pt_schema", CONFIG_SCHEMA)
  storage.write("pt_alt", cfg.altitudeSource)
  storage.write("pt_var", cfg.varioSource)
  storage.write("pt_cur", cfg.currentSource)
  storage.write("pt_arm", cfg.armSource)
  storage.write("pt_elev", cfg.elevatorSource)
  storage.write("pt_spd", cfg.gpsSpeedSource)
  return true
end

local function sourceInitScore(source)
  source:value(0)
  source:decimals(0)
  source:minimum(0)
  source:maximum(100)
  source:unit(UNIT_PERCENT)
end

local function sourceInitState(source)
  source:value(0)
  source:decimals(0)
  source:minimum(0)
  source:maximum(2)
end

local function sourceReset(source)
  source:value(0)
end

local function sourceRead(source)
  readConfig()
  updateDetector()
  source:value(0)
end

local function sourceWrite(source)
  return writeConfig()
end

local function sourceConfigure(source)
  configureSource()
end

local function wakeScore(source)
  updateDetector()
  source:value(math.floor(d.score + 0.5))
end

local function wakeState(source)
  updateDetector()
  source:value(d.state)
end

local function init()
  system.registerSource({
    key = "TScore",
    name = "PT Thermal Score",
    init = sourceInitScore,
    reset = sourceReset,
    wakeup = wakeScore,
    configure = sourceConfigure,
    read = sourceRead,
    write = sourceWrite,
  })

  system.registerSource({
    key = "TState",
    name = "PT Stav termiky",
    init = sourceInitState,
    reset = sourceReset,
    wakeup = wakeState,
    configure = sourceConfigure,
    read = sourceRead,
    write = sourceWrite,
  })
end

return {
  init = init,
  author = "Panther F5J project",
  version = SCRIPT_VERSION,
}

