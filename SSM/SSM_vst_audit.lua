-- @description SSM_vst_audit
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--  Чтобы не вспоминать, какие плагины нужны, а какие нет, перед удалением сделал вот такой скрипт для
--  Reaper, работает на Mac, LIN и WIN. Вы будете точно знать, какие плагины используются часто, какие
--  реже, а какие вам точно не нужны. Установка одинакова для всех систем.
--  тг канал https://t.me/bardinssm
--  тг ЛС https://t.me/ssm_metalmix
--  вк https://vk.ru/ssm_metalmix
--  бусти https://boosty.to/boostbg
-- @changelog
--   + Релиз



local reaper = reaper

-- Секция/ключ для хранения последнего выбранного пути (persist=true -> сохраняется между сессиями REAPER)
local EXT_SECTION = "SSM_pluginsData"
local EXT_KEY_LASTPATH = "last_projects_path"

-------------------------------------------------
-- 1. Выбор папки проектов
-------------------------------------------------
local projects_dir = nil
local last_path = reaper.GetExtState(EXT_SECTION, EXT_KEY_LASTPATH) or ""

if reaper.JS_Dialog_BrowseForFolder then
    local retval, path = reaper.JS_Dialog_BrowseForFolder("Выберите папку с проектами REAPER", last_path)
    if retval and path and path ~= "" then
        projects_dir = path
    end
else
    -- Fallback без js_ReaScriptAPI
    local retval, path = reaper.GetUserInputs("Папка проектов", 1, "Путь к папке с .rpp (extrawidth=300):", last_path)
    if retval and path and path ~= "" then
        projects_dir = path
    end
end

if not projects_dir or projects_dir == "" then
    reaper.ShowMessageBox("Папка проектов не выбрана. Скрипт остановлен.", "Ошибка", 0)
    return
end

-- Запоминаем выбранную папку на следующий запуск
reaper.SetExtState(EXT_SECTION, EXT_KEY_LASTPATH, projects_dir, true)

-------------------------------------------------
-- Вспомогательные функции
-------------------------------------------------
local function get_os()
    local os = reaper.GetOS()
    if os:find("Win") then return "win"
    elseif os:find("OSX") or os:find("mac") then return "mac"
    else return "linux" end
end

local function normalize_path(path)
    if not path then return "" end
    path = path:gsub("\\", "/")          -- унифицируем
    path = path:gsub("/+", "/")          -- убираем двойные слэши
    return path
end

local function join_path(...)
    local parts = {...}
    local result = table.concat(parts, "/")
    return normalize_path(result)
end

local function get_report_dir()
    -- Отчёт сохраняется в папке ресурсов REAPER (Options > Show REAPER resource path...)
    return normalize_path(reaper.GetResourcePath())
end

local function html_escape(s)
    if not s then return "" end
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    return s
end

local function open_file(path)
    if reaper.CF_ShellExecute then
        reaper.CF_ShellExecute(path)
        return
    end
    local os_type = get_os()
    if os_type == "win" then
        os.execute('start "" "' .. path .. '"')
    elseif os_type == "mac" then
        os.execute('open "' .. path .. '"')
    else
        os.execute('xdg-open "' .. path .. '"')
    end
end

-- Нормализация имени плагина для сравнения
local function normalize_plugin_name(name)
    if not name then return "" end
    
    name = name:lower()
    
    -- Убираем типичные префиксы
    name = name:gsub("^vst3?:%s*", "")
    name = name:gsub("^clap:%s*", "")
    name = name:gsub("^js:%s*", "")
    name = name:gsub("^au:%s*", "")
    
    -- Убираем (Manufacturer) в конце
    name = name:gsub("%s*%([^%)]*%)%s*$", "")
    
    -- Убираем расширение файла, если есть
    name = name:gsub("%.vst3?$", "")
    name = name:gsub("%.dll$", "")
    name = name:gsub("%.clap$", "")
    name = name:gsub("%.vst$", "")
    name = name:gsub("%.so$", "")
    name = name:gsub("%.component$", "")
    
    -- Убираем лишние пробелы
    name = name:gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
    
    return name
end

-------------------------------------------------
-- 2. Получение путей VST / CLAP из reaper.ini
-------------------------------------------------
local ini_path = reaper.get_ini_file()
local vst_paths = {}

local file = io.open(ini_path, "r")
if file then
    for line in file:lines() do
        -- Разбираем произвольную строку "key=value" (без учёта регистра ключа)
        local key, value = line:match("^([%w_]+)%s*=%s*(.*)$")
        if key then
            local lkey = key:lower()
            -- Ловим любые варианты: vstpath, vstpath64, vstpath_x64, clappath, clappath64, clap_path и т.д.
            if lkey:find("vstpath", 1, true) or lkey:find("clappath", 1, true) or lkey:find("clap_path", 1, true) then
                if value and value ~= "" then
                    for path in value:gmatch("[^;]+") do
                        path = path:match("^%s*(.-)%s*$") -- trim
                        if path and path ~= "" then
                            table.insert(vst_paths, normalize_path(path))
                        end
                    end
                end
            end
        end
    end
    file:close()
end

if #vst_paths == 0 then
    reaper.ShowMessageBox("Не удалось найти пути к VST/CLAP в reaper.ini", "Предупреждение", 0)
end

-------------------------------------------------
-- 3. Сканирование установленных плагинов
-------------------------------------------------
local installed = {}   -- key = normalized name

local function scan_plugin_dir(dir)
    if not dir or dir == "" then return end
    dir = normalize_path(dir)

    -- Файлы
    local i = 0
    while true do
        local filename = reaper.EnumerateFiles(dir, i)
        if not filename then break end

        local ext = filename:match("%.([^.]+)$")
        if ext then
            ext = ext:lower()
            if ext == "vst3" or ext == "dll" or ext == "clap" or ext == "vst" or ext == "so" then
                local raw_name = filename:match("(.+)%..+$")
                if raw_name then
                    local norm = normalize_plugin_name(raw_name)
                    if norm ~= "" and not installed[norm] then
                        installed[norm] = {
                            clean_name = raw_name,
                            path = join_path(dir, filename),
                            project_count = 0,
                            instance_count = 0
                        }
                    end
                end
            end
        end
        i = i + 1
    end

    -- Подпапки. На macOS VST/VST3/AU/CLAP — это "бандлы" (директории с
    -- расширением .vst / .vst3 / .component / .clap), их нужно считать
    -- плагинами, а не рекурсивно сканировать как обычную папку.
    local j = 0
    while true do
        local subfolder = reaper.EnumerateSubdirectories(dir, j)
        if not subfolder or subfolder == "" then break end

        local sub_ext = subfolder:match("%.([^.]+)$")
        sub_ext = sub_ext and sub_ext:lower() or nil

        if sub_ext == "vst3" or sub_ext == "vst" or sub_ext == "component" or sub_ext == "clap" then
            local raw_name = subfolder:match("(.+)%..+$") or subfolder
            local norm = normalize_plugin_name(raw_name)
            if norm ~= "" and not installed[norm] then
                installed[norm] = {
                    clean_name = raw_name,
                    path = join_path(dir, subfolder),
                    project_count = 0,
                    instance_count = 0
                }
            end
        else
            scan_plugin_dir(join_path(dir, subfolder))
        end
        j = j + 1
    end
end

for _, vpath in ipairs(vst_paths) do
    scan_plugin_dir(vpath)
end

-------------------------------------------------
-- 4. Сканирование проектов
-------------------------------------------------
local total_projects = 0
local processed = 0

local function scan_projects(dir)
    if not dir or dir == "" then return end
    dir = normalize_path(dir)

    local i = 0
    while true do
        local filename = reaper.EnumerateFiles(dir, i)
        if not filename then break end

        local lower = filename:lower()
        if lower:match("%.rpp$") and not lower:match("%.rpp%-bak$") then
            total_projects = total_projects + 1
            local filepath = join_path(dir, filename)

            local f = io.open(filepath, "r")
            if f then
                local content = f:read("*all")
                f:close()

                -- Ищем VST и CLAP
                for plugin_raw in content:gmatch('<VST%d?%s+"([^"]+)"') do
                    local norm = normalize_plugin_name(plugin_raw)
                    if norm ~= "" then
                        -- Сначала точное совпадение
                        if installed[norm] then
                            installed[norm].instance_count = installed[norm].instance_count + 1
                        else
                            -- Частичное совпадение (с защитой от слишком коротких имён)
                            for key, data in pairs(installed) do
                                if #key >= 4 and #norm >= 4 then
                                    if norm:find(key, 1, true) or key:find(norm, 1, true) then
                                        data.instance_count = data.instance_count + 1
                                        break
                                    end
                                end
                            end
                        end
                    end
                end

                -- CLAP (если есть)
                for plugin_raw in content:gmatch('<CLAP%s+"([^"]+)"') do
                    local norm = normalize_plugin_name(plugin_raw)
                    if installed[norm] then
                        installed[norm].instance_count = installed[norm].instance_count + 1
                    end
                end
            end
        end
        i = i + 1
    end

    -- Рекурсия по подпапкам
    local j = 0
    while true do
        local subfolder = reaper.EnumerateSubdirectories(dir, j)
        if not subfolder or subfolder == "" then break end
        scan_projects(join_path(dir, subfolder))
        j = j + 1
    end
end

reaper.ClearConsole()
reaper.ShowConsoleMsg("Сканирование проектов...\n")
scan_projects(projects_dir)

-- Подсчёт уникальных проектов, где плагин использовался
-- (упрощённо: если instance_count > 0 — считаем как использованный)
for _, data in pairs(installed) do
    if data.instance_count > 0 then
        data.project_count = 1   -- минимальная отметка "использовался"
        -- Для более точного подсчёта проектов нужно хранить set проектов,
        -- но это сильно усложняет код. Оставляем instance_count.
    end
end

-------------------------------------------------
-- 5. Запись HTML-отчёта
-------------------------------------------------
local report_dir = get_report_dir()
local report_path = join_path(report_dir, "vst_reaper_audit.html")

if get_os() == "win" then
    report_path = report_path:gsub("/", "\\")
end

-- Разбиваем на используемые / неиспользуемые
local unused_list = {}
local used_list = {}

for _, data in pairs(installed) do
    if data.instance_count == 0 then
        table.insert(unused_list, data)
    else
        table.insert(used_list, data)
    end
end

table.sort(unused_list, function(a, b) return a.clean_name:lower() < b.clean_name:lower() end)
table.sort(used_list, function(a, b) return a.instance_count > b.instance_count end)

local unused_count = #unused_list
local installed_count = unused_count + #used_list

local out = io.open(report_path, "w")
if not out then
    reaper.ShowConsoleMsg("❌ Не удалось создать файл отчёта:\n" .. report_path .. "\n")
    return
end

out:write([[<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="UTF-8">
<title>Отчёт по плагинам REAPER</title>
<style>
  :root, [data-theme="light"] {
    --bg: #f5f6f8;
    --card: #ffffff;
    --text: #1f2430;
    --muted: #6b7280;
    --border: #e5e7eb;
    --accent: #4f6df5;
    --danger: #e5484d;
    --success: #12b76a;
  }
  [data-theme="dark"] {
    --bg: #14161b;
    --card: #1c1f26;
    --text: #e7e9ee;
    --muted: #8b93a1;
    --border: #2b2f38;
    --accent: #7d97ff;
    --danger: #ff6b6f;
    --success: #35d488;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 32px 16px;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    transition: background 0.15s ease, color 0.15s ease;
  }
  .wrap { max-width: 760px; margin: 0 auto; }
  .header-row {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 24px;
  }
  h1 { font-size: 20px; margin: 0 0 4px; }
  .subtitle { color: var(--muted); font-size: 13px; }
  .theme-toggle {
    flex: none;
    width: 36px;
    height: 36px;
    border-radius: 999px;
    border: 1px solid var(--border);
    background: var(--card);
    color: var(--text);
    font-size: 16px;
    cursor: pointer;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .stats {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
    gap: 12px;
    margin-bottom: 24px;
  }
  .stat {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 14px 16px;
  }
  .stat .num { font-size: 22px; font-weight: 600; }
  .stat .label { font-size: 12px; color: var(--muted); margin-top: 2px; }
  .stat.danger .num { color: var(--danger); }
  .stat.success .num { color: var(--success); }
  details {
    background: var(--card);
    border: 1px solid var(--border);
    border-radius: 10px;
    margin-bottom: 12px;
    overflow: hidden;
  }
  summary {
    cursor: pointer;
    padding: 14px 16px;
    font-weight: 600;
    list-style: none;
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  summary::-webkit-details-marker { display: none; }
  summary::after {
    content: "▾";
    color: var(--muted);
    transition: transform 0.15s ease;
  }
  details[open] summary::after { transform: rotate(180deg); }
  .list { padding: 0 16px 12px; }
  .row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 0;
    border-top: 1px solid var(--border);
    font-size: 14px;
  }
  .row:first-child { border-top: none; }
  .count {
    color: var(--muted);
    font-size: 12px;
    background: var(--bg);
    border-radius: 999px;
    padding: 2px 9px;
    white-space: nowrap;
  }
  .empty { padding: 12px 0; color: var(--muted); font-size: 14px; }
  .footer {
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid var(--border);
    display: flex;
    flex-wrap: wrap;
    gap: 16px;
    justify-content: center;
  }
  .footer a {
    color: var(--muted);
    text-decoration: none;
    font-size: 13px;
  }
  .footer a:hover { color: var(--accent); }
</style>
</head>
<body>
<div class="wrap">
  <div class="header-row">
    <div>
      <h1>Отчёт по плагинам REAPER</h1>
      <div class="subtitle">]])

out:write(os.date("%d.%m.%Y %H:%M") .. " · " .. html_escape(projects_dir))

out:write([[</div>
    </div>
    <button id="themeToggle" class="theme-toggle" type="button" aria-label="Переключить тему">🌙</button>
  </div>

  <div class="stats">
    <div class="stat"><div class="num">]] .. total_projects .. [[</div><div class="label">проектов проверено</div></div>
    <div class="stat"><div class="num">]] .. installed_count .. [[</div><div class="label">плагинов установлено</div></div>
    <div class="stat danger"><div class="num">]] .. unused_count .. [[</div><div class="label">не используются</div></div>
    <div class="stat success"><div class="num">]] .. #used_list .. [[</div><div class="label">используются</div></div>
  </div>

  <details open>
    <summary>❌ Не используются (]] .. unused_count .. [[)</summary>
    <div class="list">
]])

if unused_count == 0 then
    out:write('      <div class="empty">Все установленные плагины используются хотя бы в одном проекте.</div>\n')
else
    for _, data in ipairs(unused_list) do
        out:write('      <div class="row"><span>' .. html_escape(data.clean_name) .. '</span></div>\n')
    end
end

out:write([[    </div>
  </details>

  <details>
    <summary>✅ Используются (]] .. #used_list .. [[)</summary>
    <div class="list">
]])

if #used_list == 0 then
    out:write('      <div class="empty">Нет использованных плагинов.</div>\n')
else
    for _, data in ipairs(used_list) do
        out:write('      <div class="row"><span>' .. html_escape(data.clean_name) ..
            '</span><span class="count">' .. data.instance_count .. '</span></div>\n')
    end
end

out:write([[    </div>
  </details>

  <div class="footer">
    <a href="https://t.me/bardinssm" target="_blank">📱 Telegram Channel</a>
    <a href="https://t.me/ssm_metalmix" target="_blank">💬 Telegram</a>
    <a href="https://boosty.to/boostbg" target="_blank">☕ Boosty</a>
    <a href="https://vk.ru/ssm_metalmix" target="_blank">🌐 VK</a>
  </div>
</div>
<script>
(function () {
  var root = document.documentElement;
  var btn = document.getElementById('themeToggle');
  var stored = null;
  try { stored = localStorage.getItem('ssm_theme'); } catch (e) {}
  var systemDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  var theme = stored || (systemDark ? 'dark' : 'light');

  function apply(t) {
    root.setAttribute('data-theme', t);
    btn.textContent = t === 'dark' ? '☀️' : '🌙';
  }
  apply(theme);

  btn.addEventListener('click', function () {
    theme = theme === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem('ssm_theme', theme); } catch (e) {}
    apply(theme);
  });
})();
</script>
</body>
</html>
]])

out:close()

-------------------------------------------------
-- Финальное сообщение
-------------------------------------------------
reaper.ShowConsoleMsg("Готово. Проектов: " .. total_projects .. ", неиспользуемых плагинов: " .. unused_count .. "\n")

open_file(report_path)
