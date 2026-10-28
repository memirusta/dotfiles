#!/usr/bin/env bash
set -u
cache_file="$HOME/.cache/toggle_animation"

if [[ -f "$cache_file" ]]; then
    hyprctl eval 'hl.config({ animations = { enabled = true } })'
    rm -f "$cache_file"
else
    hyprctl eval 'hl.config({ animations = { enabled = false } })'
    mkdir -p "$(dirname "$cache_file")"
    touch "$cache_file"
fi
