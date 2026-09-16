-- @description SSM_Labor Safety
-- @version 1.4
-- @author @ssm_metalmix
-- @about
--   🎧 Бережём слух и сохраняем продуктивность: Labor Safety v1.0 для REAPER!
--   Как это работает?
--   Таймер отслеживает только реальное время воспроизведения и записи (Play/Record). Короткие паузы во --   время работы не обнуляют прогресс, но стоит сделать полноценный перерыв — отсчёт сбросится сам. Как --   только лимит безопасной работы истечёт, REAPER остановит плейбек и напомнит, что пора отдохнуть.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   + Релиз
--   + add icon (SSM_Labor_Safety_REAPER_90x30.png)
--   + 1.3: таймер теперь не тикает и не сбрасывается во время записи
--     и рендера (оффлайн и в реальном времени) — принудительная
--     остановка транспорта больше не может прервать запись/рендер
--   + 1.4
--   Добавил функцию снятия нагрузки на CPU при долгом простое.
--   В настройках есть опция включения и задаётся время простоя (в минутах). Таймер считает только когда --   нет Play/Record и не двигаешь мышь. Перед выгрузкой — обратный отсчёт 30 сек (можно отменить). Скрипт --   запоминает текущую вкладку, открывает пустую — проект разгружается. На пустой вкладке окно с кнопкой --   «Продолжить работу» → возврат к проекту.
--   Бережём и слух, и процессор 🛠




-- ============================================================
-- PATHS & CONSTANTS
-- ============================================================
local script_path = ({reaper.get_action_context()})[2]
local script_dir  = script_path:match("(.+[\\/])") or ""
local ini_path    = script_dir .. "SSM_Labor_Safety.ini"

local defaults = {
  safe_minutes     = 50,
  short_break_sec  = 15,
  long_break_sec   = 120,
  show_float_timer = 1,
  lang             = 0,
  timer_x          = 300,
  timer_y          = 200,
  timer_w          = 130,
  timer_h          = 55,
  settings_x       = 200,
  settings_y       = 200,
  break_x          = 400,
  break_y          = 260,
  idle_cpu_save    = 0,
  idle_minutes     = 30,
}

local settings = {}
local is_running = false
local continuous_sec = 0
local last_play_time = nil
local pause_start = nil
local rest_shown = false
local script_should_exit = false

local ui_mode = "settings"
local timer_locked = false
local last_mouse_cap = 0
local window_open = true

-- drag / resize state
local dragging = false
local resizing = false
local drag_off_x, drag_off_y = 0, 0
local resize_start_w, resize_start_h = 0, 0
local resize_start_mx, resize_start_my = 0, 0

local settings_dragging = false
local settings_drag_off_x, settings_drag_off_y = 0, 0

local break_dragging = false
local break_drag_off_x, break_drag_off_y = 0, 0
local break_countdown = 0
local break_start_time = 0

local lang_dropdown_open = false

-- Idle CPU-save state
local idle_sec = 0
local idle_last_check = nil
local idle_last_mx, idle_last_my = nil, nil
local idle_countdown = 0
local idle_countdown_start = 0
local idle_orig_proj = nil
local idle_new_proj = nil
local idle_dragging = false
local idle_drag_off_x, idle_drag_off_y = 0, 0
local IDLE_CHECK_INTERVAL = 10   -- activity check every 10 s (mouse + transport; very cheap)
local IDLE_MOUSE_THRESHOLD = 4   -- pixels of mouse movement = user activity
local IDLE_COUNTDOWN_SEC = 30    -- countdown before switching to empty tab

local SETTINGS_W, SETTINGS_H = 440, 580
local BREAK_W, BREAK_H = 440, 260
local IDLE_W, IDLE_H = 440, 260
local MIN_TIMER_W, MIN_TIMER_H = 80, 36
local ASPECT = 2.35
local BREAK_AUTO_CLOSE = 30


local FRAME_INTERVAL = 1 / 30
local next_frame_time = 0

local timer_force_redraw = true
local timer_last_tstr = nil
local timer_last_bgcat = nil
local timer_last_w, timer_last_h = -1, -1
local timer_last_paint_time = 0
local TIMER_MAX_IDLE = 1.0


local timer_font_size, timer_font_w, timer_font_h = 16, -1, -1

-- ============================================================
-- COPYRIGHT LINKS
-- ============================================================
local links = {
  { text = "📱 Telegram Channel",  url = "https://t.me/bardinssm" },
  { text = "💬 Telegram",          url = "https://t.me/ssm_metalmix" },
  { text = "☕ Boosty",            url = "https://boosty.to/boostbg" },
  { text = "🌐 VK",                url = "https://vk.ru/ssm_metalmix" },
}

local function open_url(url)
  local cmd
  local os_name = reaper.GetOS()
  if os_name:match("Win") then
    cmd = 'cmd /c start "" "' .. url .. '"'
  elseif os_name:match("OSX") or os_name:match("mac") then
    cmd = 'open "' .. url .. '"'
  else
    cmd = 'xdg-open "' .. url .. '"'
  end
  reaper.ExecProcess(cmd, 0)
end

-- Colors
local col = {
  bg        = {0.11, 0.12, 0.15},
  panel     = {0.16, 0.17, 0.21},
  accent    = {0.25, 0.55, 0.95},
  accent2   = {0.10, 0.95, 0.35},
  danger    = {0.95, 0.25, 0.25},
  warn      = {0.95, 0.70, 0.15},
  text      = {0.92, 0.93, 0.95},
  text_dim  = {0.55, 0.58, 0.65},
  link      = {0.45, 0.70, 1.00},
  link_hov  = {0.70, 0.85, 1.00},
  border    = {0.25, 0.27, 0.32},
  input_bg  = {0.09, 0.10, 0.13},
  btn_start = {0.16, 0.62, 0.38},
  btn_hover = {0.35, 0.65, 1.00},
  resize    = {0.40, 0.45, 0.55},
  break_bg  = {0.20, 0.06, 0.06},
  break_acc = {0.95, 0.35, 0.30},
  break_btn = {0.85, 0.30, 0.25},
  break_btn_h = {1.00, 0.45, 0.40},
  dropdown  = {0.12, 0.13, 0.17},
  dropdown_h = {0.22, 0.30, 0.45},
  shadow    = {0.04, 0.04, 0.06},
}

-- ============================================================
-- LANGUAGE STORAGE
-- ============================================================
-- langs заполняется автоматически из секций INI: { {code="RU", name="Русский"}, ... }
local langs = {}
local T = {}
local T_fallback = {}

local function tr(key)
  local v = T[key]
  if v == nil then v = T_fallback[key] end
  if v == nil then return key end
  return v
end

-- ============================================================
-- HELPERS
-- ============================================================
local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

local function apply_aspect(w, h, prefer_w)
  if prefer_w then
    h = math.floor(w / ASPECT + 0.5)
  else
    w = math.floor(h * ASPECT + 0.5)
  end
  w = clamp(w, MIN_TIMER_W, 600)
  h = clamp(h, MIN_TIMER_H, 300)
  if prefer_w then
    h = math.floor(w / ASPECT + 0.5)
  else
    w = math.floor(h * ASPECT + 0.5)
  end
  return w, h
end

-- ============================================================
-- INI PARSING
-- ============================================================
local function parse_ini_file()
  -- Возвращает params (глобальная область) и sections (все [XX] с полями).
  -- Дополнительно возвращает порядок секций (order).
  local params = {}
  local sections = {}
  local order = {}
  local current_section = nil
  local f = io.open(ini_path, "r")
  if not f then return params, sections, order end
  for raw_line in f:lines() do
    local line = raw_line:gsub("\r$", "")
    local section = line:match("^%s*%[([^%]]+)%]%s*$")
    if section then
      current_section = section:upper()
      if not sections[current_section] then
        sections[current_section] = {}
        order[#order + 1] = current_section
      end
    else
      local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if key then
        if current_section then
          sections[current_section][key] = val
        else
          params[key] = val
        end
      end
    end
  end
  f:close()
  return params, sections, order
end

-- Собирает список языков из секций INI.
-- Секцией языка считается любая секция, у которой есть поле langName.
local function collect_languages()
  local _, sections, order = parse_ini_file()
  langs = {}
  for _, code in ipairs(order) do
    local sec = sections[code]
    if sec and sec.langName and sec.langName ~= "" then
      langs[#langs + 1] = { code = code, name = sec.langName }
    end
  end
end

local function build_translation(lang_code)
  local _, sections = parse_ini_file()
  return sections[lang_code:upper()] or {}
end

local function reload_translations()
  if #langs == 0 then
    T = {}
    T_fallback = {}
    return
  end
  local first_code = langs[1].code
  T_fallback = build_translation(first_code)

  local idx = settings.lang + 1
  if idx < 1 or idx > #langs then
    settings.lang = 0
    idx = 1
  end
  local cur_code = langs[idx].code
  if cur_code == first_code then
    T = T_fallback
  else
    T = build_translation(cur_code)
  end
end

local function load_ini()
  settings = {}
  for k, v in pairs(defaults) do settings[k] = v end

  local params = parse_ini_file()
  for key, val in pairs(params) do
    if defaults[key] ~= nil then
      local num = tonumber(val)
      if num then settings[key] = num end
    end
  end

  collect_languages()

  if settings.lang < 0 or settings.lang > #langs - 1 then
    settings.lang = 0
  end

  reload_translations()
end

-- Сохраняет параметры и все языковые секции, ничего не теряя.
local function save_ini()
  local lines = {}
  local f = io.open(ini_path, "r")
  if f then
    for line in f:lines() do
      lines[#lines + 1] = line:gsub("\r$", "")
    end
    f:close()
  end

  -- Собираем тело секций (все, кроме глобальных параметров).
  local sections_in = {}
  local order_in = {}
  local current_section = nil
  for _, l in ipairs(lines) do
    local s = l:match("^%s*%[([^%]]+)%]%s*$")
    if s then
      current_section = s
      sections_in[current_section] = sections_in[current_section] or {}
      order_in[#order_in + 1] = current_section
    elseif current_section then
      sections_in[current_section][#sections_in[current_section] + 1] = l
    end
  end

  -- Формируем вывод.
  local out = {}
  out[#out + 1] = "; Sound Engineer Labor Safety – settings"
  out[#out + 1] = "; Параметры скрипта (до первой секции)"
  out[#out + 1] = "; Settings (before the first section)"
  out[#out + 1] = ""
  out[#out + 1] = "safe_minutes="     .. tostring(settings.safe_minutes)
  out[#out + 1] = "short_break_sec="  .. tostring(settings.short_break_sec)
  out[#out + 1] = "long_break_sec="   .. tostring(settings.long_break_sec)
  out[#out + 1] = "show_float_timer=" .. tostring(settings.show_float_timer)
  out[#out + 1] = "lang="             .. tostring(settings.lang)
  out[#out + 1] = "timer_x="          .. tostring(math.floor(settings.timer_x))
  out[#out + 1] = "timer_y="          .. tostring(math.floor(settings.timer_y))
  out[#out + 1] = "timer_w="          .. tostring(math.floor(settings.timer_w))
  out[#out + 1] = "timer_h="          .. tostring(math.floor(settings.timer_h))
  out[#out + 1] = "settings_x="       .. tostring(math.floor(settings.settings_x))
  out[#out + 1] = "settings_y="       .. tostring(math.floor(settings.settings_y))
  out[#out + 1] = "break_x="          .. tostring(math.floor(settings.break_x))
  out[#out + 1] = "break_y="          .. tostring(math.floor(settings.break_y))
  out[#out + 1] = "idle_cpu_save="    .. tostring(settings.idle_cpu_save)
  out[#out + 1] = "idle_minutes="     .. tostring(settings.idle_minutes)
  out[#out + 1] = ""

  for _, sec_name in ipairs(order_in) do
    out[#out + 1] = "[" .. sec_name .. "]"
    for _, l in ipairs(sections_in[sec_name]) do
      out[#out + 1] = l
    end
    out[#out + 1] = ""
  end

  local wf = io.open(ini_path, "w")
  if not wf then return end
  wf:write(table.concat(out, "\n"))
  wf:close()
end

-- Если INI нет — создаём с RU/EN по умолчанию.
local function ensure_ini_exists()
  local f = io.open(ini_path, "r")
  if f then f:close() return end

  local content = [[; Sound Engineer Labor Safety – settings
; Параметры скрипта (до первой секции)
; Settings (before the first section)

safe_minutes=50
short_break_sec=15
long_break_sec=120
show_float_timer=1
lang=1
timer_x=300
timer_y=200
timer_w=130
timer_h=55
settings_x=200
settings_y=200
break_x=400
break_y=260
idle_cpu_save=0
idle_minutes=30

[RU]
langName=Русский
window_title=Трудовая безопасность звукорежиссёра
window_subtitle=Labor Safety Timer
row_safe_minutes=1. Безопасное непрерывное время (мин)
row_short_break=2. Не считается перерывом (сек)
row_long_break=3. Считается перерывом / сброс (сек)
row_show_float=4. Показывать плавающее окно таймера
row_language=5. Язык интерфейса
row_idle_cpu=6. Снимать нагрузку при простое
row_idle_minutes=7. Время простоя до снятия нагрузки (мин)
link_header=Автор / Поддержка:

btn_start=START
edit_dialog_title=Значение
edit_dialog_caption=Значение:

break_header=⏸  ПЕРЕРЫВ
break_autoclose=Закрытие через %d сек
break_line1=Время непрерывной работы истекло.
break_line2=Пожалуйста, сделайте перерыв и отдохните.
break_line3=Воспроизведение остановлено в целях вашей безопасности.
break_button=Продолжить

idle_countdown_header=⏳  СНЯТИЕ НАГРУЗКИ
idle_countdown_autoclose=Через %d сек проект будет выгружен
idle_countdown_line1=Долгий простой. Скоро нагрузка на процессор будет снята.
idle_countdown_line2=Начните воспроизведение, чтобы отменить.
idle_countdown_button=Отмена

idle_restore_header=💤  ПРОЕКТ ВЫГРУЖЕН
idle_restore_line1=Проект выгружен для снижения нагрузки на CPU.
idle_restore_line2=Нажмите кнопку, чтобы вернуться к работе.
idle_restore_button=Продолжить работу

menu_stop=Stop
menu_lock=Lock
menu_unlock=Unlock
menu_close=Close window

[EN]
langName=English
window_title=Sound Engineer Labor Safety
window_subtitle=Labor Safety Timer
row_safe_minutes=1. Safe continuous time (min)
row_short_break=2. Does not count as break (sec)
row_long_break=3. Counts as break / reset (sec)
row_show_float=4. Show floating timer window
row_language=5. Interface language
row_idle_cpu=6. Unload project on long idle
row_idle_minutes=7. Idle time before unload (min)
link_header=Author / Support:
btn_start=START
edit_dialog_title=Value
edit_dialog_caption=Value:

break_header=⏸  BREAK
break_autoclose=Closing in %d sec
break_line1=Continuous work time is over.
break_line2=Please take a break and rest.
break_line3=Playback has been stopped for your safety.
break_button=Continue

idle_countdown_header=⏳  UNLOADING PROJECT
idle_countdown_autoclose=Project will be unloaded in %d sec
idle_countdown_line1=Long idle detected. CPU load will be reduced soon.
idle_countdown_line2=Start playback to cancel.
idle_countdown_button=Cancel

idle_restore_header=💤  PROJECT UNLOADED
idle_restore_line1=Project unloaded to reduce CPU load.
idle_restore_line2=Press the button to return to work.
idle_restore_button=Continue working

menu_stop=Stop
menu_lock=Lock
menu_unlock=Unlock
menu_close=Close window
]]

  local wf = io.open(ini_path, "w")
  if wf then
    wf:write(content)
    wf:close()
  end
end

-- ============================================================
-- HELPERS (rest)
-- ============================================================
local function format_time(sec)
  sec = math.max(0, math.floor(sec + 0.5))
  local m = math.floor(sec / 60)
  local s = sec % 60
  return string.format("%02d:%02d", m, s)
end

local function is_playing()
  local st = reaper.GetPlayState()
  return (st & 1) == 1 or (st & 4) == 4
end

-- Идёт запись прямо сейчас? (бит &4 в GetPlayState)
local function is_recording()
  local st = reaper.GetPlayState()
  return (st & 4) == 4
end


local function is_rendering()
  local proj = reaper.EnumProjects(0x40000000)
  return proj ~= nil
end

local function stop_transport()
  reaper.Main_OnCommand(1016, 0)
end

-- ============================================================
-- IDLE CPU-SAVE HELPERS
-- ============================================================
local function reset_idle_state()
  idle_sec = 0
  idle_last_check = nil
  idle_last_mx, idle_last_my = nil, nil
  idle_countdown = 0
  idle_countdown_start = 0
  idle_orig_proj = nil
  idle_new_proj = nil
end

local function get_current_project()
  return reaper.EnumProjects(-1)
end

local function switch_to_empty_tab()
  idle_orig_proj = get_current_project()
  reaper.Main_OnCommand(40859, 0) -- New project tab (switches to it)
  idle_new_proj = get_current_project()
end

local function restore_original_tab()
  if idle_orig_proj then
    if idle_new_proj and get_current_project() == idle_new_proj then
      reaper.Main_OnCommand(40860, 0) -- Close current project tab
    end
    if idle_orig_proj then
      reaper.SelectProjectInstance(idle_orig_proj)
    end
  end
  idle_orig_proj = nil
  idle_new_proj = nil
end

local open_idle_countdown_window
local open_idle_restore_window
local close_idle_window

-- ============================================================
-- GFX HELPERS
-- ============================================================
local function set_color(c, a)
  gfx.r, gfx.g, gfx.b = c[1], c[2], c[3]
  gfx.a = a or 1
end

local function draw_round_rect(x, y, w, h, c, a, r)
  r = r or 10
  set_color(c, a)
  gfx.rect(x + r, y, w - 2 * r, h, 1)
  gfx.rect(x, y + r, w, h - 2 * r, 1)
  gfx.circle(x + r, y + r, r, 1, 1)
  gfx.circle(x + w - r, y + r, r, 1, 1)
  gfx.circle(x + r, y + h - r, r, 1, 1)
  gfx.circle(x + w - r, y + h - r, r, 1, 1)
end

local function draw_text(str, x, y, c)
  set_color(c)
  gfx.x, gfx.y = x, y
  gfx.drawstr(str)
end

local function mouse_in(x, y, w, h)
  local mx, my = gfx.mouse_x, gfx.mouse_y
  return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function edit_number(title_key, current, minv, maxv)
  local title = tr(title_key)
  local caption = tr("edit_dialog_caption")
  local retval, str = reaper.GetUserInputs(title, 1, caption, tostring(current))
  if not retval then return current end
  local num = tonumber(str)
  if not num then return current end
  return math.max(minv, math.min(maxv, math.floor(num + 0.5)))
end

local function set_fitting_font(text, max_w, max_h)
  for size = 96, 12, -1 do
    gfx.setfont(1, "Arial", size)
    local tw, th = gfx.measurestr(text)
    if tw <= max_w * 0.94 and th <= max_h * 0.88 then
      return size, tw, th
    end
  end
  gfx.setfont(1, "Arial", 16)
  local tw, th = gfx.measurestr(text)
  return 16, tw, th
end


local function get_cached_fitting_font(text, max_w, max_h)
  if timer_font_w == max_w and timer_font_h == max_h then
    gfx.setfont(1, "Arial", timer_font_size)
    return timer_font_size
  end
  local size = set_fitting_font(text, max_w, max_h)
  timer_font_size, timer_font_w, timer_font_h = size, max_w, max_h
  return size
end

-- ============================================================
-- WINDOW POSITION
-- ============================================================
local function get_window_pos()
  local _, x, y, w, h = gfx.dock(-1, 0, 0, 0, 0)
  if x and w and w > 20 and h > 20 then
    return x, y, w, h
  end
  return settings.timer_x, settings.timer_y, settings.timer_w, settings.timer_h
end

local function set_window_pos(x, y, w, h)
  gfx.init("", math.floor(w), math.floor(h), 0, math.floor(x), math.floor(y))
end

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local open_timer_window
local close_break_window
-- open_idle_* already declared above

-- ============================================================
-- OPEN WINDOWS
-- ============================================================
local function open_settings_window()
  ui_mode = "settings"
  window_open = true
  gfx.init(tr("window_title") .. " • Settings", SETTINGS_W, SETTINGS_H, 0,
           math.floor(settings.settings_x), math.floor(settings.settings_y))
  gfx.setfont(1, "Arial", 16)
end

open_timer_window = function()
  ui_mode = "timer"
  window_open = true
  timer_force_redraw = true

  settings.timer_w, settings.timer_h = apply_aspect(settings.timer_w, settings.timer_h, true)

  gfx.init("SafetyTimer",
           settings.timer_w, settings.timer_h,
           0,
           math.floor(settings.timer_x), math.floor(settings.timer_y))

  reaper.defer(function()
    local hwnd = reaper.JS_Window_Find("SafetyTimer", true)
    if hwnd then
      reaper.JS_Window_SetStyle(hwnd, "POPUP")
      reaper.JS_WindowMessage_Send(hwnd, "WM_NCCALCSIZE", 0, 0, 0, 0)
      if reaper.JS_Window_SetPosition then
        reaper.JS_Window_SetPosition(hwnd,
          math.floor(settings.timer_x), math.floor(settings.timer_y),
          settings.timer_w, settings.timer_h)
      end
    end
  end)
end

local function open_break_window()
  rest_shown = true
  ui_mode = "break"
  window_open = true
  break_countdown = BREAK_AUTO_CLOSE
  break_start_time = reaper.time_precise()

  gfx.init("SafetyBreak", BREAK_W, BREAK_H, 0,
           math.floor(settings.break_x), math.floor(settings.break_y))

  reaper.defer(function()
    local hwnd = reaper.JS_Window_Find("SafetyBreak", true)
    if hwnd then
      reaper.JS_Window_SetStyle(hwnd, "POPUP")
      reaper.JS_WindowMessage_Send(hwnd, "WM_NCCALCSIZE", 0, 0, 0, 0)
      if reaper.JS_Window_SetPosition then
        reaper.JS_Window_SetPosition(hwnd,
          math.floor(settings.break_x), math.floor(settings.break_y),
          BREAK_W, BREAK_H)
      end
    end
  end)
end

open_idle_countdown_window = function()
  ui_mode = "idle_countdown"
  window_open = true
  idle_countdown = IDLE_COUNTDOWN_SEC
  idle_countdown_start = reaper.time_precise()

  gfx.init("SafetyIdleCountdown", IDLE_W, IDLE_H, 0,
           math.floor(settings.break_x), math.floor(settings.break_y))

  reaper.defer(function()
    local hwnd = reaper.JS_Window_Find("SafetyIdleCountdown", true)
    if hwnd then
      reaper.JS_Window_SetStyle(hwnd, "POPUP")
      reaper.JS_WindowMessage_Send(hwnd, "WM_NCCALCSIZE", 0, 0, 0, 0)
      if reaper.JS_Window_SetPosition then
        reaper.JS_Window_SetPosition(hwnd,
          math.floor(settings.break_x), math.floor(settings.break_y),
          IDLE_W, IDLE_H)
      end
    end
  end)
end

open_idle_restore_window = function()
  ui_mode = "idle_restore"
  window_open = true

  gfx.init("SafetyIdleRestore", IDLE_W, IDLE_H, 0,
           math.floor(settings.break_x), math.floor(settings.break_y))

  reaper.defer(function()
    local hwnd = reaper.JS_Window_Find("SafetyIdleRestore", true)
    if hwnd then
      reaper.JS_Window_SetStyle(hwnd, "POPUP")
      reaper.JS_WindowMessage_Send(hwnd, "WM_NCCALCSIZE", 0, 0, 0, 0)
      if reaper.JS_Window_SetPosition then
        reaper.JS_Window_SetPosition(hwnd,
          math.floor(settings.break_x), math.floor(settings.break_y),
          IDLE_W, IDLE_H)
      end
      if reaper.JS_Window_SetForeground then
        reaper.JS_Window_SetForeground(hwnd)
      end
    end
  end)
end

close_idle_window = function()
  idle_dragging = false
  if ui_mode == "idle_countdown" then
    reset_idle_state()
    if settings.show_float_timer == 1 and is_running then
      open_timer_window()
    else
      window_open = false
      ui_mode = "background"
      gfx.quit()
    end
  elseif ui_mode == "idle_restore" then
    restore_original_tab()
    reset_idle_state()
    if settings.show_float_timer == 1 and is_running then
      open_timer_window()
    else
      window_open = false
      ui_mode = "background"
      gfx.quit()
    end
  end
end

-- ============================================================
-- CORE TIMER
-- ============================================================
local function update_idle()
  if not is_running then return end
  if settings.idle_cpu_save ~= 1 then return end
  if ui_mode == "break" or ui_mode == "idle_countdown" or ui_mode == "idle_restore" then return end

  local now = reaper.time_precise()

  -- Light check every ~10 s: mouse + transport (negligible CPU)
  if idle_last_check and (now - idle_last_check) < IDLE_CHECK_INTERVAL then
    return
  end

  local was_idle = idle_last_check ~= nil
  local delta = idle_last_check and (now - idle_last_check) or 0
  idle_last_check = now

  -- Any transport activity = user is working
  if is_recording() or is_rendering() or is_playing() then
    idle_sec = 0
    idle_last_mx, idle_last_my = reaper.GetMousePosition()
    return
  end

  -- Mouse movement = user is working in REAPER (or at the desk)
  local mx, my = reaper.GetMousePosition()
  if idle_last_mx and idle_last_my then
    local dx = math.abs(mx - idle_last_mx)
    local dy = math.abs(my - idle_last_my)
    if dx >= IDLE_MOUSE_THRESHOLD or dy >= IDLE_MOUSE_THRESHOLD then
      idle_sec = 0
      idle_last_mx, idle_last_my = mx, my
      return
    end
  end
  idle_last_mx, idle_last_my = mx, my

  -- Optional: mouse button held = activity (JS extension, already used by script)
  if reaper.JS_Mouse_GetState then
    local mstate = reaper.JS_Mouse_GetState(1 + 2 + 64) -- L/R/M buttons
    if mstate ~= 0 then
      idle_sec = 0
      return
    end
  end

  -- Truly idle: accumulate time
  if was_idle then
    idle_sec = idle_sec + delta
  end

  if idle_sec >= settings.idle_minutes * 60 then
    idle_sec = 0
    idle_last_check = nil
    idle_last_mx, idle_last_my = nil, nil
    open_idle_countdown_window()
  end
end

local function update_timer()
  if not is_running then return end

  local now = reaper.time_precise()


  if is_recording() or is_rendering() then
    last_play_time = now
    pause_start = nil
    return
  end

  local playing = is_playing()

  if playing then
    if pause_start then
      local pause_dur = now - pause_start
      pause_start = nil
      if pause_dur >= settings.long_break_sec then
        continuous_sec = 0
        rest_shown = false
      end
    end
    if last_play_time then
      continuous_sec = continuous_sec + (now - last_play_time)
    end
    last_play_time = now

    if continuous_sec >= settings.safe_minutes * 60 and not rest_shown then
      stop_transport()
      continuous_sec = 0
      last_play_time = nil
      open_break_window()
    end
  else
    last_play_time = nil
    if not pause_start then
      pause_start = now
    end
  end
end

-- ============================================================
-- CLOSE HELPERS
-- ============================================================
local function close_window_keep_running()
  if gfx.w > 20 and gfx.h > 20 then
    settings.timer_w = gfx.w
    settings.timer_h = gfx.h
  end
  local x, y = get_window_pos()
  settings.timer_x = x
  settings.timer_y = y
  settings.timer_w, settings.timer_h = apply_aspect(settings.timer_w, settings.timer_h, true)
  save_ini()
  window_open = false
  ui_mode = "background"
  dragging = false
  resizing = false
  gfx.quit()
end

local function full_stop()
  is_running = false
  continuous_sec = 0
  last_play_time = nil
  pause_start = nil
  rest_shown = false
  reset_idle_state()

  if gfx.w > 20 and gfx.h > 20 then
    settings.timer_w = gfx.w
    settings.timer_h = gfx.h
  end
  local x, y = get_window_pos()
  settings.timer_x = x
  settings.timer_y = y
  settings.timer_w, settings.timer_h = apply_aspect(settings.timer_w, settings.timer_h, true)
  save_ini()

  window_open = false
  script_should_exit = true
  gfx.quit()
end

close_break_window = function()
  local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
  if x then
    settings.break_x = x
    settings.break_y = y
  end
  save_ini()

  break_dragging = false

  if settings.show_float_timer == 1 and is_running then
    open_timer_window()
  else
    window_open = false
    ui_mode = "background"
    gfx.quit()
  end
end

-- ============================================================
-- BREAK WINDOW DRAW
-- ============================================================
local function draw_break_window()
  local w, h = gfx.w, gfx.h

  if w ~= BREAK_W or h ~= BREAK_H then
    set_window_pos(settings.break_x, settings.break_y, BREAK_W, BREAK_H)
    w, h = BREAK_W, BREAK_H
  end

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  local in_header = my >= 0 and my <= 56

  if left_click and in_header then
    break_dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    wx = wx or settings.break_x
    wy = wy or settings.break_y
    break_drag_off_x = sx - wx
    break_drag_off_y = sy - wy
  end

  if left_release then
    if break_dragging then
      local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
      if x then
        settings.break_x = x
        settings.break_y = y
        save_ini()
      end
    end
    break_dragging = false
  end

  if break_dragging then
    local sx, sy = reaper.GetMousePosition()
    local new_x = sx - break_drag_off_x
    local new_y = sy - break_drag_off_y
    settings.break_x = new_x
    settings.break_y = new_y
    set_window_pos(new_x, new_y, BREAK_W, BREAK_H)
    last_mouse_cap = gfx.mouse_cap
    return
  end

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)

  draw_round_rect(0, 0, w, 56, col.break_bg, 1, 0)
  set_color(col.break_acc)
  gfx.rect(0, 0, w, 3, 1)

  gfx.setfont(1, "Arial", 18)
  draw_text(tr("break_header"), 20, 18, col.break_acc)

  local elapsed = reaper.time_precise() - break_start_time
  break_countdown = math.max(0, BREAK_AUTO_CLOSE - elapsed)
  local cd_str = string.format(tr("break_autoclose"), math.ceil(break_countdown))
  gfx.setfont(1, "Arial", 13)
  local cd_w = gfx.measurestr(cd_str)
  draw_text(cd_str, w - 20 - cd_w, 22, col.text_dim)

  gfx.setfont(1, "Arial", 16)
  draw_text(tr("break_line1"), 24, 88, col.text)

  gfx.setfont(1, "Arial", 14)
  draw_text(tr("break_line2"), 24, 116, col.text_dim)
  draw_text(tr("break_line3"), 24, 138, col.text_dim)

  local pb_x, pb_y = 24, 168
  local pb_w, pb_h = w - 48, 6
  draw_round_rect(pb_x, pb_y, pb_w, pb_h, col.input_bg, 1, 3)
  local pct = break_countdown / BREAK_AUTO_CLOSE
  local fill_w = math.floor(pb_w * pct)
  if fill_w > 4 then
    draw_round_rect(pb_x, pb_y, fill_w, pb_h, col.break_acc, 1, 3)
  end

  local btn_w, btn_h = 200, 42
  local bx = (w - btn_w) / 2
  local by = h - 58

  local hov = mouse_in(bx, by, btn_w, btn_h)
  local c = hov and col.break_btn_h or col.break_btn
  draw_round_rect(bx, by, btn_w, btn_h, c, 1, 8)

  gfx.setfont(1, "Arial", 16)
  local btn_label = tr("break_button")
  local tw = gfx.measurestr(btn_label)
  draw_text(btn_label, bx + (btn_w - tw) / 2, by + 12, col.text)

  if hov and left_click then
    close_break_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  local char = gfx.getchar()
  if char == 27 or char < 0 then
    close_break_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  if break_countdown <= 0 then
    close_break_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  last_mouse_cap = gfx.mouse_cap
end

-- ============================================================
-- IDLE COUNTDOWN / RESTORE WINDOWS
-- ============================================================
local function draw_idle_countdown_window()
  local w, h = gfx.w, gfx.h

  if w ~= IDLE_W or h ~= IDLE_H then
    set_window_pos(settings.break_x, settings.break_y, IDLE_W, IDLE_H)
    w, h = IDLE_W, IDLE_H
  end

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  local in_header = my >= 0 and my <= 56

  if left_click and in_header then
    idle_dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    wx = wx or settings.break_x
    wy = wy or settings.break_y
    idle_drag_off_x = sx - wx
    idle_drag_off_y = sy - wy
  end

  if left_release then
    if idle_dragging then
      local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
      if x then
        settings.break_x = x
        settings.break_y = y
        save_ini()
      end
    end
    idle_dragging = false
  end

  if idle_dragging then
    local sx, sy = reaper.GetMousePosition()
    local new_x = sx - idle_drag_off_x
    local new_y = sy - idle_drag_off_y
    settings.break_x = new_x
    settings.break_y = new_y
    set_window_pos(new_x, new_y, IDLE_W, IDLE_H)
    last_mouse_cap = gfx.mouse_cap
    return
  end

  if is_playing() or is_recording() or is_rendering() then
    close_idle_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)
  draw_round_rect(0, 0, w, 56, col.break_bg, 1, 0)
  set_color(col.warn)
  gfx.rect(0, 0, w, 3, 1)

  gfx.setfont(1, "Arial", 18)
  draw_text(tr("idle_countdown_header"), 20, 18, col.warn)

  local elapsed = reaper.time_precise() - idle_countdown_start
  idle_countdown = math.max(0, IDLE_COUNTDOWN_SEC - elapsed)
  local cd_str = string.format(tr("idle_countdown_autoclose"), math.ceil(idle_countdown))
  gfx.setfont(1, "Arial", 13)
  local cd_w = gfx.measurestr(cd_str)
  draw_text(cd_str, w - 20 - cd_w, 22, col.text_dim)

  gfx.setfont(1, "Arial", 16)
  draw_text(tr("idle_countdown_line1"), 24, 88, col.text)
  gfx.setfont(1, "Arial", 14)
  draw_text(tr("idle_countdown_line2"), 24, 116, col.text_dim)

  local pb_x, pb_y = 24, 168
  local pb_w, pb_h = w - 48, 6
  draw_round_rect(pb_x, pb_y, pb_w, pb_h, col.input_bg, 1, 3)
  local pct = idle_countdown / IDLE_COUNTDOWN_SEC
  local fill_w = math.floor(pb_w * pct)
  if fill_w > 4 then
    draw_round_rect(pb_x, pb_y, fill_w, pb_h, col.warn, 1, 3)
  end

  local btn_w, btn_h = 200, 42
  local bx = (w - btn_w) / 2
  local by = h - 58
  local hov = mouse_in(bx, by, btn_w, btn_h)
  local c = hov and col.btn_hover or col.btn_start
  draw_round_rect(bx, by, btn_w, btn_h, c, 1, 8)
  gfx.setfont(1, "Arial", 16)
  local btn_label = tr("idle_countdown_button")
  local tw = gfx.measurestr(btn_label)
  draw_text(btn_label, bx + (btn_w - tw) / 2, by + 12, col.text)

  if hov and left_click then
    close_idle_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  local char = gfx.getchar()
  if char == 27 or char < 0 then
    close_idle_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  if idle_countdown <= 0 then
    switch_to_empty_tab()
    open_idle_restore_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  last_mouse_cap = gfx.mouse_cap
end

local function draw_idle_restore_window()
  local w, h = gfx.w, gfx.h

  if w ~= IDLE_W or h ~= IDLE_H then
    set_window_pos(settings.break_x, settings.break_y, IDLE_W, IDLE_H)
    w, h = IDLE_W, IDLE_H
  end

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  local in_header = my >= 0 and my <= 56

  if left_click and in_header then
    idle_dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    wx = wx or settings.break_x
    wy = wy or settings.break_y
    idle_drag_off_x = sx - wx
    idle_drag_off_y = sy - wy
  end

  if left_release then
    if idle_dragging then
      local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
      if x then
        settings.break_x = x
        settings.break_y = y
        save_ini()
      end
    end
    idle_dragging = false
  end

  if idle_dragging then
    local sx, sy = reaper.GetMousePosition()
    local new_x = sx - idle_drag_off_x
    local new_y = sy - idle_drag_off_y
    settings.break_x = new_x
    settings.break_y = new_y
    set_window_pos(new_x, new_y, IDLE_W, IDLE_H)
    last_mouse_cap = gfx.mouse_cap
    return
  end

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)
  draw_round_rect(0, 0, w, 56, {0.06, 0.12, 0.20}, 1, 0)
  set_color(col.accent)
  gfx.rect(0, 0, w, 3, 1)

  gfx.setfont(1, "Arial", 18)
  draw_text(tr("idle_restore_header"), 20, 18, col.accent)

  gfx.setfont(1, "Arial", 16)
  draw_text(tr("idle_restore_line1"), 24, 100, col.text)
  gfx.setfont(1, "Arial", 14)
  draw_text(tr("idle_restore_line2"), 24, 130, col.text_dim)

  local btn_w, btn_h = 220, 48
  local bx = (w - btn_w) / 2
  local by = h - 70
  local hov = mouse_in(bx, by, btn_w, btn_h)
  local c = hov and col.btn_hover or col.btn_start
  draw_round_rect(bx, by, btn_w, btn_h, c, 1, 8)
  gfx.setfont(1, "Arial", 16)
  local btn_label = tr("idle_restore_button")
  local tw = gfx.measurestr(btn_label)
  draw_text(btn_label, bx + (btn_w - tw) / 2, by + 15, col.text)

  if hov and left_click then
    close_idle_window()
    last_mouse_cap = gfx.mouse_cap
    return
  end

  local char = gfx.getchar()
  if char == 27 or char < 0 then
    -- ESC does not close – user must press the button
  end

  last_mouse_cap = gfx.mouse_cap
end

-- ============================================================
-- LANGUAGE DROPDOWN
-- ============================================================
local function draw_language_dropdown(x, y, w, h)
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0

  if #langs == 0 then
    -- нет языков — рисуем заглушку
    draw_round_rect(x, y, w, h, col.input_bg, 1, 5)
    set_color(col.border); gfx.rect(x, y, w, h, 0)
    return
  end

  local current = langs[settings.lang + 1] or langs[1]
  local hovered = mouse_in(x, y, w, h)
  local bg = hovered and col.accent or col.input_bg
  draw_round_rect(x, y, w, h, bg, 1, 5)
  set_color(col.border)
  gfx.rect(x, y, w, h, 0)

  gfx.setfont(1, "Arial", 14)
  local label = current.name .. "  ▾"
  local tw = gfx.measurestr(label)
  draw_text(label, x + 10, y + (h - 14) / 2 + 1, col.text)

  if left_click and hovered then
    lang_dropdown_open = not lang_dropdown_open
    last_mouse_cap = gfx.mouse_cap
    return
  end

  if lang_dropdown_open then
    local item_h = 26
    local list_h = item_h * #langs
    local ly = y + h + 2

    draw_round_rect(x + 2, ly + 2, w, list_h, col.shadow, 0.35, 6)
    draw_round_rect(x, ly, w, list_h, col.dropdown, 1, 6)
    set_color(col.border)
    gfx.rect(x, ly, w, list_h, 0)

    for i, lang in ipairs(langs) do
      local iy = ly + (i - 1) * item_h
      local hovered_item = mouse_in(x, iy, w, item_h)
      if hovered_item then
        draw_round_rect(x + 2, iy + 1, w - 4, item_h - 2, col.dropdown_h, 1, 4)
      end
      gfx.setfont(1, "Arial", 14)
      local is_current = (i - 1) == settings.lang
      local c = is_current and col.accent or col.text
      draw_text(lang.name, x + 10, iy + (item_h - 14) / 2 + 1, c)

      if hovered_item and left_click then
        if settings.lang ~= (i - 1) then
          settings.lang = i - 1
          reload_translations()
          save_ini()
        end
        lang_dropdown_open = false
        last_mouse_cap = gfx.mouse_cap
        return
      end
    end

    if left_click and not mouse_in(x, ly, w, list_h) and not hovered then
      lang_dropdown_open = false
    end
  end
end

-- ============================================================
-- SETTINGS WINDOW
-- ============================================================
local function draw_settings_window()
  local w, h = gfx.w, gfx.h

  if w ~= SETTINGS_W or h ~= SETTINGS_H then
    set_window_pos(settings.settings_x, settings.settings_y, SETTINGS_W, SETTINGS_H)
    w, h = SETTINGS_W, SETTINGS_H
  end

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  local in_header = my >= 0 and my <= 48

  if left_click and in_header then
    settings_dragging = true
    local sx, sy = reaper.GetMousePosition()
    local wx, wy = get_window_pos()
    settings_drag_off_x = sx - wx
    settings_drag_off_y = sy - wy
  end

  if left_release then
    if settings_dragging then
      local x, y = get_window_pos()
      settings.settings_x = x
      settings.settings_y = y
      save_ini()
    end
    settings_dragging = false
  end

  if settings_dragging then
    local sx, sy = reaper.GetMousePosition()
    local new_x = sx - settings_drag_off_x
    local new_y = sy - settings_drag_off_y
    settings.settings_x = new_x
    settings.settings_y = new_y
    set_window_pos(new_x, new_y, SETTINGS_W, SETTINGS_H)
    last_mouse_cap = gfx.mouse_cap
    return
  end

  draw_round_rect(0, 0, w, 48, col.panel, 1, 0)
  gfx.setfont(1, "Arial", 15)
  draw_text(tr("window_title"), 20, 14, col.text)
  gfx.setfont(1, "Arial", 12)
  draw_text(tr("window_subtitle"), 20, 32, col.text_dim)
  gfx.setfont(1, "Arial", 16)

  local y = 68
  local left = 24
  local val_w = 90
  local row_h = 44

  local rows = {
    { key = "safe_minutes",    label_key = "row_safe_minutes", min = 5,  max = 180 },
    { key = "short_break_sec", label_key = "row_short_break",  min = 1,  max = 60  },
    { key = "long_break_sec",  label_key = "row_long_break",   min = 30, max = 600 },
  }

  for i, row in ipairs(rows) do
    local ry = y + (i - 1) * row_h
    draw_round_rect(left - 8, ry - 6, w - 32, 36, col.panel, 1, 6)
    draw_text(tr(row.label_key), left, ry + 4, col.text)

    local vx = w - left - val_w
    local hovered = mouse_in(vx, ry - 2, val_w, 28)
    draw_round_rect(vx, ry - 2, val_w, 28, hovered and col.accent or col.input_bg, 1, 5)
    set_color(col.border)
    gfx.rect(vx, ry - 2, val_w, 28, 0)

    local val_str = tostring(settings[row.key])
    local tw = gfx.measurestr(val_str)
    draw_text(val_str, vx + (val_w - tw) / 2, ry + 4, col.text)

    if hovered and (gfx.mouse_cap & 1) == 1 and gfx.mouse_cap ~= last_mouse_cap then
      settings[row.key] = edit_number(row.label_key, settings[row.key], row.min, row.max)
    end
  end

  local cy = y + 3 * row_h + 8
  draw_round_rect(left - 8, cy - 6, w - 32, 36, col.panel, 1, 6)
  draw_text(tr("row_show_float"), left + 28, cy + 4, col.text)

  local cb_x, cb_y = left, cy + 2
  local checked = settings.show_float_timer == 1
  draw_round_rect(cb_x, cb_y, 20, 20, checked and col.accent or col.input_bg, 1, 4)
  set_color(col.border)
  gfx.rect(cb_x, cb_y, 20, 20, 0)
  if checked then
    draw_text("✓", cb_x + 3, cb_y + 1, col.text)
  end
  if mouse_in(cb_x, cb_y, 20, 20) and (gfx.mouse_cap & 1) == 1 and gfx.mouse_cap ~= last_mouse_cap then
    settings.show_float_timer = checked and 0 or 1
  end

  -- Idle CPU-save checkbox
  local idle_cy = cy + row_h
  draw_round_rect(left - 8, idle_cy - 6, w - 32, 36, col.panel, 1, 6)
  draw_text(tr("row_idle_cpu"), left + 28, idle_cy + 4, col.text)

  local icb_x, icb_y = left, idle_cy + 2
  local idle_checked = settings.idle_cpu_save == 1
  draw_round_rect(icb_x, icb_y, 20, 20, idle_checked and col.accent or col.input_bg, 1, 4)
  set_color(col.border)
  gfx.rect(icb_x, icb_y, 20, 20, 0)
  if idle_checked then
    draw_text("✓", icb_x + 3, icb_y + 1, col.text)
  end
  if mouse_in(icb_x, icb_y, 20, 20) and (gfx.mouse_cap & 1) == 1 and gfx.mouse_cap ~= last_mouse_cap then
    settings.idle_cpu_save = idle_checked and 0 or 1
  end

  -- Idle minutes
  local idle_min_y = idle_cy + row_h
  draw_round_rect(left - 8, idle_min_y - 6, w - 32, 36, col.panel, 1, 6)
  draw_text(tr("row_idle_minutes"), left, idle_min_y + 4, col.text)

  local ivx = w - left - val_w
  local idle_hov = mouse_in(ivx, idle_min_y - 2, val_w, 28)
  draw_round_rect(ivx, idle_min_y - 2, val_w, 28, idle_hov and col.accent or col.input_bg, 1, 5)
  set_color(col.border)
  gfx.rect(ivx, idle_min_y - 2, val_w, 28, 0)
  local idle_val_str = tostring(settings.idle_minutes)
  local itw = gfx.measurestr(idle_val_str)
  draw_text(idle_val_str, ivx + (val_w - itw) / 2, idle_min_y + 4, col.text)
  if idle_hov and (gfx.mouse_cap & 1) == 1 and gfx.mouse_cap ~= last_mouse_cap then
    settings.idle_minutes = edit_number("row_idle_minutes", settings.idle_minutes, 5, 240)
  end

  -- Language
  local lang_y = idle_min_y + row_h
  draw_round_rect(left - 8, lang_y - 6, w - 32, 36, col.panel, 1, 6)
  draw_text(tr("row_language"), left, lang_y + 4, col.text)

  local dd_w = 160
  local dd_h = 28
  local dd_x = w - left - dd_w
  local dd_y = lang_y - 2
  draw_language_dropdown(dd_x, dd_y, dd_w, dd_h)

  -- Links (не переводятся)
  local links_y = lang_y + row_h + 6
  gfx.setfont(1, "Arial", 13)
  draw_text(tr("link_header"), left, links_y, col.text_dim)

  local ly = links_y + 20
  local link_h = 20
  for i, ln in ipairs(links) do
    local ry = ly + (i - 1) * link_h
    local hovered = mouse_in(left, ry - 2, w - 2 * left, link_h)
    local c = hovered and col.link_hov or col.link
    draw_text(ln.text, left, ry, c)

    if hovered and (gfx.mouse_cap & 1) == 1 and (last_mouse_cap & 1) == 0 then
      open_url(ln.url)
    end
  end

  local btn_y = h - 68
  local btn_w = 200
  local btn_h = 44
  local bx = (w - btn_w) / 2

  local hov = mouse_in(bx, btn_y, btn_w, btn_h)
  local c = hov and col.btn_hover or col.btn_start
  draw_round_rect(bx, btn_y, btn_w, btn_h, c, 1, 8)
  local btn_label = tr("btn_start")
  local tw = gfx.measurestr(btn_label)
  draw_text(btn_label, bx + (btn_w - tw) / 2, btn_y + 13, col.text)

  if hov and (gfx.mouse_cap & 1) == 1 and gfx.mouse_cap ~= last_mouse_cap then
    save_ini()
    is_running = true
    continuous_sec = 0
    last_play_time = nil
    pause_start = nil
    rest_shown = false
    timer_locked = false
    lang_dropdown_open = false
    reset_idle_state()
    if settings.show_float_timer == 1 then
      open_timer_window()
    else
      window_open = false
      ui_mode = "background"
      gfx.quit()
    end
  end

  last_mouse_cap = gfx.mouse_cap
end

-- ============================================================
-- FLOATING TIMER
-- ============================================================
local function draw_timer_window()
  local w, h = gfx.w, gfx.h

  if w > 20 and h > 20 and not resizing then
    settings.timer_w = w
    settings.timer_h = h
  end

  local remain = math.max(0, settings.safe_minutes * 60 - continuous_sec)
  local pct = continuous_sec / math.max(1, settings.safe_minutes * 60)
  local tstr = format_time(remain)
  local bgcat = (pct > 0.85) and 2 or ((pct > 0.60) and 1 or 0)

  local now = reaper.time_precise()
  local need_paint = timer_force_redraw
    or tstr ~= timer_last_tstr
    or bgcat ~= timer_last_bgcat
    or w ~= timer_last_w
    or h ~= timer_last_h
    or (now - timer_last_paint_time) > TIMER_MAX_IDLE

  local painted = false

  if need_paint then
    painted = true
    timer_force_redraw = false
    timer_last_tstr = tstr
    timer_last_bgcat = bgcat
    timer_last_w, timer_last_h = w, h
    timer_last_paint_time = now

    local bg = {0.08, 0.09, 0.11}
    if bgcat == 2 then
      bg = {0.18, 0.06, 0.06}
    elseif bgcat == 1 then
      bg = {0.16, 0.12, 0.05}
    end
    local radius = math.max(10, math.min(20, math.floor(math.min(w, h) * 0.28)))
    draw_round_rect(0, 0, w, h, bg, 1, radius)

    local tcol = bgcat == 2 and col.danger or (bgcat == 1 and col.warn or col.accent2)
    get_cached_fitting_font(tstr, w, h)
    local tw, th = gfx.measurestr(tstr)
    draw_text(tstr, (w - tw) / 2, (h - th) / 2 - 1, tcol)
  end

  local handle = 20

  local mx, my = gfx.mouse_x, gfx.mouse_y
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  local in_resize = (not timer_locked) and mx >= (w - handle) and my >= (h - handle)

  if left_click then
    if in_resize then
      resizing = true
      dragging = false
      resize_start_w = w
      resize_start_h = h
      resize_start_mx, resize_start_my = reaper.GetMousePosition()
    elseif not timer_locked then
      dragging = true
      resizing = false
      local sx, sy = reaper.GetMousePosition()
      local wx, wy = get_window_pos()
      drag_off_x = sx - wx
      drag_off_y = sy - wy
    end
  end

  if left_release then
    if dragging or resizing then
      settings.timer_w = math.max(MIN_TIMER_W, gfx.w)
      settings.timer_h = math.max(MIN_TIMER_H, gfx.h)
      settings.timer_w, settings.timer_h = apply_aspect(settings.timer_w, settings.timer_h, true)
      local x, y = get_window_pos()
      settings.timer_x = x
      settings.timer_y = y
      save_ini()
    end
    dragging = false
    resizing = false
  end

  if dragging and not timer_locked then
    local sx, sy = reaper.GetMousePosition()
    local new_x = sx - drag_off_x
    local new_y = sy - drag_off_y
    settings.timer_x = new_x
    settings.timer_y = new_y
    set_window_pos(new_x, new_y, settings.timer_w, settings.timer_h)
  end

  if resizing and not timer_locked then
    local sx, sy = reaper.GetMousePosition()
    local dx = sx - resize_start_mx
    local dy = sy - resize_start_my
    local new_w = resize_start_w + dx
    local new_h = resize_start_h + dy
    new_w, new_h = apply_aspect(new_w, new_h, math.abs(dx) >= math.abs(dy))
    settings.timer_w = new_w
    settings.timer_h = new_h

    local x, y = get_window_pos()
    set_window_pos(x, y, new_w, new_h)
  end

  if (gfx.mouse_cap & 2) == 2 and (last_mouse_cap & 2) == 0 then
    local stop_label = tr("menu_stop")
    local lock_label = timer_locked and tr("menu_unlock") or tr("menu_lock")
    local close_label = tr("menu_close")

    local menu = stop_label .. "|"
    if timer_locked then
      menu = menu .. "!" .. lock_label .. "|"
    else
      menu = menu .. lock_label .. "|"
    end
    menu = menu .. close_label

    local ret = gfx.showmenu(menu)
    if ret == 1 then
      full_stop()
      return painted
    elseif ret == 2 then
      timer_locked = not timer_locked
    elseif ret == 3 then
      close_window_keep_running()
      return painted
    end
  end

  last_mouse_cap = gfx.mouse_cap
  return painted
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function main_loop()
  if script_should_exit then
    return
  end

  update_timer()
  update_idle()

  if window_open then
    local now = reaper.time_precise()
    local do_redraw = now >= next_frame_time

    if ui_mode == "break" then
      if do_redraw then
        next_frame_time = now + FRAME_INTERVAL
        draw_break_window()
        gfx.update()
      end
    elseif ui_mode == "idle_countdown" then
      if do_redraw then
        next_frame_time = now + FRAME_INTERVAL
        draw_idle_countdown_window()
        gfx.update()
      end
    elseif ui_mode == "idle_restore" then
      if do_redraw then
        next_frame_time = now + FRAME_INTERVAL
        draw_idle_restore_window()
        gfx.update()
      end
    else
      local char = gfx.getchar()
      if char == 27 or char < 0 then
        if ui_mode == "timer" then
          close_window_keep_running()
        else
          gfx.quit()
          return
        end
      else
        if do_redraw then
          next_frame_time = now + FRAME_INTERVAL
          if ui_mode == "settings" then
            draw_settings_window()
            gfx.update()
          elseif ui_mode == "timer" then
            if draw_timer_window() then
              gfx.update()
            end
          end
        end
      end
    end
  end

  reaper.defer(main_loop)
end

-- ============================================================
-- ENTRY
-- ============================================================
ensure_ini_exists()
load_ini()
open_settings_window()
reaper.defer(main_loop)