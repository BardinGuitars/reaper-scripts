-- @description SSM_Unused_Plugins_Remover
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🧹 Удаляет неиспользуемые плагины с дорожек ТЕКУЩЕГО проекта: байпасснутые,
--   офлайн или оба типа сразу (выбор в диалоге). Плагины, у которых есть
--   автоматизация (точки в окружении любого параметра), не удаляются, даже
--   если они в байпасе или офлайн. Другие открытые проекты не затрагиваются.
--   В диалоге можно включить мастер-трек и режим «только отчёт» - тогда
--   ничего не удаляется, а в консоль REAPER выводится список того, что было бы
--   удалено. Ход работы выводится в консоль, вся операция - одна запись в undo.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   + Релиз

-- Есть ли у плагина параметр с окружением автоматизации, в котором есть точки
local function plugin_has_automation(track, fx_index)
    local num_params = reaper.TrackFX_GetNumParams(track, fx_index)
    for param_idx = 0, num_params - 1 do
        local env = reaper.GetFXEnvelope(track, fx_index, param_idx, false)
        if env and reaper.CountEnvelopePoints(env) > 0 then
            return true
        end
    end
    return false
end

local function get_track_name(track, track_idx)
    if track_idx == "master" then return "Master" end
    local retval, track_name = reaper.GetTrackName(track, "")
    if retval and track_name ~= "" then
        return track_name
    end
    return "Дорожка " .. tostring(track_idx + 1)
end

local function get_fx_name(track, fx_idx)
    local retval, fx_name = reaper.TrackFX_GetFXName(track, fx_idx, "")
    if retval and fx_name ~= "" then
        return fx_name
    end
    return "Плагин " .. tostring(fx_idx + 1)
end

-- Один диалог: режим, мастер, только отчёт
local function ask_options()
    local retval, input = reaper.GetUserInputs(
        "Удаление плагинов (плагины с автоматизацией не удаляются)",
        3,
        -- запятая в подписи разбила бы список полей - разделяем через "/"
        "1 байпас / 2 офлайн / 3 оба:,Мастер-трек (0 нет / 1 да):,Только отчёт (0 нет / 1 да):",
        "1,0,0"
    )
    if not retval then return nil end

    local values = {}
    for v in (input .. ","):gmatch("([^,]*),") do values[#values + 1] = tonumber(v) end

    local mode = ({ "bypass", "offline", "both" })[values[1] or 0]
    if not mode then
        reaper.MB("Первое поле: число от 1 до 3.", "Ошибка", 0)
        return nil
    end
    return { mode = mode, master = values[2] == 1, report_only = values[3] == 1 }
end

local mode_names = {
    bypass = "БАЙПАССНУТЫЕ",
    offline = "ОФЛАЙН",
    both = "БАЙПАССНУТЫЕ И ОФЛАЙН",
}

local mode_descriptions = {
    bypass = "только байпасснутые плагины",
    offline = "только офлайн плагины",
    both = "байпасснутые и офлайн плагины",
}

local function main()
    local opts = ask_options()
    if not opts then return end
    local mode = opts.mode

    local scope = opts.master and "дорожек и мастер-трека" or "дорожек (без мастер-трека)"
    local confirm_msg
    if opts.report_only then
        confirm_msg = "Режим ОТЧЁТА: ничего не будет удалено.\n\n" ..
                      "В консоль REAPER будет выведен список: " .. mode_descriptions[mode] ..
                      " на " .. scope .. " текущего проекта."
    else
        confirm_msg = "Вы выбрали: " .. mode_names[mode] .. "\n\n" ..
                      "В ТЕКУЩЕМ проекте на " .. scope .. " будут удалены " .. mode_descriptions[mode] .. ",\n" ..
                      "у которых НЕТ автоматизации.\n\n" ..
                      "Продолжить?"
    end
    if reaper.MB(confirm_msg, "Подтверждение", 1) ~= 1 then return end

    local proj = 0 -- только текущий проект: другие открытые проекты не затрагиваются
    local deleted_count, skipped_count = 0, 0

    if not opts.report_only then reaper.Undo_BeginBlock() end
    reaper.PreventUIRefresh(1)

    reaper.ShowConsoleMsg("\n=== " .. (opts.report_only and "ОТЧЁТ (без удаления)" or "НАЧАЛО УДАЛЕНИЯ") .. " ===\n")

    local function process_track(track, track_idx)
        -- Идём в обратном порядке, чтобы индексы не сбивались
        for fx_idx = reaper.TrackFX_GetCount(track) - 1, 0, -1 do
            local bypassed = not reaper.TrackFX_GetEnabled(track, fx_idx)
            local offline = reaper.TrackFX_GetOffline(track, fx_idx)

            local should_delete, status_text = false, ""
            if mode == "bypass" then
                should_delete, status_text = bypassed, "байпасснут"
            elseif mode == "offline" then
                should_delete, status_text = offline, "офлайн"
            else
                should_delete = bypassed or offline
                if bypassed and offline then status_text = "байпасснут и офлайн"
                elseif bypassed then status_text = "байпасснут"
                else status_text = "офлайн" end
            end

            if should_delete then
                local fx_name = get_fx_name(track, fx_idx)
                local track_name = get_track_name(track, track_idx)

                if plugin_has_automation(track, fx_idx) then
                    skipped_count = skipped_count + 1
                    reaper.ShowConsoleMsg("ПРОПУЩЕН: " .. fx_name .. " (с " .. track_name ..
                                          ") - есть АВТОМАТИЗАЦИЯ\n")
                else
                    if not opts.report_only then reaper.TrackFX_Delete(track, fx_idx) end
                    deleted_count = deleted_count + 1
                    reaper.ShowConsoleMsg((opts.report_only and "БЫЛ БЫ УДАЛЁН: " or "УДАЛЁН: ") .. fx_name ..
                                          " (с " .. track_name .. ") - статус: " .. status_text .. "\n")
                end
            end
        end
    end

    for track_idx = 0, reaper.CountTracks(proj) - 1 do
        local track = reaper.GetTrack(proj, track_idx)
        if track then process_track(track, track_idx) end
    end
    if opts.master then
        local master = reaper.GetMasterTrack(proj)
        if master then process_track(master, "master") end
    end

    reaper.PreventUIRefresh(-1)
    if not opts.report_only then
        reaper.Undo_EndBlock("Удаление " .. mode_names[mode] .. " плагинов (с защитой автоматизации)", -1)
    end
    reaper.UpdateArrange()

    reaper.ShowConsoleMsg(string.format(
        "\nРЕЗУЛЬТАТ: %s %d, пропущено (с автоматизацией) %d, тип: %s\n=== ЗАВЕРШЕНИЕ ===\n",
        opts.report_only and "к удалению" or "удалено", deleted_count, skipped_count, mode_names[mode]))

    if deleted_count > 0 then
        reaper.MB((opts.report_only and "К удалению: " or "Удалено ") .. deleted_count .. " плагинов\n\n" ..
                  "Пропущено (с автоматизацией): " .. skipped_count ..
                  (opts.report_only and "\n\nПодробности - в консоли REAPER. Ничего не изменено." or ""),
                  opts.report_only and "Отчёт" or "Результат удаления", 0)
    elseif skipped_count > 0 then
        reaper.MB("Не найдено плагинов для удаления\n\n" ..
                  "Все " .. skipped_count .. " найденных плагинов имеют автоматизацию\n" ..
                  "и были защищены от удаления.",
                  "Результат", 0)
    else
        reaper.MB("Не найдено плагинов для удаления", "Результат", 0)
    end
end

main()
