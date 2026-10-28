-- Environment. Duplicate legacy values were collapsed to their final effective value.
local vars = {
    XDG_CURRENT_DESKTOP = "Hyprland",
    XDG_SESSION_TYPE = "wayland",
    XDG_SESSION_DESKTOP = "Hyprland",
    QT_QPA_PLATFORM = "wayland;xcb",
    QT_QPA_PLATFORMTHEME = "qt5ct",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1",
    QT_AUTO_SCREEN_SCALE_FACTOR = "1",
    GDK_SCALE = "1",
    GDK_BACKEND = "wayland,x11,*",
    CLUTTER_BACKEND = "wayland",
    MOZ_ENABLE_WAYLAND = "1",
    XCURSOR_SIZE = "24",
    OZONE_PLATFORM = "wayland",
    ELECTRON_OZONE_PLATFORM_HINT = "auto",
    SDL_VIDEODRIVER = "wayland",
    __GL_GSYNC_ALLOWED = "0",
    __GL_THREADED_OPTIMIZATIONS = "1",
}

for name, value in pairs(vars) do
    hl.env(name, value)
end
