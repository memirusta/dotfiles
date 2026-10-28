#!/bin/bash
VIDEO="$HOME/wallpaper/default.mp4"
IMAGE="$HOME/wallpaper/default.jpg"

get_monitors() {
    hyprctl monitors | awk '/^Monitor / {gsub(/:$/, "", $2); print $2}'
}

stop_wallpapers() {
    pkill -x mpvpaper 2>/dev/null || true
}

start_static() {
    local target="$1"

    if ! command -v swww >/dev/null 2>&1; then
        return 0
    fi

    if ! pgrep -x swww-daemon >/dev/null; then
        swww-daemon &
        sleep 0.3
    fi

    if [ -n "$target" ]; then
        swww img "$target" --transition-type fade --transition-duration 1
    else
        swww clear 11111b
    fi
}

start_video() {
    if ! command -v mpvpaper >/dev/null 2>&1; then
        return 1
    fi

    killall swww-daemon 2>/dev/null || true
    sleep 0.2
    stop_wallpapers

    while IFS= read -r monitor; do
        [ -n "$monitor" ] || continue
        mpvpaper -f -p -o "hwdec=no no-audio loop" "$monitor" "$VIDEO" &
        sleep 0.2
    done < <(get_monitors)
}

stop_wallpapers

if [ -f "$VIDEO" ]; then
    start_video || start_static "$IMAGE"
elif [ -f "$IMAGE" ]; then
    start_static "$IMAGE"
else
    start_static ""
fi
