-- Windows-style window management on top of Hyprland floating windows.
--
--   snap / maximize ...... aero_snap plugin (hl.plugin.aero_snap.*), geometry based
--   minimize / restore ... parked on the special workspace "minimized"; focusing a minimized
--                          window (taskbar click, Alt+Tab, ...) brings it back automatically
--   show desktop ......... Super+D: minimize everything on this workspace, again to restore
--   move to monitor ...... keeps the snap zone on the target monitor
--
-- Every function degrades gracefully if the aero_snap plugin is not loaded
-- (for example after a Hyprland update, before the plugin has been rebuilt).

local M = {}

local MINIMIZED = "special:minimized"
local scripts = (os.getenv("HOME") or "") .. "/.config/hypr/scripts"

local function snap()
    return hl.plugin and hl.plugin.aero_snap or nil
end

local function later(ms, fn)
    hl.timer(fn, { timeout = ms, type = "oneshot" })
end

local function is_minimized(w)
    return w ~= nil and w.workspace ~= nil and w.workspace.name == MINIMIZED
end

local function selector(w)
    return "address:" .. w.address
end

-- ── Minimize / restore ──────────────────────────────────────────────────────────

local hidden_by_desktop = {}

function M.minimize(w)
    w = w or hl.get_active_window()
    if not w or is_minimized(w) then
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = MINIMIZED, follow = false, window = selector(w) }))
end

function M.restore(w)
    if not is_minimized(w) then
        return
    end
    local ws = hl.get_active_workspace()
    if not ws then
        return
    end
    hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id), follow = true, window = selector(w) }))

    -- Focusing a parked window may have revealed the special workspace; hide it again.
    local special = hl.get_active_special_workspace()
    if special and special.name == MINIMIZED then
        hl.dispatch(hl.dsp.workspace.toggle_special("minimized"))
    end

    hl.dispatch(hl.dsp.focus({ window = selector(w) }))
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top", window = selector(w) }))
end

function M.restore_all()
    for _, w in ipairs(hl.get_windows()) do
        if is_minimized(w) then
            M.restore(w)
        end
    end
    hidden_by_desktop = {}
end

-- Win+D: hide everything on the current workspace, press again to bring it all back.
function M.show_desktop()
    if #hidden_by_desktop > 0 then
        for _, address in ipairs(hidden_by_desktop) do
            local w = hl.get_window("address:" .. address)
            if w then
                M.restore(w)
            end
        end
        hidden_by_desktop = {}
        return
    end

    local ws = hl.get_active_workspace()
    if not ws then
        return
    end
    for _, w in ipairs(hl.get_windows()) do
        if w.mapped and not is_minimized(w) and w.workspace and w.workspace.id == ws.id and not w.pinned then
            hidden_by_desktop[#hidden_by_desktop + 1] = w.address
            M.minimize(w)
        end
    end
end

-- Clicking a minimized window's taskbar button / Alt+Tab-ing to it restores it.
hl.on("window.active", function(w)
    if is_minimized(w) then
        M.restore(w)
    end
end)

-- ── Snapping / maximize ─────────────────────────────────────────────────────────

local focus_dirs = { left = "left", right = "right", up = "up", down = "down" }

-- Super+Arrow. Floating window: Windows-style snap state machine.
-- Tiled / fullscreen window (or plugin missing): plain focus movement; Down on an
-- unsnapped floating window minimizes it, like Windows.
function M.arrow(dir)
    local s = snap()
    local result = s and s.step(dir) or "unavailable"

    if result == "unavailable" then
        hl.dispatch(hl.dsp.focus({ direction = focus_dirs[dir] }))
    elseif result == "unchanged" and dir == "down" and s.zone() == "none" then
        M.minimize()
    end
end

function M.toggle_maximize()
    local s = snap()
    if s and s.toggle_maximize() ~= "unavailable" then
        return
    end
    -- Fallback when the plugin is unavailable.
    hl.dispatch(hl.dsp.exec_cmd(scripts .. "/windows-maximize.sh"))
end

function M.snap_zone(zone)
    local s = snap()
    if s then
        s.snap(zone)
    end
end

-- Super+Shift+Left/Right: send the window to the neighbouring monitor, keeping its snap zone.
function M.move_to_monitor(dir)
    local s = snap()
    local zone = s and s.zone() or "none"
    hl.dispatch(hl.dsp.window.move({ monitor = dir, follow = true }))
    if s and zone ~= "none" then
        later(60, function()
            s.snap(zone)
        end)
    end
end

-- Exposed for title-bar buttons (hyprctl eval 'EmirWindows.minimize()').
_G.EmirWindows = M

return M
