#!/bin/bash
# Cursor açılınca Hz düşerse hemen düzelt (yalnızca 165 Hz modunda)

SETTINGS_HZ="$HOME/.config/hypr/settings/laptop-refresh-hz"

refresh_fix_enabled() {
    local hz=165
    if [ -f "$SETTINGS_HZ" ]; then
        hz=$(tr -d '[:space:]' <"$SETTINGS_HZ")
    fi
    [ "$hz" != "60" ]
}

last=0
while true; do
    if refresh_fix_enabled; then
        running=$(pgrep -fc 'cursor|Cursor' 2>/dev/null || echo 0)
        if [ "$running" -gt 0 ] && [ "$last" -eq 0 ]; then
            sleep 4
            "$HOME/.config/hypr/scripts/monitors.sh" fix 2>/dev/null || true
            sleep 2
            "$HOME/.config/hypr/scripts/monitors.sh" fix 2>/dev/null || true
        fi
        last=$running
    else
        last=0
    fi
    sleep 2
done
