local home = os.getenv("HOME") or ""
local scripts = home .. "/.config/hypr/scripts"

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Adwaita 22")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    local commands = {
        scripts .. "/bt-agent.sh",
        scripts .. "/bt-obex.sh start",
        scripts .. "/ensure-session.sh",
        scripts .. "/xdg.sh",
        scripts .. "/monitors.sh",
        scripts .. "/monitors.sh listen",
        scripts .. "/cursor-monitor-watch.sh",
        scripts .. "/battery-mode.sh listen",
        "sleep 8 && " .. scripts .. "/monitors.sh force",
        "sleep 20 && " .. scripts .. "/monitors.sh force",
        "sleep 45 && " .. scripts .. "/monitors.sh force",
        "noctalia --daemon",
        scripts .. "/gtk.sh",
        scripts .. "/cleanup.sh",
    }

    for _, command in ipairs(commands) do
        hl.exec_cmd(command)
    end
end)
