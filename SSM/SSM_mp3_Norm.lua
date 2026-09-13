-- Рендеринг выделенных треков в MP3 (открывает диалог для каждого)
local function sanitize(name)
    return name:gsub('[\\%/:*?"<>|@]', '_')
end

local function get_sr(track)
    local max = 0
    for i = 0, reaper.CountTrackMediaItems(track)-1 do
        local item = reaper.GetTrackMediaItem(track, i)
        local take = reaper.GetActiveTake(item)
        if take then
            local src = reaper.GetMediaItemTake_Source(take)
            if src then
                local sr = reaper.GetMediaSourceSampleRate(src)
                if sr > max then max = sr end
            end
        end
    end
    if max == 0 then
        local proj = reaper.GetSetProjectInfo_String(0, "PROJECT_SRATE", "", false)
        max = tonumber(proj) or 44100
    end
    return math.floor(max)
end

function main()
    local tracks = {}
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        tracks[i+1] = reaper.GetSelectedTrack(0, i)
    end
    if #tracks == 0 then
        reaper.ShowMessageBox("Выделите треки.", "Ошибка", 0)
        return
    end

    local orig_start, orig_end = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local orig_sel = {}
    for i = 0, reaper.CountSelectedTracks(0)-1 do
        orig_sel[i+1] = reaper.GetSelectedTrack(0, i)
    end

    for _, track in ipairs(tracks) do
        reaper.SetTrackSelected(track, true)
        reaper.Main_OnCommand(40421, 0) -- select items
        reaper.Main_OnCommand(40290, 0) -- time selection to items
        
        local _, name = reaper.GetTrackName(track)
        local safe = sanitize(name)
        local sr = get_sr(track)
        local desktop = os.getenv("USERPROFILE") .. "\\Desktop\\Rendered_MP3"
        os.execute('mkdir "' .. desktop .. '" 2>nul')
        
        reaper.GetSetProjectInfo_String(0, "RENDER_FILE", desktop .. "\\" .. safe .. ".mp3", true)
        reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT2", "MP3 (LAME)", true)
        reaper.GetSetProjectInfo_String(0, "RENDER_MP3_MODE", "CBR", true)
        reaper.GetSetProjectInfo_String(0, "RENDER_MP3_BITRATE", "320", true)
        reaper.GetSetProjectInfo_String(0, "RENDER_SRATE", tostring(sr), true)
        reaper.GetSetProjectInfo_String(0, "RENDER_BOUNDS", "Time selection", true)
        reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "Selected tracks", true)
        
        reaper.Main_OnCommand(40630, 0) -- открыть диалог рендеринга
        reaper.ShowMessageBox("Нажмите 'Render 1 file', дождитесь завершения, закройте окно и нажмите OK.", "Следующий трек: " .. name, 0)
        
        reaper.SetTrackSelected(track, false)
        reaper.GetSet_LoopTimeRange(true, false, 0, 0, false)
    end

    -- Восстановление
    reaper.Main_OnCommand(40297, 0)
    for _, t in ipairs(orig_sel) do reaper.SetTrackSelected(t, true) end
    reaper.GetSet_LoopTimeRange(true, false, orig_start, orig_end, false)
    reaper.UpdateArrange()
end

main()
