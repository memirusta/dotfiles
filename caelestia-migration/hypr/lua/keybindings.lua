local main = "SUPER"
local scripts = (os.getenv("HOME") or "") .. "/.config/hypr/scripts"
local function exec(command)
    return hl.dsp.exec_cmd(command)
end
local windows = require("lua/windows")

-- Toggle all windows on the active workspace between Windows-style floating
-- and Hyprland's tiled layout.
local function toggle_workspace_window_mode()
    local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not workspace then
        return
    end

    local windows = hl.get_workspace_windows(workspace)
    if #windows == 0 then
        return
    end

    local make_floating = false
    for _, window in ipairs(windows) do
        if not window.floating then
            make_floating = true
            break
        end
    end

    for _, window in ipairs(windows) do
        hl.dispatch(hl.dsp.window.float({
            action = make_floating and "set" or "unset",
            window = window,
        }))
        if make_floating then
            hl.dispatch(hl.dsp.window.center({ window = window }))
        end
    end

    hl.notification.create({
        text = make_floating and "Windows mode: floating" or "Hyprland mode: tiled",
        timeout = 1800,
        icon = "ok",
    })
end

-- Applications
hl.bind(main .. " + RETURN", exec("kitty"))
hl.bind(main .. " + B", exec("google-chrome-stable"))
hl.bind(main .. " + E", exec("dolphin"))
hl.bind(main .. " + CTRL + E", exec("pkill fuzzel || caelestia emoji -p"))
hl.bind(main .. " + CTRL + C", exec("gnome-calculator"))

-- Windows
hl.bind(main .. " + Q", hl.dsp.window.close())
hl.bind(main .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(main .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(main .. " + M", function() windows.toggle_maximize() end)
hl.bind(main .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(main .. " + SHIFT + T", toggle_workspace_window_mode)
hl.bind(main .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))


hl.bind(main .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


hl.bind(main .. " + G", hl.dsp.group.toggle())

-- Windows-style window keys ---------------------------------------------------
--   Super+Arrows ........ snap (half / quarter / maximize / restore); Down on a free window minimizes
--   Super+Alt+Arrows .... move focus          Super+Ctrl+Shift+Arrows .. swap tiled windows
--   Super+Shift+Left/Right  move window to the other monitor (keeps its snap zone)
--   Super+Alt+Shift+Arrows  resize by 100 px
--   Super+D ............. show desktop        Super+Shift+M ........... restore minimized windows
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(main .. " + " .. dir, function() windows.arrow(dir) end)
    hl.bind(main .. " + ALT + " .. dir, hl.dsp.focus({ direction = dir }))
    hl.bind(main .. " + CTRL + SHIFT + " .. dir, hl.dsp.window.swap({ direction = dir }))
end
hl.bind(main .. " + SHIFT + left", function() windows.move_to_monitor("l") end)
hl.bind(main .. " + SHIFT + right", function() windows.move_to_monitor("r") end)
hl.bind(main .. " + ALT + SHIFT + right", hl.dsp.window.resize({ x = 100,  y = 0,    relative = true }), { repeating = true })
hl.bind(main .. " + ALT + SHIFT + left",  hl.dsp.window.resize({ x = -100, y = 0,    relative = true }), { repeating = true })
hl.bind(main .. " + ALT + SHIFT + down",  hl.dsp.window.resize({ x = 0,    y = 100,  relative = true }), { repeating = true })
hl.bind(main .. " + ALT + SHIFT + up",    hl.dsp.window.resize({ x = 0,    y = -100, relative = true }), { repeating = true })
hl.bind(main .. " + D", function() windows.show_desktop() end)
hl.bind(main .. " + SHIFT + M", function() windows.restore_all() end)

-- Alt+Tab: snappy-switcher (MRU, Windows-like). Hold Alt, Tab / Shift+Tab to cycle, release to switch.
-- Minimized windows (special:minimized) are listed too; focusing one restores it (lua/windows.lua).
hl.bind("ALT + Tab", exec("snappy-switcher next --mod alt"))
hl.bind("ALT + SHIFT + Tab", exec("snappy-switcher prev --mod alt"))

-- Actions
hl.bind(main .. " + CTRL + R", exec("hyprctl reload"))
hl.bind(main .. " + SHIFT + A", exec(scripts .. "/toggle-animations.sh"))
hl.bind(main .. " + PRINT", exec(scripts .. "/screenshot.sh"))
hl.bind(main .. " + SHIFT + S", exec(scripts .. "/screenshot.sh"))
hl.bind(main .. " + CTRL + Q", hl.dsp.global("caelestia:session"))
hl.bind(main .. " + SHIFT + V", exec(scripts .. "/wallpaper-toggle.sh"))
hl.bind(main .. " + SHIFT + W", exec("waypaper --random"))
hl.bind(main .. " + CTRL + W", exec(scripts .. "/waypaper-open.sh"))
hl.bind(main .. " + ALT + W", exec(scripts .. "/wallpaper-automation.sh"))
hl.bind(main .. " + CTRL + RETURN", hl.dsp.global("caelestia:launcher"))
hl.bind(main .. " + CTRL + K", exec(scripts .. "/keybindings.sh"))
-- Restart the Caelestia shell (it hot-reloads shell.json by itself; this is for when it misbehaves)
hl.bind(main .. " + SHIFT + B", exec("qs -c caelestia kill; sleep .2; caelestia shell -d"))
hl.bind(main .. " + CTRL + B", hl.dsp.global("caelestia:dashboard"))
hl.bind(main .. " + A", hl.dsp.global("caelestia:utilities"))   -- quick toggles (old control center)
hl.bind(main .. " + N", hl.dsp.global("caelestia:sidebar"))     -- notifications sidebar
hl.bind(main .. " + SHIFT + R", exec(scripts .. "/loadconfig.sh"))
hl.bind(main .. " + V", exec("vicinae vicinae://launch/clipboard/history"))
hl.bind(main .. " + SHIFT + H", exec(scripts .. "/hyprshade.sh"))
hl.bind(main .. " + I", exec(scripts .. "/settings.sh"))
hl.bind(main .. " + CTRL + G", exec(scripts .. "/gpu-switch.sh"))
hl.bind(main .. " + CTRL + M", exec(scripts .. "/monitors.sh force"))
hl.bind(main .. " + ALT + M", exec(scripts .. "/monitors.sh fix"))
hl.bind(main .. " + SPACE", exec(scripts .. "/keyboard-layout.sh"))
hl.bind(main .. " + CTRL + L", hl.dsp.global("caelestia:lock"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(main .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(main .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
    hl.bind(main .. " + CTRL + " .. key, exec(scripts .. "/moveTo.sh " .. i))
end

hl.bind(main .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(main .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))
hl.bind(main .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main .. " + CTRL + down", hl.dsp.focus({ workspace = "empty" }))

-- Fn keys
-- Brightness / media go through Caelestia (it shows the OSD); volume via wpctl, Caelestia's OSD picks it up.
hl.bind("XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), { locked = true })
hl.bind("XF86AudioRaiseVolume", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.global("caelestia:mediaToggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.global("caelestia:mediaNext"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev"), { locked = true })
hl.bind("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86Calculator", exec("gnome-calculator"), { locked = true })
hl.bind("XF86ScreenSaver", hl.dsp.global("caelestia:lock"), { locked = true })
hl.bind("code:238", exec("brightnessctl -d smc::kbd_backlight s +10"), { locked = true, repeating = true })
hl.bind("code:237", exec("brightnessctl -d smc::kbd_backlight s 10-"), { locked = true, repeating = true })
