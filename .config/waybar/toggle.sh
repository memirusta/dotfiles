#!/bin/bash
if [ -f "$HOME/.config/waybar/disabled" ]; then
    rm "$HOME/.config/waybar/disabled"
else
    touch "$HOME/.config/waybar/disabled"
fi
"$HOME/.config/waybar/launch.sh" &
