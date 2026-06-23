#!/bin/bash
STATE_FILE="$HOME/.epis_mode"
MODE=$(cat "$STATE_FILE")

if [ "$MODE" = "logical" ]; then
    echo "emotional" > "$STATE_FILE"
else
    echo "logical" > "$STATE_FILE"
fi

# Waybar'ın beklemeden anında güncellenmesi için sinyal gönderir
pkill -RTMIN+8 waybar