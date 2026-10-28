#!/bin/bash
# Prize takılı / pil — güç profili ve Hz otomasyonu

STATE="$HOME/.cache/hypr-battery-ac-state"
SETTINGS_LAPTOP_HZ="$HOME/.config/hypr/settings/laptop-refresh-hz"
SETTINGS_EXT_HZ="$HOME/.config/hypr/settings/external-refresh-hz"
MONITORS="$HOME/.config/hypr/scripts/monitors.sh"
REFRESH="$HOME/.config/hypr/scripts/refresh-rate.sh"
CURSOR_REFRESH="$HOME/.config/hypr/scripts/cursor-refresh.sh"

mkdir -p "$(dirname "$STATE")" "$(dirname "$SETTINGS_LAPTOP_HZ")"

ac_online() {
    local ac online
    for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        [ -f "$ac" ] || continue
        online=$(tr -d '[:space:]' <"$ac")
        [ "$online" = "1" ] && return 0
    done
    return 1
}

external_connected() {
    hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    d = m.get('description', '').lower()
    n = m.get('name', '')
    if '25g4s' in d or (not n.startswith('eDP') and n):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

save_ac_state() {
    local profile laptop_hz ext_hz
    profile=$(powerprofilesctl get 2>/dev/null || echo balanced)
    laptop_hz=$(tr -d '[:space:]' <"$SETTINGS_LAPTOP_HZ" 2>/dev/null || echo 165)
    ext_hz=$(tr -d '[:space:]' <"$SETTINGS_EXT_HZ" 2>/dev/null || echo 300)
    printf 'profile=%s\nlaptop_hz=%s\next_hz=%s\n' "$profile" "$laptop_hz" "$ext_hz" >"$STATE"
}

load_state_var() {
    local key="${1:?}"
    [ -f "$STATE" ] || return 1
    sed -n "s/^${key}=//p" "$STATE" | head -1
}

apply_monitors() {
    [ -x "$MONITORS" ] && "$MONITORS" force >/dev/null 2>&1 || true
}

apply_battery() {
    save_ac_state

    powerprofilesctl set power-saver >/dev/null 2>&1 || true
    printf '%s\n' 60 >"$SETTINGS_LAPTOP_HZ"
    [ -x "$CURSOR_REFRESH" ] && "$CURSOR_REFRESH" sync 2>/dev/null || true
    apply_monitors

    if external_connected; then
        notify-send -a "Pil modu" -t 8000 "Harici monitör: 60 Hz" "Laptop paneli: 60 Hz
Güç: power-saver

Not: Harici monitör için NVIDIA açık kalmalı (yeniden başlatma gerekmez).
Tahmini pil: ~1,5–2,5 saat."
    else
        notify-send -a "Pil modu" -t 8000 "Pil modu aktif" "60 Hz + power-saver

Sadece laptop ile max pil için: integrated GPU + yeniden başlat."
    fi
}

apply_ac() {
    local profile laptop_hz ext_hz

    profile=$(load_state_var profile || echo balanced)
    laptop_hz=$(load_state_var laptop_hz || echo 165)
    ext_hz=$(load_state_var ext_hz || echo 300)

    case "$profile" in
        performance|balanced|power-saver) ;;
        *) profile=balanced ;;
    esac
    case "$laptop_hz" in
        60|165) ;;
        *) laptop_hz=165 ;;
    esac
    case "$ext_hz" in
        60|120|144|165|240|300) ;;
        *) ext_hz=300 ;;
    esac

    powerprofilesctl set "$profile" >/dev/null 2>&1 || true
    printf '%s\n' "$laptop_hz" >"$SETTINGS_LAPTOP_HZ"
    printf '%s\n' "$ext_hz" >"$SETTINGS_EXT_HZ"
    [ -x "$CURSOR_REFRESH" ] && "$CURSOR_REFRESH" sync 2>/dev/null || true
    apply_monitors

    notify-send -a "Prize takılı" -t 6000 "Masaüstü modu" "Panel: ${laptop_hz} Hz
Harici: ${ext_hz} Hz
Güç: ${profile}"
}

sync() {
    if ac_online; then
        apply_ac
    else
        apply_battery
    fi
}

listen() {
    local last="" cur
    while true; do
        if ac_online; then cur=ac; else cur=battery; fi
        if [ "$cur" != "$last" ]; then
            if [ "$cur" = "ac" ]; then
                apply_ac
            else
                apply_battery
            fi
            last=$cur
        fi
        sleep 2
    done
}

case "${1:-sync}" in
    sync) sync ;;
    battery) apply_battery ;;
    ac) apply_ac ;;
    listen) listen ;;
    status)
        if ac_online; then echo ac; else echo battery; fi
        ;;
    *)
        echo "Kullanım: $0 [sync|battery|ac|listen|status]"
        exit 1
        ;;
esac
