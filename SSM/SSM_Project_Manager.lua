-- @description SSM_Project_Manager
-- @version 3.0
-- @author @ssm_metalmix
-- @about
--   🗂 Менеджер проектов: недавние (Recent projects) и все проекты из ваших
--   папок - поиск, сортировка, избранное, пометки, быстрое открытие, чистка.
--
--   Источник списка (второй ряд кнопок)
--     - «Недавние» - список Recent projects из reaper.ini (чистка, удаление);
--     - «Все проекты» - каталог файлов .rpp из папок, которые вы добавили
--       кнопкой «Папки». Список только для чтения: проекты можно искать,
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
--     - ★ у проекта: избранные всегда сверху и защищены от массовых действий
--       («Отметить все», «Убрать пропавшие»); удаление отмеченного избранного
--       - только после подтверждения;
--     - пометка (F2 или клик по полю под списком): своя заметка или теги,
--       по ним тоже работает поиск.
--   Панель проекта (под списком)
--     - для проекта под курсором: версия REAPER, темп, частота, число треков,
--       примерная длина, плагины (читается из .rpp);
--     - «Показать в папке» открывает проводник (Finder) на файле проекта.
--   Открытие: двойной клик, Enter или кнопка «Открыть» - в новой вкладке REAPER.
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

local TITLE = "SSM Project Manager"
local WIN_W, WIN_H = 1000, 820
local MIN_W, MIN_H = 720, 560
local HEAD_H, INFO_H, FOOT_H, ROW_H = 192, 90, 116, 34
local SEARCH_Y, SEARCH_H = 66, 34
local SORT_Y, SORT_H = 110, 34
local CHIP_Y, CHIP_H = 152, 30
local EXT_SECTION = "SSM_ProjectManager"
local OLD_EXT_SECTION = "SSM_RecentCleanup" -- настройки прежнего названия скрипта
local COLS_H = 26 -- строка заголовков колонок под шапкой
local COL_DEF = { name = 220, date = 100, size = 84 } -- стандартная ширина, пикселей
local COL_MIN = { name = 60, path = 100, date = 70, size = 56 }
local INDEX_NAME = "SSM_ProjectManager_index.txt" -- индекс «Всех проектов», рядом с reaper.ini
local SCAN_BUDGET, SCAN_MAX_DEPTH = 0.02, 20      -- секунд на кадр; глубина вложенности папок
local SET_ROW_Y0, SET_ROW_H = HEAD_H + 70, 34     -- окно «Папки»: первая строка и высота строки
local F_ROW, F_TITLE, F_SMALL, F_BTN, F_SORT = 17, 20, 15, 17, 16
local CB = 20 -- сторона чекбокса
local STAR_X, STAR_W = 44, 22
local TEXT_X = 74 -- начало пути в строке списка
local BTN_W = 190 -- ширина кнопок панели проекта
local NOTE_LABEL_W = 78
local DOUBLE_CLICK = 0.4 -- секунд
local INFO_MAX_BYTES = 40 * 1024 * 1024

local ini_path = reaper.get_ini_file()

local col = {
  bg = { 0.13, 0.14, 0.16 }, panel = { 0.17, 0.18, 0.21 }, row_alt = { 0.15, 0.16, 0.19 },
  text = { 0.92, 0.93, 0.95 }, dim = { 0.62, 0.65, 0.70 }, accent = { 0.30, 0.55, 0.95 },
  border = { 0.36, 0.38, 0.44 }, danger = { 0.95, 0.42, 0.42 },
  btn = { 0.24, 0.26, 0.31 }, btn_hover = { 0.31, 0.34, 0.40 }, btn_off = { 0.18, 0.19, 0.22 },
  btn_danger = { 0.62, 0.24, 0.24 }, star = { 1.0, 0.80, 0.25 }, tag = { 0.55, 0.75, 1.0 },
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

local AGE_STEPS = { { 0, "любой" }, { 90, "старше 3 мес." }, { 180, "старше 6 мес." },
  { 365, "старше 1 года" }, { 730, "старше 2 лет" } }

local sort_key, sort_desc = "order", false
do
  local section = EXT_SECTION
  if reaper.GetExtState(section, "sort_key") == "" then section = OLD_EXT_SECTION end
  local k = reaper.GetExtState(section, "sort_key")
  for _, sk in ipairs(SORT_KEYS) do if sk.key == k then sort_key = k end end
  sort_desc = reaper.GetExtState(section, "sort_desc") == "1"
end

local f_missing, f_age = false, 1 -- фильтры: только пропавшие, возраст (индекс AGE_STEPS)

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
  if a.fav ~= b.fav then return a.fav end -- избранные всегда сверху
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

local function index_of(it)
  for i, v in ipairs(view) do if v == it then return i end end
  return nil
end

local function filters_active()
  return query ~= "" or f_missing or f_age > 1
end

local function refresh_view()
  local words = {}
  for wd in fold(query):gmatch("%S+") do words[#words + 1] = wd end
  local cutoff
  if f_age > 1 then
    cutoff = os.date("%Y.%m.%d %H:%M:%S", os.time() - AGE_STEPS[f_age][1] * 86400)
  end
  view = {}
  for _, it in ipairs(items) do
    local ok = true
    for _, wd in ipairs(words) do
      if not it.hay_l:find(wd, 1, true) then ok = false; break end
    end
    if ok and f_missing and it.exists then ok = false end
    if ok and cutoff and not (it.mtime and it.mtime < cutoff) then ok = false end
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

  function lib.ensure_loaded()
    if lib.loaded then return end
    lib.loaded = true
    local entries = {}
    for _, e in ipairs(load_index()) do
      if under_dirs(e.path) then entries[#entries + 1] = e end
    end
    lib.items = build(entries, true)
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

set_source = function(src)
  if src == source and not show_settings then return end
  show_settings = false
  edit = nil
  if src == "library" then lib.ensure_loaded() end
  source = src
  items = (src == "recent") and recent_items or lib.items
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

-- Открывает проект в НОВОЙ вкладке (действие 40859), чтобы не трогать текущий
-- проект; "noprompt:" - без вопроса о сохранении пустой вкладки.
local function open_project(it)
  if not it or not it.exists then return end
  reaper.Main_OnCommand(40859, 0)
  reaper.Main_openProject("noprompt:" .. it.path)
  status = "Открыт в новой вкладке: " .. (it.path:match("([^\\/]+)$") or it.path)
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

  local info = { tracks = 0, fx = 0, fx_names = {} }
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
      elseif item_depth and depth == item_depth + 1 then
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

-- Положение колонок для окна шириной w. Без js_ReaScriptAPI даты нет - колонка
-- «Дата» скрыта. В узком окне имя/дата/размер временно ужимаются, путь не меньше минимума.
local function layout(w)
  local right = w - 26 -- справа остаётся место под полосу прокрутки
  local avail = right - TEXT_X
  local nw, dw, sw = col_w.name, has_dates and col_w.date or 0, col_w.size
  local fixed = nw + dw + sw
  if avail - fixed < COL_MIN.path then
    local k = math.max(0.3, (avail - COL_MIN.path) / fixed)
    nw, dw, sw = nw * k, dw * k, sw * k
    fixed = nw + dw + sw
  end
  local pw = avail - fixed
  local L = { right = right, name_x = TEXT_X, name_w = nw, path_x = TEXT_X + nw, path_w = pw }
  L.date_x, L.date_w = L.path_x + pw, dw
  L.size_x, L.size_w = L.date_x + dw, sw
  return L
end

-- Разделители заголовка: какой ширине что соответствует
local function dividers(L)
  local d = { { x = L.path_x, kind = "name" } }             -- имя | путь: меняет имя
  if has_dates then
    d[#d + 1] = { x = L.date_x, kind = "date_l" }           -- путь | дата: меняет дату
    d[#d + 1] = { x = L.size_x, kind = "date_size" }        -- дата | размер: дата <-> размер
  else
    d[#d + 1] = { x = L.size_x, kind = "size_l" }           -- путь | размер: меняет размер
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
  return math.max(1, math.floor((gfx.h - HEAD_H - COLS_H - INFO_H - FOOT_H) / ROW_H))
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
  if ch == 27 then
    if query ~= "" then set_query("") else return "close" end
  elseif ch == 13 then open_project(cursor)
  elseif ch == KEY.up then move_cursor_to(idx - 1)
  elseif ch == KEY.down then move_cursor_to(idx + 1)
  elseif ch == KEY.pgup then move_cursor_to(idx - page_rows())
  elseif ch == KEY.pgdn then move_cursor_to(idx + page_rows())
  elseif ch == KEY.home then move_cursor_to(1)
  elseif ch == KEY["end"] then move_cursor_to(#view)
  elseif ch == 9 or ch == KEY.ins then -- Tab / Insert: отметить и перейти ниже
    if cursor and source == "recent" then
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
  if source == "library" then -- в «Всех проектах» галочек нет: клик ставит курсор
    if dbl then last_click_it = nil end
    return dbl
  end
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
-- Отрисовка
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

-- Обрезка слева ("…хвост пути") - имя файла в конце пути самое важное
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

-- Обрезка справа ("начало…")
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
  local tw = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - size) / 2 - 1, enabled and col.text or col.dim)
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

local function draw()
  local w, h = gfx.w, gfx.h
  local cap = gfx.mouse_cap
  local down = (cap & 1) == 1
  local click = down and (last_cap & 1) == 0
  local shift = (cap & 8) ~= 0
  last_cap = cap
  local lclick = click and not show_settings -- клики по списку и панели проекта не проходят под окно «Папки»

  local list_y = HEAD_H + COLS_H
  local foot_y = h - FOOT_H
  local info_y = foot_y - INFO_H
  local list_h = math.max(60, info_y - list_y)
  local text_w = w - 32 - BTN_W - 12                 -- ширина текста панели проекта
  local note_x, note_y = 16 + NOTE_LABEL_W, info_y + 54 -- поле пометки
  local note_w, note_h = text_w - NOTE_LABEL_W, 26

  set_color(col.bg); gfx.rect(0, 0, w, h, 1)

  -- клик мимо поля пометки завершает её редактирование
  if edit and click and not mouse_in(note_x, note_y, note_w, note_h) then commit_edit() end

  -- ширина колонок: перетаскивание разделителя, двойной клик - сброс
  if col_drag then
    if down then
      apply_drag(col_drag.kind, col_drag.start, gfx.mouse_x - col_drag.x0)
    else
      col_drag = nil
      save_cols()
    end
  end
  local L = layout(w)
  local divs = dividers(L)
  if lclick and not col_drag and gfx.mouse_y >= HEAD_H and gfx.mouse_y < list_y then
    for _, dv in ipairs(divs) do
      if math.abs(gfx.mouse_x - dv.x) <= 4 then
        local now = reaper.time_precise()
        if now - last_div_click_t < DOUBLE_CLICK then
          reset_cols()
          last_div_click_t = -1e9
        else
          last_div_click_t = now
          col_w.name, col_w.date, col_w.size = L.name_w, has_dates and L.date_w or col_w.date, L.size_w
          col_drag = { kind = dv.kind, x0 = gfx.mouse_x,
            start = { name = col_w.name, date = col_w.date, size = col_w.size, path = L.path_w } }
        end
        break
      end
    end
  end

  local total_h = #view * ROW_H
  local max_scroll = math.max(0, total_h - list_h)

  if gfx.mouse_wheel ~= 0 then
    scroll = scroll - (gfx.mouse_wheel / 120) * ROW_H * 3
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

  -- строки списка (шапка и панели перекрывают выступающие части)
  gfx.setfont(1, "Arial", F_ROW)
  local open_now, fav_now
  for i, it in ipairs(view) do
    local ry = list_y + (i - 1) * ROW_H - scroll
    if ry + ROW_H > list_y and ry < list_y + list_h then
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(0, ry, w, ROW_H, 1) end

      local in_list = gfx.mouse_y >= list_y and gfx.mouse_y < list_y + list_h
      if in_list and mouse_in(0, ry, w - 14, ROW_H) then
        set_color(col.panel); gfx.rect(0, ry, w, ROW_H, 1)
        if lclick then
          if mouse_in(STAR_X - 2, ry, STAR_W + 4, ROW_H) then
            fav_now = it
          elseif row_click(it, shift, reaper.time_precise()) then
            open_now = it
          end
        end
      end
      if it == cursor then
        set_color(col.accent); gfx.rect(1, ry, w - 16, ROW_H, 0)
      end

      if source == "recent" then draw_checkbox(16, ry + (ROW_H - CB) / 2, it.checked) end
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(it.fav and "★" or "☆", STAR_X, ry + (ROW_H - F_ROW) / 2 - 1, it.fav and col.star or col.dim)

      local small_y = ry + (ROW_H - F_SMALL) / 2
      local text_y = ry + (ROW_H - F_ROW) / 2 - 1
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(clip_head(it.title, L.name_w - 12), L.name_x + 4, text_y, it.exists and col.text or col.dim)

      -- пометка - у правого края колонки пути
      local note_tag_w = 0
      if it.note ~= "" then
        gfx.setfont(1, "Arial", F_SMALL)
        local shown = clip_head(it.note, math.min(220, L.path_w * 0.4))
        note_tag_w = gfx.measurestr(shown) + 14
        draw_text(shown, L.date_x - note_tag_w + 4, small_y, col.tag)
        gfx.setfont(1, "Arial", F_ROW)
      end
      draw_text(clip_tail(it.path, L.path_w - 12 - note_tag_w), L.path_x + 4, text_y, col.dim)

      gfx.setfont(1, "Arial", F_SMALL)
      if it.exists then
        if has_dates then draw_text(fmt_date(it.mtime), L.date_x + 4, small_y, col.dim) end
        local sz = fmt_size(it.size)
        draw_text(sz, L.right - 2 - gfx.measurestr(sz), small_y, col.dim)
      else
        local tag = "не найден"
        draw_text(tag, L.right - 2 - gfx.measurestr(tag), small_y, col.danger)
      end
    end
  end

  if #items == 0 then
    local msg
    if source == "recent" then msg = "Список Recent projects пуст."
    elseif #lib.dirs == 0 then msg = "Папки не заданы. Нажмите «Папки» и добавьте папку с проектами."
    elseif lib.scan then msg = "Идёт сканирование…"
    else msg = "Список пуст. Нажмите «Пересканировать»." end
    draw_text(msg, 16, list_y + 18, col.dim)
  elseif #view == 0 then
    draw_text("Ничего не найдено. Измените поиск или фильтры.", 16, list_y + 18, col.dim)
  end

  -- полоса прокрутки
  if max_scroll > 0 then
    local thumb_h = math.max(24, list_h * list_h / total_h)
    local thumb_y = list_y + (list_h - thumb_h) * (scroll / max_scroll)
    set_color(col.border); gfx.rect(w - 10, thumb_y, 6, thumb_h, 1)
  end

  -- заголовки колонок с разделителями
  set_color(col.row_alt); gfx.rect(0, HEAD_H, w, COLS_H, 1)
  set_color(col.border); gfx.rect(0, list_y - 1, w, 1, 1)
  gfx.setfont(1, "Arial", F_SMALL)
  local hy = HEAD_H + (COLS_H - F_SMALL) / 2 - 1
  draw_text("Имя", L.name_x + 4, hy, col.dim)
  draw_text("Путь", L.path_x + 4, hy, col.dim)
  if has_dates then draw_text("Дата", L.date_x + 4, hy, col.dim) end
  draw_text("Размер", L.right - 2 - gfx.measurestr("Размер"), hy, col.dim)
  for _, dv in ipairs(divs) do
    local hot = (col_drag and col_drag.kind == dv.kind) or (not col_drag and mouse_in(dv.x - 4, HEAD_H, 9, COLS_H))
    set_color(hot and col.accent or col.border)
    gfx.rect(dv.x - (hot and 1 or 0), HEAD_H + 4, hot and 3 or 1, COLS_H - 8, 1)
  end

  -- шапка
  set_color(col.panel); gfx.rect(0, 0, w, HEAD_H, 1)
  set_color(col.border); gfx.rect(0, HEAD_H - 1, w, 1, 1)
  gfx.setfont(1, "Arial", F_TITLE)
  if not filters_active() then
    draw_text(string.format("%s: %d  (не найдено: %d)", source == "recent" and "Недавние проекты" or "Все проекты",
      #items, count_missing()), 16, 9, col.text)
  else
    draw_text(string.format("Найдено: %d из %d  (не найдено: %d)", #view, #items, count_missing()), 16, 9, col.text)
  end
  gfx.setfont(1, "Arial", F_SMALL)
  if source == "recent" then
    draw_text("Галочка - выбрать · ★ - избранное · двойной клик или Enter - открыть · F2 - пометка · Esc - очистить поиск",
      16, 40, col.dim)
  else
    draw_text("★ - избранное · двойной клик или Enter - открыть · F2 - пометка · Esc - очистить поиск · «Папки» - где искать проекты",
      16, 40, col.dim)
  end
  if not has_js_stat then
    gfx.setfont(1, "Arial", 14)
    local note = "Дата изменения: нужен js_ReaScriptAPI"
    draw_text(note, w - 16 - gfx.measurestr(note), 12, col.dim)
  end

  -- строка поиска: ввод идёт сюда всегда (см. loop), справа кнопка очистки
  do
    local sx, sw = 16, w - 32
    set_color(col.bg); gfx.rect(sx, SEARCH_Y, sw, SEARCH_H, 1)
    set_color(query ~= "" and col.accent or col.border); gfx.rect(sx, SEARCH_Y, sw, SEARCH_H, 0)
    gfx.setfont(1, "Arial", F_ROW)
    local ty = SEARCH_Y + (SEARCH_H - F_ROW) / 2 - 1
    local clear_w = SEARCH_H
    local shown = ""
    if query == "" then
      draw_text("Поиск по имени, пути и пометкам: начните печатать…", sx + 10, ty, col.dim)
    else
      shown = clip_tail(query, sw - clear_w - 20)
      draw_text(shown, sx + 10, ty, col.text)
      local cx = sx + sw - clear_w
      local hov = mouse_in(cx, SEARCH_Y, clear_w, SEARCH_H)
      set_color(hov and col.btn_hover or col.btn); gfx.rect(cx + 1, SEARCH_Y + 1, clear_w - 2, SEARCH_H - 2, 1)
      draw_text("✕", cx + (clear_w - gfx.measurestr("✕")) / 2, ty, col.text)
      if hov and click then set_query("") end
    end
    if not edit and math.floor(reaper.time_precise() * 2) % 2 == 0 then -- мигающий курсор
      set_color(col.text)
      gfx.rect(sx + 10 + gfx.measurestr(shown) + 1, SEARCH_Y + 7, 1, SEARCH_H - 14, 1)
    end
  end

  -- ряд кнопок сортировки
  do
    local n, gap = #SORT_KEYS, 6
    local bw2 = (w - 32 - gap * (n - 1)) / n
    local clicked_key
    for i, sk in ipairs(SORT_KEYS) do
      local active = (sk.key == sort_key)
      local enabled = not (sk.key == "date" and not has_dates)
      local label = sk.label
      if sk.key == "order" and source == "library" then label = "Как найдено" end
      if active and (sk.key ~= "order" or sort_desc) then label = label .. (sort_desc and " ▼" or " ▲") end
      local x = 16 + (i - 1) * (bw2 + gap)
      local hov = enabled and mouse_in(x, SORT_Y, bw2, SORT_H)
      local c = (not enabled) and col.btn_off or (active and col.accent or (hov and col.btn_hover or col.btn))
      set_color(c); gfx.rect(x, SORT_Y, bw2, SORT_H, 1)
      set_color(col.border); gfx.rect(x, SORT_Y, bw2, SORT_H, 0)
      local size = F_SORT
      gfx.setfont(1, "Arial", size)
      while size > 11 and gfx.measurestr(label) > bw2 - 8 do
        size = size - 1
        gfx.setfont(1, "Arial", size)
      end
      draw_text(label, x + (bw2 - gfx.measurestr(label)) / 2, SORT_Y + (SORT_H - size) / 2 - 1,
        enabled and col.text or col.dim)
      if hov and click then clicked_key = sk.key end
    end
    if clicked_key then set_sort(clicked_key) end
  end

  -- второй ряд: источник списка, фильтры, массовая отметка (Недавние) или «Папки» (Все проекты)
  do
    local specs = {
      { id = "recent", w = 112, label = "Недавние", color = source == "recent" and col.accent or nil },
      { id = "library", w = 112, label = "Все проекты", color = source == "library" and col.accent or nil },
      { id = "missing", w = 190, label = "Только не найденные", color = f_missing and col.accent or nil },
      { id = "age", w = 210, enabled = has_dates, color = f_age > 1 and col.accent or nil,
        label = has_dates and ("Возраст: " .. AGE_STEPS[f_age][2]) or "Возраст: нужен js_ReaScriptAPI" },
    }
    local right
    if source == "recent" then
      right = { { id = "all", w = 120, label = "Отметить все", enabled = #view > 0 },
                { id = "none", w = 110, label = "Снять все" } }
    else
      right = { { id = "folders", w = 100, label = "Папки", color = show_settings and col.accent or nil } }
    end
    local gap, sum = 8, 0
    for _, b in ipairs(specs) do sum = sum + b.w end
    for _, b in ipairs(right) do sum = sum + b.w end
    local gaps = (#specs - 1 + #right - 1 + 1) * gap -- плюс зазор между левой и правой группами
    local k = math.max(0.5, math.min(1, (w - 32 - gaps) / sum)) -- в узком окне кнопки ужимаются
    local clicked
    local x = 16
    for _, b in ipairs(specs) do
      local bw = b.w * k
      if draw_button(x, CHIP_Y, bw, CHIP_H, b.label, b.enabled ~= false, click, b.color, F_SMALL) then clicked = b.id end
      x = x + bw + gap
    end
    x = w - 16
    for i = #right, 1, -1 do
      local b = right[i]
      local bw = b.w * k
      x = x - bw
      if draw_button(x, CHIP_Y, bw, CHIP_H, b.label, b.enabled ~= false, click, b.color, F_SMALL) then clicked = b.id end
      x = x - gap
    end
    if clicked == "recent" or clicked == "library" then set_source(clicked)
    elseif clicked == "missing" then f_missing = not f_missing; after_filter_change()
    elseif clicked == "age" then f_age = f_age % #AGE_STEPS + 1; after_filter_change()
    elseif clicked == "all" then
      for _, it in ipairs(view) do if not it.fav then it.checked = true end end -- избранные защищены
    elseif clicked == "none" then
      for _, it in ipairs(items) do it.checked = false end
    elseif clicked == "folders" then
      show_settings = not show_settings
      edit = nil
    end
  end

  -- панель проекта под курсором
  local act_fav, act_note, act_reveal
  do
    set_color(col.panel); gfx.rect(0, info_y, w, INFO_H, 1)
    set_color(col.border); gfx.rect(0, info_y, w, 1, 1)
    local it = cursor
    if not it then
      gfx.setfont(1, "Arial", F_SMALL)
      draw_text("Проект не выбран.", 16, info_y + 12, col.dim)
    else
      gfx.setfont(1, "Arial", F_ROW)
      local name = it.path:match("([^\\/]+)$") or it.path
      draw_text(clip_head(name, text_w), 16, info_y + 8, it.exists and col.text or col.danger)

      gfx.setfont(1, "Arial", F_SMALL)
      local line
      if not it.exists then
        line = "Файл не найден."
      else
        local inf = get_info(it)
        if not inf then line = "Читаю проект…"
        elseif inf.err then line = inf.err
        else line = info_text(inf) end
      end
      draw_text(clip_head(line, text_w), 16, info_y + 33, col.dim)

      -- пометка: поле ввода (клик или F2 - редактировать)
      draw_text("Пометка:", 16, note_y + (note_h - F_SMALL) / 2 - 1, col.dim)
      local editing = edit and edit.it == it
      set_color(col.bg); gfx.rect(note_x, note_y, note_w, note_h, 1)
      set_color(editing and col.accent or col.border); gfx.rect(note_x, note_y, note_w, note_h, 0)
      local ty = note_y + (note_h - F_SMALL) / 2 - 1
      if editing then
        local shown = clip_tail(edit.buf, note_w - 20)
        draw_text(shown, note_x + 8, ty, col.text)
        if math.floor(reaper.time_precise() * 2) % 2 == 0 then
          set_color(col.text)
          gfx.rect(note_x + 8 + gfx.measurestr(shown) + 1, note_y + 4, 1, note_h - 8, 1)
        end
      elseif it.note ~= "" then
        draw_text(clip_head(it.note, note_w - 20), note_x + 8, ty, col.tag)
      else
        draw_text("нет - клик или F2, чтобы добавить (Enter - сохранить)", note_x + 8, ty, col.dim)
      end
      if lclick and not edit and mouse_in(note_x, note_y, note_w, note_h) then start_edit() end

      local bx = w - 16 - BTN_W
      act_fav = draw_button(bx, info_y + 6, BTN_W, 24, it.fav and "★ Убрать из избранного" or "☆ В избранное",
        true, lclick, nil, F_SMALL)
      act_note = draw_button(bx, info_y + 33, BTN_W, 24, "Пометка (F2)", true, lclick, nil, F_SMALL)
      act_reveal = draw_button(bx, info_y + 60, BTN_W, 24, "Показать в папке", it.exists, lclick, nil, F_SMALL)
    end
  end

  -- окно «Папки»: закрывает список и панель проекта
  local rm_dir, opt_click
  if show_settings then
    set_color(col.bg); gfx.rect(0, HEAD_H, w, foot_y - HEAD_H, 1)
    set_color(col.border); gfx.rect(0, HEAD_H, w, 1, 1)
    gfx.setfont(1, "Arial", F_TITLE)
    draw_text("Папки для поиска проектов", 16, HEAD_H + 12, col.text)
    gfx.setfont(1, "Arial", F_SMALL)
    draw_text("Проекты (.rpp) ищутся в этих папках и во всех вложенных. Файлы проектов не изменяются.",
      16, HEAD_H + 42, col.dim)
    if #lib.dirs == 0 then
      draw_text("Папок нет. Нажмите «Добавить папку…».", 16, SET_ROW_Y0 + 10, col.dim)
    end
    for i, d in ipairs(lib.dirs) do
      local ry = SET_ROW_Y0 + (i - 1) * SET_ROW_H
      if ry + SET_ROW_H > foot_y - 100 then break end
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(0, ry, w, SET_ROW_H, 1) end
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(clip_tail(d, w - 32 - 110), 16, ry + (SET_ROW_H - F_ROW) / 2 - 1, col.text)
      if draw_button(w - 16 - 90, ry + 4, 90, 26, "Убрать", true, click, nil, F_SMALL) then rm_dir = i end
    end
    local options = {
      { key = "skip_backups", y = foot_y - 84, label = "Пропускать папки Backups (копии и автосохранения REAPER)" },
      { key = "with_bak", y = foot_y - 50, label = "Учитывать резервные копии .rpp-bak" },
    }
    for _, o in ipairs(options) do
      draw_checkbox(16, o.y + 4, lib[o.key])
      gfx.setfont(1, "Arial", F_ROW)
      draw_text(o.label, 46, o.y + 5, col.text)
      if click and mouse_in(16, o.y, w - 32, 28) then opt_click = o.key end
    end
  end

  -- подвал
  set_color(col.panel); gfx.rect(0, foot_y, w, FOOT_H, 1)
  set_color(col.border); gfx.rect(0, foot_y, w, 1, 1)

  gfx.setfont(1, "Arial", F_SMALL)
  draw_text(clip_tail(status, w - 32), 16, foot_y + 13, col.dim)

  local bh, by, gap = 46, foot_y + 52, 10
  local act_auto, act_open, act_del, act_undo, act_close, act_scan, act_add, act_back
  local target -- что откроет кнопка «Открыть»
  local scan_label = lib.scan and "Остановить сканирование" or "Пересканировать"
  local scan_enabled = lib.scan ~= nil or #lib.dirs > 0
  if show_settings then
    local bw = (w - 32 - gap * 3) / 4
    act_add = draw_button(16, by, bw, bh, "Добавить папку…", true, click, col.accent)
    act_scan = draw_button(16 + (bw + gap), by, bw, bh, scan_label, scan_enabled, click)
    act_back = draw_button(16 + (bw + gap) * 2, by, bw, bh, "Назад к списку", true, click)
    act_close = draw_button(16 + (bw + gap) * 3, by, bw, bh, "Закрыть", true, click)
  elseif source == "library" then
    target = cursor
    local bw = (w - 32 - gap * 2) / 3
    act_scan = draw_button(16, by, bw, bh, scan_label, scan_enabled, click)
    act_open = draw_button(16 + (bw + gap), by, bw, bh, "Открыть", target ~= nil and target.exists, click, col.accent)
    act_close = draw_button(16 + (bw + gap) * 2, by, bw, bh, "Закрыть", true, click)
  else
    local n_missing, n_checked = count_missing_unprotected(), count_checked()
    -- «Открыть»: единственный отмеченный проект, а если отметок нет - проект под курсором
    if n_checked == 1 then
      for _, it in ipairs(view) do if it.checked then target = it end end
    elseif n_checked == 0 then
      target = cursor
    end
    local last_undo = undo_stack[#undo_stack]
    local bw = (w - 32 - gap * 4) / 5
    act_auto = draw_button(16, by, bw, bh,
      string.format("Убрать пропавшие (%d)", n_missing), n_missing > 0, click)
    act_open = draw_button(16 + (bw + gap), by, bw, bh, "Открыть", target ~= nil and target.exists, click, col.accent)
    act_del = draw_button(16 + (bw + gap) * 2, by, bw, bh,
      string.format("Удалить выбранные (%d)", n_checked), n_checked > 0, click, col.btn_danger)
    act_undo = draw_button(16 + (bw + gap) * 3, by, bw, bh,
      last_undo and string.format("Вернуть удалённые (%d)", #last_undo.removed) or "Вернуть удалённые",
      last_undo ~= nil, click)
    act_close = draw_button(16 + (bw + gap) * 4, by, bw, bh, "Закрыть", true, click)
  end

  if opt_click then
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
    open_project(target)
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
