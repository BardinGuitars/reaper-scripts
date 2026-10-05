-- @description SSM_AI_Drummer
-- @version 1.6
-- @author @ssm_metalmix
-- @about
--   🥁 Барабанная MIDI-партия под гитарный DI-риф: нейросеть или словарь тактов барабанщика.
--   Выделите в проекте item с DI-рифом -> окно берёт точный темп, размер и сильную долю из проекта
--   (в начале item) -> «Сгенерировать MIDI-партию» -> под треком рифа появляется новый трек
--   с MIDI-item той же длины (GM или карта нужного плагина барабанов). Вкладка «Конвертер карт» переводит
--   выделенные MIDI-item из одной карты барабанов в другую.
--   Скрипт - только окно: партию сочиняет движок AI Drummer (Python), ноты рифа находит модуль детектора
--   SSM_DI_Detector. Движок и модуль не публикуются: без них скрипт не работает (путь к движку - кнопка «Путь…»).
-- @changelog
--   1.6 Гуманизация: тайминг High 1.4 (как у живых барабанщиков; было 1.0). ИИ: ползунок «Бочка: как у барабанщика ->
--   за рифом» (слева - как раньше). Если папку движка перенесли или
--   переименовали, окно находит движок само.
--   1.5 Вкладка «Конвертер карт»: выделенные MIDI-item переводятся из одной карты барабанов в другую
--   (GM / Toontrack / GGD OKW / GGD Invasion / Ultimate Heavy). Левая нога бочки - на полтона ниже правой там, где
--   карта это поддерживает. «Карта барабанов на выходе»: + GGD Invasion.
--   1.4 «Самые короткие ноты: Авто» (по умолчанию): движок сам определяет по записи 1/8, 1/8T, 1/16 или 1/32.
--   1.3 ИИ: кнопки «Тарелка», «Дабл-бочка», «Малый» (Авто или выбор).
--   1.2 Барабанщик «Общий» (ИИ без стиля конкретного барабанщика). «Смелость ИИ»: слева предсказуемо, справа смело.
--   1.1 «Движок»: Словарь (такты барабанщика) или ИИ (нейросеть сочиняет такт за тактом).
--   1.0 Гуманизация: отдельные уровни «Сила удара» и «Тайминг» (Light / Normal / High / Ultra).
--   0.9 Барабанщик Architects и галочка «Упор на альбом».
--   0.8 Выбор барабанщика: Sleep Token или System of a Down. Имя барабанщика - в имени трека и в статусе.
--   0.7 «Часть песни»: Авто / Вся песня (регионы) / Интро / Куплет / Предприпев / Припев / Бридж / Брейкдаун /
--   Проигрыш / Аутро.
--   0.6 Окно в две колонки. «Разнообразие», «Подчеркнуть стиль»; риф сравнивается и по высоте нот.
--   0.5 Ползунок «Бочка: как у барабанщика / под риф», «Художественные сбивки», выбор карты барабанов на выходе.
--   0.4 Составной такт: грув - от барабанщика, бочка - под риф.
--   0.3 Движок запускается без окна терминала; журнал движка - внизу окна.
--   0.2 Части песни из регионов проекта; тишина в начале и конце рифа - без барабанов; кнопка «Другой вариант».
--   0.1 Первая версия: размер нот, триоли (авто/прямые/триоли), гуманизация, одинаковая сила удара.

----------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------
local SCRIPT_TITLE = "SSM AI Drummer"
local EXT_SECTION = "SSM_AI_Drummer"
local DEFAULT_ENGINE = [[C:\DrummerProject\Code\metal-drum-composer\generate.py]]
local DEFAULT_PYTHON = "pythonw" -- pythonw: без консольного окна (python.exe мелькал терминалом)
local WIN_W, WIN_H = 1180, 850
local HEADER_H = 48
local MIDI_CHANNEL = 9 -- канал 10 (с нуля - 9): барабаны GM

-- «Самые короткие ноты в рифе» - как в SSM_DI_Guitar_Align (мин. пауза детектора = 70% длительности)
local SHORTEST_NOTES = {
  { label = "1/8", key = "1/8" },
  { label = "1/8T", key = "1/8T" },
  { label = "1/16", key = "1/16" },
  { label = "1/32 тремоло", key = "1/32" },
  { label = "Авто", key = "auto" },
}
local SHORTEST_DEFAULT = 5
local DRUM_MAPS = {
  { label = "GM", key = "gm" },
  { label = "Toontrack", key = "toontrack" },
  { label = "GGD (OKW)", key = "ggd_okw" },
  { label = "Ultimate Heavy", key = "ultimate_heavy" },
  { label = "GGD Invasion", key = "ggd_invasion" },   -- в конце: номера прежних кнопок в настройках не сдвигаются
}
-- конвертер карт (вкладка «Конвертер карт»): из какой карты в какую переводить выделенные MIDI-item. Ключи -- карты
-- хьюманизера (humanize.NOTE_MAPS); соответствие нот -- его convert_map, как в боте (/convert_map)
local CONVERT_MAPS = {
  { label = "GM", key = "gm" },
  { label = "Toontrack", key = "toontrack" },
  { label = "GGD (OKW)", key = "ggd_okw" },
  { label = "GGD Invasion", key = "ggd_invasion" },
  { label = "Ultimate Heavy", key = "ultimate_heavy" },
}
local VIEWS = { { label = "Партия", key = "drummer" }, { label = "Конвертер карт", key = "convert" } }
-- движок: словарь тактов барабанщика или нейросеть (ai/ в движке)
local ENGINES = {
  { label = "Словарь", key = "dictionary" },
  { label = "ИИ (нейросеть)", key = "ai" },
}
-- ИИ: версия модели (D:\DrummerData\runs\<key>\best.pt) -- для сравнения на слух
local AI_MODELS = { { label = "v5", key = "v5" }, { label = "v7 (металкор)", key = "v7" },
  { label = "v8 (+32-е)", key = "v8" },     -- v8: сетка 1/24 (32-е ноты), стиль Architects на 88 песнях
  { label = "v9 (Сирл)", key = "v9" } }     -- v9: как v8, но стиль Architects -- только песни Дэна Сирла (3 альбома)
-- ИИ: управляющие метки (ai/tokens2.CONTROL_VALUES в движке)
local AI_CYM = { { label = "Авто", key = "auto" }, { label = "Нет", key = "none" }, { label = "Хэт", key = "hh" },
  { label = "Райд", key = "ride" }, { label = "Крэш", key = "crash" }, { label = "Чайна", key = "china" } }
local AI_DK = { { label = "Авто", key = "auto" }, { label = "Нет", key = "0" }, { label = "Вставки", key = "1" },
  { label = "Сплошная", key = "2" } }
local AI_SN = { { label = "Авто", key = "auto" }, { label = "Половинный", key = "half" }, { label = "Обычный", key = "back" },
  { label = "Плотный", key = "busy" } }
-- чей стиль: словарь, параметры и модель бочки своего барабанщика (движок: поле задания drummer)
local DRUMMERS = {
  { label = "Sleep Token", key = "sleep_token" },
  { label = "System of a Down", key = "soad" },
  { label = "Architects", key = "architects", focus = "The Sky, the Earth & All Between" },
  { label = "Общий (ИИ)", key = "general" },
}
-- часть песни: auto - не учитывать; song - регионы проекта; остальное - весь item одна такая часть
local PART_MODES = {
  { label = "Авто", key = "auto" },
  { label = "Вся песня", key = "song" },
  { label = "Интро", key = "intro", low = "интро" },
  { label = "Куплет", key = "verse", low = "куплет" },
  { label = "Предприпев", key = "prechorus", low = "предприпев" },
  { label = "Припев", key = "chorus", low = "припев" },
  { label = "Бридж", key = "bridge", low = "бридж" },
  { label = "Брейкдаун", key = "breakdown", low = "брейкдаун" },
  { label = "Проигрыш", key = "interlude", low = "проигрыш" },
  { label = "Аутро", key = "outro", low = "аутро" },
}
-- уровни гуманизации -- как в боте SSM (humanize_bot.py: VELOCITY_LEVELS / TIMING_LEVELS)
local HUM_VEL_LEVELS = {
  { label = "Light", key = 0.2 }, { label = "Normal", key = 0.3 }, { label = "High", key = 0.8 }, { label = "Ultra", key = 1.0 },
}
-- тайминг: High 1.4 -- уровень живых игроков (исследование хьюманизера, 05.10.2026: паки GGD, 5 игроков; на 1.0 разброс
-- на четверть меньше живого), Ultra 2.0 -- шире любого из них. Движок принимает до 2.0. Те же числа -- в боте (TIMING_LEVELS)
local HUM_TIME_LEVELS = {
  { label = "Light", key = 0.2 }, { label = "Normal", key = 0.5 }, { label = "High", key = 1.4 }, { label = "Ultra", key = 2.0 },
}
local TRIPLET_MODES = {
  { label = "Авто", key = "auto" },
  { label = "Прямые", key = "off" },
  { label = "Триоли", key = "on" },
}

----------------------------------------------------------------------
-- SETTINGS (ExtState)
----------------------------------------------------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function load_str(key, default)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == nil or v == "" then return default end
  return v
end

local function load_num(key, default)
  return tonumber(load_str(key, "")) or default
end

local S = {
  engine = load_str("engine", DEFAULT_ENGINE),
  python = load_str("python", DEFAULT_PYTHON),
  shortest_idx = clamp(math.floor(load_num("shortest_idx", SHORTEST_DEFAULT)), 1, #SHORTEST_NOTES),
  triplet_idx = clamp(math.floor(load_num("triplet_idx", 1)), 1, #TRIPLET_MODES),
  humanize = load_num("humanize", 0) == 1,
  hum_vel_idx = clamp(math.floor(load_num("hum_vel_idx", 2)), 1, 4),
  hum_time_idx = clamp(math.floor(load_num("hum_time_idx", 2)), 1, 4),
  vel_const = load_num("vel_const", 1) == 1,
  vel_value = clamp(math.floor(load_num("vel_value", 118)), 1, 127),
  fill_silence = load_num("fill_silence", 0) == 1,
  bar_from_riff = load_num("bar_from_riff", 0) == 1,
  kick_blend = clamp(load_num("kick_blend", 0.5), 0, 1),
  fills = load_num("fills", 0) == 1,
  diversity = clamp(load_num("diversity", 0), 0, 1),
  style = load_num("style", 0) == 1,
  map_idx = clamp(math.floor(load_num("map_idx", 1)), 1, #DRUM_MAPS),
  part_idx = clamp(math.floor(load_num("part_idx", 1)), 1, 10),
  drummer_idx = clamp(math.floor(load_num("drummer_idx", 1)), 1, 4),
  -- ключ ai_temp2: прежнее умолчание 0.90 (ключ ai_temp) делало партии однообразными - новое умолчание 1.00
  ai_temp = clamp(load_num("ai_temp2", 1.0), 0.3, 1.3),
  -- ИИ: «Бочка: как у барабанщика -> за рифом», 0..1; слева (0) -- как обучена модель (движок: ai_kick_follow). Левее
  -- нуля не делаем: замер 05.10.2026 -- отрицательные значения уводят бочку с нот рифа (39% ударов на рифе вместо 83%)
  ai_kick = clamp(load_num("ai_kick", 0), 0, 1),
  ai_cym_idx = clamp(math.floor(load_num("ai_cym_idx", 1)), 1, 6),
  ai_model_idx = clamp(math.floor(load_num("ai_model_idx", 2)), 1, #AI_MODELS), -- по умолчанию v7 (на слух лучше v5)
  ai_dk_idx = clamp(math.floor(load_num("ai_dk_idx", 1)), 1, 4),
  ai_sn_idx = clamp(math.floor(load_num("ai_sn_idx", 1)), 1, 4),
  engine_idx = clamp(math.floor(load_num("engine_idx", 1)), 1, 2),
  focus = load_num("focus", 1) == 1,
  follow = clamp(load_num("follow", 0.5), 0, 1),
  view_idx = clamp(math.floor(load_num("view_idx", 1)), 1, #VIEWS),
  conv_from_idx = clamp(math.floor(load_num("conv_from_idx", 2)), 1, #CONVERT_MAPS),
  conv_to_idx = clamp(math.floor(load_num("conv_to_idx", 1)), 1, #CONVERT_MAPS),
  win_x = load_num("win_x", 200),
  win_y = load_num("win_y", 150),
  -- размер окна запоминается (пользователь растягивает окно под свой экран)
  win_w = clamp(math.floor(load_num("win_w", WIN_W)), 700, 6000),
  win_h = clamp(math.floor(load_num("win_h", WIN_H)), 500, 4000),
}

-- прежнее значение по умолчанию "python" открывало консольное окно -> заменяем на pythonw
if S.python == "python" then S.python = DEFAULT_PYTHON end

local function save_settings()
  local function put(k, v) reaper.SetExtState(EXT_SECTION, k, tostring(v), true) end
  put("engine", S.engine)
  put("python", S.python)
  put("shortest_idx", S.shortest_idx)
  put("triplet_idx", S.triplet_idx)
  put("humanize", S.humanize and 1 or 0)
  put("hum_vel_idx", S.hum_vel_idx)
  put("hum_time_idx", S.hum_time_idx)
  put("vel_const", S.vel_const and 1 or 0)
  put("vel_value", S.vel_value)
  put("fill_silence", S.fill_silence and 1 or 0)
  put("bar_from_riff", S.bar_from_riff and 1 or 0)
  put("kick_blend", string.format("%.2f", S.kick_blend))
  put("fills", S.fills and 1 or 0)
  put("diversity", string.format("%.2f", S.diversity))
  put("style", S.style and 1 or 0)
  put("map_idx", S.map_idx)
  put("part_idx", S.part_idx)
  put("drummer_idx", S.drummer_idx)
  put("ai_temp2", string.format("%.2f", S.ai_temp))
  put("ai_kick", string.format("%.2f", S.ai_kick))
  put("ai_cym_idx", S.ai_cym_idx)
  put("ai_model_idx", S.ai_model_idx)
  put("ai_dk_idx", S.ai_dk_idx)
  put("ai_sn_idx", S.ai_sn_idx)
  put("engine_idx", S.engine_idx)
  put("focus", S.focus and 1 or 0)
  put("follow", string.format("%.2f", S.follow))
  put("view_idx", S.view_idx)
  put("conv_from_idx", S.conv_from_idx)
  put("conv_to_idx", S.conv_to_idx)
  put("win_x", math.floor(S.win_x))
  put("win_y", math.floor(S.win_y))
  put("win_w", math.floor(S.win_w))
  put("win_h", math.floor(S.win_h))
end

----------------------------------------------------------------------
-- МАЛЕНЬКИЙ JSON (запись задания и чтение ответа движка)
----------------------------------------------------------------------
local function json_str(s)
  s = tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
  return '"' .. s .. '"'
end

local function json_encode(v)
  local t = type(v)
  if v == nil then return "null" end
  if t == "boolean" then return v and "true" or "false" end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "null" end
    if math.type and math.type(v) == "integer" then return tostring(v) end
    return string.format("%.9g", v)
  end
  if t == "string" then return json_str(v) end
  if t == "table" then
    if #v > 0 or next(v) == nil and v.__array then
      local parts = {}
      for i = 1, #v do parts[#parts + 1] = json_encode(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    end
    local keys = {}
    for k in pairs(v) do if k ~= "__array" then keys[#keys + 1] = k end end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = json_str(k) .. ":" .. json_encode(v[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
  end
  return "null"
end

-- минимальный разбор JSON (объекты, массивы, строки с \-экранированием, числа, true/false/null)
local function json_decode(s)
  local pos = 1
  local function ws() pos = s:find("[^ \t\r\n]", pos) or (#s + 1) end
  local parse
  local function str()
    local out = {}
    pos = pos + 1
    while true do
      local c = s:sub(pos, pos)
      if c == "" then error("JSON: незакрытая строка") end
      if c == '"' then pos = pos + 1; break end
      if c == "\\" then
        local n = s:sub(pos + 1, pos + 1)
        local map = { n = "\n", r = "\r", t = "\t", b = "\b", f = "\f", ["/"] = "/", ["\\"] = "\\", ['"'] = '"' }
        if n == "u" then
          local code = tonumber(s:sub(pos + 2, pos + 5), 16) or 63
          if utf8 and utf8.char then out[#out + 1] = utf8.char(code) else out[#out + 1] = "?" end
          pos = pos + 6
        else
          out[#out + 1] = map[n] or n
          pos = pos + 2
        end
      else
        out[#out + 1] = c
        pos = pos + 1
      end
    end
    return table.concat(out)
  end
  parse = function()
    ws()
    local c = s:sub(pos, pos)
    if c == "{" then
      local obj = {}
      pos = pos + 1; ws()
      if s:sub(pos, pos) == "}" then pos = pos + 1; return obj end
      while true do
        ws()
        local k = str(); ws()
        pos = pos + 1 -- ':'
        obj[k] = parse(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "}" then return obj end
      end
    elseif c == "[" then
      local arr = {}
      pos = pos + 1; ws()
      if s:sub(pos, pos) == "]" then pos = pos + 1; return arr end
      while true do
        arr[#arr + 1] = parse(); ws()
        local d = s:sub(pos, pos); pos = pos + 1
        if d == "]" then return arr end
      end
    elseif c == '"' then
      return str()
    elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4; return true
    elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5; return false
    elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4; return nil
    else
      local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
      if not num or num == "" then error("JSON: неожиданный символ на позиции " .. pos) end
      pos = pos + #num
      return tonumber(num)
    end
  end
  return parse()
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function write_file(path, text)
  local f = assert(io.open(path, "wb"))
  f:write(text)
  f:close()
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

----------------------------------------------------------------------
-- ПРОЕКТ: выбранный item, темп/размер/сильная доля
----------------------------------------------------------------------
local function fmt_time(sec)
  return string.format("%d:%04.1f", math.floor(sec / 60), sec % 60)
end

-- Сведения о выбранном item для задания. Возвращает info или nil, текст ошибки.
local function get_selected_item_info()
  local n = reaper.CountSelectedMediaItems(0)
  if n ~= 1 then return nil, "Выберите один аудио item с DI-рифом." end
  local item = reaper.GetSelectedMediaItem(0, 0)
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return nil, "Выбранный item - не аудио." end
  local src = reaper.GetMediaItemTake_Source(take)
  local file = reaper.GetMediaSourceFileName(src, "")
  if not file or file == "" then return nil, "Не удалось получить файл источника item." end
  local track = reaper.GetMediaItem_Track(item)
  local _, track_name = reaper.GetTrackName(track)
  local info = {
    item = item, take = take, track = track, file = file, track_name = track_name,
    take_name = reaper.GetTakeName(take),
    pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
    len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
    offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
    rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
  }
  -- темп и размер в начале item
  local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(0, info.pos)
  info.num, info.den, info.bpm = num, den, bpm
  -- сильная доля: начало такта, в котором начинается item (может быть раньше item -> отрицательная)
  local _, measures = reaper.TimeMap2_timeToBeats(0, info.pos)
  local bar_start = reaper.TimeMap2_beatsToTime(0, 0, measures)
  info.first_downbeat = bar_start - info.pos
  -- смена темпа/размера внутри item -> предупреждение (v0.1 берёт темп в начале item)
  info.tempo_change = false
  for i = 0, reaper.CountTempoTimeSigMarkers(0) - 1 do
    local _, tpos = reaper.GetTempoTimeSigMarker(0, i)
    if tpos > info.pos + 1e-6 and tpos < info.pos + info.len - 1e-6 then info.tempo_change = true end
  end
  -- регионы проекта, пересекающие item -> части песни (время от начала item)
  info.sections = {}
  local total = reaper.CountProjectMarkers(0)   -- число маркеров + регионов
  for i = 0, total - 1 do
    local _, isrgn, rpos, rend, rname = reaper.EnumProjectMarkers3(0, i)
    if isrgn and rend > info.pos + 1e-6 and rpos < info.pos + info.len - 1e-6 then
      info.sections[#info.sections + 1] = { start = rpos - info.pos, ["end"] = rend - info.pos, name = rname or "" }
    end
  end
  table.sort(info.sections, function(a, b) return a.start < b.start end)
  if math.abs(info.rate - 1) > 1e-9 then
    return nil, string.format("Скорость воспроизведения item %.3f - поддерживается только 1.0.", info.rate)
  end
  return info
end

----------------------------------------------------------------------
-- ДВИЖОК: задание -> фоновый запуск -> ответ
----------------------------------------------------------------------
local job = nil          -- текущая генерация: { dir, started, info, variant, replace }
local last_status = nil  -- { kind = "ok"|"error"|"info", text = ... }
local last_gen = nil     -- прошлая генерация: { item, track, midi_item, created_track, variant } -- для «Другой вариант»
local last_log = nil     -- журнал движка: { path, lines }

-- Папка заданий и их журналов (job.json, log.txt, ноты): рядом с движком, в <движок>/out/reaper_jobs. Не во
-- временной папке системы: её чистят (журналы прослушанных генераций пропадали в тот же день), а по ним разбираются
-- замечания к партиям. Если папки движка нет - в папке ресурсов REAPER. Тесты задают свою (SSM_AI_DRUMMER_JOB_ROOT).
local function job_root()
  if SSM_AI_DRUMMER_JOB_ROOT then return SSM_AI_DRUMMER_JOB_ROOT end
  local dir = tostring(S.engine or ""):gsub("\\", "/"):match("^(.*)/[^/]*$")
  if dir and dir ~= "" then return dir .. "/out/reaper_jobs" end
  return (reaper.GetResourcePath():gsub("\\", "/")) .. "/SSM_AI_Drummer"
end

-- Корень DrummerProject (переносимая папка всех проектов, правило -- <корень>\_workspace\PORTABLE.md): папка, где лежит
-- _workspace\paths.json. REAPER запускает КОПИЮ скрипта из %APPDATA%\REAPER\Scripts\SSM -- от места скрипта корень не найти.
-- Поэтому: путь к движку (кнопка «Путь…») -> вверх от generate.py до папки с _workspace\paths.json; найденный корень
-- записывается в общую настройку REAPER (ExtState SSM_DrummerProject/root) -- её читают и другие скрипты SSM (выравниватель).
-- Нет движка на месте -> записанный корень -> переменная SSM_ROOT -> прежнее место C:\DrummerProject.
local ROOT_SECTION, ROOT_DEFAULT = "SSM_DrummerProject", [[C:\DrummerProject]]
local function root_from(path)
  local d = tostring(path or ""):gsub("/", "\\"):match("^(.*)\\[^\\]*$")
  while d and d ~= "" do
    if file_exists(d .. "\\_workspace\\paths.json") then return d end
    d = d:match("^(.*)\\[^\\]*$")
  end
  return nil
end
local function project_root()
  local r = root_from(S.engine)
  if r then
    if reaper.GetExtState(ROOT_SECTION, "root") ~= r then reaper.SetExtState(ROOT_SECTION, "root", r, true) end
    return r
  end
  local saved = reaper.GetExtState(ROOT_SECTION, "root")
  if saved ~= "" then return saved end
  local env = os.getenv("SSM_ROOT")
  return (env and env ~= "") and env or ROOT_DEFAULT
end
-- движка по сохранённому пути нет (корень перенесли или переименовали), а в известном корне он есть -> берём оттуда
local function engine_path()
  if file_exists(S.engine) then return S.engine end
  local r = project_root()
  local cand = r .. [[\Code\metal-drum-composer\generate.py]]
  if file_exists(cand) then S.engine = cand; save_settings() end
  return S.engine
end

-- Кэш разбора рифов: его ведёт мост детектора нот (tools\di_detector\cli.lua); там же записи кэша SSM_DI_Guitar_Align --
-- имена на «r». Кнопка «Кэш…» открывает папку -- что удалять, решает пользователь (удалённое просто посчитается заново).
-- Порядок: своя настройка cache_dir (ExtState) -> ключ di_cache общего <корень>\_workspace\paths.json (относительный путь --
-- от корня) -> <корень>\Cache\di_candidates.
local function cache_dir()
  local own = reaper.GetExtState(EXT_SECTION, "cache_dir")
  if own ~= "" then return own end
  local root = project_root()
  local f = io.open(root .. "\\_workspace\\paths.json", "r")
  if f then
    local ok, j = pcall(json_decode, f:read("a"))
    f:close()
    if ok and type(j) == "table" and type(j.di_cache) == "string" and j.di_cache ~= "" then
      local p = j.di_cache:gsub("/", "\\")
      if p:match("^%a:") or p:match("^\\\\") then return p end
      return root .. "\\" .. p
    end
  end
  return root .. "\\Cache\\di_candidates"
end

local function make_dir(path)
  if reaper.RecursiveCreateDirectory then
    reaper.RecursiveCreateDirectory(path, 0)
  else
    os.execute('mkdir "' .. path:gsub("/", "\\") .. '" >nul 2>nul')
  end
end

-- куда ставить партию: первый выбранный трек, если это не трек рифа; иначе nil -> новый трек под рифом
local function get_target_track(info)
  if not info or reaper.CountSelectedTracks(0) == 0 then return nil end
  local tr = reaper.GetSelectedTrack(0, 0)
  if tr == nil or tr == info.track then return nil end
  return tr
end

local function read_log_tail(path, n)
  local text = read_file(path or "")
  if not text then return {} end
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
  local out = {}
  for i = math.max(1, #lines - n + 1), #lines do out[#out + 1] = lines[i] end
  return out
end

-- задание для движка (контракт generate.py --job)
local function build_job(info, out_dir, variant)
  return {
    guitar = info.file,
    start = info.offs,
    length = info.len,
    bpm = info.bpm,
    meter = { info.num, info.den },
    first_downbeat = info.first_downbeat,
    exact_grid = true,
    shortest = SHORTEST_NOTES[S.shortest_idx].key,
    triplets = TRIPLET_MODES[S.triplet_idx].key,
    humanize = S.humanize,
    humanize_velocity = HUM_VEL_LEVELS[S.hum_vel_idx].key,
    humanize_timing = HUM_TIME_LEVELS[S.hum_time_idx].key,
    -- Без гуманизации: одинаковая сила - по галочке. С гуманизацией: значение силы - основа, вокруг которой
    -- хьюманизер меняет удары (он не задаёт громкость сам). Как в боте, куда уходит партия с силой 118: без основы
    -- партия шла с «измеренной по записи» силой (тарелки 88) и после гуманизации звучала слабее, чем из бота.
    velocity = (S.humanize or S.vel_const) and S.vel_value or nil,
    fill_silence = S.fill_silence,
    -- сильная доля - на первой ноте рифа (риф в item начинается не с начала такта проекта)
    downbeat_from_riff = S.bar_from_riff,
    kick = "model",
    kick_blend = S.kick_blend,
    fills = S.fills,
    diversity = S.diversity,
    style = S.style,
    drum_map = DRUM_MAPS[S.map_idx].key,
    follow = S.follow,
    variant = variant or 0,
    part = PART_MODES[S.part_idx].key,
    -- «Общий»: словарю нужен настоящий барабанщик (берётся Sleep Token), ИИ играет без метки стиля
    drummer = DRUMMERS[S.drummer_idx].key == "general" and "sleep_token" or DRUMMERS[S.drummer_idx].key,
    ai_style = DRUMMERS[S.drummer_idx].key == "general" and "none" or nil,
    ai_temperature = S.ai_temp,
    ai_kick_follow = S.ai_kick,
    ai_cymbal = AI_CYM[S.ai_cym_idx].key,
    ai_model = AI_MODELS[S.ai_model_idx].key,
    ai_double_kick = AI_DK[S.ai_dk_idx].key,
    ai_snare = AI_SN[S.ai_sn_idx].key,
    engine = ENGINES[S.engine_idx].key,
    focus = DRUMMERS[S.drummer_idx].focus ~= nil and S.focus or false,
    sections = PART_MODES[S.part_idx].key == "song" and info.sections or nil,
    out = out_dir,
  }
end

local function quote(s) return '"' .. tostring(s) .. '"' end

local function start_generation(as_variant)
  local info, err = get_selected_item_info()
  if not info then
    last_status = { kind = "error", text = err }
    return false
  end
  if not file_exists(engine_path()) then
    last_status = { kind = "error", text = "Нет движка: " .. S.engine .. " (кнопка «Путь…»)" }
    return false
  end
  local dir = string.format("%s/%s_%04d", job_root(), os.date("%Y%m%d_%H%M%S"), math.random(0, 9999))
  make_dir(dir)
  local job_path = dir .. "/job.json"
  local variant, replace = 0, nil
  if as_variant and last_gen and last_gen.item == info.item then
    variant = last_gen.variant + 1
    replace = last_gen
  end
  write_file(job_path, json_encode(build_job(info, dir, variant)))
  local cmd = quote(S.python) .. " " .. quote(S.engine) .. " --job " .. quote(job_path)
  -- -1: не ждать завершения (REAPER не блокируется), готовность - по появлению done.json
  reaper.ExecProcess(cmd, -1)
  local target = (replace and not replace.created_track) and replace.track or get_target_track(info)
  job = { dir = dir, started = reaper.time_precise(), info = info, cmd = cmd, variant = variant, replace = replace,
          target = target, log = dir .. "/log.txt" }
  last_log = { path = dir .. "/log.txt", lines = {} }
  last_status = { kind = "info", text = "Генерация запущена…" }
  return true
end

local function read_notes_csv(path)
  local notes = {}
  local text = read_file(path)
  if not text then return nil end
  local first = true
  for line in text:gmatch("[^\r\n]+") do
    if first then
      first = false
    else
      local t, n, v, l = line:match("^([^,]+),([^,]+),([^,]+),([^,]+)$")
      if t then notes[#notes + 1] = { t = tonumber(t), note = tonumber(n), vel = tonumber(v), len = tonumber(l) } end
    end
  end
  return notes
end

-- новый трек под треком рифа + MIDI-item на длину рифа; ноты - по времени проекта
local function apply_result(info, notes, sources, replace, variant, target)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  -- в имени - чем сочинено: барабанщик и (для ИИ) версия модели, чтобы партии разных моделей не путались
  -- для ИИ ещё и смелость: по имени видно, если её меняли (по умолчанию 1.00)
  local who = DRUMMERS[S.drummer_idx].label ..
    (S.engine_idx == 2 and (", " .. AI_MODELS[S.ai_model_idx].key .. string.format(", смелость %.2f", S.ai_temp) ..
      (S.ai_kick > 0 and string.format(", бочка за рифом %.2f", S.ai_kick) or "")) or "")
  local name = "AI Drummer (" .. who .. ") — " .. (info.take_name ~= "" and info.take_name or info.track_name) ..
    ((variant or 0) > 0 and (" (вариант " .. (variant + 1) .. ")") or "")
  local tr, created = nil, false
  if target and reaper.ValidatePtr(target, "MediaTrack*") then
    -- выбранный трек: партия встаёт на него от начала рифа; что там уже есть - забота пользователя.
    -- «Другой вариант»: удаляется только MIDI-item прошлой генерации на этом треке
    tr = target
    if replace and replace.midi_item and reaper.ValidatePtr(replace.midi_item, "MediaItem*") then
      reaper.DeleteTrackMediaItem(tr, replace.midi_item)
    end
  else
    local idx = math.floor(reaper.GetMediaTrackInfo_Value(info.track, "IP_TRACKNUMBER")) -- 1-based = индекс следующего
    -- «Другой вариант»: трек прошлой генерации (если он ещё есть) заменяется -- новый встаёт на его место
    if replace and replace.created_track and reaper.ValidatePtr(replace.track, "MediaTrack*") then
      idx = math.floor(reaper.GetMediaTrackInfo_Value(replace.track, "IP_TRACKNUMBER")) - 1
      reaper.DeleteTrack(replace.track)
    end
    reaper.InsertTrackAtIndex(idx, true)
    tr = reaper.GetTrack(0, idx)
    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
    created = true
  end
  local item = reaper.CreateNewMIDIItemInProj(tr, info.pos, info.pos + info.len, false)
  local take = reaper.GetActiveTake(item)
  for _, n in ipairs(notes) do
    local t0 = info.pos + n.t
    local t1 = t0 + (n.len or 0.05)
    if t0 < info.pos + info.len then
      local p0 = reaper.MIDI_GetPPQPosFromProjTime(take, t0)
      local p1 = reaper.MIDI_GetPPQPosFromProjTime(take, math.min(t1, info.pos + info.len))
      reaper.MIDI_InsertNote(take, false, false, p0, math.max(p1, p0 + 1), MIDI_CHANNEL, n.note, clamp(n.vel, 1, 127), true)
    end
  end
  reaper.MIDI_Sort(take)
  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM AI Drummer: MIDI-партия", -1)
  last_gen = { item = info.item, track = tr, midi_item = item, created_track = created, variant = variant or 0 }
  return tr, item
end

-- опрос фоновой генерации; вызывается из главного цикла
local function poll_job()
  if not job then return end
  local done_path = job.dir .. "/done.json"
  if not file_exists(done_path) then return end
  local ok_parse, done = pcall(json_decode, read_file(done_path) or "")
  local info, replace, variant, target = job.info, job.replace, job.variant, job.target
  if last_log then last_log.lines = read_log_tail(last_log.path, 6) end
  job = nil
  if not ok_parse or type(done) ~= "table" then
    last_status = { kind = "error", text = "Не удалось прочитать ответ движка: " .. tostring(done) }
    return
  end
  if not done.ok then
    last_status = { kind = "error", text = "Движок: " .. tostring(done.error or "ошибка без описания") }
    if done.traceback then reaper.ShowConsoleMsg("[AI Drummer] " .. tostring(done.traceback) .. "\n") end
    return
  end
  local notes = read_notes_csv(done.notes_csv or "")
  if not notes or #notes == 0 then
    last_status = { kind = "error", text = "Движок не вернул нот." }
    return
  end
  apply_result(info, notes, done.sources, replace, variant, target)
  local src = {}
  if type(done.sources) == "table" then
    for song, cnt in pairs(done.sources) do src[#src + 1] = song .. " ×" .. tostring(cnt) end
    table.sort(src)
  end
  local text = string.format("Готово%s%s: %d нот, %d тактов%s%s. Такты из: %s",
    done.drummer_name and (" (" .. tostring(done.drummer_name) .. ")") or "",
    (variant or 0) > 0 and (" (вариант " .. (variant + 1) .. ")") or "", #notes, done.n_bars or 0,
    done.triplets and ", триоли (как 6/4)" or "",
    (done.sections_used or 0) > 0 and (", частей песни: " .. done.sections_used) or "",
    #src > 0 and table.concat(src, ", ") or "—")
  if type(done.warnings) == "table" and #done.warnings > 0 then text = text .. "  ⚠ " .. table.concat(done.warnings, "; ") end
  last_status = { kind = "ok", text = text }
end

----------------------------------------------------------------------
-- КОНВЕРТЕР КАРТ: выделенные MIDI-item из одной карты барабанов в другую
----------------------------------------------------------------------
-- Таблицу «нота -> нота» даёт движок (tools\map_table.py рядом с generate.py): соответствие инструментов -- из
-- convert_map хьюманизера, то же, что в боте. Скрипт меняет только высоту нот (время, длина, сила, канал -- как были);
-- нота не из исходной карты или без пары в целевой остаётся как есть (как в convert_map). Одна отмена (Ctrl+Z) на всё.
local conv = nil          -- идущий запрос таблицы: { out, started, items, from, to }
local conv_tables = {}    -- "from>to" -> ответ map_table.py (за сеанс окна таблица не меняется)
local last_conv = nil     -- итог последней конвертации -- для статуса вкладки

local function selected_midi_items()
  local items, other = {}, 0
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do
    local it = reaper.GetSelectedMediaItem(0, i)
    local tk = it and reaper.GetActiveTake(it)
    if tk and reaper.TakeIsMIDI(tk) then
      items[#items + 1] = { item = it, take = tk, name = reaper.GetTakeName(tk) }
    else
      other = other + 1
    end
  end
  return items, other
end

local function apply_conversion(items, res)
  local tab, in_src = {}, {}
  for k, v in pairs(res.table or {}) do tab[tonumber(k)] = math.floor(v) end
  for _, n in ipairs(res.source_notes or {}) do in_src[math.floor(n)] = true end
  local total, changed, same, kept, foreign, nopair, done_items = 0, 0, 0, 0, {}, {}, 0
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for _, e in ipairs(items) do
    if reaper.ValidatePtr(e.item, "MediaItem*") and reaper.ValidatePtr(e.take, "MediaItem_Take*") then
      local _, cnt = reaper.MIDI_CountEvts(e.take)
      for i = 0, cnt - 1 do
        local _, _, _, _, _, _, pitch = reaper.MIDI_GetNote(e.take, i)
        total = total + 1
        local to = tab[pitch]
        if to == nil then
          if not in_src[pitch] then foreign[pitch] = true else kept = kept + 1; nopair[pitch] = true end
        elseif to ~= pitch then
          reaper.MIDI_SetNote(e.take, i, nil, nil, nil, nil, nil, to, nil, true)
          changed = changed + 1
        else
          same = same + 1
        end
      end
      reaper.MIDI_Sort(e.take)
      done_items = done_items + 1
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM AI Drummer: карта " .. res.from .. " -> " .. res.to, -1)
  local fl, nl = {}, {}
  for p in pairs(foreign) do fl[#fl + 1] = p end
  table.sort(fl)
  for p in pairs(nopair) do nl[#nl + 1] = p end
  table.sort(nl)
  for i, p in ipairs(nl) do                       -- «28 (crash_extra)»: нота и инструмент исходной карты
    local nm = (res.source_names or {})[tostring(p)]
    nl[i] = nm and (p .. " (" .. nm .. ")") or tostring(p)
  end
  return { items = done_items, total = total, changed = changed, same = same, kept = kept, foreign = fl, nopair = nl,
           from = res.from, to = res.to }
end

local function conv_label(key)
  for _, m in ipairs(CONVERT_MAPS) do if m.key == key then return m.label end end
  return key
end

local function finish_conversion(items, res)
  if type(res) ~= "table" or not res.ok then
    last_conv = nil
    last_status = { kind = "error", text = "Конвертер: " .. tostring(type(res) == "table" and res.error or res) }
    return
  end
  local r = apply_conversion(items, res)
  last_conv = r
  local text = string.format("Готово: %s -> %s, item: %d, нот: %d, переведено: %d", conv_label(r.from), conv_label(r.to),
    r.items, r.total, r.changed)
  if r.same > 0 then text = text .. string.format(" (ещё %d - та же нота в обеих картах)", r.same) end
  if #r.foreign > 0 then
    text = text .. ".  ⚠ Ноты не из карты «" .. conv_label(r.from) .. "» оставлены как есть: " .. table.concat(r.foreign, ", ")
  end
  if r.kept > 0 then
    text = text .. ".  ⚠ Нет пары в «" .. conv_label(r.to) .. "» (оставлены как есть, нот " .. r.kept .. "): " ..
      table.concat(r.nopair, ", ")
  end
  last_status = { kind = (#r.foreign > 0 or r.kept > 0) and "info" or "ok", text = text }
end

local function start_conversion()
  local items, other = selected_midi_items()
  if #items == 0 then
    last_status = { kind = "error", text = other > 0 and "Выделенные item - не MIDI." or "Выделите MIDI-item (один или несколько)." }
    return false
  end
  local from, to = CONVERT_MAPS[S.conv_from_idx].key, CONVERT_MAPS[S.conv_to_idx].key
  if from == to then
    last_status = { kind = "error", text = "Исходная и целевая карта совпадают." }
    return false
  end
  local cached = conv_tables[from .. ">" .. to]
  if cached then finish_conversion(items, cached); return true end
  local edir = tostring(engine_path() or ""):match("^(.*)[\\/][^\\/]*$") or "."
  local tool = edir .. "\\tools\\map_table.py"
  if not file_exists(tool) then
    last_status = { kind = "error", text = "Нет " .. tool .. " (движок старый или путь не тот: кнопка «Путь…»)" }
    return false
  end
  local dir = string.format("%s/convert_%s_%04d", job_root(), os.date("%Y%m%d_%H%M%S"), math.random(0, 9999))
  make_dir(dir)
  local out = dir .. "/table.json"
  local cmd = quote(S.python) .. " " .. quote(tool) .. " --from " .. from .. " --to " .. to .. " --out " .. quote(out)
  reaper.ExecProcess(cmd, -1)   -- в фоне: таблица готова через 1-2 с (Python загружает хьюманизер)
  conv = { out = out, started = reaper.time_precise(), items = items, from = from, to = to }
  last_status = { kind = "info", text = "Конвертер: готовлю таблицу нот…" }
  return true
end

local function poll_conversion()
  if not conv then return end
  if not file_exists(conv.out) then
    if reaper.time_precise() - conv.started > 60 then
      conv = nil
      last_status = { kind = "error", text = "Конвертер: движок не ответил за 60 с (проверьте «Python…» и «Путь…»)." }
    end
    return
  end
  local c = conv
  conv = nil
  local ok, res = pcall(json_decode, read_file(c.out) or "")
  if ok and type(res) == "table" and res.ok then conv_tables[c.from .. ">" .. c.to] = res end
  finish_conversion(c.items, ok and res or ("не удалось прочитать ответ: " .. tostring(res)))
end

----------------------------------------------------------------------
-- GUI (оформление как у SSM_DI_Guitar_Align)
----------------------------------------------------------------------
local win_x, win_y = S.win_x, S.win_y
local dragging = false
local drag_off_x, drag_off_y = 0, 0
local last_mouse_cap = 0

local col = {
  bg        = {0.11, 0.12, 0.15},
  panel     = {0.16, 0.17, 0.21},
  accent    = {0.25, 0.55, 0.95},
  accent2   = {0.10, 0.95, 0.35},
  text      = {0.92, 0.93, 0.95},
  text_dim  = {0.55, 0.58, 0.65},
  border    = {0.25, 0.27, 0.32},
  input_bg  = {0.09, 0.10, 0.13},
  btn       = {0.20, 0.22, 0.27},
  btn_hover = {0.35, 0.65, 1.00},
  btn_start = {0.16, 0.62, 0.38},
  warn      = {0.95, 0.70, 0.15},
  err       = {0.95, 0.40, 0.35},
}

local function set_color(c, a)
  gfx.r, gfx.g, gfx.b = c[1], c[2], c[3]
  gfx.a = a or 1
end

local function draw_round_rect(x, y, w, h, c, a, r)
  r = r or 6
  set_color(c, a)
  if r <= 0 then gfx.rect(x, y, w, h, 1); return end
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

local function clip_text(str, max_w, size)
  gfx.setfont(1, "Arial", size or 13)
  if gfx.measurestr(str) <= max_w then return str end
  local out = str
  -- отрезаем по целому символу UTF-8 (по байту -- русская буква режется пополам и рисуется мусором)
  while #out > 1 and gfx.measurestr(out .. "…") > max_w do out = out:sub(1, (utf8.offset(out, -1) or #out) - 1) end
  return out .. "…"
end

-- перенос длинного текста по словам на несколько строк
local function wrap_text(str, max_w, size)
  gfx.setfont(1, "Arial", size or 14)
  local lines, cur = {}, ""
  for word in tostring(str):gmatch("%S+") do
    local try = cur == "" and word or (cur .. " " .. word)
    if gfx.measurestr(try) > max_w and cur ~= "" then
      lines[#lines + 1] = cur
      cur = word
    else
      cur = try
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local function draw_chip_row(x, y, w, h, options, selected_idx, left_click, enabled)
  local gap = 6
  local n = #options
  local chip_w = (w - gap * (n - 1)) / n
  local clicked = nil
  for i, o in ipairs(options) do
    local cx = x + (i - 1) * (chip_w + gap)
    local is_sel = (i == selected_idx)
    local hov = enabled and mouse_in(cx, y, chip_w, h)
    local c = is_sel and col.accent or (hov and col.btn_hover or col.btn)
    draw_round_rect(cx, y, chip_w, h, c, 1, 6)
    set_color(col.border); gfx.rect(cx, y, chip_w, h, 0)
    gfx.setfont(1, "Arial", 14)
    local tw = gfx.measurestr(o.label)
    draw_text(o.label, cx + (chip_w - tw) / 2, y + (h - 14) / 2, col.text)
    if hov and left_click then clicked = i end
  end
  return clicked
end

local function draw_button(x, y, w, h, label, enabled, left_click, color)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = enabled and (color or (hov and col.btn_hover or col.btn)) or col.panel
  if enabled and color and hov then c = col.btn_hover end
  draw_round_rect(x, y, w, h, c, 1, 6)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  gfx.setfont(1, "Arial", 15)
  local tw = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - 15) / 2, enabled and col.text or col.text_dim)
  return enabled and hov and left_click
end

local function draw_value_box(x, y, w, h, value_str, left_click, enabled)
  local hov = enabled and mouse_in(x, y, w, h)
  draw_round_rect(x, y, w, h, hov and col.accent or col.input_bg, 1, 5)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  gfx.setfont(1, "Arial", 15)
  local tw = gfx.measurestr(value_str)
  draw_text(value_str, x + (w - tw) / 2, y + (h - 15) / 2, enabled and col.text or col.text_dim)
  return hov and left_click
end

local function draw_checkbox(x, y, checked, label, left_click)
  draw_round_rect(x, y, 20, 20, checked and col.accent or col.input_bg, 1, 4)
  set_color(col.border); gfx.rect(x, y, 20, 20, 0)
  gfx.setfont(1, "Arial", 15)
  if checked then draw_text("✓", x + 4, y, col.text) end
  draw_text(label, x + 29, y + 2, col.text)
  local hit_w = math.max(300, 29 + gfx.measurestr(label) + 10)
  return mouse_in(x, y, hit_w, 22) and left_click
end

-- ползунок 0..1: возвращает новое значение при клике/перетаскивании
local slider_drag = nil -- id слайдера, который тянут
local function draw_slider(x, y, w, value, left_down, left_click, enabled, id)
  id = id or "default"
  local h = 8
  draw_round_rect(x, y + 6, w, h, col.input_bg, 1, 4)
  set_color(col.border); gfx.rect(x, y + 6, w, h, 0)
  local hx = x + value * w
  draw_round_rect(x, y + 6, math.max(hx - x, 1), h, col.accent, 1, 4)
  gfx.circle(hx, y + 10, 9, 1, 1)
  set_color(col.text); gfx.circle(hx, y + 10, 9, 0, 1)
  if enabled and left_click and mouse_in(x - 10, y - 4, w + 20, 28) then slider_drag = id end
  if not left_down then slider_drag = nil end
  if enabled and slider_drag == id then
    return clamp((gfx.mouse_x - x) / w, 0, 1)
  end
  return nil
end

local function ask_text(title, label, current)
  local ok, str = reaper.GetUserInputs(title, 1, label .. ",extrawidth=420", current)
  if not ok then return nil end
  return str
end

local function draw_window()
  local w, h = gfx.w, gfx.h
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1
  local busy = job ~= nil
  local action = nil

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)

  -- заголовок (перетаскивается)
  local in_header = gfx.mouse_y >= 0 and gfx.mouse_y <= HEADER_H and gfx.mouse_x < w - 18 - 330  -- справа вкладки
  if left_click and in_header then
    dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    drag_off_x = sx - (wx or win_x)
    drag_off_y = sy - (wy or win_y)
  end
  if left_release and dragging then
    local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
    if x then win_x, win_y = x, y; S.win_x, S.win_y = x, y; save_settings() end
  end
  if left_release then dragging = false end
  if dragging then
    local sx, sy = reaper.GetMousePosition()
    win_x, win_y = sx - drag_off_x, sy - drag_off_y
    gfx.init("", math.floor(w), math.floor(h), 0, math.floor(win_x), math.floor(win_y))
  end
  draw_round_rect(0, 0, w, HEADER_H, col.panel, 1, 0)
  gfx.setfont(1, "Arial", 18)
  draw_text("🥁 SSM AI Drummer v1.6", 18, 15, col.text)
  -- своего крестика нет: окно закрывается средствами REAPER (Esc, рамка окна, список действий)
  -- вкладки: партия (генерация) / конвертер карт
  local vc = draw_chip_row(w - 18 - 330, 10, 330, 28, VIEWS, S.view_idx, left_click and not dragging, true)
  if vc then S.view_idx = vc; save_settings() end

  if VIEWS[S.view_idx].key == "convert" then
    local pad = 18
    local fw = w - 2 * pad
    local y = HEADER_H + 14
    local cbusy = conv ~= nil
    local items, other = selected_midi_items()
    draw_round_rect(pad, y, fw, 150, col.panel, 1, 8)
    gfx.setfont(1, "Arial", 15)
    draw_text(string.format("Выделено MIDI-item: %d%s", #items, other > 0 and ("  (не MIDI - пропускаются: " .. other .. ")") or ""),
      pad + 10, y + 8, #items > 0 and col.text or col.warn)
    gfx.setfont(1, "Arial", 13)
    for i, e in ipairs(items) do
      if i > 5 then draw_text("… и ещё " .. (#items - 5), pad + 22, y + 32 + 5 * 20, col.text_dim); break end
      draw_text(clip_text(e.name ~= "" and e.name or "(без имени)", fw - 40, 13), pad + 22, y + 32 + (i - 1) * 20, col.text_dim)
    end
    if #items == 0 then draw_text("Выделите в проекте один или несколько MIDI-item с барабанами.", pad + 22, y + 34, col.text_dim) end
    y = y + 164

    gfx.setfont(1, "Arial", 15)
    draw_text("Из карты (в какой записан MIDI сейчас):", pad, y, col.text)
    local fc = draw_chip_row(pad, y + 22, fw, 30, CONVERT_MAPS, S.conv_from_idx, left_click and not cbusy, not cbusy)
    if fc then S.conv_from_idx = fc; save_settings() end
    y = y + 66
    gfx.setfont(1, "Arial", 15)
    draw_text("В карту (под какой плагин нужно):", pad, y, col.text)
    local tc = draw_chip_row(pad, y + 22, fw, 30, CONVERT_MAPS, S.conv_to_idx, left_click and not cbusy, not cbusy)
    if tc then S.conv_to_idx = tc; save_settings() end
    y = y + 70

    if cbusy then
      draw_button(pad, y, fw, 40, string.format("%.0f с — готовлю таблицу нот…", reaper.time_precise() - conv.started), false, false)
    else
      local can = #items > 0 and S.conv_from_idx ~= S.conv_to_idx
      if draw_button(pad, y, fw - 180, 40, "🔁 Перевести выделенные MIDI-item", can, left_click, col.btn_start) then
        action = "convert"
      end
      if draw_button(pad + fw - 170, y, 170, 40, "⇄ Поменять", true, left_click) then
        S.conv_from_idx, S.conv_to_idx = S.conv_to_idx, S.conv_from_idx; save_settings()
      end
    end
    y = y + 52
    gfx.setfont(1, "Arial", 13)
    for _, ln in ipairs({
      "Меняется только номер ноты: время, длина и сила удара остаются. Отмена - Ctrl+Z (одним шагом).",
      "Соответствие инструментов - из SSM Humanizer (как в боте). Нота не из исходной карты остаётся как есть.",
    }) do
      draw_text(clip_text(ln, fw, 13), pad, y, col.text_dim)
      y = y + 18
    end
    y = y + 10
    if last_status then
      local cc = last_status.kind == "error" and col.err or (last_status.kind == "ok" and col.accent2 or col.text_dim)
      gfx.setfont(1, "Arial", 14)
      for i, ln in ipairs(wrap_text(last_status.text, fw, 14)) do
        if i > 6 then break end
        draw_text(ln, pad, y + (i - 1) * 18, cc)
      end
    end
    last_mouse_cap = gfx.mouse_cap
    return action
  end

  -- две колонки: слева -- вход и выход (item, сетка, ноты рифа, гуманизация, карта), справа -- характер партии
  -- (слайдеры и галочки), кнопки и статус; журнал движка -- внизу во всю ширину
  local pad, gap = 18, 24
  local colw = math.floor((w - 2 * pad - gap) / 2)
  local lx, rx = pad, pad + colw + gap
  local top = HEADER_H + 14

  local function slider_block(x, y, label_l, label_r, value, id, hint)
    gfx.setfont(1, "Arial", 15)
    draw_text(label_l, x, y, col.text)
    draw_text(label_r, x + colw - gfx.measurestr(label_r), y, col.text)
    local v = draw_slider(x + 10, y + 22, colw - 20, value, left_down, left_click, not busy, id)
    gfx.setfont(1, "Arial", 13)
    draw_text(clip_text(hint, colw, 13), x, y + 48, col.text_dim)
    return v, y + 68
  end

  local function check_block(x, y, checked, label, hint)
    local hit = draw_checkbox(x, y, checked, label, left_click and not busy)
    gfx.setfont(1, "Arial", 13)
    draw_text(clip_text(hint, colw - 29, 13), x + 29, y + 22, col.text_dim)
    return hit, y + 44
  end

  ---------------- левая колонка ----------------
  local y = top

  -- выбранный item и сетка проекта
  local info, err = get_selected_item_info()
  draw_round_rect(lx, y, colw, 84, col.panel, 1, 8)
  gfx.setfont(1, "Arial", 15)
  draw_text("Выбрано в проекте:", lx + 10, y + 8, col.text)
  if info then
    local line = string.format("%s  —  %s   (%s)", info.track_name, info.take_name, fmt_time(info.len))
    draw_text(clip_text(line, colw - 30, 14), lx + 22, y + 32, col.text)
    gfx.setfont(1, "Arial", 14)
    local grid = string.format("Темп %.2f bpm, размер %d/%d, сильная доля %+.3f с от начала item",
      info.bpm, info.num, info.den, info.first_downbeat)
    draw_text(clip_text(grid, colw - 30, 14), lx + 22, y + 54, info.tempo_change and col.warn or col.text_dim)
    if info.tempo_change then draw_text("⚠ смена темпа внутри item: взят темп в начале", lx + 22, y + 68, col.warn) end
  else
    gfx.setfont(1, "Arial", 14)
    draw_text(clip_text(err, colw - 30, 14), lx + 22, y + 34, col.warn)
  end
  y = y + 96

  -- движок
  gfx.setfont(1, "Arial", 15)
  draw_text("Движок:", lx, y + 5, col.text)
  local ec = draw_chip_row(lx + 80, y, colw - 80, 28, ENGINES, S.engine_idx, left_click and not busy, not busy)
  if ec then S.engine_idx = ec; save_settings() end
  gfx.setfont(1, "Arial", 13)
  draw_text(S.engine_idx == 2 and "ИИ сочиняет такт за тактом (настройки словаря скрыты)"
    or "Словарь: такты барабанщика из его песен (как раньше)", lx, y + 32, col.text_dim)
  y = y + 58

  -- часть песни: подсказка барабанщику, что это за риф
  gfx.setfont(1, "Arial", 15)
  draw_text("Часть песни:", lx, y, col.text)
  local row1, row2 = {}, {}
  for i, o in ipairs(PART_MODES) do if i <= 5 then row1[#row1 + 1] = o else row2[#row2 + 1] = o end end
  local pc = draw_chip_row(lx, y + 22, colw, 28, row1, S.part_idx <= 5 and S.part_idx or 0, left_click and not busy, not busy)
  if pc then S.part_idx = pc; save_settings() end
  pc = draw_chip_row(lx, y + 56, colw, 28, row2, S.part_idx > 5 and S.part_idx - 5 or 0, left_click and not busy, not busy)
  if pc then S.part_idx = pc + 5; save_settings() end
  local pk = PART_MODES[S.part_idx].key
  local nreg = info and #info.sections or 0
  gfx.setfont(1, "Arial", 13)
  if pk == "song" and nreg > 0 then
    local names = {}
    for _, r in ipairs(info.sections) do names[#names + 1] = r.name ~= "" and r.name or "?" end
    draw_text(clip_text("Части песни из регионов (" .. nreg .. "): " .. table.concat(names, ", "), colw, 13), lx, y + 90, col.accent2)
  elseif pk == "song" then
    draw_text("Регионов на item нет - добавьте регионы (Куплет, Припев…) или выберите часть кнопкой", lx, y + 90, col.warn)
  elseif pk == "auto" then
    draw_text(nreg > 0 and ("На item есть регионы (" .. nreg .. ") - «Вся песня» учтёт их") or
      "Часть не задана - такты подбираются только по рифу", lx, y + 90, col.text_dim)
  else
    draw_text("Весь item - " .. PART_MODES[S.part_idx].low .. ": такты из этой части его песен", lx, y + 90, col.accent2)
  end
  y = y + 114

  -- самые короткие ноты
  gfx.setfont(1, "Arial", 15)
  draw_text("Самые короткие ноты в рифе:", lx, y, col.text)
  local c = draw_chip_row(lx, y + 22, colw, 30, SHORTEST_NOTES, S.shortest_idx, left_click and not busy, not busy)
  if c then S.shortest_idx = c; save_settings() end
  y = y + 64

  -- триоли
  gfx.setfont(1, "Arial", 15)
  draw_text("Триоли:", lx, y, col.text)
  c = draw_chip_row(lx, y + 22, colw, 30, TRIPLET_MODES, S.triplet_idx, left_click and not busy, not busy)
  if c then S.triplet_idx = c; save_settings() end
  gfx.setfont(1, "Arial", 13)
  draw_text(clip_text(S.engine_idx == 2 and "ИИ играет триоли в исходном размере (сетка точна и для триолей)" or
    "Авто: триольный риф играется как 6/4 прямыми восьмыми (как у барабанщика)", colw, 13),
    lx, y + 58, col.text_dim)
  y = y + 82

  -- гуманизация и сила удара
  if draw_checkbox(lx, y, S.humanize, "SSM Humanizer", left_click and not busy) then
    S.humanize = not S.humanize; save_settings()
  end
  y = y + 32
  if S.humanize then
    -- интенсивность отдельно для силы удара и тайминга (как в боте)
    gfx.setfont(1, "Arial", 14)
    draw_text("Сила удара:", lx + 29, y + 5, col.text)
    local hv = draw_chip_row(lx + 130, y, colw - 130, 26, HUM_VEL_LEVELS, S.hum_vel_idx, left_click and not busy, not busy)
    if hv then S.hum_vel_idx = hv; save_settings() end
    y = y + 32
    gfx.setfont(1, "Arial", 14)
    draw_text("Тайминг:", lx + 29, y + 5, col.text)
    local ht = draw_chip_row(lx + 130, y, colw - 130, 26, HUM_TIME_LEVELS, S.hum_time_idx, left_click and not busy, not busy)
    if ht then S.hum_time_idx = ht; save_settings() end
    y = y + 36
  else
    if draw_checkbox(lx, y, S.vel_const, "Одинаковая сила удара:", left_click and not busy) then
      S.vel_const = not S.vel_const; save_settings()
    end
    if draw_value_box(lx + 230, y - 3, 70, 26, tostring(S.vel_value), left_click and not busy, S.vel_const) and S.vel_const then
      local v = tonumber(ask_text("Сила удара", "Velocity 1-127:", tostring(S.vel_value)) or "")
      if v then S.vel_value = clamp(math.floor(v + 0.5), 1, 127); save_settings() end
    end
    y = y + 38
  end

  -- карта барабанов на выходе
  gfx.setfont(1, "Arial", 15)
  draw_text("Карта барабанов на выходе:", lx, y, col.text)
  local mc = draw_chip_row(lx, y + 22, colw, 30, DRUM_MAPS, S.map_idx, left_click and not busy, not busy)
  if mc then S.map_idx = mc; save_settings() end
  y = y + 66

  -- движок
  gfx.setfont(1, "Arial", 13)
  draw_text(clip_text("Движок: " .. S.engine, colw - 292, 13), lx, y + 6, file_exists(S.engine) and col.text_dim or col.err)
  if draw_button(lx + colw - 282, y, 88, 26, "Кэш…", true, left_click) then action = "open_cache" end
  if draw_button(lx + colw - 190, y, 90, 26, "Путь…", not busy, left_click) then
    local p = ask_text("Движок AI Drummer", "Путь к generate.py:", S.engine)
    if p and p ~= "" then S.engine = p; save_settings(); project_root() end
  end
  if draw_button(lx + colw - 94, y, 94, 26, "Python…", not busy, left_click) then
    local p = ask_text("Python для движка", "python.exe (или python):", S.python)
    if p and p ~= "" then S.python = p; save_settings() end
  end
  local left_end = y + 40

  ---------------- правая колонка ----------------
  y = top

  -- барабанщик: чей стиль
  gfx.setfont(1, "Arial", 15)
  draw_text("Барабанщик:", rx, y, col.text)
  local dc = draw_chip_row(rx, y + 22, colw, 30, DRUMMERS, S.drummer_idx, left_click and not busy, not busy)
  if dc then S.drummer_idx = dc; save_settings() end
  y = y + 60
  if DRUMMERS[S.drummer_idx].focus and S.engine_idx ~= 2 then
    if draw_checkbox(rx, y, S.focus, "Упор на альбом " .. DRUMMERS[S.drummer_idx].focus, left_click and not busy) then
      S.focus = not S.focus; save_settings()
    end
    y = y + 30
  end

  if S.engine_idx == 2 then
    -- ИИ: смелость (температура выборки) 0.3..1.3; 1.0 -- по умолчанию (как у настоящих барабанщиков)
    local tv
    tv, y = slider_block(rx, y, "Смелость ИИ: предсказуемо", "смело", (S.ai_temp - 0.3) / 1.0, "temp",
      string.format("%.2f: %s", S.ai_temp, S.ai_temp < 0.7 and "самые частые шаблоны (скучнее; может недоигрывать)" or
        (S.ai_temp < 0.97 and "ровнее и однообразнее: меньше сбивок и смен тарелок" or
          (S.ai_temp <= 1.03 and "как у настоящих барабанщиков: сбивки, смены тарелок" or "смело: больше неожиданного"))))
    if tv then
      local t = 0.3 + tv * 1.0
      if math.abs(t - 1.0) < 0.03 then t = 1.0 end
      S.ai_temp = t; save_settings()
    end
    -- бочка: слева -- как обучена модель (у Architects -- как сам Сирл), вправо -- бочка на нотах рифа. Замер на рифах
    -- NewRifss (v9 Architects): нот рифа с бочкой 59% -> 79% (середина) -> 93% (справа)
    local kv2
    kv2, y = slider_block(rx, y, "Бочка: как у барабанщика", "за рифом", S.ai_kick, "aikick",
      S.ai_kick == 0 and "слева - как играет барабанщик (у Architects бочка примерно на половине нот рифа)" or
      string.format("%d%% к «за рифом»: бочка чаще на нотах гитары", math.floor(S.ai_kick * 100 + 0.5)))
    if kv2 then
      if kv2 < 0.03 then kv2 = 0 end
      S.ai_kick = kv2; save_settings()
    end
  else
    -- бочка: смесь такта барабанщика и модели под риф
    local kv
    kv, y = slider_block(rx, y, "Бочка: как у барабанщика", "под риф", S.kick_blend, "kick",
      S.kick_blend == 0.5 and "середина: смесь - бочка на нотах рифа примерно так же часто, как у самого барабанщика" or
      string.format("%d%% к «под риф»", math.floor(S.kick_blend * 100 + 0.5)))
    if kv then
      if math.abs(kv - 0.5) < 0.03 then kv = 0.5 end
      S.kick_blend = kv; save_settings()
    end
  end

  local hit
  if S.engine_idx == 2 then
    -- ИИ: управляющие метки -- чем играть (модель версии 5; «Авто» -- решает сама)
    local function ctl_row(label, opts, key)
      gfx.setfont(1, "Arial", 14)
      draw_text(label, rx, y + 6, col.text)
      local c = draw_chip_row(rx + 100, y, colw - 100, 28, opts, S[key], left_click and not busy, not busy)
      if c then S[key] = c; save_settings() end
      y = y + 36
    end
    ctl_row("Модель ИИ:", AI_MODELS, "ai_model_idx")
    ctl_row("Тарелка:", AI_CYM, "ai_cym_idx")
    ctl_row("Дабл-бочка:", AI_DK, "ai_dk_idx")
    ctl_row("Малый:", AI_SN, "ai_sn_idx")
    gfx.setfont(1, "Arial", 13)
    draw_text("«Авто» - модель решает сама по рифу; выбор - так она играет весь item", rx, y, col.text_dim)
    y = y + 26
  else
    -- баланс: держать грув / следовать рифу
    local nv
    nv, y = slider_block(rx, y, "Держать грув песни", "Следовать рифу", S.follow, "follow",
      S.follow == 0.5 and "середина - баланс, подобранный проверкой на песнях выбранного барабанщика" or
      string.format("%d%% к «Следовать рифу» (середина - подобранный баланс)", math.floor(S.follow * 100 + 0.5)))
    if nv then
      -- середина "липкая": ±3% -> ровно 0.5 (подобранный проверкой баланс)
      if math.abs(nv - 0.5) < 0.03 then nv = 0.5 end
      S.follow = nv; save_settings()
    end

    -- разнообразие: штраф за такты из одной песни
    local dv
    dv, y = slider_block(rx, y, "Разнообразие: как выйдет", "из разных песен", S.diversity, "diversity",
      S.diversity == 0 and "0 - такты берутся по сходству, даже если почти все из одной песни" or
      string.format("%d%%: штраф песне за долю партии, уже взятую из неё", math.floor(S.diversity * 100 + 0.5)))
    if dv then
      if dv < 0.03 then dv = 0 end
      S.diversity = dv; save_settings()
    end
    y = y + 4

    hit, y = check_block(rx, y, S.fills, "Художественные сбивки", "в конце каждой части и рифа; без регионов - каждые 8 тактов")
    if hit then S.fills = not S.fills; save_settings() end
    hit, y = check_block(rx, y, S.style, "Подчеркнуть стиль", "суета: внезапные быстрые бочки/малые, частая смена тарелок и хэта")
    if hit then S.style = not S.style; save_settings() end
  end
  hit, y = check_block(rx, y, S.fill_silence, "Играть в паузах рифа", "интро/концовка, до вступления гитары")
  if hit then S.fill_silence = not S.fill_silence; save_settings() end
  hit, y = check_block(rx, y, S.bar_from_riff, "Такт от первой ноты рифа", "если риф начинается не с начала такта проекта (не для затакта)")
  if hit then S.bar_from_riff = not S.bar_from_riff; save_settings() end
  y = y + 6

  -- куда встанет партия
  gfx.setfont(1, "Arial", 14)
  local tgt = get_target_track(info)
  if tgt then
    local _, tn = reaper.GetTrackName(tgt)
    draw_text(clip_text("Куда: на выбранный трек «" .. tn .. "» (от начала рифа)", colw, 14), rx, y, col.accent2)
  else
    draw_text("Куда: новый трек под рифом (или выберите трек для партии)", rx, y, col.text_dim)
  end
  y = y + 24

  -- кнопка генерации / прогресс
  if busy then
    local el = reaper.time_precise() - job.started
    local cur = read_log_tail(job.log, 1)[1]
    cur = cur and cur:gsub("^%S+%s+", "") or "запуск движка"
    draw_button(rx, y, colw, 40, clip_text(string.format("%.0f с — %s", el, cur), colw - 20, 15), false, false)
  else
    local can_variant = info ~= nil and last_gen ~= nil and last_gen.item == info.item
    if draw_button(rx, y, colw - 180, 40, "🥁 Сгенерировать MIDI-партию", info ~= nil, left_click, col.btn_start) then
      action = "generate"
    end
    if draw_button(rx + colw - 170, y, 170, 40, "Другой вариант", can_variant, left_click) then
      action = "variant"
    end
  end
  y = y + 50

  -- статус
  if last_status then
    local cc = last_status.kind == "error" and col.err or (last_status.kind == "ok" and col.accent2 or col.text_dim)
    for i, ln in ipairs(wrap_text(last_status.text, colw, 14)) do
      if i > 4 then break end
      draw_text(ln, rx, y + (i - 1) * 18, cc)
    end
    y = y + 74
  end

  ---------------- журнал движка: внизу во всю ширину ----------------
  y = math.max(left_end, y) + 4
  if last_log and #last_log.lines > 0 and not busy then
    local fw = w - 2 * pad
    set_color(col.border); gfx.line(pad, y - 6, pad + fw, y - 6)
    gfx.setfont(1, "Arial", 14)
    draw_text("Журнал движка:", pad, y, col.text)
    if draw_button(pad + fw - 150, y - 4, 150, 24, "Открыть журнал", true, left_click) then
      action = "open_log"
    end
    y = y + 24
    gfx.setfont(1, "Arial", 12)
    for _, ln in ipairs(last_log.lines) do
      draw_text(clip_text(ln, fw, 12), pad, y, col.text_dim)
      y = y + 16
    end
  end

  last_mouse_cap = gfx.mouse_cap
  return action
end

-- положение и размер окна -> настройки (положение -- от системы: окно могли двигать за рамку)
local function remember_window()
  local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
  if x then win_x, win_y = x, y end
  S.win_x, S.win_y = win_x, win_y
  if gfx.w and gfx.h and gfx.w >= 700 and gfx.h >= 500 then S.win_w, S.win_h = gfx.w, gfx.h end
  save_settings()
end

local function main_loop()
  local char = gfx.getchar()
  if char == 27 or char < 0 then
    if char == 27 then remember_window() end      -- при char < 0 окна уже нет: размер сохранён раньше (ниже)
    gfx.quit()
    return
  end
  -- размер изменили (растянули окно) -- запомнить, когда кнопку мыши отпустили
  if (gfx.mouse_cap & 1) == 0 and not dragging then
    local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
    local moved = x and (x ~= S.win_x or y ~= S.win_y)       -- окно передвинули за рамку
    local resized = gfx.w >= 700 and gfx.h >= 500 and (gfx.w ~= S.win_w or gfx.h ~= S.win_h)
    if moved or resized then remember_window() end
  end
  local okp, perr = pcall(poll_job)
  if not okp then
    job = nil
    last_status = { kind = "error", text = "Ошибка вставки партии: " .. tostring(perr) }
  end
  local okc, cerr = pcall(poll_conversion)
  if not okc then
    conv = nil
    last_status = { kind = "error", text = "Ошибка конвертера: " .. tostring(cerr) }
  end
  local ok, action = pcall(draw_window)
  if not ok then
    reaper.ShowConsoleMsg("[AI Drummer] ERROR in GUI: " .. tostring(action) .. "\n")
    reaper.ShowMessageBox("Ошибка интерфейса:\n" .. tostring(action), SCRIPT_TITLE, 0)
    gfx.quit()
    return
  end
  gfx.update()
  if action == "close" then
    S.win_x, S.win_y = win_x, win_y
    save_settings()
    gfx.quit()
    return
  end
  if action == "generate" then start_generation(false) end
  if action == "variant" then start_generation(true) end
  if action == "convert" then start_conversion() end
  if action == "open_cache" then
    local dir = cache_dir()
    make_dir(dir)
    if reaper.CF_ShellExecute then reaper.CF_ShellExecute(dir) else os.execute('start "" "' .. dir .. '"') end
  end
  if action == "open_log" and last_log then
    local path = last_log.path:gsub("/", "\\")
    if reaper.CF_ShellExecute then reaper.CF_ShellExecute(path) else os.execute('start "" "' .. path .. '"') end
  end
  reaper.defer(main_loop)
end

----------------------------------------------------------------------
-- ENTRY
----------------------------------------------------------------------
-- Режим библиотеки (тесты, будущие обёртки): SSM_AI_DRUMMER_LIBRARY = true -> окно не открывается.
if SSM_AI_DRUMMER_LIBRARY then
  return {
    S = S, SHORTEST_NOTES = SHORTEST_NOTES, TRIPLET_MODES = TRIPLET_MODES,
    get_selected_item_info = get_selected_item_info, build_job = build_job,
    start_generation = start_generation, poll_job = poll_job, apply_result = apply_result,
    is_busy = function() return job ~= nil end, job = function() return job end, last_gen = function() return last_gen end,
    last_log = function() return last_log end, get_target_track = get_target_track,
    status = function() return last_status end, draw_window = draw_window,
    remember_window = remember_window, window_size = function() return S.win_w, S.win_h end, cache_dir = cache_dir,
    PART_MODES = PART_MODES, json_encode = json_encode, json_decode = json_decode, read_notes_csv = read_notes_csv,
    CONVERT_MAPS = CONVERT_MAPS, VIEWS = VIEWS, start_conversion = start_conversion, poll_conversion = poll_conversion,
    is_converting = function() return conv ~= nil end, selected_midi_items = selected_midi_items,
    project_root = project_root, engine_path = engine_path,
  }
end

math.randomseed(os.time())
pcall(engine_path)   -- корень перенесли -> движок из корня; корень -> общая настройка для других скриптов SSM
gfx.init(SCRIPT_TITLE, S.win_w, S.win_h, 0, math.floor(win_x), math.floor(win_y))
gfx.setfont(1, "Arial", 15)
reaper.defer(main_loop)
