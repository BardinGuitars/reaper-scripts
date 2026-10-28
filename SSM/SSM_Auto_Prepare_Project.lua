-- @description SSM_Auto_Prepare_Project
-- @version 1.2
-- @author @ssm_metalmix
-- @about
--   🧹 Автоподготовка проекта: быстро наводит порядок в только что собранном проекте. Скрипт сначала анализирует проект,
--   потом показывает окно со списком изменений: у каждой функции и у каждого изменения своя галочка, применяется только отмеченное,
--   всё одним шагом Undo (Ctrl+Z возвращает проект как был).
--   Что умеет:
--   1) Стерео, которое на деле моно: если левый и правый канал айтема одинаковые (стерео-файл с моно внутри) или один канал пустой,
--   айтем переключается на моно (левый канал, а если левый пуст - правый). Файлы не меняются: это режим канала тейка (Take channel mode).
--   Настоящее стерео и почти-моно с разным уровнем каналов не трогаются.
--   2) Панорама по названию трека: L, Left, Лево, Л - влево до упора; R, Right, Право, П - вправо. Если в названии есть и то и другое - не трогает.
--   3) Дубликаты: два айтема с одним и тем же звуком в одном и том же месте (на разных дорожках) - один удаляется; если он был
--   единственным на дорожке, удаляется и дорожка (кроме папок, дорожек с плагинами и дорожек с посылами).
--   4) Раскладка дорожек по папкам: барабаны (бочка, малый, томы, тарелки; оверхеды и румы - каждые в своей папке внутри тарелок), бас, гитары, вокал, синты и клавиши - по названиям.
--   Если подходящая папка в проекте уже есть, дорожка уходит в неё, иначе папка создаётся (когда в ней будет две дорожки и больше).
--   Дорожки, которые уже лежат в папках, не трогаются.
--   5) Загрузка папки: при запуске скрипт предлагает выбрать папку с аудиофайлами (окно ОС), сам загружает файлы новыми дорожками и проверяет их по пунктам 1-4.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   1.2 Загрузка папки: перед проверкой можно выбрать папку с аудиофайлами через окно ОС (нужен js_ReaScriptAPI, без него путь вводится вручную): файлы (и из вложенных
--   папок) загружаются новыми дорожками, имя дорожки - имя файла, потом проверяются моно, панорама, дубликаты и раскладка по папкам. Загрузка - отдельный шаг Undo.
--   1.2 Раскладка по папкам: внутри CYMBALS оверхеды (OH) и румы (ROOM) лежат каждые в своей папке: DRUMS > CYMBALS > OH, ROOM (хэт, райд, крэш - прямо в CYMBALS).
--   1.1 Окно согласия с галочками (на каждую функцию и на каждое изменение). Новое: поиск и удаление дубликатов айтемов (и пустых после этого дорожек),
--   раскладка дорожек по папкам (DRUMS / KICK / SD / TOMS / CYMBALS, BASS, GTR, VOX, INST) по образцу ваших проектов.
--   1.0 Релиз

local TITLE = "SSM: автоподготовка проекта"

-- Настройки (при желании поменяйте числа)
local FAKE_STEREO_DB = 50   -- левый и правый канал одинаковые, если разность тише на столько дБ
local GAIN_TOL_DB = 1.5     -- ...и их уровни различаются не больше, чем на столько дБ (иначе это моно с панорамой, не трогаем)
local SILENT_DB = 60        -- канал тише другого на столько дБ считается пустым
local PAN_AMOUNT = 1.0      -- насколько уводить в сторону: 1.0 = до упора (100 %)
local ANALYSE_SR = 22050    -- частота, на которой читается звук для проверки
local WIN_SEC = 1.0         -- длина куска, который читается за раз
local MAX_WINDOWS = 40      -- у длинных айтемов читается не больше стольких кусков, равномерно по всей длине
local SLICE_SEC = 0.02      -- сколько работать за один заход, потом отдать управление REAPER (окно не зависает)
local DUP_POS_TOL = 0.001   -- дубликат: начало и длина совпадают с точностью до этого, секунд
local HASH_WINDOWS = 12     -- дубликат: звук сравнивается по стольким кускам, равномерно по айтему
local HASH_FRAMES = 4096    -- ...длиной в столько кадров каждый
local FOLDER_MIN_TRACKS = 2 -- новая папка создаётся, если в ней будет не меньше стольких дорожек
local IMPORT_SUBFOLDERS = true -- загрузка папки: брать файлы и из вложенных папок
local IMPORT_DEPTH = 3         -- ...не глубже стольких уровней
local EXT_SECTION = "SSM_Auto_Prepare_Project"
local AUDIO_EXT = { wav = true, wave = true, w64 = true, aif = true, aiff = true, aifc = true, flac = true, mp3 = true, ogg = true,
  opus = true, wv = true, caf = true, m4a = true }

----------------------------------------------------------------------
-- Название трека -> сторона панорамы
----------------------------------------------------------------------
local LEFT_WORDS = { l = true, lt = true, lft = true, left = true, ["л"] = true, ["лев"] = true, ["лево"] = true,
  ["левый"] = true, ["левая"] = true, ["левое"] = true }
local RIGHT_WORDS = { r = true, rt = true, rgt = true, right = true, ["п"] = true, ["прав"] = true, ["право"] = true,
  ["правый"] = true, ["правая"] = true, ["правое"] = true }

-- класс символа: d - цифра, U - заглавная буква, l - строчная, s - всё остальное (разделитель)
local function cp_class(cp)
  if cp >= 0x30 and cp <= 0x39 then return "d" end
  if (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x410 and cp <= 0x42F) or cp == 0x401 then return "U" end
  if (cp >= 0x61 and cp <= 0x7A) or (cp >= 0x430 and cp <= 0x44F) or cp == 0x451 then return "l" end
  return "s"
end

local function cp_lower(cp)
  if (cp >= 0x41 and cp <= 0x5A) or (cp >= 0x410 and cp <= 0x42F) then return cp + 32 end
  if cp == 0x401 then return 0x451 end
  return cp
end

-- слова названия: делится по разделителям, на стыке буква/цифра и по "ЗаглавнымБуквам" (GtrL -> gtr, l), всё в нижнем регистре
local function name_tokens(name)
  local cps = {}
  local ok = pcall(function() for _, cp in utf8.codes(name) do cps[#cps + 1] = cp end end)
  if not ok then
    cps = {}
    for i = 1, #name do cps[#cps + 1] = name:byte(i) end
  end
  local cls = {}
  for i, cp in ipairs(cps) do cls[i] = cp_class(cp) end
  local out, cur = {}, {}
  local function flush()
    if #cur > 0 then out[#out + 1] = utf8.char(table.unpack(cur)); cur = {} end
  end
  for i = 1, #cps do
    local c, p, n = cls[i], cls[i - 1], cls[i + 1]
    if c == "s" then
      flush()
    else
      if p and p ~= "s" then
        if (p == "d") ~= (c == "d") then flush()
        elseif p == "l" and c == "U" then flush()
        elseif p == "U" and c == "U" and n == "l" then flush() end
      end
      cur[#cur + 1] = cp_lower(cps[i])
    end
  end
  flush()
  return out
end

-- -> -1 (влево), 1 (вправо) или nil (в названии нет стороны либо есть обе)
local function pan_side(name)
  local left, right = false, false
  for _, w in ipairs(name_tokens(name or "")) do
    if LEFT_WORDS[w] then left = true end
    if RIGHT_WORDS[w] then right = true end
  end
  if left and not right then return -1 end
  if right and not left then return 1 end
  return nil
end

----------------------------------------------------------------------
-- Моно или настоящее стерео: по накопленным суммам L*L, R*R, L*R
----------------------------------------------------------------------
local function db(x) return 10 * math.log(x, 10) end

-- -> { kind, pick, text }; kind: "silent" | "mono" (взять pick = "L" или "R") | "stereo" | "panned" | "inverted"
local function classify(sLL, sRR, sLR, frames)
  if frames <= 0 or (sLL / frames < 1e-10 and sRR / frames < 1e-10) then
    return { kind = "silent", text = "тишина - не определить" }
  end
  local silent = 10 ^ (-SILENT_DB / 10)
  if sRR <= sLL * silent then
    return { kind = "mono", pick = "L", text = "правый канал пуст" }
  elseif sLL <= sRR * silent then
    return { kind = "mono", pick = "R", text = "левый канал пуст, берётся правый" }
  end
  local a = sLR / sLL
  local resid = math.max(0, sRR - sLR * sLR / sLL)
  local resid_db = db(resid / sRR + 1e-30)
  local diff_text = string.format("разность каналов %.0f дБ", resid_db)
  if resid_db <= -FAKE_STEREO_DB then
    if a < 0 then return { kind = "inverted", text = "каналы одинаковые, но в противофазе - " .. diff_text } end
    if math.abs(20 * math.log(a, 10)) <= GAIN_TOL_DB then
      return { kind = "mono", pick = "L", text = "левый и правый одинаковые (" .. diff_text .. ")" }
    end
    return { kind = "panned", text = string.format("моно с панорамой (уровни каналов различаются на %.1f дБ)", math.abs(20 * math.log(a, 10))) }
  end
  return { kind = "stereo", text = "настоящее стерео (" .. diff_text .. ")" }
end

----------------------------------------------------------------------
-- Раскладка по папкам: категории по названию, дерево дорожек, перенос в папки (чистые функции без REAPER)
----------------------------------------------------------------------
-- Порядок важен: первое совпавшее правило выигрывает. exact - слова названия целиком, prefix - начало слова, phrase - фраза в названии.
local CATEGORY_RULES = {
  { path = { "DRUMS", "KICK" }, exact = { "kick", "kicks", "kik", "kd", "bd", "subkick", "бочка", "бочки" }, prefix = { "kick" }, phrase = { "bass drum", "bassdrum" } },
  { path = { "DRUMS", "SD" }, exact = { "snare", "snares", "snr", "sd", "малый", "рабочий" }, prefix = { "snare" } },
  { path = { "DRUMS", "TOMS" }, exact = { "tom", "toms", "floor", "rack", "том", "томы" }, tom_digit = true },
  { path = { "DRUMS", "CYMBALS", "OH" }, exact = { "oh", "ohs", "overhead", "overheads", "оверхед", "оверхеды" }, prefix = { "overhead" } },
  { path = { "DRUMS", "CYMBALS", "ROOM" }, exact = { "room", "rooms", "рум", "румы" } },
  { path = { "DRUMS", "CYMBALS" }, exact = { "hat", "hats", "hh", "hihat", "ride", "crash", "splash", "china",
      "cymbal", "cymbals", "тарелки", "хет", "хэт", "райд", "крэш" }, prefix = { "hihat" } },
  { path = { "DRUMS" }, exact = { "drums", "drum", "drumkit", "барабаны" } },
  { path = { "BASS" }, exact = { "bass", "bas", "бас", "басс" }, prefix = { "bass" } },
  { path = { "GTR" }, exact = { "gtr", "gtrs", "guitar", "guitars", "guit", "git", "gitar", "гитара", "гитары" }, prefix = { "guitar", "gtr" } },
  { path = { "VOX" }, exact = { "vox", "vocal", "vocals", "voc", "vx", "вокал", "bv", "bgv", "backing", "dubb", "dub" }, prefix = { "vocal" } },
  { path = { "INST" }, exact = { "synth", "synths", "keys", "key", "piano", "pad", "pads", "strings", "organ", "rise", "sweep", "bells", "choir",
      "ambience", "atmo" }, prefix = { "synth" } },
}
for _, rule in ipairs(CATEGORY_RULES) do
  local set = {}
  for _, w in ipairs(rule.exact) do set[w] = true end
  rule.set = set
end

-- Под какими словами в названии существующая папка считается папкой этой категории
local FOLDER_ALIASES = {
  DRUMS = { "drums", "drum", "drumkit", "барабаны" }, KICK = { "kick", "kicks", "kik", "bd", "kd" }, SD = { "sd", "snare", "snr" },
  TOMS = { "toms", "tom", "t" }, CYMBALS = { "cymbals", "cymbal", "c" }, OH = { "oh", "ohs", "overhead", "overheads" }, ROOM = { "room", "rooms" },
  BASS = { "bass", "бас", "басс" },
  GTR = { "gtr", "gtrs", "guitar", "guitars" }, VOX = { "vox", "vocal", "vocals" }, INST = { "inst", "synths", "synth", "keys" },
}
local CANON_ORDER = { DRUMS = 1, BASS = 2, GTR = 3, VOX = 4, INST = 5 } -- порядок новых папок верхнего уровня
local SUB_ORDER = { KICK = 1, SD = 2, TOMS = 3, CYMBALS = 4 }
local SUB2_ORDER = { OH = 1, ROOM = 2 } -- внутри CYMBALS: сначала папка OH, потом ROOM, потом отдельные дорожки (хэт, райд ...)

-- Категория дорожки по названию: список вида { "DRUMS", "KICK" } или nil
local function track_category(name)
  local tokens = name_tokens(name or "")
  local joined = " " .. table.concat(tokens, " ") .. " "
  for _, rule in ipairs(CATEGORY_RULES) do
    local hit = false
    for i, tk in ipairs(tokens) do
      if rule.set[tk] then hit = true; break end
      for _, pre in ipairs(rule.prefix or {}) do
        if #tk > #pre and tk:sub(1, #pre) == pre then hit = true; break end
      end
      if hit then break end
      if rule.tom_digit and tk == "t" and tokens[i + 1] and tokens[i + 1]:match("^%d+$") then hit = true; break end
    end
    if not hit then
      for _, ph in ipairs(rule.phrase or {}) do if joined:find(" " .. ph .. " ", 1, true) then hit = true; break end end
    end
    if hit then return rule.path end
  end
  return nil
end

-- Папка с таким названием подходит категории (по словам из FOLDER_ALIASES)?
local function folder_matches(name, key)
  local alias = {}
  for _, w in ipairs(FOLDER_ALIASES[key] or {}) do alias[w] = true end
  for _, tk in ipairs(name_tokens(name or "")) do if alias[tk] then return true end end
  return false
end

-- Дерево дорожек из плоского списка { ref, name, fd (I_FOLDERDEPTH), items }: -> корень { children = {...} }
-- у узла: ref, name, items, fd0 (исходное значение), children (если это папка)
local function build_tree(list)
  local root = { children = {} }
  local stack = { root }
  for _, t in ipairs(list) do
    local parent = stack[#stack]
    local node = { ref = t.ref, name = t.name, items = t.items or 0, fd0 = t.fd or 0, children = {} }
    parent.children[#parent.children + 1] = node
    local fd = t.fd or 0
    if fd > 0 then
      stack[#stack + 1] = node
    elseif fd < 0 then
      for _ = 1, -fd do
        if #stack > 1 then stack[#stack] = nil end
      end
    end
  end
  return root
end

-- Дерево -> плоский порядок с уровнями вложенности и значениями I_FOLDERDEPTH: { { node, level, fd } ... }
local function flatten_tree(root)
  local flat = {}
  local function walk(node, level)
    for _, ch in ipairs(node.children) do
      flat[#flat + 1] = { node = ch, level = level }
      walk(ch, level + 1)
    end
  end
  walk(root, 0)
  for i, e in ipairs(flat) do
    local nxt = flat[i + 1]
    e.fd = (nxt and nxt.level or 0) - e.level
  end
  return flat
end

local function is_folder_node(n) return #n.children > 0 end

-- Найти папку для категории key: сначала среди детей scope (его поддерево целиком), ближайшую к корню. -> узел или nil
local function find_folder(scope, key)
  local best, best_level
  local function walk(node, level)
    for _, ch in ipairs(node.children) do
      if is_folder_node(ch) and folder_matches(ch.name, key) and (not best or level < best_level) then best, best_level = ch, level end
      walk(ch, level + 1)
    end
  end
  walk(scope, 0)
  return best
end

-- План раскладки: дорожки верхнего уровня (не папки, есть items, название узнаётся) -> в какую папку идут (до трёх уровней: DRUMS > CYMBALS > OH).
-- Папка нужной категории берётся существующая (любой глубины), иначе создаётся - когда в ней будет не меньше FOLDER_MIN_TRACKS дорожек;
-- если папка не набирает дорожек, дорожка кладётся на уровень выше.
-- -> список групп { key = "DRUMS/CYMBALS/OH", label, tracks = { узлы }, top, sub, sub2, new_top, new_sub, new_sub2 }
local function plan_sort(root)
  local cands = {}
  for _, node in ipairs(root.children) do
    if not is_folder_node(node) and node.fd0 <= 0 and node.items > 0 then
      local path = track_category(node.name)
      if path then cands[#cands + 1] = { node = node, path = path } end
    end
  end
  local count = {}
  for _, c in ipairs(cands) do
    local key = ""
    for i, name in ipairs(c.path) do
      key = key .. (i > 1 and "/" or "") .. name
      count[key] = (count[key] or 0) + 1
    end
  end
  local groups, by_key = {}, {}
  for _, c in ipairs(cands) do
    local top, sub, sub2 = c.path[1], c.path[2], c.path[3]
    local top_node = find_folder(root, top)
    local new_top = false
    local ok = true
    if not top_node then
      if count[top] >= FOLDER_MIN_TRACKS then new_top = true else ok = false end
    end
    if ok then
      local sub_name, new_sub, sub2_name, new_sub2 = nil, false, nil, false
      local sub_node
      if sub then
        sub_node = top_node and find_folder(top_node, sub)
        if sub_node then sub_name = sub
        elseif count[top .. "/" .. sub] >= FOLDER_MIN_TRACKS then sub_name, new_sub = sub, true end
      end
      if sub_name and sub2 then
        local sub2_node = sub_node and find_folder(sub_node, sub2)
        if sub2_node then sub2_name = sub2
        elseif count[top .. "/" .. sub .. "/" .. sub2] >= FOLDER_MIN_TRACKS then sub2_name, new_sub2 = sub2, true end
      end
      local key = top .. (sub_name and ("/" .. sub_name) or "") .. (sub2_name and ("/" .. sub2_name) or "")
      local g = by_key[key]
      if not g then
        g = { key = key, top = top, sub = sub_name, sub2 = sub2_name, new_top = new_top, new_sub = new_sub, new_sub2 = new_sub2, tracks = {} }
        g.label = top .. (sub_name and (" > " .. sub_name) or "") .. (sub2_name and (" > " .. sub2_name) or "")
        by_key[key] = g
        groups[#groups + 1] = g
      end
      g.tracks[#g.tracks + 1] = c.node
    end
  end
  -- порядок: папки верхнего уровня как в образце, внутри - KICK, SD, TOMS, CYMBALS; внутри CYMBALS - OH, ROOM, потом дорожки без своей папки
  table.sort(groups, function(a, b)
    local oa, ob = CANON_ORDER[a.top] or 99, CANON_ORDER[b.top] or 99
    if oa ~= ob then return oa < ob end
    local sa, sb = SUB_ORDER[a.sub or ""] or 0, SUB_ORDER[b.sub or ""] or 0
    if sa ~= sb then return sa < sb end
    return (SUB2_ORDER[a.sub2 or ""] or 9) < (SUB2_ORDER[b.sub2 or ""] or 9)
  end)
  return groups
end

-- Применить выбранные группы к дереву (дорожки переезжают в папки; новые папки - узлы без ref). -> число перенесённых дорожек, список новых узлов
local function apply_sort(root, groups)
  local moved, created = 0, {}
  local function remove_from_root(node)
    for i, ch in ipairs(root.children) do if ch == node then table.remove(root.children, i); return i end end
  end
  -- где вставлять новые папки верхнего уровня: на месте первой переносимой дорожки
  local insert_at
  for _, g in ipairs(groups) do
    for _, node in ipairs(g.tracks) do
      for i, ch in ipairs(root.children) do
        if ch == node and (not insert_at or i < insert_at) then insert_at = i end
      end
    end
  end
  local new_tops, made = {}, {}
  for _, g in ipairs(groups) do if g.new_top and not made[g.top] then made[g.top] = true; new_tops[#new_tops + 1] = g.top end end
  table.sort(new_tops, function(a, b) return (CANON_ORDER[a] or 99) < (CANON_ORDER[b] or 99) end)
  -- сначала вынимаем переносимые дорожки из корня, потом создаём папки (индексы не сбиваются)
  for _, g in ipairs(groups) do for _, node in ipairs(g.tracks) do remove_from_root(node) end end
  local ins = math.min(insert_at or (#root.children + 1), #root.children + 1)
  local top_nodes = {}
  for _, name in ipairs(new_tops) do
    local node = { name = name, items = 0, fd0 = 1, children = {}, new = true }
    table.insert(root.children, ins, node)
    ins = ins + 1
    top_nodes[name] = node
    created[#created + 1] = node
  end
  -- папка внутри parent: существующая (в том числе созданная выше в этом же проходе) или новая в конце parent
  local function ensure_child(parent, key)
    local node = find_folder(parent, key)
    if not node then
      node = { name = key, items = 0, fd0 = 1, children = {}, new = true }
      parent.children[#parent.children + 1] = node
      created[#created + 1] = node
    end
    return node
  end
  for _, g in ipairs(groups) do
    local container = top_nodes[g.top] or find_folder(root, g.top)
    if g.sub then container = ensure_child(container, g.sub) end
    if g.sub2 then container = ensure_child(container, g.sub2) end
    for _, node in ipairs(g.tracks) do
      container.children[#container.children + 1] = node
      moved = moved + 1
    end
  end
  return moved, created
end

----------------------------------------------------------------------
-- Дубликаты: какой из одинаковых айтемов оставить, какие удалить (чистая часть)
----------------------------------------------------------------------
-- group: список { track_index, has_fx, ... }. Остаётся айтем на дорожке с плагинами, иначе самый верхний. -> остаётся (номер в списке)
local function pick_keeper(group)
  local keep = 1
  for i, e in ipairs(group) do
    if e.has_fx and not group[keep].has_fx then keep = i
    elseif e.has_fx == group[keep].has_fx and e.track_index < group[keep].track_index then keep = i end
  end
  return keep
end

----------------------------------------------------------------------
-- Загрузка папки: какие файлы брать и в каком порядке (чистые функции)
----------------------------------------------------------------------
local function is_audio_file(name)
  local ext = name:match("%.([^./" .. string.char(92) .. "]+)$")
  return ext ~= nil and AUDIO_EXT[ext:lower()] == true and name:sub(1, 2) ~= "._"
end

-- название дорожки из имени файла: без расширения
local function base_name(path)
  local n = path:match("([^/" .. string.char(92) .. "]+)$") or path
  return (n:gsub("%.[^.]*$", ""))
end

-- ключ «естественного» порядка: числа сравниваются как числа (2 раньше 10), регистр не важен
local function natural_key(path)
  return (path:lower():gsub("%d+", function(d) return string.rep("0", math.max(0, 12 - #d)) .. d end))
end

----------------------------------------------------------------------
-- Библиотечный режим для тестов: отдать чистые функции и не запускать скрипт
----------------------------------------------------------------------
if SSM_AUTO_PREPARE_LIBRARY then
  return { name_tokens = name_tokens, pan_side = pan_side, classify = classify, track_category = track_category, folder_matches = folder_matches,
    build_tree = build_tree, flatten_tree = flatten_tree, plan_sort = plan_sort, apply_sort = apply_sort, find_folder = find_folder,
    pick_keeper = pick_keeper, is_audio_file = is_audio_file, base_name = base_name, natural_key = natural_key }
end

----------------------------------------------------------------------
-- Проект: что есть и что нужно сделать
----------------------------------------------------------------------
local function track_name(tr)
  local _, n = reaper.GetTrackName(tr)
  return n or ""
end

-- первый настоящий (не вложенный) источник тейка
local function root_source(take)
  local src = reaper.GetMediaItemTake_Source(take)
  for _ = 1, 4 do
    local parent = src and reaper.GetMediaSourceParent(src)
    if not parent then break end
    src = parent
  end
  return src
end

local function source_path(src)
  local get_name = reaper.GetMediaSourceFileName
  if not (src and get_name) then return nil end
  local a, b = get_name(src, "")
  local name = (type(a) == "string" and a ~= "") and a or ((type(b) == "string" and b ~= "") and b or nil)
  return name
end

local function item_name(take)
  return select(2, reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)) or ""
end

-- стерео-айтемы, которые нужно проверить (активный тейк, не MIDI, источник из двух каналов, режим канала обычный)
local function collect_stereo_items()
  local jobs = {}
  for ti = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, ti)
    for ii = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local item = reaper.GetTrackMediaItem(tr, ii)
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local src = root_source(take)
        local ch = src and reaper.GetMediaSourceNumChannels(src) or 0
        local mode = reaper.GetMediaItemTakeInfo_Value(take, "I_CHANMODE")
        if ch == 2 and mode == 0 then
          jobs[#jobs + 1] = {
            track = tr, item = item, take = take,
            pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
            len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
            tname = track_name(tr), iname = item_name(take),
          }
        end
      end
    end
  end
  return jobs
end

-- куски (начало в времени проекта, длина), которые читаются у айтема
local function job_windows(job)
  local wins = {}
  if job.len <= WIN_SEC * MAX_WINDOWS then
    local t = 0
    while t < job.len - 1e-6 do
      wins[#wins + 1] = { job.pos + t, math.min(WIN_SEC, job.len - t) }
      t = t + WIN_SEC
    end
  else
    for k = 0, MAX_WINDOWS - 1 do
      wins[#wins + 1] = { job.pos + (job.len - WIN_SEC) * k / (MAX_WINDOWS - 1), WIN_SEC }
    end
  end
  return wins
end

-- панорама по названиям: список { track, name, side, mode }
local function plan_pans()
  local pans = {}
  for ti = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, ti)
    local name = track_name(tr)
    local side = pan_side(name)
    if side then
      local pm = reaper.GetMediaTrackInfo_Value(tr, "I_PANMODE")
      local want = side * PAN_AMOUNT
      local cur, cur2
      if pm == 6 then
        cur, cur2 = reaper.GetMediaTrackInfo_Value(tr, "D_DUALPANL"), reaper.GetMediaTrackInfo_Value(tr, "D_DUALPANR")
      else
        cur = reaper.GetMediaTrackInfo_Value(tr, "D_PAN")
      end
      local already = math.abs(cur - want) < 0.005 and (cur2 == nil or math.abs(cur2 - want) < 0.005)
      pans[#pans + 1] = { track = tr, name = name, side = side, want = want, dual = (pm == 6), already = already, cur = cur }
    end
  end
  return pans
end

-- аудио-айтемы для поиска дубликатов, разложенные по корзинам "начало|длина|каналы|длина источника": сравниваются только внутри корзины
local function collect_dup_buckets()
  local buckets, order = {}, {}
  for ti = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, ti)
    for ii = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local item = reaper.GetTrackMediaItem(tr, ii)
      local take = reaper.GetActiveTake(item)
      if take and not reaper.TakeIsMIDI(take) then
        local src = root_source(take)
        if src then
          local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
          local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
          local ch = reaper.GetMediaSourceNumChannels(src) or 0
          local slen = reaper.GetMediaSourceLength and (reaper.GetMediaSourceLength(src)) or 0
          local key = string.format("%d|%d|%d|%d", math.floor(pos / DUP_POS_TOL + 0.5), math.floor(len / DUP_POS_TOL + 0.5), ch, math.floor((slen or 0) / DUP_POS_TOL + 0.5))
          local rec = {
            item = item, take = take, track = tr, track_index = ti, pos = pos, len = len, ch = ch,
            path = source_path(src), offs = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
            rate = reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
            tname = track_name(tr), iname = item_name(take),
          }
          if not buckets[key] then buckets[key] = {}; order[#order + 1] = key end
          local b = buckets[key]
          b[#b + 1] = rec
        end
      end
    end
  end
  local list = {}
  for _, key in ipairs(order) do
    local b = buckets[key]
    -- только корзины с айтемами на РАЗНЫХ дорожках: два одинаковых айтема на одной дорожке - обычное дело (повтор)
    local tracks = {}
    local n_tracks = 0
    for _, e in ipairs(b) do if not tracks[e.track] then tracks[e.track] = true; n_tracks = n_tracks + 1 end end
    if #b >= 2 and n_tracks >= 2 then list[#list + 1] = b end
  end
  return list
end

-- свёртка звука айтема по HASH_WINDOWS кускам (одинаковые файлы дают одинаковое число); nil - тишина или не прочиталось
local function audio_hash(rec, arr)
  local AA = reaper.CreateTakeAudioAccessor(rec.take)
  if not AA then return nil end
  local h, energy = 5381, 0
  local ok_any = false
  local span = math.max(0, rec.len - HASH_FRAMES / ANALYSE_SR)
  for k = 0, HASH_WINDOWS - 1 do
    local t0 = rec.pos + (HASH_WINDOWS > 1 and span * k / (HASH_WINDOWS - 1) or 0)
    local ok = reaper.GetAudioAccessorSamples(AA, ANALYSE_SR, 2, t0, HASH_FRAMES, arr)
    if ok and ok > 0 then
      ok_any = true
      local tb = nil
      local fine, res = pcall(function() return arr:table() end)
      if fine and type(res) == "table" then tb = res end
      for i = 1, HASH_FRAMES * 2 do
        local v = tb and tb[i] or arr[i] or 0
        energy = energy + v * v
        h = (h * 33 + math.floor(v * 8388608 + 0.5)) % 4294967296
      end
    end
  end
  reaper.DestroyAudioAccessor(AA)
  if not ok_any or energy < 1e-12 then return nil end
  return h
end

-- состояние дорожки для решения «удалять ли дорожку целиком»: нет плагинов, посылов, приёмов, это не папка
local function track_deletable(tr, item_count)
  if item_count ~= 1 then return false, "на дорожке есть и другие айтемы" end
  if (reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") or 0) > 0 then return false, "дорожка - папка" end
  if (reaper.TrackFX_GetCount(tr) or 0) > 0 or (reaper.TrackFX_GetRecCount and (reaper.TrackFX_GetRecCount(tr) or 0) > 0) then return false, "на дорожке плагины" end
  if reaper.GetTrackNumSends then
    if (reaper.GetTrackNumSends(tr, 0) or 0) > 0 or (reaper.GetTrackNumSends(tr, -1) or 0) > 0 then return false, "у дорожки посылы" end
  end
  return true
end

-- Группы одинаковых айтемов -> список { keep = rec, drop = rec, delete_track = bool, why = текст }
local function find_duplicates(buckets, hashes)
  local result = {}
  for _, b in ipairs(buckets) do
    -- одинаковые: тот же файл и то же место в нём, либо одинаковый звук по свёртке
    local groups = {}
    for _, e in ipairs(b) do
      local placed = false
      for _, g in ipairs(groups) do
        local f = g[1]
        local same_file = e.path and f.path and e.path:lower() == f.path:lower() and math.abs((e.offs or 0) - (f.offs or 0)) < DUP_POS_TOL
          and math.abs((e.rate or 1) - (f.rate or 1)) < 1e-6
        local same_audio = hashes[e] and hashes[f] and hashes[e] == hashes[f]
        if same_file or same_audio then
          if e.track ~= f.track then g[#g + 1] = e; placed = true; break end
        end
      end
      if not placed then groups[#groups + 1] = { e } end
    end
    for _, g in ipairs(groups) do
      if #g >= 2 then
        for _, e in ipairs(g) do
          e.has_fx = (reaper.TrackFX_GetCount(e.track) or 0) > 0
        end
        local keep = pick_keeper(g)
        for i, e in ipairs(g) do
          if i ~= keep then
            local cnt = reaper.CountTrackMediaItems(e.track)
            local can, why = track_deletable(e.track, cnt)
            result[#result + 1] = { keep = g[keep], drop = e, delete_track = can, why = why }
          end
        end
      end
    end
  end
  table.sort(result, function(a, b) return a.drop.track_index < b.drop.track_index end)
  return result
end

----------------------------------------------------------------------
-- Загрузка файлов из папки в проект
----------------------------------------------------------------------
-- Папка через диалог ОС (js_ReaScriptAPI) или ввод пути вручную. -> путь или nil
local function choose_folder()
  local last = reaper.GetExtState(EXT_SECTION, "last_dir")
  local dir
  if reaper.JS_Dialog_BrowseForFolder then
    local rv, folder = reaper.JS_Dialog_BrowseForFolder("Папка с аудиофайлами для проекта", last or "")
    if rv == 1 and folder and folder ~= "" then dir = folder end
  else
    local ok, val = reaper.GetUserInputs("Папка с аудиофайлами", 1, "Путь к папке,extrawidth=420", last or "")
    if ok and val and val:match("%S") then dir = (val:gsub("^%s+", ""):gsub("%s+$", "")) end
  end
  if dir then reaper.SetExtState(EXT_SECTION, "last_dir", dir, true) end
  return dir
end

-- Аудиофайлы папки (с вложенными, если включено) в естественном порядке имён. -> список путей
local function scan_audio_files(dir)
  local sep = dir:find(string.char(92), 1, true) and string.char(92) or "/"
  local found = {}
  local function walk(d, depth)
    reaper.EnumerateFiles(d, -1) -- сбросить кэш каталога
    reaper.EnumerateSubdirectories(d, -1)
    local i = 0
    while true do
      local fn = reaper.EnumerateFiles(d, i)
      if not fn then break end
      i = i + 1
      if is_audio_file(fn) then found[#found + 1] = d:gsub("[/" .. string.char(92) .. "]+$", "") .. sep .. fn end
    end
    if IMPORT_SUBFOLDERS and depth < IMPORT_DEPTH then
      local j = 0
      while true do
        local sn = reaper.EnumerateSubdirectories(d, j)
        if not sn then break end
        j = j + 1
        local low = sn:lower()
        if sn:sub(1, 1) ~= "." and low ~= "backups" and low ~= "peaks" then walk(d:gsub("[/" .. string.char(92) .. "]+$", "") .. sep .. sn, depth + 1) end
      end
    end
  end
  walk(dir, 0)
  table.sort(found, function(a, b) return natural_key(a) < natural_key(b) end)
  return found
end

-- Загрузка: по дорожке на файл в конце проекта, айтем с нуля; уже загруженные файлы пропускаются. Свой шаг Undo. -> загружено, пропущено (уже есть), не удалось
local function import_files(paths)
  local have = {}
  for ti = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, ti)
    for ii = 0, reaper.CountTrackMediaItems(tr) - 1 do
      local take = reaper.GetActiveTake(reaper.GetTrackMediaItem(tr, ii))
      if take and not reaper.TakeIsMIDI(take) then
        local pth = source_path(root_source(take))
        if pth then have[pth:lower()] = true end
      end
    end
  end
  local n_new, n_have, n_fail = 0, 0, 0
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for _, path in ipairs(paths) do
    if have[path:lower()] then
      n_have = n_have + 1
    else
      local src = reaper.PCM_Source_CreateFromFile(path)
      local len = src and (reaper.GetMediaSourceLength(src)) or 0
      if src and len and len > 0 then
        local idx = reaper.CountTracks(0)
        reaper.InsertTrackAtIndex(idx, true)
        local tr = reaper.GetTrack(0, idx)
        local name = base_name(path)
        reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
        local item = reaper.AddMediaItemToTrack(tr)
        local take = reaper.AddTakeToMediaItem(item)
        reaper.SetMediaItemTake_Source(take, src)
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", 0)
        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len)
        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", name, true)
        n_new = n_new + 1
      else
        n_fail = n_fail + 1
      end
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM: загрузка файлов из папки", -1)
  return n_new, n_have, n_fail
end

----------------------------------------------------------------------
-- Модель окна согласия: группы изменений с галочками
----------------------------------------------------------------------
local run = {}

local function shorten(s, n)
  if #s <= n then return s end
  return s:sub(1, n - 3) .. "..."
end

local function build_groups()
  local groups = {}
  local mono = {}
  for _, j in ipairs(run.jobs) do
    local r = j.result
    if r and r.kind == "mono" then
      mono[#mono + 1] = { text = string.format("%s: %s (%s)", shorten(j.tname .. " / " .. j.iname, 60), r.pick == "L" and "левый канал" or "правый канал", r.text), checked = true, data = j }
    end
  end
  if #mono > 0 then groups[#groups + 1] = { id = "mono", title = "Стерео, которое на деле моно: включить один канал", rows = mono, open = true } end

  local pans = {}
  for _, p in ipairs(run.pans) do
    if not p.already then
      pans[#pans + 1] = { text = string.format("%s: %s", shorten(p.name, 60), p.side < 0 and "влево" or "вправо"), checked = true, data = p }
    end
  end
  if #pans > 0 then groups[#groups + 1] = { id = "pan", title = "Панорама по названию трека", rows = pans, open = true } end

  local dups = {}
  for _, d in ipairs(run.dups) do
    local text
    if d.delete_track then
      text = string.format("удалить дорожку «%s» (одинаковый звук с «%s»)", shorten(d.drop.tname, 40), shorten(d.keep.tname, 40))
    else
      text = string.format("удалить айтем на «%s» (одинаковый звук с «%s»; дорожка остаётся: %s)", shorten(d.drop.tname, 34), shorten(d.keep.tname, 34), d.why or "")
    end
    dups[#dups + 1] = { text = text, checked = true, data = d }
  end
  if #dups > 0 then groups[#groups + 1] = { id = "dups", title = "Дубликаты: один и тот же звук в одном месте на разных дорожках", rows = dups, open = true } end

  local sorts = {}
  for _, g in ipairs(run.sort_groups) do
    local names = {}
    for i, node in ipairs(g.tracks) do
      if i <= 4 then names[#names + 1] = node.name end
    end
    local more = #g.tracks > 4 and string.format(" и ещё %d", #g.tracks - 4) or ""
    local newtxt = (g.new_top or g.new_sub) and " [новая папка]" or ""
    sorts[#sorts + 1] = { text = string.format("%s%s: %d - %s%s", g.label, newtxt, #g.tracks, shorten(table.concat(names, ", "), 70), more), checked = true, data = g }
  end
  if #sorts > 0 then groups[#groups + 1] = { id = "folders", title = "Раскладка дорожек по папкам", rows = sorts, open = true } end
  return groups
end

local function group_state(g)
  local on = 0
  for _, r in ipairs(g.rows) do if r.checked then on = on + 1 end end
  return on, #g.rows
end

local function selected_total(groups)
  local n = 0
  for _, g in ipairs(groups) do local on = group_state(g); n = n + on end
  return n
end

-- Изменения, отмеченные галочками, по функциям
local function selection(groups)
  local sel = { mono = {}, pan = {}, dups = {}, folders = {} }
  for _, g in ipairs(groups) do
    for _, r in ipairs(g.rows) do
      if r.checked then sel[g.id][#sel[g.id] + 1] = r.data end
    end
  end
  return sel
end

----------------------------------------------------------------------
-- Применение
----------------------------------------------------------------------
local function valid_track(tr)
  if reaper.ValidatePtr2 then return reaper.ValidatePtr2(0, tr, "MediaTrack*") end
  return true
end

-- плоский список всех дорожек проекта для дерева
local function read_track_list()
  local list = {}
  for ti = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, ti)
    list[#list + 1] = { ref = tr, name = track_name(tr), fd = math.floor((reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") or 0) + 0.5),
      items = reaper.CountTrackMediaItems(tr) }
  end
  return list
end

local function track_index(tr) return math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") + 0.5) - 1 end

local function remove_node(root, ref)
  local function walk(node)
    for i, ch in ipairs(node.children) do
      if ch.ref == ref then table.remove(node.children, i); return true end
      if walk(ch) then return true end
    end
    return false
  end
  return walk(root)
end

-- Всё выбранное: моно, панорама, затем удаление дубликатов и раскладка по папкам. -> текст итога
local function apply_selected(sel)
  local out = {}
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  -- 1) моно и панорама - свойства, ничего не удаляют
  local deleted_items = {}
  for _, d in ipairs(sel.dups) do deleted_items[d.drop.item] = true end
  local n_mono = 0
  for _, j in ipairs(sel.mono) do
    if not deleted_items[j.item] then
      reaper.SetMediaItemTakeInfo_Value(j.take, "I_CHANMODE", j.result.pick == "L" and 3 or 4)
      if reaper.UpdateItemInProject then reaper.UpdateItemInProject(j.item) end
      n_mono = n_mono + 1
    end
  end
  local n_pan = 0
  for _, p in ipairs(sel.pan) do
    if p.dual then
      reaper.SetMediaTrackInfo_Value(p.track, "D_DUALPANL", p.want)
      reaper.SetMediaTrackInfo_Value(p.track, "D_DUALPANR", p.want)
    else
      reaper.SetMediaTrackInfo_Value(p.track, "D_PAN", p.want)
    end
    n_pan = n_pan + 1
  end
  if n_mono > 0 then out[#out + 1] = string.format("моно: %d", n_mono) end
  if n_pan > 0 then out[#out + 1] = string.format("панорама: %d", n_pan) end

  -- 2) дубликаты: удаляем айтемы; дорожки, ставшие пустыми, - вместе с деревом (чтобы не сломать папки)
  local doomed = {}
  local n_items, n_tracks = 0, 0
  for _, d in ipairs(sel.dups) do
    reaper.DeleteTrackMediaItem(d.drop.track, d.drop.item)
    n_items = n_items + 1
    if d.delete_track and not doomed[d.drop.track] then doomed[d.drop.track] = true; n_tracks = n_tracks + 1 end
  end
  if n_items > 0 then
    out[#out + 1] = string.format("дубликатов удалено: %d (дорожек: %d)", n_items, n_tracks)
  end

  -- 3) дерево дорожек: убрать удаляемые, разложить по папкам, выставить порядок и глубину папок
  local need_tree = n_tracks > 0 or #sel.folders > 0
  if need_tree then
    local root = build_tree(read_track_list())
    for tr in pairs(doomed) do remove_node(root, tr) end
    local n_moved, created = 0, {}
    if #sel.folders > 0 then
      local keys = {}
      for _, g in ipairs(sel.folders) do keys[g.key] = true end
      local fresh = {}
      for _, g in ipairs(plan_sort(root)) do if keys[g.key] then fresh[#fresh + 1] = g end end -- план заново: после удалений дорожки могли исчезнуть
      n_moved, created = apply_sort(root, fresh)
    end
    -- удалить ненужные дорожки (после этого глубину задаём заново по дереву)
    local saved_sel = {}
    for ti = 0, reaper.CountTracks(0) - 1 do
      local tr = reaper.GetTrack(0, ti)
      if (reaper.GetMediaTrackInfo_Value(tr, "I_SELECTED") or 0) > 0 then saved_sel[#saved_sel + 1] = tr end
    end
    for tr in pairs(doomed) do reaper.DeleteTrack(tr) end
    -- новые папки: создаём дорожки в конце проекта и называем
    for _, node in ipairs(created) do
      local idx = reaper.CountTracks(0)
      reaper.InsertTrackAtIndex(idx, true)
      node.ref = reaper.GetTrack(0, idx)
      reaper.GetSetMediaTrackInfo_String(node.ref, "P_NAME", node.name, true)
    end
    local flat = flatten_tree(root)
    -- порядок: каждую дорожку ставим на своё место (кто уже стоит правильно - не трогаем)
    for i, e in ipairs(flat) do
      if track_index(e.node.ref) ~= i - 1 then
        if reaper.SetOnlyTrackSelected then reaper.SetOnlyTrackSelected(e.node.ref) end
        reaper.ReorderSelectedTracks(i - 1, 0)
      end
    end
    for _, e in ipairs(flat) do reaper.SetMediaTrackInfo_Value(e.node.ref, "I_FOLDERDEPTH", e.fd) end
    -- проверка: порядок дорожек в проекте должен совпасть с рассчитанным (REAPER мог переставить иначе, чем ожидается)
    local bad = 0
    for i, e in ipairs(flat) do if track_index(e.node.ref) ~= i - 1 then bad = bad + 1 end end
    if bad > 0 then out[#out + 1] = string.format("ВНИМАНИЕ: порядок %d дорожек отличается от расчётного - проверьте проект или отмените (Ctrl+Z)", bad) end
    -- выделение как было
    for ti = 0, reaper.CountTracks(0) - 1 do reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, ti), "I_SELECTED", 0) end
    for _, tr in ipairs(saved_sel) do
      if not doomed[tr] then reaper.SetMediaTrackInfo_Value(tr, "I_SELECTED", 1) end
    end
    if n_moved > 0 then out[#out + 1] = string.format("по папкам: %d дорожек (новых папок: %d)", n_moved, #created) end
  end

  reaper.PreventUIRefresh(-1)
  if reaper.TrackList_AdjustWindows then reaper.TrackList_AdjustWindows(false) end
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM: автоподготовка проекта", -1)
  return #out > 0 and ("Готово: " .. table.concat(out, "; ") .. ".\nОдин шаг Undo (Ctrl+Z) вернёт всё как было.") or "Ничего не изменено."
end

----------------------------------------------------------------------
-- Окно: ход анализа и окно согласия с галочками (gfx)
----------------------------------------------------------------------
local WIN_W, WIN_H = 900, 640
local col = {
  bg = { 0.07, 0.09, 0.13 }, panel = { 0.10, 0.13, 0.19 }, group = { 0.12, 0.16, 0.24 }, text = { 0.91, 0.93, 0.96 },
  dim = { 0.58, 0.64, 0.73 }, accent = { 0.10, 0.45, 0.90 }, border = { 0.22, 0.28, 0.38 }, off = { 0.16, 0.19, 0.26 },
}
local function set_color(c, a) gfx.set(c[1], c[2], c[3], a or 1) end
local function text_at(str, x, y, c) set_color(c); gfx.x, gfx.y = x, y; gfx.drawstr(str) end

local function clip(str, max_w)
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

-- геометрия окна согласия (и для тестов)
local ROW_H, GRP_H, HEAD_H, FOOT_H = 30, 40, 78, 76
local function review_geometry(w, h)
  local g = { w = w, h = h, pad = 18, head_h = HEAD_H, foot_h = FOOT_H, list_y = HEAD_H, list_h = h - HEAD_H - FOOT_H, row_h = ROW_H, grp_h = GRP_H }
  g.btn_w, g.btn_h = 190, 42
  g.ok_x, g.ok_y = w - g.pad - g.btn_w, h - FOOT_H + 18
  g.cancel_x = g.ok_x - 12 - 130
  g.cancel_w = 130
  g.all_x, g.none_x = g.pad, g.pad + 120
  g.link_y = h - FOOT_H + 26
  g.cb = 20
  return g
end
if type(SSM_AP_GEOMETRY_HOOK) == "function" then SSM_AP_GEOMETRY_HOOK(review_geometry) end -- только для тестов

local function draw_checkbox(x, y, size, on, partial)
  set_color(on and col.accent or col.off); gfx.rect(x, y, size, size, 1)
  set_color(col.border); gfx.rect(x, y, size, size, 0)
  if on then
    set_color(col.text)
    gfx.line(x + 4, y + size / 2, x + size / 2 - 1, y + size - 5)
    gfx.line(x + 4, y + size / 2 + 1, x + size / 2 - 1, y + size - 4)
    gfx.line(x + size / 2 - 1, y + size - 5, x + size - 4, y + 4)
    gfx.line(x + size / 2 - 1, y + size - 4, x + size - 4, y + 5)
  elseif partial then
    set_color(col.accent); gfx.rect(x + 5, y + size / 2 - 1, size - 10, 3, 1)
  end
end

local function draw_progress()
  if not (gfx and gfx.init) then return true end
  local c = gfx.getchar()
  if c < 0 or c == 27 then return false end -- окно закрыто или Esc: отмена
  local g = review_geometry(gfx.w, gfx.h)
  set_color(col.bg); gfx.rect(0, 0, gfx.w, gfx.h, 1)
  gfx.setfont(1, "Arial", 18)
  text_at(run.stage_title or "Проверка проекта", g.pad, 24, col.text)
  gfx.setfont(1, "Arial", 15)
  text_at(string.format("%d из %d", math.min(run.done + 1, run.total), run.total), g.pad, 56, col.dim)
  text_at(clip(run.current or "", gfx.w - 2 * g.pad), g.pad, 82, col.dim)
  set_color(col.off); gfx.rect(g.pad, 112, gfx.w - 2 * g.pad, 10, 1)
  set_color(col.accent); gfx.rect(g.pad, 112, (gfx.w - 2 * g.pad) * (run.done / math.max(1, run.total)), 10, 1)
  text_at("Esc - отмена", g.pad, 136, col.dim)
  gfx.update()
  return true
end

local review = { groups = nil, scroll = 0, last_cap = 0 }

-- Кадр окна согласия. Возвращает "apply", "cancel" или nil
local function draw_review()
  local c = gfx.getchar()
  if c < 0 or c == 27 then return "cancel" end
  local g = review_geometry(gfx.w, gfx.h)
  local cap = gfx.mouse_cap
  local click = (cap & 1) == 1 and (review.last_cap & 1) == 0
  review.last_cap = cap
  local mx, my = gfx.mouse_x, gfx.mouse_y
  local function inside(x, y, w, h) return mx >= x and mx < x + w and my >= y and my < y + h end
  local total_sel = selected_total(review.groups)
  if c == 13 and total_sel > 0 then return "apply" end

  -- высота содержимого и прокрутка
  local content_h = 0
  for _, gr in ipairs(review.groups) do
    content_h = content_h + g.grp_h
    if gr.open then content_h = content_h + #gr.rows * g.row_h end
  end
  local max_scroll = math.max(0, content_h - g.list_h)
  if gfx.mouse_wheel ~= 0 then
    review.scroll = review.scroll - (gfx.mouse_wheel / 120) * g.row_h * 3
    gfx.mouse_wheel = 0
  end
  review.scroll = math.max(0, math.min(review.scroll, max_scroll))

  set_color(col.bg); gfx.rect(0, 0, g.w, g.h, 1)
  -- строки списка
  local y = g.list_y - review.scroll
  local in_list = my >= g.list_y and my < g.list_y + g.list_h
  for _, gr in ipairs(review.groups) do
    local on, n = group_state(gr)
    if y + g.grp_h > g.list_y and y < g.list_y + g.list_h then
      set_color(col.group); gfx.rect(0, y, g.w, g.grp_h, 1)
      draw_checkbox(g.pad, y + (g.grp_h - g.cb) / 2, g.cb, on == n, on > 0 and on < n)
      gfx.setfont(1, "Arial", 17)
      local ax, ay = g.pad + g.cb + 18, y + g.grp_h / 2 -- стрелка: вниз - список открыт, вправо - свёрнут
      set_color(col.dim)
      if gr.open then gfx.triangle(ax - 5, ay - 3, ax + 5, ay - 3, ax, ay + 4) else gfx.triangle(ax - 3, ay - 5, ax - 3, ay + 5, ax + 4, ay) end
      text_at(clip(gr.title, g.w - 2 * g.pad - 170), g.pad + g.cb + 34, y + (g.grp_h - 17) / 2 - 1, col.text)
      local cnt = string.format("%d из %d", on, n)
      gfx.setfont(1, "Arial", 15)
      text_at(cnt, g.w - g.pad - gfx.measurestr(cnt), y + (g.grp_h - 15) / 2, col.dim)
      if click and in_list and inside(0, y, g.w, g.grp_h) then
        if inside(g.pad - 4, y, g.cb + 8, g.grp_h) then
          local want = on < n
          for _, r in ipairs(gr.rows) do r.checked = want end
        else
          gr.open = not gr.open
        end
      end
    end
    y = y + g.grp_h
    if gr.open then
      for i, r in ipairs(gr.rows) do
        if y + g.row_h > g.list_y and y < g.list_y + g.list_h then
          if i % 2 == 0 then set_color(col.panel); gfx.rect(0, y, g.w, g.row_h, 1) end
          draw_checkbox(g.pad + 22, y + (g.row_h - g.cb + 4) / 2 - 2, g.cb - 4, r.checked)
          gfx.setfont(1, "Arial", 15)
          text_at(clip(r.text, g.w - g.pad - 22 - g.cb - 24), g.pad + 22 + g.cb + 8, y + (g.row_h - 15) / 2 - 1, r.checked and col.text or col.dim)
          if click and in_list and inside(0, y, g.w, g.row_h) then r.checked = not r.checked end
        end
        y = y + g.row_h
      end
    end
  end
  -- полоса прокрутки
  if max_scroll > 0 then
    local th = math.max(24, g.list_h * g.list_h / content_h)
    local ty = g.list_y + (g.list_h - th) * (review.scroll / max_scroll)
    set_color(col.border); gfx.rect(g.w - 8, ty, 5, th, 1)
  end
  -- шапка и подвал перекрывают выступающее
  set_color(col.bg); gfx.rect(0, 0, g.w, g.head_h, 1)
  gfx.setfont(1, "Arial", 22)
  text_at("Что сделать в проекте", g.pad, 16, col.text)
  gfx.setfont(1, "Arial", 15)
  text_at("Снимите галочки с того, что менять не нужно. Применится только отмеченное, одним шагом Undo.", g.pad, 48, col.dim)
  set_color(col.panel); gfx.rect(0, g.h - g.foot_h, g.w, g.foot_h, 1)
  set_color(col.border); gfx.rect(0, g.h - g.foot_h, g.w, 1, 1)
  -- ссылки «отметить всё / снять всё»
  gfx.setfont(1, "Arial", 15)
  local lx, ly = g.all_x, g.link_y
  text_at("Отметить всё", lx, ly, col.accent)
  text_at("Снять всё", g.none_x, ly, col.accent)
  if click then
    if inside(g.all_x - 4, ly - 6, 110, 30) then for _, gr in ipairs(review.groups) do for _, r in ipairs(gr.rows) do r.checked = true end end end
    if inside(g.none_x - 4, ly - 6, 90, 30) then for _, gr in ipairs(review.groups) do for _, r in ipairs(gr.rows) do r.checked = false end end end
  end
  -- кнопки
  local act
  local function button(x, yb, w, h, label, enabled, primary)
    local hov = enabled and inside(x, yb, w, h)
    set_color(not enabled and col.off or (primary and (hov and { 0.18, 0.52, 0.97 } or col.accent) or (hov and col.group or col.panel)))
    gfx.rect(x, yb, w, h, 1)
    set_color(col.border); gfx.rect(x, yb, w, h, 0)
    gfx.setfont(1, "Arial", 17)
    text_at(label, x + (w - gfx.measurestr(label)) / 2, yb + (h - 17) / 2 - 1, enabled and col.text or col.dim)
    return hov and click
  end
  if button(g.cancel_x, g.ok_y, g.cancel_w, g.btn_h, "Отмена", true, false) then act = "cancel" end
  if button(g.ok_x, g.ok_y, g.btn_w, g.btn_h, string.format("Применить (%d)", total_sel), total_sel > 0, true) then act = "apply" end
  gfx.update()
  return act
end

----------------------------------------------------------------------
-- Ход работы: порции анализа, затем окно согласия
----------------------------------------------------------------------
-- массив REAPER -> таблица Lua (n значений)
local function array_to_table(arr, n)
  local ok, t = pcall(function() return arr:table() end)
  if ok and type(t) == "table" then return t end
  local t2 = {}
  for i = 1, n do
    local ok2, v = pcall(function() return arr[i] end)
    t2[i] = (ok2 and v) or 0
  end
  return t2
end

local function finish_window()
  if gfx and gfx.quit then pcall(gfx.quit) end
end

local function on_review_done(action)
  finish_window()
  if action ~= "apply" then return end
  local msg = apply_selected(selection(review.groups))
  reaper.ShowMessageBox(msg, TITLE, 0)
end

local function start_review()
  review.groups = build_groups()
  review.scroll, review.last_cap = 0, 0
  if #review.groups == 0 then
    finish_window()
    reaper.ShowMessageBox("Менять нечего: проект в порядке.\n\n" .. (run.notes or ""), TITLE, 0)
    return
  end
  if type(SSM_AP_REVIEW_HOOK) == "function" then SSM_AP_REVIEW_HOOK(review) end -- только для тестов
  if not (gfx and gfx.init) then return end
  gfx.init(TITLE, WIN_W, WIN_H)
  local function frame()
    local act = draw_review()
    if act then on_review_done(act); return end
    reaper.defer(frame)
  end
  frame()
end

-- итоговые замечания про то, что оставлено без изменений
local function make_notes()
  local kept, odd, silent = 0, 0, 0
  for _, j in ipairs(run.jobs) do
    local r = j.result
    if r and r.kind == "stereo" then kept = kept + 1
    elseif r and (r.kind == "panned" or r.kind == "inverted") then odd = odd + 1
    elseif r and r.kind == "silent" then silent = silent + 1 end
  end
  local notes = {}
  if kept > 0 then notes[#notes + 1] = string.format("настоящее стерео: %d (не трогаю)", kept) end
  if odd > 0 then notes[#notes + 1] = string.format("моно с панорамой или в противофазе: %d (не трогаю)", odd) end
  if silent > 0 then notes[#notes + 1] = string.format("тишина, определить нельзя: %d", silent) end
  local already = 0
  for _, p in ipairs(run.pans) do if p.already then already = already + 1 end end
  if already > 0 then notes[#notes + 1] = string.format("панорама уже стоит: %d", already) end
  return table.concat(notes, "; ")
end

-- переход к следующему этапу анализа
local function next_stage()
  if run.stage == "stereo" then
    run.stage, run.stage_title = "dups", "Поиск дубликатов"
    run.buckets = collect_dup_buckets()
    run.bidx, run.bitem, run.hashes = 1, 1, {}
    run.total = 0
    for _, b in ipairs(run.buckets) do run.total = run.total + #b end
    run.done = 0
    if run.total == 0 then return next_stage() end
  elseif run.stage == "dups" then
    run.dups = find_duplicates(run.buckets, run.hashes)
    run.stage = "folders"
    local root = build_tree(read_track_list())
    run.sort_groups = plan_sort(root)
    run.notes = make_notes()
    return "review"
  end
end

-- один заход анализа: работаем SLICE_SEC, потом возвращаем управление
local function tick()
  if not draw_progress() then -- окно прогресса закрыли
    if run.job and run.job.AA then reaper.DestroyAudioAccessor(run.job.AA) end
    finish_window()
    return
  end
  local t_end = reaper.time_precise() + SLICE_SEC
  repeat
    if run.stage == "stereo" then
      local job = run.jobs[run.idx]
      if not job then
        if next_stage() == "review" then start_review(); return end
      else
        run.job = job
        run.current = shorten(job.tname .. " / " .. job.iname, 70)
        if not job.AA then
          job.AA = reaper.CreateTakeAudioAccessor(job.take)
          job.wins = job_windows(job)
          job.w = 1
          job.sLL, job.sRR, job.sLR, job.frames = 0, 0, 0, 0
        end
        local win = job.wins[job.w]
        if not win or not job.AA then
          if job.AA then reaper.DestroyAudioAccessor(job.AA) end
          job.AA = nil
          job.result = classify(job.sLL, job.sRR, job.sLR, job.frames)
          run.idx, run.done = run.idx + 1, run.done + 1
        else
          local n = math.max(1, math.floor(win[2] * ANALYSE_SR))
          if not run.arr then run.arr = reaper.new_array(math.floor(WIN_SEC * ANALYSE_SR) * 2 + 4) end
          local ok = reaper.GetAudioAccessorSamples(job.AA, ANALYSE_SR, 2, win[1], n, run.arr)
          if ok and ok > 0 then
            local tb = array_to_table(run.arr, n * 2)
            local sLL, sRR, sLR = 0, 0, 0
            for i = 1, n * 2, 2 do
              local l, r = tb[i], tb[i + 1]
              sLL, sRR, sLR = sLL + l * l, sRR + r * r, sLR + l * r
            end
            job.sLL, job.sRR, job.sLR, job.frames = job.sLL + sLL, job.sRR + sRR, job.sLR + sLR, job.frames + n
          end
          job.w = job.w + 1
        end
      end
    elseif run.stage == "dups" then
      local b = run.buckets[run.bidx]
      if not b then
        if next_stage() == "review" then start_review(); return end
      else
        local rec = b[run.bitem]
        run.current = shorten(rec.tname .. " / " .. rec.iname, 70)
        -- по файлу дубликаты видны без чтения звука; звук читается, только если у айтемов разные файлы
        local need_audio = false
        for _, other in ipairs(b) do
          if other ~= rec and not (other.path and rec.path and other.path:lower() == rec.path:lower()) then need_audio = true; break end
        end
        if need_audio then
          if not run.harr then run.harr = reaper.new_array(HASH_FRAMES * 2 + 4) end
          run.hashes[rec] = audio_hash(rec, run.harr)
        end
        run.bitem, run.done = run.bitem + 1, run.done + 1
        if run.bitem > #b then run.bidx, run.bitem = run.bidx + 1, 1 end
      end
    else
      return
    end
  until reaper.time_precise() >= t_end
  reaper.defer(tick)
end

-- Перед проверкой: предложить загрузить файлы из папки. -> false, если работу нужно прекратить
local function maybe_import()
  local empty = reaper.CountTracks(0) == 0
  local ask
  if empty then
    ask = reaper.ShowMessageBox("В проекте нет дорожек.\n\nВыбрать папку с аудиофайлами и загрузить их в проект?\nПосле загрузки скрипт сам проверит дорожки (моно, панорама, дубликаты, папки).", TITLE, 4)
    if ask ~= 6 then return false end
  else
    ask = reaper.ShowMessageBox("Загрузить в проект файлы из папки перед проверкой?\n\nДа - выбрать папку с аудиофайлами (они загрузятся новыми дорожками, потом всё будет проверено)\nНет - проверить только то, что уже в проекте\nОтмена - выйти",
      TITLE, 3)
    if ask == 2 then return false end
    if ask ~= 6 then return true end
  end
  local dir = choose_folder()
  if not dir then return not empty end
  local files = scan_audio_files(dir)
  if #files == 0 then
    reaper.ShowMessageBox("В папке нет аудиофайлов:\n" .. dir, TITLE, 0)
    return not empty
  end
  local sub = IMPORT_SUBFOLDERS and " (с вложенными папками)" or ""
  if reaper.ShowMessageBox(string.format("Найдено аудиофайлов: %d%s\nПапка: %s\n\nЗагрузить их в проект новыми дорожками?", #files, sub, dir), TITLE, 4) ~= 6 then return not empty end
  local n_new, n_have, n_fail = import_files(files)
  local note = string.format("Загружено файлов: %d.", n_new)
  if n_have > 0 then note = note .. string.format(" Уже были в проекте: %d.", n_have) end
  if n_fail > 0 then note = note .. string.format(" Не удалось открыть: %d.", n_fail) end
  if n_new == 0 and reaper.CountTracks(0) == 0 then
    reaper.ShowMessageBox(note, TITLE, 0)
    return false
  end
  return true
end

local function main()
  if not maybe_import() then return end
  if reaper.CountTracks(0) == 0 then
    reaper.ShowMessageBox("В проекте нет треков.", TITLE, 0)
    return
  end
  run = { jobs = collect_stereo_items(), pans = plan_pans(), idx = 1, done = 0, stage = "stereo", stage_title = "Проверка стерео-айтемов", dups = {}, sort_groups = {} }
  run.total = #run.jobs
  if gfx and gfx.init then gfx.init(TITLE, WIN_W, WIN_H) end
  if run.total == 0 then
    if next_stage() == "review" then start_review(); return end
  end
  reaper.defer(tick)
end

main()
