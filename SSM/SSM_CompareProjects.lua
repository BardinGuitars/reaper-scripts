-- @description SSM_CompareProjects
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🔎 Сравнение открытых проектов REAPER (нужно минимум два, во вкладках).
--   Собирает отличия по роутингу (папки, send'ы), фейдерам (громкость и пан) и
--   плагинам (наличие и значения параметров, включая содержимое контейнеров
--   первого уровня) и открывает удобный HTML-отчёт project_diff.html
--   (фильтры по треку и плагину, сворачивание секций, копирование отличий).
--   Отчёт сохраняется в папку ресурсов REAPER. Проект не изменяется.
--   Треки сравниваются по имени, мастер-трек не учитывается.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   + Релиз

local r = reaper

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function get_all_projects()
  local projects = {}
  local i = 0
  while true do
    local proj, path = r.EnumProjects(i)
    if not proj then break end
    local name
    if path and path ~= "" then
      name = path:match("([^\\/]+)%.[Rr][Pp]+$") or path:match("([^\\/]+)$") or ("Project " .. (i + 1))
    else
      name = "Unsaved " .. (i + 1)
    end
    projects[#projects + 1] = { proj = proj, name = name, path = path or "" }
    i = i + 1
  end
  return projects
end

local function vol_to_db(vol)
  if vol <= 0 then return -150 end
  return 20 * math.log(vol, 10)
end

local function pan_to_str(pan)
  if math.abs(pan) < 0.001 then return "0"
  elseif pan < 0 then return string.format("L%.0f", -pan * 100)
  else return string.format("R%.0f", pan * 100)
  end
end

local function format_num(n, decimals)
  decimals = decimals or 2
  if type(n) ~= "number" then return tostring(n) end
  local s = string.format("%." .. decimals .. "f", n)
  return (s:gsub("%.?0+$", ""))
end

-- Имена треков/плагинов/параметров попадают прямо в HTML и в JS-строки -
-- без экранирования "Bass & Gtr" или имя с кавычкой ломают отчёт.
local function esc(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
  return s
end

local function js_esc(s)
  s = tostring(s or "")
  s = s:gsub("\\", "\\\\"):gsub("'", "\\'"):gsub("\r?\n", " "):gsub("</", "<\\/")
  return s
end

local function smart_value(param_name, formatted)
  if not formatted or formatted == "" then return "" end
  local lower = formatted:lower()
  local pname = (param_name or ""):lower()
  if pname:find("used") or pname:find("enable") or pname:find("active") then
    if lower == "used" or lower == "on" or lower == "yes" or lower == "enabled" then
      return "add"
    elseif lower == "unused" or lower == "off" or lower == "no" or lower == "disabled" then
      return ""
    end
  end
  if lower == "on" and (pname:find("tilt") or pname:find("side") or pname:find("sc ")) then
    return "add"
  elseif lower == "off" and (pname:find("tilt") or pname:find("side") or pname:find("sc ")) then
    return ""
  end
  return formatted
end

-- Короткое имя плагина
local function short_fx_name(full)
  if not full or full == "" then return full end
  local name = full
  -- убираем префиксы
  name = name:gsub("^VST3:%s*", "")
  name = name:gsub("^VST:%s*", "")
  name = name:gsub("^JS:%s*", "")
  name = name:gsub("^AU:%s*", "")
  name = name:gsub("^CLAP:%s*", "")
  -- убираем производителя в скобках в конце
  name = name:gsub("%s*%([^%)]+%)%s*$", "")
  -- убираем лишние пробелы
  name = name:gsub("%s+", " "):match("^%s*(.-)%s*$")
  return name
end

-- Нормализация имени контейнера
local function nice_container_name(name)
  if not name or name == "" then return "Container" end
  local trimmed = name:match("^%s*(.-)%s*$")
  -- если короткое / число / начинается с минуса — делаем понятнее
  if #trimmed <= 4 or trimmed:match("^%-?%d+$") or trimmed:match("^%-?%d+%-?%d*$") then
    return 'Container "' .. trimmed .. '"'
  end
  return trimmed
end

----------------------------------------------------------------
-- Collect FX parameters
----------------------------------------------------------------
local function collect_fx_params(tr, fx_idx)
  local params = {}
  local num_params = r.TrackFX_GetNumParams(tr, fx_idx)
  for p = 0, num_params - 1 do
    local _, pname = r.TrackFX_GetParamName(tr, fx_idx, p, "")
    if pname and pname ~= "" then
      local pl = pname:lower()
      if pl ~= "wet" and pl ~= "bypass" and pl ~= "delta" then
        local val = r.TrackFX_GetParam(tr, fx_idx, p)
        local _, formatted = r.TrackFX_GetFormattedParamValue(tr, fx_idx, p, "")
        params[pname] = {
          raw = val,
          formatted = (formatted ~= "" and formatted) or format_num(val, 4),
        }
      end
    end
  end
  return params
end

----------------------------------------------------------------
-- Collect project data
----------------------------------------------------------------
local function collect_project_data(proj)
  local data = { tracks = {}, track_order = {} }
  local num_tracks = r.CountTracks(proj)
  local name_count = {}

  for i = 0, num_tracks - 1 do
    local tr = r.GetTrack(proj, i)
    local _, name = r.GetTrackName(tr)
    name = name or ("Track " .. (i + 1))
    -- треки с одинаковыми именами раньше затирали друг друга (ключ - имя)
    name_count[name] = (name_count[name] or 0) + 1
    if name_count[name] > 1 then name = name .. " (" .. name_count[name] .. ")" end

    local folder_depth = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
    local vol = r.GetMediaTrackInfo_Value(tr, "D_VOL")
    local pan = r.GetMediaTrackInfo_Value(tr, "D_PAN")
    local ok, ui_vol, ui_pan = r.GetTrackUIVolPan(tr)
    if ok then vol, pan = ui_vol, ui_pan end

    local sends = {}
    local num_sends = r.GetTrackNumSends(tr, 0)
    for s = 0, num_sends - 1 do
      local dest = r.GetTrackSendInfo_Value(tr, 0, s, "P_DESTTRACK")
      local dest_name = "?"
      if dest then
        local _, dn = r.GetTrackName(dest)
        dest_name = dn or "?"
      end
      sends[#sends + 1] = {
        dest = dest_name,
        vol  = r.GetTrackSendInfo_Value(tr, 0, s, "D_VOL"),
        pan  = r.GetTrackSendInfo_Value(tr, 0, s, "D_PAN"),
        mode = r.GetTrackSendInfo_Value(tr, 0, s, "I_SENDMODE"),
        mute = r.GetTrackSendInfo_Value(tr, 0, s, "B_MUTE"),
      }
    end

    local fx_list = {}
    local fx_count = r.TrackFX_GetCount(tr)

    for f = 0, fx_count - 1 do
      local _, fx_name = r.TrackFX_GetFXName(tr, f, "")
      local params = collect_fx_params(tr, f)
      local short = short_fx_name(fx_name)

      fx_list[#fx_list + 1] = {
        name = fx_name,          -- полное (для сравнения)
        short_name = short,      -- короткое (для отображения)
        full_name = fx_name,     -- для title
        params = params,
        is_container_child = false,
      }

      -- Container (один уровень)
      local ok_cc, cc_str = r.TrackFX_GetNamedConfigParm(tr, f, "container_count")
      if ok_cc then
        local child_count = tonumber(cc_str) or 0
        if child_count > 0 then
          local cont_nice = nice_container_name(fx_name)
          for c = 0, child_count - 1 do
            local ok_item, child_id_str = r.TrackFX_GetNamedConfigParm(tr, f, "container_item." .. c)
            if ok_item then
              local child_fx = tonumber(child_id_str)
              if child_fx then
                local _, child_name = r.TrackFX_GetFXName(tr, child_fx, "")
                local child_params = collect_fx_params(tr, child_fx)
                local child_short = short_fx_name(child_name or "")

                local display_name = cont_nice .. " → " .. child_short
                local full_path = cont_nice .. " → " .. (child_name or ("FX " .. (c + 1)))

                fx_list[#fx_list + 1] = {
                  name = full_path,               -- для сравнения (уникальный ключ)
                  short_name = display_name,      -- для отображения
                  full_name = full_path,
                  params = child_params,
                  is_container_child = true,
                }
              end
            end
          end
        end
      end
    end

    data.tracks[name] = {
      name = name,
      folder_depth = folder_depth,
      vol = vol,
      pan = pan,
      sends = sends,
      fx = fx_list,
    }
    data.track_order[#data.track_order + 1] = name
  end
  return data
end

----------------------------------------------------------------
-- Compare
----------------------------------------------------------------
local function compare_projects(all_data)
  local rows = {}
  local n = #all_data

  local all_track_names, seen = {}, {}
  for _, pdata in ipairs(all_data) do
    for _, name in ipairs(pdata.track_order) do
      if not seen[name] then
        seen[name] = true
        all_track_names[#all_track_names + 1] = name
      end
    end
  end

  local function add_diff(section, track, param, values, extra)
    local first = tostring(values[1] or "")
    for i = 2, n do
      if tostring(values[i] or "") ~= first then
        local row = {
          section = section,
          track = track or "",
          param = param or "",
          values = values,
        }
        if extra then
          for k, v in pairs(extra) do row[k] = v end
        end
        rows[#rows + 1] = row
        return
      end
    end
  end

  -- ROUTING
  for _, tname in ipairs(all_track_names) do
    local present, depths = {}, {}
    for pi, pdata in ipairs(all_data) do
      local tr = pdata.tracks[tname]
      present[pi] = tr and "yes" or "MISSING"
      depths[pi]  = tr and tostring(tr.folder_depth) or ""
    end
    add_diff("ROUTING", tname, "exists", present)
    add_diff("ROUTING", tname, "folder_depth", depths)
  end

  for _, tname in ipairs(all_track_names) do
    local send_dests, seen_dest = {}, {}
    for _, pdata in ipairs(all_data) do
      local tr = pdata.tracks[tname]
      if tr then
        for _, s in ipairs(tr.sends) do
          if not seen_dest[s.dest] then
            seen_dest[s.dest] = true
            send_dests[#send_dests + 1] = s.dest
          end
        end
      end
    end
    for _, dest in ipairs(send_dests) do
      local vols, pans, modes, mutes = {}, {}, {}, {}
      for pi, pdata in ipairs(all_data) do
        local tr = pdata.tracks[tname]
        local found
        if tr then
          for _, s in ipairs(tr.sends) do
            if s.dest == dest then found = s break end
          end
        end
        if found then
          vols[pi]  = format_num(vol_to_db(found.vol), 1) .. " dB"
          pans[pi]  = pan_to_str(found.pan)
          modes[pi] = tostring(found.mode)
          mutes[pi] = found.mute > 0 and "muted" or "on"
        else
          vols[pi], pans[pi], modes[pi], mutes[pi] = "no send", "", "", ""
        end
      end
      add_diff("ROUTING", tname, "send → " .. dest .. " (vol)", vols)
      add_diff("ROUTING", tname, "send → " .. dest .. " (pan)", pans)
      add_diff("ROUTING", tname, "send → " .. dest .. " (mode)", modes)
      add_diff("ROUTING", tname, "send → " .. dest .. " (mute)", mutes)
    end
  end

  -- FADERS
  for _, tname in ipairs(all_track_names) do
    local vols, pans = {}, {}
    for pi, pdata in ipairs(all_data) do
      local tr = pdata.tracks[tname]
      vols[pi] = tr and format_num(vol_to_db(tr.vol), 1) or ""
      pans[pi] = tr and pan_to_str(tr.pan) or ""
    end
    add_diff("FADERS", tname, "volume", vols)
    add_diff("FADERS", tname, "pan", pans)
  end

  -- PLUGINS
  for _, tname in ipairs(all_track_names) do
    local fx_names, seen_fx = {}, {}
    local fx_meta = {} -- name → {short_name, full_name}

    for _, pdata in ipairs(all_data) do
      local tr = pdata.tracks[tname]
      if tr then
        for _, fx in ipairs(tr.fx) do
          if not seen_fx[fx.name] then
            seen_fx[fx.name] = true
            fx_names[#fx_names + 1] = fx.name
            fx_meta[fx.name] = {
              short_name = fx.short_name or short_fx_name(fx.name),
              full_name = fx.full_name or fx.name,
            }
          end
        end
      end
    end

    for _, fxname in ipairs(fx_names) do
      local fx_objs = {}
      local present_count = 0

      for pi, pdata in ipairs(all_data) do
        local tr = pdata.tracks[tname]
        local found
        if tr then
          for _, fx in ipairs(tr.fx) do
            if fx.name == fxname then found = fx break end
          end
        end
        fx_objs[pi] = found
        if found then present_count = present_count + 1 end
      end

      local meta = fx_meta[fxname] or { short_name = short_fx_name(fxname), full_name = fxname }

      if present_count < n then
        local add_vals = {}
        for pi = 1, n do
          add_vals[pi] = fx_objs[pi] and "add" or ""
        end
        rows[#rows + 1] = {
          section = "PLUGINS",
          track = tname,
          param = fxname .. " (presence)",
          values = add_vals,
          is_presence = true,
          short_name = meta.short_name,
          full_name = meta.full_name,
        }
      end

      if present_count >= 1 then
        local all_param_names, seen_p = {}, {}
        for pi = 1, n do
          if fx_objs[pi] then
            for pname, _ in pairs(fx_objs[pi].params) do
              if not seen_p[pname] then
                seen_p[pname] = true
                all_param_names[#all_param_names + 1] = pname
              end
            end
          end
        end

        for _, pname in ipairs(all_param_names) do
          local vals = {}
          local non_empty = {}
          for pi = 1, n do
            if fx_objs[pi] and fx_objs[pi].params[pname] then
              local v = smart_value(pname, fx_objs[pi].params[pname].formatted)
              vals[pi] = v
              if v ~= "" then non_empty[#non_empty + 1] = v end
            else
              vals[pi] = ""
            end
          end

          local real_diff = false
          if #non_empty >= 2 then
            local first = non_empty[1]
            for i = 2, #non_empty do
              if non_empty[i] ~= first then
                real_diff = true
                break
              end
            end
          end

          if real_diff then
            rows[#rows + 1] = {
              section = "PLUGINS",
              track = tname,
              param = fxname .. " | " .. pname,
              values = vals,
              is_presence = false,
              short_name = meta.short_name,
              full_name = meta.full_name,
              param_only = pname,
            }
          end
        end
      end
    end
  end

  return rows, all_track_names
end

----------------------------------------------------------------
-- Write HTML (полностью переработанный)
----------------------------------------------------------------
local function write_html(filename, project_names, rows, all_track_names)
  local f = io.open(filename, "w")
  if not f then return false end

  -- Подсчёт статистики
  local stats = { ROUTING = 0, FADERS = 0, PLUGINS = 0, presence = 0 }
  local tracks_with_diff = {}
  for _, row in ipairs(rows) do
    stats[row.section] = (stats[row.section] or 0) + 1
    if row.is_presence then stats.presence = stats.presence + 1 end
    tracks_with_diff[row.track] = true
  end
  local track_list = {}
  for t, _ in pairs(tracks_with_diff) do
    track_list[#track_list + 1] = t
  end
  table.sort(track_list)

  local html = [[
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>REAPER Projects Comparison</title>
<style>
  :root {
    --blue-dark: #1F4E79;
    --blue: #2E75B6;
    --yellow: #FFF2CC;
    --green: #E2EFDA;
    --blue-light: #DDEBF7;
    --border: #B0B0B0;
  }
  * { box-sizing: border-box; }
  body {
    font-family: Calibri, 'Segoe UI', Arial, sans-serif;
    margin: 0;
    padding: 16px 20px 40px;
    background: #f7f9fc;
    color: #222;
  }
  .toolbar {
    position: sticky;
    top: 0;
    z-index: 100;
    background: white;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 12px 16px;
    margin-bottom: 16px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    align-items: center;
  }
  .toolbar input[type="text"] {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    min-width: 180px;
    font-size: 13px;
  }
  .toolbar select {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
  }
  .toolbar button {
    padding: 6px 14px;
    border: 1px solid var(--blue);
    background: var(--blue);
    color: white;
    border-radius: 4px;
    cursor: pointer;
    font-size: 13px;
  }
  .toolbar button:hover { background: var(--blue-dark); }
  .toolbar button.secondary {
    background: white;
    color: var(--blue);
  }
  .toolbar button.secondary:hover { background: #f0f4f8; }
  .toolbar label {
    font-size: 13px;
    display: flex;
    align-items: center;
    gap: 6px;
    cursor: pointer;
  }

  .summary {
    background: white;
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 14px 18px;
    margin-bottom: 16px;
    font-size: 14px;
  }
  .summary h2 {
    margin: 0 0 8px 0;
    font-size: 16px;
    color: var(--blue-dark);
  }
  .summary-stats {
    display: flex;
    flex-wrap: wrap;
    gap: 18px;
    margin-bottom: 6px;
  }
  .summary-stats span { font-weight: 600; }
  .summary-tracks {
    color: #555;
    font-size: 13px;
  }

  .section-header {
    background: var(--blue);
    color: white;
    font-weight: bold;
    font-size: 15px;
    padding: 8px 14px;
    margin-top: 18px;
    border-radius: 6px 6px 0 0;
    cursor: pointer;
    user-select: none;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }
  .section-header:hover { background: var(--blue-dark); }
  .section-header .toggle { font-size: 12px; opacity: 0.85; }

  .section-body { display: block; }
  .section-body.collapsed { display: none; }

  table {
    border-collapse: collapse;
    width: 100%;
    font-size: 13px;
    background: white;
    border: 1px solid var(--border);
    border-top: none;
  }
  thead th {
    background: var(--blue-dark);
    color: white;
    font-weight: bold;
    padding: 7px 10px;
    text-align: center;
    border: 1px solid #163a5f;
    position: sticky;
    top: 60px; /* под toolbar */
    z-index: 50;
  }
  td {
    padding: 4px 8px;
    border: 1px solid var(--border);
    text-align: center;
    white-space: nowrap;
  }
  tr:nth-child(even) { background: #fafbfc; }
  tr:hover { background: #eef3f9 !important; }

  .track-group {
    background: #e8eef5 !important;
    font-weight: bold;
    text-align: left !important;
    color: var(--blue-dark);
    font-size: 13px;
  }
  .track-group td { padding: 6px 10px; }

  .routing { background-color: var(--yellow); }
  .faders  { background-color: var(--green); }
  .plugins { background-color: var(--blue-light); }

  .track { font-weight: 600; text-align: left; min-width: 90px; }
  .param { text-align: left; min-width: 140px; }
  .plugin {
    font-style: italic;
    color: #444;
    text-align: left;
    font-size: 12.5px;
    max-width: 280px;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .plugin:hover { color: #111; }

  .missing { color: #c00; font-weight: bold; }
  .add { color: #060; font-weight: bold; }

  .presence-row { opacity: 0.92; }
  .hidden-by-filter { display: none !important; }
  .hidden-presence { display: none !important; }

  .footer {
    margin-top: 28px;
    padding-top: 14px;
    border-top: 2px solid var(--blue-dark);
    text-align: center;
    font-size: 13px;
    color: #555;
  }
  .footer-links {
    display: inline-flex;
    gap: 24px;
    flex-wrap: wrap;
    justify-content: center;
  }
  .footer-links a {
    color: var(--blue-dark);
    text-decoration: none;
    font-weight: 500;
  }
  .footer-links a:hover { text-decoration: underline; }
  .footer-copy { margin-top: 6px; font-size: 12px; color: #888; }

  @media print {
    .toolbar { display: none; }
    body { background: white; }
    thead th { position: static; }
  }
</style>
</head>
<body>

<div class="toolbar">
  <input type="text" id="filterTrack" placeholder="Фильтр по треку...">
  <input type="text" id="filterPlugin" placeholder="Фильтр по плагину...">
  <label><input type="checkbox" id="hidePresence"> Скрыть presence</label>
  <button onclick="copyDiffs()">Копировать отличия</button>
  <button class="secondary" onclick="expandAll()">Развернуть всё</button>
  <button class="secondary" onclick="collapseAll()">Свернуть всё</button>
</div>

<div class="summary">
  <h2>Сводка сравнения</h2>
  <div class="summary-stats">
    <div>Всего отличий: <span id="totalDiffs">]] .. #rows .. [[</span></div>
    <div>Routing: <span>]] .. stats.ROUTING .. [[</span></div>
    <div>Faders: <span>]] .. stats.FADERS .. [[</span></div>
    <div>Plugins: <span>]] .. stats.PLUGINS .. [[</span> (из них presence: ]] .. stats.presence .. [[)</div>
  </div>
  <div class="summary-tracks">Треки с отличиями: ]] .. (#track_list > 0 and esc(table.concat(track_list, ", ")) or "—") .. [[</div>
</div>
]]

  f:write(html)

  -- Группируем строки по секциям и трекам
  local sections_order = { "ROUTING", "FADERS", "PLUGINS" }
  local by_section = { ROUTING = {}, FADERS = {}, PLUGINS = {} }
  for _, row in ipairs(rows) do
    by_section[row.section] = by_section[row.section] or {}
    table.insert(by_section[row.section], row)
  end

  for _, sec in ipairs(sections_order) do
    local sec_rows = by_section[sec] or {}
    if #sec_rows > 0 then
      f:write('<div class="section-header" onclick="toggleSection(this)">\n')
      f:write('  <span>' .. sec .. ' <small>(' .. #sec_rows .. ')</small></span>\n')
      f:write('  <span class="toggle">▼ свернуть</span>\n')
      f:write('</div>\n')
      f:write('<div class="section-body" data-section="' .. sec .. '">\n')
      f:write('<table>\n<thead><tr>\n')
      f:write('<th style="min-width:200px">Плагин / </th>\n')
      f:write('<th style="width:20px"></th>\n')
      f:write('<th>Трек</th>\n')
      f:write('<th>Параметр</th>\n')
      for _, pname in ipairs(project_names) do
        f:write('<th>' .. esc(pname) .. '</th>\n')
      end
      f:write('</tr></thead>\n<tbody>\n')

      local last_track = ""
      for _, row in ipairs(sec_rows) do
        if row.track ~= last_track then
          f:write('<tr class="track-group"><td colspan="' .. (4 + #project_names) .. '">▶ ' .. esc(row.track) .. '</td></tr>\n')
          last_track = row.track
        end

        local is_presence = row.is_presence or false
        local classes = {}
        if is_presence then classes[#classes+1] = "presence-row" end
        local row_class = table.concat(classes, " ")

        f:write('<tr class="' .. row_class .. '" data-track="' .. esc(row.track:lower()) .. '" data-plugin="' .. esc((row.short_name or ""):lower()) .. '">\n')

        -- Колонка плагина
        if sec == "PLUGINS" then
          local display = row.short_name or row.param
          local title = row.full_name or ""
          f:write('<td class="plugin" title="' .. esc(title) .. '">' .. esc(display) .. '</td>\n')
        else
          f:write('<td></td>\n')
        end

        f:write('<td></td>\n')
        f:write('<td class="track">' .. esc(row.track) .. '</td>\n')

        local param_display = row.param_only or row.param
        if is_presence then
          param_display = "presence / add-remove"
        elseif row.param:find(" | ") then
          param_display = row.param:match(" | (.*)") or row.param
        end
        f:write('<td class="param">' .. esc(param_display) .. '</td>\n')

        local cell_class = sec:lower()
        for _, val in ipairs(row.values) do
          local display = esc(val)
          if val == "" then
            display = "&nbsp;"
          elseif val == "MISSING" then
            display = '<span class="missing">MISSING</span>'
          elseif val == "add" then
            display = '<span class="add">add</span>'
          end
          f:write('<td class="' .. cell_class .. '">' .. display .. '</td>\n')
        end
        f:write('</tr>\n')
      end

      f:write('</tbody></table>\n</div>\n')
    end
  end

  -- Footer + JS
  f:write([[
<div class="footer">
  <div class="footer-links">
    <a href="https://t.me/bardinssm" target="_blank">📱 Telegram Channel</a>
    <a href="https://t.me/ssm_metalmix" target="_blank">💬 Telegram</a>
    <a href="https://boosty.to/boostbg" target="_blank">☕ Boosty</a>
    <a href="https://vk.ru/ssm_metalmix" target="_blank">🌐 VK</a>
  </div>
  <div class="footer-copy">
    Generated: ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[ | Projects: ]] .. #project_names .. [[ | Differences: ]] .. #rows .. [[
  </div>
</div>

<script>
function toggleSection(header) {
  const body = header.nextElementSibling;
  const toggle = header.querySelector('.toggle');
  if (body.classList.contains('collapsed')) {
    body.classList.remove('collapsed');
    toggle.textContent = '▼ свернуть';
  } else {
    body.classList.add('collapsed');
    toggle.textContent = '▶ развернуть';
  }
}
function expandAll() {
  document.querySelectorAll('.section-body').forEach(b => b.classList.remove('collapsed'));
  document.querySelectorAll('.section-header .toggle').forEach(t => t.textContent = '▼ свернуть');
}
function collapseAll() {
  document.querySelectorAll('.section-body').forEach(b => b.classList.add('collapsed'));
  document.querySelectorAll('.section-header .toggle').forEach(t => t.textContent = '▶ развернуть');
}

function applyFilters() {
  const trackQ = document.getElementById('filterTrack').value.toLowerCase().trim();
  const pluginQ = document.getElementById('filterPlugin').value.toLowerCase().trim();
  const hidePres = document.getElementById('hidePresence').checked;

  document.querySelectorAll('tbody tr').forEach(tr => {
    if (tr.classList.contains('track-group')) {
      // группы треков оставляем видимыми, если есть видимые дочерние
      return;
    }
    const track = tr.dataset.track || '';
    const plugin = tr.dataset.plugin || '';
    let show = true;
    if (trackQ && !track.includes(trackQ)) show = false;
    if (pluginQ && !plugin.includes(pluginQ)) show = false;
    if (hidePres && tr.classList.contains('presence-row')) show = false;

    tr.classList.toggle('hidden-by-filter', !show);
  });

  // Скрываем пустые группы треков
  document.querySelectorAll('.track-group').forEach(group => {
    let next = group.nextElementSibling;
    let hasVisible = false;
    while (next && !next.classList.contains('track-group')) {
      if (!next.classList.contains('hidden-by-filter') && next.tagName === 'TR') {
        hasVisible = true;
        break;
      }
      next = next.nextElementSibling;
    }
    group.classList.toggle('hidden-by-filter', !hasVisible);
  });
}

document.getElementById('filterTrack').addEventListener('input', applyFilters);
document.getElementById('filterPlugin').addEventListener('input', applyFilters);
document.getElementById('hidePresence').addEventListener('change', applyFilters);

function copyDiffs() {
  let text = 'REAPER Projects Comparison\n';
  text += 'Projects: ]] .. js_esc(table.concat(project_names, ' | ')) .. [[\n\n';

  document.querySelectorAll('.section-body').forEach(body => {
    const sec = body.dataset.section;
    text += '=== ' + sec + ' ===\n';
    body.querySelectorAll('tbody tr:not(.track-group):not(.hidden-by-filter)').forEach(tr => {
      const cells = tr.querySelectorAll('td');
      if (cells.length < 5) return;
      const plugin = cells[0].textContent.trim();
      const track  = cells[2].textContent.trim();
      const param  = cells[3].textContent.trim();
      const vals = [];
      for (let i = 4; i < cells.length; i++) vals.push(cells[i].textContent.trim());
      text += track + ' | ' + (plugin || '-') + ' | ' + param + ' | ' + vals.join(' | ') + '\n';
    });
    text += '\n';
  });

  navigator.clipboard.writeText(text).then(() => {
    alert('Отличия скопированы в буфер обмена');
  }).catch(() => {
    prompt('Скопируйте вручную:', text);
  });
}
</script>
</body>
</html>
]])

  f:close()
  return true
end

----------------------------------------------------------------
-- Open HTML
----------------------------------------------------------------
local function open_html(filename)
  local os_name = r.GetOS()
  if os_name:match("Win") then
    r.ExecProcess('cmd.exe /C start "" "' .. filename .. '"', -1)
  elseif os_name:match("Mac") or os_name:match("darwin") then
    r.ExecProcess('open "' .. filename .. '"', -1)
  else
    r.ExecProcess('xdg-open "' .. filename .. '"', -1)
  end
end

----------------------------------------------------------------
-- Main
----------------------------------------------------------------
function main()
  local projects = get_all_projects()
  if #projects < 2 then
    r.ShowMessageBox("Need at least 2 open projects to compare!", "Information", 0)
    return
  end

  local all_data, names = {}, {}
  for i, p in ipairs(projects) do
    names[i] = p.name
    all_data[i] = collect_project_data(p.proj)
  end

  local rows, all_track_names = compare_projects(all_data)
  if #rows == 0 then
    r.ShowMessageBox("No differences found between projects!", "Information", 0)
    return
  end

  local resource = r.GetResourcePath()
  local html_path = resource .. "/project_diff.html"

  if not write_html(html_path, names, rows, all_track_names) then
    r.ShowMessageBox("Failed to save HTML file!", "Error", 0)
    return
  end

  open_html(html_path)

  local msg = "HTML saved successfully!\n\n"
  msg = msg .. "File: " .. html_path .. "\n"
  msg = msg .. "Projects: " .. #names .. "\n"
  msg = msg .. "Differences: " .. #rows
  r.ShowMessageBox(msg, "Success", 0)
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Compare projects → diff.html", -1)