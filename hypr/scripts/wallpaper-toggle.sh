#!/bin/bash
# Video duvar kağıdını aç/kapa — kapalıyken siyah ekran

STATE="$HOME/.config/hypr/settings/wallpaper-disabled"
BLACK="$HOME/wallpaper/black.mp4"
OPTS='hwdec=auto-safe no-audio loop panscan=1.0'

notify() {
    notify-send -a "Wallpaper" -t 2500 "$1" "${2:-}" 2>/dev/null || true
}

ensure_black_video() {
    [ -f "$BLACK" ] && return 0
    command -v ffmpeg >/dev/null 2>&1 || return 1
    mkdir -p "$(dirname "$BLACK")"
    ffmpeg -y -loglevel error \
        -f lavfi -i "color=c=black:s=1920x1080:r=30:d=2" \
        -c:v libx264 -preset ultrafast -pix_fmt yuv420p -t 2 \
        "$BLACK"
}

black_running() {
    local monitor count=0 running=0
    while IFS= read -r monitor; do
        [ -n "$monitor" ] || continue
        count=$((count + 1))
        pgrep -f "mpvpaper.*[[:space:]]${monitor}[[:space:]]" >/dev/null 2>&1 && \
            running=$((running + 1))
    done < <(hyprctl monitors 2>/dev/null | awk '/^Monitor / {gsub(/:$/, "", $2); print $2}')
    [ "$count" -gt 0 ] && [ "$running" -eq "$count" ]
}

apply_black() {
    ensure_black_video || { notify "Wallpaper" "ffmpeg required for black screen"; return 1; }

    if black_running && pgrep -f "mpvpaper.*${BLACK}" >/dev/null 2>&1; then
        return 0
    fi

    pkill -x mpvpaper 2>/dev/null || true
    sleep 0.2

    local monitor
    while IFS= read -r monitor; do
        [ -n "$monitor" ] || continue
        mpvpaper -f -p -o "$OPTS" "$monitor" "$BLACK" &
        sleep 0.1
    done < <(hyprctl monitors 2>/dev/null | awk '/^Monitor / {gsub(/:$/, "", $2); print $2}')
}

apply_normal() {
    rm -f "$STATE"
    pkill -x mpvpaper 2>/dev/null || true
    sleep 0.2
    if [ -x "$HOME/.config/hypr/scripts/wallpaper-boot.sh" ]; then
        "$HOME/.config/hypr/scripts/wallpaper-boot.sh"
    fi
}

toggle() {
    mkdir -p "$(dirname "$STATE")"
    if [ -f "$STATE" ]; then
        apply_normal
        notify "Wallpaper" "On"
    else
        touch "$STATE"
        apply_black
        notify "Wallpaper" "Off — black screen"
    fi
}

case "${1:-toggle}" in
    toggle) toggle ;;
    black|off)
        mkdir -p "$(dirname "$STATE")"
        touch "$STATE"
        apply_black
        ;;
    on)
        apply_normal
        notify "Wallpaper" "On"
        ;;
    status)
        [ -f "$STATE" ] && echo off || echo on
        ;;
    *)
        toggle
        ;;
esac
