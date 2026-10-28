#!/bin/bash
# Waybar: laptop panel Hz

SETTINGS="$HOME/.config/hypr/settings/laptop-refresh-hz"
SCRIPT="$HOME/.config/hypr/scripts/refresh-rate.sh"

preferred=165
[ -f "$SETTINGS" ] && preferred=$(tr -d '[:space:]' <"$SETTINGS")

current=$("$SCRIPT" current 2>/dev/null || echo "$preferred")
[ -z "$current" ] && current="$preferred"

if [ "$preferred" = "60" ]; then
    css="hz-60"
    tip="Panel: 60 Hz (pil tasarrufu)"
else
    css="hz-165"
    tip="Panel: 165 Hz (akıcı)"
fi

if [ -n "$current" ] && [ "$current" != "$preferred" ]; then
    tip="${tip}
Şu an: ${current} Hz — uygulanıyor…"
fi

tip="${tip}
Sol tık: 60 ↔ 165
Sağ tık: menü"

python3 -c 'import json,sys; print(json.dumps({"text": sys.argv[1], "tooltip": sys.argv[2], "class": sys.argv[3]}))' \
    "${preferred}Hz" "$tip" "$css"
