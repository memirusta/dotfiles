#!/bin/bash
# Waybar: wallpaper on/off — SVG via CSS class (same pattern as chrome/spotify icons)

STATE="$HOME/.config/hypr/settings/wallpaper-disabled"

if [ -f "$STATE" ]; then
    tip="Wallpaper off (black)\nClick to enable"
    css="wallpaper-off"
else
    tip="Wallpaper on\nClick to disable (black screen)"
    css="wallpaper-on"
fi

python3 -c 'import json,sys; print(json.dumps({"text": " ", "tooltip": sys.argv[1], "class": sys.argv[2]}))' \
    "$tip" "$css"
