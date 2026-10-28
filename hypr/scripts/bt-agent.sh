#!/bin/bash
# Bluetooth eşleştirme — ortada rofi onay penceresi

export PATH="/usr/bin:$PATH"
bash "$HOME/.config/hypr/scripts/bt-visibility.sh" watch &
exec python3 "$HOME/.config/hypr/scripts/bt-agent.py"
