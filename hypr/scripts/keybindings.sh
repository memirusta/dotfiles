#!/usr/bin/env bash
set -u
help_file="$HOME/.config/hypr/keybindings-help.tsv"
rofi_config="$HOME/.config/rofi/config-compact.rasi"

if [[ ! -r "$help_file" ]]; then
    notify-send -a "Hyprland" "Kısayol listesi bulunamadı" "$help_file"
    exit 1
fi

awk -F '\t' 'NF >= 2 { printf "%s\r%s\n", $1, $2 }' "$help_file" |
    rofi -dmenu -i -markup -eh 2 -replace -p "Keybinds" -config "$rofi_config"
