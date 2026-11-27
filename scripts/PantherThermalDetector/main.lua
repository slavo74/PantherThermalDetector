-- Panther F5J - Thermal Test View v2.1.5
-- Optional full-screen diagnostic widget for field testing.
-- No detector logic is duplicated here; it only displays configured sources.

local function safeValue(src)
  if not src then return nil end
  local ok,v=pcall(function() return src:value() end)
  if ok and type(v)=="number" then return v end
  return nil
end

local function text(x,y,s,font,c)
  lcd.font(font)
  lcd.color(c)
  lcd.drawText(math.floor(x),math.floor(y),tostring(s))
end

local function center(x,y,s,font,c)
  lcd.font(font)
  lcd.color(c)
  lcd.drawText(math.floor(x),math.floor(y),tostring(s),CENTERED)
end

local function create()
  return { score=nil, state=nil, alt=nil, vario=nil, current=nil, speed=nil, arm=nil }
end

local function loadSetting(key)
  local ok, value = pcall(function() return storage.read(key) end)
  if ok then return value end
  return nil
end

local function saveSetting(key, value)
  -- Do not replace an existing saved assignment with an uninitialized nil.
  -- This can happen when ETHOS calls write before read during model changes.
  if value == nil then return end
  pcall(function() storage.write(key, value) end)
end

local function setSetting(widget, field, key, value)
  widget[field] = value
  saveSetting(key, value)
end

local function readSetting(widget, field, key)
  local value = loadSetting(key)
  if value ~= nil then widget[field] = value end
end

local function read(widget)
  readSetting(widget, "score", "ptv_score")
  readSetting(widget, "state", "ptv_state")
  readSetting(widget, "alt", "ptv_alt")
  readSetting(widget, "vario", "ptv_vario")
  readSetting(widget, "current", "ptv_current")
  readSetting(widget, "speed", "ptv_speed")
  readSetting(widget, "arm", "ptv_arm")
  return true
end

local function write(widget)
  saveSetting("ptv_score", widget.score)
  saveSetting("ptv_state", widget.state)
  saveSetting("ptv_alt", widget.alt)
  saveSetting("ptv_vario", widget.vario)
  saveSetting("ptv_current", widget.current)
  saveSetting("ptv_speed", widget.speed)
  saveSetting("ptv_arm", widget.arm)
  return true
end

local function configure(w)
  local line=form.addLine("PT Thermal Score")
  form.addSourceField(line,nil,function() return w.score end,function(v) setSetting(w,"score","ptv_score",v) end)

  line=form.addLine("PT Stav termiky")
  form.addSourceField(line,nil,function() return w.state end,function(v) setSetting(w,"state","ptv_state",v) end)

  line=form.addLine("GPS Logger 3 Altitude - Výška")
  form.addSourceField(line,nil,function() return w.alt end,function(v) setSetting(w,"alt","ptv_alt",v) end)

  line=form.addLine("GPS Logger 3 Vario - Vert.rychlost")
  form.addSourceField(line,nil,function() return w.vario end,function(v) setSetting(w,"vario","ptv_vario",v) end)

  line=form.addLine("GPS Logger 3 GPS speed - GSpd")
  form.addSourceField(line,nil,function() return w.speed end,function(v) setSetting(w,"speed","ptv_speed",v) end)

  line=form.addLine("UniSens-E Current - Proud")
  form.addSourceField(line,nil,function() return w.current end,function(v) setSetting(w,"current","ptv_current",v) end)

  line=form.addLine("ARM source - LSW17 / ARMED")
  form.addSwitchField(line,nil,function() return w.arm end,function(v) setSetting(w,"arm","ptv_arm",v) end)
end

local function wakeup(w)
  lcd.invalidate()
end

local function paint(w)
  local W,H=lcd.getWindowSize()
  local WHITE=lcd.RGB(247,249,250)
  local MUTED=lcd.RGB(176,187,193)
  local CYAN=lcd.RGB(72,202,241)
  local GREEN=lcd.RGB(92,217,28)
  local YELLOW=lcd.RGB(255,196,0)
  local RED=lcd.RGB(255,55,36)
  local DARK=lcd.RGB(5,14,20)

  lcd.color(DARK)
  lcd.drawFilledRectangle(0,0,W,H)

  local score=safeValue(w.score) or 0
  local state=safeValue(w.state) or 0
  local alt=safeValue(w.alt)
  local vario=safeValue(w.vario)
  local current=safeValue(w.current)
  local speed=safeValue(w.speed)

  local stateText="NONE"
  local stateColor=MUTED
  if state>=2 then stateText="CONFIRMED"; stateColor=GREEN
  elseif state>=1 then stateText="SUSPECT"; stateColor=YELLOW end

  center(W/2,8,"PANTHER THERMAL",FONT_XL,WHITE)
  center(W/2,42,"FIELD TEST v2.1.5",FONT_S,MUTED)

  text(18,82,"SCORE",FONT_M,MUTED)
  text(120,72,string.format("%3d",math.floor(score+0.5)),FONT_XL,CYAN)

  text(18,124,"STATE",FONT_M,MUTED)
  text(120,116,stateText,FONT_L,stateColor)

  text(18,166,"ALT",FONT_M,MUTED)
  text(120,158,alt and string.format("%.1f m",alt) or "--",FONT_L,WHITE)

  text(18,205,"VARIO",FONT_M,MUTED)
  text(120,197,vario and string.format("%+.2f m/s",vario) or "--",FONT_L,WHITE)

  text(18,244,"GPS SPEED",FONT_M,MUTED)
  text(160,236,speed and string.format("%.1f",speed) or "--",FONT_L,WHITE)

  text(18,282,"CURRENT",FONT_M,MUTED)
  text(120,274,current and string.format("%.1f A",current) or "--",FONT_L,WHITE)

  center(W/2,H-58,"Audio: LSW44 HINT / LSW45 CONFIRM",FONT_S,MUTED)
  center(W/2,H-36,"Existing VARIO audio unchanged",FONT_S,MUTED)
end

local function init()
  system.registerWidget({
    -- Keep this widget key and the ptv_* storage keys stable between releases;
    -- changing them would make ETHOS treat saved Configure data as new.
    key="TView",
    name="Panther Thermal Test",
    create=create,
    configure=configure,
    read=read,
    write=write,
    wakeup=wakeup,
    paint=paint,
    title=false,
    persistent=true,
  })
end

return { init=init }

