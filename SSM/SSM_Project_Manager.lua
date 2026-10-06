-- @description SSM_Project_Manager
-- @version 4.0
-- @author @ssm_metalmix
-- @about
--   🗂 Менеджер проектов: недавние (Recent projects) и все проекты из ваших
--   папок - поиск, сортировка, избранное, пометки, быстрое открытие, чистка.
--
--   Нужна ReaImGui (расширение REAPER): REAPER -> Extensions -> ReaPack -> Browse
--   packages -> ReaImGui (репозиторий ReaTeam Extensions). Без неё скрипт
--   подскажет, как её поставить.
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
--   Открытие: двойной клик, Enter или кнопка «Открыть». Галочка «Открывать в новой
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
--   4.0 Окно переписано на ReaImGui: быстрее на длинных списках (рисуются только
--   видимые строки), обычная полоса прокрутки и ввод текста (вставка Ctrl+V без SWS).
--   Нужна ReaImGui 0.10 или новее (ReaPack, репозиторий ReaTeam Extensions).
--   Все функции, избранное, пометки, индекс «Всех проектов» и ширины колонок - прежние.
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
local WIN_W, WIN_H = 1000, 820
local MIN_W, MIN_H = 720, 560
local INFO_H, FOOT_H, ROW_H = 90, 116, 34
local EXT_SECTION = "SSM_ProjectManager"
local OLD_EXT_SECTION = "SSM_RecentCleanup" -- настройки прежнего названия скрипта
local COLS_H = 26 -- строка заголовков колонок под шапкой
local COL_DEF = { name = 220, date = 100, size = 84 } -- стандартная ширина, пикселей
local COL_MIN = { name = 60, path = 100, date = 70, size = 56 }
local INDEX_NAME = "SSM_ProjectManager_index.txt" -- индекс «Всех проектов», рядом с reaper.ini
local SCAN_BUDGET, SCAN_MAX_DEPTH = 0.02, 20      -- секунд на кадр; глубина вложенности папок
local F_ROW, F_TITLE, F_SMALL = 17, 20, 15 -- размеры шрифта окна, пикселей
local CB = 20 -- сторона чекбокса
local STAR_X, STAR_W = 28, 22 -- звёздочка: от левого края колонок списка
local TEXT_X = 58 -- начало имени в строке списка (от левого края колонок)
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
local scroll_reset = false -- после поиска, фильтров и смены сортировки список возвращается наверх

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
  scroll_reset = true
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
  scroll_reset = true
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
    scroll_reset = true
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
  scroll_reset = true
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

-- Как открывать проект: в новой вкладке (по умолчанию) или в текущей
local open_new_tab = reaper.GetExtState(EXT_SECTION, "open_new_tab") ~= "0"

-- Новая вкладка (действие 40859): текущий проект не трогается; "noprompt:" - без вопроса
-- о сохранении пустой вкладки. В текущей вкладке имя без "noprompt:" - REAPER сам
-- спросит, сохранить ли несохранённые изменения, ничего не потеряется молча.
local function open_project(it)
  if not it or not it.exists then return end
  local name = it.path:match("([^\\/]+)$") or it.path
  if open_new_tab then
    reaper.Main_OnCommand(40859, 0)
    reaper.Main_openProject("noprompt:" .. it.path)
    status = "Открыт в новой вкладке: " .. name
  else
    reaper.Main_openProject(it.path)
    status = "Открыт в текущей вкладке: " .. name
  end
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
  local right = w -- w - ширина колонок от их левого края (справа уже оставлено место под полосу прокрутки)
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

local col_drag = nil               -- { kind, start } пока разделитель тащат

----------------------------------------------------------------------
-- Ввод пометки
----------------------------------------------------------------------
local NOTE_MAX = 200 -- байт

-- Обрезка строки до max байт без разрыва символа UTF-8
local function cut_utf8(s, max)
  if #s <= max then return s end
  local i = max
  while i > 0 and ((s:byte(i + 1) or 0) & 0xC0) == 0x80 do i = i - 1 end
  return s:sub(1, i)
end

local function start_edit()
  if cursor and not edit then edit = { it = cursor, buf = cursor.note, focus = true } end
end

local function commit_edit()
  if not edit then return end
  local it = edit.it
  local text = cut_utf8(edit.buf:gsub("^%s+", ""):gsub("%s+$", ""), NOTE_MAX)
  edit = nil
  if text ~= it.note then
    set_note_of(it, text)
    status = text == "" and "Пометка удалена." or "Пометка сохранена."
  end
end

local function move_cursor_to(idx)
  if #view == 0 then return end
  cursor = view[math.max(1, math.min(idx, #view))]
  follow_cursor = true
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
-- ReaImGui: подключение
----------------------------------------------------------------------
local NEED_IMGUI = "Окно менеджера проектов работает на расширении ReaImGui, а оно не установлено.\n\n" ..
  "Как поставить:\n" ..
  "1. REAPER -> Extensions -> ReaPack -> Browse packages.\n" ..
  "2. Найти «ReaImGui» (репозиторий ReaTeam Extensions) -> правый клик -> Install.\n" ..
  "3. Apply, затем перезапустить REAPER и запустить скрипт снова."
local NEED_IMGUI_NEW = "Установленная ReaImGui слишком старая: нужна версия 0.10 или новее.\n\n" ..
  "Обновить: REAPER -> Extensions -> ReaPack -> Synchronize packages (или Browse packages -> ReaImGui -> Install), " ..
  "затем перезапустить REAPER."

local function connect_imgui()
  if not reaper.ImGui_GetBuiltinPath then return nil, NEED_IMGUI end
  package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua"
  local ok, lib = pcall(require, "imgui")
  if not ok or type(lib) ~= "function" then return nil, NEED_IMGUI end
  local ok2, api = pcall(lib, "0.10")
  if not ok2 then return nil, NEED_IMGUI_NEW end
  return api
end

local ImGui, imgui_err = connect_imgui()
if not ImGui then
  reaper.ShowMessageBox(imgui_err, TITLE, 0)
  return
end

----------------------------------------------------------------------
-- Окно: цвета, шрифты, помощники рисования
----------------------------------------------------------------------
local function rgba(c, a)
  return (math.floor(c[1] * 255 + 0.5) << 24) | (math.floor(c[2] * 255 + 0.5) << 16)
    | (math.floor(c[3] * 255 + 0.5) << 8) | (a or 255)
end
local C = {} -- те же цвета в формате ReaImGui (0xRRGGBBAA)
for k, v in pairs(col) do C[k] = rgba(v) end

local WINDOW_TITLE = TITLE .. "###SSM_ProjectManager"
local ctx = ImGui.CreateContext("SSM Project Manager")
local clipper = ImGui.CreateListClipper(ctx)
ImGui.Attach(ctx, clipper)
-- Шрифт тот же, что был в окне до 4.0 (Arial); нет такого - любой без засечек
local font
do
  local ok, f = pcall(ImGui.CreateFont, "Arial")
  if not ok or not f then ok, f = pcall(ImGui.CreateFont, "sans-serif") end
  font = ok and f or nil
  if font then ImGui.Attach(ctx, font) end
end

local search_gen, note_gen = 0, 0 -- меняются, когда текст полей меняет сам скрипт (Esc, кнопка очистки): поле создаётся заново
local list_h = 400               -- высота списка в последнем кадре (для PgUp/PgDn)
local later = {}                 -- действия с модальными окнами и открытием проектов: выполняются вне кадра ReaImGui
local want_close = false
local ITEM_GAP = 8
local SB = 14                    -- ширина полосы прокрутки списка
local OX = 16                    -- левый край колонок списка
local RIGHT_PAD = 26             -- справа от колонок остаётся место под полосу прокрутки
local CB_X, STAR_CX = 0, STAR_X + STAR_W / 2

local function defer_action(fn) later[#later + 1] = fn end

local function text_w(s) return (ImGui.CalcTextSize(ctx, s)) end

-- Обрезка слева ("…хвост пути") - имя файла в конце пути самое важное
local function clip_tail(str, max_w)
  if text_w(str) <= max_w then return str end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, 2)
    if not ok or not off then off = 2 end
    s = s:sub(off)
    if text_w("…" .. s) <= max_w then return "…" .. s end
  end
  return "…"
end

-- Обрезка справа ("начало…")
local function clip_head(str, max_w)
  if text_w(str) <= max_w then return str end
  local s = str
  while #s > 1 do
    local ok, off = pcall(utf8.offset, s, -1)
    if not ok or not off then off = #s end
    s = s:sub(1, off - 1)
    if text_w(s .. "…") <= max_w then return s .. "…" end
  end
  return "…"
end

-- Звёздочка и галочка рисуются линиями: в шрифте может не быть символов ★ и ✓
local function draw_star(dl, cx, cy, R, filled, color)
  local pts, r = {}, R * 0.42
  for k = 0, 9 do
    local a = -math.pi / 2 + k * math.pi / 5
    local rr = (k % 2 == 0) and R or r
    pts[#pts + 1] = { cx + rr * math.cos(a), cy + rr * math.sin(a) }
  end
  for k = 1, 10 do
    local a, b = pts[k], pts[k % 10 + 1]
    if filled then
      ImGui.DrawList_AddTriangleFilled(dl, cx, cy, a[1], a[2], b[1], b[2], color)
    else
      ImGui.DrawList_AddLine(dl, a[1], a[2], b[1], b[2], color, 1.5)
    end
  end
end

local function draw_check(dl, x, y, checked)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + CB, y + CB, checked and C.accent or C.bg)
  ImGui.DrawList_AddRect(dl, x, y, x + CB, y + CB, C.border)
  if checked then
    ImGui.DrawList_AddLine(dl, x + 4, y + 10, x + 8, y + 14, C.text, 2)
    ImGui.DrawList_AddLine(dl, x + 8, y + 14, x + 16, y + 5, C.text, 2)
  end
end

-- Кнопка: color - цвет фона вместо обычного, enabled == false - серая и не нажимается
local function button(label, id, w, h, enabled, color)
  if enabled == false then ImGui.BeginDisabled(ctx) end
  if color then ImGui.PushStyleColor(ctx, ImGui.Col_Button, color) end
  local clicked = ImGui.Button(ctx, label .. "##" .. id, w, h)
  if color then ImGui.PopStyleColor(ctx) end
  if enabled == false then ImGui.EndDisabled(ctx) end
  return clicked and enabled ~= false
end

-- Ряд кнопок одной ширины на всю ширину avail_w; возвращает id нажатой
local function button_row(specs, avail_w, h)
  local bw = (avail_w - ITEM_GAP * (#specs - 1)) / #specs
  local clicked
  for i, s in ipairs(specs) do
    if i > 1 then ImGui.SameLine(ctx) end
    if button(s.label, s.id, bw, h, s.enabled, s.color) then clicked = s.id end
  end
  return clicked
end

-- Панель на всю ширину окна (от левого края) с цветом фона и отступами
local function begin_panel(id, win_w, h, bg, pad_x, pad_y)
  ImGui.SetCursorPosX(ctx, 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, bg)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, pad_x or OX, pad_y or 8)
  local visible = ImGui.BeginChild(ctx, id, win_w, h, ImGui.ChildFlags_AlwaysUseWindowPadding,
    ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse)
  ImGui.PopStyleVar(ctx)
  ImGui.PopStyleColor(ctx)
  return visible
end

local function small_text(str, color)
  ImGui.PushFont(ctx, font, F_SMALL)
  ImGui.TextColored(ctx, color or C.dim, str)
  ImGui.PopFont(ctx)
end

----------------------------------------------------------------------
-- Окно: ввод с клавиатуры
----------------------------------------------------------------------
local function pressed(key, repeat_) return ImGui.IsKeyPressed(ctx, key, repeat_ == true) end

local function clear_query()
  set_query("")
  search_gen = search_gen + 1
end

local function page_rows() return math.max(1, math.floor(list_h / ROW_H)) end

local function handle_keys()
  local enter = pressed(ImGui.Key_Enter) or pressed(ImGui.Key_KeypadEnter)
  if show_settings then -- в окне «Папки» ввода нет: Esc возвращает к списку
    if pressed(ImGui.Key_Escape) then show_settings = false end
    return
  end
  if edit then
    if enter then commit_edit(); note_gen = note_gen + 1
    elseif pressed(ImGui.Key_Escape) then edit = nil; note_gen = note_gen + 1 end
    return
  end
  local idx = index_of(cursor) or 1
  if pressed(ImGui.Key_Escape) then
    if query ~= "" then clear_query() else want_close = true end
  elseif enter then
    local it = cursor
    defer_action(function() open_project(it) end)
  elseif pressed(ImGui.Key_UpArrow, true) then move_cursor_to(idx - 1)
  elseif pressed(ImGui.Key_DownArrow, true) then move_cursor_to(idx + 1)
  elseif pressed(ImGui.Key_PageUp, true) then move_cursor_to(idx - page_rows())
  elseif pressed(ImGui.Key_PageDown, true) then move_cursor_to(idx + page_rows())
  elseif pressed(ImGui.Key_Home) then move_cursor_to(1)
  elseif pressed(ImGui.Key_End) then move_cursor_to(#view)
  elseif pressed(ImGui.Key_Tab) or pressed(ImGui.Key_Insert) then -- отметить и перейти ниже
    if cursor and source == "recent" then
      cursor.checked = not cursor.checked
      anchor = cursor
      move_cursor_to(idx + 1)
    end
  elseif pressed(ImGui.Key_F2) then start_edit()
  end
end

----------------------------------------------------------------------
-- Окно: заголовок, поиск, кнопки сортировки и фильтров
----------------------------------------------------------------------
local function draw_top(win_w)
  local inner_w = win_w - OX * 2
  ImGui.PushFont(ctx, font, F_TITLE)
  if not filters_active() then
    ImGui.Text(ctx, string.format("%s: %d  (не найдено: %d)", source == "recent" and "Недавние проекты" or "Все проекты",
      #items, count_missing()))
  else
    ImGui.Text(ctx, string.format("Найдено: %d из %d  (не найдено: %d)", #view, #items, count_missing()))
  end
  ImGui.PopFont(ctx)
  if not has_js_stat then
    local note = "Дата изменения: нужен js_ReaScriptAPI"
    ImGui.PushFont(ctx, font, 14)
    ImGui.SameLine(ctx, win_w - OX - text_w(note), 0)
    ImGui.TextColored(ctx, C.dim, note)
    ImGui.PopFont(ctx)
  end
  if source == "recent" then
    small_text("Галочка - выбрать · звезда - избранное · двойной клик или Enter - открыть · F2 - пометка · Esc - очистить поиск")
  else
    small_text("Звезда - избранное · двойной клик или Enter - открыть · F2 - пометка · Esc - очистить поиск · «Папки» - где искать проекты")
  end

  -- строка поиска: ввод идёт сюда всегда, пока не редактируется пометка и не нажата кнопка
  local clear_w = 34
  if not edit and not ImGui.IsAnyItemActive(ctx) then ImGui.SetKeyboardFocusHere(ctx) end
  ImGui.SetNextItemWidth(ctx, query ~= "" and (inner_w - clear_w - ITEM_GAP) or inner_w)
  local changed, text = ImGui.InputTextWithHint(ctx, "##search" .. search_gen,
    "Поиск по имени, пути и пометкам: начните печатать…", query)
  if changed and text ~= query then set_query(text) end
  if query ~= "" then
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "×##clear", clear_w, 0) then clear_query() end
  end

  -- ряд кнопок сортировки
  local specs = {}
  for _, sk in ipairs(SORT_KEYS) do
    local active = (sk.key == sort_key)
    local label = sk.label
    if sk.key == "order" and source == "library" then label = "Как найдено" end
    if active and (sk.key ~= "order" or sort_desc) then label = label .. (sort_desc and " ▼" or " ▲") end
    specs[#specs + 1] = { label = label, id = "sort_" .. sk.key, enabled = not (sk.key == "date" and not has_dates),
      color = active and C.accent or nil, key = sk.key }
  end
  local clicked = button_row(specs, inner_w, 34)
  for _, s in ipairs(specs) do if clicked == s.id then set_sort(s.key) end end

  -- второй ряд: источник списка, фильтры, массовая отметка (Недавние) или «Папки» (Все проекты)
  local left = {
    { id = "recent", w = 112, label = "Недавние", color = source == "recent" and C.accent or nil },
    { id = "library", w = 112, label = "Все проекты", color = source == "library" and C.accent or nil },
    { id = "missing", w = 190, label = "Только не найденные", color = f_missing and C.accent or nil },
    { id = "age", w = 210, enabled = has_dates, color = f_age > 1 and C.accent or nil,
      label = has_dates and ("Возраст: " .. AGE_STEPS[f_age][2]) or "Возраст: нужен js_ReaScriptAPI" },
  }
  local right
  if source == "recent" then
    right = { { id = "all", w = 120, label = "Отметить все", enabled = #view > 0 },
              { id = "none", w = 110, label = "Снять все" } }
  else
    right = { { id = "folders", w = 100, label = "Папки", color = show_settings and C.accent or nil } }
  end
  local sum = 0
  for _, b in ipairs(left) do sum = sum + b.w end
  for _, b in ipairs(right) do sum = sum + b.w end
  local gaps = (#left - 1 + #right - 1 + 1) * ITEM_GAP -- плюс зазор между левой и правой группами
  local k = math.max(0.5, math.min(1, (inner_w - gaps) / sum)) -- в узком окне кнопки ужимаются
  local x0 = ImGui.GetCursorPosX(ctx)
  local right_w = 0
  for _, b in ipairs(right) do right_w = right_w + b.w * k end
  right_w = right_w + ITEM_GAP * (#right - 1)
  local chip
  for i, b in ipairs(left) do
    if i > 1 then ImGui.SameLine(ctx) end
    if button(b.label, "chip_" .. b.id, b.w * k, 30, b.enabled, b.color) then chip = b.id end
  end
  for i, b in ipairs(right) do
    if i == 1 then ImGui.SameLine(ctx, x0 + inner_w - right_w, 0) else ImGui.SameLine(ctx) end
    if button(b.label, "chip_" .. b.id, b.w * k, 30, b.enabled, b.color) then chip = b.id end
  end
  if chip == "recent" or chip == "library" then set_source(chip)
  elseif chip == "missing" then f_missing = not f_missing; after_filter_change()
  elseif chip == "age" then f_age = f_age % #AGE_STEPS + 1; after_filter_change()
  elseif chip == "all" then
    for _, it in ipairs(view) do if not it.fav then it.checked = true end end -- избранные защищены
  elseif chip == "none" then
    for _, it in ipairs(items) do it.checked = false end
  elseif chip == "folders" then
    show_settings = not show_settings
    edit = nil
  end
end

----------------------------------------------------------------------
-- Окно: заголовки колонок с разделителями и список проектов
----------------------------------------------------------------------
local function draw_columns_header(win_w, L)
  ImGui.SetCursorPosX(ctx, 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, C.row_alt)
  local visible = ImGui.BeginChild(ctx, "##cols", win_w, COLS_H, ImGui.ChildFlags_None,
    ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse)
  ImGui.PopStyleColor(ctx)
  if not visible then return end
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.PushFont(ctx, font, F_SMALL)
  local ty = sy + (COLS_H - F_SMALL) / 2 - 1
  local x0 = sx + OX
  ImGui.DrawList_AddText(dl, x0 + L.name_x + 4, ty, C.dim, "Имя")
  ImGui.DrawList_AddText(dl, x0 + L.path_x + 4, ty, C.dim, "Путь")
  if has_dates then ImGui.DrawList_AddText(dl, x0 + L.date_x + 4, ty, C.dim, "Дата") end
  ImGui.DrawList_AddText(dl, x0 + L.right - 2 - text_w("Размер"), ty, C.dim, "Размер")
  ImGui.PopFont(ctx)
  ImGui.DrawList_AddLine(dl, sx, sy + COLS_H - 1, sx + win_w, sy + COLS_H - 1, C.border)

  -- разделители: тянутся мышью (запоминаются), двойной клик - стандартная ширина
  for _, dv in ipairs(dividers(L)) do
    ImGui.SetCursorScreenPos(ctx, x0 + dv.x - 4, sy)
    ImGui.InvisibleButton(ctx, "##div_" .. dv.kind, 9, COLS_H)
    local hot = ImGui.IsItemHovered(ctx) or (col_drag and col_drag.kind == dv.kind)
    if hot then ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW) end
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      reset_cols(); col_drag = nil
    elseif ImGui.IsItemActivated(ctx) then
      col_w.name, col_w.date, col_w.size = L.name_w, has_dates and L.date_w or col_w.date, L.size_w
      col_drag = { kind = dv.kind,
        start = { name = col_w.name, date = col_w.date, size = col_w.size, path = L.path_w } }
    elseif col_drag and col_drag.kind == dv.kind and ImGui.IsItemActive(ctx) then
      local dx = ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left, 0.0)
      apply_drag(col_drag.kind, col_drag.start, dx)
    elseif col_drag and col_drag.kind == dv.kind and ImGui.IsItemDeactivated(ctx) then
      col_drag = nil
      save_cols()
    end
    local x = x0 + dv.x
    ImGui.DrawList_AddLine(dl, x, sy + 4, x, sy + COLS_H - 4, hot and C.accent or C.border, hot and 3 or 1)
  end
  ImGui.Dummy(ctx, 0, 0) -- окно заканчивается виджетом: после SetCursorPos* нужен виджет, иначе ImGui ругается в EndChild
  ImGui.EndChild(ctx)
end

local function draw_row(i, it, L, row_w)
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x0 = sx + OX
  if i % 2 == 0 then ImGui.DrawList_AddRectFilled(dl, sx, sy, sx + row_w, sy + ROW_H, C.row_alt) end
  ImGui.SetNextItemAllowOverlap(ctx)
  local clicked = ImGui.Selectable(ctx, "##row" .. i, false, ImGui.SelectableFlags_AllowOverlap, 0, ROW_H)
  -- звёздочка: своя область поверх строки
  ImGui.SetCursorScreenPos(ctx, x0 + STAR_X - 2, sy)
  local star_clicked = ImGui.InvisibleButton(ctx, "##star" .. i, STAR_W + 4, ROW_H)

  if it == cursor then ImGui.DrawList_AddRect(dl, sx + 1, sy, sx + row_w - 1, sy + ROW_H, C.accent) end
  if source == "recent" then draw_check(dl, x0 + CB_X, sy + (ROW_H - CB) / 2, it.checked) end
  draw_star(dl, x0 + STAR_CX, sy + ROW_H / 2, 8, it.fav, it.fav and C.star or C.dim)

  local text_y = sy + (ROW_H - F_ROW) / 2 - 1
  ImGui.DrawList_AddText(dl, x0 + L.name_x + 4, text_y, it.exists and C.text or C.dim,
    clip_head(it.title, L.name_w - 12))
  ImGui.PushFont(ctx, font, F_SMALL)
  local small_y = sy + (ROW_H - F_SMALL) / 2
  local note_tag_w = 0
  if it.note ~= "" then -- пометка - у правого края колонки пути
    local shown = clip_head(it.note, math.min(220, L.path_w * 0.4))
    note_tag_w = text_w(shown) + 14
    ImGui.DrawList_AddText(dl, x0 + L.date_x - note_tag_w + 4, small_y, C.tag, shown)
  end
  if it.exists then
    if has_dates then ImGui.DrawList_AddText(dl, x0 + L.date_x + 4, small_y, C.dim, fmt_date(it.mtime)) end
    local sz = fmt_size(it.size)
    ImGui.DrawList_AddText(dl, x0 + L.right - 2 - text_w(sz), small_y, C.dim, sz)
  else
    local tag = "не найден"
    ImGui.DrawList_AddText(dl, x0 + L.right - 2 - text_w(tag), small_y, C.danger, tag)
  end
  ImGui.PopFont(ctx)
  ImGui.DrawList_AddText(dl, x0 + L.path_x + 4, text_y, C.dim, clip_tail(it.path, L.path_w - 12 - note_tag_w))
  return clicked, star_clicked
end

local function draw_list(win_w, L, h)
  ImGui.SetCursorPosX(ctx, 0)
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, C.bg)
  local visible = ImGui.BeginChild(ctx, "##list", win_w, h, ImGui.ChildFlags_None, ImGui.WindowFlags_None)
  ImGui.PopStyleColor(ctx)
  if not visible then return end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, 0, 0) -- строки стоят вплотную: шаг ровно ROW_H

  -- прокрутка: после смены списка - наверх, курсор с клавиатуры не должен уходить за край
  if scroll_reset then
    scroll_reset = false
    follow_cursor = false
    ImGui.SetScrollY(ctx, 0)
  elseif follow_cursor then
    follow_cursor = false
    local idx = index_of(cursor)
    if idx then
      local scroll = ImGui.GetScrollY(ctx)
      local top = (idx - 1) * ROW_H
      if top < scroll then ImGui.SetScrollY(ctx, top)
      elseif top + ROW_H > scroll + h then ImGui.SetScrollY(ctx, top + ROW_H - h) end
    end
  end

  local shift = (ImGui.GetKeyMods(ctx) & ImGui.Mod_Shift) ~= 0
  local open_now, fav_now
  ImGui.PushFont(ctx, font, F_ROW)
  ImGui.ListClipper_Begin(clipper, #view, ROW_H) -- рисуются только видимые строки: список может быть в тысячи проектов
  while ImGui.ListClipper_Step(clipper) do
    local first, last = ImGui.ListClipper_GetDisplayRange(clipper)
    for i = first + 1, last do
      local it = view[i]
      local clicked, star_clicked = draw_row(i, it, L, win_w)
      if star_clicked then fav_now = it
      elseif clicked and row_click(it, shift, reaper.time_precise()) then open_now = it end
    end
  end
  if #items == 0 then
    local msg
    if source == "recent" then msg = "Список Recent projects пуст."
    elseif #lib.dirs == 0 then msg = "Папки не заданы. Нажмите «Папки» и добавьте папку с проектами."
    elseif lib.scan then msg = "Идёт сканирование…"
    else msg = "Список пуст. Нажмите «Пересканировать»." end
    ImGui.SetCursorPos(ctx, OX, 18)
    ImGui.TextColored(ctx, C.dim, msg)
  elseif #view == 0 then
    ImGui.SetCursorPos(ctx, OX, 18)
    ImGui.TextColored(ctx, C.dim, "Ничего не найдено. Измените поиск или фильтры.")
  end
  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx)
  ImGui.Dummy(ctx, 0, 0) -- окно заканчивается виджетом: после SetCursorPos* нужен виджет, иначе ImGui ругается в EndChild
  ImGui.EndChild(ctx)
  if fav_now then toggle_fav(fav_now)
  elseif open_now then local it = open_now; defer_action(function() open_project(it) end) end
end

----------------------------------------------------------------------
-- Окно: панель проекта под курсором
----------------------------------------------------------------------
local function draw_info(win_w)
  if not begin_panel("##info", win_w, INFO_H, C.panel, OX, 6) then return end
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddLine(dl, sx - OX, sy - 6, sx - OX + win_w, sy - 6, C.border)
  local it = cursor
  local text_max = win_w - OX * 2 - BTN_W - 12 -- ширина текста панели проекта
  if not it then
    ImGui.SetCursorPosY(ctx, 12)
    small_text("Проект не выбран.")
  else
    local name = it.path:match("([^\\/]+)$") or it.path
    ImGui.SetCursorPosY(ctx, 8)
    ImGui.PushFont(ctx, font, F_ROW)
    ImGui.TextColored(ctx, it.exists and C.text or C.danger, clip_head(name, text_max))
    ImGui.PopFont(ctx)
    local line
    if not it.exists then
      line = "Файл не найден."
    else
      local inf = get_info(it)
      if not inf then line = "Читаю проект…"
      elseif inf.err then line = inf.err
      else line = info_text(inf) end
    end
    ImGui.SetCursorPosY(ctx, 33)
    ImGui.PushFont(ctx, font, F_SMALL)
    ImGui.TextColored(ctx, C.dim, clip_head(line, text_max))
    ImGui.SetCursorPosY(ctx, 54)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 8, 4)
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.TextColored(ctx, C.dim, "Пометка:")
    ImGui.SameLine(ctx, OX + NOTE_LABEL_W, 0)
    -- пометка: поле ввода; клик или F2 - редактировать, Enter - сохранить, Esc - отменить, клик мимо - сохранить
    local editing = edit and edit.it == it
    if edit and edit.focus then edit.focus = false; ImGui.SetKeyboardFocusHere(ctx) end
    ImGui.SetNextItemWidth(ctx, text_max - NOTE_LABEL_W)
    if not editing and it.note ~= "" then ImGui.PushStyleColor(ctx, ImGui.Col_Text, C.tag) end
    local changed, text = ImGui.InputTextWithHint(ctx, "##note" .. note_gen,
      "нет - клик или F2, чтобы добавить (Enter - сохранить)", editing and edit.buf or it.note)
    if not editing and it.note ~= "" then ImGui.PopStyleColor(ctx) end
    ImGui.PopStyleVar(ctx)
    if ImGui.IsItemActivated(ctx) and not edit then -- клик по полю: редактирование началось, фокус уже в нём
      start_edit()
      if edit then edit.focus = false end
    end
    if changed and editing then edit.buf = text end
    if edit and ImGui.IsItemDeactivated(ctx) then commit_edit(); note_gen = note_gen + 1 end
    ImGui.PopFont(ctx)

    -- кнопки справа
    local bx = win_w - OX - BTN_W
    ImGui.PushFont(ctx, font, F_SMALL)
    ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 10, 3)
    ImGui.SetCursorPos(ctx, bx, 6)
    local act_fav = button(it.fav and "Убрать из избранного" or "В избранное", "fav", BTN_W, 24)
    ImGui.SetCursorPos(ctx, bx, 33)
    local act_note = button("Пометка (F2)", "note", BTN_W, 24)
    ImGui.SetCursorPos(ctx, bx, 60)
    local act_reveal = button("Показать в папке", "reveal", BTN_W, 24, it.exists)
    ImGui.PopStyleVar(ctx)
    ImGui.PopFont(ctx)
    if act_fav then toggle_fav(it)
    elseif act_note then start_edit()
    elseif act_reveal then defer_action(function() reveal_in_folder(it) end) end
  end
  ImGui.Dummy(ctx, 0, 0) -- окно заканчивается виджетом: после SetCursorPos* нужен виджет, иначе ImGui ругается в EndChild
  ImGui.EndChild(ctx)
end

----------------------------------------------------------------------
-- Окно: «Папки» (закрывает список и панель проекта)
----------------------------------------------------------------------
local function draw_settings(win_w, h)
  if not begin_panel("##settings", win_w, h, C.bg, OX, 10) then return end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, ITEM_GAP, 6)
  ImGui.PushFont(ctx, font, F_TITLE)
  ImGui.Text(ctx, "Папки для поиска проектов")
  ImGui.PopFont(ctx)
  small_text("Проекты (.rpp) ищутся в этих папках и во всех вложенных. Файлы проектов не изменяются.")
  if #lib.dirs == 0 then
    ImGui.TextColored(ctx, C.dim, "Папок нет. Нажмите «Добавить папку…».")
  end
  local rm_dir
  for i, d in ipairs(lib.dirs) do
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, clip_tail(d, win_w - OX * 2 - 110))
    ImGui.SameLine(ctx, win_w - OX - 90, 0)
    if button("Убрать", "rmdir" .. i, 90, 26) then rm_dir = i end
  end
  ImGui.SetCursorPosY(ctx, h - 84)
  local opt
  local ch, v = ImGui.Checkbox(ctx, "Пропускать папки Backups (копии и автосохранения REAPER)", lib.skip_backups)
  if ch then opt = "skip_backups" end
  ch, v = ImGui.Checkbox(ctx, "Учитывать резервные копии .rpp-bak", lib.with_bak)
  if ch then opt = "with_bak" end
  ImGui.PopStyleVar(ctx)
  ImGui.Dummy(ctx, 0, 0) -- окно заканчивается виджетом: после SetCursorPos* нужен виджет, иначе ImGui ругается в EndChild
  ImGui.EndChild(ctx)
  if opt then
    lib[opt] = not lib[opt]
    lib.save_settings()
    status = "Настройка применится при следующем сканировании."
  elseif rm_dir then
    lib.remove_dir(rm_dir)
  end
end

----------------------------------------------------------------------
-- Окно: подвал со статусом и кнопками действий
----------------------------------------------------------------------
local function draw_footer(win_w)
  if not begin_panel("##foot", win_w, FOOT_H, C.panel, OX, 6) then return end
  local sx, sy = ImGui.GetCursorScreenPos(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddLine(dl, sx - OX, sy - 6, sx - OX + win_w, sy - 6, C.border)
  local inner_w = win_w - OX * 2
  local tab_w = 260

  -- статус слева, справа - галочка «Открывать в новой вкладке»
  ImGui.SetCursorPosY(ctx, 12)
  ImGui.PushFont(ctx, font, F_SMALL)
  ImGui.TextColored(ctx, C.dim, clip_tail(status, inner_w - (show_settings and 0 or tab_w + 12)))
  if not show_settings then
    ImGui.SameLine(ctx, win_w - OX - tab_w, 0)
    ImGui.SetCursorPosY(ctx, 6)
    local ch, v = ImGui.Checkbox(ctx, "Открывать в новой вкладке", open_new_tab)
    if ch then
      open_new_tab = v
      reaper.SetExtState(EXT_SECTION, "open_new_tab", open_new_tab and "1" or "0", true)
      status = open_new_tab and "Проекты открываются в новой вкладке."
        or "Проекты открываются в текущей вкладке: REAPER спросит о сохранении."
    end
  end
  ImGui.PopFont(ctx)

  ImGui.SetCursorPosY(ctx, FOOT_H - 6 - 46 - 6)
  local scan_label = lib.scan and "Остановить сканирование" or "Пересканировать"
  local scan_enabled = lib.scan ~= nil or #lib.dirs > 0
  local target -- что откроет кнопка «Открыть»
  local clicked
  if show_settings then
    clicked = button_row({
      { label = "Добавить папку…", id = "add", color = C.accent },
      { label = scan_label, id = "scan", enabled = scan_enabled },
      { label = "Назад к списку", id = "back" },
      { label = "Закрыть", id = "close" } }, inner_w, 46)
  elseif source == "library" then
    target = cursor
    clicked = button_row({
      { label = scan_label, id = "scan", enabled = scan_enabled },
      { label = "Открыть", id = "open", enabled = target ~= nil and target.exists, color = C.accent },
      { label = "Закрыть", id = "close" } }, inner_w, 46)
  else
    local n_missing, n_checked = count_missing_unprotected(), count_checked()
    -- «Открыть»: единственный отмеченный проект, а если отметок нет - проект под курсором
    if n_checked == 1 then
      for _, it in ipairs(view) do if it.checked then target = it end end
    elseif n_checked == 0 then
      target = cursor
    end
    local last_undo = undo_stack[#undo_stack]
    clicked = button_row({
      { label = string.format("Убрать пропавшие (%d)", n_missing), id = "auto", enabled = n_missing > 0 },
      { label = "Открыть", id = "open", enabled = target ~= nil and target.exists, color = C.accent },
      { label = string.format("Удалить выбранные (%d)", n_checked), id = "del", enabled = n_checked > 0, color = C.btn_danger },
      { label = last_undo and string.format("Вернуть удалённые (%d)", #last_undo.removed) or "Вернуть удалённые",
        id = "undo", enabled = last_undo ~= nil },
      { label = "Закрыть", id = "close" } }, inner_w, 46)
  end
  ImGui.Dummy(ctx, 0, 0) -- окно заканчивается виджетом: после SetCursorPos* нужен виджет, иначе ImGui ругается в EndChild
  ImGui.EndChild(ctx)

  if clicked == "add" then
    defer_action(function() lib.add_folder_dialog() end)
  elseif clicked == "scan" then
    if lib.scan then lib.stop_scan() else lib.start_scan() end
  elseif clicked == "back" then
    show_settings = false
  elseif clicked == "auto" then
    local doomed = {}
    for _, it in ipairs(view) do if not it.exists and not it.fav then doomed[it.path] = true end end
    defer_action(function() remove_where(function(path) return doomed[path] == true end) end)
  elseif clicked == "open" then
    local it = target
    defer_action(function() open_project(it) end)
  elseif clicked == "del" then
    local doomed, n_fav = {}, 0
    for _, it in ipairs(view) do
      if it.checked then doomed[it.path] = true; if it.fav then n_fav = n_fav + 1 end end
    end
    defer_action(function()
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
    end)
  elseif clicked == "undo" then
    defer_action(restore_last)
  elseif clicked == "close" then
    want_close = true
  end
end

----------------------------------------------------------------------
-- Окно: кадр
----------------------------------------------------------------------
local saved_w, saved_h = WIN_W, WIN_H
do
  local sw, sh = tonumber(reaper.GetExtState(EXT_SECTION, "win_w")), tonumber(reaper.GetExtState(EXT_SECTION, "win_h"))
  if sw and sh and sw >= MIN_W and sh >= MIN_H and sw <= 5000 and sh <= 4000 then saved_w, saved_h = sw, sh end
end

local function draw_window()
  local win_w, win_h = ImGui.GetWindowSize(ctx)
  -- размер окна запоминается между запусками
  if (win_w ~= saved_w or win_h ~= saved_h) and win_w >= MIN_W and win_h >= MIN_H then
    saved_w, saved_h = win_w, win_h
    reaper.SetExtState(EXT_SECTION, "win_w", tostring(math.floor(saved_w)), true)
    reaper.SetExtState(EXT_SECTION, "win_h", tostring(math.floor(saved_h)), true)
  end
  handle_keys()
  if lib.scan then lib.scan_step() end

  ImGui.Dummy(ctx, 0, 8)
  draw_top(win_w)

  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, ITEM_GAP, 0) -- панели стоят вплотную друг к другу
  local _, avail_h = ImGui.GetContentRegionAvail(ctx)
  if show_settings then
    draw_settings(win_w, math.max(60, avail_h - FOOT_H))
  else
    local L = layout(win_w - OX - RIGHT_PAD)
    list_h = math.max(60, avail_h - COLS_H - INFO_H - FOOT_H)
    draw_columns_header(win_w, L)
    draw_list(win_w, L, list_h)
    draw_info(win_w)
  end
  draw_footer(win_w)
  ImGui.PopStyleVar(ctx)
  ImGui.Dummy(ctx, 0, 0) -- см. выше: окно заканчивается виджетом
end

local THEME_COLORS = {
  { ImGui.Col_WindowBg, C.bg }, { ImGui.Col_ChildBg, C.bg }, { ImGui.Col_PopupBg, C.panel },
  { ImGui.Col_Text, C.text }, { ImGui.Col_TextDisabled, C.dim }, { ImGui.Col_Border, C.border },
  { ImGui.Col_FrameBg, C.bg }, { ImGui.Col_FrameBgHovered, C.panel }, { ImGui.Col_FrameBgActive, C.panel },
  { ImGui.Col_Button, C.btn }, { ImGui.Col_ButtonHovered, C.btn_hover }, { ImGui.Col_ButtonActive, C.accent },
  { ImGui.Col_Header, C.panel }, { ImGui.Col_HeaderHovered, C.panel }, { ImGui.Col_HeaderActive, C.btn_hover },
  { ImGui.Col_ScrollbarBg, C.bg }, { ImGui.Col_ScrollbarGrab, C.border },
  { ImGui.Col_ScrollbarGrabHovered, C.dim }, { ImGui.Col_ScrollbarGrabActive, C.accent },
  { ImGui.Col_TitleBg, C.panel }, { ImGui.Col_TitleBgActive, C.panel }, { ImGui.Col_CheckMark, C.accent },
  { ImGui.Col_TextSelectedBg, rgba(col.accent, 110) },
}

local WINDOW_FLAGS = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoScrollbar | ImGui.WindowFlags_NoScrollWithMouse

local function frame()
  for _, c in ipairs(THEME_COLORS) do ImGui.PushStyleColor(ctx, c[1], c[2]) end
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_WindowPadding, OX, 0)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ItemSpacing, ITEM_GAP, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FramePadding, 10, 6)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_FrameRounding, 3)
  ImGui.PushStyleVar(ctx, ImGui.StyleVar_ScrollbarSize, SB)
  ImGui.PushFont(ctx, font, F_ROW)
  ImGui.SetNextWindowSize(ctx, saved_w, saved_h, ImGui.Cond_FirstUseEver)
  ImGui.SetNextWindowSizeConstraints(ctx, MIN_W, MIN_H, 8000, 8000)
  local visible, open = ImGui.Begin(ctx, WINDOW_TITLE, true, WINDOW_FLAGS)
  if visible then
    draw_window()
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)
  ImGui.PopStyleVar(ctx, 5)
  ImGui.PopStyleColor(ctx, #THEME_COLORS)
  return open and not want_close
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
local ok, err = reload()
if not ok then
  reaper.ShowMessageBox(err, TITLE, 0)
  return
end

local function loop()
  -- модальные окна и открытие проектов - вне кадра ReaImGui
  local todo = later
  later = {}
  for _, fn in ipairs(todo) do fn() end
  if frame() then reaper.defer(loop) end
end
loop()
