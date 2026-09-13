-- SSM_AutoBalancer v0.1 (public alpha)
-- https://t.me/bardinssm

-- Блок отмены
reaper.Undo_BeginBlock()

-- Переменные
local lufs = {1, 0, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16, -17}
local lufs0 = 0
local lufs19 = (23 - 19)
local lufs20 = (23 - 20)
local lufs21 = (23 - 21)
local lufs22 = (23 - 22)
local lufs23 = (23 - 23)
local lufs24 = (23 - 24)
local lufs25 = (23 - 25)
local lufs25_5 = (23 - 25.5)
local lufs26 = (23 - 26)
local lufs26_5 = (23 - 26.5)
local lufs27 = (23 - 27)
local lufs28 = (23 - 28)
local lufs28_5 = (23 - 28.5)
local lufs29 = (23 - 29)
local lufs30 = (23 - 30)
local lufs30_5 = (23 - 30.5)
local lufs31 = (23 - 31)
local lufs32 = (23 - 32)
local lufs33 = (23 - 33)
local lufs34 = (23 - 34)
local lufs35 = (23 - 35)
local lufs36 = (23 - 36)
local lufs37 = (23 - 37)
local lufs38 = (23 - 38)
local lufs39 = (23 - 39)
local lufs40 = (23 - 40)
--local lufs40 = lufs[18]
-- Переменные


-- Проверяем, есть ли выделенные медиапредметы
local selected_items_count = reaper.CountSelectedMediaItems(0)


if selected_items_count == 0 then
    reaper.ShowMessageBox("Items not selected", "INFO", 0)
else
    -- Применяем нормализацию
    reaper.Main_OnCommand(54211, 0)

    -- Проходим по всем выделенным элементам
    for i = 0, selected_items_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if not item then goto continue end

        local take = reaper.GetActiveTake(item)
        if not take then goto continue end

        local source = reaper.GetMediaItemTake_Source(take)
        if not source then goto continue end

        local ok, file_name = pcall(reaper.GetMediaSourceFileName, source, "")
        if not ok or not file_name then goto continue end

        local name = file_name:lower()
        local current_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
        local new_volume

        -- Хелпер: plain-поиск (без шаблонов)
        local function has(sub)
            return string.find(name, sub, 1, true) ~= nil
        end

        -- Сначала проверяем самые специфичные варианты, затем общие
		
		-- Барабаны
			-- Kick
        if has("kick sub") or has("kick room") or has("toms room") then
            new_volume = current_volume * 10^(lufs40 / 20) --40
        
    elseif has("kick in") or has("kick") or has("db") then
            new_volume = current_volume * 10^(lufs26_5 / 20)--26,5
			
	elseif has("bass") then
            new_volume = current_volume * 10^(lufs28_5 / 20)--lufs28_5
			       
    elseif has("snare bot") or has("snare bottom") or has("snr bot") or has("snare btm") or has("snare hall") or has("snare room") or has("kick room") or has("shaker") or has("room") then
            new_volume = current_volume * 10^(lufs40 / 20)   --40				
	   -- Барабаны
			-- Snare 
    elseif has("snare top") or has("snare") or has("snr") then
            new_volume = current_volume * 10^(lufs26 / 20)  --26
        
    elseif has("tom") or has("gtr solo") then
            new_volume = current_volume * 10^(lufs25 / 20)  --25
        
    elseif has("gtr acc") or has("piano") or has("organ") then
            new_volume = current_volume * 10^(lufs30 / 20)--30
			
	elseif has("synth") then
            new_volume = current_volume * 10^(lufs33 / 20)--33
        
    elseif has("guitars") or has("guitar") or has("gtr") then
            new_volume = current_volume * 10^(lufs27 / 20)	--27
        
    elseif has("hat") or has("hh") or has("ride") then
            new_volume = current_volume * 10^(lufs37 / 20)--37
        
    elseif has("oh") or has("ovhs") then
            new_volume = current_volume * 10^(lufs30 / 20)--33
        
    elseif has("tambo") then
            new_volume = current_volume * 10^(lufs39 / 20)--39
        
    elseif has("vocal") or has("vox") then
            new_volume = current_volume * 10^(lufs24 / 20)--24
        
    else
            -- Если имя не знакомо — мутируем элемент
            reaper.SetMediaItemInfo_Value(item, "B_MUTE", 1)
        end

        -- Устанавливаем новую громкость для элемента (если применили)
        if new_volume then
            reaper.SetMediaItemInfo_Value(item, "D_VOL", new_volume)
        end

        ::continue::
    end
end

-- Завершаем блок отмены
reaper.Undo_EndBlock("!!!SSM - AutoBalancer!!!", -1)