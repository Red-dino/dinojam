
local latest_print = nil

local debounce_time = 0.15
local time_since_last_input = 0
local is_debouncing = false
local is_key_up = true

local beat = 0

local discs = {}

local tracks = {}
local visuals = {}
local programs = {
    {"wave", ""},
    {"cord wave", ""},
    {"dots", ""},
    {"time-space rain", ""},
    {"flower", ""},
    {"time fossils", ""},
    {"rings", ""},
    {"square", ""}
}
local tracks_index = 1
local file_menu_index = 1

local track_bpms = {}
local track_beat_starts = {}

local left_track = nil
local right_track = nil
local left = true

local volume_bias = 0.5

local visual_setting = "under"
local background = nil
local background_x = 0
local background_y = 0
local background_type = nil
local current_program = nil
local program_canvas = nil

local action_x = 1
local action_y = 8
local actions = {
    {"tap", "test"},
    {"slower", "faster", "sync"},
    {"back", "forward", "play", "playsync", "stop"},
    {"lpf"},
    {"hpf"},
    -- {"volume_down", "volume_up"},
    {"volume"},
    {"none", "under", "over"},
    {"files"}
}

local default_filter = {
    type = "bandpass",
    volume = 1.0,
    highgain = 1.0,
    lowgain = 1.0
}

-- function love.gamepadpressed(joystick, button)
    -- latest_print = tostring(button)
-- end

function love.load()
    local joysticks = love.joystick.getJoysticks()
    joystick = joysticks[1]

    if joystick then
        debounce_time = 0.25
    end

    for i=0,3 do
        discs[i] = love.graphics.newImage(string.format("assets/disc%d.png", i + 1))
    end

    tracks = {}
    getFiles("tracks", "", {"mp3", "ogg", "oga", "ogv", "wav", "flac"}, tracks)
    sortFiles(tracks)
    visuals = {}
    getFiles("visuals", "", {"ogv", "png", "jpg", "jpeg", "bmp", "tga", "hdr", "pic", "exr"}, visuals)
    sortFiles(visuals)

    loadTrackData()
end

function love.update(dt)
    updateTrack(dt, left_track)
    updateTrack(dt, right_track)

    if background_type == "Video" and not background:isPlaying() then
        background:rewind()
        background:play()
    end

    time_since_last_input = time_since_last_input + dt

    if time_since_last_input > debounce_time then
        is_debouncing = false
    end

    is_key_up = true

    if isKeyDown("left", "dpleft") then
        time_since_last_input = 0

        if getCurrentAction() == "volume" then
            volume_bias = math.max(0, volume_bias - 0.05)
            updateVolumes()
        elseif getCurrentAction() == "lpf" then
            local track = getCurrentTrack().track
            local filter = track:getFilter()
            filter.lowgain = math.max(0, filter.lowgain - 0.1)
            track:setFilter(filter)
        elseif getCurrentAction() == "hpf" then
            local track = getCurrentTrack().track
            local filter = track:getFilter()
            filter.highgain = math.max(0, filter.highgain - 0.1)
            track:setFilter(filter)
        end

        if inFiles() then
            tracks_index = 1
            file_menu_index = ((file_menu_index - 2) % 3) + 1
        end

        action_x = action_x - 1
        if action_x == 0 then
            action_x = #actions[action_y]
        end
    elseif isKeyDown("right", "dpright") then
        time_since_last_input = 0

        -- left_track.track:setPitch(left_track.track:getPitch() / 1.01)

        if getCurrentAction() == "volume" then
            volume_bias = math.min(1, volume_bias + 0.05)
            updateVolumes()
        elseif getCurrentAction() == "lpf" then
            local track = getCurrentTrack().track
            local filter = track:getFilter()
            filter.lowgain = math.min(1.0, filter.lowgain + 0.1)
            track:setFilter(filter)
        elseif getCurrentAction() == "hpf" then
            local track = getCurrentTrack().track
            local filter = track:getFilter()
            filter.highgain = math.min(1.0, filter.highgain + 0.1)
            track:setFilter(filter)
        end

        if inFiles() then
            tracks_index = 1
            file_menu_index = ((file_menu_index) % 3) + 1
        end

        action_x = action_x + 1
        if action_x > #actions[action_y] then
            action_x = 1 
        end
    elseif isKeyDown("up", "dpup") then
        time_since_last_input = 0

        if inFiles() then
            tracks_index = tracks_index - 1
            if tracks_index == 0 then
                tracks_index = 1
                action_y = action_y - 1
                action_x = 1
            end
        elseif getCurrentAction() == "volume" then
            if getCurrentTrack() then
                action_y = action_y - 1
                action_x = 1
            end
        else
            action_y = action_y - 1
            action_x = 1
        end

        if action_y == 0 then
            action_y = 1
        end
    elseif isKeyDown("down", "dpdown") then
        time_since_last_input = 0

        beat = 0
        if inFiles() then
            tracks_index = math.min(#getFileList(), tracks_index + 1)
        else
            action_x = 1
            action_y = action_y + 1
            if action_y > #actions then
                action_y = #actions
            end
        end
    elseif isKeyDown("q", "leftshoulder") then
        time_since_last_input = 0

        beat = 0
        left = true

        if not getCurrentTrack() then
            action_x = 1
            action_y = 7
        end
    elseif isKeyDown("e", "rightshoulder") then
        time_since_last_input = 0

        beat = 0
        left = false

        if not getCurrentTrack() then
            action_x = 1
            action_y = 8
        end
    elseif isKeyDown("space", "a") then
        time_since_last_input = 0

        handleClick()
    elseif isKeyDown("d", "b") then
        time_since_last_input = 0
        
        visual_setting = "under"
        tracks_index = 1
        action_x = 2
        action_y = 7
    elseif isKeyDown("w", "x") then
        time_since_last_input = 0
        
        if getCurrentTrack() then
            tracks_index = 1
            action_x = 3
            action_y = 3
        end
    elseif isKeyDown("a", "y") then
        time_since_last_input = 0
        
        tracks_index = 1
        action_x = 1
        action_y = 8
    elseif isGamepadDown("guide") then
        love.event.quit()
        return
    end

    is_debouncing = not is_key_up
end

function handleClick()
    local action = getCurrentAction()
    if action == "back" then
        local t = getCurrentTrack().track
        t:seek(math.max(0, t:tell() - (5 * t:getPitch())))
    elseif action == "forward" then
        local t = getCurrentTrack().track
        t:seek(math.min(t:getDuration(), t:tell() + (5 * t:getPitch())))
    elseif action == "play" then
        local t = getCurrentTrack().track
        if t:isPlaying() then
            t:pause()
        else
            t:play()
        end
    elseif action == "playsync" then
        if not syncTracks() then
            return
        end

        local t = getCurrentTrack()
        local not_t = getOtherTrack()

        if not not_t.track:isPlaying() then
            return
        end

        local bps = track_bpms[t.path] / 60
        local not_bps = track_bpms[not_t.path] / 60

        local pos = ((t.track:tell() - track_beat_starts[t.path]) * bps) % 4
        local not_pos = ((not_t.track:tell() - track_beat_starts[not_t.path]) * not_bps) % 4

        -- Jump forward only.
        if pos > not_pos then
            not_pos = not_pos + 4
        end

        local rel = not_pos - pos
        t.track:seek(t.track:tell() + (rel / bps))
        t.track:play()
    elseif action == "stop" then
        getCurrentTrack().track:stop()
    elseif action == "tap" then
        local t = getCurrentTrack()
        if not t.track:isPlaying() then
            return
        end

        local key = t.path
        if beat == 0 then
            local t = t.track:tell()
            track_beat_starts[key] = t
        end
        beat = beat + 1
        if beat > 1 then
            latest_time = t.track:tell()
            track_bpms[key] = (beat - 1) * 60 / (latest_time - track_beat_starts[key])
            saveTrackData()
        end
    elseif action == "test" then
        local t = getCurrentTrack()
        if track_beat_starts[t.path] then
            t.track:seek(track_beat_starts[t.path])
            t.track:play()
        end
    elseif action == "slower" then
        local t = getCurrentTrack()
        t.track:setPitch(t.track:getPitch() / 1.01)
    elseif action == "faster" then
        local t = getCurrentTrack()
        t.track:setPitch(t.track:getPitch() * 1.01)
    elseif action == "sync" then
        syncTracks()
    elseif action == "lpf" then
        local track = getCurrentTrack().track
        local filter = track:getFilter()
        filter.lowgain = 1.0 - filter.lowgain
        track:setFilter(filter)
    elseif action == "hpf" then
        local track = getCurrentTrack().track
        local filter = track:getFilter()
        filter.highgain = 1.0 - filter.highgain
        track:setFilter(filter)
    elseif action == "volume" then
        volume_bias = 1 - volume_bias
        updateVolumes()
    elseif action == "none" then
        visual_setting = "none"
    elseif action == "under" then
        visual_setting = "under"
    elseif action == "over" then
        visual_setting = "over"
    elseif action == "files" and file_menu_index == 1 then
        local name = tracks[tracks_index][1]
        local track = getTrack(name, "tracks/"..name)
        if left then
            if left_track then
                left_track.track:stop()
                left_track.track:release()
            end
            left_track = track
        else
            if right_track then
                right_track.track:stop()
                right_track.track:release()
            end
            right_track = track
        end
        updateVolumes()
    elseif action == "files" and file_menu_index == 2 then
        if background then
            background:release()
        end

        current_program = nil

        local file = visuals[tracks_index]
        local path = "visuals/"..file[1]
        if file[2] == "ogv" then
            background = love.graphics.newVideo(path)
            if background:getSource() then
                background:getSource():setVolume(0)
            end

            background:play()
            background_type = "Video"
        else
            background = love.graphics.newImage(path)
            background_type = "Image"
        end
        background_x = 320 - (background:getWidth() / 2)
        background_y = 240 - (background:getHeight() / 2)
    elseif action == "files" and file_menu_index == 3 then
        if background then
            background:release()
        end

        current_program = nil

        local program_name = programs[tracks_index][1]

        if program_name == "wave" then
            current_program = program_wave
        elseif program_name == "cord wave" then
            current_program = program_cord_wave
        elseif program_name == "dots" then
            current_program = program_dots
        elseif program_name == "time-space rain" then
            current_program = program_time_space_rain
        elseif program_name == "flower" then
            current_program = program_flower
        elseif program_name == "time fossils" then
            current_program = program_time_fossils
        elseif program_name == "rings" then
            current_program = program_rings
        elseif program_name == "square" then
            current_program = program_square
        end

        background = love.graphics.newCanvas(640, 480)
        background_type = "Program"
        background_x = 0
        background_y = 0
    end
end

function love.draw()

    if current_program then
        love.graphics.setCanvas(background)
        current_program()
        love.graphics.setCanvas()
    end

    if background and visual_setting == "under" then
        love.graphics.draw(background, background_x, background_y)
    end

    if background and visual_setting == "over" then
        love.graphics.draw(background, background_x, background_y)
        return
    end

    love.graphics.setColor(255, 255, 255)

    if latest_print then
        love.graphics.print(latest_print)
    end

    drawTrack(left_track, 0, 0, left)
    drawTrack(right_track, 320, 0, not left)

    local y = 245
    love.graphics.rectangle(getCurrentAction() == "volume" and "fill" or "line", 160, y + 7, 320, 6)

    local x = 160 + (320 * volume_bias) - 3
    love.graphics.rectangle("fill", x, y + 2, 6, 16)

    y = y + 20

    local selection = getCurrentAction()
    love.graphics.print("Visuals", 5, y + 7)
    drawButton("None", 50, y + 5, 40, 20, visual_setting == "none" or selection == "none")
    drawButton("Under", 95, y + 5, 40, 20, visual_setting == "under" or selection == "under")
    drawButton("Over", 140, y + 5, 40, 20, visual_setting == "over" or selection == "over")

    y = y + 30

    if file_menu_index == 3 then
        love.graphics.print("  Tracks    Visuals  [ Programs ]", 5, y)
    elseif file_menu_index == 2 then
        love.graphics.print("  Tracks  [ Visuals ]  Programs", 5, y)
    else
        love.graphics.print("[ Tracks ]  Visuals    Programs", 5, y)
    end

    local list = getFileList()
    local minimum = math.max(tracks_index - 9, 1)
    local maximum = math.min(minimum + 9, #list)
    for i=minimum, maximum do
        local file = list[i]
        if file then
            y = y + 15
            local name = file[1]
            local bpm = track_bpms["tracks/"..name]
            if bpm then
                name = string.format("%s - %.2f BPM", name, bpm)
            end
            love.graphics.print(name, 5, y)
            if inFiles() and i == tracks_index then
                love.graphics.rectangle("fill", 0, y, 4, 15)
            end
        end
    end
    if #list > 9 and #list > tracks_index then
        y = y + 15
        love.graphics.print("(more)", 5, y)
    end
end

function getTrack(filename, filepath)
    local source = love.audio.newSource(filepath, "stream")
    source:setFilter(default_filter)
    local name = filename
    if string.len(name) > 45 then
        name = "..."..name:sub(string.len(name) - 44, string.len(name))
    end
    return {
        name = name,
        path = filepath,
        track = source,
        bar = 0
    }
end

function updateTrack(dt, track)
    if not track then
        return
    end

    local bpm = track_bpms[track.path]
    if bpm then
        local b = math.floor(((track.track:tell() - track_beat_starts[track.path]) / 60) * bpm)
        track.bar = b
    end
end

function drawTrack(track, x, y, selected)
    if selected then
        love.graphics.rectangle("line", x, y, 320, 240)
    end

    if not track then
        love.graphics.print("No track selected", x + 5, y + 5)
        return
    end

    love.graphics.print(track.name, x + 5, y + 5)

    local bpm = track_bpms[track.path]
    if bpm then
        love.graphics.draw(discs[track.bar % 4], x + 5, y + 25)

        bpm = bpm * track.track:getPitch()
        love.graphics.print(string.format("BPM %.2f", bpm), x + 130, y + 27)
    else
        love.graphics.draw(discs[0], x + 5, y + 25)
        love.graphics.print(string.format("BPM ??", bpm), x + 130, y + 27)
    end

    local selection = getCurrentAction()
    drawButton("Tap", x + 65, y + 25, 26, 20, selected and selection == "tap")
    drawButton("Test", x + 96, y + 25, 29, 20, selected and selection == "test")

    drawButton("-", x + 65, y + 50, 20, 20, selected and selection == "slower")
    drawButton("+", x + 90, y + 50, 20, 20, selected and selection == "faster")
    drawButton("Sync", x + 115, y + 50, 35, 20, selected and selection == "sync")
    love.graphics.print(string.format("Pitch %.2f", track.track:getPitch()), x + 155, y + 52)

    drawButton("<", x + 5, y + 85, 20, 20, selected and selection == "back")
    drawButton(">", x + 30, y + 85, 20, 20, selected and selection == "forward")
    drawButton(track.track:isPlaying() and "Pause" or "Play", x + 55, y + 85, 40, 20, selected and selection == "play")
    drawButton("Sync Play", x + 100, y + 85, 62, 20, selected and selection == "playsync")
    drawButton("Stop", x + 167, y + 85, 32, 20, selected and selection == "stop")

    local width = 300
    local percent = track.track:tell() / track.track:getDuration()
    local play_width = (width - 4) * percent
    love.graphics.rectangle("line", x + 5, y + 110, width, 20)
    love.graphics.rectangle("fill", x + 7, y + 112, play_width, 16)

    local newDuration = track.track:getDuration() / track.track:getPitch()
    love.graphics.print(formatTime(newDuration * percent).." / "..formatTime(newDuration), x + 5, y + 135)

    love.graphics.print("Low Gain", x + 9, y + 155)
    love.graphics.rectangle(getCurrentAction() == "lpf" and selected and "fill" or "line", x + 70, y + 160, width - 70, 6)
    local x_diff = (width - 70) * track.track:getFilter().lowgain + 70
    love.graphics.rectangle("fill", x + x_diff, y + 155, 6, 16)

    love.graphics.print("High Gain", x + 5, y + 180)
    love.graphics.rectangle(getCurrentAction() == "hpf" and selected and "fill" or "line", x + 70, y + 185, width - 70, 6)
    local x_diff = (width - 70) * track.track:getFilter().highgain + 70
    love.graphics.rectangle("fill", x + x_diff, y + 180, 6, 16)

    --local x = 160 + (320 * volume_bias) - 3
    --love.graphics.rectangle("fill", x, y + 2, 6, 16)
end

function formatTime(t)
    local m = math.floor(t / 60)
    local s = t % 60
    return string.format("%d:%05.2f", m, s)
end

function drawButton(text, x, y, w, h, selected)
    love.graphics.rectangle(selected and "fill" or "line", x, y, w, h)

    if selected then
        love.graphics.setColor(0, 0, 0)
    end

    love.graphics.print(text, x + 2, y + 2)

    if selected then
        love.graphics.setColor(255, 255, 255)
    end
end

function getCurrentAction()
    return actions[action_y][action_x]
end

function getCurrentTrack()
    if left then
        return left_track
    else
        return right_track
    end
end

function getOtherTrack()
    if left then
        return right_track
    else
        return left_track
    end
end

function updateVolumes()
    if left_track then
        left_track.track:setVolume(getFaderValue(1 - volume_bias))
    end
    if right_track then
        right_track.track:setVolume(getFaderValue(volume_bias))
    end
end

function syncTracks()
    local t = getCurrentTrack()
    local not_current_t = getOtherTrack()

    if not not_current_t then
        return false
    end

    local current_bpm = track_bpms[t.path]
    local not_current_bpm = track_bpms[not_current_t.path]

    if not current_bpm or not not_current_bpm then
        return false
    end

    not_current_bpm = not_current_bpm * not_current_t.track:getPitch()

    t.track:setPitch(not_current_bpm / current_bpm)

    return true
end

function isKeyDown(keyboard_key, gamepad_key)

    local is_this_key_down = false
    if joystick then
        is_this_key_down = joystick:isGamepadDown(gamepad_key)
    elseif keyboard_key then
        is_this_key_down = love.keyboard.isDown(keyboard_key)
    end

    -- If the key is down, we want to is_key_up should be false,
    -- and should stay there for the rest of the loop.
    is_key_up = is_key_up and not is_this_key_down
    -- Since we've already updated is_key_up, we can return whatever,
    -- so we check that the current key is down, but there isn't
    -- an existing debounce in effect.
    return is_this_key_down and not is_debouncing
end

function isGamepadDown(gamepad_key)
    if not joystick then return end

    return joystick:isGamepadDown(gamepad_key)
end

function inFiles()
    return action_y == 8
end

function getFileList()
    if file_menu_index == 3 then
        return programs
    elseif file_menu_index == 2 then
        return visuals
    else
        return tracks
    end
end

function getFiles(top_level_directory, directory, supported_file_types, files_return)
    local files = love.filesystem.getDirectoryItems(top_level_directory.."/"..directory)
	for i,v in ipairs(files) do
        local file_path = v
        if directory ~= "" then
            file_path = directory.."/"..file_path
        end
		local info = love.filesystem.getInfo(top_level_directory.."/"..file_path)
		if info then
			if info.type == "file" then
                local ext = getFileExtension(v)
                for _, val in pairs(supported_file_types) do
                    if ext == val then
                        table.insert(files_return, {file_path, ext})
                    end
                end
			elseif info.type == "directory" then
				getFiles(top_level_directory, file_path, supported_file_types, files_return)
			end
		end
	end
end

function getFileExtension(file_path)
    local s = ""
    for i=0, string.len(file_path)-1 do
        local j = string.len(file_path) - i
        local c = file_path:sub(j, j)
        if c == "." then
            return string.lower(s)
        end
        s = c..s
    end
    return nil
end

function getFaderValue(percent)
    return math.sqrt(percent)
end

-- trackname;bpm;start_time_seconds;tags
function loadTrackData()
    if love.filesystem.getInfo("tracks.txt") then
        for line in love.filesystem.lines("tracks.txt") do
            local items = parseLine(line)
            local k = items[1]
            track_bpms[k] = tonumber(items[2])
            track_beat_starts[k] = tonumber(items[3])
        end
    else
        print("Cannot find tracks file.")
    end
end

function saveTrackData()
    local data = ""
    for k, v in pairs(track_bpms) do
        data = data..k..";"..v..";"..track_beat_starts[k].."\n"
    end
    love.filesystem.write("tracks.txt", data)
end

function parseLine(line)
    local line_items = {}
    for s in string.gmatch(line, "([^;]+)") do
        table.insert(line_items, s)
    end
    return line_items
end

function sortFiles(files)
    table.sort(files, function (a, b) return string.lower(a[1]) < string.lower(b[1]) end )
end 

-- Spinning disc
-- percent complete
-- pause, play, back, forward
-- volume
-- bpm: match, normal, +, -
-- tap
-- file finder
-- volume bias
-- picture status

-- controls on individual
-- keep current menu selection
-- loop video
-- save settings

-- improve scrolling
-- add metadata
-- return to normal BPM button
-- individual volume controls
-- separate files

--== PROGRAMS ==--
local function _hsv(h)
    local r = 0.5 + 0.5 * math.sin(h)
    local g = 0.5 + 0.5 * math.sin(h + 2.094)
    local b = 0.5 + 0.5 * math.sin(h + 4.188)
    return r, g, b
end

function program_wave()
    love.graphics.clear()
    for i=0,31 do
        love.graphics.rectangle("fill", 20 * i, 230 + 20 * math.sin(i + 20 * love.timer.getTime()), 20, 40)
    end
end


function program_cord_wave()
    love.graphics.clear()
    for i=0,31 do
        love.graphics.rectangle("fill", 20 * i, 230 + 40 * math.sin((i - 16) * love.timer.getTime()), 20, 20)
    end
end

function program_dots()
    if math.floor(love.timer.getTime() * 20) % 20 == 1 then
        love.graphics.circle("fill", love.math.random(20, 620), love.math.random(20, 460), 20)
    end
end

function program_time_space_rain()
    local t = love.timer.getTime()
    for i = 0, 400 do
        local p = t * 20 + i

        local x = (p * 37) % 640
        local y = (p * p * 0.1) % 480

        love.graphics.points(x, y)
    end
end

function program_flower() 
    local t = love.timer.getTime()
    for i = 0, 99 do
        local a = i * 0.0628

        local r1 = 180 + 40 * math.sin(t)
        local r2 = 180 + 40 * math.sin(t * 1.618)

        local x1 = 320 + r1 * math.cos(a + t * 0.2)
        local y1 = 240 + r1 * math.sin(a + t * 0.2)

        local x2 = 320 + r2 * math.cos(a * 7 - t * 0.3)
        local y2 = 240 + r2 * math.sin(a * 7 - t * 0.3)

        love.graphics.line(x1, y1, x2, y2)
    end
end

function program_time_fossils()
    local t = love.timer.getTime()
    local x = 320 + 250 * math.sin(t * 0.13) * math.sin(t * 2.7)

    local y = 240 + 200 * math.cos(t * 0.17) * math.sin(t * 3.1)

    local r = 1 + 8 * (0.5 + 0.5 * math.sin(t * 5))

    love.graphics.circle("fill", x, y, r)
end

function program_rings()
    local t = love.timer.getTime()
    local x = 320 + 120 * math.sin(t * 0.21)
    local y = 240 + 80  * math.cos(t * 0.17)

    local r = 20 + 200 * (
        0.5 + 0.5 * math.sin(t * 1.13)
    )

    local cr, cg, cb = _hsv(t * 0.1)

    love.graphics.setColor(cr, cg, cb)
    love.graphics.circle("line", x, y, r)
end


function program_square()
    local t = love.timer.getTime()

    love.graphics.clear()
    love.graphics.setLineWidth(5)
    for i=0,16 do
        local cr, cg, cb = _hsv(i + (t) / 2)
        love.graphics.setColor(cr, cg, cb)
        love.graphics.rectangle("line", 320 - i * 20 + 15 * (15 - i) * math.sin(t), 240 - i * 20 + 15 * (15 - i) * math.cos(t), i * 40, i * 40)
    end
    love.graphics.setLineWidth(1)
end

