-- @description SSM_Del_Numbers_Name
-- @version 1.0
-- @author @ssm_metalmix
-- @about
--   🔢 Удаляет цифры из названий треков: все цифры, только в начале
--   («01 Kick» → «Kick») или только в конце («Guitar 03» → «Guitar»).
--   Если выделены треки - обрабатываются только они, если ничего не выделено -
--   все треки проекта. Лишние пробелы после удаления убираются; если имя стало
--   пустым, трек получает имя «Track N». Перед изменением просит подтверждение
--   (в нём указано, сколько треков будет обработано), вся операция - одна
--   запись в undo.
--   📱 Telegram Channel - https://t.me/bardinssm
--   💬 Telegram - https://t.me/ssm_metalmix
--   ☕ Boosty - https://boosty.to/boostbg
--   🌐 VK - https://vk.ru/ssm_metalmix
-- @changelog
--   + Релиз

-- Функции возвращают только строку (gsub возвращает ещё и счётчик замен)
local function remove_all_digits(name)
    return (name:gsub("%d", ""))
end

-- Удаляем цифры в начале и следующий за ними пробел (если есть)
local function remove_leading_digits(name)
    return (name:gsub("^%d+%s?", ""))
end

-- Удаляем пробел перед цифрами (если есть) и сами цифры в конце
local function remove_trailing_digits(name)
    return (name:gsub("%s?%d+$", ""))
end

-- После удаления цифр из середины ("Gtr 1 L" -> "Gtr  L", "808 kick" -> " kick")
-- остаются лишние пробелы - чистим их, но только у реально изменённых имён
local function tidy(name)
    name = name:gsub("%s+", " ")
    return (name:match("^%s*(.-)%s*$"))
end

local ACTIONS = {
    [1] = { func = remove_all_digits,      name = "удаление всех цифр" },
    [2] = { func = remove_leading_digits,  name = "удаление цифр в начале (и пробела после)" },
    [3] = { func = remove_trailing_digits, name = "удаление цифр в конце (и пробела перед)" },
}

-- Выделенные треки, а если ничего не выделено - все. Возвращает список
-- {track=, number=} (number - порядковый номер трека в проекте, с 1).
local function collect_targets(project)
    local targets = {}
    local selected = reaper.CountSelectedTracks(project)
    if selected > 0 then
        for i = 0, selected - 1 do
            local track = reaper.GetSelectedTrack(project, i)
            targets[#targets + 1] = {
                track = track,
                number = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") + 0.5),
            }
        end
        return targets, true
    end
    for i = 0, reaper.CountTracks(project) - 1 do
        targets[#targets + 1] = { track = reaper.GetTrack(project, i), number = i + 1 }
    end
    return targets, false
end

function main()
    local project = reaper.EnumProjects(-1, "")
    if not project then
        reaper.MB("Нет открытого проекта!", "Ошибка", 0)
        return
    end

    if reaper.CountTracks(project) == 0 then
        reaper.MB("В проекте нет треков!", "Информация", 0)
        return
    end

    local targets, only_selected = collect_targets(project)

    -- Один диалог вместо двух: варианты прямо в подписи поля
    local retval, input = reaper.GetUserInputs(
        "Удаление цифр из названий треков",
        1,
        "1 - все цифры, 2 - в начале, 3 - в конце:",
        "1"
    )
    if not retval then return end

    local action = ACTIONS[tonumber(input)]
    if not action then
        reaper.MB("Введите число от 1 до 3.", "Ошибка", 0)
        return
    end

    local scope = only_selected
        and ("выделенных треков: " .. #targets)
        or ("всех треков проекта: " .. #targets)
    local confirm = reaper.ShowMessageBox(
        "Вы уверены, что хотите выполнить " .. action.name .. "?\n\nБудет обработано " .. scope,
        "Подтверждение",
        1 -- 1 = OK/Cancel
    )
    if confirm ~= 1 then return end

    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)

    local modified_count = 0

    for _, target in ipairs(targets) do
        local track = target.track
        if track then
            local _, track_name = reaper.GetTrackName(track, "")

            if track_name and track_name ~= "" then
                local new_name = action.func(track_name)

                if new_name ~= track_name then
                    new_name = tidy(new_name)
                    -- Если имя стало пустым - даём нейтральное
                    if new_name == "" then
                        new_name = "Track " .. target.number
                    end

                    if new_name ~= track_name then
                        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", new_name, true)
                        modified_count = modified_count + 1
                    end
                end
            end
        end
    end

    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Удаление цифр из названий треков (" .. action.name .. ")", -1)
    reaper.UpdateArrange()

    if modified_count > 0 then
        reaper.MB(
            "Готово! Обработано треков: " .. modified_count .. " из " .. #targets,
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
end

main()
