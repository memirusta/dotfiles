#!/bin/bash
# Oturum açılışında son duvar kağıdını yükle (statik + video)

defaultwallpaper="$HOME/wallpaper/default.jpg"
cachefile="$HOME/.config/hypr/cache/current_wallpaper"

if waypaper --restore 2>/dev/null; then
    echo ":: Wallpaper restored via waypaper"
    exit 0
fi

if [ -f "$cachefile" ]; then
    sed -i "s|~|$HOME|g" "$cachefile"
    wallpaper=$(cat "$cachefile")
    if [ -f "$wallpaper" ]; then
        waypaper --wallpaper "$wallpaper"
        exit 0
    fi
fi

if [ -f "$defaultwallpaper" ]; then
    waypaper --wallpaper "$defaultwallpaper"
else
    echo ":: No wallpaper found"
fi
