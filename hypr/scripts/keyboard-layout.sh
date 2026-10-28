#!/bin/bash
hyprctl switchxkblayout all next

layout=$(hyprctl devices -j | python3 -c "
import json, sys
for k in json.load(sys.stdin).get('keyboards', []):
    if k.get('main'):
        print(k.get('active_keymap', ''))
        break
")

case "$layout" in
    *Turkish*) notify-send "Klavye" "TRQ" ;;
    *) notify-send "Klavye" "US" ;;
esac
