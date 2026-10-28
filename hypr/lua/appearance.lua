-- Appearance, layout and animations.
-- Reads the Matugen palette already used by Hyprlock from colors.conf.

local function read_palette()
    local colors = {}
    local home = os.getenv("HOME") or ""
    local file = io.open(home .. "/.config/hypr/colors.conf", "r")

    if file then
        for line in file:lines() do
            local name, fn, value = line:match("^%s*%$([%w_]+)%s*=%s*(rgba?)%(([%x]+)%)")
            if name and fn and value then
                colors[name] = fn .. "(" .. value .. ")"
            end
        end
        file:close()
    end

    return colors
end

local palette = read_palette()
local border = palette.on_primary_fixed or "rgba(002022ff)"

hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 0,
        border_size = 0,
        col = {
            active_border = border,
            inactive_border = border,
        },
        layout = "dwindle",
        resize_on_border = true,
        snap = {
            enabled = true,
            window_gap = 10,
            monitor_gap = 10,
            border_overlap = false,
            respect_gaps = true,
        },
    },

    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.8,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 6,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            xray = true,
        },

        shadow = {
            enabled = true,
            range = 30,
            render_power = 3,
            color = 0x66000000,
        },
    },

    misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    initial_workspace_tracking = 1,

    -- Windows-like behavior:
    -- maximized window stays maximized, but another window may take focus.
    on_focus_under_fullscreen = 0,
},

    dwindle = {
        preserve_split = true,
    },

    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles = true,
        pass_mouse_when_bound = false,
    },

    animations = {
        enabled = true,
    },
})

hl.curve("linear",       { type = "bezier", points = { { 0, 0 },       { 1, 1 } } })
hl.curve("md3_standard", { type = "bezier", points = { { 0.2, 0 },     { 0, 1 } } })
hl.curve("md3_decel",    { type = "bezier", points = { { 0.05, 0.7 },  { 0.1, 1 } } })
hl.curve("md3_accel",    { type = "bezier", points = { { 0.3, 0 },     { 0.8, 0.15 } } })
hl.curve("overshot",     { type = "bezier", points = { { 0.05, 0.9 },  { 0.1, 1.1 } } })
hl.curve("crazyshot",    { type = "bezier", points = { { 0.1, 1.5 },   { 0.76, 0.92 } } })
hl.curve("hyprnostretch",{ type = "bezier", points = { { 0.05, 0.9 },  { 0.1, 1.0 } } })
hl.curve("fluent_decel", { type = "bezier", points = { { 0.1, 1 },     { 0, 1 } } })
hl.curve("easeInOutCirc",{ type = "bezier", points = { { 0.85, 0 },    { 0.15, 1 } } })
hl.curve("easeOutCirc",  { type = "bezier", points = { { 0, 0.55 },    { 0.45, 1 } } })
hl.curve("easeOutExpo",  { type = "bezier", points = { { 0.16, 1 },    { 0.3, 1 } } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3,   bezier = "md3_decel",   style = "popin 60%" })
hl.animation({ leaf = "border",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2.5, bezier = "md3_decel" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3.5, bezier = "easeOutExpo", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3,   bezier = "md3_decel",   style = "slidevert" })
