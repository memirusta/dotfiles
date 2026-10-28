#!/bin/bash
exec >>"$HOME/.cache/epis-autostart.log" 2>&1
echo "=== autostart $(date) ==="

sleep 2

"$HOME/.config/hypr/scripts/wallpaper.sh" &
sleep 1

pkill -x waybar 2>/dev/null || true
"$HOME/.config/waybar/launch.sh"

if ! pgrep -x swaync >/dev/null; then
    pkill -x dunst 2>/dev/null || true
    dunst &
    disown
fi

if ! pgrep -x hypridle >/dev/null; then
    hypridle &
    disown
fi

echo "done: waybar=$(pgrep -x waybar) mpvpaper=$(pgrep -c mpvpaper)"
