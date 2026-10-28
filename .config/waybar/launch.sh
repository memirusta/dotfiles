#!/bin/bash
killall waybar 2>/dev/null
pkill waybar 2>/dev/null
sleep 0.5

if [ -f "$HOME/.config/waybar/disabled" ]; then
    echo ":: Waybar disabled"
    exit 0
fi

waybar -c "$HOME/.config/waybar/config.json" -s "$HOME/.config/waybar/style.css" &
