-- @description SSM_Item_Search
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🔍 Удобный поиск медиа-items по имени тейка (то самое поле "Take name"
--   в Media Item Properties).
--   Открывает панель, где можно ввести текст поиска, увидеть список всех
--   совпадений (трек + имя тейка + позиция) и быстро перейти к нужному
--   item — по клику в списке или кнопками "Пред / След". Найденные items
--   выделяются на таймлайне, при переходе трек с item подскролливается
--   в видимую область.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   + Релиз

-- ============================================================
-- STATE
-- ============================================================
local EXT_SECTION = "SSM_ItemSearch"

local query = ""
local scope_selected_only = false
local matches = {}
local match_idx = 0
local scroll_offset = 0

local win_x = tonumber(reaper.GetExtState(EXT_SECTION, "win_x")) or 300
local win_y = tonumber(reaper.GetExtState(EXT_SECTION, "win_y")) or 200
local WIN_W_DEFAULT, WIN_H_DEFAULT = 460, 560

local last_mouse_cap = 0
local dragging = false
local drag_off_x, drag_off_y = 0, 0

local ROW_H = 24
local HEADER_H = 48

-- ============================================================
-- COLORS (в стиле остальных SSM-скриптов)
-- ============================================================
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
  row_hov   = {0.20, 0.22, 0.27},
  row_cur   = {0.14, 0.28, 0.22},
}

-- ============================================================
-- HELPERS
-- ============================================================
local function set_color(c, a)
  gfx.r, gfx.g, gfx.b = c[1], c[2], c[3]
  gfx.a = a or 1
end

local function draw_round_rect(x, y, w, h, c, a, r)
  r = r or 8
  set_color(c, a)
  if r <= 0 then
    gfx.rect(x, y, w, h, 1)
    return
  end
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

local function clip_text(str, max_w)
  gfx.setfont(1, "Arial", 14)
  if gfx.measurestr(str) <= max_w then return str end
  local out = str
  while #out > 1 and gfx.measurestr(out .. "…") > max_w do
    out = out:sub(1, -2)
  end
  return out .. "…"
end

-- ============================================================
-- SEARCH LOGIC
-- ============================================================
local function do_search()
  matches = {}
  scroll_offset = 0
  match_idx = 0

  local q = query:lower()
  if q == "" then return end

  local n = reaper.CountMediaItems(0)
  for i = 0, n - 1 do
    local item = reaper.GetMediaItem(0, i)
    local track = reaper.GetMediaItemTrack(item)

    if (not scope_selected_only) or reaper.IsTrackSelected(track) then
      local take = reaper.GetActiveTake(item)
      local name = take and reaper.GetTakeName(take) or ""

      if name ~= "" and name:lower():find(q, 1, true) then
        local _, tname = reaper.GetTrackName(track)
        matches[#matches + 1] = {
          item       = item,
          pos        = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
          name       = name,
          track_name = tname or "",
        }
      end
    end
  end

  table.sort(matches, function(a, b) return a.pos < b.pos end)
  if #matches > 0 then match_idx = 1 end
end

local function ensure_visible(idx, visible_rows)
  if idx <= scroll_offset then
    scroll_offset = math.max(0, idx - 1)
  elseif idx > scroll_offset + visible_rows then
    scroll_offset = idx - visible_rows
  end
end

local function focus_item(idx, visible_rows)
  if idx < 1 or idx > #matches then return end
  match_idx = idx
  local m = matches[idx]

  reaper.PreventUIRefresh(1)
  reaper.Main_OnCommand(40289, 0) -- Item: Unselect all items
  reaper.SetMediaItemSelected(m.item, true)

  local track = reaper.GetMediaItemTrack(m.item)
  if track then
    reaper.SetOnlyTrackSelected(track)
    reaper.Main_OnCommand(40913, 0) -- Track: Vertical scroll selected tracks into view
  end

  reaper.SetEditCurPos(m.pos, true, false)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)

  if visible_rows then ensure_visible(idx, visible_rows) end
end

local function select_all_matches()
  if #matches == 0 then return end
  reaper.PreventUIRefresh(1)
  reaper.Main_OnCommand(40289, 0)
  for _, m in ipairs(matches) do
    reaper.SetMediaItemSelected(m.item, true)
  end
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
end

local function edit_query()
  local retval, newq = reaper.GetUserInputs("Поиск items", 1, "Текст поиска (имя тейка):,extrawidth=220", query)
  if retval then
    query = newq or ""
    do_search()
    if #matches > 0 then focus_item(1) end
  end
end

-- ============================================================
-- DRAW
-- ============================================================
local function draw_button(x, y, w, h, label, enabled, color)
  local hov = enabled and mouse_in(x, y, w, h)
  local c = color or (hov and col.btn_hover or col.btn)
  if not enabled then c = col.panel end
  draw_round_rect(x, y, w, h, c, 1, 6)
  set_color(col.border); gfx.rect(x, y, w, h, 0)

  gfx.setfont(1, "Arial", 14)
  local tw = gfx.measurestr(label)
  draw_text(label, x + (w - tw) / 2, y + (h - 14) / 2, enabled and col.text or col.text_dim)

  return enabled and hov
end

local function draw_window()
  local w, h = gfx.w, gfx.h

  local left_down = (gfx.mouse_cap & 1) == 1
  local left_click = left_down and (last_mouse_cap & 1) == 0
  local left_release = not left_down and (last_mouse_cap & 1) == 1
  local wheel = gfx.mouse_wheel
  gfx.mouse_wheel = 0

  -- background
  draw_round_rect(0, 0, w, h, col.bg, 1, 0)

  -- header (draggable)
  local in_header = gfx.mouse_y >= 0 and gfx.mouse_y <= HEADER_H
  if left_click and in_header and not mouse_in(w - 34, 10, 24, 24) then
    dragging = true
    local sx, sy = reaper.GetMousePosition()
    local _, wx, wy = gfx.dock(-1, 0, 0, 0, 0)
    wx = wx or win_x
    wy = wy or win_y
    drag_off_x = sx - wx
    drag_off_y = sy - wy
  end
  if left_release and dragging then
    local _, x, y = gfx.dock(-1, 0, 0, 0, 0)
    if x then
      win_x, win_y = x, y
      reaper.SetExtState(EXT_SECTION, "win_x", tostring(math.floor(win_x)), true)
      reaper.SetExtState(EXT_SECTION, "win_y", tostring(math.floor(win_y)), true)
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
  draw_text("🔍 Поиск items по имени тейка", 18, 14, col.text)

  -- close (X)
  local close_hov = mouse_in(w - 34, 10, 24, 24)
  draw_round_rect(w - 34, 10, 24, 24, close_hov and col.btn_hover or col.panel, 1, 6)
  gfx.setfont(1, "Arial", 15)
  draw_text("✕", w - 34 + 7, 12, col.text)
  if close_hov and left_click then
    return "close"
  end

  if dragging then
    last_mouse_cap = gfx.mouse_cap
    return nil
  end

  -- search box
  local left = 18
  local box_y = HEADER_H + 14
  local box_h = 32
  local edit_btn_w = 40
  local box_w = w - left * 2 - edit_btn_w - 8

  local box_hov = mouse_in(left, box_y, box_w, box_h)
  draw_round_rect(left, box_y, box_w, box_h, box_hov and col.accent or col.input_bg, 1, 6)
  set_color(col.border); gfx.rect(left, box_y, box_w, box_h, 0)

  gfx.setfont(1, "Arial", 15)
  local shown = query == "" and "нажмите, чтобы ввести текст поиска…" or query
  local shown_col = query == "" and col.text_dim or col.text
  draw_text(clip_text(shown, box_w - 16), left + 10, box_y + 8, shown_col)

  if box_hov and left_click then
    edit_query()
  end

  local edit_x = left + box_w + 8
  if draw_button(edit_x, box_y, edit_btn_w, box_h, "✎", true) and left_click then
    edit_query()
  end

  -- scope checkbox
  local cb_y = box_y + box_h + 14
  local cb_x = left
  local checked = scope_selected_only
  draw_round_rect(cb_x, cb_y, 18, 18, checked and col.accent or col.input_bg, 1, 4)
  set_color(col.border); gfx.rect(cb_x, cb_y, 18, 18, 0)
  if checked then
    gfx.setfont(1, "Arial", 13)
    draw_text("✓", cb_x + 3, cb_y - 1, col.text)
  end
  gfx.setfont(1, "Arial", 14)
  draw_text("Только на выбранных треках", cb_x + 26, cb_y + 1, col.text)
  if mouse_in(cb_x, cb_y, 250, 20) and left_click then
    scope_selected_only = not scope_selected_only
    do_search()
  end

  -- info + refresh row
  local info_y = cb_y + 30
  gfx.setfont(1, "Arial", 13)
  local info_str = (query == "") and "Введите текст для поиска" or ("Найдено: " .. #matches)
  draw_text(info_str, left, info_y + 6, col.text_dim)

  local refresh_w = 110
  if draw_button(w - left - refresh_w, info_y, refresh_w, 26, "↻ Обновить", true) and left_click then
    do_search()
  end

  -- nav buttons row
  local nav_y = info_y + 36
  local nav_h = 30
  local gap = 8
  local nav_w = (w - left * 2 - gap * 2) / 3

  local has_matches = #matches > 0
  local list_h_probe = math.max(0, h - (nav_y + nav_h + 44) - 60)
  local visible_rows_probe = math.max(1, math.floor(list_h_probe / ROW_H))

  if draw_button(left, nav_y, nav_w, nav_h, "◀ Пред", has_matches) and left_click and has_matches then
    local idx = match_idx - 1
    if idx < 1 then idx = #matches end
    focus_item(idx, visible_rows_probe)
  end
  if draw_button(left + nav_w + gap, nav_y, nav_w, nav_h, "След ▶", has_matches) and left_click and has_matches then
    local idx = match_idx + 1
    if idx > #matches then idx = 1 end
    focus_item(idx, visible_rows_probe)
  end
  if draw_button(left + (nav_w + gap) * 2, nav_y, nav_w, nav_h, "Выбрать все", has_matches) and left_click and has_matches then
    select_all_matches()
  end

  -- list
  local list_y = nav_y + nav_h + 12
  local list_bottom_margin = 56
  local list_h = math.max(0, h - list_y - list_bottom_margin)
  local list_w = w - left * 2

  draw_round_rect(left, list_y, list_w, list_h, col.input_bg, 1, 6)
  set_color(col.border); gfx.rect(left, list_y, list_w, list_h, 0)

  local visible_rows = math.max(1, math.floor(list_h / ROW_H))
  local max_offset = math.max(0, #matches - visible_rows)

  if mouse_in(left, list_y, list_w, list_h) and wheel ~= 0 then
    scroll_offset = scroll_offset - math.floor(wheel / 40)
  end
  scroll_offset = math.max(0, math.min(max_offset, scroll_offset))

  if #matches == 0 then
    gfx.setfont(1, "Arial", 13)
    local msg = (query == "") and "Список пуст. Введите текст поиска выше." or "Совпадений не найдено."
    draw_text(msg, left + 12, list_y + 10, col.text_dim)
  else
    for row = 0, visible_rows - 1 do
      local i = scroll_offset + row + 1
      local m = matches[i]
      if not m then break end

      local ry = list_y + row * ROW_H
      local row_hov = mouse_in(left, ry, list_w, ROW_H)
      local is_current = (i == match_idx)

      if is_current then
        draw_round_rect(left + 2, ry + 1, list_w - 4, ROW_H - 2, col.row_cur, 1, 4)
      elseif row_hov then
        draw_round_rect(left + 2, ry + 1, list_w - 4, ROW_H - 2, col.row_hov, 1, 4)
      end

      gfx.setfont(1, "Arial", 13)
      local time_str = reaper.format_timestr_pos(m.pos, "", -1)
      local time_w = gfx.measurestr(time_str)

      local track_col = is_current and col.accent2 or col.text_dim
      local name_col = is_current and col.text or col.text

      local track_label = clip_text(m.track_name ~= "" and m.track_name or "(без имени)", 110)
      draw_text(track_label, left + 10, ry + 5, track_col)
      draw_text(clip_text(m.name, list_w - 150 - time_w), left + 130, ry + 5, name_col)
      draw_text(time_str, left + list_w - time_w - 10, ry + 5, col.text_dim)

      if row_hov and left_click then
        focus_item(i, visible_rows)
      end
    end
  end

  -- close button (bottom)
  local btn_w, btn_h = 160, 34
  local bx = (w - btn_w) / 2
  local by = h - 46
  if draw_button(bx, by, btn_w, btn_h, "Закрыть", true, col.btn_start) and left_click then
    last_mouse_cap = gfx.mouse_cap
    return "close"
  end

  last_mouse_cap = gfx.mouse_cap
  return nil
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function main_loop()
  local char = gfx.getchar()
  if char == 27 or char < 0 then
    reaper.SetExtState(EXT_SECTION, "win_x", tostring(math.floor(win_x)), true)
    reaper.SetExtState(EXT_SECTION, "win_y", tostring(math.floor(win_y)), true)
    gfx.quit()
    return
  end

  local action = draw_window()
  gfx.update()

  if action == "close" then
    reaper.SetExtState(EXT_SECTION, "win_x", tostring(math.floor(win_x)), true)
    reaper.SetExtState(EXT_SECTION, "win_y", tostring(math.floor(win_y)), true)
    gfx.quit()
    return
  end

  reaper.defer(main_loop)
end

-- ============================================================
-- ENTRY
-- ============================================================
gfx.init("SSM Item Search", WIN_W_DEFAULT, WIN_H_DEFAULT, 0, math.floor(win_x), math.floor(win_y))
gfx.setfont(1, "Arial", 14)
reaper.defer(main_loop)
