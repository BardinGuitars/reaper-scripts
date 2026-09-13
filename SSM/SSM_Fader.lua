--[[
REAPER: TCP Volume Fader Mousewheel
-----------------------------------
Changes TRACK VOLUME by a fixed dB step ONLY when the mouse
is directly over the TCP volume fader.

STEP = 0.1 means:
    Wheel up   = +0.1 dB
    Wheel down = -0.1 dB

Uses REAPER's native GetThingFromPoint() hit testing.
No SWS is required.

IMPORTANT:
Assign this script to a Mousewheel action in the TCP / Track panel
mouse-modifier context. The script itself additionally checks that
the mouse is actually over the TCP volume control.
]]

local STEP = 0.1

-- Get wheel movement from the action invocation.
local is_new_value, _, _, _, _, _, wheel = reaper.get_action_context()

if not is_new_value or wheel == 0 then
    return
end

-- Screen coordinates of the mouse.
local x, y = reaper.GetMousePosition()

-- Native REAPER hit test.
-- For the TCP volume control, info normally identifies the control
-- as a TCP volume element (e.g. "tcp.volume").
local track, info = reaper.GetThingFromPoint(x, y)

if not track or not info then
    return
end

-- ONLY allow the TCP volume control.
-- Do not react to other TCP controls or other REAPER areas.
local is_tcp_volume =
    info == "tcp.volume" or
    info:match("^tcp%.volume")

if not is_tcp_volume then
    return
end

-- Current track volume in linear scale.
local current_linear = reaper.GetMediaTrackInfo_Value(track, "D_VOL")

-- Convert linear -> dB.
local current_db
if current_linear > 0 then
    current_db = 20 * math.log(current_linear, 10)
else
    current_db = -150
end

-- One wheel direction = exactly one STEP.
local direction = wheel > 0 and 1 or -1
local new_db = current_db + direction * STEP

-- Avoid going below REAPER's practical minimum.
if new_db < -150 then
    new_db = -150
end

-- Convert dB -> linear.
local new_linear = 10 ^ (new_db / 20)

reaper.Undo_BeginBlock()
reaper.SetMediaTrackInfo_Value(track, "D_VOL", new_linear)
reaper.UpdateArrange()
reaper.Undo_EndBlock(
    string.format("TCP volume mousewheel %+.2f dB", direction * STEP),
    -1
)

