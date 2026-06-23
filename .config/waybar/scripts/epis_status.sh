#!/bin/bash
STATE_FILE="$HOME/.epis_mode"

if [ ! -f "$STATE_FILE" ]; then
    echo "logical" > "$STATE_FILE"
fi

MODE=$(cat "$STATE_FILE")

if [ "$MODE" = "logical" ]; then
    echo '{"text": "🧠 İŞ", "class": "logical", "tooltip": "Saf hız, analitik yanıtlar, düşük gecikme."}'
else
    echo '{"text": "💚 EMPATİ", "class": "emotional", "tooltip": "Uzun bağlam, empati, derin detaylı analiz."}'
fi