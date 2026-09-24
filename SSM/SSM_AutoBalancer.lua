-- @description SSM_AutoBalancer
-- @version 0.3
-- @author @ssm_metalmix
-- @about
--   ⚖️ Быстрая черновая раскладка громкости по названию файлов (public alpha).
--   Выделите items и запустите скрипт: по имени файла каждого item (kick, snare,
--   tom, guitar, vox, oh, hat и т.д.) выставляется своя громкость. Items с
--   незнакомым именем заглушаются (mute), чтобы их сразу было видно.
--   Перед применением показывается ПЛАН (сколько items получат какую громкость
--   и какие будут заглушены) - можно отменить без изменений.
--   Перед раскладкой выполняется команда нормализации 54211. Одна запись в
--   undo: «!!!SSM - AutoBalancer!!!».
--   Правила можно менять без правки скрипта: при первом запуске рядом со
--   скриптом создаётся файл SSM_AutoBalancer_rules.txt. Строка правила:
--   «уровень; имя1, имя2, ...» (усиление в дБ = 23 - уровень), порядок строк
--   важен - выигрывает первое совпавшее. Строка «preview = 0» отключает показ
--   плана. Чтобы вернуть стандартные правила, удалите файл.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   0.1 Публичная альфа.
--   0.2 Названия ищутся только в имени файла, а не в полном пути (папка вроде
--   «Vocals» раньше задевала все items внутри). Короткие обозначения (oh, hh, db,
--   tom, hat, vox) распознаются только целым словом. Правила собраны в таблицу.
--   Если у источника нет файла - берётся имя тейка.
--   0.3 Показ плана перед применением (можно отменить). Правила вынесены во
--   внешний файл SSM_AutoBalancer_rules.txt, который создаётся при первом запуске.

-- Правила по умолчанию (первое совпавшее выигрывает): lufs - "уровень" по
-- шкале скрипта, усиление в дБ = 23 - lufs. Названия ищутся в ИМЕНИ файла
-- (без папок и расширения), а не в полном пути.
local DEFAULT_RULES = {
  { lufs = 40,   "kick sub", "kick room", "toms room" },
  { lufs = 26.5, "kick in", "kick", "db" },
  { lufs = 28.5, "bass" },
  { lufs = 40,   "snare bot", "snare bottom", "snr bot", "snare btm", "snare hall", "snare room", "shaker", "room" },
  { lufs = 26,   "snare top", "snare", "snr" },
  { lufs = 25,   "tom", "gtr solo" },
  { lufs = 30,   "gtr acc", "piano", "organ" },
  { lufs = 33,   "synth" },
  { lufs = 27,   "guitars", "guitar", "gtr" },
  { lufs = 37,   "hat", "hh", "ride" },
  { lufs = 30,   "oh", "ovhs" },
  { lufs = 39,   "tambo" },
  { lufs = 24,   "vocal", "vox" },
}

local script_path = ({ reaper.get_action_context() })[2] or ""
local script_dir = script_path:match("(.+[\\/])") or ""
local RULES_FILE = script_dir .. "SSM_AutoBalancer_rules.txt"

----------------------------------------------------------------------
-- Правила: внешний файл
----------------------------------------------------------------------
local function write_rules_template(path)
  local f = io.open(path, "w")
  if not f then return end
  f:write("# SSM_AutoBalancer - правила раскладки громкости\n")
  f:write("# Формат: уровень; имя1, имя2, ...   (усиление в дБ = 23 - уровень)\n")
  f:write("# Порядок строк важен: выигрывает первая совпавшая. Регистр не важен.\n")
  f:write("# Короткие имена (до 3 букв) ищутся только целым словом, длинные - с начала слова.\n")
  f:write("# Строка 'preview = 0' отключает показ плана перед применением.\n")
  f:write("# Удалите файл, чтобы вернуть стандартные правила.\n\n")
  f:write("preview = 1\n\n")
  for _, rule in ipairs(DEFAULT_RULES) do
    f:write(string.format("%s; %s\n", tostring(rule.lufs), table.concat(rule, ", ")))
  end
  f:close()
end

-- Возвращает rules, options; при отсутствии/пустоте файла - стандартные правила.
local function load_rules()
  local options = { preview = true }
  local f = io.open(RULES_FILE, "r")
  if not f then
    write_rules_template(RULES_FILE)
    return DEFAULT_RULES, options
  end
  local rules = {}
  for line in f:lines() do
    line = line:gsub("\r$", "")
    if not line:match("^%s*#") and line:match("%S") then
      local opt_key, opt_val = line:match("^%s*([%a_]+)%s*=%s*(%S+)%s*$")
      if opt_key == "preview" then
        options.preview = opt_val ~= "0"
      else
        local lufs, names = line:match("^%s*(%-?[%d%.]+)%s*;%s*(.+)$")
        lufs = tonumber(lufs)
        if lufs then
          local rule = { lufs = lufs }
          for name in names:gmatch("[^,]+") do
            -- как и у имён файлов: разделители -> пробел (иначе "hi-hat" из файла
            -- правил никогда не совпал бы, а "-" в шаблоне Lua - спецсимвол)
            name = name:lower():gsub("[^%w]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if name ~= "" then rule[#rule + 1] = name end
          end
          if #rule > 0 then rules[#rules + 1] = rule end
        end
      end
    end
  end
  f:close()
  if #rules == 0 then return DEFAULT_RULES, options end
  return rules, options
end

----------------------------------------------------------------------
-- Сопоставление имён
----------------------------------------------------------------------
-- Имя файла без папок и расширения; любые разделители (_ - . пробел и т.п.)
-- сводятся к одному пробелу, чтобы "Kick_In-01.wav" находилось как "kick in".
local function normalized_name(path)
  local base = path:match("([^\\/]+)$") or path
  base = base:gsub("%.[^.]+$", "")
  base = base:lower():gsub("[^%w]+", " ")
  return " " .. base
end

-- Короткие обозначения (oh, hh, db, tom, hat...) - только целым словом (можно
-- с "s" на конце), иначе "oh" находилось бы в любом "ohm", а "db" в "dbl".
-- Длинные - с начала слова ("guitar" найдёт "guitar_L", "guitars").
local function name_has(norm, sub)
  if #sub <= 3 then
    return norm:find("%f[%a]" .. sub .. "%f[%A]") ~= nil
        or norm:find("%f[%a]" .. sub .. "s%f[%A]") ~= nil
  end
  return norm:find("%f[%a]" .. sub) ~= nil
end

-- Возвращает усиление в дБ и индекс сработавшего правила
local function find_gain_db(norm, rules)
  for ri, rule in ipairs(rules) do
    for _, sub in ipairs(rule) do
      if name_has(norm, sub) then return 23 - rule.lufs, ri end
    end
  end
  return nil
end

local function item_display_name(item)
  local take = reaper.GetActiveTake(item)
  local source = take and reaper.GetMediaItemTake_Source(take)
  if not source then return nil end
  local ok, file_name = pcall(reaper.GetMediaSourceFileName, source, "")
  if not ok or not file_name or file_name == "" then
    -- у источника нет файла (например, склеенный/сгенерированный) - имя тейка
    file_name = reaper.GetTakeName(take) or ""
  end
  return file_name
end

----------------------------------------------------------------------
-- MAIN
----------------------------------------------------------------------
local selected_items_count = reaper.CountSelectedMediaItems(0)
if selected_items_count == 0 then
  reaper.ShowMessageBox("Items not selected", "INFO", 0)
  return
end

local rules, options = load_rules()

-- 1. План (ничего не меняет)
local plan, per_rule, muted = {}, {}, {}
for i = 0, selected_items_count - 1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  local name = item and item_display_name(item)
  if name then
    local gain_db, ri = find_gain_db(normalized_name(name), rules)
    plan[#plan + 1] = { item = item, gain_db = gain_db }
    if gain_db then
      per_rule[ri] = (per_rule[ri] or 0) + 1
    else
      muted[#muted + 1] = name:match("([^\\/]+)$") or name
    end
  end
end

if options.preview then
  local lines = { string.format("Items в обработке: %d", #plan), "" }
  for ri, rule in ipairs(rules) do
    if per_rule[ri] then
      lines[#lines + 1] = string.format("%+.1f дБ: %d шт. (%s)", 23 - rule.lufs, per_rule[ri],
        table.concat(rule, ", "):sub(1, 60))
    end
  end
  if #muted > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = string.format("Будут заглушены (имя не распознано): %d", #muted)
    for i = 1, math.min(#muted, 12) do lines[#lines + 1] = "   " .. muted[i] end
    if #muted > 12 then lines[#lines + 1] = string.format("   ...и ещё %d", #muted - 12) end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Применить?"
  if reaper.ShowMessageBox(table.concat(lines, "\n"), "SSM AutoBalancer - план", 1) ~= 1 then return end
end

-- 2. Применение
reaper.Undo_BeginBlock()

-- Применяем нормализацию
reaper.Main_OnCommand(54211, 0)

for _, p in ipairs(plan) do
  if p.gain_db then
    local current_volume = reaper.GetMediaItemInfo_Value(p.item, "D_VOL")
    reaper.SetMediaItemInfo_Value(p.item, "D_VOL", current_volume * 10 ^ (p.gain_db / 20))
  else
    -- Если имя не знакомо — мутируем элемент
    reaper.SetMediaItemInfo_Value(p.item, "B_MUTE", 1)
  end
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("!!!SSM - AutoBalancer!!!", -1)
