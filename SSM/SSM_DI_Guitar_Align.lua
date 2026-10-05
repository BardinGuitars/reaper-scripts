-- @description SSM_DI_Guitar_Align
-- @version 1.2
-- @author @ssm_metalmix
-- @about
--   🎸 Расстановка стрейч-маркеров (или разрезание) для DI-гитары по
--   таймингу нот — работает и там, где нет чёткого транзиента (легато:
--   хаммер-он, пул-офф, слайд). В отличие от обычного транзиент-детектора,
--   скрипт объединяет три независимых признака атаки ноты:
--     - Spectral Flux (изменение спектра) — щипки/атаки медиатором;
--     - HFC (высокочастотный контент) — резкие/перкуссивные атаки;
--     - Смену высоты тона (автокорреляционный питч-трекер через FFT) —
--       ловит легато-переходы без транзиента.
--   Результат: стрейч-маркеры (неразрушающе, утягивает аудио под сетку),
--   разрезание item на слайсы или гибрид. Есть
--   привязка к сетке проекта (с учётом карты темпа, опционально) и снэп
--   к нулевым переходам.
--   Точность в приоритете: анализ полностью на чистом Lua (свой FFT),
--   может занимать заметное время CPU на длинных файлах — это ожидаемо,
--   прогресс отображается в окне, обработка идёт частями между кадрами,
--   REAPER не блокируется.
--   Обученный фильтр нот: детектор берёт кандидатов с низким порогом, а
--   фильтр, обученный на реальных DI-записях с MIDI живой игры, отсеивает
--   лишние срабатывания (призвуки, шум, дребезг). Порог фильтра (по
--   умолчанию 20%) - больше = меньше нот.
--   «Самые короткие ноты в партии» (ноты ближе 70% их длительности считаются
--   одной): 1/8 или 1/8T - меньше лишних срабатываний на партиях восьмыми, но
--   более короткие ноты теряются; 1/16 (по умолчанию, не больше 70 мс);
--   1/32 - тремоло.
--   Привязка к сетке двигает ноту к ближайшей линии; лимит - доля шага сетки
--   (по умолчанию 50% = всегда к ближайшей).
--   Референс: в авто-режиме допуск для каждой ноты референса - половина
--   расстояния до соседней ноты (до 150 мс), живая игра отстаёт от сетки сильнее,
--   чем прежний допуск от мин. паузы.
--   Стрейч-маркер ставится ровно на найденное начало ноты: граница, где звук
--   склеивается с разной скоростью, маскируется атакой. Маркер в хвосте
--   предыдущей ноты или в сустейне (пробовали «запас до атаки» и «защиту
--   атаки») слышен как неестественный звук при любом режиме растяжения.
--   Повторное «Применить» заменяет
--   прошлые маркеры (результат анализа сохраняется). Если на item уже есть
--   стрейч-маркеры, анализ предложит их удалить. Снэп к нулевым переходам -
--   только при разрезании.
--   Разрезание: каждая нота удлиняется влево на 1/64 (или 1/128) ноты и
--   S-образным микрокроссфейдом наезжает на хвост предыдущей, обрезанный по
--   атаке; у нот, сдвинутых вправо (пауза), и при выключенном кроссфейде -
--   микрофейды 1 мс на краях кусков против щелчков.
--   Гибрид: как «Разрезать», но нота, после которой образовалась пауза,
--   дотягивается стрейч-маркерами до следующей (вся нота / после атаки / в
--   хвосте - на выбор) и кроссфейдом переходит в неё; «Предел растяжения»
--   (по умолчанию 25%) - больше не тянется, пауза остаётся.
--   «Склеить куски в один item после выравнивания» (для «Разрезать» и
--   «Гибрид»): куски склеиваются в новый файл (Glue), кроссфейды и растяжение
--   запекаются; выравнивание и склейка - один шаг отмены. «Оставить оригинал»
--   (при склейке): трек дублируется целиком (плагины, посылы) под оригиналом с
--   именем «... [Q]», выравнивается и склеивается копия, оригинальный трек в мьюте.
--   Шорох медиатора (для «Разрезать» и «Гибрид») можно относить к концу
--   предыдущей ноты или к началу своей и ставить на сетку атаку или шорох.
--   «Создать дабл-трек»: копия проанализированного item на новом треке -
--   имитация второго дубля без второй записи, гибрид приёмов студийного
--   удвоения (параметры по умолчанию - по разнице между настоящими дублями,
--   7 разных партий). На каждой ноте - лёгкое случайное дрожание тайминга и
--   высоты (как аппаратный/плагинный дублер): без этого часть нот звучала бы
--   совсем как оригинал, а часть - слишком по-другому, и при жёсткой панораме
--   это слышно как перескок между колонками. Громкость вместо этого плавно
--   «гуляет» на протяжении нескольких нот подряд, а не скачет по одной ноте -
--   так у настоящих дублей чаще, чем нет. Дрожание никогда не трогает, ЧТО звучит -
--   только тайминг/высоту/громкость СВОЕЙ же ноты, партия остаётся той же партией.
--   Поверх дрожания есть необязательный слой - «Заимствование, %» (по умолчанию
--   выключено: 0%): нота может занять звук другого повтора той же высоты не
--   дальше «Радиуса заимствования» и близкой громкости - настоящая вариация
--   исполнения, но это уже подмена того, что реально звучит в конкретный момент
--   (свой тайминг и место в партии не меняются, а вот исполнение этой ноты - да),
--   поэтому включается вручную, если нужна дополнительная живость. Высота донора
--   при этом подстраивается к своей ноте, а если нужная поправка слишком большая,
--   донор слишком короткий, или сама нота не согласуется по высоте ни с одним
--   соседом по времени (возможный сбой питч-детектора - путает с квинтой/октавой,
--   тогда заимствование только повторило бы эту ошибку явно и слышимо) -
--   заимствование пропускается. Похожие по высоте ноты группируются не жёсткой
--   сеткой полутонов, а по факту звучания. Галочка «Склеить дабл-трек» склеивает
--   его куски в один item.
-- @changelog
--   1.1 Обученный фильтр нот, поправка времени, сетка в % шага, референс и
--   дубли с окном по соседним нотам, повторное «Применить» заменяет маркеры,
--   блок «Выбрано в проекте», качество анализа только «Точно».
--   Разрезание: микрокроссфейд 1/64 / 1/128 / выкл вместо галочки кроссфейда.
--   Режим «Гибрид» с настраиваемым пределом растяжения, выбор места шороха
--   медиатора и что ставить на сетку. «Самые короткие ноты» (1/8, 1/8T, 1/16, 1/32);
--   прежний выбор мин. паузы переносится. Галочки «Склеить куски в один item» и «Оставить оригинал».
--   Убраны лишние настройки: веса признаков, строгость и выключение
--   фильтра, диапазон питча, ручной допуск референса, алгоритм и режим
--   растяжения, досочинение нот по ансамблю дублей, отладочный лог.
--   1.2 «Создать дабл-трек» - гибрид дрожания тайминга/высоты, плавного ухода
--   громкости по фразе и заимствования звука похожих повторов, значения по
--   умолчанию подобраны по настоящим дублям, галочка «Склеить дабл-трек».
--   + Релиз

----------------------------------------------------------------------
-- CONSTANTS (можно подстроить, если понадобится - не вынесено в GUI,
-- чтобы не перегружать интерфейс десятком редких технических полей)
----------------------------------------------------------------------
-- Константы самого детектора нот (диапазон питча, сглаживание, адаптивный порог) - в модуле, см. ниже.
----------------------------------------------------------------------
-- МОДУЛЬ ДЕТЕКТОРА НОТ: SSM_DI_Detector.lua. «Сэмплы -> кривые -> кандидаты нот с вероятностями ->
-- отбор нот» считает он (им же пользуется AI Drummer через tools/di_detector/cli.lua); здесь остаётся
-- всё, что касается REAPER: чтение звука item, темп проекта, окно, применение результата.
-- Где ищется файл модуля (первое найденное):
--   1. своя настройка REAPER: ExtState SSM_DI_Guitar_Align / detector_path (кнопка «Детектор…» в окне);
--   2. тесты и инструменты: папка из переменной SSM_DIR, затем папка SSM репозитория reaper-scripts, если
--      текущая папка - его корень или его папка dev (в REAPER нет ни того, ни другого);
--   3. общая папка проектов: <корень>\Code\reaper-scripts\SSM - тот же модуль, что у моста барабанщика
--      (tools/di_detector/cli.lua). Корень - как для кэша (см. drummer_root): SSM_ROOT -> SSM_WORKSPACE ->
--      настройка SSM_DrummerProject/root (её пишет окно AI Drummer) -> C:\DrummerProject;
--   4. рядом с этим скриптом (машина бота, старая установка).
-- Не найден - окно предлагает указать файл и запоминает путь в настройку.
----------------------------------------------------------------------
local DETECTOR_NAME = "SSM_DI_Detector.lua"
local DETECTOR_KEY = "detector_path" -- ключ в разделе SSM_DI_Guitar_Align (EXT_SECTION, объявлен ниже)
local DETECTOR_FROM_SETTING = "своя настройка (кнопка «Детектор…»)"
-- прежнее место корня DrummerProject (правило <корень>\_workspace\PORTABLE.md)
local ROOT_DEFAULT = [[C:\DrummerProject]]

-- значение ExtState или "" (в заглушках тестов GetExtState может не быть)
local function ext_get(section, key)
  local ok, v = pcall(function() return reaper.GetExtState(section, key) end)
  return (ok and type(v) == "string") and v or ""
end

-- Корень DrummerProject и папка общего файла путей (_workspace). Скрипт в REAPER запускается из копии в
-- %APPDATA%\REAPER\Scripts\SSM, вне корня, поэтому корень (правило <корень>\_workspace\PORTABLE.md): переменная
-- SSM_ROOT -> переменная SSM_WORKSPACE (её родитель) -> настройка REAPER SSM_DrummerProject/root (её пишет окно
-- AI Drummer) -> прежнее место C:\DrummerProject.
local function drummer_root()
  local root = os.getenv("SSM_ROOT")
  if root and root ~= "" then return root, root .. "/_workspace" end
  local ws = os.getenv("SSM_WORKSPACE")
  if ws and ws ~= "" then return ws .. "/..", ws end
  root = ext_get("SSM_DrummerProject", "root")
  if root ~= "" then return root, root .. "/_workspace" end
  return ROOT_DEFAULT, ROOT_DEFAULT .. [[\_workspace]]
end

local function readable(path)
  local fh = io.open(path, "rb")
  if fh then fh:close(); return true end
  return false
end

-- загрузить выбранный пользователем файл; -> модуль или nil и причина
local function load_detector(path)
  local ok, mod = pcall(dofile, path)
  if not ok then return nil, tostring(mod) end
  if type(mod) ~= "table" or type(mod.new_context) ~= "function" or type(mod.candidates) ~= "function" then
    return nil, "это не модуль детектора нот " .. DETECTOR_NAME
  end
  return mod
end

-- места поиска по порядку: { путь, откуда }
local function detector_places()
  local list = {}
  local set = ext_get("SSM_DI_Guitar_Align", DETECTOR_KEY)
  if set ~= "" then list[#list + 1] = { set, DETECTOR_FROM_SETTING } end
  local env = os.getenv("SSM_DIR")
  if env and env ~= "" then list[#list + 1] = { env .. "/" .. DETECTOR_NAME, "папка SSM_DIR (тесты и инструменты)" } end
  if readable("tools/di_detector/cli.lua") then
    list[#list + 1] = { "SSM/" .. DETECTOR_NAME, "репозиторий в текущей папке (тесты и инструменты)" }
  end
  if readable("../tools/di_detector/cli.lua") then
    list[#list + 1] = { "../SSM/" .. DETECTOR_NAME, "репозиторий над текущей папкой dev (тесты и инструменты)" }
  end
  list[#list + 1] = { drummer_root() .. [[\Code\reaper-scripts\SSM\]] .. DETECTOR_NAME, "общая папка проектов" }
  local src = debug.getinfo(1, "S").source or ""
  local dir = src:sub(1, 1) == "@" and src:sub(2):match("^(.*[/\\])")
  if dir then list[#list + 1] = { dir .. DETECTOR_NAME, "рядом со скриптом" } end
  return list
end

local Detector, DETECTOR_PATH, DETECTOR_FROM
do
  local tried = {}
  for _, place in ipairs(detector_places()) do
    local path, from = place[1], place[2]
    tried[#tried + 1] = path
    if readable(path) then
      if from == DETECTOR_FROM_SETTING then
        Detector = load_detector(path) -- не тот файл в настройке - ищем дальше
      else
        Detector = dofile(path)
      end
      if Detector then DETECTOR_PATH, DETECTOR_FROM = path, from; break end
    end
  end
  if not Detector then
    local msg = "Не найден модуль детектора нот " .. DETECTOR_NAME .. ".\n\nИскал:\n" .. table.concat(tried, "\n")
    if SSM_DI_ALIGN_LIBRARY then error(msg) end
    local answer = reaper.ShowMessageBox(msg .. "\n\nОбычно он лежит в <корень DrummerProject>\\Code\\reaper-scripts\\SSM.\n" ..
      "Указать файл сейчас? Путь запомнится (сменить потом - кнопка «Детектор…»).", "SSM DI Guitar Aligner", 4)
    if answer == 6 then
      local ok, path = reaper.GetUserFileNameForRead("", "Где лежит " .. DETECTOR_NAME .. "?", "lua")
      if ok and path and path ~= "" then
        local mod, why = load_detector(path)
        if mod then
          reaper.SetExtState("SSM_DI_Guitar_Align", DETECTOR_KEY, path, true)
          Detector, DETECTOR_PATH, DETECTOR_FROM = mod, path, DETECTOR_FROM_SETTING
        else
          reaper.ShowMessageBox("Файл не подошёл:\n" .. path .. "\n\n" .. tostring(why), "SSM DI Guitar Aligner", 0)
        end
      end
    end
    if not Detector then return end
  end
end
local PITCH_MIN_FREQ, PITCH_MAX_FREQ = Detector.PITCH_MIN_FREQ, Detector.PITCH_MAX_FREQ
local LOG_FLOOR_FACTOR = Detector.LOG_FLOOR_FACTOR
local ZC_SEARCH_MS             = 6       -- +/- окно поиска ближайшего нулевого перехода, мс
local MERGE_MIN_GAP_SEC        = 0.012   -- слияние соседних онсетов ближе этого порога после снэпа
local TIME_BUDGET_SEC          = 0.035   -- сколько секунд DSP-работы делать за один тик defer



-- Поиск ноты по звуку/питчу в окне (досочинение нот референса, см. local_onset_search).
local MICRO_SR                 = 22050
local MICRO_WIN                = 1024
local MICRO_HOP                = 128
local MICRO_PITCH_TOL_SEMITONES = 1.0 -- насколько близко по высоте тона считаем "та же нота"
local MICRO_MIN_SCORE          = 0.15 -- ниже этого - считаем, что в окне реально пусто, не вставляем
-- Минимальный радиус поиска, при котором окно вообще набирает MICRO_WIN+MICRO_HOP
-- сэмплов. При узком "Допуске синхронизации" (например, низкая "Мин. пауза" на
-- быстрых риффах) вычисленный радиус мог оказаться меньше этого технического
-- минимума - тогда local_onset_search раньше просто тихо возвращал nil без
-- всякой причины в логе. Теперь радиус снизу зажат этим значением - "Досочинять"
-- всегда реально ищет, а не отказывает молча из-за слишком узких настроек.
local MICRO_MIN_RADIUS_SEC     = (MICRO_WIN + MICRO_HOP) / (2 * MICRO_SR)

----------------------------------------------------------------------
-- ОБУЧЕННЫЙ ФИЛЬТР НОТ - веса и описание в модуле SSM_DI_Detector.lua (блок BEGIN/END LEARNED FILTER,
-- его переписывает tools/di_filter/train.py).
----------------------------------------------------------------------
local LEARNED_FILTER = Detector.LEARNED_FILTER

-- номер версии из строки "@version" этого файла - в заголовке окна видно, какая копия запущена
local SCRIPT_VERSION = (function()
  local ok, ver = pcall(function()
    local path = debug.getinfo(1, "S").source:gsub("^@", "")
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local head = fh:read(2048)
    fh:close()
    return head and head:match("@version%s+([%d%.]+)")
  end)
  return (ok and ver) and ("v" .. ver) or ""
end)()

local EXT_SECTION = "SSM_DI_Guitar_Align"
local MAX_ITEMS = 4 -- максимум items за раз (даблтрек/квадротрек)
-- Чтение буфера и скан пика (для калибровки log_floor) идут синхронно одним
-- куском в момент старта анализа, ДО первого тика прогресс-бара - на обычной
-- гитарной дорожке (единицы минут) незаметно, но на экстремально длинном
-- файле может на секунду-другую подвесить интерфейс. Ограничиваем длину item.
local MAX_ITEM_LEN_SEC = 300 -- 5 минут

-- Параметры анализа (частота, окна и шаги кадров) - в модуле детектора: единственный пресет "Точно",
-- фильтр нот обучен именно на его признаках.
local QUALITY_PRESETS = { Detector.PRESET }

local OUTPUT_MODES = { "Stretch-маркеры", "Разрезать", "SSM" }

-- Для авто-расчёта "Мин. паузы между нотами" из темпа проекта: длительности
-- покороче/потриольнее в список не включены - на гитаре 1/32 уже практический
-- предел, а секстоль по интервалу между соседними нотами не отличается от
-- 1/16-триоли (секстоль = удвоенная триоль), отдельно её указывать не нужно.
local NOTE_LENGTH_OPTIONS = {
  { label = "1/4",   qn = 1.0 },
  { label = "1/8",   qn = 0.5 },
  { label = "1/8T",  qn = 0.5 * 2 / 3 },
  { label = "1/16",  qn = 0.25 },
  { label = "1/16T", qn = 0.25 * 2 / 3 },
  { label = "1/32",  qn = 0.125 },
}

-- Те же длительности + пункт "Грид" (qn=nil -> берём шаг из грида проекта,
-- см. get_project_grid_qn_step) - строится из NOTE_LENGTH_OPTIONS, чтобы не
-- дублировать один и тот же список длительностей в двух таблицах.
local GRID_MODES = { { label = "Грид", qn = nil } }
for _, o in ipairs(NOTE_LENGTH_OPTIONS) do
  GRID_MODES[#GRID_MODES + 1] = o
end
-- «Авто» - шаг сетки берётся из анализа (триоли/прямые, см. auto_grid_state ниже).
-- Добавлена последней, чтобы не сдвинуть существующие индексы (ExtState grid_mode_idx).
GRID_MODES[#GRID_MODES + 1] = { label = "Авто", qn = nil, auto = true }

-- «Самые короткие ноты в партии» -> мин. пауза между нотами = 70% их длительности (ноты ближе
-- считаются одной). 1/16 - не больше 70 мс (на этом значении обучен фильтр; до 150 bpm это
-- ровно 70 мс). 1/8 и 1/8T - для партий без 1/16: меньше лишних срабатываний между
-- восьмыми (28 записей: лишних 97 -> 72), но ноты ближе паузы теряются (триоли и 1/16
-- при выборе 1/8). 1/32 - тремоло, на обычных партиях +40% лишних.
local SHORTEST_NOTES = {
  { label = "1/8", qn = 0.5 },
  { label = "1/8T", qn = 0.5 * 2 / 3 },
  { label = "1/16", qn = 0.25, cap = 0.070 },
  { label = "1/32 тремоло", qn = 0.125 },
  -- «Авто» - определяется по интервалам между нотами (как в AI Drummer, см.
  -- resolve_auto_shortest). Добавлена последней, чтобы не сдвинуть индексы 1-4
  -- (ExtState shortest_idx, миграция настроек со старых версий).
  { label = "Авто", auto = true },
}
local SHORTEST_DEFAULT = 3
-- Индекс «1/32 тремоло» в SHORTEST_NOTES - нужен автосетке (GRID_MODES «Авто»):
-- при самых коротких 1/32 триольный шаг сетки мельче (1/16T), чем обычно (1/8T).
local SHORTEST_IDX_32 = 4

----------------------------------------------------------------------
-- SETTINGS (persisted via ExtState)
----------------------------------------------------------------------
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function load_num(key, default)
  local v = tonumber(reaper.GetExtState(EXT_SECTION, key))
  return v or default
end

local S = {
  quality_idx   = 1, -- единственный пресет анализа ("Точно"), не настраивается
  -- веса признаков детектора: не настраиваются - на них обучен фильтр нот
  w_flux        = 100,
  w_hfc         = 50,
  w_pitch       = 100,
  -- обученный фильтр нот всегда; прежний порог строгости остался только внутри - как
  -- эталон для сравнения в тестах (smart_filter = 0, sensitivity)
  sensitivity   = 110,
  smart_filter  = 1,
  filter_pct    = load_num("filter_pct", 20),    -- порог уверенности фильтра, % (больше = меньше нот)
  shortest_idx  = load_num("shortest_idx", 0), -- самые короткие ноты партии, см. SHORTEST_NOTES (0 - ещё не выбрано)
  zerocross     = load_num("zerocross", 1),
  gridsnap      = load_num("gridsnap", 0),
  grid_mode_idx = load_num("grid_mode_idx", 1),
  -- Лимит привязки к сетке - доля шага сетки, а не миллисекунды: на реальных записях
  -- (13 партий с MIDI) нота на сетке 1/8 при 150 bpm бывает до ~100 мс от своей линии,
  -- и прежний лимит 60 мс оставлял её на месте (совпадение с эталоном 88.7%). При 50%
  -- (= всегда к ближайшей линии) совпадение 96.5%, при 40% - 92.4%. Ключ новый, старое
  -- значение в мс не переносится.
  grid_max_pct  = load_num("grid_max_pct", 50),
  output_mode   = load_num("output_mode", 1),
  split_xfade_idx = load_num("split_xfade_idx", 1),     -- при "Разрезать"/"Гибрид": микрокроссфейд, см. SPLIT_XFADES
  hybrid_marker_idx = load_num("hybrid_marker_idx", 1), -- "Гибрид": что растягивать, см. HYBRID_MARKERS
  pick_to_idx = load_num("pick_to_idx", 1),             -- шорох медиатора: 1 - к концу пред. ноты, 2 - к началу ноты
  pick_align_idx = load_num("pick_align_idx", 1),       -- шорох к началу: 1 - на сетку атака, 2 - на сетку шорох
  glue_after    = load_num("glue_after", 0),            -- "Разрезать"/"Гибрид": склеить куски в один item после выравнивания
  keep_original = load_num("keep_original", 0),         -- при склейке: оригинал на заглушённом треке, результат - на копии трека "[Q]"
  double_glue   = load_num("double_glue", 0),           -- "Создать дабл-трек": склеить его куски в один item
  double_window_sec = load_num("double_window_sec", 2.0), -- "Создать дабл-трек": радиус заимствования звука, с
  -- Значения по умолчанию для дрожания и плавного ухода громкости - по разнице между
  -- НАСТОЯЩИМИ дублями (7 разных партий, 107-175bpm, 809 пар нот, не одна запись):
  -- тайминг std ~13-19 мс (по партиям, среднее по больше выборке ближе к 18); высота -
  -- сырое std сотни центов, но это почти целиком шум питч-детектора (у части нот
  -- скачки на октавы - см. PITCH_CORRECTION_MAX_CENTS); после отсева выбросов
  -- (робастная оценка MAD) настоящая разница ~14-16 центов; громкость std ~2.1-2.6 дБ.
  double_jitter_ms = load_num("double_jitter_ms", 18),    -- "Создать дабл-трек": дрожание тайминга, ± мс, на каждой ноте
  double_jitter_cents = load_num("double_jitter_cents", 15), -- "Создать дабл-трек": дрожание высоты, ± центов, на каждой ноте
  double_level_db = load_num("double_level_db", 2.5),    -- "Создать дабл-трек": плавный уход громкости по фразе, ± дБ
  double_swap_pct = load_num("double_swap_pct", 0),      -- "Создать дабл-трек": доля нот, заимствующих звук похожего повтора, % (0 = выкл по умолчанию - заимствование меняет, ЧТО реально звучит в партии, а не только тайминг/высоту/громкость своей же ноты)
  -- Звук растяжения (для сравнения на слух; при каждом "Применить" записывается в take):
  ensemble_mode = load_num("ensemble_mode", 1),        -- сводить дубли (2+ items) по консенсусу
  reference_mode = load_num("reference_mode", 0),               -- подтягивать группу к захваченному референсу
  reference_inject = load_num("reference_inject", 0),           -- досочинять ноты референса, которых нет у item
  -- Единый "допуск синхронизации" (насколько близко = та же нота) для ОБОИХ
  -- случаев - дубли между собой и группа-к-референсу. Раньше было 4 разных
  -- мс-настройки без понятных ориентиров - теперь одна, привязанная к уже
  -- посчитанной "Мин. паузе" (то есть к темпу проекта), как и просили.
  -- "та же нота" для дублей и референса - всегда авто (половина расстояния до соседней ноты)
  sync_tolerance_mode = 1,
  sync_tolerance_pct = 45,  -- радиус поиска ноты по звуку при досочинении нот референса
  sync_tolerance_ms = 40,
  debug         = 0,        -- отладочный лог в консоль REAPER (включается только в коде)
  hybrid_max_stretch_pct = load_num("hybrid_max_stretch_pct", 25), -- "Гибрид": предел растяжения ноты, %
  win_x         = load_num("win_x", 260),
  win_y         = load_num("win_y", 160),
}

S.grid_mode_idx = clamp(math.floor(S.grid_mode_idx + 0.5), 1, #GRID_MODES)
S.grid_max_pct  = clamp(math.floor(S.grid_max_pct + 0.5), 5, 50)
S.filter_pct    = clamp(math.floor(S.filter_pct + 0.5), 1, 95)
S.output_mode   = clamp(math.floor(S.output_mode + 0.5), 1, #OUTPUT_MODES)
S.split_xfade_idx = clamp(math.floor(S.split_xfade_idx + 0.5), 1, 3)
S.hybrid_marker_idx = clamp(math.floor(S.hybrid_marker_idx + 0.5), 1, 3)
S.pick_to_idx = clamp(math.floor(S.pick_to_idx + 0.5), 1, 2)
S.pick_align_idx = clamp(math.floor(S.pick_align_idx + 0.5), 1, 2)
-- Перенос выбора из прошлых версий: "самые короткие ноты" 1/16 | 1/32 или "мин. пауза: авто
-- по длительности ноты" (ещё раньше) - иначе после обновления пауза молча стала бы другой.
if S.shortest_idx < 1 then
  local old_short = tonumber(reaper.GetExtState(EXT_SECTION, "shortest_note_idx"))
  local old_mode = tonumber(reaper.GetExtState(EXT_SECTION, "min_gap_mode"))
  local old_note = tonumber(reaper.GetExtState(EXT_SECTION, "min_gap_note_idx"))
  if old_short == 2 then
    S.shortest_idx = 4
  elseif old_mode == 2 and old_note then
    -- NOTE_LENGTH_OPTIONS: 1/4, 1/8, 1/8T, 1/16, 1/16T, 1/32
    S.shortest_idx = ({ 1, 1, 2, 3, 3, 4 })[math.floor(old_note)] or SHORTEST_DEFAULT
  else
    S.shortest_idx = SHORTEST_DEFAULT
  end
end
S.shortest_idx = clamp(math.floor(S.shortest_idx + 0.5), 1, #SHORTEST_NOTES)
S.hybrid_max_stretch_pct = clamp(math.floor(S.hybrid_max_stretch_pct + 0.5), 5, 100)
S.double_window_sec = clamp(S.double_window_sec, 0.3, 10)
S.double_jitter_ms = clamp(math.floor(S.double_jitter_ms + 0.5), 0, 30)
S.double_jitter_cents = clamp(math.floor(S.double_jitter_cents + 0.5), 0, 50)
S.double_level_db = clamp(S.double_level_db, 0, 9)
S.double_swap_pct = clamp(math.floor(S.double_swap_pct + 0.5), 0, 100)

local function get_pitch_min_freq()
  return PITCH_MIN_FREQ
end

local function save_settings()
  for k, v in pairs(S) do
    reaper.SetExtState(EXT_SECTION, k, tostring(v), true)
  end
end

-- fmt/... вместо готовой строки - чтобы string.format не считался впустую на
-- каждый вызов, когда лог выключен (а часть мест зовутся на каждую ноту/маркер)
local function dbg(fmt, ...)
  if S.debug ~= 1 then return end
  local msg = (select("#", ...) > 0) and string.format(fmt, ...) or tostring(fmt)
  reaper.ShowConsoleMsg("[DI Align] " .. msg .. "\n")
end

----------------------------------------------------------------------
-- FFT, оконная функция и питч-трекер - в модуле детектора. Здесь они нужны для поиска ноты по
-- звуку при досочинении нот референса (см. local_onset_search).
----------------------------------------------------------------------
local fft_precalc, fft_run, make_hann = Detector.fft_precalc, Detector.fft_run, Detector.make_hann
local extract_frame, magnitude_spectrum = Detector.extract_frame, Detector.magnitude_spectrum
local estimate_pitch = Detector.estimate_pitch

----------------------------------------------------------------------
-- AUDIO READING
----------------------------------------------------------------------
local function array_to_table(arr, n)
  local ok, t = pcall(function() return arr:table() end)
  if ok and type(t) == "table" then return t end
  local t2 = {}
  for i = 1, n do
    local ok2, v = pcall(function() return arr[i] end)
    t2[i] = (ok2 and v) or 0
  end
  return t2
end

-- Проверяет выбор: от 1 до MAX_ITEMS аудио-items (для даблтрека/квадротрека).
-- Каждый анализируется независимо по своему собственному звуку - онсеты одного
-- дубля НЕ копируются на другие, дубли редко идеально синхронны по факту записи.
-- Возвращает список {item, take, track} или nil+сообщение.
local function get_selected_audio_items()
  local cnt = reaper.CountSelectedMediaItems(0)
  if cnt == 0 then return nil, "Выберите от 1 до " .. MAX_ITEMS .. " аудио item(ов)." end
  if cnt > MAX_ITEMS then
    return nil, string.format("Выбрано %d items, максимум %d за раз.", cnt, MAX_ITEMS)
  end

  local list = {}
  for i = 0, cnt - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if not take then return nil, "У одного из items нет активного тейка." end
    if reaper.TakeIsMIDI(take) then return nil, "Один из items - MIDI-тейк, нужны аудио-тейки." end
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    if len > MAX_ITEM_LEN_SEC then
      return nil, string.format(
        "Item длиннее %d мин (%.1f мин) - чтение/скан идёт синхронно и подвесит интерфейс. Разрежьте на части короче.",
        MAX_ITEM_LEN_SEC / 60, len / 60)
    end
    local track = reaper.GetMediaItemTrack(item)
    list[#list + 1] = { item = item, take = take, track = track }
  end
  return list
end

-- reaper.array не позволяет выделить произвольно большой буфер одним куском
-- (на длинных item на "Точном" пресете легко превысить лимит) - читаем частями.
local READ_CHUNK_SAMPLES = 1024 * 1024

-- Читает весь item одним моно-буфером (по частям) на заданной частоте анализа.
-- Время буфера = абсолютное время проекта (item_start .. item_start+item_len).
local function read_mono_buffer(item, take, target_sr)
  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len    = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  if item_len <= 0 then return nil, "Нулевая длина item." end

  local AA = reaper.CreateTakeAudioAccessor(take)
  if not AA then return nil, "Не удалось создать audio accessor." end

  local nsamples = math.floor(item_len * target_sr + 0.5)
  if nsamples < 8 then
    reaper.DestroyAudioAccessor(AA)
    return nil, "Item слишком короткий для анализа."
  end

  local samples = {}
  local arr = reaper.new_array(math.min(READ_CHUNK_SAMPLES, nsamples))
  local offset = 0

  while offset < nsamples do
    local chunk = math.min(READ_CHUNK_SAMPLES, nsamples - offset)
    local t_start = item_start + offset / target_sr
    local ok = reaper.GetAudioAccessorSamples(AA, target_sr, 1, t_start, chunk, arr)
    if ok == nil or ok < 0 then
      reaper.DestroyAudioAccessor(AA)
      return nil, "Ошибка чтения аудио (GetAudioAccessorSamples)."
    end
    local chunk_tab = array_to_table(arr, chunk)
    for i = 1, chunk do
      samples[offset + i] = chunk_tab[i]
    end
    offset = offset + chunk
  end

  reaper.DestroyAudioAccessor(AA)
  return samples, nil, nsamples, item_start, item_len
end

----------------------------------------------------------------------
-- ANALYSIS STATE MACHINE (инкрементальная обработка между кадрами defer,
-- чтобы не блокировать REAPER на тяжёлых файлах)
----------------------------------------------------------------------
local ctx = nil            -- активный контекст анализа ТЕКУЩЕГО item очереди, nil если не анализируем
local queue = nil          -- {items={{item,take,track},...}, idx, count, results={}, start_time}
local apply_status = nil   -- строка под кнопками: что сделало последнее "Применить" (время, маркеры)
local double_status = nil  -- строка под кнопкой "Создать дабл-трек": что сделал последний клик
local last_results = nil   -- список результатов по каждому item: {raw_onsets, take, item, track, item_start, item_len, sr}
local last_batch_info = nil -- {elapsed, item_count, total_onsets} - для отображения "Готово" после очереди
local last_applied = nil   -- список {mode, take, item, entries={...}} по item - последний Apply в режиме
                            -- Stretch-маркеров: позволяет мгновенно переключать сетку туда-обратно
local reference = nil      -- {kind="midi"|"audio", track, item, take, item_start, item_len,
                            --  notes={{time=.., pitch=..}, ...}} - захваченный референс-трек (та же партия гитары)

-- «Авто» для самых коротких нот/сетки - состояние на ВСЮ очередь (не на item),
-- сбрасывается в start_analysis, копится в step_analysis (фаза "peaks", только
-- queue.mode == "main"). shortest = самая мелкая (наибольший индекс в
-- SHORTEST_NOTES) из найденных по items; grid = счётчики триольных/прямых
-- позиций, суммарно по всем items (независимо от того, авто ли "самые
-- короткие ноты" - сетка "Авто" должна работать и при ручном выборе).
local auto_shortest_state = nil -- nil пока не определено, иначе {idx = <индекс в SHORTEST_NOTES>}
local auto_grid_state = nil     -- nil пока не определено, иначе {n_trip = N, n_straight = N}

----------------------------------------------------------------------
-- ENSEMBLE CONSENSUS (сведение дублей / даблтрека друг к другу).
-- Каждый item анализируется независимо по своему звуку (детектор не угадывает,
-- а честно находит, что реально сыграно) - ошибку игры детектором не починить,
-- её можно только СКОРРЕКТИРОВАТЬ смещением к тому, что сыграло большинство.
----------------------------------------------------------------------
local function median(list)
  table.sort(list)
  local n = #list
  if n == 0 then return nil end
  if n % 2 == 1 then return list[(n + 1) / 2] end
  return (list[n / 2] + list[n / 2 + 1]) / 2
end

-- Кластеризует онсеты ВСЕХ items по времени (простой greedy: попадает в
-- текущий кластер, если ближе tolerance_sec к последнему добавленному).
-- Кластер с >=2 разными items - это "одна и та же нота у нескольких дублей":
-- консенсус = медиана их позиций (устойчива к одному выбросу; для 2 items
-- медиана = среднее, то есть мягкое подтягивание друг к другу без "виноватых").
-- Кластер с 1 item - никто больше не сыграл ноту здесь (или наоборот - этот
-- item сыграл лишнюю/не туда) - не трогаем, только помечаем для проверки.
-- Возвращает: consensus_lookup[item_idx][onset_idx] = время или nil,
--             per_item_stats[item_idx] = {matched, missed, unmatched, sum_abs_dev}
-- Третье возвращаемое значение - сами кластеры (с .consensus и .by_item у тех,
-- где нашлось совпадение).

-- Реальная длительность одной четверти (QN) в секундах В ТОЧКЕ time_pos -
-- через карту темпа проекта (учитывает изменения темпа, не просто общий BPM).
local function seconds_per_qn_at(time_pos)
  local qn0 = reaper.TimeMap2_timeToQN(0, time_pos)
  local t1 = reaper.TimeMap2_QNToTime(0, qn0 + 1)
  return t1 - time_pos
end

-- Возвращает ДЕЙСТВУЮЩУЮ запись SHORTEST_NOTES: для ручного выбора - её же
-- (без изменений, поведение байт-в-байт как раньше); для «Авто» - то, во что
-- она разрешилась по итогам анализа очереди (auto_shortest_state), а до
-- первого анализа - запись по умолчанию (1/16, см. SHORTEST_DEFAULT).
local function effective_shortest_entry()
  local o = SHORTEST_NOTES[S.shortest_idx]
  if o.auto then
    if auto_shortest_state then return SHORTEST_NOTES[auto_shortest_state.idx] end
    return SHORTEST_NOTES[SHORTEST_DEFAULT]
  end
  return o
end

-- "Мин. пауза между нотами" (защита от ретригера ниже) - либо значение в мс,
-- заданное вручную, либо вычисленное из темпа проекта и выбранной "самой
-- короткой ноты в песне" с запасом (человек не играет идеально по сетке -
-- без запаса живой тайминг будет резать настоящие ноты).
-- Мин. пауза между нотами (защита от повторного срабатывания на одной ноте) - от темпа
-- проекта, по выбору «Самые короткие ноты» (см. SHORTEST_NOTES).
-- entry_override - для двухпроходного разбора «Авто» в finish_peaks: сначала
-- принимаем атаки с самой мелкой записью (1/32), затем по ним определяем
-- запись и повторяем приём уже с ней (пересчитывать спектр не нужно).
local function get_min_gap_sec(time_pos, entry_override)
  local o = entry_override or effective_shortest_entry()
  return Detector.min_gap_sec(seconds_per_qn_at(time_pos), o.qn, o.cap)
end

-- Доля атак, попавших в триольные (k=8/16 от деления четверти на 24 части -
-- 1/3 и 2/3 доли) и прямые (k=6/12/18 - 1/4, 1/2, 3/4) позиции сетки. Та же
-- логика, что в AI Drummer (metal-drum-composer/generate.py), для сетки
-- «Авто» (GRID_MODES) - не зависит от того, авто ли "самые короткие ноты".
local function count_trip_straight(times)
  local n_trip, n_straight = 0, 0
  for _, t in ipairs(times) do
    local qn = reaper.TimeMap2_timeToQN(0, t)
    local frac = qn - math.floor(qn)
    local k = math.floor(frac * 24 + 0.5) % 24
    if k == 8 or k == 16 then
      n_trip = n_trip + 1
    elseif k == 6 or k == 12 or k == 18 then
      n_straight = n_straight + 1
    end
  end
  return n_trip, n_straight
end

-- Автоопределение «самых коротких нот» по интервалам между атаками (та же
-- логика и пороги, что auto_shortest() в AI Drummer - generate.py, подобрано
-- на 32 DI-записях). times - атаки, принятые с САМОЙ мелкой записью (1/32),
-- чтобы ничего мельче заданного порога не потерять до разбора. Возвращает
-- индекс в SHORTEST_NOTES.
local AUTO_P32, AUTO_P16, AUTO_PT = 0.3, 0.15, 0.3
local function resolve_auto_shortest(times)
  if #times < 2 then return SHORTEST_DEFAULT end
  local sorted = {}
  for i, t in ipairs(times) do sorted[i] = t end
  table.sort(sorted)
  local n32, n16, nt, n8, total = 0, 0, 0, 0, 0
  for i = 2, #sorted do
    local qn1 = reaper.TimeMap2_timeToQN(0, sorted[i - 1])
    local qn2 = reaper.TimeMap2_timeToQN(0, sorted[i])
    local v = qn2 - qn1
    if v > 0.09 and v < 1.2 then
      total = total + 1
      if v <= 0.1875 then n32 = n32 + 1
      elseif v <= 0.29 then n16 = n16 + 1
      elseif v <= 0.4 then nt = nt + 1
      elseif v <= 0.6 then n8 = n8 + 1 end
    end
  end
  if total == 0 then return SHORTEST_DEFAULT end
  local p32, p16, pt = n32 / total, n16 / total, nt / total
  if p32 >= AUTO_P32 then return SHORTEST_IDX_32 end
  if pt >= AUTO_PT and pt > p16 then return 2 end -- "1/8T"
  if p16 >= AUTO_P16 then return 3 end            -- "1/16"
  return 1                                        -- "1/8"
end

-- Радиус поиска при досочинении (ensemble/reference) - всегда шире допуска
-- совпадения: даём запас на неточность интерполяции предполагаемой позиции.
local INJECT_RADIUS_MULT = 1.5

-- Единый "допуск синхронизации" - насколько близко по времени считать два
-- онсета "той же нотой" (у дублей между собой ИЛИ у группы с референсом).
-- Авто-режим: доля от "Мин. паузы" (та же тёмпо-карта проекта) - тем самым
-- одной настройкой темпа управляются сразу оба места, вместо четырёх
-- независимых мс-значений без понятных ориентиров.
local function get_sync_tolerance_sec(time_pos)
  if S.sync_tolerance_mode == 2 then
    return S.sync_tolerance_ms / 1000
  end
  return get_min_gap_sec(time_pos) * (S.sync_tolerance_pct / 100)
end

-- Окна допуска "та же нота" (для референса и для сведения дублей). В авто-режиме окно
-- каждой ноты - половина расстояния до соседней (не больше REF_TOL_CAP_SEC): окна
-- соседних нот не пересекаются, поэтому нота не может уйти к чужой. Живая игра
-- отстаёт от сетки и дубли расходятся между собой на 20-100 мс - прежний допуск
-- "% от мин. паузы" (~32 мс) на реальных записях сводил мало: референс - 68% нот
-- (стало 99.3%), дубли Bloodlust x3 - 87% (стало 99.6%), пара Tets4/5 - 67% (стало
-- 100%), пара с вариациями Tets3/PM - 21% (стало 83%). Ручной режим (мс) - одно окно на все.
local REF_TOL_NEIGHBOR = 0.5
local REF_TOL_CAP_SEC = 0.150

-- notes - список {time=...}, отсортированный по времени
local function reference_tolerances(notes, fixed_sec)
  local tols = {}
  for ri, rn in ipairs(notes) do
    if S.sync_tolerance_mode == 2 then
      tols[ri] = fixed_sec
    else
      local gap = math.huge
      if notes[ri - 1] then gap = math.min(gap, rn.time - notes[ri - 1].time) end
      if notes[ri + 1] then gap = math.min(gap, notes[ri + 1].time - rn.time) end
      tols[ri] = math.min(REF_TOL_CAP_SEC, REF_TOL_NEIGHBOR * gap)
    end
  end
  return tols
end

-- Сведение дублей: дубли по очереди (начиная с дубля, где найдено больше всего нот)
-- сопоставляются с уже собранными нотами группы. Для каждой ноты группы берётся
-- ближайшая нота дубля в её окне допуска, остальные ноты дубля становятся новыми
-- нотами группы. Нота группы, где есть 2+ дубля, получает консенсус - медиану.
local function compute_consensus(results, tolerance_sec)
  local consensus_lookup, per_item_stats = {}, {}
  for ti = 1, #results do
    consensus_lookup[ti] = {}
    per_item_stats[ti] = { matched = 0, missed = 0, unmatched = 0, sum_abs_dev = 0 }
  end
  if #results < 2 then return consensus_lookup, per_item_stats, {} end

  local order = {}
  for ti = 1, #results do order[ti] = ti end
  table.sort(order, function(a, b)
    local na, nb = #results[a].raw_onsets, #results[b].raw_onsets
    if na ~= nb then return na > nb end
    return a < b
  end)

  local function center(cl)
    local ts = {}
    for _, m in pairs(cl.by_item) do ts[#ts + 1] = m.time end
    return median(ts)
  end

  local clusters = {}
  for _, ti in ipairs(order) do
    local onsets = results[ti].raw_onsets
    if #clusters == 0 then
      for oi, t in ipairs(onsets) do
        clusters[#clusters + 1] = { by_item = { [ti] = { time = t, item_idx = ti, onset_idx = oi } }, time = t }
      end
    else
      local tols = reference_tolerances(clusters, tolerance_sec)
      -- лучшая (ближайшая) нота дубля для каждой ноты группы; окна не пересекаются,
      -- в ручном режиме (одно окно на всех) - ближайшие пары разбираются первыми
      local pairs_list = {}
      local k0 = 1
      for oi, t in ipairs(onsets) do
        while k0 <= #clusters and clusters[k0].time < t - REF_TOL_CAP_SEC - tolerance_sec do k0 = k0 + 1 end
        local k = k0
        while k <= #clusters and clusters[k].time <= t + REF_TOL_CAP_SEC + tolerance_sec do
          local d = math.abs(clusters[k].time - t)
          if d <= tols[k] then pairs_list[#pairs_list + 1] = { k = k, oi = oi, d = d } end
          k = k + 1
        end
      end
      table.sort(pairs_list, function(a, b) return a.d < b.d end)
      local used_k, used_o = {}, {}
      for _, pr in ipairs(pairs_list) do
        if not used_k[pr.k] and not used_o[pr.oi] then
          used_k[pr.k], used_o[pr.oi] = true, true
          clusters[pr.k].by_item[ti] = { time = onsets[pr.oi], item_idx = ti, onset_idx = pr.oi }
        end
      end
      for oi, t in ipairs(onsets) do
        if not used_o[oi] then
          clusters[#clusters + 1] = { by_item = { [ti] = { time = t, item_idx = ti, onset_idx = oi } }, time = t }
        end
      end
      for _, cl in ipairs(clusters) do cl.time = center(cl) end
      table.sort(clusters, function(a, b) return a.time < b.time end)
    end
  end

  for _, cl in ipairs(clusters) do
    local by_item = cl.by_item
    local times, n_present = {}, 0
    for _, m in pairs(by_item) do n_present = n_present + 1; times[#times + 1] = m.time end

    if n_present >= 2 then
      local cons = median(times)
      cl.consensus = cons
      cl.by_item = by_item
      cl.n_present = n_present
      for item_idx, m in pairs(by_item) do
        consensus_lookup[item_idx][m.onset_idx] = cons
        local st = per_item_stats[item_idx]
        st.matched = st.matched + 1
        st.sum_abs_dev = st.sum_abs_dev + math.abs(m.time - cons)
      end
      for ti = 1, #results do
        if not by_item[ti] then per_item_stats[ti].missed = per_item_stats[ti].missed + 1 end
      end
    else
      for item_idx, _ in pairs(by_item) do
        per_item_stats[item_idx].unmatched = per_item_stats[item_idx].unmatched + 1
      end
    end
  end

  return consensus_lookup, per_item_stats, clusters
end

-- Человекочитаемый отчёт: у какого дубля больше расхождений с группой.
local function describe_ensemble(results, per_item_stats, tolerance_sec)
  if #results < 2 then return nil end
  local lines = { S.sync_tolerance_mode == 2
    and string.format("Сведение %d дублей (допуск %d мс):", #results, math.floor(tolerance_sec * 1000))
    or string.format("Сведение %d дублей (допуск по соседним нотам):", #results) }
  local worst_idx, worst_score = nil, -1
  for ti, res in ipairs(results) do
    local st = per_item_stats[ti]
    local mean_dev_ms = (st.matched > 0) and (st.sum_abs_dev / st.matched * 1000) or 0
    local _, tname = reaper.GetTrackName(res.track)
    lines[#lines + 1] = string.format("  %s: совпало=%d, пропущено=%d, лишних=%d, ср.отклонение=%.1fмс",
      tname or ("item " .. ti), st.matched, st.missed, st.unmatched, mean_dev_ms)
    local score = st.missed + st.unmatched + mean_dev_ms / 10
    if score > worst_score then worst_score = score; worst_idx = ti end
  end
  if worst_idx and worst_score > 0.5 then
    local _, tname = reaper.GetTrackName(results[worst_idx].track)
    lines[#lines + 1] = string.format("Больше всего расхождений у: %s - стоит послушать этот дубль отдельно.",
      tname or ("item " .. worst_idx))
  else
    lines[#lines + 1] = "Дубли играют ровно, заметных расхождений нет."
  end
  return table.concat(lines, "\n")
end

-- Оценивает, насколько СОБСТВЕННЫЙ тайминг item обычно смещён относительно
-- какого-то внешнего ориентира (консенсус дублей ИЛИ референс-трек) РЯДОМ с
-- target_time - линейная интерполяция смещения по уже совпавшим "якорям" до и
-- после, а не сырое время ориентира напрямую: у каждого дубля своя манера
-- (чуть спешит/тянет), и предположение должно её учитывать, а не считать, что
-- "слабый" дубль играет ровно как ориентир.
-- anchors - список {raw=.., matched=..} (собственное время item и время
-- ориентира) - НЕ индекс-based lookup: источники (консенсус по индексам
-- res.raw_onsets, референс по индексам уже пересобранного списка final) имеют
-- разную индексацию, единый по смыслу список пар избавляет от риска их перепутать.
local function estimate_offset_at(anchors, target_time)
  local before_t, before_off = nil, nil
  local after_t, after_off = nil, nil
  for _, a in ipairs(anchors) do
    local off = a.raw - a.matched
    if a.raw <= target_time and (not before_t or a.raw > before_t) then before_t, before_off = a.raw, off end
    if a.raw >= target_time and (not after_t or a.raw < after_t) then after_t, after_off = a.raw, off end
  end
  if before_t and after_t and after_t > before_t then
    local frac = (target_time - before_t) / (after_t - before_t)
    return before_off + (after_off - before_off) * frac
  elseif before_t then
    return before_off
  elseif after_t then
    return after_off
  end
  return 0
end

-- Микро-поиск ноты в реальном звуке item вокруг candidate_time (радиус
-- radius_sec). Переиспользует тот же FFT-движок, что и основной анализ, но в
-- маленьком масштабе: лог-сжатый spectral flux + (если известен эталонный
-- питч от согласных дублей) точный поиск именно этой высоты тона - это и есть
-- "сравнение контекста", а не просто общий порог. Возвращает время лучшего
-- совпадения или nil, если в окне реально пусто (даже по питчу ничего похожего).
local function local_onset_search(take, candidate_time, radius_sec, target_pitch)
  radius_sec = math.max(radius_sec, MICRO_MIN_RADIUS_SEC)
  local start_t = candidate_time - radius_sec
  local nsamples = math.floor(radius_sec * 2 * MICRO_SR)
  if nsamples < MICRO_WIN + MICRO_HOP then return nil end

  local AA = reaper.CreateTakeAudioAccessor(take)
  if not AA then return nil end
  local arr = reaper.new_array(nsamples)
  local ok = reaper.GetAudioAccessorSamples(AA, MICRO_SR, 1, start_t, nsamples, arr)
  reaper.DestroyAudioAccessor(AA)
  if ok == nil or ok < 0 then return nil end
  local buf = array_to_table(arr, nsamples)

  local peak = 1e-6
  for i = 1, nsamples do
    local a = buf[i]; if a < 0 then a = -a end
    if a > peak then peak = a end
  end
  if peak < 1e-5 then return nil end -- буфер практически пуст (обрыв/тишина канала) - вставлять некуда

  local floor = MICRO_WIN * peak * LOG_FLOOR_FACTOR
  if floor < 1e-9 then floor = 1e-9 end
  local inv_floor = 1 / floor

  local tabs = fft_precalc(MICRO_WIN)
  local hann = make_hann(MICRO_WIN)
  local half = MICRO_WIN / 2 + 1
  local re, im, mag = {}, {}, {}
  local prev_logmag = {}
  for k = 1, half do prev_logmag[k] = 0 end

  local n_frames = math.max(0, math.floor((nsamples - MICRO_WIN) / MICRO_HOP) + 1)
  if n_frames < 2 then return nil end

  local flux_list, pitch_score_list, time_list = {}, {}, {}
  local flux_max = 1e-9

  for i = 0, n_frames - 1 do
    local s1 = i * MICRO_HOP + 1

    extract_frame(buf, nsamples, s1, MICRO_WIN, hann, re, im)
    fft_run(re, im, tabs, false)
    magnitude_spectrum(re, im, half, mag)

    local logmag = {}
    for k = 1, half do logmag[k] = math.log(1 + mag[k] * inv_floor) end
    local flux = 0
    for k = 1, half do
      local d = logmag[k] - prev_logmag[k]
      if d > 0 then flux = flux + d end
      prev_logmag[k] = logmag[k]
    end

    local pscore = 0
    if target_pitch then
      -- estimate_pitch портит re/im (использует их как рабочий буфер под АКФ) -
      -- нужен свежий FFT именно для этого вызова
      extract_frame(buf, nsamples, s1, MICRO_WIN, hann, re, im)
      fft_run(re, im, tabs, false)
      local freq, conf = estimate_pitch(re, im, tabs, MICRO_WIN, MICRO_SR, get_pitch_min_freq(), PITCH_MAX_FREQ)
      if freq then
        local semis = math.abs(12 * math.log(freq / target_pitch, 2))
        if semis <= MICRO_PITCH_TOL_SEMITONES then
          pscore = conf * (1 - semis / MICRO_PITCH_TOL_SEMITONES)
        end
      end
    end

    local idx = i + 1
    flux_list[idx] = flux
    pitch_score_list[idx] = pscore
    time_list[idx] = start_t + (s1 - 1 + MICRO_WIN / 2) / MICRO_SR
    if flux > flux_max then flux_max = flux end
  end

  -- первый фрейм сравнивается с "тишиной до окна" (искусственный перепад) -
  -- не даём ему быть кандидатом, только используем для затравки разности
  local best_score, best_time = -1, nil
  for i = 2, n_frames do
    local score = (flux_list[i] / flux_max) * 0.4 + pitch_score_list[i] * 1.0
    if score > best_score then best_score = score; best_time = time_list[i] end
  end

  if not best_time or best_score < MICRO_MIN_SCORE then return nil end
  return best_time
end

----------------------------------------------------------------------
-- REFERENCE TRACK (та же партия гитары - MIDI или аудио, захваченная кнопкой
-- "Захватить референс"). Число и позиции нот в референсе считаются "правдой":
-- расхождение с ним - это не другая партия, а место, где сыграно не так, как
-- надо.
----------------------------------------------------------------------

-- Сопоставляет onsets (уже посчитанные raw/target позиции, после сведения
-- дублей) со списком нот референса - оптимальный жадный поиск ближайшей ПАРЫ
-- (а не "для каждого онсета свою ближайшую ноту по порядку"): сортируем все
-- возможные пары (онсет, нота референса) в пределах допуска по расстоянию и
-- разбираем от ближайших к дальним, чтобы не отдать одному онсету чужую ноту
-- только потому, что до неё раньше дошла очередь.
-- Возвращает ref_lookup[onset_idx]=время_референса, missing=ноты без пары.
local function match_to_reference(onsets, tolerance_sec)
  local ref_notes = reference.notes
  local tols = reference_tolerances(ref_notes, tolerance_sec)
  local candidates = {}
  for oi, t in ipairs(onsets) do
    for ri, rn in ipairs(ref_notes) do
      local d = math.abs(rn.time - t)
      if d <= tols[ri] then
        candidates[#candidates + 1] = { oi = oi, ri = ri, d = d }
      end
    end
  end
  table.sort(candidates, function(a, b) return a.d < b.d end)

  local ref_lookup, used_onset, used_ref = {}, {}, {}
  for _, cnd in ipairs(candidates) do
    if not used_onset[cnd.oi] and not used_ref[cnd.ri] then
      ref_lookup[cnd.oi] = ref_notes[cnd.ri].time
      used_onset[cnd.oi] = true
      used_ref[cnd.ri] = true
    end
  end

  local missing = {}
  for ri, rn in ipairs(ref_notes) do
    if not used_ref[ri] then missing[#missing + 1] = { time = rn.time, pitch = rn.pitch, tol = tols[ri] } end
  end

  return ref_lookup, missing
end

-- Завершает очередь "reference": ровно один item, MIDI-ноты или аудио-онсеты
-- уже лежат в results[1] (см. begin_item_analysis) - просто оборачиваем в
-- единый формат notes={{time,pitch},...}, сортированный по времени.
local function finalize_reference(results)
  local r = results[1]
  local notes
  if r.midi_notes then
    notes = r.midi_notes
  else
    notes = {}
    for i, t in ipairs(r.raw_onsets) do
      notes[#notes + 1] = { time = t, pitch = r.onset_pitch[i] }
    end
  end
  table.sort(notes, function(a, b) return a.time < b.time end)

  reference = {
    kind = r.midi_notes and "midi" or "audio",
    track = r.track, item = r.item, take = r.take,
    item_start = r.item_start, item_len = r.item_len,
    notes = notes,
  }
  local _, tname = reaper.GetTrackName(r.track)
  dbg("референс захвачен (%s, %s): %d нот", reference.kind, tname or "?", #notes)
end

local function finalize_batch(results)
  if queue.mode == "reference" then
    finalize_reference(results)
    queue = nil
    ctx = nil
    return
  end

  last_results = results
  local total_onsets = 0
  local n_cached = 0
  for _, r in ipairs(results) do
    total_onsets = total_onsets + #r.raw_onsets
    if r.from_cache then n_cached = n_cached + 1 end
  end

  local ensemble_summary = nil
  if S.ensemble_mode == 1 and #results > 1 then
    local tolerance_sec = get_sync_tolerance_sec(results[1].item_start)
    local _, per_item_stats = compute_consensus(results, tolerance_sec)
    ensemble_summary = describe_ensemble(results, per_item_stats, tolerance_sec)

    if ensemble_summary then dbg(ensemble_summary) end
  end

  last_batch_info = {
    elapsed = reaper.time_precise() - queue.start_time,
    item_count = queue.count,
    total_onsets = total_onsets,
    from_cache = n_cached,
    ensemble_summary = ensemble_summary,
  }
  queue = nil
  ctx = nil
end

-- Запускает (или продолжает) анализ ОДНОГО item из очереди. При ошибке чтения
-- этого item - помечает его пропущенным и переходит к следующему, не обрывая
-- всю очередь целиком. MIDI-тейк (возможен только для queue.mode=="reference" -
-- основные items всегда аудио, см. get_selected_audio_items) обрабатывается
-- отдельно: точное время нот берём из PPQ, без FFT-анализа.
----------------------------------------------------------------------
-- КЭШ РАЗБОРА: кандидаты нот уже разобранного звука не считаются заново (смена порога фильтра,
-- «самых коротких нот», сетки, режима - без повторного анализа спектра). Папка и формат записи - те же,
-- что у моста tools/di_detector/cli.lua (Detector.cache_read / cache_write), но ключи свои: мост строит
-- ключ от байтов WAV-файла, а здесь детектор получает сэмплы от REAPER (audio accessor: свой пересчёт
-- частоты, громкость тейка, смешение каналов) - звук в общем случае не совпадает побитно, и общий ключ
-- дал бы чужой результат. Ключ здесь - хэш ровно того, что получил детектор: все сэмплы (побитно),
-- их число и частота, позиция item (от неё зависят времена кандидатов), окна, веса и версия модуля.
-- В записи - кандидаты с полной точностью (%.17g, а не округление как у моста) и высота тона в момент
-- каждой возможной ноты (_pitch): результат из кэша совпадает с полным разбором до последнего знака.
-- Включается только в REAPER (в заглушках тестов нет RecursiveCreateDirectory) и только с обученным
-- фильтром нот (S.smart_filter == 1).
----------------------------------------------------------------------
local CACHE_FORMAT = "reaper-1" -- меняется, если меняется состав записи или ключа
-- Папка кэша - та же, что у моста: ключ di_cache общего файла путей всех проектов
-- <корень>\_workspace\paths.json (на машине владельца - <корень>\Cache\di_candidates, вне репозитория).
-- Корень DrummerProject - drummer_root() (объявлена у загрузчика модуля детектора).

-- функция REAPER или nil (в заглушках тестов её может не быть; обращение к ней там - ошибка)
local function reaper_fn(name)
  local ok, fn = pcall(function() return reaper[name] end)
  return (ok and type(fn) == "function") and fn or nil
end
local CACHE_MKDIR = reaper_fn("RecursiveCreateDirectory")

-- строковое значение ключа из плоского JSON {"ключ": "строка", ...} (как в tools/paths.lua) или nil
local function json_string(path, key)
  local fh = io.open(path, "rb")
  if not fh then return nil end
  local text = fh:read("*a")
  fh:close()
  for k, v in text:gmatch('"([^"]+)"%s*:%s*"([^"]*)"') do
    if k == key and v ~= "" then return (v:gsub("\\\\", "\\"):gsub("\\/", "/")) end
  end
  return nil
end

-- Папка кэша: настройка cache_dir (ExtState) -> ключ di_cache общего paths.json (относительное значение - от
-- корня) -> папка Data ресурсов REAPER (машина без общего файла, например серверный ПК бота).
local function cache_dir()
  local set = reaper.GetExtState(EXT_SECTION, "cache_dir")
  if set and set ~= "" then return set end
  local root, ws = drummer_root()
  local shared = json_string(ws .. "/paths.json", "di_cache")
  if shared then
    if shared:match("^%a:[/\\]") or shared:match("^[/\\]") then return shared end
    return root .. "/" .. shared
  end
  local res = reaper_fn("GetResourcePath")
  return res and (res() .. "/Data/SSM_DI_Guitar_Align/di_candidates") or nil
end

local CACHE_PACK_N = 512
local CACHE_PACK_FMT = "<" .. string.rep("d", CACHE_PACK_N)

-- ключ записи: хэш всего, что получил детектор (или nil, если модуль не прочитать)
local function cache_key(c, weights)
  local ver = Detector.source_hash()
  if not ver then return nil end
  local h = Detector.hasher()
  h:update(table.concat({ CACHE_FORMAT, Detector.VERSION, ver, string.format("%a", c.item_start), c.sr, c.nsamples,
    c.flux_win, c.flux_hop, c.pitch_win, c.pitch_hop, weights.w_flux, weights.w_hfc, weights.w_pitch }, "|"))
  local buf, n, i = c.buf, c.nsamples, 1
  while i <= n do
    local j = math.min(i + CACHE_PACK_N - 1, n)
    local fmt = (j - i + 1 == CACHE_PACK_N) and CACHE_PACK_FMT or ("<" .. string.rep("d", j - i + 1))
    h:update(string.pack(fmt, table.unpack(buf, i, j)))
    i = j + 1
  end
  return "r" .. h:hex()
end

local function cache_header()
  return "t,_sm,_lm,_p," .. table.concat(LEARNED_FILTER.features, ",") .. ",_pitch"
end

-- время ноты, в которое отбор поставит кандидата (то же выражение, что в Detector.accept)
local function cache_onset_time(c, t)
  return math.max(c.item_start, t - (LEARNED_FILTER.time_offset_ms or 0) / 1000)
end

-- запись: кандидаты с полной точностью + высота тона в момент ноты каждого кандидата
local function cache_store(c, list)
  local rows = { cache_header() }
  for _, e in ipairs(list) do
    local row = { string.format("%.17g", e.t), string.format("%.17g", e.sm), string.format("%.17g", e.lm), string.format("%.17g", e.p) }
    for _, v in ipairs(e.x) do row[#row + 1] = string.format("%.17g", v) end
    local pitch = Detector.nearest_pitch_at(c, cache_onset_time(c, e.t))
    row[#row + 1] = pitch and string.format("%.17g", pitch) or "-"
    rows[#rows + 1] = table.concat(row, ",")
  end
  local ok = Detector.cache_write(c.cache_dir, c.cache_key, table.concat(rows, "\n") .. "\n",
    function(d) CACHE_MKDIR(d, 0) end)
  dbg("кэш: %s запись %s (%d кандидатов)", ok and "сохранена" or "НЕ сохранена", c.cache_key, #list)
end

-- запись кэша -> { list = кандидаты, pitch = { [время ноты] = высота } } или nil, если запись не годится
local function cache_parse(c, csv)
  local lines = {}
  for line in csv:gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
  if lines[1] ~= cache_header() then return nil end
  local nf = #LEARNED_FILTER.features
  local list, pitch = {}, {}
  for k = 2, #lines do
    local cells = {}
    for cell in lines[k]:gmatch("[^,]+") do cells[#cells + 1] = cell end
    if #cells ~= nf + 5 then return nil end
    local e = { t = tonumber(cells[1]), sm = tonumber(cells[2]), lm = tonumber(cells[3]), p = tonumber(cells[4]), x = {} }
    if not (e.t and e.sm and e.lm and e.p) then return nil end
    for j = 1, nf do
      e.x[j] = tonumber(cells[4 + j])
      if not e.x[j] then return nil end
    end
    local pv = cells[nf + 5]
    if pv ~= "-" and not tonumber(pv) then return nil end
    pitch[cache_onset_time(c, e.t)] = tonumber(pv)
    list[#list + 1] = e
  end
  return { list = list, pitch = pitch }
end

-- кнопка «Кэш…»: открыть папку (создать, если нет). Удаляет пользователь сам - удалённое посчитается заново.
local function open_cache_folder()
  local dir = cache_dir()
  if not dir then
    reaper.ShowMessageBox("Папка кэша не определена.", "SSM DI Guitar Aligner", 0)
    return
  end
  if CACHE_MKDIR then CACHE_MKDIR(dir, 0) end
  local shell = reaper_fn("CF_ShellExecute")
  local win = dir:gsub("/", "\\")
  if shell then shell(win) else os.execute('start "" "' .. win .. '"') end
end

-- кнопка «Детектор…»: показать, откуда взят модуль детектора, и сменить путь (своя настройка detector_path).
-- Новый путь действует после перезапуска скрипта: модуль загружается один раз при старте.
local function choose_detector()
  local title = "SSM DI Guitar Aligner"
  local set = ext_get(EXT_SECTION, DETECTOR_KEY)
  local msg = "Модуль детектора нот загружен из:\n" .. tostring(DETECTOR_PATH) .. "\n(" .. tostring(DETECTOR_FROM) .. ")\n\n"
  local answer
  if set ~= "" then
    answer = reaper.ShowMessageBox(msg .. "Своя настройка: " .. set .. "\n\nДа - выбрать другой файл\n" ..
      "Нет - убрать свою настройку (искать как обычно: общая папка проектов, потом рядом со скриптом)\n" ..
      "Отмена - ничего не менять", title, 3)
    if answer == 7 then
      reaper.DeleteExtState(EXT_SECTION, DETECTOR_KEY, true)
      reaper.ShowMessageBox("Своя настройка убрана. Модуль будет найден как обычно после перезапуска скрипта.", title, 0)
      return
    end
  else
    answer = reaper.ShowMessageBox(msg .. "Выбрать другой файл?", title, 4)
  end
  if answer ~= 6 then return end
  local ok, path = reaper.GetUserFileNameForRead(DETECTOR_PATH or "", "Где лежит " .. DETECTOR_NAME .. "?", "lua")
  if not ok or not path or path == "" then return end
  local mod, why = load_detector(path)
  if not mod then
    reaper.ShowMessageBox("Файл не подошёл:\n" .. path .. "\n\n" .. tostring(why), title, 0)
    return
  end
  reaper.SetExtState(EXT_SECTION, DETECTOR_KEY, path, true)
  reaper.ShowMessageBox("Путь сохранён:\n" .. path .. "\n\nМодуль возьмётся отсюда после перезапуска скрипта " ..
    "(закройте окно и запустите снова).", title, 0)
end

local function begin_item_analysis(entry)
  local item, take, track = entry.item, entry.take, entry.track

  if reaper.TakeIsMIDI(take) then
    local notes = {}
    local _, notecnt = reaper.MIDI_CountEvts(take)
    for i = 0, notecnt - 1 do
      local ok, _, muted, startppq, _, _, pitch = reaper.MIDI_GetNote(take, i)
      if ok and not muted then
        local t = reaper.MIDI_GetProjTimeFromPPQPos(take, startppq)
        notes[#notes + 1] = { time = t, pitch = 440 * 2 ^ ((pitch - 69) / 12) }
      end
    end
    table.sort(notes, function(a, b) return a.time < b.time end)

    queue.results[queue.idx] = {
      raw_onsets = {}, onset_pitch = {}, item = item, take = take, track = track,
      item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
      item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"), sr = 0,
      midi_notes = notes,
    }
    queue.idx = queue.idx + 1
    if queue.idx <= queue.count then
      begin_item_analysis(queue.items[queue.idx])
    else
      finalize_batch(queue.results)
    end
    return
  end

  local preset = QUALITY_PRESETS[S.quality_idx]
  local buf, err, nsamples, item_start, item_len = read_mono_buffer(item, take, preset.samplerate)

  if not buf then
    dbg("item %d/%d пропущен: %s", queue.idx, queue.count, tostring(err))
    queue.results[queue.idx] = {
      raw_onsets = {}, onset_pitch = {}, item = item, take = take, track = track,
      item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION"), item_len = 0, sr = preset.samplerate,
    }
    queue.idx = queue.idx + 1
    if queue.idx <= queue.count then
      begin_item_analysis(queue.items[queue.idx])
    else
      finalize_batch(queue.results)
    end
    return
  end

  -- контекст анализа (окна, таблицы FFT, калибровка лог-сжатия по пику файла) создаёт модуль детектора
  local c = Detector.new_context(buf, nsamples, item_start, preset)
  c.item, c.take, c.track = item, take, track
  c.item_len = item_len
  c.start_time = reaper.time_precise()
  ctx = c

  dbg("item %d/%d: preset=%s sr=%d nsamples=%d n_flux=%d n_pitch=%d sample_peak=%.4g log_floor=%.4g",
    queue.idx, queue.count, preset.name, preset.samplerate, nsamples, c.n_flux, c.n_pitch, c.sample_peak, c.log_floor)

  -- кэш разбора: тот же звук этого item уже разбирался - кадры и кривая не считаются
  c.cache_dir = CACHE_MKDIR and S.smart_filter == 1 and c.n_flux >= 3 and cache_dir() or nil
  if c.cache_dir then
    c.cache_key = cache_key(c, { w_flux = S.w_flux, w_hfc = S.w_hfc, w_pitch = S.w_pitch })
    local csv = c.cache_key and Detector.cache_read(c.cache_dir, c.cache_key)
    if csv then
      c.cached = cache_parse(c, csv)
      if c.cached then
        c.phase = "peaks"
        dbg("кэш: кандидаты item %d/%d взяты из записи %s", queue.idx, queue.count, c.cache_key)
      else
        os.remove(c.cache_dir .. "/" .. c.cache_key .. ".cand") -- запись не того состава: пересчитать и перезаписать
      end
    end
  end
end

local function start_analysis()
  local items, err = get_selected_audio_items()
  if not items then
    reaper.ShowMessageBox(err, "SSM DI Guitar Aligner", 0)
    return
  end

  -- Стрейч-маркеры на item (например, от прошлого применения) искажают анализ: он читает
  -- уже растянутый звук, а новые маркеры встали бы поверх старых - двойные атаки.
  local n_marks = 0
  for _, it in ipairs(items) do n_marks = n_marks + reaper.GetTakeNumStretchMarkers(it.take) end
  if n_marks > 0 then
    local ans = reaper.ShowMessageBox(string.format(
      "На выбранных items уже есть стрейч-маркеры: %d.\n\nОни искажают анализ, а новые маркеры встанут поверх старых " ..
      "(двойные атаки).\n\nДа - удалить их и анализировать исходный звук\nНет - оставить как есть\nОтмена - ничего не делать",
      n_marks), "SSM DI Guitar Aligner", 3)
    if ans == 2 then return end
    if ans == 6 then
      reaper.Undo_BeginBlock()
      for _, it in ipairs(items) do
        local n = reaper.GetTakeNumStretchMarkers(it.take)
        if n > 0 then reaper.DeleteTakeStretchMarkers(it.take, 0, n) end
        reaper.UpdateItemInProject(it.item)
      end
      reaper.Undo_EndBlock("SSM DI Guitar Aligner: удалить стрейч-маркеры", -1)
      reaper.UpdateArrange()
      last_applied = nil
    end
  end

  queue = { items = items, idx = 1, count = #items, results = {}, start_time = reaper.time_precise(), mode = "main" }
  last_batch_info = nil
  auto_shortest_state = nil
  auto_grid_state = nil
  begin_item_analysis(items[1])
end

-- Захватывает ТЕКУЩЕЕ выделение (ровно один item, MIDI или аудио) как референс.
-- MIDI обрабатывается мгновенно (без FFT); аудио идёт через ту же очередь/FFT,
-- что и основные items - поэтому во время захвата аудио-референса анализ
-- тоже идёт по тикам defer с прогрессом, как обычно.
local function start_reference_capture()
  local cnt = reaper.CountSelectedMediaItems(0)
  if cnt ~= 1 then
    reaper.ShowMessageBox("Для захвата референса выберите ровно один item (MIDI или аудио).", "SSM DI Guitar Align", 0)
    return
  end
  local item = reaper.GetSelectedMediaItem(0, 0)
  local take = reaper.GetActiveTake(item)
  if not take then
    reaper.ShowMessageBox("У item нет активного тейка.", "SSM DI Guitar Aligner", 0)
    return
  end
  local track = reaper.GetMediaItemTrack(item)

  queue = {
    items = { { item = item, take = take, track = track } },
    idx = 1, count = 1, results = {}, start_time = reaper.time_precise(), mode = "reference",
  }
  begin_item_analysis(queue.items[1])
end

-- Расчёт кадров (Spectral Flux / HFC с лог-сжатием спектра, питч) и питч в момент ноты - в модуле детектора.
local process_flux_frame, process_pitch_frame = Detector.process_flux_frame, Detector.process_pitch_frame
local nearest_pitch_at = Detector.nearest_pitch_at

local function finish_peaks(c)
  local n = c.n_flux
  if n < 3 then
    c.raw_onsets = {}
    return
  end

  -- Общая кривая поиска нот (Spectral Flux + HFC + смена высоты тона), её сглаживание, адаптивный порог
  -- и пики - в модуле детектора. Мин. пауза считается ОТДЕЛЬНО для каждого кандидата в его собственной
  -- позиции (по локальному темпу проекта), поэтому отбор получает её функцией.
  local pk = (not c.cached) and Detector.curves(c, { w_flux = S.w_flux, w_hfc = S.w_hfc, w_pitch = S.w_pitch }) or nil
  local raw_onsets = {}
  local last_min_gap_sec = nil

  local shortest_entry = SHORTEST_NOTES[S.shortest_idx]

  if S.smart_filter == 1 then
    -- Кандидаты с низким порогом, признаки и вероятность обученного фильтра - в модуле детектора.
    local list = c.cached and c.cached.list or Detector.candidates(c, pk)
    if c.cache_key and not c.cached then cache_store(c, list) end
    c.filter_candidates = list -- для отладки и для выгрузки при обучении

    -- Отбор (в модуле): принимаем уверенные, а из близких (ближе мин. паузы) оставляем самый уверенный;
    -- время ноты сдвигается раньше на поправку фильтра. entry_override - запись "самых коротких нот"
    -- для двухпроходного разбора "Авто" (см. ниже): цикл отбора повторяется без пересчёта спектра.
    local function accept_filtered(entry_override)
      return Detector.accept(list, {
        threshold = S.filter_pct / 100, t_floor = c.item_start,
        min_gap = function(t) return get_min_gap_sec(t, entry_override) end,
      })
    end
    if shortest_entry.auto then
      -- проход 1: с самой мелкой записью (1/32), чтобы не потерять мелкие ноты
      -- до того, как разбор определит реальные "самые короткие ноты" партии
      local pass1_onsets = accept_filtered(SHORTEST_NOTES[SHORTEST_IDX_32])
      c.auto_shortest_resolved_idx = resolve_auto_shortest(pass1_onsets)
      raw_onsets, last_min_gap_sec = accept_filtered(SHORTEST_NOTES[c.auto_shortest_resolved_idx])
    else
      raw_onsets, last_min_gap_sec = accept_filtered(nil)
    end
  else
    local peaks_list = pk.peaks_above(S.sensitivity / 100)
    local function accept_plain(entry_override)
      return Detector.accept_plain(c, peaks_list, function(t) return get_min_gap_sec(t, entry_override) end)
    end
    if shortest_entry.auto then
      local pass1_onsets = accept_plain(SHORTEST_NOTES[SHORTEST_IDX_32])
      c.auto_shortest_resolved_idx = resolve_auto_shortest(pass1_onsets)
      raw_onsets, last_min_gap_sec = accept_plain(SHORTEST_NOTES[c.auto_shortest_resolved_idx])
    else
      raw_onsets, last_min_gap_sec = accept_plain(nil)
    end
  end

  -- Накопление состояния "Авто" на всю очередь (сетка должна работать и при
  -- ручном выборе самых коротких нот, поэтому триоли/прямые считаются всегда).
  -- Только для основного прохода анализа (не для захвата референса).
  if queue and queue.mode == "main" then
    if shortest_entry.auto and c.auto_shortest_resolved_idx then
      -- "самые мелкие из найденных" = наибольший индекс в SHORTEST_NOTES
      -- (длительность падает от 1/8 к 1/32 тремоло по возрастанию индекса)
      if not auto_shortest_state or c.auto_shortest_resolved_idx > auto_shortest_state.idx then
        auto_shortest_state = { idx = c.auto_shortest_resolved_idx }
      end
    end
    local nt, ns = count_trip_straight(raw_onsets)
    auto_grid_state = auto_grid_state or { n_trip = 0, n_straight = 0 }
    auto_grid_state.n_trip = auto_grid_state.n_trip + nt
    auto_grid_state.n_straight = auto_grid_state.n_straight + ns
    if shortest_entry.auto then
      dbg("авто: доли интервалов между нотами (накоплено по очереди) -> выбрано %s | триольных/прямых позиций за item: %d/%d",
        SHORTEST_NOTES[c.auto_shortest_resolved_idx].label, nt, ns)
    end
  end

  c.raw_onsets = raw_onsets
  c.onset_pitch = {}
  for i, t in ipairs(raw_onsets) do
    if c.cached then c.onset_pitch[i] = c.cached.pitch[t] else c.onset_pitch[i] = nearest_pitch_at(c, t) end
  end

  if not pk then
    dbg("peaks: %d raw onsets (кандидаты из кэша)", #raw_onsets)
    return
  end
  local smoothed, pitch_events = pk.smoothed, pk.pitch_events
  local sf_max, hfc_max, silence_gate, energy_max = pk.sf_max, pk.hfc_max, pk.silence_gate, pk.energy_max
  local c_min, c_max, c_sum = math.huge, -math.huge, 0
  for i = 1, n do
    if smoothed[i] < c_min then c_min = smoothed[i] end
    if smoothed[i] > c_max then c_max = smoothed[i] end
    c_sum = c_sum + smoothed[i]
  end
  local shown_min_gap = last_min_gap_sec or get_min_gap_sec(c.item_start)
  local min_gap_label = "от темпа проекта (для каждой ноты по локальному темпу)"
  dbg(
    "peaks: %d raw onsets, %d pitch-change events | min_gap ~ %.0f мс, %s | combined curve min/mean/max = %.4f/%.4f/%.4f | sf_max=%.4g hfc_max=%.4g silence_gate=%.4g energy_max=%.4g",
    #raw_onsets, #pitch_events, shown_min_gap * 1000, min_gap_label,
    c_min, c_sum / n, c_max, sf_max, hfc_max, silence_gate, energy_max)
  dbg("Если нот мало: понизьте 'Порог' фильтра (сейчас " .. S.filter_pct ..
    "%). Если лишних много: повысьте.")
end

----------------------------------------------------------------------
-- STEP DRIVER (вызывается из главного цикла с бюджетом времени на тик)
----------------------------------------------------------------------
local function step_analysis(budget_sec)
  if not ctx then return end
  local c = ctx
  local t0 = reaper.time_precise()

  if c.phase == "flux" then
    while c.flux_i < c.n_flux and (reaper.time_precise() - t0) < budget_sec do
      process_flux_frame(c, c.flux_i)
      c.flux_i = c.flux_i + 1
    end
    if c.flux_i >= c.n_flux then c.phase = "pitch" end

  elseif c.phase == "pitch" then
    while c.pitch_i < c.n_pitch and (reaper.time_precise() - t0) < budget_sec do
      process_pitch_frame(c, c.pitch_i)
      c.pitch_i = c.pitch_i + 1
    end
    if c.pitch_i >= c.n_pitch then c.phase = "peaks" end

  elseif c.phase == "peaks" then
    finish_peaks(c)
    local elapsed = reaper.time_precise() - c.start_time
    dbg("item %d/%d done in %.1fs, %d онсетов", queue.idx, queue.count, elapsed, #c.raw_onsets)

    queue.results[queue.idx] = {
      raw_onsets = c.raw_onsets, onset_pitch = c.onset_pitch,
      item = c.item, take = c.take, track = c.track,
      item_start = c.item_start, item_len = c.item_len, sr = c.sr,
      from_cache = c.cached ~= nil,
    }
    queue.idx = queue.idx + 1

    if queue.idx <= queue.count then
      begin_item_analysis(queue.items[queue.idx])
    else
      finalize_batch(queue.results)
    end
  end
end

local function analysis_progress()
  if ctx and queue then
    local c = ctx
    local item_pct, item_status
    if c.phase == "flux" then
      local p = c.n_flux > 0 and (c.flux_i / c.n_flux) or 1
      item_pct, item_status = p * 0.55, string.format("Spectral Flux / HFC: %d%%", math.floor(p * 100))
    elseif c.phase == "pitch" then
      local p = c.n_pitch > 0 and (c.pitch_i / c.n_pitch) or 1
      item_pct, item_status = 0.55 + p * 0.40, string.format("Питч-трекинг: %d%%", math.floor(p * 100))
    else
      item_pct, item_status = 0.97, "Поиск онсетов..."
    end
    local overall = ((queue.idx - 1) + item_pct) / queue.count
    local prefix
    if queue.mode == "reference" then
      prefix = "Захват референса: "
    elseif queue.count > 1 then
      prefix = string.format("Item %d/%d: ", queue.idx, queue.count)
    else
      prefix = ""
    end
    return overall, prefix .. item_status
  end
  if last_batch_info then
    return 1.0, string.format("Готово: %d онсетов, %d item(ов), за %.1fс",
      last_batch_info.total_onsets, last_batch_info.item_count, last_batch_info.elapsed) ..
      ((last_batch_info.from_cache or 0) > 0 and string.format(" (из кэша: %d)", last_batch_info.from_cache) or "")
  end
  return 0, ""
end

----------------------------------------------------------------------
-- SNAPPING (нулевые переходы + сетка проекта, с ограничением дистанции)
----------------------------------------------------------------------
-- Снэп к нулю нужен только при разрезании (щелчки на стыках). Стрейч-маркер звук не режет,
-- а сдвиг до ±6 мс может увести его за начало атаки - там снэп не применяется.
local function use_zerocross()
  return S.zerocross == 1 and S.output_mode >= 2
end

local function snap_zero_crossing(take, time_pos)
  local sr = 44100
  local radius = ZC_SEARCH_MS / 1000
  local start_t = time_pos - radius
  local nsamples = math.floor(radius * 2 * sr)
  if nsamples < 4 then return time_pos end

  local AA = reaper.CreateTakeAudioAccessor(take)
  if not AA then return time_pos end

  local arr = reaper.new_array(nsamples)
  local ok = reaper.GetAudioAccessorSamples(AA, sr, 1, start_t, nsamples, arr)
  reaper.DestroyAudioAccessor(AA)
  if ok == nil or ok < 0 then return time_pos end

  local s = array_to_table(arr, nsamples)
  local center_i = math.floor(nsamples / 2)
  local best_i, best_d = nil, math.huge

  for i = 2, nsamples do
    local a, b = s[i - 1], s[i]
    if (a >= 0 and b < 0) or (a < 0 and b >= 0) then
      local d = math.abs(i - center_i)
      if d < best_d then best_d = d; best_i = i end
    end
  end

  if not best_i then return time_pos end
  return start_t + (best_i - 1) / sr
end

-- Шаг сетки проекта в четвертях (QN). GetSetProjectGrid возвращает
-- (флаги, division, swingmode, swingamt) - division ВТОРЫМ значением; это доля
-- ЦЕЛОЙ ноты (0.25 = четверть), а не такта, поэтому от размера такта шаг не
-- зависит (1/8 в 7/8 и в 4/4 - одна и та же половина четверти). Не зависит
-- от тумблера "магнита" - в отличие от reaper.SnapToGrid, который ведёт себя
-- по-разному в зависимости от того, включён ли снэп в самом REAPER.
local function get_project_grid_qn_step()
  local _, division = reaper.GetSetProjectGrid(0, false)
  if not division or division <= 0 then division = 0.25 end
  return division * 4
end

-- Шаг сетки для GRID_MODES "Авто": если по итогам анализа (auto_grid_state,
-- см. finish_peaks) триольных позиций больше, чем прямых - риф триольный,
-- шаг 1/8T (1/16T при самых коротких 1/32 - см. SHORTEST_IDX_32); иначе шаг
-- равен действующим "самым коротким нотам" (effective_shortest_entry - это
-- работает и когда они выбраны вручную, не только при "Авто"). nil, если
-- анализа ещё не было - вызывающий код в этом случае берёт грид проекта.
local function auto_grid_qn_step()
  if not auto_grid_state then return nil end
  local shortest = effective_shortest_entry()
  if auto_grid_state.n_trip > auto_grid_state.n_straight then
    return (shortest == SHORTEST_NOTES[SHORTEST_IDX_32]) and (1 / 6) or (1 / 3)
  end
  return shortest.qn
end

local function snap_to_grid_time(time_pos)
  local mode = GRID_MODES[S.grid_mode_idx]
  local qn_step = (mode.auto and auto_grid_qn_step()) or mode.qn or get_project_grid_qn_step()

  local qn = reaper.TimeMap2_timeToQN(0, time_pos)
  local snapped_qn = math.floor(qn / qn_step + 0.5) * qn_step
  local target = reaper.TimeMap2_QNToTime(0, snapped_qn)

  -- расстояние до линии в долях шага сетки (в четвертях - не зависит от темпа)
  local dist_pct = math.abs(qn - snapped_qn) / qn_step * 100
  if dist_pct > S.grid_max_pct + 1e-9 then
    dbg("grid: %.3fs - ближайшая линия за %.0f%% шага (лимит %d%%), не трогаю",
      time_pos, dist_pct, S.grid_max_pct)
    return time_pos
  end
  return target
end

-- Промежуточный список {raw=..., target=..., flagged=...} (абсолютное время
-- проекта) - без сетки и без референса, это делает build_item_final_onsets
-- следующими этапами. raw - позиция после снэпа к нулевому переходу (если
-- включено) - "где реально нота". target - позиция после сведения к
-- консенсусу дублей (если включено и есть совпадение). flagged - true, если
-- консенсус включён, но у этой ноты нет совпадения у других дублей (её НЕ
-- двигаем на этом этапе - решать дальше через референс или человеку).
local function compute_intermediate_onsets(raw_onsets, take, consensus_for_item, ensemble_active)
  local out = {}
  for oi, t in ipairs(raw_onsets) do
    local raw = t
    if use_zerocross() then raw = snap_zero_crossing(take, raw) end

    local target = raw
    local flagged = false
    local cons = consensus_for_item and consensus_for_item[oi]
    if cons then
      target = cons
    elseif ensemble_active then
      flagged = true
    end

    out[#out + 1] = { raw = raw, target = target, flagged = flagged }
  end
  table.sort(out, function(a, b) return a.raw < b.raw end)

  local merged = {}
  for _, o in ipairs(out) do
    if #merged == 0 or (o.raw - merged[#merged].raw) >= MERGE_MIN_GAP_SEC then
      merged[#merged + 1] = o
    end
  end
  return merged
end

-- Финальный список онсетов ОДНОГО item - центральная точка сборки конвейера,
-- используется и "Превью", и "Применить". Порядок этапов (как договорились):
--   1. raw + zero-cross + консенсус дублей (compute_intermediate_onsets)
--   2. досочинение пропущенных нот по консенсусу дублей (injections)
--   3. привязка ВСЕЙ группы целиком к референс-треку - сначала подтягиваем
--      уже сведённые между собой ноты к ближайшей ноте референса, затем (если
--      включено) досочиняем ноты референса, которых нет вообще ни у одного
--      онсета item (тот же микро-поиск по звуку/питчу, что и для дублей)
--   4. сетка проекта - финальный слой поверх всего, применяется ко ВСЕМ
--      онсетам (включая досочинённые на любом из предыдущих этапов)
local function build_item_final_onsets(res, item_idx, consensus_lookup, ensemble_active, injections)
  local _, item_tname = reaper.GetTrackName(res.track)
  item_tname = item_tname or "?"

  local final = compute_intermediate_onsets(res.raw_onsets, res.take,
    consensus_lookup and consensus_lookup[item_idx], ensemble_active)

  local inj_list = injections and injections[item_idx]
  if inj_list then
    for _, inj in ipairs(inj_list) do
      local raw = inj.raw
      if use_zerocross() then raw = snap_zero_crossing(res.take, raw) end
      final[#final + 1] = { raw = raw, target = inj.target, flagged = false, injected = true }
    end
  end

  -- ВАЖНО: если ОДНОВРЕМЕННО включены "Привязка к сетке" и "Подтягивать
  -- группу к референсу", сетка применяется ПОСЛЕДНЕЙ (см. ниже) и может
  -- перекрыть результат референса там, где нота референса не легла ровно на
  -- линию сетки - это ожидаемое поведение конвейера (дубли -> референс ->
  -- сетка), но если кажется, что референс "не работает", первым делом
  -- проверьте, не включена ли заодно и сетка.
  if S.reference_mode == 1 and reference then
    local sync_tol = get_sync_tolerance_sec(res.item_start)
    local basis = {}
    for i, e in ipairs(final) do basis[i] = e.target end
    local ref_lookup, missing_refs = match_to_reference(basis, sync_tol)

    local anchors = {}
    local matched_n = 0
    for i, e in ipairs(final) do
      if ref_lookup[i] then
        matched_n = matched_n + 1
        anchors[#anchors + 1] = { raw = e.raw, matched = ref_lookup[i] }
        e.target = ref_lookup[i]
        e.flagged = false
      end
    end
    dbg("референс [%s]: сопоставлено %d из %d онсетов item, %d нот референса без пары (допуск %s)",
      item_tname, matched_n, #final, #missing_refs,
      S.sync_tolerance_mode == 2 and string.format("%.0f мс", sync_tol * 1000) or "половина расстояния до соседней ноты")

    if S.reference_inject == 1 and #missing_refs > 0 then
      local injected_n = 0
      for _, rn in ipairs(missing_refs) do
        local offset = estimate_offset_at(anchors, rn.time)
        local candidate = rn.time + offset
        local found_raw = local_onset_search(res.take, candidate, (rn.tol or sync_tol) * INJECT_RADIUS_MULT, rn.pitch)
        if found_raw then
          local raw = found_raw
          if use_zerocross() then raw = snap_zero_crossing(res.take, raw) end
          final[#final + 1] = { raw = raw, target = rn.time, flagged = false, injected = true }
          injected_n = injected_n + 1
        end
      end
      dbg("референс [%s]: досочинено %d из %d непарных нот", item_tname, injected_n, #missing_refs)
    end
  end

  if S.gridsnap == 1 then
    local moved_n, kept_n = 0, 0
    for _, e in ipairs(final) do
      local snapped = snap_to_grid_time(e.target)
      if math.abs(snapped - e.target) > 1e-6 then moved_n = moved_n + 1 else kept_n = kept_n + 1 end
      e.target = snapped
    end
    dbg("grid snap [%s]: сдвинуто %d из %d, %d оставлено (лимит %d%% шага)",
      item_tname, moved_n, moved_n + kept_n, kept_n, S.grid_max_pct)
  end

  table.sort(final, function(a, b) return a.raw < b.raw end)
  local merged = {}
  for _, e in ipairs(final) do
    if #merged == 0 or (e.raw - merged[#merged].raw) >= MERGE_MIN_GAP_SEC then
      merged[#merged + 1] = e
    end
  end
  return merged
end

----------------------------------------------------------------------
-- PREVIEW MARKERS (проектные маркеры с префиксом - чтобы можно было
-- удобно смотреть/зумить результат в родном таймлайне REAPER, без
-- необходимости рисовать свою волну)
----------------------------------------------------------------------
local PREVIEW_PREFIX = "DI:"

local function clear_preview_markers()
  local ids = {}
  local i = 0
  while true do
    local retval, isrgn, _, _, name, idx = reaper.EnumProjectMarkers3(0, i)
    if retval == 0 then break end
    if not isrgn and name and name:sub(1, #PREVIEW_PREFIX) == PREVIEW_PREFIX then
      ids[#ids + 1] = idx
    end
    i = i + 1
  end
  for _, idx in ipairs(ids) do
    reaper.DeleteProjectMarker(0, idx, false)
  end
  reaper.UpdateArrange()
end

local function set_preview_markers(onsets)
  clear_preview_markers()
  local color_ok   = reaper.ColorToNative(255, 140, 0) | 0x1000000 -- оранжевый: обычный/сведённый онсет
  local color_flag = reaper.ColorToNative(230, 40, 40) | 0x1000000 -- красный: без совпадения у других дублей
  local color_inj  = reaper.ColorToNative(80, 140, 255) | 0x1000000 -- синий: досочинён по большинству - проверьте на слух
  for i, o in ipairs(onsets) do
    local suffix = o.injected and "*" or (o.flagged and "!" or "")
    local color = o.injected and color_inj or (o.flagged and color_flag or color_ok)
    reaper.AddProjectMarker2(0, false, o.target, 0, PREVIEW_PREFIX .. i .. suffix, -1, color)
  end
  reaper.UpdateArrange()
end

----------------------------------------------------------------------
-- APPLY
----------------------------------------------------------------------
-- Микрокроссфейд на стыке кусков при разрезании: кусок с нотой удлиняется влево на 1/64
-- (или 1/128) ноты по темпу проекта - в это удлинение попадает звук, идущий в записи перед
-- атакой, - а предыдущий кусок обрезается ровно по атаке. На их перекрытии - S-образный
-- кроссфейд, который заканчивается к атаке: атака звучит целиком, хвост предыдущей ноты не
-- обрывается. Ноты, сдвинутые вправо (между кусками пауза), пока не трогаются.
local SPLIT_XFADES = {
  { label = "1/64", qn = 4 / 64 },
  { label = "1/128", qn = 4 / 128 },
  { label = "выкл" },
}
local XFADE_SHAPE = 5 -- форма фейда REAPER "slow start/end" (S-образная)
-- Край куска без кроссфейда (пауза между кусками, кроссфейд выключен или не поместился) -
-- резкий обрыв звука, щелчок. На такие края - микрофейд 1 мс (самый короткий в REAPER).
local MICRO_FADE_SEC = 0.001

local function split_xfade_len(at_time)
  local xf = SPLIT_XFADES[S.split_xfade_idx]
  if not xf or not xf.qn then return 0 end
  local q = reaper.TimeMap2_timeToQN(0, at_time)
  return at_time - reaper.TimeMap2_QNToTime(0, q - xf.qn)
end

-- "Гибрид": после разрезания нота, за которой образовалась пауза (следующая нота уехала
-- вправо), растягивается стрейч-маркерами до следующей ноты и кроссфейдом переходит в неё.
-- Что растягивать - на выбор (сравнить на слух): всю ноту (склеек посреди звука нет, атака
-- тянется на те же проценты), хвост после атаки (маркер через 30 мс после начала - на прошлых
-- пробах такой маркер в сустейне звучал неестественно) или конец хвоста (маркер на 70% ноты,
-- где звук тише). Если растягивать пришлось бы больше S.hybrid_max_stretch_pct - пауза остаётся.
-- at(len) - где неподвижный маркер от начала ноты (len - длина ноты без удлинения под кроссфейд)
local HYBRID_MARKERS = {
  { label = "Вся нота", at = function() return 0 end },
  { label = "После атаки", at = function(len) return math.min(0.030, len * 0.3) end },
  { label = "В хвосте", at = function(len) return len * 0.7 end },
}


-- Начало шороха медиатора перед атакой t (время проекта): высокочастотная огибающая звука,
-- от атаки назад, пока она заметно выше фона (фон - начало окна, за 60..45 мс до атаки).
-- Не дальше 40 мс. На 792 нотах с разметкой: у 2/3 нот шорох совпадает с найденным началом,
-- 10-40 мс - у ~10% (глушение, низкие строи). Возвращает время начала шороха (<= t).
local PICK_BACK_SEC = 0.040
local function find_pick_start(take, t)
  local sr = 44100
  local start_t = t - PICK_BACK_SEC - 0.020
  local n = math.floor((PICK_BACK_SEC + 0.025) * sr)
  local AA = reaper.CreateTakeAudioAccessor(take)
  if not AA then return t end
  local arr = reaper.new_array(n)
  local ok = reaper.GetAudioAccessorSamples(AA, sr, 1, start_t, n, arr)
  reaper.DestroyAudioAccessor(AA)
  if ok == nil or ok < 1 then return t end
  local x = array_to_table(arr, n)
  local hp = {}
  for i = 3, n do hp[i - 2] = x[i] - 2 * x[i - 1] + x[i - 2] end -- простой фильтр высоких частот
  local w = math.floor(sr * 0.001)
  local env, acc = {}, 0
  for i = 1, #hp do
    acc = acc + hp[i] * hp[i]
    if i > w then acc = acc - hp[i - w] * hp[i - w] end
    env[i] = math.sqrt(math.max(acc, 0) / w)
  end
  local nb = math.floor(0.015 * sr)
  local base_list, emax = {}, 0
  for i = 1, #env do
    if i <= nb then base_list[#base_list + 1] = env[i] end
    if env[i] > emax then emax = env[i] end
  end
  local thr = math.max((median(base_list) or 0) * 4, 0.05 * emax, 1e-9)
  local k = math.floor((t - start_t) * sr) - 2
  local lo = math.floor(0.020 * sr)
  if k > #env then k = #env end
  while k > lo and env[k - 1] and env[k - 1] > thr do k = k - 1 end
  return math.min(t, start_t + (k + 2) / sr)
end

local function apply_split(item, onsets)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local sorted = {}
  for i, o in ipairs(onsets) do sorted[i] = o end
  table.sort(sorted, function(a, b) return a.raw < b.raw end)

  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local src_take = reaper.GetActiveTake(item)

  -- Где резать и куда ставить кусок. "raw" - найденное начало ноты (атака). Шорох медиатора
  -- "к началу ноты": режем по началу шороха, и шорох уезжает вместе с нотой; на сетку ставится
  -- атака (шорох чуть раньше линии) или сам шорох (атака чуть позже - на слух бывает естественнее).
  local cuts = {}
  local prev_cut = item_start
  for _, o in ipairs(sorted) do
    local cut_at, target = o.raw, o.target
    if S.pick_to_idx == 2 and src_take then
      local ps = find_pick_start(src_take, o.raw)
      if ps > prev_cut + 0.003 and ps < o.raw then
        cut_at = ps
        if S.pick_align_idx == 1 then target = o.target - (o.raw - ps) end
      end
    end
    cuts[#cuts + 1] = { cut = cut_at, target = target }
    prev_cut = cut_at
  end

  -- шаг 1: режем на ещё не сдвинутой цепочке кусков - SplitMediaItem сам звук не двигает,
  -- поэтому резать сразу по target бессмысленно: атака ноты окажется внутри куска
  local pieces = {}
  local cur_item = item
  for _, c in ipairs(cuts) do
    local new_item = reaper.SplitMediaItem(cur_item, c.cut)
    if new_item then
      pieces[#pieces + 1] = { item = new_item, target = c.target }
      cur_item = new_item
    end
  end

  -- шаг 2: сдвигаем каждый кусок на целевую (скорректированную) позицию -
  -- независимо от порядка, т.к. D_POSITION каждого item'а самостоятелен
  for _, p in ipairs(pieces) do
    reaper.SetMediaItemInfo_Value(p.item, "D_POSITION", p.target)
  end

  -- шаг 3: микрокроссфейды. Кусок перед первой нотой (начало item) не удлиняется.
  local chain = { { item = item } }
  for _, p in ipairs(pieces) do chain[#chain + 1] = p end
  local done, stretched, gaps_kept = 0, 0, 0
  local function micro_out(it)
    if reaper.GetMediaItemInfo_Value(it, "D_FADEOUTLEN") < MICRO_FADE_SEC then
      reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", MICRO_FADE_SEC)
      reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN_AUTO", 0)
    end
  end
  local function micro_in(it)
    if reaper.GetMediaItemInfo_Value(it, "D_FADEINLEN") < MICRO_FADE_SEC then
      reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN", MICRO_FADE_SEC)
      reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN_AUTO", 0)
    end
  end
  -- "Гибрид": дотянуть кусок-ноту стрейч-маркерами до длины new_len. note_at - где в куске
  -- начинается сама нота (кусок мог быть удлинён влево под кроссфейд с предыдущей нотой):
  -- до этого места ничего не тянется, иначе съедет атака и кроссфейд перед ней.
  local function hybrid_stretch(it, new_len, note_at)
    local take = reaper.GetActiveTake(it)
    if not take then return false end
    local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    if new_len <= len then return false end
    local p1 = note_at + HYBRID_MARKERS[S.hybrid_marker_idx].at(len - note_at)
    if (new_len - p1) / (len - p1) > 1 + S.hybrid_max_stretch_pct / 100 then return false end
    if reaper.GetMediaItemTakeInfo_Value(take, "B_PPITCH") < 0.5 then
      reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH", 1)
    end
    reaper.SetTakeStretchMarker(take, -1, 0)
    if note_at > 0 then reaper.SetTakeStretchMarker(take, -1, note_at) end
    if p1 > note_at then reaper.SetTakeStretchMarker(take, -1, p1) end
    local idx_end = reaper.SetTakeStretchMarker(take, -1, len)
    reaper.SetMediaItemInfo_Value(it, "D_LENGTH", new_len)
    reaper.SetTakeStretchMarker(take, idx_end, new_len)
    return true
  end
  for i = 2, #chain do
    local a, b = chain[i - 1].item, chain[i].item
    local a_pos = reaper.GetMediaItemInfo_Value(a, "D_POSITION")
    local a_len = reaper.GetMediaItemInfo_Value(a, "D_LENGTH")
    local b_pos = reaper.GetMediaItemInfo_Value(b, "D_POSITION") -- начало ноты (на сетке)
    local b_len = reaper.GetMediaItemInfo_Value(b, "D_LENGTH")
    local gap = b_pos - (a_pos + a_len)
    local ext = split_xfade_len(b_pos)
    if gap > 0.0005 and S.output_mode == 3 and i > 2 then -- пауза после ноты: гибрид дотягивает ноту
      if hybrid_stretch(a, b_pos - a_pos, chain[i - 1].ext_left or 0) then
        stretched = stretched + 1
        a_len = b_pos - a_pos
        gap = 0
      else
        gaps_kept = gaps_kept + 1
      end
    end
    local crossfaded = false
    if ext > 0 and gap <= 0.0005 then -- нахлёст или стык без сдвига; пауза (нота вправо) - без кроссфейда
      local take = reaper.GetActiveTake(b)
      local rate = take and reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1
      if rate <= 0 then rate = 1 end
      local offs = take and reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS") or 0
      local a_new_len = b_pos - a_pos -- предыдущий кусок кончается ровно на начале ноты
      -- удлинение не больше, чем есть звука перед нотой в источнике, и не больше половины
      -- каждого из кусков - иначе кроссфейд займёт весь кусок
      ext = math.min(ext, offs / rate, a_new_len * 0.5, b_len * 0.5)
      if ext > 0.0005 then
        reaper.SetMediaItemInfo_Value(a, "D_LENGTH", a_new_len)
        reaper.SetMediaItemInfo_Value(b, "D_POSITION", b_pos - ext)
        reaper.SetMediaItemInfo_Value(b, "D_LENGTH", b_len + ext)
        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", offs - ext * rate)
        reaper.SetMediaItemInfo_Value(a, "D_FADEOUTLEN", ext)
        reaper.SetMediaItemInfo_Value(a, "C_FADEOUTSHAPE", XFADE_SHAPE)
        reaper.SetMediaItemInfo_Value(a, "D_FADEOUTLEN_AUTO", 0)
        reaper.SetMediaItemInfo_Value(b, "D_FADEINLEN", ext)
        reaper.SetMediaItemInfo_Value(b, "C_FADEINSHAPE", XFADE_SHAPE)
        reaper.SetMediaItemInfo_Value(b, "D_FADEINLEN_AUTO", 0)
        done = done + 1
        crossfaded = true
        chain[i].ext_left = ext
      end
    end
    if not crossfaded then -- стык без кроссфейда: микрофейды на обоих краях
      micro_out(a)
      micro_in(b)
    end
  end
  -- внешние края: начало item и конец последнего куска (свой фейд пользователя не трогаем)
  micro_in(chain[1].item)
  micro_out(chain[#chain].item)

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM DI Guitar Aligner: split by onsets (" .. #onsets .. ")", -1)
  local chain_items = {}
  for _, c in ipairs(chain) do chain_items[#chain_items + 1] = c.item end
  return #pieces, done, stretched, gaps_kept, chain_items
end

local GLUE_ACTION = 40362 -- Item: Glue items, ignoring time selection
-- Склеивает куски одного item в один новый (новый файл: кроссфейды, фейды и растяжение
-- "Гибрида" запекаются, паузы - тишина). Выделение пользователя восстанавливается,
-- склеенный item остаётся выделенным. Возвращает склеенный item или nil.
local function glue_pieces(items)
  local keep = {}
  for i = 0, reaper.CountSelectedMediaItems(0) - 1 do keep[#keep + 1] = reaper.GetSelectedMediaItem(0, i) end
  reaper.SelectAllMediaItems(0, false)
  local n = 0
  for _, it in ipairs(items) do
    if reaper.ValidatePtr2(0, it, "MediaItem*") then reaper.SetMediaItemSelected(it, true); n = n + 1 end
  end
  if n == 0 then return nil end
  reaper.Main_OnCommand(GLUE_ACTION, 0)
  local glued = reaper.GetSelectedMediaItem(0, 0)
  for _, it in ipairs(keep) do
    if reaper.ValidatePtr2(0, it, "MediaItem*") then reaper.SetMediaItemSelected(it, true) end
  end
  return glued
end

-- Имя тейка результата: REAPER при склейке даёт "<имя>-glued", нужно "<имя> [Q]" (как у трека
-- результата). Расширение сохраняется; имя, уже помеченное [Q], не помечается второй раз.
-- Меняется только имя тейка в проекте - файл на диске называет сам REAPER.
local function q_take_name(orig_name)
  local base, ext = orig_name:match("^(.*)(%.%w+)$")
  if not base or base == "" then base, ext = orig_name, "" end
  if base:sub(-4) == " [Q]" then return orig_name end
  return base .. " [Q]" .. ext
end

local function name_glued_take(glued_item, orig_name)
  if not orig_name or orig_name == "" then return end
  local take = reaper.GetActiveTake(glued_item)
  if take then reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", q_take_name(orig_name), true) end
end

local DUPLICATE_TRACK_ACTION = 40062 -- Track: Duplicate tracks
-- «Оставить оригинал»: копия трека целиком (плагины, посылы, остальные items) сразу под ним,
-- с именем "<имя> [Q]". Возвращает новый трек или nil. Выделение треков восстанавливается.
local function duplicate_track_for_result(track)
  local keep = {}
  for i = 0, reaper.CountSelectedTracks(0) - 1 do keep[#keep + 1] = reaper.GetSelectedTrack(0, i) end
  reaper.SetOnlyTrackSelected(track)
  reaper.Main_OnCommand(DUPLICATE_TRACK_ACTION, 0)
  local new_track = reaper.GetSelectedTrack(0, 0)
  for i = 0, reaper.CountSelectedTracks(0) - 1 do reaper.SetTrackSelected(reaper.GetSelectedTrack(0, i), false) end
  for _, tr in ipairs(keep) do
    if reaper.ValidatePtr2(0, tr, "MediaTrack*") then reaper.SetTrackSelected(tr, true) end
  end
  if not new_track or new_track == track then return nil end
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if not name or name == "" then
    name = "Track " .. math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
  end
  reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", name .. " [Q]", true)
  return new_track
end

-- тот же item на копии трека: копия хранит items в том же порядке
local function item_copy_on(new_track, item)
  local idx = math.floor(reaper.GetMediaItemInfo_Value(item, "IP_ITEMNUMBER"))
  local copy = reaper.GetTrackMediaItem(new_track, idx)
  if not copy then return nil end
  local same = math.abs(reaper.GetMediaItemInfo_Value(copy, "D_POSITION") - reaper.GetMediaItemInfo_Value(item, "D_POSITION")) < 1e-6
    and math.abs(reaper.GetMediaItemInfo_Value(copy, "D_LENGTH") - reaper.GetMediaItemInfo_Value(item, "D_LENGTH")) < 1e-6
  return same and copy or nil
end

----------------------------------------------------------------------
-- ДАБЛ-ТРЕК (псевдо-дубль): копия item на новом треке, нарезка по найденным
-- нотам, гибрид двух приёмов студийного удвоения:
--   1) дрожание (как ADT/дублер) - на КАЖДОЙ ноте лёгкий случайный сдвиг тайминга
--      и высоты. Без этого часть нот звучит идентично оригиналу (нулевая ширина),
--      а часть - совсем другим куском (резкий скачок): при жёсткой панораме это
--      слышно как "пинг-понг" между колонками. Дрожание есть всегда и ровно
--      понемногу, поэтому ширина одинаковая на всех нотах - как у настоящего
--      второго дубля.
--   2) изредка (не на каждом повторе) занимаем звук у похожей по громкости ноты
--      той же высоты не дальше "радиуса перемешивания" - настоящая вариация
--      исполнения, а не просто синтетическое дрожание, но нечастая и подобранная
--      по громкости, чтобы не выскакивать на общем фоне.
-- Оба слоя настраиваются в окне.
----------------------------------------------------------------------
math.randomseed(os.time())

-- Копия item на новом треке сразу под исходным (аудио - тот же PCM_source, это
-- нормально: его держат сразу несколько items). Стрейч-маркеры, режим растяжения
-- и собственная расстройка тейка копируются, чтобы дабл стартовал с тем же
-- звуком, что и уже обработанный оригинал.
local function duplicate_item_to_new_track(item, take)
  local track = reaper.GetMediaItemTrack(item)
  local track_idx = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER"))
  if track_idx < 1 then return nil end
  reaper.InsertTrackAtIndex(track_idx, true)
  local new_track = reaper.GetTrack(0, track_idx)
  if not new_track then return nil end
  local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
  if not name or name == "" then name = "Track " .. track_idx end
  reaper.GetSetMediaTrackInfo_String(new_track, "P_NAME", name .. " Double", true)

  local new_item = reaper.AddMediaItemToTrack(new_track)
  local new_take = reaper.AddTakeToMediaItem(new_item)
  reaper.SetMediaItemTake_Source(new_take, reaper.GetMediaItemTake_Source(take))

  for _, key in ipairs({ "D_POSITION", "D_LENGTH", "D_FADEINLEN", "D_FADEOUTLEN", "D_VOL",
                          "C_FADEINSHAPE", "C_FADEOUTSHAPE", "D_FADEINLEN_AUTO", "D_FADEOUTLEN_AUTO", "B_MUTE" }) do
    reaper.SetMediaItemInfo_Value(new_item, key, reaper.GetMediaItemInfo_Value(item, key))
  end
  for _, key in ipairs({ "D_STARTOFFS", "D_PLAYRATE", "D_PITCH", "B_PPITCH", "I_PITCHMODE", "I_STRETCHFLAGS" }) do
    reaper.SetMediaItemTakeInfo_Value(new_take, key, reaper.GetMediaItemTakeInfo_Value(take, key))
  end
  for i = 0, reaper.GetTakeNumStretchMarkers(take) - 1 do
    local _, pos, srcpos = reaper.GetTakeStretchMarker(take, i)
    if pos then reaper.SetTakeStretchMarker(new_take, -1, pos, srcpos) end
  end
  reaper.UpdateItemInProject(new_item)
  return new_item, new_track
end

-- Допуск группировки "та же нота" - не жёсткая сетка полутонов (у соседних по
-- звучанию нот бывает 43.4 и 43.6 - округление раскидало бы их по разным
-- соседним ячейкам), а кластеризация по факту: идём по времени, каждая нота
-- уходит в ближайший уже открытый кластер, если тот в допуске, иначе открывает
-- новый. freq=nil (питч не определён - типично для глухих заглушённых нот) - в
-- отдельный кластер "?" (тоже участвует в перестановке, но только сам с собой).
local PITCH_CLUSTER_TOL_SEMITONES = 0.6
local function cluster_by_pitch(order, pitches)
  local clusters, group_of = {}, {}
  for _, idx in ipairs(order) do
    local freq = pitches[idx]
    if not freq then
      group_of[idx] = "?"
    else
      local semi = 12 * math.log(freq / 440, 2) + 69
      local best, best_d = nil, math.huge
      for ci, c in ipairs(clusters) do
        local d = math.abs(c.mean - semi)
        if d < best_d then best, best_d = ci, d end
      end
      if best and best_d <= PITCH_CLUSTER_TOL_SEMITONES then
        local c = clusters[best]
        c.n = c.n + 1
        c.mean = c.mean + (semi - c.mean) / c.n
        group_of[idx] = best
      else
        clusters[#clusters + 1] = { mean = semi, n = 1 }
        group_of[idx] = #clusters
      end
    end
  end
  return group_of
end

-- Громкость куска (RMS первых <=0.5с его собственного звучания на текущей
-- позиции в проекте) - для подбора партнёра похожей динамики при заимствовании
-- звука; читается ДО каких-либо правок куска.
-- Питч-детектор изредка путает ноту с квинтой/октавой (известная слабость -
-- автокорреляция цепляется не за тот пик), и такая нота может честно "по цифрам"
-- попасть в НАСТОЯЩИЙ чужой кластер (тот и правда есть в партии дальше) - никакого
-- дрейфа кластеризация не покажет, ошибка спрятана на уровне самих данных. Раньше
-- (без коррекции высоты) это звучало тише - заимствованный звук просто играл на
-- своей высоте; теперь коррекция активно подтягивает к цели, и промах слышен явно.
-- Различить на слух "редкая настоящая нота-акцент" от "сбой детектора" по соседям
-- нельзя - обе выглядят одинаково (резкий скачок от контекста). Но цена ошибки
-- разная: пропустить настоящий акцент - нота просто останется звучать сама собой
-- (не хуже, чем без заимствования вообще); не пропустить сбой - нота прозвучит на
-- чужой высоте. Поэтому при подозрении (нет согласия НИ с одним соседом по времени,
-- независимо от кластера) - лучше не давать ноте участвовать в заимствовании вовсе.
local ISOLATION_TOL_SEMITONES = 2.0
local function is_isolated(piece_pitch, k)
  local my = piece_pitch[k]
  if not my then return false end -- без своего питча - решает бакет "?", сюда не относится
  local function far(other)
    if not other then return true end
    return math.abs(12 * math.log(my / other, 2)) > ISOLATION_TOL_SEMITONES
  end
  return far(piece_pitch[k - 1]) and far(piece_pitch[k + 1])
end

local function piece_rms(take, pos, len)
  local sr = 32000
  local n = math.max(64, math.floor(math.min(len, 0.5) * sr))
  local AA = reaper.CreateTakeAudioAccessor(take)
  if not AA then return 0 end
  local arr = reaper.new_array(n)
  local ok = reaper.GetAudioAccessorSamples(AA, sr, 1, pos, n, arr)
  reaper.DestroyAudioAccessor(AA)
  if ok == nil or ok < 1 then return 0 end
  local x = array_to_table(arr, n)
  local acc = 0
  for i = 1, n do acc = acc + x[i] * x[i] end
  return math.sqrt(acc / n)
end

local LOUDNESS_TOL_DB = 3.0 -- заимствуем звук только у похожего по громкости повтора
-- Заимствуем звук, только если высоту донора можно подтянуть к своей не больше чем
-- на столько (мимо - или явно другая нота, или сбой питч-детектора - лучше не трогать
-- звук вообще, чем красить его большим и слышимым сдвигом высоты).
local PITCH_CORRECTION_MAX_CENTS = 50
-- ...и только если после обрезки под короче ноты партнёра останется не совсем огрызок -
-- слишком короткий кусок звучит как щелчок/призвук, а не как нота, и заодно так же
-- ненадёжно читается обратно детектором (лишний риск на пустом месте).
local MIN_SWAP_LEN_SEC = 0.06

-- Громкость по фразе не скачет от ноты к ноте, а плавно "гуляет" на протяжении
-- нескольких нот подряд - измерено на 7 парах настоящих дублей разных партий
-- (<корень DrummerProject>\TestDIs\Doubler\New, 107-175bpm): автокорреляция разницы
-- громкости между дублями в среднем положительная (слабее и не так стабильно от
-- партии к партии, как показала первая запись, но чаще да, чем нет), а у тайминга
-- и высоты - около нуля (там независимое дрожание в самый раз). Поэтому громкость -
-- сглаженное случайное блуждание вдоль партии (экспоненциальное сглаживание, не
-- слишком сильное - широкая выборка не подтвердила сильную связь на первой записи),
-- а не независимый бросок на каждой ноте.
local LEVEL_SMOOTH = 0.3
-- Сглаживание само по себе уменьшает разброс результата против размаха шага (для
-- AR(1) с равномерным шагом - в sqrt(3*(1+r)/(1-r)) раз, r = LEVEL_SMOOTH). Компенсируем,
-- чтобы double_level_db значил то, что написано в окне - итоговое std ухода громкости
-- в дБ, а не какое-то меньшее число, которое пользователь не сможет предсказать.
local LEVEL_STEP_MULT = math.sqrt(3 * (1 + LEVEL_SMOOTH) / (1 - LEVEL_SMOOTH))
local function smoothed_walk(n, target_std_db)
  local amp_db = target_std_db * LEVEL_STEP_MULT
  local vals, prev = {}, 0
  for i = 1, n do
    local innov = (math.random() * 2 - 1) * amp_db
    prev = LEVEL_SMOOTH * prev + (1 - LEVEL_SMOOTH) * innov
    vals[i] = prev
  end
  return vals
end

-- Режет item ровно по найденным онсетам (без сдвига к сетке/референсу - тайминг
-- дабла должен остаться таким же, как у оригинала). Дальше на каждой ноте:
--   - изредка (S.double_swap_pct) заимствуем звук у другой ноты той же высоты
--     не дальше S.double_window_sec и с похожей громкостью (LOUDNESS_TOL_DB);
--     если у партнёра нота короче - кусок укорачивается, чтобы не захватить
--     чужой звук (зазор тишины лучше, чем кусок чужой ноты); высота донора
--     подтягивается к своей (внутри кластера они могут отличаться на доли
--     полутона - без этого заимствование слышно как расстройка);
--   - всегда - небольшое случайное дрожание тайминга (S.double_jitter_ms) и
--     высоты (S.double_jitter_cents) на каждой ноте отдельно, плюс плавный
--     уход громкости (S.double_level_db) на протяжении нескольких нот - поверх
--     заимствованного звука тоже.
local function shuffle_double(item, onsets, pitches)
  local pieces, piece_pitch, piece_time = { item }, { false }, { 0 }
  for i, t in ipairs(onsets) do
    local new_item = reaper.SplitMediaItem(pieces[#pieces], t)
    if new_item then
      pieces[#pieces + 1] = new_item
      piece_pitch[#pieces] = pitches[i]
      piece_time[#pieces] = t
    end
  end
  if #pieces < 2 then return pieces, 0, 0 end

  local order = {}
  for k = 2, #pieces do
    if not is_isolated(piece_pitch, k) then order[#order + 1] = k end
  end
  local group_of = cluster_by_pitch(order, piece_pitch)
  local groups = {}
  for _, k in ipairs(order) do
    local key = group_of[k]
    groups[key] = groups[key] or {}
    groups[key][#groups[key] + 1] = k
  end

  local orig, loud = {}, {}
  for i = 2, #pieces do
    local it = pieces[i]
    local take = reaper.GetActiveTake(it)
    local pos, len = reaper.GetMediaItemInfo_Value(it, "D_POSITION"), reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
    orig[it] = { startoffs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"), len = len }
    loud[i] = piece_rms(take, pos, len)
  end

  -- слой 2: для каждой подходящей ноты - с вероятностью double_swap_pct% найти
  -- партнёра похожей громкости среди той же высоты в пределах окна по времени
  local swap_partner, groups_used = {}, 0
  for _, list in pairs(groups) do
    if #list >= 2 then
      local any = false
      for _, idx in ipairs(list) do
        if math.random() < S.double_swap_pct / 100 then
          local cands = {}
          for _, other in ipairs(list) do
            if other ~= idx and math.abs(piece_time[other] - piece_time[idx]) <= S.double_window_sec then
              local ldb = 20 * math.log((loud[other] + 1e-9) / (loud[idx] + 1e-9), 10)
              local my_p, other_p = piece_pitch[idx], piece_pitch[other]
              local pitch_ok = (not my_p or not other_p)
                or math.abs(12 * math.log(my_p / other_p, 2)) * 100 <= PITCH_CORRECTION_MAX_CENTS
              local len_ok = math.min(orig[pieces[idx]].len, orig[pieces[other]].len) >= MIN_SWAP_LEN_SEC
              if math.abs(ldb) <= LOUDNESS_TOL_DB and pitch_ok and len_ok then cands[#cands + 1] = other end
            end
          end
          if #cands > 0 then
            swap_partner[idx] = cands[math.random(#cands)]
            any = true
          end
        end
      end
      if any then groups_used = groups_used + 1 end
    end
  end

  local level_seq = S.double_level_db > 0 and smoothed_walk(#pieces - 1, S.double_level_db) or nil

  local swapped = 0
  for i = 2, #pieces do
    local it = pieces[i]
    local take = reaper.GetActiveTake(it)
    local p = swap_partner[i]
    if p then
      local new_len = math.min(orig[it].len, orig[pieces[p]].len)
      reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", orig[pieces[p]].startoffs)
      reaper.SetMediaItemInfo_Value(it, "D_LENGTH", new_len)
      -- донор внутри кластера мог быть на доли полутона в стороне от СВОЕЙ ноты
      -- (кластер по допуску, не точное совпадение) - подтягиваем высоту донора к
      -- своей, иначе заимствование слышно как лёгкая расстройка, а не просто
      -- другая атака/призвук
      local my_pitch, donor_pitch = piece_pitch[i], piece_pitch[p]
      if my_pitch and donor_pitch then
        local correction = 12 * math.log(my_pitch / donor_pitch, 2)
        reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH") + correction)
      end
      swapped = swapped + 1
    end
    -- слой 1: дрожание тайминга и высоты - независимо на каждой ноте
    if S.double_jitter_ms > 0 then
      local dt = (math.random() * 2 - 1) * (S.double_jitter_ms / 1000)
      reaper.SetMediaItemInfo_Value(it, "D_POSITION", reaper.GetMediaItemInfo_Value(it, "D_POSITION") + dt)
    end
    if S.double_jitter_cents > 0 then
      local base_pitch = reaper.GetMediaItemTakeInfo_Value(take, "D_PITCH")
      local dcents = (math.random() * 2 - 1) * S.double_jitter_cents
      reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", base_pitch + dcents / 100)
    end
    -- громкость - плавный уход по фразе (level_seq), не сама по себе на каждой ноте
    if level_seq then
      local base_vol = reaper.GetMediaItemInfo_Value(it, "D_VOL")
      reaper.SetMediaItemInfo_Value(it, "D_VOL", base_vol * 10 ^ (level_seq[i - 1] / 20))
    end
  end

  -- маленькие фейды на всех кусках-нотах - маскируют стык там, где звук
  -- поменялся или сдвинулась позиция
  for i = 2, #pieces do
    local it = pieces[i]
    if reaper.GetMediaItemInfo_Value(it, "D_FADEINLEN") < MICRO_FADE_SEC then
      reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN", MICRO_FADE_SEC)
      reaper.SetMediaItemInfo_Value(it, "D_FADEINLEN_AUTO", 0)
    end
    if reaper.GetMediaItemInfo_Value(it, "D_FADEOUTLEN") < MICRO_FADE_SEC then
      reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", MICRO_FADE_SEC)
      reaper.SetMediaItemInfo_Value(it, "D_FADEOUTLEN_AUTO", 0)
    end
  end
  return pieces, swapped, groups_used
end

-- «Создать дабл-трек»: по каждому проанализированному item - копия на новый трек,
-- нарезка, дрожание + заимствование звука; при S.double_glue - куски склеиваются.
local function create_double_tracks()
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local n_tracks, n_notes, n_swapped, n_groups = 0, 0, 0, 0
  for _, res in ipairs(last_results) do
    if #res.raw_onsets > 0 then
      local new_item = duplicate_item_to_new_track(res.item, res.take)
      if new_item then
        n_tracks = n_tracks + 1
        local pieces, swapped, groups_used = shuffle_double(new_item, res.raw_onsets, res.onset_pitch)
        n_notes = n_notes + #res.raw_onsets
        n_swapped, n_groups = n_swapped + swapped, n_groups + groups_used
        if S.double_glue == 1 then glue_pieces(pieces) end
      end
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM DI Guitar Aligner: создать дабл-трек", -1)
  if n_tracks == 0 then
    return "Не удалось создать дабл-трек: нет проанализированных items с найденными нотами."
  end
  return string.format(
    "Дабл-трек создан: %d track(s), нот %d, дрожание ±%.0fмс/±%.0fцент, громкость ±%.1fдБ по фразе, заимствован звук у %d нот%s",
    n_tracks, n_notes, S.double_jitter_ms, S.double_jitter_cents, S.double_level_db, n_swapped, S.double_glue == 1 and ", склеено" or "")
end

local function find_marker_idx_by_srcpos(take, srcpos, eps)
  local n = reaper.GetTakeNumStretchMarkers(take)
  for i = 0, n - 1 do
    local _, _, sp = reaper.GetTakeStretchMarker(take, i)
    if sp and math.abs(sp - srcpos) < eps then return i end
  end
  return nil
end

-- Убирает маркеры, поставленные прошлым "Применить" (по исходной позиции в звуке -
-- она у маркера не меняется, даже если его потом сдвинули руками)
local function remove_applied_markers(applied)
  local removed = 0
  for _, la in ipairs(applied or {}) do
    if la.take and reaper.ValidatePtr2(0, la.take, "MediaItem_Take*") then
      for _, e in ipairs(la.entries) do
        local idx = find_marker_idx_by_srcpos(la.take, e.srcpos, 1e-6)
        if idx then removed = removed + reaper.DeleteTakeStretchMarkers(la.take, idx, 1) end
      end
      reaper.UpdateItemInProject(la.item)
    end
  end
  return removed
end

-- Возвращает {mode="stretch", take, item, entries} - вызывающий код (Apply в GUI)
-- собирает эти состояния по каждому item в список last_applied для батча.
local function apply_stretch_markers(take, item, onsets)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- без "Preserve pitch" стрейч-маркеры меняют высоту тона отрезков - нота "плывёт"
  if reaper.GetMediaItemTakeInfo_Value(take, "B_PPITCH") < 0.5 then
    reaper.SetMediaItemTakeInfo_Value(take, "B_PPITCH", 1)
  end


  local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local created = {}

  -- Один маркер на ноту, ровно на найденном начале: граница стрейч-маркера (склейка
  -- звука с разной скоростью) маскируется атакой ноты. Маркер в тянущемся звуке -
  -- до атаки или в сустейне - на слух даёт неестественный звук при любом режиме
  -- растяжения (проверено пользователем в REAPER). Нота, чья цель не строго позже
  -- цели предыдущей (две ноты притянулись к одной линии), пропускается: иначе
  -- маркеры перекрестились бы.
  local GAP = 0.002
  local list = {}
  for _, o in ipairs(onsets) do list[#list + 1] = { raw = o.raw - item_start, target = o.target - item_start } end
  table.sort(list, function(a, b) return a.raw < b.raw end)
  local marks = {}
  local prev_raw, prev_tgt = -math.huge, -math.huge
  for _, o in ipairs(list) do
    if o.raw >= 0 and o.raw > prev_raw + GAP and o.target > prev_tgt + GAP then
      marks[#marks + 1] = { raw = o.raw, target = o.target }
      prev_raw, prev_tgt = o.raw, o.target
    end
  end

  -- шаг 1: ставим маркеры на "сырых" позициях (замораживаем нужный срез аудио)
  for _, mk in ipairs(marks) do
    local relpos = mk.raw
    if relpos >= 0 then
      local idx = reaper.SetTakeStretchMarker(take, -1, relpos)
      if idx and idx >= 0 then
        local _, _, srcpos = reaper.GetTakeStretchMarker(take, idx)
        created[#created + 1] = {
          idx = idx, srcpos = srcpos,
          raw_rel = relpos, target_rel = mk.target,
        }
      end
    end
  end

  -- шаг 2: переносим маркеры на целевые (сетка) позиции - это и создаёт растяжение
  for _, m in ipairs(created) do
    if math.abs(m.target_rel - m.raw_rel) > 1e-6 then
      local idx = m.idx
      local _, _, sp = reaper.GetTakeStretchMarker(take, idx)
      if not sp or math.abs(sp - m.srcpos) > 1e-6 then
        idx = find_marker_idx_by_srcpos(take, m.srcpos, 1e-6) or idx
      end
      reaper.SetTakeStretchMarker(take, idx, m.target_rel)
      m.idx = idx
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateItemInProject(item)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM DI Guitar Aligner: stretch markers (" .. #created .. ")", -1)

  if S.debug == 1 then
    local _, tname = reaper.GetTrackName(reaper.GetMediaItemTrack(item))
    for _, m in ipairs(created) do
      dbg("apply [%s]: raw_rel=%.4f target_rel=%.4f srcpos=%s idx=%d",
        tname or "?", m.raw_rel, m.target_rel, m.srcpos and string.format("%.4f", m.srcpos) or "nil", m.idx)
    end
  end

  return { mode = "stretch", take = take, item = item, entries = created }
end

-- Переключает уже применённые стрейч-маркеры (по ВСЕМ items последнего Apply)
-- между "сеткой" и исходной позицией (по текущему состоянию галочки "Привязка
-- к сетке"), без повторного анализа. Работает только для режима Stretch-
-- маркеров - для Split нет чистого способа сдвинуть уже разрезанные items
-- туда-обратно без риска щелчков/наложений.
local function reapply_grid_state_to_markers()
  if not last_applied then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local kept = {}
  for _, la in ipairs(last_applied) do
    if reaper.ValidatePtr2(0, la.take, "MediaItem_Take*") then
      for _, e in ipairs(la.entries) do
        local want = (S.gridsnap == 1) and e.target_rel or e.raw_rel
        local idx = e.idx
        local _, _, sp = reaper.GetTakeStretchMarker(la.take, idx)
        if not sp or math.abs(sp - e.srcpos) > 1e-6 then
          idx = find_marker_idx_by_srcpos(la.take, e.srcpos, 1e-6) or idx
        end
        if idx then
          reaper.SetTakeStretchMarker(la.take, idx, want)
          e.idx = idx
        end
      end
      reaper.UpdateItemInProject(la.item)
      kept[#kept + 1] = la
    end
  end
  last_applied = (#kept > 0) and kept or nil

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM DI Guitar Aligner: toggle grid snap", -1)
end

-- «Применить» к результатам анализа (last_results) в текущем режиме вывода.
-- Возвращает строку статуса и таблицу чисел (для серверного режима).
local function apply_results()
  local ensemble_active = S.ensemble_mode == 1 and #last_results > 1
  local consensus_lookup, injections
  if ensemble_active then
    consensus_lookup = compute_consensus(last_results, get_sync_tolerance_sec(last_results[1].item_start))
  end
  -- прошлое применение заменяется, а не складывается с новым
  local removed = remove_applied_markers(last_applied)
  last_applied = nil
  if S.output_mode == 1 then
    local applied_list = {}
    local placed = 0
    for ti, res in ipairs(last_results) do
      local final = build_item_final_onsets(res, ti, consensus_lookup, ensemble_active, injections)
      applied_list[#applied_list + 1] = apply_stretch_markers(res.take, res.item, final)
      placed = placed + #applied_list[#applied_list].entries
    end
    last_applied = applied_list
    clear_preview_markers()
    -- результат анализа остаётся: можно поменять сетку/алгоритм и применить снова
    return string.format("Применено в %s: маркеров %d на %d item(s)%s",
      os.date("%H:%M:%S"), placed, #applied_list,
      removed > 0 and string.format(", прошлые %d заменены", removed) or ""),
      { notes = placed, items = #applied_list }
  end
  local glue = S.glue_after == 1
  local keep_orig = glue and S.keep_original == 1
  if glue then reaper.Undo_BeginBlock() end -- выравнивание и склейка - один шаг отмены
  -- «Оставить оригинал»: сначала копии треков (пока items не разрезаны), по одной на трек
  local work_item, new_tracks, orig_tracks = {}, {}, {}
  if keep_orig then
    for _, res in ipairs(last_results) do
      local tr = reaper.GetMediaItemTrack(res.item)
      if not new_tracks[tr] then
        new_tracks[tr] = duplicate_track_for_result(tr) or false
        orig_tracks[#orig_tracks + 1] = tr
      end
    end
    local bad = {}
    for ti, res in ipairs(last_results) do
      local tr = reaper.GetMediaItemTrack(res.item)
      work_item[ti] = new_tracks[tr] and item_copy_on(new_tracks[tr], res.item) or nil
      if not work_item[ti] then bad[tr] = true end
    end
    -- копия трека без своей копии item не нужна: этот трек - как без галочки (оригинал не глушится)
    for tr in pairs(bad) do
      if new_tracks[tr] then reaper.DeleteTrack(new_tracks[tr]); new_tracks[tr] = false end
    end
    for ti, res in ipairs(last_results) do
      if bad[reaper.GetMediaItemTrack(res.item)] then work_item[ti] = nil end
    end
  end
  local n_pieces, n_xf, n_str, n_gap, n_glued, n_kept = 0, 0, 0, 0, 0, 0
  for ti, res in ipairs(last_results) do
    local final = build_item_final_onsets(res, ti, consensus_lookup, ensemble_active, injections)
    local target_item = work_item[ti] or res.item
    local target_take = glue and reaper.GetActiveTake(target_item)
    local orig_take_name = target_take and reaper.GetTakeName(target_take)
    local np, nx, ns, ng, chain_items = apply_split(target_item, final)
    n_pieces, n_xf, n_str, n_gap = n_pieces + np, n_xf + nx, n_str + ns, n_gap + ng
    local glued = glue and glue_pieces(chain_items)
    if glued then
      n_glued = n_glued + 1
      name_glued_take(glued, orig_take_name)
    end
    if work_item[ti] then
      n_kept = n_kept + 1
      reaper.SetMediaItemSelected(res.item, false) -- оригинал остаётся как был, выделен результат
    end
  end
  if keep_orig then
    for _, tr in ipairs(orig_tracks) do
      if new_tracks[tr] then reaper.SetMediaTrackInfo_Value(tr, "B_MUTE", 1) end
    end
  end
  if glue then
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("SSM DI Guitar Aligner: выровнять и склеить", -1)
  end
  clear_preview_markers()
  local n_results = #last_results
  last_results = nil -- item разрезан, прежний анализ к нему больше не относится
  return string.format("%s в %s: кусков %d, микрокроссфейдов %d (%s)%s%s. Для нового применения нужен новый анализ.",
    S.output_mode == 3 and "Гибрид" or "Разрезано", os.date("%H:%M:%S"), n_pieces, n_xf, SPLIT_XFADES[S.split_xfade_idx].label,
    S.output_mode == 3 and string.format(", дотянуто нот %d, пауз оставлено %d (растяжение больше %d%%)",
      n_str, n_gap, S.hybrid_max_stretch_pct) or "",
    (glue and string.format(", склеено в %d item(s)", n_glued) or "") ..
      (keep_orig and (n_kept == n_results and ", оригинал на заглушённом треке, результат - на треке [Q]"
        or string.format(", ОРИГИНАЛ СОХРАНЁН НЕ ДЛЯ ВСЕХ: %d из %d", n_kept, n_results)) or "")),
    { pieces = n_pieces, xfades = n_xf, stretched = n_str, gaps = n_gap, glued = n_glued, kept = n_kept }
end

----------------------------------------------------------------------
-- GUI HELPERS
----------------------------------------------------------------------
-- Окно: ширина фиксирована (две колонки), высота подстраивается под контент (см. конец
-- draw_window) в пределах MIN_WIN_H..MAX_WIN_H и рабочей области экрана. DEFAULT_WIN_H -
-- только стартовая высота до первой отрисовки.
local WIN_W = 1220
local DEFAULT_WIN_H, MIN_WIN_H, MAX_WIN_H = 800, 480, 990
local HEADER_H = 36
local WIN_FRAME_H = 40 -- запас на заголовок и рамку окна Windows при подгонке под экран

-- Верх и низ рабочей области экрана (без панели задач), на котором находится окно.
-- nil, если узнать не удалось - тогда высота ограничена только MAX_WIN_H.
local function screen_work_area(x, y, w, h)
  local ok, _, top, _, bottom = pcall(function()
    return reaper.my_getViewport(0, 0, 0, 0,
      math.floor(x), math.floor(y), math.floor(x + w), math.floor(y + h), true)
  end)
  if ok and type(top) == "number" and type(bottom) == "number" and bottom - top >= MIN_WIN_H + WIN_FRAME_H then
    return top, bottom
  end
  return nil
end

local win_x, win_y = S.win_x, S.win_y
local cur_win_h = DEFAULT_WIN_H
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
  while #out > 1 and gfx.measurestr(out .. "…") > max_w do
    out = out:sub(1, -2)
  end
  return out .. "…"
end

local function edit_number(title, current, minv, maxv)
  local retval, str = reaper.GetUserInputs(title, 1, "Значение:", tostring(current))
  if not retval then return current end
  local num = tonumber(str)
  if not num then return current end
  return clamp(math.floor(num + 0.5), minv, maxv)
end

-- Как edit_number, но для дробных значений (секунды и т.п.) - не округляет до целого
local function edit_number_float(title, current, minv, maxv)
  local retval, str = reaper.GetUserInputs(title, 1, "Значение:", string.format("%.2g", current))
  if not retval then return current end
  local num = tonumber(str)
  if not num then return current end
  return clamp(num, minv, maxv)
end

local function draw_chip_row(x, y, w, h, options, selected_idx, left_click, gap)
  gap = gap or 6
  local n = #options
  local chip_w = (w - gap * (n - 1)) / n
  local clicked = nil
  for i, label in ipairs(options) do
    local cx = x + (i - 1) * (chip_w + gap)
    local is_sel = (i == selected_idx)
    local hov = mouse_in(cx, y, chip_w, h)
    local c = is_sel and col.accent or (hov and col.btn_hover or col.btn)
    draw_round_rect(cx, y, chip_w, h, c, 1, 6)
    set_color(col.border); gfx.rect(cx, y, chip_w, h, 0)
    gfx.setfont(1, "Arial", 14)
    local tw = gfx.measurestr(label)
    draw_text(label, cx + (chip_w - tw) / 2, y + (h - 14) / 2, col.text)
    if hov and left_click then clicked = i end
  end
  return clicked
end

local function draw_button(x, y, w, h, label, enabled, left_click, color)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = enabled and (color or (hov and col.btn_hover or col.btn)) or col.panel
  draw_round_rect(x, y, w, h, c, 1, 6)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  gfx.setfont(1, "Arial", 15)
  local tw = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - 15) / 2, enabled and col.text or col.text_dim)
  return enabled and hov and left_click
end

local function draw_value_box(x, y, w, h, value_str, left_click)
  local hov = mouse_in(x, y, w, h)
  draw_round_rect(x, y, w, h, hov and col.accent or col.input_bg, 1, 5)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  gfx.setfont(1, "Arial", 15)
  local tw = gfx.measurestr(value_str)
  draw_text(value_str, x + (w - tw) / 2, y + (h - 15) / 2, col.text)
  return hov and left_click
end

local function draw_checkbox(x, y, checked, label, left_click)
  draw_round_rect(x, y, 20, 20, checked and col.accent or col.input_bg, 1, 4)
  set_color(col.border); gfx.rect(x, y, 20, 20, 0)
  if checked then
    gfx.setfont(1, "Arial", 15)
    draw_text("✓", x + 4, y, col.text)
  end
  gfx.setfont(1, "Arial", 15)
  draw_text(label, x + 29, y + 2, col.text)
  -- область клика по реальной ширине подписи (с минимумом 300 для коротких
  -- подписей) - длинные подписи в двухколоночной раскладке (~458px) раньше
  -- рисовались шире жёстко зашитых 300px, и клик по хвосту текста не срабатывал
  local label_w = gfx.measurestr(label)
  local hit_w = math.max(300, 29 + label_w + 10)
  return mouse_in(x, y, hit_w, 22) and left_click
end

local function draw_progress(x, y, w, h, pct)
  draw_round_rect(x, y, w, h, col.input_bg, 1, h / 2)
  local fw = math.floor(w * clamp(pct, 0, 1))
  if fw > 4 then draw_round_rect(x, y, fw, h, col.accent2, 1, h / 2) end
  set_color(col.border); gfx.rect(x, y, w, h, 0)
end

-- Заголовок секции (ДЕТЕКТОР / СЕТКА / ...) - акцентный цвет, капс, маленький шрифт.
-- Группирует колонки визуально без доп. панелей/фонов (которым нужна была бы высота
-- секции заранее, а она зависит от включённых опций).
local function draw_section_title(x, y, text)
  gfx.setfont(1, "Arial", 13)
  set_color(col.accent)
  gfx.x, gfx.y = x, y
  gfx.drawstr(text:upper())
end

-- Тонкая горизонтальная линия-разделитель между крупными блоками интерфейса.
local function draw_divider(x, y, w)
  set_color(col.border, 0.6)
  gfx.rect(x, y, w, 1, 1)
end

-- Блок "Выбрано в проекте": каждый выбранный item отдельной строкой (трек, тейк, длина) и
-- отметка, есть ли для него результат анализа. Если анализ сделан для других items -
-- предупреждение (иначе "Применить" сработал бы не там, где ожидает пользователь).
-- Возвращает новую координату y.
local function draw_selection_block(x, y, w)
  local items, err = get_selected_audio_items()
  local analyzed = {}
  if last_results then
    for _, r in ipairs(last_results) do analyzed[r.item] = r end
  end
  local box_top = y
  gfx.setfont(1, "Arial", 15)
  draw_text("Выбрано в проекте:", x + 10, y + 6, col.text)
  y = y + 28
  local selected = {}
  if not items then
    draw_text(err, x + 22, y, col.warn)
    y = y + 22
  else
    for i, e in ipairs(items) do
      selected[e.item] = true
      local _, tname = reaper.GetTrackName(e.track)
      local take_name = reaper.GetTakeName(e.take) or "?"
      local len = reaper.GetMediaItemInfo_Value(e.item, "D_LENGTH")
      local tag = analyzed[e.item] and "✓ проанализирован" or "не анализирован"
      gfx.setfont(1, "Arial", 14)
      local tag_w = gfx.measurestr(tag)
      local line = string.format("%d.  %s  —  %s   (%d:%04.1f)", i, tname or "?", take_name, math.floor(len / 60), len % 60)
      draw_text(clip_text(line, w - tag_w - 50, 14), x + 22, y, col.text)
      draw_text(tag, x + w - 12 - tag_w, y, analyzed[e.item] and col.accent2 or col.text_dim)
      y = y + 20
    end
  end
  if last_results then
    local other = {}
    for _, r in ipairs(last_results) do
      if not selected[r.item] then
        local _, tname = reaper.GetTrackName(r.track)
        other[#other + 1] = tname or "?"
      end
    end
    if #other > 0 then
      gfx.setfont(1, "Arial", 13)
      draw_text(clip_text("⚠ Результат анализа относится к другим items (" .. table.concat(other, ", ") ..
        ") - «Превью»/«Применить» работают с ними. Для выбранных нажмите «Анализировать».", w - 30, 13), x + 22, y, col.warn)
      y = y + 20
    end
  end
  set_color(col.border); gfx.rect(x, box_top, w, y - box_top + 4, 0)
  return y + 12
end

-- Проверяет, что items из последнего анализа ещё существуют (невалидные тихо
-- выбрасываются из списка, остальные остаются рабочими), и если какой-то item
-- за это время подвинули на таймлайне - сдвигает его сохранённые онсеты на ту
-- же дельту (иначе Preview/Apply тихо поставят маркеры на старое место).
-- Возвращает true, если в last_results остался хотя бы один валидный item.
local function sync_last_results()
  if not last_results then return false end
  local kept = {}
  for _, res in ipairs(last_results) do
    if reaper.ValidatePtr2(0, res.item, "MediaItem*") and reaper.ValidatePtr2(0, res.take, "MediaItem_Take*") then
      local cur_start = reaper.GetMediaItemInfo_Value(res.item, "D_POSITION")
      local delta = cur_start - res.item_start
      if math.abs(delta) > 1e-6 then
        for i, t in ipairs(res.raw_onsets) do res.raw_onsets[i] = t + delta end
        res.item_start = cur_start
        dbg("item сдвинулся на %.3fs с момента анализа - онсеты пересчитаны", delta)
      end
      kept[#kept + 1] = res
    end
  end
  last_results = (#kept > 0) and kept or nil
  return last_results ~= nil
end

-- Позиция item для предпросмотра "Мин. пауза" в реальных мс до запуска анализа:
-- берём первый item последнего анализа, иначе первый текущий выбранный.
local function get_reference_item_start()
  if last_results and last_results[1] then
    return last_results[1].item_start
  end
  local item = reaper.GetSelectedMediaItem(0, 0)
  if item then return reaper.GetMediaItemInfo_Value(item, "D_POSITION") end
  return nil
end

----------------------------------------------------------------------
-- MAIN DRAW
----------------------------------------------------------------------
local function draw_window()
  local w, h = gfx.w, gfx.h
  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1

  draw_round_rect(0, 0, w, h, col.bg, 1, 0)

  -- header (draggable). Своего крестика нет: окно закрывается крестиком в заголовке
  -- Windows/REAPER или клавишей Esc.
  local in_header = gfx.mouse_y >= 0 and gfx.mouse_y <= HEADER_H
  if left_click and in_header then
    dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    drag_off_x = sx - (wx or win_x)
    drag_off_y = sy - (wy or win_y)
  end
  if left_release and dragging then
    local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
    if x then
      win_x, win_y = x, y
      S.win_x, S.win_y = win_x, win_y
      save_settings()
    end
  end
  if left_release then dragging = false end
  if dragging then
    local sx, sy = reaper.GetMousePosition()
    win_x = sx - drag_off_x
    win_y = sy - drag_off_y
    gfx.init("", math.floor(w), math.floor(h), 0, math.floor(win_x), math.floor(win_y))
  end

  draw_round_rect(0, 0, w, HEADER_H, col.panel, 1, 0)
  gfx.setfont(1, "Arial", 16)
  draw_text("🎸SSM DI Guitar Aligner " .. SCRIPT_VERSION .. " — AI Based", 18, 9, col.text)

  if dragging then
    last_mouse_cap = gfx.mouse_cap
    return nil
  end

  -- Раскладка: две колонки одной ширины на всё окно (настройки, результат), ниже кнопки.
  -- Одно правило на всё окно: подпись НАД полем, поле начинается от левого края колонки,
  -- ряды кнопок - на всю ширину колонки, поля со значением - одной ширины (BOX_W).
  local left = 20
  local content_w = w - left * 2
  local col_gap = 28
  local col_w = (content_w - col_gap) / 2
  local colA_x = left
  local colB_x = left + col_w + col_gap
  local CHIP_H, BOX_W, BOX_H = 28, 150, 28
  local third_w = (col_w - 12) / 3 -- ширина кнопки в ряду из трёх
  local y = HEADER_H + 12

  local function field_label(text, x, yy)
    gfx.setfont(1, "Arial", 13)
    draw_text(text, x, yy, col.text)
  end
  local function hint(text, x, yy, max_w, c)
    draw_text(clip_text(text, max_w, 12), x, yy, c or col.text_dim)
  end

  local analyzing = ctx ~= nil
  local has_result = sync_last_results()

  -- какие items выбраны и для каких есть результат анализа
  y = draw_selection_block(left, y, content_w)

  local yA, yB = y, y

  -- === КОЛОНКА A: ДЕТЕКТОР ===
  draw_section_title(colA_x, yA, "Детектор")
  yA = yA + 20
  field_label("Самые короткие ноты в партии:", colA_x, yA)
  yA = yA + 18
  local short_labels = {}
  for i, o in ipairs(SHORTEST_NOTES) do short_labels[i] = o.label end
  local sclicked = draw_chip_row(colA_x, yA, col_w, CHIP_H, short_labels, S.shortest_idx, left_click and not analyzing)
  if sclicked then S.shortest_idx = sclicked; save_settings() end
  yA = yA + 32
  do
    local ref_pos = get_reference_item_start()
    local text
    if SHORTEST_NOTES[S.shortest_idx].auto then
      if not auto_shortest_state then
        text = "Авто: определится при анализе"
      elseif ref_pos then
        text = string.format("Авто: определено %s (мин. пауза ≈ %.0f мс)",
          SHORTEST_NOTES[auto_shortest_state.idx].label, get_min_gap_sec(ref_pos) * 1000)
      else
        text = "Авто: определено " .. SHORTEST_NOTES[auto_shortest_state.idx].label
      end
    elseif ref_pos then
      text = string.format("мин. пауза между нотами ≈ %.0f мс при темпе проекта", get_min_gap_sec(ref_pos) * 1000)
    else
      text = "мин. пауза считается от темпа проекта"
    end
    hint(text, colA_x, yA, col_w)
    yA = yA + 22
  end

  field_label("Обученный фильтр нот:", colA_x, yA)
  yA = yA + 18
  if draw_value_box(colA_x, yA, BOX_W, BOX_H, "Порог " .. S.filter_pct .. "%", left_click) then
    S.filter_pct = edit_number("Порог фильтра, % (больше = МЕНЬШЕ нот, меньше = БОЛЬШЕ нот). Обычно 15-30", S.filter_pct, 1, 95)
    save_settings()
  end
  -- «Кэш…» - открыть папку кэша разбора (что удалять, решает пользователь);
  -- «Детектор…» - откуда взят модуль детектора нот, сменить путь
  local cache_btn_w, det_btn_w = 64, 92 -- �� ������ ��������: ������� �������: �� (~237 px) ���������� �������
  if draw_button(colA_x + col_w - cache_btn_w, yA, cache_btn_w, BOX_H, "Кэш…", true, left_click) then
    open_cache_folder()
  end
  if draw_button(colA_x + col_w - cache_btn_w - 8 - det_btn_w, yA, det_btn_w, BOX_H, "Детектор…", true, left_click) then
    choose_detector()
  end
  hint("обучен: " .. LEARNED_FILTER.trained_on, colA_x + BOX_W + 12, yA + 8, col_w - BOX_W - cache_btn_w - det_btn_w - 32)
  yA = yA + 38

  gfx.setfont(1, "Arial", 15)
  if draw_checkbox(colA_x, yA, S.zerocross == 1, "Исключить щелчки", left_click) then
    S.zerocross = (S.zerocross == 1) and 0 or 1; save_settings()
  end
  yA = yA + 30
  if draw_checkbox(colA_x, yA, S.ensemble_mode == 1, "Сводить дубли по консенсусу (2+ items)", left_click) then
    S.ensemble_mode = (S.ensemble_mode == 1) and 0 or 1; save_settings()
  end
  yA = yA + 28
  if S.ensemble_mode == 1 then
    hint("Онсеты дублей группируются и тянутся к медиане; несовпавшие - красным, не трогаются.", colA_x, yA, col_w)
    yA = yA + 20
  end

  -- === КОЛОНКА B: СЕТКА И РЕФЕРЕНС (один конвейер привязки: дубли -> референс -> сетка) ===
  draw_section_title(colB_x, yB, "Сетка и референс")
  yB = yB + 20
  gfx.setfont(1, "Arial", 15)
  if draw_checkbox(colB_x, yB, S.gridsnap == 1, "Привязка к сетке проекта (тайминг)", left_click) then
    S.gridsnap = (S.gridsnap == 1) and 0 or 1; save_settings()
    reapply_grid_state_to_markers()
  end
  yB = yB + 30
  if S.gridsnap == 1 then
    local gnames = {}
    for i, g in ipairs(GRID_MODES) do gnames[i] = g.label end
    local gclicked = draw_chip_row(colB_x, yB, col_w, CHIP_H, gnames, S.grid_mode_idx, left_click)
    if gclicked then S.grid_mode_idx = gclicked; save_settings() end
    yB = yB + 34
    field_label("Предел сдвига к сетке, % шага:", colB_x, yB)
    yB = yB + 18
    local lim_label = S.grid_max_pct >= 50 and "всегда" or ("≤" .. S.grid_max_pct .. "%")
    if draw_value_box(colB_x, yB, BOX_W, BOX_H, lim_label, left_click) then
      S.grid_max_pct = edit_number("Макс. сдвиг к сетке, % шага (50 = всегда к ближайшей)", S.grid_max_pct, 5, 50)
      save_settings()
    end
    if GRID_MODES[S.grid_mode_idx].auto then
      local text = "Авто: определится при анализе"
      if auto_grid_state then
        local step = auto_grid_qn_step()
        local step_label = "?"
        for _, o in ipairs(NOTE_LENGTH_OPTIONS) do
          if step and math.abs(o.qn - step) < 1e-6 then step_label = o.label; break end
        end
        -- подпись - по самому шагу: при «самых коротких» 1/8T шаг триольный, даже если по
        -- положению нот в долях партия сочтена прямой (иначе выходило «1/8T (прямые)»)
        text = string.format("Авто: %s (%s)", step_label, step_label:sub(-1) == "T" and "триоли" or "прямые")
      end
      hint(text, colB_x + BOX_W + 12, yB + 8, col_w - BOX_W - 12)
    end
    yB = yB + 38
  end
  if last_applied and #last_applied > 0 then
    hint("Галочка мгновенно двигает уже применённые стрейч-маркеры туда/обратно.", colB_x, yB, col_w)
    yB = yB + 20
  end

  -- референс-трек (та же партия гитары - MIDI или аудио): захват и подтягивание - в одном месте
  if draw_button(colB_x, yB, third_w, BOX_H, "Захватить референс", not analyzing, left_click) then
    start_reference_capture()
  end
  do
    local ref_status
    if reference then
      local _, rtname = reaper.GetTrackName(reference.track)
      ref_status = string.format("Референс (%s): %s, %d нот",
        reference.kind == "midi" and "MIDI" or "аудио", rtname or "?", #reference.notes)
    else
      ref_status = "Не захвачен - выделите 1 item (MIDI или аудио) и нажмите кнопку"
    end
    hint(ref_status, colB_x + third_w + 12, yB + 8, col_w - third_w - 12)
  end
  yB = yB + 36
  gfx.setfont(1, "Arial", 15)
  if draw_checkbox(colB_x, yB, S.reference_mode == 1, "Подтягивать группу к референсу", left_click) then
    S.reference_mode = (S.reference_mode == 1) and 0 or 1; save_settings()
  end
  yB = yB + 28
  if S.reference_mode == 1 then
    hint("Число/позиции нот референса - 'правда'; расхождение = сыграно не так, как надо.", colB_x, yB, col_w)
    yB = yB + 20
    gfx.setfont(1, "Arial", 15)
    if draw_checkbox(colB_x, yB, S.reference_inject == 1, "Досочинять ноты референса, которых нет у item", left_click) then
      S.reference_inject = (S.reference_inject == 1) and 0 or 1; save_settings()
    end
    yB = yB + 28
    if S.reference_inject == 1 then
      hint("Ищет ноту по звуку/питчу референса; вставленные - синим, проверьте на слух.", colB_x, yB, col_w)
      yB = yB + 20
    end
  end
  -- Сетка - ПОСЛЕДНИЙ этап конвейера и может перекрыть результат референса там, где нота
  -- референса не легла ровно на линию сетки - предупреждаем сразу, а не в логах.
  if S.gridsnap == 1 and S.reference_mode == 1 then
    hint("⚠ Сетка + Референс: сетка идёт последней и почти всегда перетянет результат референса.", colB_x, yB, col_w, col.warn)
    yB = yB + 16
    hint("Если нужен именно тайминг референса - выключите 'Привязку к сетке'.", colB_x, yB, col_w)
    yB = yB + 20
  end

  y = math.max(yA, yB) + 6
  draw_divider(left, y, content_w)
  y = y + 12

  -- === РЕЗУЛЬТАТ: те же две колонки; каждая строка = подпись + ряд кнопок (строки слева и
  -- справа на одной высоте) ===
  draw_section_title(left, y, "Результат")
  y = y + 20
  local yL, yR = y, y
  field_label("Результат применения:", colA_x, yL)
  yL = yL + 18
  local oclicked = draw_chip_row(colA_x, yL, col_w, CHIP_H, OUTPUT_MODES, S.output_mode, left_click)
  if oclicked then S.output_mode = oclicked; save_settings() end
  yL = yL + 34

  if S.output_mode == 1 then
    hint("Меняйте сетку и жмите «Применить» снова - прошлые маркеры заменяются, анализ не нужен.", colA_x, yL, content_w)
    yL = yL + 20
  end
  if S.output_mode == 3 then
    field_label("Сохранять атаку:", colA_x, yL)
    yL = yL + 18
    local hnames = {}
    for i, hm in ipairs(HYBRID_MARKERS) do hnames[i] = hm.label end
    local hclicked = draw_chip_row(colA_x, yL, col_w, CHIP_H, hnames, S.hybrid_marker_idx, left_click)
    if hclicked then S.hybrid_marker_idx = hclicked; save_settings() end
    yL = yL + 34
    field_label("Предел:", colA_x, yL)
    yL = yL + 18
    if draw_value_box(colA_x, yL, BOX_W, BOX_H, S.hybrid_max_stretch_pct .. "%", left_click) then
      S.hybrid_max_stretch_pct = edit_number("Гибрид: не растягивать ноту больше чем на, % (5-100)", S.hybrid_max_stretch_pct, 5, 100)
      save_settings()
    end
    hint("больше - пауза остаётся", colA_x + BOX_W + 12, yL + 8, col_w - BOX_W - 12)
    yL = yL + 34
  end
  if S.output_mode >= 2 then
    gfx.setfont(1, "Arial", 15)
    if draw_checkbox(colA_x, yL + 2, S.glue_after == 1, "Новый item после выравнивания", left_click) then
      S.glue_after = (S.glue_after == 1) and 0 or 1; save_settings()
    end
    yL = yL + 28
    if S.glue_after == 1 then
      if draw_checkbox(colA_x + 24, yL, S.keep_original == 1, "Оставить оригинал (в мьюте), результат - на треке [Q]", left_click) then
        S.keep_original = (S.keep_original == 1) and 0 or 1; save_settings()
      end
      yL = yL + 26
    end

    field_label("Ремонт:", colB_x, yR)
    yR = yR + 18
    local xnames = {}
    for i, xm in ipairs(SPLIT_XFADES) do xnames[i] = xm.label end
    local xclicked = draw_chip_row(colB_x, yR, col_w, CHIP_H, xnames, S.split_xfade_idx, left_click)
    if xclicked then S.split_xfade_idx = xclicked; save_settings() end
    yR = yR + 34
    field_label("Шорох медиатора:", colB_x, yR)
    yR = yR + 18
    local pclicked2 = draw_chip_row(colB_x, yR, col_w, CHIP_H, { "к концу пред. ноты", "к началу ноты" }, S.pick_to_idx, left_click)
    if pclicked2 then S.pick_to_idx = pclicked2; save_settings() end
    yR = yR + 34
    if S.pick_to_idx == 2 then
      field_label("На сетку ставить:", colB_x, yR)
      yR = yR + 18
      local aclicked2 = draw_chip_row(colB_x, yR, col_w, CHIP_H, { "атаку", "шорох" }, S.pick_align_idx, left_click)
      if aclicked2 then S.pick_align_idx = aclicked2; save_settings() end
      yR = yR + 34
    end
    hint("Нота удлиняется влево на 1/64 (1/128) ноты и S-кроссфейдом наезжает на хвост предыдущей.", colB_x, yR, col_w)
    yR = yR + 15
    hint(S.output_mode == 3 and "Нота с паузой после неё дотягивается до следующей (см. предел растяжения)."
      or "Края без кроссфейда (сдвиг вправо, «выкл») - микрофейд 1 мс против щелчков.", colB_x, yR, col_w)
    yR = yR + 18
  end
  y = math.max(yL, yR) + 6

  if last_batch_info and last_batch_info.ensemble_summary then
    gfx.setfont(1, "Arial", 12)
    for line in (last_batch_info.ensemble_summary .. "\n"):gmatch("(.-)\n") do
      if line ~= "" then
        draw_text(clip_text(line, content_w, 12), left, y, col.text_dim)
        y = y + 15
      end
    end
    y = y + 4
  end
  draw_divider(left, y, content_w)
  y = y + 12

  -- кнопки действий: четыре одинаковые; «Создать дабл-трек» ниже - той же ширины и высоты
  local btn_gap, btn_h = 12, 34
  local bw = (content_w - btn_gap * 3) / 4
  if draw_button(left, y, bw, btn_h, "Анализировать", not analyzing, left_click, col.btn_start) then
    start_analysis()
  end
  if draw_button(left + bw + btn_gap, y, bw, btn_h, "Превью", has_result and not analyzing, left_click) then
    local ensemble_active = S.ensemble_mode == 1 and #last_results > 1
    local consensus_lookup, injections
    if ensemble_active then
      consensus_lookup = compute_consensus(last_results, get_sync_tolerance_sec(last_results[1].item_start))
    end
    local all = {}
    for ti, res in ipairs(last_results) do
      local final = build_item_final_onsets(res, ti, consensus_lookup, ensemble_active, injections)
      for _, o in ipairs(final) do all[#all + 1] = o end
    end
    table.sort(all, function(a, b) return a.target < b.target end)
    set_preview_markers(all)
  end
  if draw_button(left + (bw + btn_gap) * 2, y, bw, btn_h, "Применить", has_result and not analyzing, left_click, col.btn_start) then
    apply_status = apply_results()
  end
  if draw_button(left + (bw + btn_gap) * 3, y, bw, btn_h, "Очистить", true, left_click) then
    clear_preview_markers()
  end
  y = y + btn_h + 10

  -- дабл-трек: копия item(ов) на новых треках, гибрид дрожания и заимствования звука
  if draw_button(left, y, bw, btn_h, "Создать дабл-трек", has_result and not analyzing, left_click, col.btn_start) then
    double_status = create_double_tracks()
  end
  gfx.setfont(1, "Arial", 15)
  if draw_checkbox(left + bw + btn_gap, y + 7, S.double_glue == 1, "Склеить дабл-трек", left_click) then
    S.double_glue = (S.double_glue == 1) and 0 or 1; save_settings()
  end
  y = y + btn_h + 8
  do
    -- пять полей дабл-трека: подпись над полем, поля одной ширины, шаг одинаковый
    local fields = {
      { label = "Радиус заимствования, с:", get = function() return string.format("%.1f", S.double_window_sec) end,
        edit = function()
          S.double_window_sec = edit_number_float("Радиус заимствования звука, секунд (0.3-10) - брать звук только у нот не дальше этого", S.double_window_sec, 0.3, 10)
        end },
      { label = "Заимствование, %:", get = function() return tostring(S.double_swap_pct) end,
        edit = function()
          S.double_swap_pct = edit_number("Доля нот, заимствующих звук похожего повтора, % (0-100)", S.double_swap_pct, 0, 100)
        end },
      { label = "Дрожание тайминга, ±мс:", get = function() return tostring(S.double_jitter_ms) end,
        edit = function()
          S.double_jitter_ms = edit_number("Дрожание тайминга, ± мс, на каждой ноте (0-30)", S.double_jitter_ms, 0, 30)
        end },
      { label = "Дрожание высоты, ±цент:", get = function() return tostring(S.double_jitter_cents) end,
        edit = function()
          S.double_jitter_cents = edit_number("Дрожание высоты, ± центов, на каждой ноте (0-50)", S.double_jitter_cents, 0, 50)
        end },
      { label = "Уход громкости, ±дБ:", get = function() return string.format("%.1f", S.double_level_db) end,
        edit = function()
          S.double_level_db = edit_number_float("Плавный уход громкости по фразе (несколько нот подряд), ± дБ (0-9) - как у настоящих дублей, не по одной ноте", S.double_level_db, 0, 9)
        end },
    }
    local cell_w = (content_w - btn_gap * (#fields - 1)) / #fields
    for i, fdef in ipairs(fields) do
      local fx = left + (i - 1) * (cell_w + btn_gap)
      gfx.setfont(1, "Arial", 12)
      draw_text(fdef.label, fx, y, col.text)
      if draw_value_box(fx, y + 16, math.min(BOX_W, cell_w), BOX_H, fdef.get(), left_click) then
        fdef.edit()
        save_settings()
      end
    end
  end
  y = y + 16 + BOX_H + 8

  if double_status then
    gfx.setfont(1, "Arial", 13)
    draw_text(clip_text(double_status, content_w, 13), left, y, col.accent2)
    y = y + 18
  end
  if apply_status then
    gfx.setfont(1, "Arial", 13)
    draw_text(clip_text(apply_status, content_w, 13), left, y, col.accent2)
    y = y + 18
  end
  hint("Порог фильтра и «самые короткие ноты» требуют повторного анализа. Сетка и режимы - «Применить» снова.", left, y, content_w)
  y = y + 20

  -- progress
  local pct, status = analysis_progress()
  draw_progress(left, y, content_w, 14, pct)
  y = y + 20
  gfx.setfont(1, "Arial", 13)
  draw_text(status, left, y, col.text_dim)
  y = y + 26

  -- Высота окна - по контенту (y), но не выше рабочей области экрана; если низ окна уходит
  -- за экран - окно поднимается. Размер меняется только когда нужная высота изменилась.
  local needed_h = clamp(math.ceil(y), MIN_WIN_H, MAX_WIN_H)
  local area_top, area_bottom = screen_work_area(win_x, win_y, w, needed_h)
  local new_y = win_y
  if area_top then
    needed_h = math.min(needed_h, math.max(MIN_WIN_H, area_bottom - area_top - WIN_FRAME_H))
    if win_y + needed_h + WIN_FRAME_H > area_bottom then
      new_y = math.max(area_top, area_bottom - needed_h - WIN_FRAME_H)
    end
  end
  if math.abs(needed_h - cur_win_h) > 1 or math.abs(new_y - win_y) > 1 then
    cur_win_h, win_y = needed_h, new_y
    gfx.init("", math.floor(w), math.floor(cur_win_h), 0, math.floor(win_x), math.floor(win_y))
  end

  last_mouse_cap = gfx.mouse_cap
  return nil
end

----------------------------------------------------------------------
-- MAIN LOOP
----------------------------------------------------------------------
local function safe_step_analysis()
  local ok, err = pcall(step_analysis, TIME_BUDGET_SEC)
  if not ok then
    reaper.ShowConsoleMsg("[DI Aligner] ERROR during analysis: " .. tostring(err) .. "\n")
    reaper.ShowMessageBox("Ошибка анализа:\n" .. tostring(err) .. "\n\nПодробности выведены в консоль REAPER.",
      "SSM DI Guitar Aligner", 0)
    ctx = nil
  end
end

local function main_loop()
  local char = gfx.getchar()
  if char == 27 or char < 0 then
    S.win_x, S.win_y = win_x, win_y
    save_settings()
    gfx.quit()
    return
  end

  if ctx then
    safe_step_analysis()
  end

  local ok, err = pcall(draw_window)
  if not ok then
    reaper.ShowConsoleMsg("[DI Aligner] ERROR in GUI: " .. tostring(err) .. "\n")
    reaper.ShowMessageBox("Ошибка интерфейса:\n" .. tostring(err), "SSM DI Guitar Aligner", 0)
    gfx.quit()
    return
  end
  gfx.update()

  reaper.defer(main_loop)
end

----------------------------------------------------------------------
-- ENTRY
----------------------------------------------------------------------
-- Режим библиотеки: серверный скрипт (обработка заданий бота) задаёт глобальную
-- SSM_DI_ALIGN_LIBRARY = true и загружает этот файл через dofile - окно не открывается,
-- возвращаются функции анализа и применения (тот же код, что у кнопок окна).
if SSM_DI_ALIGN_LIBRARY then
  return {
    version = SCRIPT_VERSION, S = S, GRID_MODES = GRID_MODES, OUTPUT_MODES = OUTPUT_MODES,
    SPLIT_XFADES = SPLIT_XFADES, MAX_ITEM_LEN_SEC = MAX_ITEM_LEN_SEC,
    start_analysis = start_analysis, step_analysis = step_analysis, analysis_progress = analysis_progress,
    is_analyzing = function() return ctx ~= nil end,
    results = function() return last_results end,
    apply = apply_results, cache_dir = cache_dir, detector_path = DETECTOR_PATH, detector_from = DETECTOR_FROM,
    reset = function() ctx, queue, last_results, last_batch_info, last_applied, reference = nil, nil, nil, nil, nil, nil end,
  }
end

gfx.init("SSM DI Guitar Aligner", WIN_W, DEFAULT_WIN_H, 0, math.floor(win_x), math.floor(win_y))
gfx.setfont(1, "Arial", 15)
reaper.defer(main_loop)
