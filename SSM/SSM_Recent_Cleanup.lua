-- @description SSM_Recent_Cleanup
-- @version 1.1
-- @author @ssm_metalmix
-- @about
--   🧹 Чистка списка Recent projects. В окне виден весь список:
--     - кнопка «Убрать несуществующие» - автоматически удаляет проекты,
--       файлов которых нет на диске (удалены, перемещены, отключён диск);
--     - галочками можно отметить любые ненужные проекты (в том числе
--       существующие) и нажать «Удалить выбранные».
--   Файлы проектов не трогаются - убираются только записи из списка.
--   Перед первым изменением делается резервная копия reaper.ini
--   (reaper.ini.ssm_bak). Список в меню REAPER обновится после перезапуска.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
-- @changelog
--   1.0 Релиз: автоматическое удаление несуществующих проектов.
--   1.1 Окно со списком: ручной выбор ненужных проектов галочками.

local TITLE = "SSM Recent Cleanup"
local WIN_W, WIN_H = 720, 560
local HEAD_H, FOOT_H, ROW_H = 64, 108, 28

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
local items = {}
local scroll = 0
local status = ""
local backup_done = false
local last_cap = 0

local function reload()
  local st, err = load_ini()
  if not st then return false, err end
  items = {}
  for _, r in ipairs(st.recents) do
    items[#items + 1] = {
      path = r.path,
      exists = r.path ~= "" and reaper.file_exists(r.path),
      checked = false,
    }
  end
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
  gfx.setfont(1, "Arial", 15)
  local tw = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - 15) / 2 - 1, enabled and col.text or col.dim)
  return hov and click
end

local function draw_checkbox(x, y, checked)
  set_color(checked and col.accent or col.bg); gfx.rect(x, y, 18, 18, 1)
  set_color(col.border); gfx.rect(x, y, 18, 18, 0)
  if checked then
    gfx.setfont(1, "Arial", 15)
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
  gfx.setfont(1, "Arial", 15)
  local text_right = w - 24
  for i, it in ipairs(items) do
    local ry = list_y + (i - 1) * ROW_H - scroll
    if ry + ROW_H > list_y and ry < list_y + list_h then
      if i % 2 == 0 then set_color(col.row_alt); gfx.rect(0, ry, w, ROW_H, 1) end

      local in_list = gfx.mouse_y >= list_y and gfx.mouse_y < list_y + list_h
      if in_list and mouse_in(0, ry, w - 14, ROW_H) then
        set_color(col.panel); gfx.rect(0, ry, w, ROW_H, 1)
        if click then it.checked = not it.checked end
      end

      draw_checkbox(16, ry + 5, it.checked)

      local tag_w = 0
      if not it.exists then
        local tag = "файл не найден"
        gfx.setfont(1, "Arial", 13)
        tag_w = gfx.measurestr(tag) + 12
        draw_text(tag, text_right - tag_w + 12, ry + 7, col.danger)
        gfx.setfont(1, "Arial", 15)
      end
      local avail = text_right - 46 - tag_w
      draw_text(clip_tail(it.path, avail), 46, ry + 5, it.exists and col.text or col.dim)
    end
  end

  if #items == 0 then
    draw_text("Список Recent projects пуст.", 16, list_y + 16, col.dim)
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
  gfx.setfont(1, "Arial", 17)
  draw_text(string.format("Недавние проекты: %d  (не найдено: %d)", #items, count_missing()), 16, 10, col.text)
  gfx.setfont(1, "Arial", 13)
  draw_text("Отметьте галочками ненужные проекты и нажмите «Удалить выбранные». Файлы на диске не удаляются.",
    16, 38, col.dim)

  -- подвал
  local foot_y = h - FOOT_H
  set_color(col.panel); gfx.rect(0, foot_y, w, FOOT_H, 1)
  set_color(col.border); gfx.rect(0, foot_y, w, 1, 1)

  gfx.setfont(1, "Arial", 13)
  draw_text(clip_tail(status, w - 32), 16, foot_y + 12, col.dim)

  local n_missing, n_checked = count_missing(), count_checked()
  local bh, by, gap = 40, foot_y + 50, 10
  local bw = (w - 32 - gap * 2) / 3
  local act_auto = draw_button(16, by, bw, bh,
    string.format("Убрать несуществующие (%d)", n_missing), n_missing > 0, click)
  local act_del = draw_button(16 + bw + gap, by, bw, bh,
    string.format("Удалить выбранные (%d)", n_checked), n_checked > 0, click, col.btn_danger)
  local act_close = draw_button(16 + (bw + gap) * 2, by, bw, bh, "Закрыть", true, click)

  if act_auto then
    remove_where(function(path) return path == "" or not reaper.file_exists(path) end)
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
