-- @description SSM_Auto_Prepare_Project
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🧹 Автоподготовка проекта: быстро наводит порядок в только что собранном проекте.
--   1) Проверяет все стерео-айтемы: если левый и правый канал на деле одинаковые (стерео-файл с моно внутри) или
--   один из каналов пустой, айтем переключается на моно: берётся левый канал (если левый пуст - правый).
--   Файлы не меняются: это обычный режим канала тейка (Take channel mode), его можно вернуть в свойствах айтема.
--   Настоящее стерео и почти-моно с разным уровнем каналов не трогаются.
--   2) Выставляет панораму треков по названию: L, Left, Лево, Л, ... - влево до упора; R, Right, Право, П, ... - вправо.
--   Если в названии есть и левое, и правое (L/R, Left Right) - трек не трогается.
--   Сначала скрипт анализирует проект и показывает, что собирается сделать, и только после «Да» применяет всё одним
--   действием (один шаг Undo, Ctrl+Z возвращает проект как был).
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
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
local MAX_LINES = 30        -- строк в окне подтверждения

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
-- Библиотечный режим для тестов: отдать чистые функции и не запускать скрипт
----------------------------------------------------------------------
if SSM_AUTO_PREPARE_LIBRARY then
  return { name_tokens = name_tokens, pan_side = pan_side, classify = classify }
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
            tname = track_name(tr),
            iname = select(2, reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)) or "",
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

----------------------------------------------------------------------
-- Анализ порциями (окно не зависает) -> подтверждение -> применение
----------------------------------------------------------------------
local run = {}

local function finish_progress()
  if gfx and gfx.quit then pcall(gfx.quit) end
end

local function draw_progress()
  if not (gfx and gfx.init) then return true end
  local c = gfx.getchar()
  if c < 0 then return false end -- окно закрыто: отмена
  gfx.set(0.12, 0.12, 0.12, 1)
  gfx.rect(0, 0, gfx.w, gfx.h, 1)
  gfx.set(0.9, 0.9, 0.9, 1)
  gfx.x, gfx.y = 14, 14
  gfx.drawstr(string.format("Проверка стерео-айтемов: %d из %d", math.min(run.done + 1, run.total), run.total))
  gfx.x, gfx.y = 14, 36
  gfx.set(0.6, 0.6, 0.6, 1)
  gfx.drawstr(run.current or "")
  gfx.set(0.25, 0.25, 0.25, 1)
  gfx.rect(14, 62, gfx.w - 28, 10, 1)
  gfx.set(0.3, 0.75, 0.45, 1)
  gfx.rect(14, 62, (gfx.w - 28) * (run.done / math.max(1, run.total)), 10, 1)
  gfx.update()
  return true
end

local function shorten(s, n)
  if #s <= n then return s end
  return s:sub(1, n - 3) .. "..."
end

local function build_report()
  local lines, summary = {}, {}
  local mono, kept, silent, odd = {}, 0, 0, {}
  for _, j in ipairs(run.jobs) do
    local r = j.result
    if r and r.kind == "mono" then mono[#mono + 1] = j
    elseif r and r.kind == "silent" then silent = silent + 1
    elseif r and (r.kind == "panned" or r.kind == "inverted") then odd[#odd + 1] = j
    else kept = kept + 1 end
  end
  local pans_todo = {}
  for _, p in ipairs(run.pans) do if not p.already then pans_todo[#pans_todo + 1] = p end end
  run.mono, run.pans_todo = mono, pans_todo

  if #mono > 0 then
    summary[#summary + 1] = string.format("Стерео, которое на деле моно: %d айтем(ов) - будет включён один канал (левый, если он не пуст).", #mono)
    for _, j in ipairs(mono) do
      lines[#lines + 1] = string.format("  моно (%s): %s", j.result.pick == "L" and "левый" or "правый", shorten(j.tname .. " / " .. j.iname, 60))
    end
  end
  if #pans_todo > 0 then
    summary[#summary + 1] = string.format("Панорама по названию: %d трек(ов).", #pans_todo)
    for _, p in ipairs(pans_todo) do
      lines[#lines + 1] = string.format("  %s: %s", p.side < 0 and "влево" or "вправо", shorten(p.name, 60))
    end
  end
  local notes = {}
  if kept > 0 then notes[#notes + 1] = string.format("настоящее стерео: %d (не трогаю)", kept) end
  if #odd > 0 then notes[#notes + 1] = string.format("моно с панорамой или в противофазе: %d (не трогаю)", #odd) end
  if silent > 0 then notes[#notes + 1] = string.format("тишина, определить нельзя: %d", silent) end
  local already = #run.pans - #pans_todo
  if already > 0 then notes[#notes + 1] = string.format("панорама уже стоит: %d", already) end
  return summary, lines, notes
end

local function show_and_apply()
  finish_progress()
  local summary, lines, notes = build_report()
  if #run.mono == 0 and #run.pans_todo == 0 then
    local msg = "Менять нечего: проект в порядке."
    if #notes > 0 then msg = msg .. "\n\n" .. table.concat(notes, "\n") end
    reaper.ShowMessageBox(msg, TITLE, 0)
    return
  end
  local shown = {}
  for i = 1, math.min(#lines, MAX_LINES) do shown[#shown + 1] = lines[i] end
  if #lines > MAX_LINES then shown[#shown + 1] = string.format("  ... и ещё %d", #lines - MAX_LINES) end
  local msg = table.concat(summary, "\n") .. "\n\n" .. table.concat(shown, "\n")
  if #notes > 0 then msg = msg .. "\n\n" .. table.concat(notes, "; ") end
  msg = msg .. "\n\nПрименить? (всё одним действием, Ctrl+Z вернёт как было)"
  if reaper.ShowMessageBox(msg, TITLE, 4) ~= 6 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for _, j in ipairs(run.mono) do
    reaper.SetMediaItemTakeInfo_Value(j.take, "I_CHANMODE", j.result.pick == "L" and 3 or 4)
    reaper.UpdateItemInProject(j.item)
  end
  for _, p in ipairs(run.pans_todo) do
    if p.dual then
      reaper.SetMediaTrackInfo_Value(p.track, "D_DUALPANL", p.want)
      reaper.SetMediaTrackInfo_Value(p.track, "D_DUALPANR", p.want)
    else
      reaper.SetMediaTrackInfo_Value(p.track, "D_PAN", p.want)
    end
  end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("SSM: автоподготовка проекта (моно и панорамы)", -1)
end

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

-- один заход анализа: работаем SLICE_SEC, потом возвращаем управление
local function tick()
  if not draw_progress() then -- окно прогресса закрыли
    if run.job and run.job.AA then reaper.DestroyAudioAccessor(run.job.AA) end
    finish_progress()
    return
  end
  local t_end = reaper.time_precise() + SLICE_SEC
  repeat
    local job = run.jobs[run.idx]
    if not job then
      show_and_apply()
      return
    end
    run.job = job
    run.current = shorten(job.tname .. " / " .. job.iname, 52)
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
  until reaper.time_precise() >= t_end
  reaper.defer(tick)
end

local function main()
  if reaper.CountTracks(0) == 0 then
    reaper.ShowMessageBox("В проекте нет треков.", TITLE, 0)
    return
  end
  run = { jobs = collect_stereo_items(), pans = plan_pans(), idx = 1, done = 0 }
  run.total = #run.jobs
  if run.total == 0 then
    show_and_apply()
    return
  end
  if gfx and gfx.init then gfx.init(TITLE, 380, 90) end
  reaper.defer(tick)
end

main()
