--[[
  Скрипт: Удалить байпасснутые и офлайн-плагины (с проверкой на автоматизацию)
  Автор: DeepSeek
  Описание: Удаляет со всех дорожек все VST/VST3/AU/JS-плагины,
           которые находятся в байпасе (bypass) или офлайн (offline),
           НО плагины, участвующие в автоматизации (есть активные точки),
           остаются нетронутыми, даже если они в байпасе/офлайн.
--]]

-- Функция для подсчёта количества открытых проектов
function count_projects()
    local count = 0
    while true do
        local proj = reaper.EnumProjects(count)
        if proj then
            count = count + 1
        else
            break
        end
    end
    return count
end

-- Функция проверки, есть ли у параметров плагина активные точки автоматизации
function plugin_has_automation(track, fx_index)
    -- Проверяем, есть ли активные точки в любом параметре плагина
    for param_idx = 0, 255 do
        -- Проверяем, есть ли окружение автоматизации для этого параметра
        local env = reaper.GetFXEnvelope(track, fx_index, param_idx, false)
        if env then
            -- Проверяем, есть ли хотя бы одна точка в окружении
            local points_count = reaper.CountEnvelopePoints(env)
            if points_count > 0 then
                return true
            end
        end
    end
    return false
end

-- Функция для безопасного получения имени дорожки
function get_track_name(track, track_idx)
    local retval, track_name = reaper.GetTrackName(track, "")
    if retval and track_name ~= "" then
        return track_name
    else
        return "Дорожка " .. tostring(track_idx + 1)
    end
end

-- Функция для безопасного получения имени плагина
function get_fx_name(track, fx_idx)
    local retval, fx_name = reaper.TrackFX_GetFXName(track, fx_idx, "")
    if retval and fx_name ~= "" then
        return fx_name
    else
        return "Плагин " .. tostring(fx_idx + 1)
    end
end

-- Функция для отображения меню
function show_menu()
    -- Сначала показываем информационное сообщение с описанием
    local info_msg = [[
УДАЛЕНИЕ ПЛАГИНОВ С ЗАЩИТОЙ АВТОМАТИЗАЦИИ

Выберите действие:

1 - Удалить только БАЙПАССНУТЫЕ плагины
    (отключенные кнопкой Bypass)

2 - Удалить только ОФЛАЙН плагины
    (не загруженные из-за ошибок)

3 - Удалить БАЙПАССНУТЫЕ И ОФЛАЙН плагины
    (оба типа одновременно)

4 - ОТМЕНА

ВАЖНО: Плагины с АВТОМАТИЗАЦИЕЙ НЕ УДАЛЯЮТСЯ!
]]
    
    reaper.MB(info_msg, "Информация о скрипте", 0)
    
    -- Теперь запрашиваем выбор
    local retval, input = reaper.GetUserInputs("Выберите действие", 1, "Введите номер (1-4):", "1")
    
    if not retval then
        return "cancel"
    end
    
    local choice = tonumber(input)
    
    if choice == 1 then
        return "bypass"
    elseif choice == 2 then
        return "offline"
    elseif choice == 3 then
        return "both"
    else
        return "cancel"
    end
end

-- Основная функция
function main()
    -- Показываем меню
    local mode = show_menu()
    
    if mode == "cancel" then
        reaper.ShowConsoleMsg("Операция отменена\n")
        reaper.MB("Операция отменена", "Информация", 0)
        return
    end
    
    -- Получаем название режима для сообщения
    local mode_names = {
        bypass = "БАЙПАССНУТЫЕ",
        offline = "ОФЛАЙН",
        both = "БАЙПАССНУТЫЕ И ОФЛАЙН"
    }
    
    local mode_descriptions = {
        bypass = "только байпасснутые плагины",
        offline = "только офлайн плагины",
        both = "байпасснутые и офлайн плагины"
    }
    
    -- Запрашиваем подтверждение
    local confirm_msg = "Вы выбрали: " .. mode_names[mode] .. "\n\n" ..
                        "Будут удалены " .. mode_descriptions[mode] .. ",\n" ..
                        "у которых НЕТ автоматизации.\n\n" ..
                        "Продолжить?"
    
    local confirm = reaper.MB(confirm_msg, "Подтверждение", 1) -- 1 = OK/Cancel
    
    if confirm ~= 1 then
        reaper.ShowConsoleMsg("Операция отменена пользователем\n")
        reaper.MB("Операция отменена", "Информация", 0)
        return
    end
    
    -- Начинаем блок для отмены
    reaper.Undo_BeginBlock()
    
    -- Подсчитываем количество удалённых плагинов
    local deleted_count = 0
    local skipped_count = 0
    local projects_count = count_projects()
    
    -- Отключаем обновление UI для ускорения
    reaper.PreventUIRefresh(1)
    
    reaper.ShowConsoleMsg("\n=== НАЧАЛО УДАЛЕНИЯ ===\n")
    
    for proj_idx = 0, projects_count - 1 do
        local proj = reaper.EnumProjects(proj_idx)
        if proj then
            local track_count = reaper.CountTracks(proj)
            
            for track_idx = 0, track_count - 1 do
                local track = reaper.GetTrack(proj, track_idx)
                if track then
                    local fx_count = reaper.TrackFX_GetCount(track)
                    
                    -- Идём в обратном порядке, чтобы индексы не сбивались
                    for fx_idx = fx_count - 1, 0, -1 do
                        local bypass = reaper.TrackFX_GetEnabled(track, fx_idx)
                        local offline = reaper.TrackFX_GetOffline(track, fx_idx)
                        
                        local should_delete = false
                        local status_text = ""
                        
                        if mode == "bypass" then
                            should_delete = (not bypass)
                            status_text = "байпасснут"
                        elseif mode == "offline" then
                            should_delete = offline
                            status_text = "офлайн"
                        elseif mode == "both" then
                            should_delete = (not bypass) or offline
                            if (not bypass) and offline then
                                status_text = "байпасснут и офлайн"
                            elseif (not bypass) then
                                status_text = "байпасснут"
                            elseif offline then
                                status_text = "офлайн"
                            end
                        end
                        
                        if should_delete then
                            -- Проверяем наличие автоматизации
                            if not plugin_has_automation(track, fx_idx) then
                                -- Получаем имя плагина для отчёта
                                local fx_name = get_fx_name(track, fx_idx)
                                
                                -- Удаляем плагин
                                reaper.TrackFX_Delete(track, fx_idx)
                                deleted_count = deleted_count + 1
                                
                                -- Выводим информацию в консоль
                                local track_name = get_track_name(track, track_idx)
                                reaper.ShowConsoleMsg("УДАЛЁН: " .. fx_name .. 
                                                     " (с " .. track_name .. 
                                                     ") - статус: " .. status_text .. "\n")
                            else
                                skipped_count = skipped_count + 1
                                -- Показываем пропущенные плагины в консоли
                                local fx_name = get_fx_name(track, fx_idx)
                                local track_name = get_track_name(track, track_idx)
                                reaper.ShowConsoleMsg("ПРОПУЩЕН: " .. fx_name .. 
                                                     " (с " .. track_name .. 
                                                     ") - есть АВТОМАТИЗАЦИЯ\n")
                            end
                        end
                    end
                end
            end
        end
    end
    
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Удаление " .. mode_names[mode] .. " плагинов (с защитой автоматизации)", -1)
    
    reaper.UpdateArrange()
    
    -- Показываем итоговое сообщение
    local result_msg = "РЕЗУЛЬТАТ УДАЛЕНИЯ\n\n" ..
                       "УДАЛЕНО: " .. deleted_count .. " плагинов\n" ..
                       "ПРОПУЩЕНО (с автоматизацией): " .. skipped_count .. " плагинов\n\n" ..
                       "Тип удалённых: " .. mode_names[mode]
    
    reaper.ShowConsoleMsg("\n" .. result_msg .. "\n")
    
    if deleted_count > 0 then
        reaper.MB("Удалено " .. deleted_count .. " плагинов\n\n" ..
                  "Пропущено (с автоматизацией): " .. skipped_count,
                  "Результат удаления", 0)
    else
        if skipped_count > 0 then
            reaper.MB("Не найдено плагинов для удаления\n\n" ..
                      "Все " .. skipped_count .. " найденных плагинов имеют автоматизацию\n" ..
                      "и были защищены от удаления.",
                      "Результат", 0)
        else
            reaper.MB("Не найдено плагинов для удаления", "Результат", 0)
        end
    end
end

-- Запуск скрипта
reaper.ShowConsoleMsg("=== ЗАПУСК СКРИПТА УДАЛЕНИЯ ПЛАГИНОВ ===\n")
reaper.ShowConsoleMsg("Время: " .. os.date() .. "\n\n")
main()
reaper.ShowConsoleMsg("\n=== ЗАВЕРШЕНИЕ СКРИПТА ===\n")
