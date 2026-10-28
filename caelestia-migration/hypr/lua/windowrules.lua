-- Window and layer rules migrated from windowrules.conf.

local function window_rule(name, match, effects)
    effects.name = name
    effects.match = match
    hl.window_rule(effects)
end

-- Windows-style stacking: normal application windows open floating, centered,
-- and large enough to overlap instead of being squeezed into tiles.
window_rule("windows-style-floating", { class = ".*" }, {
    float = true,
    size = { "monitor_w * 0.78", "monitor_h * 0.78" },
    center = true,
})

window_rule("geometry-dash-monitor", { class = "^steam_app_322170$" }, {
    monitor = "DP-1",
})

window_rule("float-pavu-title", { title = "^(pavucontrol)$" }, { float = true })
window_rule("float-blueman-title", { title = "^(blueman-manager)$" }, { float = true })
window_rule("float-nm-editor", { title = "^(nm-connection-editor)$" }, { float = true })
window_rule("float-qalculate", { title = "^(qalculate-gtk)$" }, { float = true })

window_rule("pip", { title = "^(Picture-in-Picture)$" }, {
    float = true,
    pin = true,
    move = { "monitor_w * 0.695", "monitor_h * 0.04" },
})

-- The old regex ([window]) only matched one character. This is the intended
-- behavior: inhibit idle for any fullscreen window.
window_rule("fullscreen-idle-inhibit", { class = ".*" }, {
    idle_inhibit = "fullscreen",
})

window_rule("pavucontrol", { class = ".*org.pulseaudio.pavucontrol.*" }, {
    float = true,
    size = { 700, 600 },
    center = true,
    pin = true,
})

window_rule("chatgpt-title", { title = "ChatGPT.*" }, { float = true })
window_rule("chatgpt-web", { title = ".*chat.openai.com.*" }, {
    float = true,
    size = { 500, "monitor_h * 0.5" },
    move = { 20, 70 },
})

window_rule("waypaper", { class = ".*waypaper.*" }, {
    float = true,
    size = { 900, 700 },
    center = true,
    pin = true,
})

window_rule("cursor", { class = "cursor" }, {
    no_anim = true,
    no_shortcuts_inhibit = true,
})

window_rule("blueman", { class = "blueman-manager" }, {
    float = true,
    size = { 800, 600 },
    center = true,
})

window_rule("nwg-look", { class = "nwg-look" }, {
    float = true,
    size = { 700, 600 },
    move = { "monitor_w * 0.10", "monitor_h * 0.20" },
    pin = true,
})

window_rule("nwg-displays", { class = "nwg-displays" }, {
    float = true,
    size = { 900, 600 },
    move = { "monitor_w * 0.10", "monitor_h * 0.20" },
    pin = true,
})

window_rule("mission-center", { class = "io.missioncenter.MissionCenter" }, {
    float = true,
    pin = true,
    center = true,
    size = { 900, 600 },
})

window_rule("mission-center-preferences", {
    class = "missioncenter",
    title = "^(Preferences)$",
}, {
    float = true,
    pin = true,
    center = true,
})

window_rule("gnome-calculator", { class = "org.gnome.Calculator" }, {
    float = true,
    size = { 700, 600 },
    center = true,
})

window_rule("smile", { class = "it.mijorus.smile" }, {
    float = true,
    pin = true,
    move = { "monitor_w - window_w - 40", 90 },
})

window_rule("share-picker", { class = "hyprland-share-picker" }, {
    float = true,
    pin = true,
    center = true,
    size = { 600, 400 },
})

window_rule("dotfiles-floating", { class = "dotfiles-floating" }, {
    float = true,
    size = { 1000, 700 },
    center = true,
})


hl.layer_rule({
    name = "rofi-glass",
    match = { namespace = "rofi" },
    blur = true,
    ignore_alpha = 0.4,
})

-- Caelestia surfaces: the shell animates itself, so no Hyprland layer animation; glass blur on the drawers
-- (bar, panels, notifications, OSD all live in caelestia-drawers).
hl.layer_rule({
    name = "caelestia-noanim",
    match = { namespace = "caelestia-(border-exclusion|area-picker)" },
    no_anim = true,
})
hl.layer_rule({
    name = "caelestia-drawers",
    match = { namespace = "caelestia-(drawers|background)" },
    animation = "fade",
    blur = true,
    ignore_alpha = 0.5,
})

-- Alt+Tab switcher and Vicinae (clipboard): glass, no slide-in.
hl.layer_rule({
    name = "snappy-switcher",
    match = { namespace = "snappy-switcher" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0.5,
})
hl.layer_rule({
    name = "vicinae",
    match = { namespace = "vicinae" },
    no_anim = true,
    blur = true,
    ignore_alpha = 0,
})

hl.layer_rule({
    name = "mpvpaper-no-animation",
    match = { namespace = "mpvpaper" },
    no_anim = true,
})

-- A focused floating window always rises to the top of the Z-order.
hl.on("window.active", function(window)
    if window then
        hl.dispatch(hl.dsp.window.alter_zorder({
            mode = "top",
            window = window,
        }))
    end
end)
hl.window_rule({
    name = "no-hyprbar-native-titlebars",

    match = {
        class = "^(com.system76.CosmicFiles|com.system76.cosmic-files|google-chrome|Google-chrome|steam|Steam|code|Code|code-oss|Code - OSS)$",
    },

    ["hyprbars:no_bar"] = true,
})
