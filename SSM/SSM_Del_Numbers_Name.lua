-- Скрипт: Удаление цифр из названий треков
-- Описание: Удаляет все цифры, только в начале или только в конце названий треков

-- Функция для удаления всех цифр
function remove_all_digits(name)
    return name:gsub("%d", "")
end

-- Функция для удаления цифр только в начале (с пробелом)
function remove_leading_digits(name)
    -- Удаляем цифры в начале и следующий за ними пробел (если есть)
    return name:gsub("^%d+%s?", "")
end

-- Функция для удаления цифр только в конце (с пробелом)
function remove_trailing_digits(name)
    -- Удаляем пробел перед цифрами (если есть) и сами цифры в конце
    return name:gsub("%s?%d+$", "")
end

-- Основная функция
function main()
    -- Проверяем, что проект открыт
    local project = reaper.EnumProjects(-1, "")
    if not project then
        reaper.MB("Нет открытого проекта!", "Ошибка", 0)
        return
    end
    
    -- Получаем количество треков
    local track_count = reaper.CountTracks(project)
    if track_count == 0 then
        reaper.MB("В проекте нет треков!", "Информация", 0)
        return
    end
    
    -- Показываем диалог с выбором действия
    local msg = "Выберите действие с цифрами в названиях треков:\n\n"
    msg = msg .. "Нажмите:\n"
    msg = msg .. "  1 - Удалить все цифры\n"
    msg = msg .. "  2 - Удалить только в начале (и пробел после)\n"
    msg = msg .. "  3 - Удалить только в конце (и пробел перед)\n"
    msg = msg .. "  4 - Отмена"
    
    -- Показываем сообщение с вариантами и запрашиваем ввод
    reaper.MB(msg, "Удаление цифр из названий треков", 0)
    
    -- Запрашиваем номер действия
    local retval, input = reaper.GetUserInputs(
        "Выбор действия",
        1, -- количество полей
        "Введите номер действия (1, 2, 3 или 4 для отмены):",
        "" -- значение по умолчанию
    )
    
    if not retval then
        return -- Отмена
    end
    
    local action_num = tonumber(input)
    if not action_num then
        reaper.MB("Ошибка! Введите число.", "Ошибка", 0)
        return
    end
    
    -- Выбираем функцию
    local process_func = nil
    local action_name = ""
    
    if action_num == 1 then
        process_func = remove_all_digits
        action_name = "удаление всех цифр"
    elseif action_num == 2 then
        process_func = remove_leading_digits
        action_name = "удаление цифр в начале (и пробела после)"
    elseif action_num == 3 then
        process_func = remove_trailing_digits
        action_name = "удаление цифр в конце (и пробела перед)"
    elseif action_num == 4 then
        return -- Отмена
    else
        reaper.MB("Неверный выбор! Введите число от 1 до 4.", "Ошибка", 0)
        return
    end
    
    -- Подтверждение действия
    local confirm = reaper.ShowMessageBox(
        "Вы уверены, что хотите выполнить " .. action_name .. "?",
        "Подтверждение",
        1 -- 1 = OK/Cancel
    )
    
    if confirm ~= 1 then
        return -- Отмена
    end
    
    -- Отключаем обновление интерфейса для скорости
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local modified_count = 0
    
    -- Проходим по всем трекам
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(project, i)
        if track then
            -- Получаем текущее имя трека
            local retval, track_name = reaper.GetTrackName(track, "")
            
            if track_name and track_name ~= "" then
                -- Применяем функцию удаления
                local new_name = process_func(track_name)
                
                -- Если имя изменилось, обновляем его
                if new_name ~= track_name then
                    -- Проверяем, не стало ли имя пустым
                    if new_name == "" or new_name == " " then
                        new_name = "Track " .. (i + 1)
                    end
                    
                    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_name, true)
                    modified_count = modified_count + 1
                end
            end
        end
    end
    
    -- Включаем обновление интерфейса
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Удаление цифр из названий треков (" .. action_name .. ")", -1)
    
    -- Показываем результат
    if modified_count > 0 then
        reaper.MB(
            "Готово! Обработано треков: " .. modified_count .. " из " .. track_count,
            "Результат",
            0
        )
    else
        reaper.MB(
            "Ни один трек не был изменен. Возможно, в названиях нет цифр.",
            "Информация",
            0
        )
    end
    
    -- Обновляем интерфейс
    reaper.UpdateArrange()
end

-- Запускаем скрипт
reaper.defer(main)
