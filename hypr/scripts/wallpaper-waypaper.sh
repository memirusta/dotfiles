#!/bin/bash
# Waypaper post_command girişi — boşluk kaçışlarını düzeltir

path="$1"
path="${path//\\ / }"

exec "$HOME/.config/hypr/scripts/wallpaper.sh" "$path"
