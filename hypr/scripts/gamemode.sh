#!/usr/bin/env bash
set -euo pipefail
state="$HOME/.config/hypr/settings/gamemode-enabled"

if [[ -f "$state" ]]; then
    hyprctl reload
    rm -f "$state"
    notify-send "Gamemode deactivated" "Animations and blur enabled"
else
    hyprctl eval 'hl.config({
        animations = { enabled = false },
        decoration = {
            rounding = 0,
            shadow = { enabled = false },
            blur = { enabled = false }
        },
        general = {
            gaps_in = 0,
            gaps_out = 0,
            border_size = 1
        }
    })'
    mkdir -p "$(dirname "$state")"
    touch "$state"
    notify-send "Gamemode activated" "Animations and blur disabled"
fi
