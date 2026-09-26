-- @description SSM_MIDI_Export
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🎹 Экспорт MIDI в отдельные .mid файлы: каждый выделенный трек или каждый
--   выделенный MIDI-айтем - в свой файл, в выбранную папку.
--
--   Что экспортировать (галочка):
--     - «Выделенные треки» - на файл по треку, в него попадают все MIDI-айтемы
--       трека; треки без MIDI пропускаются;
--     - «Выделенные MIDI-айтемы» - на файл по айтему.
--   Что вшить в файл:
--     - темп и размер такта проекта (изменения темпа, в том числе линейные
--       переходы, записываются ступенями по четвертям);
--     - маркеры проекта (регионы не переносятся) - только те, что попадают в
--       экспортируемый фрагмент.
--   Дополнительно:
--     - только выделенные ноты (те, что выделены в MIDI-редакторе);
--     - пропускать замьюченные события;
--     - начать с нуля: пустое место перед первым айтемом обрезается, темп и
--       маркеры сдвигаются вместе с нотами (иначе позиции как в проекте);
--     - что делать, если файл уже есть: добавить номер / перезаписать / пропустить;
--     - открыть папку после экспорта.
--   В списке видно, какие файлы будут созданы; строку можно исключить галочкой.
--   Список обновляется сам при смене выделения. Проект не изменяется.
--   Ограничения: текстовые события и sysex в файл не переносятся; зацикленные
--   айтемы экспортируются один раз, без повторов.
--   Для выбора папки диалогом нужен js_ReaScriptAPI (без него путь вводится
--   вручную). Enter - экспорт, Esc - закрыть.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
-- @changelog
--   1.0 Релиз: экспорт выделенных треков или MIDI-айтемов в отдельные файлы,
--   темп и маркеры на выбор, обрезка пустоты в начале, политика имён файлов.

local TITLE = "SSM MIDI Export"
local EXT_SECTION = "SSM_MidiExport"
local OUT_PPQ = 960                       -- разрешение в файле: тиков на четверть
local WIN_W, WIN_H = 760, 720
local MIN_W, MIN_H = 620, 520
local ROW_H, FOOT_H = 30, 104
local F_ROW, F_TITLE, F_SMALL, F_BTN = 17, 20, 15, 17
local CB = 20
local SCAN_EVERY = 0.5                    -- секунд между проверками выделения
local TEMPO_DQ = 1 / 64                   -- шаг измерения темпа, четвертей
local MAX_TEMPO_STEPS = 4000

-- Вертикальная раскладка окна
local Y_MODE = 70
local Y_OPT = { 108, 140, 172 }
local Y_FOLDER, FOLDER_H = 214, 32
local Y_POLICY = 258
local Y_LIST_HEAD, LIST_Y = 300, 328

local col = {
  bg = { 0.13, 0.14, 0.16 }, panel = { 0.17, 0.18, 0.21 }, row_alt = { 0.15, 0.16, 0.19 },
  text = { 0.92, 0.93, 0.95 }, dim = { 0.62, 0.65, 0.70 }, accent = { 0.30, 0.55, 0.95 },
  border = { 0.36, 0.38, 0.44 }, danger = { 0.95, 0.42, 0.42 }, ok = { 0.45, 0.85, 0.55 },
  btn = { 0.24, 0.26, 0.31 }, btn_hover = { 0.31, 0.34, 0.40 }, btn_off = { 0.18, 0.19, 0.22 },
}

local IS_WIN = (reaper.GetOS() or ""):find("^Win") ~= nil

----------------------------------------------------------------------
-- Настройки (ExtState)
----------------------------------------------------------------------
local cfg = {
  mode = "tracks",       -- "tracks" | "items"
  tempo = true, markers = true, only_sel = false, skip_muted = true, trim = false, open_after = false,
  policy = "number",     -- "number" | "overwrite" | "skip"
  folder = "",
}
local BOOL_KEYS = { "tempo", "markers", "only_sel", "skip_muted", "trim", "open_after" }
local POLICIES = {
  { key = "number", label = "добавить номер" },
  { key = "overwrite", label = "перезаписать" },
  { key = "skip", label = "пропустить" },
}

local function load_cfg()
  local m = reaper.GetExtState(EXT_SECTION, "mode")
  if m == "tracks" or m == "items" then cfg.mode = m end
  for _, k in ipairs(BOOL_KEYS) do
    local v = reaper.GetExtState(EXT_SECTION, k)
    if v == "1" then cfg[k] = true elseif v == "0" then cfg[k] = false end
  end
  local p = reaper.GetExtState(EXT_SECTION, "policy")
  for _, pol in ipairs(POLICIES) do if pol.key == p then cfg.policy = p end end
  cfg.folder = reaper.GetExtState(EXT_SECTION, "folder")
end

local function save_cfg()
  reaper.SetExtState(EXT_SECTION, "mode", cfg.mode, true)
  for _, k in ipairs(BOOL_KEYS) do reaper.SetExtState(EXT_SECTION, k, cfg[k] and "1" or "0", true) end
  reaper.SetExtState(EXT_SECTION, "policy", cfg.policy, true)
  reaper.SetExtState(EXT_SECTION, "folder", cfg.folder, true)
end

load_cfg()

----------------------------------------------------------------------
-- Запись Standard MIDI File
----------------------------------------------------------------------
local function varlen(n)
  local bytes = { n & 0x7F }
  n = n >> 7
  while n > 0 do
    table.insert(bytes, 1, (n & 0x7F) | 0x80)
    n = n >> 7
  end
  return string.char(table.unpack(bytes))
end

local function meta(kind, data) return "\xFF" .. string.char(kind) .. varlen(#data) .. data end

-- События - { tick, prio, seq, bytes }. При равных тиках сначала note-off (prio 0),
-- потом остальное (1), потом note-on (2): иначе соседние одинаковые ноты слипнутся.
local function build_track(events, end_tick)
  table.sort(events, function(a, b)
    if a.tick ~= b.tick then return a.tick < b.tick end
    if a.prio ~= b.prio then return a.prio < b.prio end
    return a.seq < b.seq
  end)
  local parts, last = {}, 0
  for _, e in ipairs(events) do
    parts[#parts + 1] = varlen(e.tick - last) .. e.bytes
    last = e.tick
  end
  local finish = math.max(end_tick or 0, last)
  parts[#parts + 1] = varlen(finish - last) .. "\xFF\x2F\x00"
  local body = table.concat(parts)
  return "MTrk" .. string.pack(">I4", #body) .. body
end

local function build_smf(chunks)
  local fmt = #chunks > 1 and 1 or 0
  return "MThd" .. string.pack(">I4I2I2I2", 6, fmt, #chunks, OUT_PPQ) .. table.concat(chunks)
end

local seq_counter = 0
local function add_event(list, tick, prio, bytes)
  seq_counter = seq_counter + 1
  list[#list + 1] = { tick = tick, prio = prio, seq = seq_counter, bytes = bytes }
end

----------------------------------------------------------------------
-- Данные проекта: темп, размер, маркеры
----------------------------------------------------------------------
local function round(x) return math.floor(x + 0.5) end

local function time_to_qn(t) return reaper.TimeMap2_timeToQN(0, t) end
local function qn_to_time(q) return reaper.TimeMap2_QNToTime(0, q) end

-- Темп в четвертях в минуту в точке q (по скорости хода времени, поэтому не зависит от
-- того, к какой доле отнесён BPM в маркере)
local function tempo_at_qn(q)
  local dt = qn_to_time(q + TEMPO_DQ) - qn_to_time(q)
  if dt <= 0 then return 120 end
  return 60 * TEMPO_DQ / dt
end

local function log2_int(n)
  local k = 0
  while n > 1 do n = n // 2; k = k + 1 end
  return k
end

-- Мета-события темпа и размера в диапазоне [o_time, e_time] со сдвигом к o_qn
local function conductor_tempo(list, o_time, e_time, o_qn)
  local markers = {}
  for i = 0, reaper.CountTempoTimeSigMarkers(0) - 1 do
    local _, t, _, _, _, num, den, lin = reaper.GetTempoTimeSigMarker(0, i)
    markers[#markers + 1] = { t = t, num = num, den = den, lin = lin }
  end

  -- где мерить темп: начало, маркеры внутри диапазона и (при линейном переходе) каждая четверть
  local points, seen = { o_qn }, { [o_qn] = true }
  local function add_point(q)
    if not seen[q] then seen[q] = true; points[#points + 1] = q end
  end
  local e_qn = time_to_qn(e_time)
  for i, m in ipairs(markers) do
    if m.t > o_time and m.t <= e_time then add_point(time_to_qn(m.t)) end
    if m.lin then
      local nxt = markers[i + 1]
      local qa = math.max(time_to_qn(m.t), o_qn)
      local qb = math.min(nxt and time_to_qn(nxt.t) or e_qn, e_qn)
      local q, steps = math.floor(qa) + 1, 0
      while q < qb and steps < MAX_TEMPO_STEPS do
        add_point(q); q = q + 1; steps = steps + 1
      end
    end
  end
  table.sort(points)
  local prev_usec
  for _, q in ipairs(points) do
    local usec = math.min(0xFFFFFF, math.max(1, round(60000000 / tempo_at_qn(q))))
    if usec ~= prev_usec then
      add_event(list, round((q - o_qn) * OUT_PPQ), 1, meta(0x51, string.pack(">I3", usec)))
      prev_usec = usec
    end
  end

  -- размер такта: действующий в начале и изменения внутри диапазона
  local function sig_bytes(num, den)
    return meta(0x58, string.char(num, log2_int(den), 24, 8))
  end
  local num, den = reaper.TimeMap_GetTimeSigAtTime(0, o_time)
  local cur
  if num and den and num > 0 and den > 0 then
    add_event(list, 0, 0, sig_bytes(num, den))
    cur = num .. "/" .. den
  end
  for _, m in ipairs(markers) do
    if m.num and m.num > 0 and m.den and m.den > 0 and m.t > o_time and m.t <= e_time then
      local id = m.num .. "/" .. m.den
      if id ~= cur then
        add_event(list, round((time_to_qn(m.t) - o_qn) * OUT_PPQ), 0, sig_bytes(m.num, m.den))
        cur = id
      end
    end
  end
end

local function conductor_markers(list, o_time, e_time, o_qn)
  local _, nm, nr = reaper.CountProjectMarkers(0)
  for i = 0, (nm or 0) + (nr or 0) - 1 do
    local _, isrgn, pos, _, name = reaper.EnumProjectMarkers3(0, i)
    if not isrgn and pos >= o_time and pos <= e_time then
      add_event(list, round((time_to_qn(pos) - o_qn) * OUT_PPQ), 2, meta(0x06, name or ""))
    end
  end
end

----------------------------------------------------------------------
-- События MIDI-айтема
----------------------------------------------------------------------
-- Добавляет в list ноты и остальные канальные события айтема в его границах.
-- Возвращает число добавленных событий. Формат буфера MIDI_GetAllEvts:
-- { int32 смещение в тиках от прошлого события, байт флагов (&1 выделено,
-- &2 заглушено), int32 длина, байты сообщения }.
local function collect_item(item, take, o_qn, list)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  local ppq_start = reaper.MIDI_GetPPQPosFromProjTime(take, pos)
  local ppq_end = reaper.MIDI_GetPPQPosFromProjTime(take, pos + len)
  local q0 = time_to_qn(pos)
  local ppq_per_qn = reaper.MIDI_GetPPQPosFromProjQN(take, q0 + 1) - reaper.MIDI_GetPPQPosFromProjQN(take, q0)
  if ppq_per_qn <= 0 then return 0 end
  local function tick_of(ppq)
    return math.max(0, round(((q0 - o_qn) + (ppq - ppq_start) / ppq_per_qn) * OUT_PPQ))
  end

  local ok, buf = reaper.MIDI_GetAllEvts(take, "")
  if not ok or not buf then return 0 end

  local count, active = 0, {}
  local i, ppq = 1, 0
  while i + 8 <= #buf do
    local off, flag, mlen = string.unpack("<i4Bi4", buf, i)
    i = i + 9
    ppq = ppq + off
    local msg = buf:sub(i, i + mlen - 1)
    i = i + mlen
    local status = mlen >= 1 and msg:byte(1) or 0
    local kind = status & 0xF0
    if status >= 0x80 and status < 0xF0 and #msg >= 2 then
      local pass = not (cfg.skip_muted and (flag & 2) ~= 0) and not (cfg.only_sel and (flag & 1) == 0)
      local is_on = kind == 0x90 and #msg >= 3 and msg:byte(3) > 0
      local is_off = kind == 0x80 or (kind == 0x90 and not is_on)
      local id = (status & 0x0F) * 128 + (msg:byte(2) & 0x7F)
      if is_on then
        if pass and ppq >= ppq_start and ppq < ppq_end then
          add_event(list, tick_of(ppq), 2, msg)
          active[id] = (active[id] or 0) + 1
          count = count + 1
        end
      elseif is_off then
        if (active[id] or 0) > 0 and ppq >= ppq_start and ppq <= ppq_end then
          add_event(list, tick_of(ppq), 0, msg)
          active[id] = active[id] - 1
        end
      elseif pass and ppq >= ppq_start and ppq < ppq_end then
        add_event(list, tick_of(ppq), 1, msg)
        count = count + 1
      end
    end
  end
  -- ноты, не закончившиеся до конца айтема, обрываются на его границе
  for id, n in pairs(active) do
    for _ = 1, n do
      add_event(list, tick_of(ppq_end), 0, string.char(0x80 | (id // 128), id % 128, 0))
    end
  end
  return count
end

----------------------------------------------------------------------
-- Имена файлов
----------------------------------------------------------------------
local function sanitize(s)
  s = (s or ""):gsub('[<>:"/\\|%?%*%c]', "_")
  s = s:gsub("^[%s%.]+", ""):gsub("[%s%.]+$", "")
  local ok, off = pcall(utf8.offset, s, 81)
  if ok and off then s = s:sub(1, off - 1) end
  local up = s:upper()
  if up == "CON" or up == "PRN" or up == "AUX" or up == "NUL" or up:match("^COM%d$") or up:match("^LPT%d$") then
    s = "_" .. s
  end
  return s
end

local function join(dir, name)
  local last = dir:sub(-1)
  if last == "/" or last == "\\" then return dir .. name end
  return dir .. (IS_WIN and "\\" or "/") .. name
end

local function normalize_dir(dir)
  dir = dir:gsub("^%s+", ""):gsub("%s+$", "")
  if IS_WIN then dir = dir:gsub("/", "\\") end
  local trimmed = dir:gsub("[/\\]+$", "")
  if trimmed == "" then return dir end
  if trimmed:match("^%a:$") then return trimmed .. "\\" end
  return trimmed
end

-- Путь для файла с учётом политики. Возвращает путь или nil, если файл пропускается.
local function pick_path(folder, base, used)
  local n, name, path = 1, base, nil
  while true do
    name = n == 1 and base or string.format("%s (%d)", base, n)
    path = join(folder, name .. ".mid")
    if used[name:lower()] then
      n = n + 1
    elseif cfg.policy == "number" and reaper.file_exists(path) then
      n = n + 1
    else
      break
    end
  end
  if cfg.policy == "skip" and reaper.file_exists(path) then return nil end
  used[name:lower()] = true
  return path
end

----------------------------------------------------------------------
-- Список того, что экспортируется
----------------------------------------------------------------------
local entries, excluded = {}, {}
local scan_stats = { tracks_selected = 0, items_selected = 0 }
local status = ""

local function midi_take_of(item)
  local tk = reaper.GetActiveTake(item)
  if tk and reaper.TakeIsMIDI(tk) then return tk end
  return nil
end

local function note_count(take)
  local _, n = reaper.MIDI_CountEvts(take)
  return n or 0
end

local function scan_selection()
  local list = {}
  scan_stats.tracks_selected = reaper.CountSelectedTracks(0)
  scan_stats.items_selected = reaper.CountSelectedMediaItems(0)
  if cfg.mode == "tracks" then
    for i = 0, scan_stats.tracks_selected - 1 do
      local tr = reaper.GetSelectedTrack(0, i)
      local units, notes = {}, 0
      for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local it = reaper.GetTrackMediaItem(tr, j)
        local tk = midi_take_of(it)
        if tk then units[#units + 1] = { item = it, take = tk }; notes = notes + note_count(tk) end
      end
      if #units > 0 then
        local _, name = reaper.GetTrackName(tr)
        list[#list + 1] = {
          key = tostring(tr), file = sanitize(name), label = name, units = units,
          info = string.format("айтемов: %d, нот: %d", #units, notes),
        }
      end
    end
  else
    for i = 0, scan_stats.items_selected - 1 do
      local it = reaper.GetSelectedMediaItem(0, i)
      local tk = midi_take_of(it)
      if tk then
        local _, tname = reaper.GetTrackName(reaper.GetMediaItemTrack(it))
        local take_name = (reaper.GetTakeName(tk) or ""):gsub("%.[Mm][Ii][Dd][Ii]?$", "")
        local part = take_name ~= "" and take_name or string.format("%02d", #list + 1)
        local label = tname .. " - " .. part
        local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
        list[#list + 1] = {
          key = tostring(it), file = sanitize(label), label = label, units = { { item = it, take = tk } },
          info = string.format("нот: %d, длина: %d:%02d", note_count(tk), len // 60, round(len) % 60),
        }
      end
    end
  end
  entries = list
end

local function included()
  local list = {}
  for _, e in ipairs(entries) do if not excluded[e.key] then list[#list + 1] = e end end
  return list
end

----------------------------------------------------------------------
-- Экспорт
----------------------------------------------------------------------
-- Собирает содержимое файла для записи. Возвращает строку или nil, "причина".
local function build_file(entry)
  local o_time, e_time = math.huge, 0
  for _, u in ipairs(entry.units) do
    local p = reaper.GetMediaItemInfo_Value(u.item, "D_POSITION")
    local l = reaper.GetMediaItemInfo_Value(u.item, "D_LENGTH")
    o_time = math.min(o_time, p)
    e_time = math.max(e_time, p + l)
  end
  if not cfg.trim then o_time = 0 end
  local o_qn = time_to_qn(o_time)

  local music, count = {}, 0
  for _, u in ipairs(entry.units) do count = count + collect_item(u.item, u.take, o_qn, music) end
  if count == 0 then
    return nil, cfg.only_sel and "нет выделенных нот" or "нет нот"
  end
  add_event(music, 0, -1, meta(0x03, entry.label))

  local chunks = {}
  if cfg.tempo or cfg.markers then
    local cond = {}
    if cfg.tempo then conductor_tempo(cond, o_time, e_time, o_qn) end
    if cfg.markers then conductor_markers(cond, o_time, e_time, o_qn) end
    chunks[#chunks + 1] = build_track(cond, round((time_to_qn(e_time) - o_qn) * OUT_PPQ))
  end
  chunks[#chunks + 1] = build_track(music, round((time_to_qn(e_time) - o_qn) * OUT_PPQ))
  return build_smf(chunks)
end

local function open_folder(dir)
  if reaper.CF_ShellExecute then reaper.CF_ShellExecute(dir); return end
  if dir:find('"', 1, true) then return end
  local os_name = reaper.GetOS() or ""
  local cmd
  if os_name:find("^Win") then cmd = 'explorer.exe "' .. dir:gsub("/", "\\") .. '"'
  elseif os_name:find("^OSX") or os_name:find("^macOS") then cmd = '/usr/bin/open "' .. dir .. '"'
  else cmd = 'xdg-open "' .. dir .. '"' end
  reaper.ExecProcess(cmd, -1)
end

local function run_export()
  if cfg.folder == "" then status = "Сначала выберите папку."; return end
  local todo = included()
  if #todo == 0 then
    status = cfg.mode == "tracks" and "Выделите треки с MIDI." or "Выделите MIDI-айтемы."
    return
  end
  save_cfg()
  reaper.RecursiveCreateDirectory(cfg.folder, 0)
  local used, written, skipped, failed = {}, 0, {}, 0
  for _, e in ipairs(todo) do
    local data, why = build_file(e)
    if not data then
      skipped[#skipped + 1] = e.label .. " (" .. why .. ")"
    else
      local path = pick_path(cfg.folder, e.file ~= "" and e.file or "midi", used)
      if not path then
        skipped[#skipped + 1] = e.label .. " (файл уже есть)"
      else
        local f = io.open(path, "wb")
        if f then f:write(data); f:close(); written = written + 1 else failed = failed + 1 end
      end
    end
  end
  local msg = string.format("Создано файлов: %d в %s.", written, cfg.folder)
  if #skipped > 0 then msg = msg .. " Пропущено: " .. table.concat(skipped, "; ") .. "." end
  if failed > 0 then msg = msg .. string.format(" Не удалось записать: %d (проверьте папку).", failed) end
  status = msg
  if cfg.open_after and written > 0 then open_folder(cfg.folder) end
end

local function pick_folder()
  local dir
  if reaper.JS_Dialog_BrowseForFolder then
    local rv, folder = reaper.JS_Dialog_BrowseForFolder("Папка для MIDI-файлов", cfg.folder)
    if rv == 1 then dir = folder end
  else
    local ok, val = reaper.GetUserInputs("Папка для MIDI-файлов", 1, "Путь к папке,extrawidth=420", cfg.folder)
    if ok then dir = val end
  end
  if dir and dir:match("%S") then
    cfg.folder = normalize_dir(dir)
    save_cfg()
  end
end

----------------------------------------------------------------------
-- Отрисовка
----------------------------------------------------------------------
local last_cap, last_scan, scroll, sb_drag = 0, -1e9, 0, nil

local function set_color(c, a) gfx.set(c[1], c[2], c[3], a or 1) end

local function draw_text(str, x, y, c)
  set_color(c)
  gfx.x, gfx.y = x, y
  gfx.drawstr(str)
end

local function mouse_in(x, y, w, h)
  local mx, my = gfx.mouse_x, gfx.mouse_y
  return mx >= x and mx < x + w and my >= y and my < y + h
end

local function clip_tail(str, max_w)
  if gfx.measurestr(str) <= max_w then return str end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, 2)
    if not ok or not off then off = 2 end
    s = s:sub(off)
    if gfx.measurestr("…" .. s) <= max_w then return "…" .. s end
  end
  return "…"
end

local function clip_head(str, max_w)
  if gfx.measurestr(str) <= max_w then return str end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, -1)
    if not ok or not off then off = #s end
    s = s:sub(1, off - 1)
    if gfx.measurestr(s .. "…") <= max_w then return s .. "…" end
  end
  return "…"
end

local function draw_button(x, y, w, h, label, enabled, click, color, fsize)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = (not enabled) and col.btn_off or (hov and col.btn_hover or (color or col.btn))
  set_color(c); gfx.rect(x, y, w, h, 1)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  local size = fsize or F_BTN
  gfx.setfont(1, "Arial", size)
  while size > 12 and gfx.measurestr(label) > w - 12 do
    size = size - 1
    gfx.setfont(1, "Arial", size)
  end
  draw_text(label, x + (w - gfx.measurestr(label)) / 2, y + (h - size) / 2 - 1, enabled and col.text or col.dim)
  return hov and click
end

local function draw_checkbox(x, y, checked)
  set_color(checked and col.accent or col.bg); gfx.rect(x, y, CB, CB, 1)
  set_color(col.border); gfx.rect(x, y, CB, CB, 0)
  if checked then
    gfx.setfont(1, "Arial", F_ROW)
    draw_text("✓", x + 3, y, col.text)
  end
end

-- Галочка с подписью; клик по подписи тоже переключает
local function check_row(x, y, w, label, checked, click)
  draw_checkbox(x, y + 4, checked)
  gfx.setfont(1, "Arial", F_ROW)
  draw_text(clip_head(label, w - CB - 14), x + CB + 10, y + 5, col.text)
  return click and mouse_in(x, y, w, 28)
end

local OPTIONS = {
  { key = "tempo", label = "Вшить темп и размер такта", col = 1, row = 1 },
  { key = "markers", label = "Вшить маркеры проекта", col = 1, row = 2 },
  { key = "only_sel", label = "Только выделенные ноты", col = 1, row = 3 },
  { key = "skip_muted", label = "Пропускать замьюченные события", col = 2, row = 1 },
  { key = "trim", label = "Начать с нуля (обрезать пустоту в начале)", col = 2, row = 2 },
  { key = "open_after", label = "Открыть папку после экспорта", col = 2, row = 3 },
}

local function draw()
  local w, h = gfx.w, gfx.h
  local cap = gfx.mouse_cap
  local down = (cap & 1) == 1
  local click = down and (last_cap & 1) == 0
  last_cap = cap

  local now = reaper.time_precise()
  if now - last_scan >= SCAN_EVERY then
    last_scan = now
    scan_selection()
  end

  local foot_y = h - FOOT_H
  local list_h = math.max(40, foot_y - LIST_Y)
  local half = math.floor((w - 32) / 2)

  set_color(col.bg); gfx.rect(0, 0, w, h, 1)

  gfx.setfont(1, "Arial", F_TITLE)
  draw_text("Экспорт MIDI в отдельные файлы", 16, 10, col.text)
  gfx.setfont(1, "Arial", F_SMALL)
  draw_text("Выделите в проекте треки или MIDI-айтемы - каждый уйдёт в свой .mid файл. Проект не меняется.",
    16, 40, col.dim)

  -- что экспортировать
  local changed_mode
  if check_row(16, Y_MODE, half - 8, "Выделенные треки (с MIDI)", cfg.mode == "tracks", click) then changed_mode = "tracks" end
  if check_row(16 + half, Y_MODE, half, "Выделенные MIDI-айтемы", cfg.mode == "items", click) then changed_mode = "items" end
  if changed_mode and changed_mode ~= cfg.mode then
    cfg.mode = changed_mode
    save_cfg()
    scan_selection()
    scroll = 0
  end

  -- галочки-параметры
  for _, o in ipairs(OPTIONS) do
    local x = o.col == 1 and 16 or 16 + half
    if check_row(x, Y_OPT[o.row], half - 8, o.label, cfg[o.key], click) then
      cfg[o.key] = not cfg[o.key]
      save_cfg()
    end
  end

  -- папка назначения
  local btn_w = 130
  gfx.setfont(1, "Arial", F_SMALL)
  draw_text("Папка:", 16, Y_FOLDER + (FOLDER_H - F_SMALL) / 2 - 1, col.dim)
  local fx, fw = 70, w - 70 - 16 - btn_w - 8
  set_color(col.bg); gfx.rect(fx, Y_FOLDER, fw, FOLDER_H, 1)
  set_color(cfg.folder == "" and col.danger or col.border); gfx.rect(fx, Y_FOLDER, fw, FOLDER_H, 0)
  gfx.setfont(1, "Arial", F_ROW)
  if cfg.folder == "" then
    draw_text("не выбрана - нажмите «Выбрать…»", fx + 8, Y_FOLDER + (FOLDER_H - F_ROW) / 2 - 1, col.dim)
  else
    draw_text(clip_tail(cfg.folder, fw - 16), fx + 8, Y_FOLDER + (FOLDER_H - F_ROW) / 2 - 1, col.text)
  end
  local act_pick = draw_button(w - 16 - btn_w, Y_FOLDER, btn_w, FOLDER_H, "Выбрать…", true, click, nil, F_SMALL)
  if click and mouse_in(fx, Y_FOLDER, fw, FOLDER_H) then act_pick = true end

  -- если файл уже существует
  gfx.setfont(1, "Arial", F_SMALL)
  draw_text("Если файл с таким именем уже есть:", 16, Y_POLICY + 6, col.dim)
  local policy_label = ""
  for _, p in ipairs(POLICIES) do if p.key == cfg.policy then policy_label = p.label end end
  local act_policy = draw_button(16 + 260, Y_POLICY, 200, 28, policy_label, true, click, nil, F_SMALL)

  -- список
  local todo = included()
  gfx.setfont(1, "Arial", F_ROW)
  draw_text(string.format("Будет создано файлов: %d", #todo), 16, Y_LIST_HEAD, col.text)
  gfx.setfont(1, "Arial", F_SMALL)
  local sel_note
  if cfg.mode == "tracks" then
    sel_note = string.format("выделено треков: %d, с MIDI: %d", scan_stats.tracks_selected, #entries)
  else
    sel_note = string.format("выделено айтемов: %d, MIDI: %d", scan_stats.items_selected, #entries)
  end
  draw_text(sel_note, w - 16 - gfx.measurestr(sel_note), Y_LIST_HEAD + 2, col.dim)

  local total_h = #entries * ROW_H
  local max_scroll = math.max(0, total_h - list_h)
  if gfx.mouse_wheel ~= 0 then
    scroll = scroll - (gfx.mouse_wheel / 120) * ROW_H * 3
    gfx.mouse_wheel = 0
  end
  scroll = math.max(0, math.min(scroll, max_scroll))

  -- полоса прокрутки: ползунок тянется мышью, клик по дорожке переносит его
  local thumb_h, thumb_y = 0, LIST_Y
  if max_scroll > 0 then
    thumb_h = math.max(24, list_h * list_h / total_h)
    local travel = list_h - thumb_h
    thumb_y = LIST_Y + travel * (scroll / max_scroll)
    if sb_drag then
      if down then
        thumb_y = math.max(LIST_Y, math.min(gfx.mouse_y - sb_drag, LIST_Y + travel))
        scroll = (thumb_y - LIST_Y) / travel * max_scroll
      else
        sb_drag = nil
      end
    elseif click and gfx.mouse_x >= w - 14 and gfx.mouse_y >= LIST_Y and gfx.mouse_y < LIST_Y + list_h then
      if gfx.mouse_y < thumb_y or gfx.mouse_y > thumb_y + thumb_h then
        thumb_y = math.max(LIST_Y, math.min(gfx.mouse_y - thumb_h / 2, LIST_Y + travel))
        scroll = (thumb_y - LIST_Y) / travel * max_scroll
      end
      sb_drag = gfx.mouse_y - thumb_y
    end
  else
    sb_drag = nil
  end

  set_color(col.panel); gfx.rect(0, LIST_Y - 2, w, list_h + 2, 1)
  local toggle_key
  gfx.setfont(1, "Arial", F_ROW)
  for i, e in ipairs(entries) do
    local ry = LIST_Y + (i - 1) * ROW_H - scroll
    if ry + ROW_H > LIST_Y and ry < LIST_Y + list_h then
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(0, ry, w, ROW_H, 1) end
      local on = not excluded[e.key]
      if mouse_in(0, ry, w - 14, ROW_H) and gfx.mouse_y >= LIST_Y and gfx.mouse_y < LIST_Y + list_h then
        set_color(col.btn); gfx.rect(0, ry, w, ROW_H, 1)
        if click then toggle_key = e.key end
      end
      draw_checkbox(16, ry + (ROW_H - CB) / 2, on)
      gfx.setfont(1, "Arial", F_SMALL)
      local info_w = gfx.measurestr(e.info)
      draw_text(e.info, w - 26 - info_w, ry + (ROW_H - F_SMALL) / 2, col.dim)
      gfx.setfont(1, "Arial", F_ROW)
      local shown = e.file ~= "" and e.file or "midi"
      draw_text(clip_head(shown .. ".mid", w - 60 - 26 - info_w - 16), 50, ry + (ROW_H - F_ROW) / 2 - 1,
        on and col.text or col.dim)
    end
  end
  if #entries == 0 then
    gfx.setfont(1, "Arial", F_SMALL)
    draw_text(cfg.mode == "tracks" and "Выделите в проекте треки, на которых есть MIDI-айтемы."
      or "Выделите в проекте MIDI-айтемы.", 16, LIST_Y + 12, col.dim)
  end
  if max_scroll > 0 then
    local hot = sb_drag ~= nil or mouse_in(w - 14, thumb_y, 14, thumb_h)
    set_color(sb_drag and col.accent or (hot and col.dim or col.border))
    gfx.rect(w - 11, thumb_y, 8, thumb_h, 1)
  end

  -- подвал
  set_color(col.panel); gfx.rect(0, foot_y, w, FOOT_H, 1)
  set_color(col.border); gfx.rect(0, foot_y, w, 1, 1)
  gfx.setfont(1, "Arial", F_SMALL)
  draw_text(clip_tail(status, w - 32), 16, foot_y + 12, col.dim)
  local bw, bh, by = (w - 32 - 10) / 2, 44, foot_y + 48
  local can = cfg.folder ~= "" and #todo > 0
  local act_export = draw_button(16, by, bw, bh, string.format("Экспортировать (%d)", #todo), can, click, col.accent)
  local act_close = draw_button(16 + bw + 10, by, bw, bh, "Закрыть", true, click)

  if toggle_key then
    excluded[toggle_key] = not excluded[toggle_key] or nil
  elseif act_pick then
    pick_folder()
  elseif act_policy then
    for i, p in ipairs(POLICIES) do
      if p.key == cfg.policy then cfg.policy = POLICIES[i % #POLICIES + 1].key; break end
    end
    save_cfg()
  elseif act_export then
    run_export()
  elseif act_close then
    return "close"
  end
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
local saved_w, saved_h = WIN_W, WIN_H
do
  local sw, sh = tonumber(reaper.GetExtState(EXT_SECTION, "win_w")), tonumber(reaper.GetExtState(EXT_SECTION, "win_h"))
  if sw and sh and sw >= MIN_W and sh >= MIN_H and sw <= 5000 and sh <= 4000 then saved_w, saved_h = sw, sh end
end
gfx.init(TITLE, saved_w, saved_h)

local function loop()
  for _ = 1, 64 do
    local ch = gfx.getchar()
    if ch < 0 then gfx.quit(); return end
    if ch == 0 then break end
    if ch == 27 then gfx.quit(); return end
    if ch == 13 then run_export() end
  end
  if (gfx.w ~= saved_w or gfx.h ~= saved_h) and gfx.w >= MIN_W and gfx.h >= MIN_H then
    saved_w, saved_h = gfx.w, gfx.h
    reaper.SetExtState(EXT_SECTION, "win_w", tostring(math.floor(saved_w)), true)
    reaper.SetExtState(EXT_SECTION, "win_h", tostring(math.floor(saved_h)), true)
  end
  if draw() == "close" then gfx.quit(); return end
  gfx.update()
  reaper.defer(loop)
end
loop()
