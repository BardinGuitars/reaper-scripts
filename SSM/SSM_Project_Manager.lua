-- @description SSM_Project_Manager
-- @version 3.7
-- @author @ssm_metalmix
-- @about
--   🗂 Менеджер проектов: недавние (Recent projects) и все проекты из ваших
--   папок - поиск, сортировка, избранное, пометки, быстрое открытие, чистка.
--   Тёмный интерфейс с боковой панелью: слева источники и фильтры, справа сортировка, список и панель проекта.
--
--   Источник списка (боковая панель или кнопки справа вверху)
--     - «Недавние» - список Recent projects из reaper.ini (чистка, удаление);
--     - «Избранное» - проекты со звездой из любых списков;
--     - «Все проекты» - каталог файлов .rpp из папок, которые вы добавили
--       в «Папки». Список только для чтения: проекты можно искать,
--       сортировать, помечать, открывать, но не удалять. Сначала папок нет -
--       список пуст. В «Папки» - добавить/убрать папку, «Пересканировать»
--       (по кнопке; результат запоминается в файле рядом с reaper.ini),
--       исключения: папки Backups и файлы .rpp-bak (по умолчанию пропускаются).
--       Для выбора папки диалогом и для дат нужен js_ReaScriptAPI (без него
--       путь вводится вручную, а дат в «Всех проектах» нет).
--
--   Список и поиск
--     - колонки: галочка, ★, имя проекта (имя файла без .rpp), путь, дата
--       изменения (день-месяц-год), размер. Ширину имени, пути, даты и размера
--       можно менять - тащите разделители в строке заголовков (двойной клик по
--       разделителю возвращает стандартную ширину); ширина запоминается;
--     - строка поиска: просто печатайте - остаются проекты, в имени, пути или
--       пометке которых есть все введённые слова (регистр не важен);
--     - ряд кнопок сортировки: как в REAPER, по имени, папке, дате изменения
--       (нужен js_ReaScriptAPI), размеру, «не найденные»; повторный клик
--       меняет направление, выбор запоминается;
--     - фильтры: «Только не найденные» и «Возраст» (старше 3 мес. ... 2 лет);
--     - размер окна запоминается.
--   Избранное и пометки
--     - ★ у проекта: избранные защищены от массовых действий
--       («Отметить все», «Убрать пропавшие»); удаление отмеченного избранного
--       - только после подтверждения;
--     - пометка (F2 или клик по полю под списком): своя заметка или теги,
--       по ним тоже работает поиск.
--   Панель проекта (под списком)
--     - для проекта под курсором: версия REAPER, темп, частота, число треков,
--       примерная длина, плагины (читается из .rpp);
--     - «Показать в папке» открывает проводник (Finder) на файле проекта.
--   Открытие: двойной клик, Enter или кнопка «Открыть». Если отмечено несколько проектов - кнопка «Открыть отмеченные (N)» открывает их все
--   по очереди в новых вкладках. Галочка «Открывать в новой
--   вкладке» справа над кнопками: включена - проект открывается в новой вкладке
--   REAPER; выключена - в текущей (тогда REAPER сам спросит, сохранить ли
--   несохранённые изменения текущего проекта).
--   Клавиши: стрелки, PgUp/PgDn, Home/End - курсор; Tab или Insert - отметить
--   и перейти ниже; Shift+клик - отметить диапазон; Esc - очистить поиск (или
--   закрыть окно, если поиск пуст).
--   Удаление и откат
--     - «Удалить выбранные» и «Убрать пропавшие» убирают только записи из
--       списка, файлы проектов не трогаются; кнопки работают с тем, что
--       видно в списке (с учётом поиска и фильтров);
--     - «Вернуть удалённые» возвращает последнее удаление на прежние места.
--   Перед первым изменением делается резервная копия reaper.ini
--   (reaper.ini.ssm_bak). Список в меню REAPER обновится после перезапуска.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
-- @changelog
--   3.7 В «Настройках» (окно «Папки») галочки колонок списка: Имя, Путь, Дата, Размер. Выключенная колонка не рисуется, остаток строки забирает «Путь», а если он скрыт - «Имя»;
--   выбор запоминается. Хотя бы одна из колонок «Имя» и «Путь» остаётся всегда.
--   3.6.1 Ползунок списка дорожек в правой панели перетаскивается мышью (клик по дорожке переносит его), а не только листается колесом.
--   3.6 Справа - панель проекта (вместо карточки под списком): название, путь, темп / размер / частота / длина, список дорожек с номерами (с вложенностью папок, колесо мыши листает),
--   плагины, заметка и кнопки «Открыть», «Новая вкладка», «В избранное», «Заметка (F2)», «Папка». Список проектов стал выше.
--   3.5 Новый интерфейс: тёмная тема, боковая панель слева (источники «Все проекты», «Избранное», «Недавние», «Папки» со счётчиками; фильтры: переключатель «Только не найденные»,
--   меню «Возраст», «Размер», «Дата»), шапка с названием, поиском и кнопками «Избранное», «Недавние», «Настройки», ряд кнопок «Найденные / Все / Только не найденные / Возраст»,
--   галочка выбора всех в заголовке колонок, галочки во всех списках (можно открывать несколько отмеченных проектов из «Всех проектов» и «Избранного»), панель проекта карточкой,
--   «Выбрано: N (размер)» в подвале. Новый источник «Избранное» - проекты со звездой из любых списков. Сортировка «Не найденные» заменена фильтром. Удаление записей - только в «Недавних».
--   Избранные проекты больше не прижаты к верху списка: порядок один для всех (по выбранной сортировке); избранное видно по звезде и в источнике «Избранное».
--   3.4 «Открыть отмеченные»: если отмечено два проекта и больше, кнопка «Открыть» открывает их все по очереди, каждый в новой вкладке REAPER
--   (при пяти и больше - сначала вопрос). Идёт по одному за кадр, видно ход («Открываю 3 из 8»), кнопка «Остановить» или Esc прерывает.
--   3.3 Номер версии в заголовке окна (видно, какая версия запущена).
--   3.2 Выбор, как открывать проект: в новой вкладке или в текущей (галочка
--   «Открывать в новой вкладке»). В текущей вкладке REAPER спрашивает о
--   сохранении несохранённого проекта.
--   3.1 Полосу прокрутки справа можно тянуть мышью, клик по дорожке переносит
--   ползунок в это место.
--   3.0 Режим «Все проекты»: поиск по всем .rpp из выбранных папок. Кнопка
--   «Папки» (добавить/убрать папку, пересканировать, исключения Backups и
--   .rpp-bak), индекс запоминается. Переключатель «Недавние | Все проекты»
--   во втором ряду кнопок.
--   2.3 Колонка «Имя» (имя проекта из пути) между звездой и путём. Заголовки
--   колонок с разделителями: ширину имени, пути, даты и размера можно менять
--   мышью (запоминается, двойной клик по разделителю - сброс). Дата в формате
--   день-месяц-год.
--   2.2 Клавиатура (стрелки, Enter, Tab/Insert, Shift+клик), двойной клик
--   открывает проект, «Отметить все» / «Снять все», фильтры «Только не
--   найденные» и «Возраст». Избранное (★) и пометки с поиском по ним.
--   Панель проекта: темп, частота, треки, длина, плагины. «Показать в папке».
--   «Вернуть удалённые». Запоминается размер окна. Исправлен ввод кириллицы
--   в строке поиска.
--   2.1 Строка поиска по имени и пути (несколько слов - все должны совпасть).
--   2.0 Скрипт переименован: SSM_Recent_Cleanup -> SSM_Project_Manager (новый
--   пакет в ReaPack, старый SSM_Recent_Cleanup больше не обновляется).
--   Сохранённая сортировка подхватывается из старого скрипта.
--   1.3 Крупнее шрифт и элементы окна. Кнопка «Открыть выбранный» в нижнем
--   ряду - открывает отмеченный проект в новой вкладке.
--   1.2 Ряд кнопок сортировки списка (как в REAPER / имя / папка / дата /
--   размер / не найденные), в строках показываются дата и размер файла.
--   1.1 Окно со списком: ручной выбор ненужных проектов галочками.
--   1.0 Релиз: автоматическое удаление несуществующих проектов.

-- Номер версии берётся из строки "@version" самого скрипта и показывается в заголовке
-- окна: сразу видно, какая версия запущена (после обновления окно нужно открыть заново).
local function script_version()
  local ok, ver = pcall(function()
    local src = debug.getinfo(1, "S").source:gsub("^@", "")
    local f = io.open(src, "rb")
    if not f then return nil end
    local head = f:read(2048)
    f:close()
    return head and head:match("@version%s+([%d%.]+)")
  end)
  return ok and ver or nil
end
local TITLE = "SSM Project Manager" .. (script_version() and (" " .. script_version()) or "")
local WIN_W, WIN_H = 1300, 820
local MIN_W, MIN_H = 1180, 640
local SIDE_W = 236 -- боковая панель: источники и фильтры
local HEAD_H, FOOT_H, ROW_H = 92, 112, 36
local EXT_SECTION = "SSM_ProjectManager"
local OLD_EXT_SECTION = "SSM_RecentCleanup" -- настройки прежнего названия скрипта
local COLS_H = 32 -- строка заголовков колонок
local COL_DEF = { name = 220, date = 100, size = 84 } -- стандартная ширина, пикселей
local COL_MIN = { name = 60, path = 100, date = 70, size = 56 }
local INDEX_NAME = "SSM_ProjectManager_index.txt" -- индекс «Всех проектов», рядом с reaper.ini
local SCAN_BUDGET, SCAN_MAX_DEPTH = 0.02, 20      -- секунд на кадр; глубина вложенности папок
local SET_ROW_Y0, SET_ROW_H = HEAD_H + 84, 36     -- окно «Папки»: первая строка и высота строки
local F_ROW, F_TITLE, F_SMALL, F_BTN, F_SORT = 17, 22, 15, 17, 16
local CB = 20 -- сторона чекбокса
local STAR_X, STAR_W = 42, 22
local TEXT_X = 72 -- начало имени в строке списка (от левого края списка)
local BTN_W = 190 -- ширина кнопок панели проекта
local DOUBLE_CLICK = 0.4 -- секунд
local INFO_MAX_BYTES = 40 * 1024 * 1024

local ini_path = reaper.get_ini_file()

local col = {
  bg = { 0.047, 0.067, 0.102 }, panel = { 0.071, 0.098, 0.145 }, card = { 0.082, 0.114, 0.165 },
  row_alt = { 0.060, 0.084, 0.124 }, sel = { 0.063, 0.200, 0.400 },
  text = { 0.91, 0.93, 0.96 }, dim = { 0.56, 0.62, 0.71 }, accent = { 0.075, 0.435, 0.905 },
  accent_hover = { 0.14, 0.51, 0.97 }, accent_text = { 0.36, 0.64, 1.0 },
  border = { 0.150, 0.200, 0.285 }, danger = { 0.95, 0.42, 0.42 },
  btn = { 0.095, 0.130, 0.190 }, btn_hover = { 0.135, 0.185, 0.270 }, btn_off = { 0.070, 0.095, 0.138 },
  btn_danger = { 0.50, 0.17, 0.20 }, star = { 1.0, 0.80, 0.25 }, tag = { 0.55, 0.75, 1.0 }, tag_bg = { 0.075, 0.155, 0.285 },
}

-- Коды клавиш gfx.getchar (многобайтные значения из документации REAPER)
local KEY = {
  up = 30064, down = 1685026670, pgup = 1885828464, pgdn = 1885824110,
  home = 1752132965, ["end"] = 6647396, ins = 6909555, f2 = 26162,
}

----------------------------------------------------------------------
-- reaper.ini: чтение и запись секции [Recent]
----------------------------------------------------------------------
local function load_ini()
  local f = io.open(ini_path, "rb")
  if not f then return nil, "Не удалось открыть reaper.ini: " .. tostring(ini_path) end
  local data = f:read("*a")
  f:close()

  local st = {
    data = data,
    eol = data:find("\r\n", 1, true) and "\r\n" or "\n",
    ends_with_eol = data:sub(-1) == "\n",
    lines = {}, recents = {}, others = {}, key_width = 2,
  }

  local pos = 1
  while pos <= #data do
    local s, e = data:find("\n", pos, true)
    local line
    if s then line = data:sub(pos, s - 1); pos = e + 1
    else line = data:sub(pos); pos = #data + 1 end
    line = line:gsub("\r$", "")
    st.lines[#st.lines + 1] = line
  end

  for i, line in ipairs(st.lines) do
    if line == "[Recent]" then
      st.sec_start = i
    elseif st.sec_start and not st.sec_end and line:match("^%[") then
      st.sec_end = i - 1
    end
  end
  if not st.sec_start then return st end
  st.sec_end = st.sec_end or #st.lines

  for i = st.sec_start + 1, st.sec_end do
    local n, path = st.lines[i]:match("^recent(%d+)=(.*)$")
    if n then
      if #st.recents == 0 then st.key_width = #n end
      st.recents[#st.recents + 1] = { num = tonumber(n), path = path }
    elseif st.lines[i] ~= "" then
      st.others[#st.others + 1] = st.lines[i]
    end
  end
  table.sort(st.recents, function(a, b) return a.num < b.num end)
  return st
end

local function write_ini(st, keep_paths)
  local out = {}
  for i = 1, st.sec_start do out[#out + 1] = st.lines[i] end
  for i, path in ipairs(keep_paths) do
    out[#out + 1] = string.format("recent%0" .. st.key_width .. "d=%s", i, path)
  end
  for _, line in ipairs(st.others) do out[#out + 1] = line end
  for i = st.sec_end + 1, #st.lines do out[#out + 1] = st.lines[i] end

  local wf = io.open(ini_path, "wb")
  if not wf then return false end
  wf:write(table.concat(out, st.eol) .. (st.ends_with_eol and st.eol or ""))
  wf:close()
  return true
end

----------------------------------------------------------------------
-- Состояние окна
----------------------------------------------------------------------
local status = ""
local query = ""           -- строка поиска
local backup_done = false
local last_cap = 0
local edit = nil           -- редактирование пометки: { it = проект, buf = текст }
local cursor = nil         -- проект под курсором (панель проекта, Enter, стрелки)
local anchor = nil         -- от него считается диапазон Shift+клик
local follow_cursor = false
local last_click_it, last_click_t = nil, 0
local undo_stack = {}      -- удаления: { removed = { {pos=, path=}, ... } }
local source = "recent"    -- источник списка: "recent" (Recent projects) | "library" (все проекты)
local show_settings = false -- открыто окно «Папки»
local recent_items = {}    -- список Recent (активный список - items)
local fav_items = {}       -- источник «Избранное»: проекты с ★ из любых списков (собирается при выборе источника)
local lib = { dirs = {}, items = {}, loaded = false, skip_backups = true, with_bak = false, scan = nil }

----------------------------------------------------------------------
-- Избранное и пометки (ExtState; пути кодируются, чтобы не ломать формат)
----------------------------------------------------------------------
local favs, notes = {}, {}

local function enc(s)
  return (s:gsub("[%%|=%c]", function(c) return string.format("%%%02X", c:byte()) end))
end

local function dec(s)
  return (s:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end))
end

local function load_meta()
  favs, notes = {}, {}
  for rec in (reaper.GetExtState(EXT_SECTION, "favs") .. "|"):gmatch("([^|]*)|") do
    if rec ~= "" then favs[dec(rec)] = true end
  end
  for rec in (reaper.GetExtState(EXT_SECTION, "notes") .. "|"):gmatch("([^|]*)|") do
    local p, n = rec:match("^([^=]*)=(.*)$")
    if p and n ~= "" then notes[dec(p)] = dec(n) end
  end
end

local function save_meta()
  local f, n = {}, {}
  for p in pairs(favs) do f[#f + 1] = enc(p) end
  for p, t in pairs(notes) do n[#n + 1] = enc(p) .. "=" .. enc(t) end
  table.sort(f); table.sort(n)
  reaper.SetExtState(EXT_SECTION, "favs", table.concat(f, "|"), true)
  reaper.SetExtState(EXT_SECTION, "notes", table.concat(n, "|"), true)
end

load_meta()

----------------------------------------------------------------------
-- Сортировка и фильтры (только отображение - порядок в reaper.ini не меняется)
----------------------------------------------------------------------
local SORT_KEYS = {
  { key = "order",   label = "Как в REAPER", default_desc = false },
  { key = "name",    label = "Имя",          default_desc = false },
  { key = "folder",  label = "Папка",        default_desc = false },
  { key = "date",    label = "Дата",         default_desc = true },  -- сначала новые
  { key = "size",    label = "Размер",       default_desc = true },  -- сначала большие
  { key = "missing", label = "Не найденные", default_desc = false }, -- сначала пропавшие
}

local SORT_BUTTONS = {}
for _, sk in ipairs(SORT_KEYS) do if sk.key ~= "missing" then SORT_BUTTONS[#SORT_BUTTONS + 1] = sk end end

local AGE_STEPS = { { 0, "любой" }, { 90, "старше 3 мес." }, { 180, "старше 6 мес." },
  { 365, "старше 1 года" }, { 730, "старше 2 лет" } }
-- размер файла (байты, от и до) и «изменён не раньше, чем N дней назад»
local MB = 1024 * 1024
local SIZE_STEPS = { { nil, "любой" }, { { 0, 1 * MB }, "до 1 МБ" }, { { 1 * MB, 10 * MB }, "1-10 МБ" }, { { 10 * MB, math.huge }, "больше 10 МБ" } }
local DATE_STEPS = { { 0, "любая" }, { 1, "за сутки" }, { 7, "за 7 дней" }, { 30, "за 30 дней" }, { 365, "за год" } }

local sort_key, sort_desc = "order", false
do
  local section = EXT_SECTION
  if reaper.GetExtState(section, "sort_key") == "" then section = OLD_EXT_SECTION end
  local k = reaper.GetExtState(section, "sort_key")
  for _, sk in ipairs(SORT_KEYS) do if sk.key == k then sort_key = k end end
  sort_desc = reaper.GetExtState(section, "sort_desc") == "1"
end

local f_missing, f_found, f_age, f_size, f_date = false, false, 1, 1, 1 -- фильтры: только пропавшие, только найденные, возраст, размер, дата (индексы шагов)

local has_js_stat = reaper.JS_File_Stat ~= nil
local has_dates = false

-- Нижний регистр с кириллицей (string.lower понимает только ASCII)
local function fold(s)
  local ok, res = pcall(function()
    local out = {}
    for _, cp in utf8.codes(s) do
      if cp >= 0x41 and cp <= 0x5A then cp = cp + 32
      elseif cp >= 0x410 and cp <= 0x42F then cp = cp + 32
      elseif cp == 0x401 then cp = 0x451 end
      out[#out + 1] = utf8.char(cp)
    end
    return table.concat(out)
  end)
  return ok and res or s:lower()
end

-- Размер и (при наличии js_ReaScriptAPI) дата изменения "ГГГГ.ММ.ДД чч:мм:сс"
local function file_info(path)
  if has_js_stat then
    local rv, size, _, mtime = reaper.JS_File_Stat(path)
    if rv == 0 and type(mtime) == "string" and mtime:match("^%d%d%d%d%.%d%d%.%d%d") then
      return size, mtime
    end
  end
  local f = io.open(path, "rb")
  if f then
    local size = f:seek("end")
    f:close()
    return size, nil
  end
  return nil, nil
end

local function fmt_size(bytes)
  if not bytes then return "" end
  if bytes < 1024 then return string.format("%d Б", bytes) end
  if bytes < 1024 * 1024 then return string.format("%.0f КБ", bytes / 1024) end
  return string.format("%.1f МБ", bytes / 1024 / 1024)
end

-- "ГГГГ.ММ.ДД чч:мм:сс" -> "ДД-ММ-ГГГГ"
local function fmt_date(mtime)
  if not mtime then return "" end
  local y, m, d = mtime:match("^(%d%d%d%d)%.(%d%d)%.(%d%d)")
  if not y then return "" end
  return d .. "-" .. m .. "-" .. y
end

local function compare_items(a, b)
  local va, vb
  if sort_key == "name" then va, vb = a.name_l, b.name_l
  elseif sort_key == "folder" then va, vb = a.dir_l, b.dir_l
  elseif sort_key == "date" then va, vb = a.mtime, b.mtime
  elseif sort_key == "size" then va, vb = a.size, b.size
  elseif sort_key == "missing" then va, vb = a.exists and 1 or 0, b.exists and 1 or 0
  else va, vb = a.ord, b.ord end
  -- нет данных (nil) - всегда в конец, независимо от направления
  if va == nil or vb == nil then
    if va == nil and vb == nil then return a.ord < b.ord end
    return vb == nil
  end
  if va == vb then return a.ord < b.ord end
  if sort_desc then return va > vb end
  return va < vb
end

local items = {}
local view = {} -- то, что видно в списке: items после сортировки, поиска и фильтров
local scroll = 0
local rp_scroll, rp_cursor = 0, nil -- прокрутка списка дорожек в правой панели и проект, для которого она сделана
local rp_drag = nil                 -- пока тащат ползунок списка дорожек: смещение мыши от его верха

local function index_of(it)
  for i, v in ipairs(view) do if v == it then return i end end
  return nil
end

local function filters_active()
  return query ~= "" or f_missing or f_found or f_age > 1 or f_size > 1 or f_date > 1
end

local function refresh_view()
  local words = {}
  for wd in fold(query):gmatch("%S+") do words[#words + 1] = wd end
  local cutoff
  if f_age > 1 then
    cutoff = os.date("%Y.%m.%d %H:%M:%S", os.time() - AGE_STEPS[f_age][1] * 86400)
  end
  local newer
  if f_date > 1 then
    newer = os.date("%Y.%m.%d %H:%M:%S", os.time() - DATE_STEPS[f_date][1] * 86400)
  end
  local size_range = SIZE_STEPS[f_size][1]
  view = {}
  for _, it in ipairs(items) do
    local ok = true
    for _, wd in ipairs(words) do
      if not it.hay_l:find(wd, 1, true) then ok = false; break end
    end
    if ok and f_missing and it.exists then ok = false end
    if ok and f_found and not it.exists then ok = false end
    if ok and cutoff and not (it.mtime and it.mtime < cutoff) then ok = false end
    if ok and newer and not (it.mtime and it.mtime >= newer) then ok = false end
    if ok and size_range and not (it.size and it.size >= size_range[1] and it.size < size_range[2]) then ok = false end
    if ok then view[#view + 1] = it end
  end
  if not index_of(cursor) then cursor = view[1] end
  if not index_of(anchor) then anchor = nil end
end

local function apply_sort()
  table.sort(items, compare_items)
  refresh_view()
end

-- Скрытые поиском и фильтрами проекты теряют галочку: кнопки внизу действуют
-- только на видимое
local function after_filter_change()
  refresh_view()
  local visible = {}
  for _, it in ipairs(view) do visible[it] = true end
  for _, it in ipairs(items) do if not visible[it] then it.checked = false end end
  scroll = 0
end

local function set_query(q)
  if q == query then return end
  query = q
  after_filter_change()
end

local function set_sort(key)
  if key == sort_key then
    sort_desc = not sort_desc
  else
    sort_key = key
    for _, sk in ipairs(SORT_KEYS) do if sk.key == key then sort_desc = sk.default_desc end end
  end
  reaper.SetExtState(EXT_SECTION, "sort_key", sort_key, true)
  reaper.SetExtState(EXT_SECTION, "sort_desc", sort_desc and "1" or "0", true)
  apply_sort()
  scroll = 0
end

local function set_note_of(it, text)
  it.note = text
  it.hay_l = it.path_l .. " " .. fold(text)
  notes[it.path] = text ~= "" and text or nil
  save_meta()
  refresh_view()
end

local function make_item(path, exists, size, mtime, ord)
  local name = path:match("([^\\/]+)$") or path
  local dir = path:sub(1, #path - #name)
  local title = (name:gsub("%.[Rr][Pp][Pp][%-%w]*$", "")) -- имя проекта: без .rpp / .rpp-bak
  if title == "" then title = name end
  local note = notes[path] or ""
  local path_l = fold(path)
  return {
    path = path, title = title, exists = exists, checked = false, ord = ord,
    name_l = fold(name), dir_l = fold(dir), path_l = path_l, size = size, mtime = mtime,
    fav = favs[path] == true, note = note, hay_l = path_l .. " " .. fold(note),
  }
end

local function update_has_dates()
  has_dates = false
  for _, it in ipairs(items) do if it.mtime then has_dates = true; break end end
end

-- Избранное и пометки общие для обоих списков: после переключения источника подтянуть их
local function refresh_meta(list)
  for _, it in ipairs(list) do
    it.fav = favs[it.path] == true
    local n = notes[it.path] or ""
    if n ~= it.note then it.note = n; it.hay_l = it.path_l .. " " .. fold(n) end
  end
end

local function reload()
  local st, err = load_ini()
  if not st then return false, err end
  local keep_idx = index_of(cursor)
  local list = {}
  for _, r in ipairs(st.recents) do
    local exists = r.path ~= "" and reaper.file_exists(r.path)
    local size, mtime
    if exists then size, mtime = file_info(r.path) end
    list[#list + 1] = make_item(r.path, exists, size, mtime, #list + 1)
  end
  recent_items = list
  if source == "recent" then
    items = list
    cursor, anchor = nil, nil
    update_has_dates()
    apply_sort()
    if keep_idx and #view > 0 then cursor = view[math.min(keep_idx, #view)] end
  end
  return true
end

----------------------------------------------------------------------
-- Библиотека: все проекты из выбранных папок (режим «Все проекты»)
----------------------------------------------------------------------
local set_source -- ниже: переключение источника списка

do
  local INDEX_PATH = (ini_path:match("^(.*)[/\\][^/\\]*$") or ".") .. "/" .. INDEX_NAME
  local IS_WIN = (reaper.GetOS() or ""):find("^Win") ~= nil

  for rec in (reaper.GetExtState(EXT_SECTION, "lib_dirs") .. "|"):gmatch("([^|]*)|") do
    if rec ~= "" then lib.dirs[#lib.dirs + 1] = dec(rec) end
  end
  lib.skip_backups = reaper.GetExtState(EXT_SECTION, "lib_skip_backups") ~= "0"
  lib.with_bak = reaper.GetExtState(EXT_SECTION, "lib_with_bak") == "1"

  function lib.save_settings()
    local d = {}
    for _, p in ipairs(lib.dirs) do d[#d + 1] = enc(p) end
    reaper.SetExtState(EXT_SECTION, "lib_dirs", table.concat(d, "|"), true)
    reaper.SetExtState(EXT_SECTION, "lib_skip_backups", lib.skip_backups and "1" or "0", true)
    reaper.SetExtState(EXT_SECTION, "lib_with_bak", lib.with_bak and "1" or "0", true)
  end

  local function join_path(dir, name)
    local last = dir:sub(-1)
    if last == "/" or last == "\\" then return dir .. name end
    return dir .. ((IS_WIN or dir:find("\\", 1, true)) and "\\" or "/") .. name
  end

  -- лежит ли файл в одной из выбранных папок (без учёта регистра и вида разделителя)
  local function under_dirs(p)
    local pl = fold(p)
    for _, d in ipairs(lib.dirs) do
      local dl = fold(d):gsub("[/\\]+$", "")
      if pl:sub(1, #dl) == dl and pl:sub(#dl + 1, #dl + 1):match("[/\\]") then return true end
    end
    return false
  end

  -- Индекс: строка заголовка, затем "путь<TAB>дата<TAB>размер"
  local function save_index(entries)
    local f = io.open(INDEX_PATH, "wb")
    if not f then return false end
    f:write("SSM_PM_INDEX 1\n")
    for _, e in ipairs(entries) do
      f:write(e.path, "\t", e.mtime or "", "\t", tostring(e.size or ""), "\n")
    end
    f:close()
    return true
  end

  local function load_index()
    local entries = {}
    local f = io.open(INDEX_PATH, "rb")
    if not f then return entries end
    if f:read("*l") == "SSM_PM_INDEX 1" then
      for line in f:lines() do
        local p, m, sz = line:match("^([^\t]*)\t([^\t]*)\t([^\t]*)$")
        if p and p ~= "" then
          entries[#entries + 1] = { path = p, mtime = m ~= "" and m or nil, size = tonumber(sz) }
        end
      end
    end
    f:close()
    return entries
  end

  -- verify: проверить, что файлы всё ещё на месте (для данных из индекса)
  local function build(entries, verify)
    local list = {}
    for _, e in ipairs(entries) do
      local exists = true
      if verify then exists = reaper.file_exists(e.path) end
      list[#list + 1] = make_item(e.path, exists, e.size, e.mtime, #list + 1)
    end
    return list
  end

  local function reset_active_list()
    if source ~= "library" then return end
    items = lib.items
    cursor, anchor = nil, nil
    update_has_dates()
    apply_sort()
    scroll = 0
  end

  -- сколько проектов в индексе (для счётчика в боковой панели, до первой загрузки списка)
  function lib.index_count()
    if lib.index_n then return lib.index_n end
    local n = 0
    for _, e in ipairs(load_index()) do if under_dirs(e.path) then n = n + 1 end end
    lib.index_n = n
    return n
  end

  function lib.ensure_loaded()
    if lib.loaded then return end
    lib.loaded = true
    local entries = {}
    for _, e in ipairs(load_index()) do
      if under_dirs(e.path) then entries[#entries + 1] = e end
    end
    lib.items = build(entries, true)
    lib.index_n = nil
  end

  local function is_project_file(name)
    if name:sub(1, 2) == "._" then return false end -- служебные файлы macOS
    local low = name:lower()
    return low:match("%.rpp$") ~= nil or (lib.with_bak and low:match("%.rpp%-bak$") ~= nil)
  end

  function lib.start_scan()
    if lib.scan then return end
    if #lib.dirs == 0 then status = "Сначала добавьте папку с проектами (кнопка «Папки»)."; return end
    local stack = {}
    for i = #lib.dirs, 1, -1 do stack[#stack + 1] = { dir = lib.dirs[i], depth = 0 } end
    lib.scan = { stack = stack, found = {}, seen = {}, ndirs = 0 }
    status = "Сканирование…"
  end

  function lib.stop_scan()
    lib.scan = nil
    status = "Сканирование остановлено, список не изменён."
  end

  local function finish_scan()
    local sc = lib.scan
    lib.scan = nil
    lib.loaded = true
    save_index(sc.found)
    lib.items = build(sc.found, false)
    reset_active_list()
    status = string.format("Найдено проектов: %d (папок просмотрено: %d).", #sc.found, sc.ndirs)
  end

  -- Обход папок небольшими порциями: один кадр - не дольше SCAN_BUDGET секунд
  function lib.scan_step()
    local sc = lib.scan
    if not sc then return end
    local t0 = reaper.time_precise()
    while #sc.stack > 0 do
      local d = table.remove(sc.stack)
      sc.ndirs = sc.ndirs + 1
      reaper.EnumerateFiles(d.dir, -1) -- сбросить кэш каталога, чтобы пересканирование видело новые файлы
      reaper.EnumerateSubdirectories(d.dir, -1)
      local i = 0
      while true do
        local fn = reaper.EnumerateFiles(d.dir, i)
        if not fn then break end
        i = i + 1
        if is_project_file(fn) then
          local p = join_path(d.dir, fn)
          if not sc.seen[p] then
            sc.seen[p] = true
            local size, mtime = file_info(p)
            sc.found[#sc.found + 1] = { path = p, size = size, mtime = mtime }
          end
        end
      end
      if d.depth < SCAN_MAX_DEPTH then
        local subs, j = {}, 0
        while true do
          local sn = reaper.EnumerateSubdirectories(d.dir, j)
          if not sn then break end
          j = j + 1
          if not (lib.skip_backups and sn:lower() == "backups") then subs[#subs + 1] = sn end
        end
        for k = #subs, 1, -1 do -- в обратном порядке: со стека берутся по алфавиту
          sc.stack[#sc.stack + 1] = { dir = join_path(d.dir, subs[k]), depth = d.depth + 1 }
        end
      end
      if reaper.time_precise() - t0 >= SCAN_BUDGET then break end
    end
    if #sc.stack == 0 then
      finish_scan()
    else
      status = string.format("Сканирование… найдено проектов: %d, папок просмотрено: %d", #sc.found, sc.ndirs)
    end
  end

  local function normalize_dir(dir)
    dir = dir:gsub("^%s+", ""):gsub("%s+$", "")
    if IS_WIN then dir = dir:gsub("/", "\\") end
    local trimmed = dir:gsub("[/\\]+$", "")
    if trimmed == "" then return dir end
    if trimmed:match("^%a:$") then return trimmed .. "\\" end
    return trimmed
  end

  function lib.add_dir(dir)
    dir = normalize_dir(dir or "")
    if dir == "" then return end
    if has_js_stat and reaper.JS_File_Stat(dir) ~= 0 then status = "Папка не найдена: " .. dir; return end
    local dl = fold(dir)
    for _, d in ipairs(lib.dirs) do
      if fold(d) == dl then status = "Эта папка уже в списке."; return end
    end
    lib.dirs[#lib.dirs + 1] = dir
    lib.save_settings()
    lib.scan = nil
    lib.start_scan()
  end

  function lib.remove_dir(i)
    local removed = table.remove(lib.dirs, i)
    if not removed then return end
    lib.save_settings()
    lib.scan = nil
    lib.ensure_loaded()
    local keep = {}
    for _, it in ipairs(lib.items) do -- проекты убранной папки уходят из индекса
      if under_dirs(it.path) then keep[#keep + 1] = { path = it.path, size = it.size, mtime = it.mtime } end
    end
    save_index(keep)
    lib.items = build(keep, false)
    reset_active_list()
    status = "Папка убрана из списка: " .. removed
  end

  function lib.add_folder_dialog()
    local dir
    if reaper.JS_Dialog_BrowseForFolder then
      local rv, folder = reaper.JS_Dialog_BrowseForFolder("Папка с проектами", lib.dirs[#lib.dirs] or "")
      if rv == 1 then dir = folder end
    else
      local ok, val = reaper.GetUserInputs("Папка с проектами", 1, "Путь к папке,extrawidth=420", "")
      if ok then dir = val end
    end
    if dir and dir ~= "" then lib.add_dir(dir) end
  end
end

-- проекты с ★: берутся из избранного (по путям), размер и дата - с диска
local function build_fav_items()
  local paths = {}
  for p in pairs(favs) do paths[#paths + 1] = p end
  table.sort(paths, function(a, b) return fold(a) < fold(b) end)
  local list = {}
  for _, p in ipairs(paths) do
    local exists = p ~= "" and reaper.file_exists(p)
    local size, mtime
    if exists then size, mtime = file_info(p) end
    list[#list + 1] = make_item(p, exists, size, mtime, #list + 1)
  end
  return list
end

set_source = function(src)
  if src == source and not show_settings then return end
  show_settings = false
  edit = nil
  if src == "library" then lib.ensure_loaded() end
  source = src
  if src == "favs" then fav_items = build_fav_items() end
  items = (src == "recent") and recent_items or (src == "favs" and fav_items or lib.items)
  refresh_meta(items)
  cursor, anchor, last_click_it = nil, nil, nil
  update_has_dates()
  apply_sort()
  scroll = 0
end

local function count_missing()
  local n = 0
  for _, it in ipairs(view) do if not it.exists then n = n + 1 end end
  return n
end

-- Пропавшие, которые «Убрать пропавшие» тронет: избранные защищены
local function count_missing_unprotected()
  local n = 0
  for _, it in ipairs(view) do if not it.exists and not it.fav then n = n + 1 end end
  return n
end

local function count_checked()
  local n = 0
  for _, it in ipairs(view) do if it.checked then n = n + 1 end end
  return n
end

local function toggle_fav(it)
  it.fav = not it.fav
  favs[it.path] = it.fav or nil
  save_meta()
  if source == "favs" and not it.fav then -- в «Избранном» проект без ★ из списка уходит
    for i, v in ipairs(items) do if v == it then table.remove(items, i); break end end
    if cursor == it then cursor = nil end
  end
  apply_sort()
end

----------------------------------------------------------------------
-- Изменение списка Recent: удаление и откат
----------------------------------------------------------------------
local function ensure_backup(st)
  if backup_done then return true end
  local bak = io.open(ini_path .. ".ssm_bak", "wb")
  if not bak then return false end
  bak:write(st.data)
  bak:close()
  backup_done = true
  return true
end

-- Перечитывает reaper.ini заново перед записью (чтобы не затереть то, что
-- REAPER мог изменить с момента открытия окна) и убирает записи по предикату.
local function remove_where(pred)
  local st, err = load_ini()
  if not st then status = err; return end

  local keep, removed = {}, {}
  for i, r in ipairs(st.recents) do
    if pred(r.path) then removed[#removed + 1] = { pos = i, path = r.path } else keep[#keep + 1] = r.path end
  end
  if #removed == 0 then status = "Нечего удалять."; return end

  if not ensure_backup(st) then
    status = "Не удалось создать резервную копию reaper.ini - ничего не изменено."; return
  end
  if not write_ini(st, keep) then status = "Не удалось записать reaper.ini - ничего не изменено."; return end

  undo_stack[#undo_stack + 1] = { removed = removed, total = #st.recents }
  reload()
  status = string.format("Удалено из списка: %d. Осталось: %d. Кнопка «Вернуть удалённые» отменит удаление.",
    #removed, #items)
end

-- Возвращает записи последнего удаления на прежние места (по текущему списку REAPER)
local function restore_last()
  local op = undo_stack[#undo_stack]
  if not op then return end
  local st, err = load_ini()
  if not st then status = err; return end

  local list, present = {}, {}
  for _, r in ipairs(st.recents) do list[#list + 1] = r.path; present[r.path] = true end
  -- Позиция считается от конца списка: новые проекты REAPER добавляет в начало, и
  -- индекс от начала сдвинулся бы. Идём от последней удалённой записи к первой -
  -- к моменту вставки все записи правее уже на месте.
  local back = 0
  for i = #op.removed, 1, -1 do
    local r = op.removed[i]
    if not present[r.path] then
      local idx = #list - (op.total - r.pos) + 1
      table.insert(list, math.max(1, math.min(idx, #list + 1)), r.path)
      present[r.path] = true
      back = back + 1
    end
  end

  if not ensure_backup(st) then
    status = "Не удалось создать резервную копию reaper.ini - ничего не изменено."; return
  end
  if not write_ini(st, list) then status = "Не удалось записать reaper.ini - ничего не изменено."; return end

  undo_stack[#undo_stack] = nil
  reload()
  status = string.format("Возвращено в список: %d. Меню REAPER обновится после перезапуска.", back)
end

-- Как открывать проект: в новой вкладке (по умолчанию) или в текущей
local open_new_tab = reaper.GetExtState(EXT_SECTION, "open_new_tab") ~= "0"

-- Новая вкладка (действие 40859): текущий проект не трогается; "noprompt:" - без вопроса
-- о сохранении пустой вкладки. В текущей вкладке имя без "noprompt:" - REAPER сам
-- спросит, сохранить ли несохранённые изменения, ничего не потеряется молча.
local function open_project(it, force_tab)
  if not it or not it.exists then return end
  local name = it.path:match("([^\\/]+)$") or it.path
  if open_new_tab or force_tab then
    reaper.Main_OnCommand(40859, 0)
    reaper.Main_openProject("noprompt:" .. it.path)
    status = "Открыт в новой вкладке: " .. name
  else
    reaper.Main_openProject(it.path)
    status = "Открыт в текущей вкладке: " .. name
  end
end

-- Несколько отмеченных проектов открываются по очереди: по одному за кадр окна (окно не замирает, видно ход
-- и можно остановить). Всегда в новых вкладках: в текущей вкладке каждый следующий закрыл бы предыдущий.
local open_queue -- { list = {проекты}, i = номер следующего, total = всего, missing = пропавших файлов }

local function start_open_queue(checked)
  local list, missing = {}, 0
  for _, it in ipairs(checked) do
    if it.exists then list[#list + 1] = it else missing = missing + 1 end
  end
  if #list == 0 then status = "Отмеченные проекты не найдены на диске - открывать нечего."; return end
  if #list >= 5 then
    local ans = reaper.ShowMessageBox(string.format(
      "Открыть по очереди %d проектов в новых вкладках?\nREAPER будет занят, пока они загружаются (остановить можно кнопкой или Esc).", #list), TITLE, 4)
    if ans ~= 6 then status = "Открытие отменено."; return end
  end
  open_queue = { list = list, i = 1, total = #list, missing = missing }
end

local function stop_open_queue(why)
  if not open_queue then return end
  local q = open_queue
  open_queue = nil
  status = string.format("%s: открыто %d из %d%s.", why, q.i - 1, q.total,
    q.missing > 0 and string.format(", пропавших файлов пропущено: %d", q.missing) or "")
end

-- один проект очереди (вызывается раз за кадр)
local function open_queue_step()
  local q = open_queue
  if not q then return end
  if q.i > q.total then stop_open_queue("Готово"); return end
  local it = q.list[q.i]
  status = string.format("Открываю %d из %d: %s", q.i, q.total, it.path:match("([^\\/]+)$") or it.path)
  reaper.Main_OnCommand(40859, 0)
  reaper.Main_openProject("noprompt:" .. it.path)
  q.i = q.i + 1
  if q.i > q.total then stop_open_queue("Готово") end
end

-- Показывает файл проекта в проводнике / Finder
local function reveal_in_folder(it)
  if not it or not it.exists then status = "Файл не найден - показывать нечего."; return end
  if reaper.CF_LocateInExplorer then
    reaper.CF_LocateInExplorer(it.path)
    status = "Показан в папке: " .. (it.path:match("([^\\/]+)$") or it.path)
    return
  end
  if it.path:find('"', 1, true) then status = "В пути есть кавычка - не могу открыть папку."; return end
  local os_name = reaper.GetOS() or ""
  local cmd
  if os_name:find("^Win") then
    cmd = 'explorer.exe /select,"' .. (it.path:gsub("/", "\\")) .. '"'
  elseif os_name:find("^OSX") or os_name:find("^macOS") then
    cmd = '/usr/bin/open -R "' .. it.path .. '"'
  else
    cmd = 'xdg-open "' .. (it.path:match("^(.*)/[^/]*$") or ".") .. '"'
  end
  reaper.ExecProcess(cmd, -1) -- -1: не ждать завершения
  status = "Показан в папке: " .. (it.path:match("([^\\/]+)$") or it.path)
end

----------------------------------------------------------------------
-- Сведения о проекте из .rpp (читаются лениво, только для проекта под курсором)
----------------------------------------------------------------------
local FX_TAGS = { VST = true, AU = true, JS = true, CLAP = true, DX = true, LV2 = true }

-- Имя плагина из строки "<VST "VST3: Pro-Q 3 (FabFilter)" ..." без префикса и вендора
local function fx_name(rest)
  local name = rest:match('^"([^"]*)"') or rest:match("^(%S+)") or ""
  name = name:gsub("^%w+:%s*", ""):gsub("%s*%b()$", "")
  return name
end

local function parse_rpp(path)
  local f = io.open(path, "rb")
  if not f then return { err = "Не удалось прочитать файл проекта." } end
  local size = f:seek("end")
  if size > INFO_MAX_BYTES then
    f:close()
    return { err = "Файл слишком большой для быстрого просмотра." }
  end
  f:seek("set", 0)
  local data = f:read("*a")
  f:close()

  local info = { tracks = 0, fx = 0, fx_names = {}, names = {} }
  local cur_track, run_level = nil, 0 -- текущая дорожка и уровень папки (ISBUS)
  local seen = {}
  local depth, item_depth = 0, nil
  local ipos, ilen, len_end = nil, nil, 0
  for line in data:gmatch("[^\r\n]+") do
    local t = line:match("^%s*(.-)%s*$")
    local c = t:sub(1, 1)
    if c == "<" then
      local tag = t:match("^<(%S+)")
      if depth == 0 then
        info.ver = t:match('"([%d%.]+)')
      elseif tag == "TRACK" and depth == 1 then
        info.tracks = info.tracks + 1
        cur_track = { name = "", level = run_level, fd = 0 }
        info.names[#info.names + 1] = cur_track
      elseif tag == "ITEM" then
        item_depth, ipos, ilen = depth, nil, nil
      elseif FX_TAGS[tag] then
        info.fx = info.fx + 1
        local name = fx_name(t:sub(#tag + 3))
        if name ~= "" and not seen[name] then
          seen[name] = true
          info.fx_names[#info.fx_names + 1] = name
        end
      end
      depth = depth + 1
    elseif c == ">" then
      depth = depth - 1
      if cur_track and depth == 1 then -- дорожка закончилась: уровень следующих меняет её ISBUS
        run_level = math.max(0, run_level + cur_track.fd)
        cur_track = nil
      end
      if item_depth and depth == item_depth then
        if ipos and ilen and ipos + ilen > len_end then len_end = ipos + ilen end
        item_depth = nil
      end
    else
      if depth == 1 then
        if not info.tempo then
          local bpm, num, den = t:match("^TEMPO%s+([%d%.]+)%s+(%d+)%s+(%d+)")
          if bpm then info.tempo = tonumber(bpm); info.sig = num .. "/" .. den end
        end
        if not info.sr then
          local sr = t:match("^SAMPLERATE%s+(%d+)")
          if sr then info.sr = tonumber(sr) end
        end
      elseif cur_track and depth == 2 then
        local nm = t:match('^NAME%s+"(.-)"') or t:match("^NAME%s+(%S.*)$")
        if nm then cur_track.name = nm end
        local fd = t:match("^ISBUS%s+%-?%d+%s+(%-?%d+)")
        if fd then cur_track.fd = tonumber(fd) end
      end
      if item_depth and depth == item_depth + 1 then
        local v = t:match("^POSITION%s+(%S+)")
        if v then ipos = tonumber(v) end
        v = t:match("^LENGTH%s+(%S+)")
        if v then ilen = tonumber(v) end
      end
    end
  end
  if len_end > 0 then info.len = len_end end
  return info
end

local function fmt_len(sec)
  local s = math.floor(sec + 0.5)
  if s >= 3600 then return string.format("%d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60) end
  return string.format("%d:%02d", s // 60, s % 60)
end

local function info_text(inf)
  local parts = {}
  if inf.ver then parts[#parts + 1] = "REAPER " .. inf.ver end
  if inf.tempo then parts[#parts + 1] = string.format("темп %g", inf.tempo) .. (inf.sig and (" " .. inf.sig) or "") end
  if inf.sr then parts[#parts + 1] = string.format("%d Гц", inf.sr) end
  parts[#parts + 1] = string.format("треков %d", inf.tracks)
  if inf.len then parts[#parts + 1] = "длина ≈" .. fmt_len(inf.len) end
  local line = table.concat(parts, " · ")
  if inf.fx > 0 then
    line = line .. string.format(" · плагинов %d: %s", inf.fx, table.concat(inf.fx_names, ", "))
  else
    line = line .. " · плагинов нет"
  end
  return line
end

local info_cache, info_wait = {}, nil

-- nil - сведения ещё не прочитаны: на первом кадре рисуется «Читаю...», разбор
-- файла делается на следующем (при быстрой прокрутке курсора файлы не читаются)
local function get_info(it)
  local key = it.path .. "|" .. tostring(it.size) .. "|" .. tostring(it.mtime)
  local inf = info_cache[key]
  if inf then return inf end
  if info_wait ~= key then info_wait = key; return nil end
  inf = parse_rpp(it.path)
  info_cache[key] = inf
  info_wait = nil
  return inf
end

----------------------------------------------------------------------
-- Колонки списка: имя | путь | дата | размер
----------------------------------------------------------------------
-- Хранятся ширины имени, даты и размера; путь занимает остаток строки. Так
-- три разделителя двигают границы между соседними колонками, а общая ширина
-- всегда равна ширине окна (без горизонтальной прокрутки).
local col_w = { name = COL_DEF.name, date = COL_DEF.date, size = COL_DEF.size }
for k in pairs(COL_DEF) do
  local v = tonumber(reaper.GetExtState(EXT_SECTION, "col_" .. k))
  if v and v >= COL_MIN[k] and v <= 2000 then col_w[k] = v end
end

local function save_cols()
  for k, v in pairs(col_w) do
    reaper.SetExtState(EXT_SECTION, "col_" .. k, tostring(math.floor(v + 0.5)), true)
  end
end

local function reset_cols()
  for k, v in pairs(COL_DEF) do col_w[k] = v end
  save_cols()
end

-- Какие колонки показаны (галочки в «Настройках»); хранятся в настройках REAPER. Дата без js_ReaScriptAPI не показывается в любом случае.
local COL_SHOW_KEYS = { "name", "path", "date", "size" }
local col_show = {}
for _, k in ipairs(COL_SHOW_KEYS) do col_show[k] = reaper.GetExtState(EXT_SECTION, "col_show_" .. k) ~= "0" end
if not col_show.name and not col_show.path then col_show.name = true end -- хотя бы одна из «Имя» и «Путь» должна остаться

-- Включить или выключить колонку. -> false, если выключить нельзя (последняя из «Имя» и «Путь»)
local function toggle_col(k)
  if col_show[k] and ((k == "name" and not col_show.path) or (k == "path" and not col_show.name)) then return false end
  col_show[k] = not col_show[k]
  reaper.SetExtState(EXT_SECTION, "col_show_" .. k, col_show[k] and "1" or "0", true)
  return true
end

-- Положение колонок для окна шириной w. Остаток строки забирает «Путь», а если он скрыт - «Имя». Без js_ReaScriptAPI даты нет - колонка
-- «Дата» скрыта. В узком окне имя/дата/размер временно ужимаются, колонка-остаток не меньше минимума.
local function layout(x0, w)
  local right = x0 + w - 26 -- справа остаётся место под полосу прокрутки
  local start = x0 + TEXT_X
  local avail = right - start
  local sh = {
    name = col_show.name or not col_show.path, path = col_show.path, date = col_show.date and has_dates, size = col_show.size,
  }
  local flex = sh.path and "path" or "name"
  local nw = (sh.name and flex ~= "name") and col_w.name or 0
  local dw = sh.date and col_w.date or 0
  local sw = sh.size and col_w.size or 0
  local fixed = nw + dw + sw
  if fixed > 0 and avail - fixed < COL_MIN.path then
    local k = math.max(0.3, (avail - COL_MIN.path) / fixed)
    nw, dw, sw = nw * k, dw * k, sw * k
    fixed = nw + dw + sw
  end
  local fw = avail - fixed
  local L = { right = right, flex = flex, flex_w = fw, show = sh }
  local x = start
  L.name_x, L.name_w = x, sh.name and ((flex == "name") and fw or nw) or 0
  x = x + L.name_w
  L.path_x, L.path_w = x, sh.path and fw or 0
  x = x + L.path_w
  L.date_x, L.date_w = x, dw
  x = x + dw
  L.size_x, L.size_w = x, sw
  L.flex_end = (flex == "path") and (L.path_x + L.path_w) or (L.name_x + L.name_w) -- правый край колонки-остатка (там плашка заметки)
  return L
end

-- Разделители заголовка между соседними показанными колонками: какой ширине что соответствует
local function dividers(L)
  local d = {}
  local order = {}
  for _, k in ipairs(COL_SHOW_KEYS) do if L.show[k] then order[#order + 1] = k end end
  for i = 2, #order do
    local left, right = order[i - 1], order[i]
    local kind
    if left == L.flex then kind = (right == "date") and "date_l" or "size_l" -- слева остаток: двигаем ширину правой колонки
    elseif right == L.flex then kind = "name"                                -- справа остаток: двигаем ширину имени
    else kind = "date_size" end                                              -- дата | размер: ширина переходит от одной к другой
    d[#d + 1] = { x = L[right .. "_x"], kind = kind }
  end
  return d
end

-- dx - сдвиг мыши с начала перетаскивания; start - ширины на тот момент
local function apply_drag(kind, start, dx)
  if kind == "name" then
    col_w.name = math.max(COL_MIN.name, math.min(start.name + dx, start.name + start.path - COL_MIN.path))
  elseif kind == "date_l" then
    col_w.date = math.max(COL_MIN.date, math.min(start.date - dx, start.date + start.path - COL_MIN.path))
  elseif kind == "date_size" then
    local d = math.max(COL_MIN.date - start.date, math.min(dx, start.size - COL_MIN.size))
    col_w.date, col_w.size = start.date + d, start.size - d
  else
    col_w.size = math.max(COL_MIN.size, math.min(start.size - dx, start.size + start.path - COL_MIN.path))
  end
end

local sb_drag = nil                -- пока тащат ползунок прокрутки: смещение мыши от его верха
local col_drag = nil               -- { kind, x0, start } пока разделитель тащат
local last_div_click_t = -1e9

----------------------------------------------------------------------
-- Ввод с клавиатуры
----------------------------------------------------------------------
-- Символ из кода gfx.getchar: ASCII и Latin-1 - как есть, остальной Unicode
-- REAPER отдаёт как 'u'<<24 + код (кириллица - 0x75000400...); служебные клавиши
-- (стрелки, F1..F12) - большие/особые коды и символами не считаются
local function key_to_codepoint(ch)
  if (ch >= 32 and ch <= 126) or (ch >= 160 and ch <= 255) then return ch end
  local base = 0x75000000
  if ch >= base + 256 and ch <= base + 0x10FFFF then return ch - base end
  if ch >= 0x400 and ch <= 0x4FF then return ch end -- кириллица без упаковки
  return nil
end

local NOTE_MAX = 200 -- байт

local function start_edit()
  if cursor then edit = { it = cursor, buf = cursor.note } end
end

local function commit_edit()
  if not edit then return end
  local it = edit.it
  local text = edit.buf:gsub("^%s+", ""):gsub("%s+$", "")
  edit = nil
  if text ~= it.note then
    set_note_of(it, text)
    status = text == "" and "Пометка удалена." or "Пометка сохранена."
  end
end

-- Набор текста: в поле пометки, если она редактируется, иначе в строку поиска
local function type_char(ch)
  local target = edit and edit.buf or query
  local new
  if ch == 8 then -- Backspace: убрать последний символ (в UTF-8 это до 4 байт)
    local off = utf8.offset(target, -1)
    new = off and target:sub(1, off - 1) or ""
  elseif ch == 22 and reaper.CF_GetClipboard then -- Ctrl+V (нужен SWS)
    local clip = (reaper.CF_GetClipboard("") or ""):gsub("%c+", " ")
    new = target .. clip
  else
    local cp = key_to_codepoint(ch)
    if cp then new = target .. utf8.char(cp) end
  end
  if not new then return end
  if edit then
    if #new <= NOTE_MAX then edit.buf = new end
  else
    set_query(new)
  end
end

local function move_cursor_to(idx)
  if #view == 0 then return end
  cursor = view[math.max(1, math.min(idx, #view))]
  follow_cursor = true
end

local function page_rows()
  -- видимая высота списка: окно минус шапка, три строки управления, заголовки колонок, панель проекта и подвал
  local list_h = gfx.h - (HEAD_H + 12 + 36 + 10 + 34 + 12 + COLS_H) - 8 - FOOT_H
  return math.max(1, math.floor(list_h / ROW_H))
end

-- Одно нажатие клавиши. Возвращает "close", если окно нужно закрыть.
local function handle_key(ch)
  if show_settings then -- в окне «Папки» ввода нет: Esc возвращает к списку
    if ch == 27 then show_settings = false end
    return
  end
  if edit then
    if ch == 13 then commit_edit()
    elseif ch == 27 then edit = nil
    else type_char(ch) end
    return
  end
  local idx = index_of(cursor) or 1
  if ch == 27 and open_queue then
    stop_open_queue("Остановлено")
  elseif ch == 27 then
    if query ~= "" then set_query("") else return "close" end
  elseif ch == 13 then open_project(cursor)
  elseif ch == KEY.up then move_cursor_to(idx - 1)
  elseif ch == KEY.down then move_cursor_to(idx + 1)
  elseif ch == KEY.pgup then move_cursor_to(idx - page_rows())
  elseif ch == KEY.pgdn then move_cursor_to(idx + page_rows())
  elseif ch == KEY.home then move_cursor_to(1)
  elseif ch == KEY["end"] then move_cursor_to(#view)
  elseif ch == 9 or ch == KEY.ins then -- Tab / Insert: отметить и перейти ниже
    if cursor then
      cursor.checked = not cursor.checked
      anchor = cursor
      move_cursor_to(idx + 1)
    end
  elseif ch == KEY.f2 then start_edit()
  else type_char(ch) end
end

-- Клик по строке: курсор, галочка, Shift+клик - диапазон от прошлой отметки.
-- Возвращает true при двойном клике (проект нужно открыть).
local function row_click(it, shift, now)
  local dbl = not shift and last_click_it == it and (now - last_click_t) < DOUBLE_CLICK
  last_click_it, last_click_t = it, now
  cursor = it
  if shift and anchor and anchor ~= it then
    local a, b = index_of(anchor), index_of(it)
    if a and b then
      if a > b then a, b = b, a end
      for i = a, b do view[i].checked = true end
    end
  else
    it.checked = not it.checked
    anchor = it
  end
  if dbl then last_click_it = nil end
  return dbl
end

----------------------------------------------------------------------
-- Отрисовка: тёмная тема; шапка (название, поиск, быстрые кнопки), боковая панель (источники и фильтры),
-- список проектов, панель выбранного проекта и подвал с действиями. Всё на стандартных средствах gfx REAPER.
----------------------------------------------------------------------
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

-- Кэш обрезанных строк: результат зависит только от строки, ширины и размера шрифта (высота текста gfx.texth)
local clip_cache, clip_cache_n = {}, 0
local function clip_remember(key, value)
  if clip_cache_n >= 4000 then clip_cache, clip_cache_n = {}, 0 end
  clip_cache[key] = value
  clip_cache_n = clip_cache_n + 1
  return value
end

-- Обрезка слева ("…хвост пути") - имя файла в конце пути самое важное
local function clip_tail(str, max_w)
  if gfx.measurestr(str) <= max_w then return str end
  local key = "t|" .. tostring(gfx.texth) .. "|" .. math.floor(max_w) .. "|" .. str
  local hit = clip_cache[key]
  if hit then return hit end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, 2)
    if not ok or not off then off = 2 end
    s = s:sub(off)
    if gfx.measurestr("…" .. s) <= max_w then return clip_remember(key, "…" .. s) end
  end
  return clip_remember(key, "…")
end

-- Обрезка справа ("начало…")
local function clip_head(str, max_w)
  if gfx.measurestr(str) <= max_w then return str end
  local key = "h|" .. tostring(gfx.texth) .. "|" .. math.floor(max_w) .. "|" .. str
  local hit = clip_cache[key]
  if hit then return hit end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, -1)
    if not ok or not off then off = #s end
    s = s:sub(1, off - 1)
    if gfx.measurestr(s .. "…") <= max_w then return clip_remember(key, s .. "…") end
  end
  return clip_remember(key, "…")
end

-- Скруглённый прямоугольник: заливка и рамка
local function rrect(x, y, w, h, r, c, a)
  set_color(c, a)
  r = math.max(0, math.min(r, math.floor(w / 2), math.floor(h / 2)))
  if r == 0 then gfx.rect(x, y, w, h, 1); return end
  gfx.rect(x + r, y, w - 2 * r, h, 1)
  gfx.rect(x, y + r, r, h - 2 * r, 1)
  gfx.rect(x + w - r, y + r, r, h - 2 * r, 1)
  gfx.circle(x + r, y + r, r, 1, 1)
  gfx.circle(x + w - r - 1, y + r, r, 1, 1)
  gfx.circle(x + r, y + h - r - 1, r, 1, 1)
  gfx.circle(x + w - r - 1, y + h - r - 1, r, 1, 1)
end

local function rframe(x, y, w, h, r, c, a)
  set_color(c, a)
  gfx.roundrect(x, y, w - 1, h - 1, r, 1)
end

-- Значки из линий и фигур gfx (шрифтам доверять нельзя): (x, y) - центр, s - размер
local function icon(kind, x, y, s, c)
  set_color(c)
  local h = s / 2
  if kind == "folder" then
    gfx.rect(x - h, y - h * 0.5, s, h * 1.4, 0)
    gfx.rect(x - h, y - h * 0.8, s * 0.42, h * 0.3, 1)
  elseif kind == "clock" then
    gfx.circle(x, y, h, 0, 1)
    gfx.line(x, y, x, y - h * 0.62)
    gfx.line(x, y, x + h * 0.45, y + h * 0.2)
  elseif kind == "gear" then
    gfx.circle(x, y, h * 0.5, 0, 1)
    for k = 0, 7 do
      local a = k * math.pi / 4
      gfx.line(x + math.cos(a) * h * 0.72, y + math.sin(a) * h * 0.72, x + math.cos(a) * h, y + math.sin(a) * h)
    end
  elseif kind == "search" then
    gfx.circle(x - h * 0.15, y - h * 0.15, h * 0.62, 0, 1)
    gfx.line(x + h * 0.3, y + h * 0.3, x + h * 0.9, y + h * 0.9)
  elseif kind == "x" then
    gfx.line(x - h * 0.55, y - h * 0.55, x + h * 0.55, y + h * 0.55)
    gfx.line(x - h * 0.55, y + h * 0.55, x + h * 0.55, y - h * 0.55)
  elseif kind == "check" then
    gfx.line(x - h * 0.6, y, x - h * 0.15, y + h * 0.5)
    gfx.line(x - h * 0.6, y + 1, x - h * 0.15, y + h * 0.5 + 1)
    gfx.line(x - h * 0.15, y + h * 0.5, x + h * 0.65, y - h * 0.5)
    gfx.line(x - h * 0.15, y + h * 0.5 + 1, x + h * 0.65, y - h * 0.5 + 1)
  elseif kind == "play" then
    gfx.triangle(x - h * 0.45, y - h * 0.65, x - h * 0.45, y + h * 0.65, x + h * 0.7, y)
  elseif kind == "trash" then
    gfx.rect(x - h * 0.5, y - h * 0.3, h, h * 1.15, 0)
    gfx.line(x - h * 0.75, y - h * 0.4, x + h * 0.75, y - h * 0.4)
    gfx.rect(x - h * 0.22, y - h * 0.72, h * 0.44, h * 0.32, 0)
  elseif kind == "undo" then
    gfx.circle(x, y, h * 0.7, 0, 1)
    gfx.line(x - h * 0.7, y - h * 0.1, x - h * 0.3, y - h * 0.7)
    gfx.line(x - h * 0.7, y - h * 0.1, x - h * 0.05, y - h * 0.2)
  elseif kind == "doc" then
    gfx.rect(x - h * 0.65, y - h, h * 1.3, s, 0)
    gfx.line(x - h * 0.35, y - h * 0.3, x + h * 0.35, y - h * 0.3)
    gfx.line(x - h * 0.35, y + h * 0.1, x + h * 0.35, y + h * 0.1)
    gfx.line(x - h * 0.35, y + h * 0.5, x + h * 0.1, y + h * 0.5)
  elseif kind == "filter" then
    gfx.line(x - h, y - h * 0.6, x + h, y - h * 0.6)
    gfx.line(x - h * 0.65, y, x + h * 0.65, y)
    gfx.line(x - h * 0.3, y + h * 0.6, x + h * 0.3, y + h * 0.6)
  elseif kind == "warn" then
    gfx.triangle(x, y - h, x - h, y + h * 0.8, x + h, y + h * 0.8)
  elseif kind == "star" or kind == "star_o" then -- звезда: заливка треугольниками от центра или контур линиями
    local pts = {}
    for k = 0, 9 do
      local a = -math.pi / 2 + k * math.pi / 5
      local r = (k % 2 == 0) and h or h * 0.44
      pts[#pts + 1] = { x + math.cos(a) * r, y + 0.06 * s + math.sin(a) * r }
    end
    for k = 1, 10 do
      local a, b = pts[k], pts[k % 10 + 1]
      if kind == "star" then gfx.triangle(x, y + 0.06 * s, a[1], a[2], b[1], b[2]) else gfx.line(a[1], a[2], b[1], b[2]) end
    end
  elseif kind == "tri_down" then
    gfx.triangle(x - h * 0.5, y - h * 0.3, x + h * 0.5, y - h * 0.3, x, y + h * 0.4)
  elseif kind == "tri_up" then
    gfx.triangle(x - h * 0.5, y + h * 0.3, x + h * 0.5, y + h * 0.3, x, y - h * 0.4)
  elseif kind == "chev" then -- шеврон вниз
    gfx.line(x - h * 0.5, y - h * 0.2, x, y + h * 0.3)
    gfx.line(x, y + h * 0.3, x + h * 0.5, y - h * 0.2)
  elseif kind == "sort" then -- ⇕: стрелки вверх и вниз
    gfx.line(x - h * 0.35, y - h * 0.7, x - h * 0.35, y + h * 0.7)
    gfx.line(x + h * 0.35, y - h * 0.7, x + h * 0.35, y + h * 0.7)
    gfx.line(x - h * 0.35, y - h * 0.7, x - h * 0.7, y - h * 0.2)
    gfx.line(x - h * 0.35, y - h * 0.7, x, y - h * 0.2)
    gfx.line(x + h * 0.35, y + h * 0.7, x, y + h * 0.2)
    gfx.line(x + h * 0.35, y + h * 0.7, x + h * 0.7, y + h * 0.2)
  end
end

-- Кнопка со скруглением; ic - значок слева от подписи. Возвращает true на клик (при enabled)
local function draw_button(x, y, w, h, label, enabled, click, color, fsize, ic)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = (not enabled) and col.btn_off or (hov and col.btn_hover or (color or col.btn))
  if enabled and color == col.accent and hov then c = col.accent_hover end
  rrect(x, y, w, h, 7, c)
  rframe(x, y, w, h, 7, (enabled and color) and c or col.border)
  local size = fsize or F_BTN
  gfx.setfont(1, "Arial", size)
  local avail = w - 14 - (ic and 26 or 0)
  while size > 12 and gfx.measurestr(label) > avail do
    size = size - 1
    gfx.setfont(1, "Arial", size)
  end
  local tw = gfx.measurestr(label)
  local total = tw + (ic and 26 or 0)
  local tx = x + (w - total) / 2
  local fg = enabled and col.text or col.dim
  if ic then icon(ic, tx + 9, y + h / 2, 16, fg); tx = tx + 26 end
  draw_text(label, tx, y + (h - size) / 2 - 1, fg)
  return hov and click
end

local function draw_checkbox(x, y, checked)
  rrect(x, y, CB, CB, 5, checked and col.accent or col.bg)
  rframe(x, y, CB, CB, 5, checked and col.accent or col.border)
  if checked then icon("check", x + CB / 2, y + CB / 2, 14, col.text) end
end

-- Переключатель (как в макете: плашка с кружком)
local function draw_switch(x, y, on)
  rrect(x, y, 38, 20, 10, on and col.accent or col.btn)
  set_color(col.text); gfx.circle(x + (on and 28 or 10), y + 10, 7, 1, 1)
end

-- Выпадающее меню в точке (x, y): current - номер отмеченного пункта; -> номер выбранного или nil
local function popup(labels, current, x, y)
  local parts = {}
  for i, lab in ipairs(labels) do parts[i] = (i == current and "!" or "") .. lab end
  gfx.x, gfx.y = x, y
  local r = gfx.showmenu(table.concat(parts, "|"))
  if r and r > 0 then return r end
  return nil
end

----------------------------------------------------------------------
-- Геометрия: все прямоугольники окна в одном месте (рисование, клики и тесты берут числа отсюда)
----------------------------------------------------------------------
local function geometry(w, h)
  local g = { w = w, h = h, pad = 14 }
  g.side_w = SIDE_W
  g.head_h = HEAD_H
  g.rp_w = (w >= 1250) and 340 or 300 -- правая панель проекта
  g.rp_x = w - g.rp_w
  g.main_x = SIDE_W + g.pad
  g.main_w = g.rp_x - g.pad - g.main_x
  g.foot_y = h - FOOT_H
  -- шапка: три кнопки справа и поле поиска между названием и ними
  g.hb_w = 86
  g.hb_x0 = w - 14 - 3 * g.hb_w
  g.search_x, g.search_y, g.search_h = SIDE_W + g.pad, 24, 44
  g.search_w = g.hb_x0 - 22 - g.search_x
  -- основная область: сортировка, фильтры-кнопки, заголовки колонок, список
  g.sort_y, g.sort_h = HEAD_H + 12, 36
  g.chip_y, g.chip_h = g.sort_y + g.sort_h + 10, 34
  g.cols_y = g.chip_y + g.chip_h + 12
  g.list_y = g.cols_y + COLS_H
  g.list_h = math.max(60, g.foot_y - g.list_y - 8)
  -- правая панель сверху вниз: название, путь, сведения, дорожки, плагины, заметка, кнопки
  g.rp_pad = 18
  g.rp_top = HEAD_H + 18
  g.rp_row_h = 22                                                -- строка списка дорожек
  g.rp_btn_h, g.rp_btn_gap, g.rp_btn1_h = 32, 8, 38
  g.rp_btn3_y = g.foot_y - 10 - g.rp_btn_h                       -- «Заметка», «Папка»
  g.rp_btn2_y = g.rp_btn3_y - g.rp_btn_gap - g.rp_btn_h          -- «Новая вкладка», «В избранное»
  g.rp_btn1_y = g.rp_btn2_y - g.rp_btn_gap - g.rp_btn1_h         -- «Открыть»
  g.note_h = 30
  g.note_x, g.note_w = g.rp_x + g.rp_pad, g.rp_w - 2 * g.rp_pad  -- поле заметки
  g.note_y = g.rp_btn1_y - 12 - g.note_h
  g.rp_note_label_y = g.note_y - 22
  g.rp_tr_y0 = g.rp_top + 142                                    -- список дорожек
  local pl_h = 66                                                -- плагины; в низком окне их не показываем, чтобы осталось место для дорожек
  local tr_y1 = g.rp_note_label_y - 8 - pl_h - 8
  if tr_y1 - g.rp_tr_y0 < 5 * g.rp_row_h then pl_h = 0; tr_y1 = g.rp_note_label_y - 8 end
  g.rp_pl_h = pl_h
  g.rp_pl_y = g.rp_note_label_y - 8 - pl_h
  g.rp_tr_y1 = tr_y1
  -- боковая панель
  g.si_y0, g.si_h, g.si_step = HEAD_H + 14, 38, 40       -- источники: Все проекты, Избранное, Недавние, Папки
  g.fil_title_y = g.si_y0 + 4 * g.si_step + 14
  g.fil_toggle_y = g.fil_title_y + 30
  g.fil_dd_y0 = g.fil_toggle_y + 42
  g.fil_dd_step, g.fil_dd_h = 40, 32
  -- подвал
  g.by, g.bh, g.gap = g.foot_y + 54, 48, 10
  g.col_opt_y, g.col_opt_step = g.foot_y - 128, 150 -- окно «Папки»: ряд галочек «Колонки списка»; шаг по x
  g.tab_w = g.rp_w - 2 * g.rp_pad
  return g
end

if type(SSM_PM_GEOMETRY_HOOK) == "function" then SSM_PM_GEOMETRY_HOOK(geometry) end -- только для тестов

-- Номер строки: центр по вертикали
local function row_top(G, i, scroll_) return G.list_y + (i - 1) * ROW_H - scroll_ end

local SIDE_ITEMS = {
  { id = "library", label = "Все проекты", icon = "folder" },
  { id = "favs", label = "Избранное", icon = "star_o" },
  { id = "recent", label = "Недавние", icon = "clock" },
  { id = "folders", label = "Папки", icon = "folder" },
}

local function draw()
  local w, h = gfx.w, gfx.h
  local G = geometry(w, h)
  local cap = gfx.mouse_cap
  local down = (cap & 1) == 1
  local click = down and (last_cap & 1) == 0
  local shift = (cap & 8) ~= 0
  last_cap = cap
  local lclick = click and not show_settings -- клики по списку и панели проекта не проходят под окно «Папки»
  local main_x, main_w = G.main_x, G.main_w
  local list_y, list_h = G.list_y, G.list_h
  local foot_y = G.foot_y
  local gap = G.gap
  local side_click_y, chip_x -- где открывать выпадающие меню

  set_color(col.bg); gfx.rect(0, 0, w, h, 1)

  -- клик мимо поля пометки завершает её редактирование
  if edit and click and not mouse_in(G.note_x, G.note_y, G.note_w, G.note_h) then commit_edit() end

  -- ширина колонок: перетаскивание разделителя, двойной клик - сброс
  if col_drag then
    if down then
      apply_drag(col_drag.kind, col_drag.start, gfx.mouse_x - col_drag.x0)
    else
      col_drag = nil
      save_cols()
    end
  end
  local L = layout(main_x, main_w)
  local divs = dividers(L)
  if lclick and not col_drag and gfx.mouse_y >= G.cols_y and gfx.mouse_y < list_y then
    for _, dv in ipairs(divs) do
      if math.abs(gfx.mouse_x - dv.x) <= 4 then
        local now = reaper.time_precise()
        if now - last_div_click_t < DOUBLE_CLICK then
          reset_cols()
          last_div_click_t = -1e9
        else
          last_div_click_t = now
          if L.show.name and L.flex ~= "name" then col_w.name = L.name_w end
          if L.show.date then col_w.date = L.date_w end
          if L.show.size then col_w.size = L.size_w end
          col_drag = { kind = dv.kind, x0 = gfx.mouse_x,
            start = { name = col_w.name, date = col_w.date, size = col_w.size, path = L.flex_w } }
        end
        break
      end
    end
  end

  local total_h = #view * ROW_H
  local max_scroll = math.max(0, total_h - list_h)

  if gfx.mouse_wheel ~= 0 then
    if gfx.mouse_x >= G.rp_x and not show_settings then -- над правой панелью колесо листает список дорожек проекта
      rp_scroll = rp_scroll - (gfx.mouse_wheel / 120) * G.rp_row_h * 3
    else
      scroll = scroll - (gfx.mouse_wheel / 120) * ROW_H * 3
    end
    gfx.mouse_wheel = 0
  end
  if follow_cursor then -- курсор, сдвинутый с клавиатуры, не должен уходить за край списка
    follow_cursor = false
    local idx = index_of(cursor)
    if idx then
      local top = (idx - 1) * ROW_H
      if top < scroll then scroll = top
      elseif top + ROW_H > scroll + list_h then scroll = top + ROW_H - list_h end
    end
  end
  scroll = math.max(0, math.min(scroll, max_scroll))

  -- Полоса прокрутки: ползунок тащится мышью, клик по дорожке переносит ползунок
  -- в это место (и его можно сразу тащить дальше). Зона захвата - правые 14 пикселей списка.
  local sb_x = main_x + main_w - 14
  local thumb_h, thumb_y = 0, list_y
  if max_scroll > 0 then
    thumb_h = math.max(24, list_h * list_h / total_h)
    local travel = list_h - thumb_h
    thumb_y = list_y + travel * (scroll / max_scroll)
    if sb_drag then
      if down then
        thumb_y = math.max(list_y, math.min(gfx.mouse_y - sb_drag, list_y + travel))
        scroll = (thumb_y - list_y) / travel * max_scroll
      else
        sb_drag = nil
      end
    elseif lclick and gfx.mouse_x >= sb_x and gfx.mouse_x < main_x + main_w and gfx.mouse_y >= list_y and gfx.mouse_y < list_y + list_h then
      if gfx.mouse_y < thumb_y or gfx.mouse_y > thumb_y + thumb_h then
        thumb_y = math.max(list_y, math.min(gfx.mouse_y - thumb_h / 2, list_y + travel))
        scroll = (thumb_y - list_y) / travel * max_scroll
      end
      sb_drag = gfx.mouse_y - thumb_y
    end
  else
    sb_drag = nil
  end

  -- строки списка (шапка и панели потом перекрывают выступающие части)
  gfx.setfont(1, "Arial", F_ROW)
  local open_now, fav_now
  local cbx = main_x + 12
  local star_x = main_x + STAR_X
  for i, it in ipairs(view) do
    local ry = row_top(G, i, scroll)
    if ry + ROW_H > list_y and ry < list_y + list_h then
      local selected = (it == cursor)
      if selected then
        rrect(main_x, ry + 1, main_w - 16, ROW_H - 2, 6, col.sel)
      elseif i % 2 == 0 then
        set_color(col.row_alt); gfx.rect(main_x, ry, main_w - 16, ROW_H, 1)
      end

      local in_list = gfx.mouse_y >= list_y and gfx.mouse_y < list_y + list_h
      if in_list and mouse_in(main_x, ry, main_w - 16, ROW_H) then
        if not selected then rrect(main_x, ry + 1, main_w - 16, ROW_H - 2, 6, col.panel) end
        if lclick then
          if mouse_in(star_x - 4, ry, STAR_W + 8, ROW_H) then
            fav_now = it
          elseif row_click(it, shift, reaper.time_precise()) then
            open_now = it
          end
        end
      end
      if selected then rframe(main_x, ry + 1, main_w - 16, ROW_H - 2, 6, col.accent) end

      draw_checkbox(cbx, ry + (ROW_H - CB) / 2, it.checked)
      gfx.setfont(1, "Arial", F_ROW)
      icon(it.fav and "star" or "star_o", star_x + STAR_W / 2, ry + ROW_H / 2, 16, it.fav and col.star or col.dim)

      local small_y = ry + (ROW_H - F_SMALL) / 2
      local text_y = ry + (ROW_H - F_ROW) / 2 - 1
      gfx.setfont(1, "Arial", F_ROW)

      -- пометка - плашка у правого края колонки-остатка («Путь», а если он скрыт - «Имя»)
      local note_tag_w = 0
      if it.note ~= "" then
        gfx.setfont(1, "Arial", F_SMALL)
        local shown = clip_head(it.note, math.min(200, L.flex_w * 0.4))
        local tw = gfx.measurestr(shown)
        note_tag_w = tw + 24
        local tx = L.flex_end - note_tag_w
        rrect(tx, ry + (ROW_H - 22) / 2, tw + 16, 22, 5, col.tag_bg)
        draw_text(shown, tx + 8, small_y, col.tag)
        gfx.setfont(1, "Arial", F_ROW)
      end
      if L.show.name then
        local tagw = (L.flex == "name") and note_tag_w or 0
        draw_text(clip_head(it.title, L.name_w - 12 - tagw), L.name_x + 4, text_y, it.exists and col.text or col.dim)
      end
      if L.show.path then
        draw_text(clip_tail(it.path, L.path_w - 12 - note_tag_w), L.path_x + 4, text_y, col.dim)
      end

      gfx.setfont(1, "Arial", F_SMALL)
      if it.exists then
        if L.show.date then draw_text(fmt_date(it.mtime), L.date_x + 4, small_y, col.dim) end
        if L.show.size then
          local sz = fmt_size(it.size)
          draw_text(sz, L.right - 2 - gfx.measurestr(sz), small_y, col.dim)
        end
      else
        local tag = "не найден"
        draw_text(tag, L.right - 2 - gfx.measurestr(tag), small_y, col.danger)
      end
    end
  end

  if #items == 0 then
    local msg
    if source == "recent" then msg = "Список Recent projects пуст."
    elseif source == "favs" then msg = "В избранном пока ничего нет: нажмите звезду у проекта."
    elseif #lib.dirs == 0 then msg = "Папки не заданы. Нажмите «Папки» и добавьте папку с проектами."
    elseif lib.scan then msg = "Идёт сканирование…"
    else msg = "Список пуст. Нажмите «Пересканировать»." end
    draw_text(msg, main_x + 16, list_y + 18, col.dim)
  elseif #view == 0 then
    draw_text("Ничего не найдено. Измените поиск или фильтры.", main_x + 16, list_y + 18, col.dim)
  end

  -- полоса прокрутки
  if max_scroll > 0 then
    local hot = sb_drag ~= nil or mouse_in(sb_x, thumb_y, 14, thumb_h)
    rrect(sb_x + 3, thumb_y, 8, thumb_h, 4, sb_drag and col.accent or (hot and col.dim or col.border))
  end

  -- верх и низ основной области перекрывают выступающие строки
  set_color(col.bg); gfx.rect(main_x - 4, HEAD_H, main_w + 8, list_y - HEAD_H, 1)
  gfx.rect(main_x - 4, list_y + list_h, main_w + 8, h - (list_y + list_h), 1)

  -- ===== боковая панель =====
  set_color(col.panel); gfx.rect(0, HEAD_H, G.side_w, h - HEAD_H, 1)
  set_color(col.border); gfx.rect(G.side_w - 1, HEAD_H, 1, h - HEAD_H, 1)
  local side_click
  do
    local n_lib = lib.loaded and #lib.items or lib.index_count()
    local n_fav = 0
    for _ in pairs(favs) do n_fav = n_fav + 1 end
    local counts = { library = n_lib, favs = n_fav, recent = #recent_items, folders = #lib.dirs }
    for i, si in ipairs(SIDE_ITEMS) do
      local y = G.si_y0 + (i - 1) * G.si_step
      local active = (si.id == "folders") and show_settings or (si.id == source and not show_settings)
      local hov = mouse_in(8, y, G.side_w - 16, G.si_h)
      if active then rrect(8, y, G.side_w - 16, G.si_h, 8, col.accent)
      elseif hov then rrect(8, y, G.side_w - 16, G.si_h, 8, col.btn_hover) end
      local fg = active and col.text or col.dim
      icon(si.icon, 30, y + G.si_h / 2, 18, fg)
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(si.label, 52, y + (G.si_h - F_ROW) / 2 - 1, active and col.text or col.text)
      local cnt = tostring(counts[si.id] or "")
      draw_text(cnt, G.side_w - 22 - gfx.measurestr(cnt), y + (G.si_h - F_ROW) / 2 - 1, fg)
      if hov and click then side_click = si.id end
    end

    -- фильтры
    set_color(col.border); gfx.rect(14, G.fil_title_y - 12, G.side_w - 28, 1, 1)
    icon("filter", 24, G.fil_title_y + 8, 16, col.text)
    gfx.setfont(2, "Arial", F_ROW, "b")
    draw_text("Фильтры", 44, G.fil_title_y, col.text)
    gfx.setfont(1, "Arial", F_SMALL + 1)
    draw_text("Только не найденные", 16, G.fil_toggle_y + 7, col.text)
    draw_switch(G.side_w - 14 - 38, G.fil_toggle_y + 4, f_missing)
    if click and mouse_in(8, G.fil_toggle_y, G.side_w - 16, 30) then side_click = "toggle_missing" end

    local dds = {
      { id = "age", label = "Возраст", value = AGE_STEPS[f_age][2], enabled = has_dates },
      { id = "size", label = "Размер", value = SIZE_STEPS[f_size][2], enabled = true },
      { id = "date", label = "Дата", value = DATE_STEPS[f_date][2], enabled = has_dates },
    }
    for i, dd in ipairs(dds) do
      local y = G.fil_dd_y0 + (i - 1) * G.fil_dd_step
      local hov = dd.enabled and mouse_in(8, y, G.side_w - 16, G.fil_dd_h)
      rrect(8, y, G.side_w - 16, G.fil_dd_h, 7, hov and col.btn_hover or col.btn_off)
      rframe(8, y, G.side_w - 16, G.fil_dd_h, 7, col.border)
      gfx.setfont(1, "Arial", F_SMALL)
      local active = (dd.id == "age" and f_age > 1) or (dd.id == "size" and f_size > 1) or (dd.id == "date" and f_date > 1)
      local label = dd.label .. " (" .. dd.value .. ")"
      if not dd.enabled then label = dd.label .. ": нужен js_ReaScriptAPI" end
      draw_text(clip_head(label, G.side_w - 60), 18, y + (G.fil_dd_h - F_SMALL) / 2 - 1, active and col.accent_text or (dd.enabled and col.text or col.dim))
      icon("chev", G.side_w - 26, y + G.fil_dd_h / 2, 12, col.dim)
      if hov and click then side_click = "dd_" .. dd.id; side_click_y = y + G.fil_dd_h end
    end
  end

  -- ===== шапка =====
  set_color(col.bg); gfx.rect(0, 0, w, HEAD_H, 1)
  set_color(col.border); gfx.rect(0, HEAD_H - 1, w, 1, 1)
  icon("folder", 36, 46, 38, col.accent)
  local n_shown = filters_active() and #view or #items
  gfx.setfont(2, "Arial", 26, "b")
  draw_text("Проекты", 70, 22, col.text)
  local tw_title = gfx.measurestr("Проекты")
  draw_text(tostring(n_shown), 70 + tw_title + 14, 22, col.accent_text)
  gfx.setfont(1, "Arial", F_SMALL)
  local sub
  if filters_active() then sub = string.format("(найдено %d из %d, не найдено: %d)", #view, #items, count_missing())
  else sub = string.format("(не найдено: %d)", count_missing()) end
  draw_text(sub, 70, 56, col.dim)
  if not has_js_stat then
    gfx.setfont(1, "Arial", 13)
    draw_text("Дата изменения: нужен js_ReaScriptAPI", 70, 74, col.dim)
  end

  -- строка поиска: ввод идёт сюда всегда (см. loop), справа кнопка очистки
  do
    local sx, sw, sy, sh = G.search_x, G.search_w, G.search_y, G.search_h
    rrect(sx, sy, sw, sh, 9, col.panel)
    rframe(sx, sy, sw, sh, 9, query ~= "" and col.accent or col.border)
    icon("search", sx + 24, sy + sh / 2, 18, col.dim)
    gfx.setfont(1, "Arial", F_ROW)
    local ty = sy + (sh - F_ROW) / 2 - 1
    local clear_w = sh
    local shown = ""
    if query == "" then
      draw_text("Поиск по имени, пути и заметкам…", sx + 48, ty, col.dim)
    else
      shown = clip_tail(query, sw - clear_w - 60)
      draw_text(shown, sx + 48, ty, col.text)
      local cx = sx + sw - clear_w
      local hov = mouse_in(cx, sy, clear_w, sh)
      icon("x", cx + clear_w / 2, sy + sh / 2, 18, hov and col.text or col.dim)
      if hov and click then set_query("") end
    end
    if not edit and math.floor(reaper.time_precise() * 2) % 2 == 0 then -- мигающий курсор
      set_color(col.text)
      gfx.rect(sx + 48 + gfx.measurestr(shown) + 1, sy + 10, 1, sh - 20, 1)
    end
  end

  -- быстрые кнопки справа: Избранное, Недавние, Настройки («Папки»)
  local head_click
  do
    local specs = {
      { id = "favs", label = "Избранное", ic = "star_o", active = source == "favs" and not show_settings },
      { id = "recent", label = "Недавние", ic = "clock", active = source == "recent" and not show_settings },
      { id = "folders", label = "Настройки", ic = "gear", active = show_settings },
    }
    for i, b in ipairs(specs) do
      local x = G.hb_x0 + (i - 1) * G.hb_w
      local hov = mouse_in(x, 12, G.hb_w, 66)
      if hov then rrect(x + 2, 12, G.hb_w - 4, 66, 8, col.btn_hover) end
      local fg = b.active and col.accent_text or col.text
      icon(b.ic, x + G.hb_w / 2, 36, 22, fg)
      gfx.setfont(1, "Arial", F_SMALL)
      draw_text(b.label, x + (G.hb_w - gfx.measurestr(b.label)) / 2, 56, fg)
      if i > 1 then set_color(col.border); gfx.rect(x, 22, 1, 46, 1) end
      if hov and click then head_click = b.id end
    end
  end

  -- ===== основная область: сортировка =====
  do
    local n, sgap = #SORT_BUTTONS, 8
    local bw2 = math.min(190, (main_w - sgap * (n - 1)) / n)
    local clicked_key
    for i, sk in ipairs(SORT_BUTTONS) do
      local active = (sk.key == sort_key)
      local enabled = not (sk.key == "date" and not has_dates)
      local label = sk.label
      if sk.key == "order" and source ~= "recent" then label = "Как найдено" end
      local x = main_x + (i - 1) * (bw2 + sgap)
      local hov = enabled and mouse_in(x, G.sort_y, bw2, G.sort_h)
      local c = (not enabled) and col.btn_off or (active and col.accent or (hov and col.btn_hover or col.btn))
      rrect(x, G.sort_y, bw2, G.sort_h, 8, c)
      rframe(x, G.sort_y, bw2, G.sort_h, 8, active and col.accent or col.border)
      local size = F_SORT
      gfx.setfont(1, "Arial", size)
      while size > 11 and gfx.measurestr(label) > bw2 - 40 do
        size = size - 1
        gfx.setfont(1, "Arial", size)
      end
      local fg = enabled and col.text or col.dim
      local tw = gfx.measurestr(label)
      local tx = x + (bw2 - tw - 22) / 2
      draw_text(label, tx, G.sort_y + (G.sort_h - size) / 2 - 1, fg)
      if active and (sk.key ~= "order" or sort_desc) then
        icon(sort_desc and "tri_down" or "tri_up", tx + tw + 14, G.sort_y + G.sort_h / 2, 14, fg)
      elseif sk.key == "order" then
        icon("chev", tx + tw + 14, G.sort_y + G.sort_h / 2, 12, fg)
      else
        icon("sort", tx + tw + 14, G.sort_y + G.sort_h / 2, 14, enabled and col.dim or col.border)
      end
      if hov and click then clicked_key = sk.key end
    end
    if clicked_key then set_sort(clicked_key) end
  end

  -- ===== основная область: фильтры-кнопки и массовая отметка =====
  local chip_click
  do
    local specs = {
      { id = "found", w = 126, label = "Найденные", ic = "folder", on = f_found },
      { id = "all", w = 104, label = "Все", ic = "folder", on = not f_found and not f_missing },
      { id = "missing", w = 210, label = "Только не найденные", ic = "warn", on = f_missing },
      { id = "age", w = 200, label = has_dates and ("Возраст: " .. AGE_STEPS[f_age][2]) or "Возраст: нужен js_ReaScriptAPI",
        enabled = has_dates, on = f_age > 1, dd = true },
    }
    local right = { { id = "all_check", w = 150, label = "Отметить все", ic = "check", enabled = #view > 0 },
                    { id = "none", w = 130, label = "Снять все", ic = "x" } }
    local sum, ngaps = 0, 0
    for _, b in ipairs(specs) do sum = sum + b.w; ngaps = ngaps + 1 end
    for _, b in ipairs(right) do sum = sum + b.w; ngaps = ngaps + 1 end
    local k = math.max(0.5, math.min(1, (main_w - ngaps * gap) / sum)) -- в узком окне кнопки ужимаются
    local x = main_x
    for _, b in ipairs(specs) do
      local bw = b.w * k
      if draw_button(x, G.chip_y, bw, G.chip_h, b.label, b.enabled ~= false, click, b.on and col.accent or nil, F_SMALL, b.ic) then
        chip_click = b.id; chip_x = x
      end
      if b.dd then icon("chev", x + bw - 16, G.chip_y + G.chip_h / 2, 12, col.dim) end
      x = x + bw + gap
    end
    x = main_x + main_w
    for i = #right, 1, -1 do
      local b = right[i]
      local bw = b.w * k
      x = x - bw
      if draw_button(x, G.chip_y, bw, G.chip_h, b.label, b.enabled ~= false, click, nil, F_SMALL, b.ic) then chip_click = b.id end
      x = x - gap
    end
  end

  -- ===== основная область: заголовки колонок =====
  do
    local all_checked = #view > 0
    for _, it in ipairs(view) do if not it.checked then all_checked = false; break end end
    set_color(col.panel); gfx.rect(main_x, G.cols_y, main_w, COLS_H, 1)
    set_color(col.border); gfx.rect(main_x, list_y - 1, main_w, 1, 1)
    draw_checkbox(cbx, G.cols_y + (COLS_H - CB) / 2, all_checked)
    if click and not show_settings and mouse_in(cbx - 2, G.cols_y, CB + 4, COLS_H) then
      if all_checked then
        for _, it in ipairs(items) do it.checked = false end
      else
        for _, it in ipairs(view) do it.checked = true end
      end
    end
    gfx.setfont(1, "Arial", F_SMALL)
    local hy = G.cols_y + (COLS_H - F_SMALL) / 2 - 1
    if L.show.name then
      draw_text("Имя", L.name_x + 4, hy, col.dim)
      if sort_key == "name" then
        icon(sort_desc and "tri_down" or "tri_up", L.name_x + 4 + gfx.measurestr("Имя") + 14, G.cols_y + COLS_H / 2, 14, col.accent_text)
      end
    end
    if L.show.path then draw_text("Путь", L.path_x + 4, hy, col.dim) end
    if L.show.date then draw_text("Дата", L.date_x + 4, hy, col.dim) end
    if L.show.size then draw_text("Размер", L.right - 2 - gfx.measurestr("Размер"), hy, col.dim) end
    for _, dv in ipairs(divs) do
      local hot = (col_drag and col_drag.kind == dv.kind) or (not col_drag and mouse_in(dv.x - 4, G.cols_y, 9, COLS_H))
      set_color(hot and col.accent or col.border)
      gfx.rect(dv.x - (hot and 1 or 0), G.cols_y + 6, hot and 3 or 1, COLS_H - 12, 1)
    end
  end

  -- ===== правая панель: сведения о проекте под курсором =====
  local act_fav, act_note, act_reveal, act_popen, act_ptab
  do
    local px, pw = G.rp_x + G.rp_pad, G.rp_w - 2 * G.rp_pad
    set_color(col.panel); gfx.rect(G.rp_x, HEAD_H, G.rp_w, foot_y - HEAD_H, 1)
    set_color(col.border); gfx.rect(G.rp_x, HEAD_H, 1, foot_y - HEAD_H, 1)
    local it = cursor
    if it ~= rp_cursor then rp_cursor, rp_scroll = it, 0 end
    if not it then
      gfx.setfont(1, "Arial", F_SMALL)
      draw_text("Проект не выбран.", px, G.rp_top, col.dim)
    else
      gfx.setfont(2, "Arial", 20, "b")
      draw_text(clip_head(it.title, pw), px, G.rp_top, it.exists and col.text or col.danger)
      gfx.setfont(1, "Arial", 14)
      draw_text(clip_tail(it.path, pw), px, G.rp_top + 30, col.dim)
      set_color(col.border); gfx.rect(px, G.rp_top + 56, pw, 1, 1)

      local y = G.rp_top + 70
      local inf = it.exists and get_info(it) or nil
      gfx.setfont(1, "Arial", F_SMALL + 1)
      if not it.exists then
        draw_text("Файл не найден.", px, y, col.danger)
      elseif not inf then
        draw_text("Читаю проект…", px, y, col.dim)
      elseif inf.err then
        draw_text(clip_head(inf.err, pw), px, y, col.dim)
      else
        -- темп, размер, частота, длина
        local parts = {}
        if inf.tempo then parts[#parts + 1] = string.format("%g BPM", inf.tempo) .. (inf.sig and (" · " .. inf.sig) or "") end
        if inf.sr then parts[#parts + 1] = string.format("%g кГц", inf.sr / 1000) end
        if inf.len then parts[#parts + 1] = fmt_len(inf.len) end
        draw_text(clip_head(table.concat(parts, " · "), pw), px, y, col.text)
        gfx.setfont(1, "Arial", 14)
        local sub = {}
        if inf.ver then sub[#sub + 1] = "REAPER " .. inf.ver end
        if it.size then sub[#sub + 1] = fmt_size(it.size) end
        if it.mtime then sub[#sub + 1] = fmt_date(it.mtime) end
        draw_text(clip_head(table.concat(sub, " · "), pw), px, y + 26, col.dim)

        -- дорожки: номер, название (папки сдвигают вправо); колесо мыши над панелью листает
        draw_text(string.format("ТРЕКОВ %d", inf.tracks), px, y + 56, col.dim)
        local names = inf.names or {}
        local rows = math.max(0, math.floor((G.rp_tr_y1 - G.rp_tr_y0) / G.rp_row_h))
        local max_sc = math.max(0, (#names - rows) * G.rp_row_h)
        rp_scroll = math.max(0, math.min(rp_scroll, max_sc))
        -- ползунок: тащится мышью, клик по дорожке переносит его туда (и сразу можно тащить дальше)
        local track_h = G.rp_tr_y1 - G.rp_tr_y0
        local th = math.max(18, track_h * rows / math.max(1, #names))
        local travel = math.max(1, track_h - th)
        local thumb_y = G.rp_tr_y0 + travel * (max_sc > 0 and rp_scroll / max_sc or 0)
        if max_sc > 0 and rows > 0 then
          if rp_drag then
            if (gfx.mouse_cap & 1) == 1 then
              thumb_y = math.max(G.rp_tr_y0, math.min(gfx.mouse_y - rp_drag, G.rp_tr_y0 + travel))
              rp_scroll = (thumb_y - G.rp_tr_y0) / travel * max_sc
            else
              rp_drag = nil
            end
          elseif lclick and gfx.mouse_x >= px + pw - 14 and gfx.mouse_x < px + pw + 6 and gfx.mouse_y >= G.rp_tr_y0 and gfx.mouse_y < G.rp_tr_y1 then
            if gfx.mouse_y < thumb_y or gfx.mouse_y > thumb_y + th then
              thumb_y = math.max(G.rp_tr_y0, math.min(gfx.mouse_y - th / 2, G.rp_tr_y0 + travel))
              rp_scroll = (thumb_y - G.rp_tr_y0) / travel * max_sc
            end
            rp_drag = gfx.mouse_y - thumb_y
          end
        else
          rp_drag = nil
        end
        local first = math.floor(rp_scroll / G.rp_row_h + 0.5)
        for k = 1, rows do
          local idx = first + k
          local tr = names[idx]
          if not tr then break end
          local ry = G.rp_tr_y0 + (k - 1) * G.rp_row_h
          local num = tostring(idx)
          draw_text(num, px + 26 - gfx.measurestr(num), ry + 3, col.dim)
          local shown = tr.name ~= "" and tr.name or ("Дорожка " .. idx)
          local indent = math.min(tr.level, 6) * 10
          draw_text(clip_head(shown, pw - 44 - indent), px + 36 + indent, ry + 3, tr.name ~= "" and col.text or col.dim)
        end
        if #names > rows and rows > 0 then -- ползунок прокрутки
          local hot = rp_drag ~= nil or mouse_in(px + pw - 14, thumb_y, 20, th)
          rrect(px + pw - 6, thumb_y, 6, th, 3, rp_drag and col.accent or (hot and col.dim or col.border))
        end

        -- плагины: число и названия (до трёх строк)
        if G.rp_pl_h > 0 then
          draw_text(inf.fx > 0 and string.format("ПЛАГИНЫ %d", inf.fx) or "Плагинов нет", px, G.rp_pl_y, col.dim)
          if inf.fx > 0 then
            local lines, cur = {}, ""
            for _, nm in ipairs(inf.fx_names) do
              local cand = cur == "" and nm or (cur .. ", " .. nm)
              if cur ~= "" and gfx.measurestr(cand .. ",") > pw then
                lines[#lines + 1] = cur .. ","
                cur = nm
              else
                cur = cand
              end
            end
            if cur ~= "" then lines[#lines + 1] = cur end
            if #lines > 3 then lines = { lines[1], lines[2], lines[3] .. " …" } end
            for i, ln in ipairs(lines) do draw_text(clip_head(ln, pw), px, G.rp_pl_y + 18 + (i - 1) * 16, col.text) end
          end
        end
      end

      -- заметка: поле ввода (клик или F2 - редактировать)
      gfx.setfont(1, "Arial", 14)
      draw_text("ЗАМЕТКА", px, G.rp_note_label_y, col.dim)
      local note_x, note_y, note_w, note_h = G.note_x, G.note_y, G.note_w, G.note_h
      local editing = edit and edit.it == it
      rrect(note_x, note_y, note_w, note_h, 6, col.bg)
      rframe(note_x, note_y, note_w, note_h, 6, editing and col.accent or col.border)
      gfx.setfont(1, "Arial", F_SMALL)
      local ty = note_y + (note_h - F_SMALL) / 2 - 1
      if editing then
        local shown = clip_tail(edit.buf, note_w - 20)
        draw_text(shown, note_x + 10, ty, col.text)
        if math.floor(reaper.time_precise() * 2) % 2 == 0 then
          set_color(col.text)
          gfx.rect(note_x + 10 + gfx.measurestr(shown) + 1, note_y + 5, 1, note_h - 10, 1)
        end
      elseif it.note ~= "" then
        local shown = clip_head(it.note, note_w - 34)
        local tw = gfx.measurestr(shown)
        rrect(note_x + 6, note_y + 4, tw + 16, note_h - 8, 5, col.tag_bg)
        draw_text(shown, note_x + 14, ty, col.tag)
      else
        draw_text(clip_head("клик или F2 - добавить (Enter - сохранить)", note_w - 24), note_x + 10, ty, col.dim)
      end
      if lclick and not edit and mouse_in(note_x, note_y, note_w, note_h) then start_edit() end

      -- кнопки: «Открыть» (как задано галочкой), «Новая вкладка», «В избранное», «Заметка», «Папка»
      local half = (pw - G.rp_btn_gap) / 2
      act_popen = draw_button(px, G.rp_btn1_y, pw, G.rp_btn1_h, "Открыть", it.exists, lclick, col.accent, F_BTN, "play")
      act_ptab = draw_button(px, G.rp_btn2_y, half, G.rp_btn_h, "Новая вкладка", it.exists, lclick, nil, F_SMALL)
      act_fav = draw_button(px + half + G.rp_btn_gap, G.rp_btn2_y, half, G.rp_btn_h, it.fav and "Из избранного" or "В избранное",
        true, lclick, nil, F_SMALL, it.fav and "star" or "star_o")
      act_note = draw_button(px, G.rp_btn3_y, half, G.rp_btn_h, "Заметка (F2)", true, lclick, nil, F_SMALL, "doc")
      act_reveal = draw_button(px + half + G.rp_btn_gap, G.rp_btn3_y, half, G.rp_btn_h, "Папка", it.exists, lclick, nil, F_SMALL, "folder")
    end
  end

  -- ===== окно «Папки»: закрывает список и панель проекта =====
  local rm_dir, opt_click, col_click
  if show_settings then
    set_color(col.bg); gfx.rect(G.side_w, HEAD_H, w - G.side_w, foot_y - HEAD_H, 1)
    gfx.setfont(2, "Arial", F_TITLE, "b")
    draw_text("Папки для поиска проектов", main_x, HEAD_H + 14, col.text)
    gfx.setfont(1, "Arial", F_SMALL)
    draw_text("Проекты (.rpp) ищутся в этих папках и во всех вложенных. Файлы проектов не изменяются.",
      main_x, HEAD_H + 46, col.dim)
    if #lib.dirs == 0 then
      draw_text("Папок нет. Нажмите «Добавить папку…».", main_x, SET_ROW_Y0 + 10, col.dim)
    end
    for i, d in ipairs(lib.dirs) do
      local ry = SET_ROW_Y0 + (i - 1) * SET_ROW_H
      if ry + SET_ROW_H > foot_y - 150 then break end
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(main_x, ry, main_w, SET_ROW_H, 1) end
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(clip_tail(d, main_w - 32 - 110), main_x + 8, ry + (SET_ROW_H - F_ROW) / 2 - 1, col.text)
      if draw_button(main_x + main_w - 96, ry + 4, 90, 26, "Убрать", true, click, nil, F_SMALL) then rm_dir = i end
    end
    -- колонки списка проектов
    gfx.setfont(1, "Arial", F_SMALL)
    draw_text("Колонки списка проектов (хотя бы «Имя» или «Путь» остаётся):", main_x + 4, G.col_opt_y - 22, col.dim)
    local col_labels = { name = "Имя", path = "Путь", date = "Дата", size = "Размер" }
    for i, k in ipairs(COL_SHOW_KEYS) do
      local cx = main_x + 4 + (i - 1) * G.col_opt_step
      local on = col_show[k]
      draw_checkbox(cx, G.col_opt_y + 4, on)
      gfx.setfont(1, "Arial", F_ROW)
      local label = col_labels[k]
      if k == "date" and not has_js_stat then label = label .. " (нужен js_ReaScriptAPI)" end
      draw_text(label, cx + CB + 8, G.col_opt_y + 5, (k == "date" and not has_js_stat) and col.dim or col.text)
      if click and mouse_in(cx - 2, G.col_opt_y, math.min(G.col_opt_step - 6, 120), 28) then col_click = k end
    end
    local options = {
      { key = "skip_backups", y = foot_y - 84, label = "Пропускать папки Backups (копии и автосохранения REAPER)" },
      { key = "with_bak", y = foot_y - 50, label = "Учитывать резервные копии .rpp-bak" },
    }
    for _, o in ipairs(options) do
      draw_checkbox(main_x + 4, o.y + 4, lib[o.key])
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(o.label, main_x + 36, o.y + 5, col.text)
      if click and mouse_in(main_x, o.y, main_w, 28) then opt_click = o.key end
    end
  end

  -- ===== подвал =====
  set_color(col.bg); gfx.rect(0, foot_y, w, FOOT_H, 1)
  set_color(col.border); gfx.rect(0, foot_y, w, 1, 1)
  set_color(col.panel); gfx.rect(0, foot_y + 1, G.side_w, FOOT_H - 1, 1)
  set_color(col.border); gfx.rect(G.side_w - 1, foot_y, 1, FOOT_H, 1)
  set_color(col.panel); gfx.rect(G.rp_x, foot_y + 1, G.rp_w, FOOT_H - 1, 1)
  set_color(col.border); gfx.rect(G.rp_x, foot_y, 1, FOOT_H, 1)

  -- «Выбрано: N (размер)» под боковой панелью
  local n_checked = count_checked()
  do
    local bytes = 0
    for _, it in ipairs(view) do if it.checked and it.size then bytes = bytes + it.size end end
    gfx.setfont(1, "Arial", F_SMALL)
    local txt = n_checked > 0 and string.format("Выбрано: %d  (%s)", n_checked, fmt_size(bytes)) or "Ничего не выбрано"
    draw_text(txt, 16, foot_y + 18, col.dim)
  end

  -- галочка «Открывать в новой вкладке» - справа в строке статуса
  local tab_w = G.tab_w
  local tx = G.rp_x + 18
  if not show_settings then
    draw_checkbox(tx, foot_y + 10, open_new_tab)
    gfx.setfont(1, "Arial", F_SMALL)
    draw_text("Открывать в новой вкладке", tx + CB + 8, foot_y + 13, col.text)
    if click and mouse_in(tx, foot_y + 8, tab_w, 26) then
      open_new_tab = not open_new_tab
      reaper.SetExtState(EXT_SECTION, "open_new_tab", open_new_tab and "1" or "0", true)
      status = open_new_tab and "Проекты открываются в новой вкладке."
        or "Проекты открываются в текущей вкладке: REAPER спросит о сохранении."
    end
  end

  gfx.setfont(1, "Arial", F_SMALL)
  local status_text = status ~= "" and status or "Галочка - выбрать · двойной клик или Enter - открыть · F2 - пометка · Esc - очистить поиск"
  draw_text((status ~= "" and clip_tail or clip_head)(status_text, main_w), main_x, foot_y + 13, col.dim)

  local bh, by = G.bh, G.by
  local act_auto, act_open, act_del, act_undo, act_close, act_scan, act_add, act_back
  local multi_checked -- отмеченные проекты, если их два и больше (кнопка «Открыть отмеченные»)
  local target -- что откроет кнопка «Открыть»
  local scan_label = lib.scan and "Остановить сканирование" or "Пересканировать"
  local scan_enabled = lib.scan ~= nil or #lib.dirs > 0
  local can_edit_list = (source == "recent") and not show_settings -- убирать записи можно только из списка Recent
  if show_settings then
    local bw = (main_w - gap * 3) / 4
    act_add = draw_button(main_x, by, bw, bh, "Добавить папку…", true, click, col.accent, nil, "folder")
    act_scan = draw_button(main_x + (bw + gap), by, bw, bh, scan_label, scan_enabled, click)
    act_back = draw_button(main_x + (bw + gap) * 2, by, bw, bh, "Назад к списку", true, click)
    act_close = draw_button(main_x + (bw + gap) * 3, by, bw, bh, "Закрыть", true, click, nil, nil, "x")
  else
    -- «Открыть»: единственный отмеченный проект, а если отметок нет - проект под курсором; два и больше - очередь
    if n_checked == 1 then
      for _, it in ipairs(view) do if it.checked then target = it end end
    elseif n_checked == 0 then
      target = cursor
    end
    multi_checked = {}
    for _, it in ipairs(view) do if it.checked then multi_checked[#multi_checked + 1] = it end end
    if #multi_checked < 2 then multi_checked = nil end
    local open_label, open_enabled = "Открыть", target ~= nil and target.exists
    if open_queue then
      open_label, open_enabled = string.format("Остановить (осталось %d)", open_queue.total - open_queue.i + 1), true
    elseif multi_checked then
      local n_exist = 0
      for _, it in ipairs(multi_checked) do if it.exists then n_exist = n_exist + 1 end end
      open_label, open_enabled = string.format("Открыть отмеченные (%d)", #multi_checked), n_exist > 0
    end
    local last_undo = undo_stack[#undo_stack]
    local n_missing = count_missing_unprotected()
    act_auto = draw_button(14, by, G.side_w - 28, bh, string.format("Убрать пропавшие (%d)", n_missing),
      can_edit_list and n_missing > 0, click, nil, F_SMALL + 1, "trash")
    local avail = main_w - gap * 3
    local w_open, w_del, w_undo = avail * 0.34, avail * 0.26, avail * 0.22
    local w_close = avail - w_open - w_del - w_undo
    act_open = draw_button(main_x, by, w_open, bh, open_label, open_enabled, click, col.accent, nil, open_queue and "x" or "play")
    act_del = draw_button(main_x + w_open + gap, by, w_del, bh, string.format("Удалить выбранные (%d)", n_checked),
      can_edit_list and n_checked > 0, click, col.btn_danger, F_SMALL + 1, "trash")
    act_undo = draw_button(main_x + w_open + w_del + gap * 2, by, w_undo, bh,
      last_undo and string.format("Вернуть удалённые (%d)", #last_undo.removed) or "Вернуть удалённые",
      last_undo ~= nil, click, nil, F_SMALL + 1, "undo")
    act_close = draw_button(main_x + w_open + w_del + w_undo + gap * 3, by, w_close, bh, "Закрыть", true, click, nil, nil, "x")
  end

  -- ===== действия по кликам =====
  if head_click then side_click = head_click end
  if side_click then
    if side_click == "folders" then
      show_settings = not show_settings
      edit = nil
    elseif side_click == "library" or side_click == "favs" or side_click == "recent" then
      set_source(side_click)
    elseif side_click == "toggle_missing" then
      f_missing = not f_missing; if f_missing then f_found = false end
      after_filter_change()
    elseif side_click == "dd_age" then
      local labels = {}
      for i, s in ipairs(AGE_STEPS) do labels[i] = (i == 1) and "Возраст: любой" or ("Возраст: " .. s[2]) end
      local r = popup(labels, f_age, G.side_w, side_click_y)
      if r then f_age = r; after_filter_change() end
    elseif side_click == "dd_size" then
      local labels = {}
      for i, s in ipairs(SIZE_STEPS) do labels[i] = (i == 1) and "Размер: любой" or ("Размер: " .. s[2]) end
      local r = popup(labels, f_size, G.side_w, side_click_y)
      if r then f_size = r; after_filter_change() end
    elseif side_click == "dd_date" then
      local labels = {}
      for i, s in ipairs(DATE_STEPS) do labels[i] = (i == 1) and "Дата: любая" or ("Дата: " .. s[2]) end
      local r = popup(labels, f_date, G.side_w, side_click_y)
      if r then f_date = r; after_filter_change() end
    end
  end
  if chip_click then
    if chip_click == "found" then f_found = not f_found; if f_found then f_missing = false end; after_filter_change()
    elseif chip_click == "all" then f_found, f_missing = false, false; after_filter_change()
    elseif chip_click == "missing" then f_missing = not f_missing; if f_missing then f_found = false end; after_filter_change()
    elseif chip_click == "age" then
      local labels = {}
      for i, s in ipairs(AGE_STEPS) do labels[i] = (i == 1) and "Возраст: любой" or ("Возраст: " .. s[2]) end
      local r = popup(labels, f_age, chip_x, G.chip_y + G.chip_h)
      if r then f_age = r; after_filter_change() end
    elseif chip_click == "all_check" then
      for _, it in ipairs(view) do
        if source ~= "recent" or not it.fav then it.checked = true end -- в Recent избранные защищены от массового удаления
      end
    elseif chip_click == "none" then
      for _, it in ipairs(items) do it.checked = false end
    end
  end

  if col_click then
    if not toggle_col(col_click) then status = "Нужна хотя бы одна из колонок «Имя» или «Путь»." end
  elseif opt_click then
    lib[opt_click] = not lib[opt_click]
    lib.save_settings()
    status = "Настройка применится при следующем сканировании."
  elseif rm_dir then
    lib.remove_dir(rm_dir)
  elseif fav_now then
    toggle_fav(fav_now)
  elseif open_now then
    open_project(open_now)
  elseif act_fav then
    toggle_fav(cursor)
  elseif act_note then
    start_edit()
  elseif act_reveal then
    reveal_in_folder(cursor)
  elseif act_popen then
    open_project(cursor)
  elseif act_ptab then
    open_project(cursor, true)
  elseif act_add then
    lib.add_folder_dialog()
  elseif act_scan then
    if lib.scan then lib.stop_scan() else lib.start_scan() end
  elseif act_back then
    show_settings = false
  elseif act_auto then
    local doomed = {}
    for _, it in ipairs(view) do if not it.exists and not it.fav then doomed[it.path] = true end end
    remove_where(function(path) return doomed[path] == true end)
  elseif act_open then
    if open_queue then stop_open_queue("Остановлено")
    elseif multi_checked then start_open_queue(multi_checked)
    else open_project(target) end
  elseif act_del then
    local doomed, n_fav = {}, 0
    for _, it in ipairs(view) do
      if it.checked then doomed[it.path] = true; if it.fav then n_fav = n_fav + 1 end end
    end
    local go = true
    if n_fav > 0 then
      go = reaper.ShowMessageBox(string.format(
        "Среди отмеченных проектов есть избранные: %d.\nВсё равно убрать их из списка?", n_fav), TITLE, 4) == 6
    end
    if go then
      remove_where(function(path) return doomed[path] == true end)
    else
      status = "Удаление отменено."
    end
  elseif act_undo then
    restore_last()
  elseif act_close then
    return "close"
  end
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
local ok, err = reload()
if not ok then
  reaper.ShowMessageBox(err, TITLE, 0)
  return
end

-- размер окна запоминается между запусками
local saved_w, saved_h = WIN_W, WIN_H
do
  local sw, sh = tonumber(reaper.GetExtState(EXT_SECTION, "win_w")), tonumber(reaper.GetExtState(EXT_SECTION, "win_h"))
  if sw and sh and sw >= MIN_W and sh >= MIN_H and sw <= 5000 and sh <= 4000 then saved_w, saved_h = sw, sh end
end
gfx.init(TITLE, saved_w, saved_h)

local function loop()
  -- за кадр может накопиться несколько нажатий; предел - защита от зависания
  for _ = 1, 64 do
    local ch = gfx.getchar()
    if ch < 0 then gfx.quit(); return end
    if ch == 0 then break end
    if handle_key(ch) == "close" then gfx.quit(); return end
  end
  if lib.scan then lib.scan_step() end
  open_queue_step()
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
