-- @description SSM_Item_Edit_Transfer
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   Копирует нарезку и свойства с цепочки items на один item другой дорожки.
--   Выделите подряд идущие исходные куски на одной дорожке и один целевой item
--   на другой дорожке. Длительность цели может отличаться: границы нарезки
--   переносятся пропорционально. Если «Нарезка» выключена, свойства одного
--   исходного куска копируются на весь целевой item.
-- @changelog
--   1.0 Перенос нарезки, mute, громкости и фейдов с галочками

local r = reaper
local SCRIPT = "SSM_Item_Edit_Transfer"
local W, H = 430, 252
local checks = { true, true, true, true }
local labels = { "Нарезка", "Mute", "Громкость item", "Фейды" }
local message, ready = "", false
local source, target = {}, nil
local last_cap = 0

local function get(item, key)
  return r.GetMediaItemInfo_Value(item, key) or 0
end

local function get_selected()
  local groups, tracks, all = {}, {}, {}
  for i = 0, r.CountSelectedMediaItems(0) - 1 do
    local item = r.GetSelectedMediaItem(0, i)
    local tr = r.GetMediaItem_Track(item)
    tracks[tr] = true
    groups[tr] = groups[tr] or {}
    groups[tr][#groups[tr] + 1] = item
    all[#all + 1] = item
  end
  local trs = {}
  for tr in pairs(tracks) do trs[#trs + 1] = tr end
  if #trs ~= 2 then return nil, nil, "Выделите исходные куски и целевой item ровно на двух дорожках." end
  table.sort(trs, function(a, b) return #groups[a] > #groups[b] end)
  if #groups[trs[1]] < 2 or #groups[trs[2]] ~= 1 then
    return nil, nil, "На одной дорожке выделите 2+ исходных куска, на другой — один целевой item."
  end
  local src = groups[trs[1]]
  table.sort(src, function(a, b) return get(a, "D_POSITION") < get(b, "D_POSITION") end)
  for i = 2, #src do
    local prev_end = get(src[i - 1], "D_POSITION") + get(src[i - 1], "D_LENGTH")
    if math.abs(get(src[i], "D_POSITION") - prev_end) > 0.001 then
      return nil, nil, "Исходные куски должны идти подряд без промежутков."
    end
  end
  local src_len = get(src[#src], "D_POSITION") + get(src[#src], "D_LENGTH") - get(src[1], "D_POSITION")
  local dst = groups[trs[2]][1]
  if src_len <= 0 or get(dst, "D_LENGTH") <= 0 then return nil, nil, "Не удалось определить длительность items." end
  return src, dst, string.format("Источник: %d кусков, цель: %.3f с. Нарезка переносится пропорционально.", #src, get(dst, "D_LENGTH"))
end

local function capture(src)
  local out = {}
  for _, item in ipairs(src) do
    local d = { mute = get(item, "B_MUTE"), vol = get(item, "D_VOL") }
    for _, k in ipairs({ "D_FADEINLEN", "D_FADEOUTLEN", "D_FADEINLEN_AUTO", "D_FADEOUTLEN_AUTO",
                         "C_FADEINSHAPE", "C_FADEOUTSHAPE" }) do d[k] = get(item, k) end
    d.length = get(item, "D_LENGTH")
    out[#out + 1] = d
  end
  return out
end

local function put(item, key, value)
  r.SetMediaItemInfo_Value(item, key, value)
end

local function transfer()
  local src, dst, err = get_selected()
  if not src then r.ShowMessageBox(err, "SSM: Перенос правок", 0); return end
  local data = capture(src)
  local dst_pos, dst_len = get(dst, "D_POSITION"), get(dst, "D_LENGTH")
  local segments, fade_scale = {}, 1
  r.Undo_BeginBlock2(0)
  r.PreventUIRefresh(1)
  local ok, why = pcall(function()
    if checks[1] then
      local src_total = 0
      for _, d in ipairs(data) do src_total = src_total + d.length end
      local scale, cut = dst_len / src_total, dst_pos
      fade_scale = scale
      segments[1] = dst
      for i = 1, #data - 1 do
        cut = cut + data[i].length * scale
        local right = r.SplitMediaItem(segments[#segments], cut)
        if not right then error("REAPER не смог разрезать целевой item.") end
        segments[#segments + 1] = right
      end
    else
      segments[1] = dst
      data = { data[1] }
    end
    for i, item in ipairs(segments) do
      local d = data[checks[1] and i or 1]
      if checks[2] then put(item, "B_MUTE", d.mute) end
      if checks[3] then put(item, "D_VOL", d.vol) end
      if checks[4] then
        put(item, "D_FADEINLEN", math.min(d.D_FADEINLEN * fade_scale, get(item, "D_LENGTH")))
        put(item, "D_FADEOUTLEN", math.min(d.D_FADEOUTLEN * fade_scale, get(item, "D_LENGTH")))
        put(item, "D_FADEINLEN_AUTO", d.D_FADEINLEN_AUTO)
        put(item, "D_FADEOUTLEN_AUTO", d.D_FADEOUTLEN_AUTO)
        put(item, "C_FADEINSHAPE", d.C_FADEINSHAPE)
        put(item, "C_FADEOUTSHAPE", d.C_FADEOUTSHAPE)
      end
    end
  end)
  r.PreventUIRefresh(-1)
  if not ok then
    r.Undo_EndBlock2(0, "SSM: Перенос правок между items (ошибка)", -1)
    r.Undo_DoUndo2(0)
    r.ShowMessageBox(tostring(why), "SSM: Перенос не выполнен", 0)
  else
    r.UpdateArrange()
    r.Undo_EndBlock2(0, "SSM: Перенос правок между items", -1)
    r.ShowMessageBox("Готово. Изменения можно отменить одной командой Undo.", "SSM: Перенос правок", 0)
  end
end

local function refresh()
  source, target, message = get_selected()
  ready = source ~= nil
end

local function draw()
  gfx.set(0.10, 0.11, 0.14, 1); gfx.rect(0, 0, W, H, 1)
  gfx.set(0.92, 0.93, 0.96, 1); gfx.setfont(1, "Arial", 18); gfx.x, gfx.y = 20, 16; gfx.drawstr("Перенос правок между items")
  gfx.setfont(1, "Arial", 15)
  for i, text in ipairs(labels) do
    local y = 58 + (i - 1) * 30
    gfx.set(0.2, 0.55, 0.92, 1); gfx.rect(22, y, 18, 18, 1)
    if checks[i] then
      gfx.set(1, 1, 1, 1); gfx.line(25, y + 9, 30, y + 14); gfx.line(30, y + 14, 38, y + 4)
    end
    gfx.set(0.92, 0.93, 0.96, 1); gfx.x, gfx.y = 50, y - 1; gfx.drawstr(text)
  end
  gfx.setfont(1, "Arial", 13)
  gfx.set(ready and 0.45 or 0.95, ready and 0.85 or 0.58, ready and 0.55 or 0.3, 1)
  gfx.x, gfx.y = 22, 184; gfx.drawstr(message)
  local hot = gfx.mouse_x >= 20 and gfx.mouse_x <= 205 and gfx.mouse_y >= 211 and gfx.mouse_y <= 240
  gfx.set(hot and 0.20 or 0.14, hot and 0.62 or 0.48, hot and 0.36 or 0.28, 1); gfx.rect(20, 211, 185, 30, 1)
  gfx.set(1, 1, 1, 1); gfx.x, gfx.y = 36, 218; gfx.drawstr("Перенести")
  gfx.set(0.25, 0.27, 0.32, 1); gfx.rect(215, 211, 190, 30, 1)
  gfx.set(0.9, 0.9, 0.92, 1); gfx.x, gfx.y = 232, 218; gfx.drawstr("Обновить выделение")
  gfx.setfont(1, "Arial", 12); gfx.set(0.62, 0.65, 0.7, 1); gfx.x, gfx.y = 20, 246
  gfx.drawstr("Источник — куски на одной дорожке; цель — один item на другой.")
  gfx.update()
  local cap = gfx.mouse_cap
  if cap & 1 == 1 and last_cap & 1 == 0 then
    local x, y = gfx.mouse_x, gfx.mouse_y
    if x >= 20 and x <= 205 and y >= 211 and y <= 241 then transfer()
    elseif x >= 215 and x <= 405 and y >= 211 and y <= 241 then refresh()
    else
      for i = 1, 4 do local cy = 58 + (i - 1) * 30; if x >= 15 and x <= 250 and y >= cy - 3 and y <= cy + 21 then checks[i] = not checks[i] end end
    end
  end
  last_cap = cap
  if gfx.getchar() >= 0 then r.defer(draw) else gfx.quit() end
end

refresh()
gfx.init("SSM: Перенос правок", W, H, 0)
draw()
