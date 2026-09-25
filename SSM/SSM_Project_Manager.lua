-- @description SSM_Project_Manager
-- @version 2.0
-- @author @ssm_metalmix
-- @about
--   🗂 Менеджер недавних проектов (Recent projects): открытие, сортировка и
--   чистка списка. В окне виден весь список:
--     - кнопка «Убрать несуществующие» - автоматически удаляет проекты,
--       файлов которых нет на диске (удалены, перемещены, отключён диск);
--     - галочками можно отметить любые ненужные проекты (в том числе
--       существующие) и нажать «Удалить выбранные».
--   Сверху ряд кнопок сортировки списка: как в REAPER, по имени файла, по
--   папке, по дате изменения, по размеру, «не найденные» - первым нажатием
--   сортировка по возрастанию (для даты и размера - по убыванию), повторным
--   меняется направление. Дата изменения доступна при установленном
--   расширении js_ReaScriptAPI; выбранная сортировка запоминается.
--   Кнопка «Открыть выбранный» открывает отмеченный галочкой проект в новой
--   вкладке REAPER (когда отмечен ровно один существующий проект).
--   Файлы проектов не трогаются - убираются только записи из списка.
--   Перед первым изменением делается резервная копия reaper.ini
--   (reaper.ini.ssm_bak). Список в меню REAPER обновится после перезапуска.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
-- @changelog
--   2.0 Скрипт переименован: SSM_Recent_Cleanup -> SSM_Project_Manager (новый
--   пакет в ReaPack, старый SSM_Recent_Cleanup больше не обновляется).
--   Сохранённая сортировка подхватывается из старого скрипта.
--   1.0 Релиз: автоматическое удаление несуществующих проектов.
--   1.3 Крупнее шрифт и элементы окна. Кнопка «Открыть выбранный» в нижнем
--   ряду - открывает отмеченный проект в новой вкладке.
--   1.2 Ряд кнопок сортировки списка (как в REAPER / имя / папка / дата /
--   размер / не найденные), в строках показываются дата и размер файла.
--   1.1 Окно со списком: ручной выбор ненужных проектов галочками.

local TITLE = "SSM Project Manager"
local WIN_W, WIN_H = 860, 660
local HEAD_H, FOOT_H, ROW_H = 112, 116, 34
local EXT_SECTION = "SSM_ProjectManager"
local OLD_EXT_SECTION = "SSM_RecentCleanup" -- настройки прежнего названия скрипта
local SIZE_W, DATE_W = 84, 108
local F_ROW, F_TITLE, F_SMALL, F_BTN, F_SORT = 17, 20, 15, 17, 16
local CB = 20 -- сторона чекбокса

local ini_path = reaper.get_ini_file()

local col = {
  bg = { 0.13, 0.14, 0.16 }, panel = { 0.17, 0.18, 0.21 }, row_alt = { 0.15, 0.16, 0.19 },
  text = { 0.92, 0.93, 0.95 }, dim = { 0.62, 0.65, 0.70 }, accent = { 0.30, 0.55, 0.95 },
  border = { 0.36, 0.38, 0.44 }, danger = { 0.95, 0.42, 0.42 },
  btn = { 0.24, 0.26, 0.31 }, btn_hover = { 0.31, 0.34, 0.40 }, btn_off = { 0.18, 0.19, 0.22 },
  btn_danger = { 0.62, 0.24, 0.24 },
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
local backup_done = false
local last_cap = 0

----------------------------------------------------------------------
-- Сортировка списка (только отображение - порядок в reaper.ini не меняется)
----------------------------------------------------------------------
local SORT_KEYS = {
  { key = "order",   label = "Как в REAPER", default_desc = false },
  { key = "name",    label = "Имя",          default_desc = false },
  { key = "folder",  label = "Папка",        default_desc = false },
  { key = "date",    label = "Дата",         default_desc = true },  -- сначала новые
  { key = "size",    label = "Размер",       default_desc = true },  -- сначала большие
  { key = "missing", label = "Не найденные", default_desc = false }, -- сначала пропавшие
}

local sort_key, sort_desc = "order", false
do
  local section = EXT_SECTION
  if reaper.GetExtState(section, "sort_key") == "" then section = OLD_EXT_SECTION end
  local k = reaper.GetExtState(section, "sort_key")
  for _, sk in ipairs(SORT_KEYS) do if sk.key == k then sort_key = k end end
  sort_desc = reaper.GetExtState(section, "sort_desc") == "1"
end

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

local function fmt_date(mtime)
  if not mtime then return "" end
  return (mtime:sub(1, 10):gsub("%.", "-"))
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
local scroll = 0

local function apply_sort()
  table.sort(items, compare_items)
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

local function reload()
  local st, err = load_ini()
  if not st then return false, err end
  items = {}
  has_dates = false
  for _, r in ipairs(st.recents) do
    local path = r.path
    local exists = path ~= "" and reaper.file_exists(path)
    local name = path:match("([^\\/]+)$") or path
    local dir = path:sub(1, #path - #name)
    local size, mtime
    if exists then size, mtime = file_info(path) end
    if mtime then has_dates = true end
    items[#items + 1] = {
      path = path, exists = exists, checked = false, ord = #items + 1,
      name_l = fold(name), dir_l = fold(dir), size = size, mtime = mtime,
    }
  end
  apply_sort()
  return true
end

local function count_missing()
  local n = 0
  for _, it in ipairs(items) do if not it.exists then n = n + 1 end end
  return n
end

local function count_checked()
  local n = 0
  for _, it in ipairs(items) do if it.checked then n = n + 1 end end
  return n
end

-- Перечитывает reaper.ini заново перед записью (чтобы не затереть то, что
-- REAPER мог изменить с момента открытия окна) и убирает записи по предикату.
local function remove_where(pred)
  local st, err = load_ini()
  if not st then status = err; return end

  local keep, removed = {}, 0
  for _, r in ipairs(st.recents) do
    if pred(r.path) then removed = removed + 1 else keep[#keep + 1] = r.path end
  end
  if removed == 0 then status = "Нечего удалять."; return end

  if not backup_done then
    local bak = io.open(ini_path .. ".ssm_bak", "wb")
    if not bak then status = "Не удалось создать резервную копию reaper.ini - ничего не изменено."; return end
    bak:write(st.data)
    bak:close()
    backup_done = true
  end

  if not write_ini(st, keep) then status = "Не удалось записать reaper.ini - ничего не изменено."; return end

  reload()
  status = string.format("Удалено из списка: %d. Осталось: %d. Меню REAPER обновится после перезапуска.",
    removed, #items)
end

-- Открывает проект в НОВОЙ вкладке (действие 40859), чтобы не трогать текущий
-- проект; "noprompt:" - без вопроса о сохранении пустой вкладки.
local function open_project(it)
  reaper.Main_OnCommand(40859, 0)
  reaper.Main_openProject("noprompt:" .. it.path)
  status = "Открыт в новой вкладке: " .. (it.path:match("([^\\/]+)$") or it.path)
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

local function draw_button(x, y, w, h, label, enabled, click, color)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = (not enabled) and col.btn_off or (hov and col.btn_hover or (color or col.btn))
  set_color(c); gfx.rect(x, y, w, h, 1)
  set_color(col.border); gfx.rect(x, y, w, h, 0)
  local size = F_BTN
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
  local down = (gfx.mouse_cap & 1) == 1
  local click = down and (last_cap & 1) == 0
  last_cap = gfx.mouse_cap

  set_color(col.bg); gfx.rect(0, 0, w, h, 1)

  local list_y = HEAD_H
  local list_h = math.max(60, h - HEAD_H - FOOT_H)
  local total_h = #items * ROW_H
  local max_scroll = math.max(0, total_h - list_h)

  if gfx.mouse_wheel ~= 0 then
    scroll = scroll - (gfx.mouse_wheel / 120) * ROW_H * 3
    gfx.mouse_wheel = 0
  end
  scroll = math.max(0, math.min(scroll, max_scroll))

  -- строки списка (шапка и подвал перекрывают выступающие части)
  gfx.setfont(1, "Arial", F_ROW)
  local text_right = w - 26
  for i, it in ipairs(items) do
    local ry = list_y + (i - 1) * ROW_H - scroll
    if ry + ROW_H > list_y and ry < list_y + list_h then
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(0, ry, w, ROW_H, 1) end

      local in_list = gfx.mouse_y >= list_y and gfx.mouse_y < list_y + list_h
      if in_list and mouse_in(0, ry, w - 14, ROW_H) then
        set_color(col.panel); gfx.rect(0, ry, w, ROW_H, 1)
        if click then it.checked = not it.checked end
      end

      draw_checkbox(16, ry + (ROW_H - CB) / 2, it.checked)

      local small_y = ry + (ROW_H - F_SMALL) / 2
      local tag_w = 0
      if not it.exists then
        local tag = "файл не найден"
        gfx.setfont(1, "Arial", F_SMALL)
        tag_w = gfx.measurestr(tag) + 12
        draw_text(tag, text_right - tag_w + 12, small_y, col.danger)
        gfx.setfont(1, "Arial", F_ROW)
      end
      local right_w = tag_w
      if it.exists then
        right_w = SIZE_W + (has_dates and DATE_W or 0) + 6
        gfx.setfont(1, "Arial", F_SMALL)
        local sz = fmt_size(it.size)
        draw_text(sz, text_right - gfx.measurestr(sz), small_y, col.dim)
        if has_dates then
          local dt = fmt_date(it.mtime)
          draw_text(dt, text_right - SIZE_W - gfx.measurestr(dt), small_y, col.dim)
        end
        gfx.setfont(1, "Arial", F_ROW)
      end
      local avail = text_right - 50 - right_w
      draw_text(clip_tail(it.path, avail), 50, ry + (ROW_H - F_ROW) / 2 - 1, it.exists and col.text or col.dim)
    end
  end

  if #items == 0 then
    draw_text("Список Recent projects пуст.", 16, list_y + 18, col.dim)
  end

  -- полоса прокрутки
  if max_scroll > 0 then
    local thumb_h = math.max(24, list_h * list_h / total_h)
    local thumb_y = list_y + (list_h - thumb_h) * (scroll / max_scroll)
    set_color(col.border); gfx.rect(w - 10, thumb_y, 6, thumb_h, 1)
  end

  -- шапка
  set_color(col.panel); gfx.rect(0, 0, w, HEAD_H, 1)
  set_color(col.border); gfx.rect(0, HEAD_H - 1, w, 1, 1)
  gfx.setfont(1, "Arial", F_TITLE)
  draw_text(string.format("Недавние проекты: %d  (не найдено: %d)", #items, count_missing()), 16, 9, col.text)
  gfx.setfont(1, "Arial", F_SMALL)
  draw_text("Отметьте галочкой проект: откройте его или удалите из списка. Файлы на диске не удаляются.",
    16, 40, col.dim)
  if not has_js_stat then
    gfx.setfont(1, "Arial", 14)
    local note = "Дата изменения: нужен js_ReaScriptAPI"
    draw_text(note, w - 16 - gfx.measurestr(note), 12, col.dim)
  end

  -- ряд кнопок сортировки
  do
    local n, gap = #SORT_KEYS, 6
    local bw2 = (w - 32 - gap * (n - 1)) / n
    local bh2, by2 = 34, HEAD_H - 34 - 8
    local clicked_key
    for i, sk in ipairs(SORT_KEYS) do
      local active = (sk.key == sort_key)
      local enabled = not (sk.key == "date" and not has_dates)
      local label = sk.label
      if active and (sk.key ~= "order" or sort_desc) then label = label .. (sort_desc and " ▼" or " ▲") end
      local x = 16 + (i - 1) * (bw2 + gap)
      local hov = enabled and mouse_in(x, by2, bw2, bh2)
      local c = (not enabled) and col.btn_off or (active and col.accent or (hov and col.btn_hover or col.btn))
      set_color(c); gfx.rect(x, by2, bw2, bh2, 1)
      set_color(col.border); gfx.rect(x, by2, bw2, bh2, 0)
      local size = F_SORT
      gfx.setfont(1, "Arial", size)
      while size > 11 and gfx.measurestr(label) > bw2 - 8 do
        size = size - 1
        gfx.setfont(1, "Arial", size)
      end
      draw_text(label, x + (bw2 - gfx.measurestr(label)) / 2, by2 + (bh2 - size) / 2 - 1,
        enabled and col.text or col.dim)
      if hov and click then clicked_key = sk.key end
    end
    if clicked_key then set_sort(clicked_key) end
  end

  -- подвал
  local foot_y = h - FOOT_H
  set_color(col.panel); gfx.rect(0, foot_y, w, FOOT_H, 1)
  set_color(col.border); gfx.rect(0, foot_y, w, 1, 1)

  gfx.setfont(1, "Arial", F_SMALL)
  draw_text(clip_tail(status, w - 32), 16, foot_y + 13, col.dim)

  local n_missing, n_checked = count_missing(), count_checked()
  local only_checked
  if n_checked == 1 then
    for _, it in ipairs(items) do if it.checked then only_checked = it end end
  end
  local can_open = only_checked ~= nil and only_checked.exists
  local bh, by, gap = 46, foot_y + 52, 10
  local bw = (w - 32 - gap * 3) / 4
  local act_auto = draw_button(16, by, bw, bh,
    string.format("Убрать несуществующие (%d)", n_missing), n_missing > 0, click)
  local act_open = draw_button(16 + (bw + gap), by, bw, bh, "Открыть выбранный", can_open, click, col.accent)
  local act_del = draw_button(16 + (bw + gap) * 2, by, bw, bh,
    string.format("Удалить выбранные (%d)", n_checked), n_checked > 0, click, col.btn_danger)
  local act_close = draw_button(16 + (bw + gap) * 3, by, bw, bh, "Закрыть", true, click)

  if act_auto then
    remove_where(function(path) return path == "" or not reaper.file_exists(path) end)
  elseif act_open then
    open_project(only_checked)
  elseif act_del then
    local doomed = {}
    for _, it in ipairs(items) do if it.checked then doomed[it.path] = true end end
    remove_where(function(path) return doomed[path] == true end)
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
gfx.init(TITLE, WIN_W, WIN_H)

local function loop()
  local ch = gfx.getchar()
  if ch == 27 or ch < 0 then gfx.quit(); return end
  if draw() == "close" then gfx.quit(); return end
  gfx.update()
  reaper.defer(loop)
end
loop()
