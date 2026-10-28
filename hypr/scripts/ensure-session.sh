#!/usr/bin/env bash
# Oturum başında klavye + kısayol kontrolü (Lua config uyumlu)

hyprctl eval 'hl.config({ input = { kb_layout = "us,tr", kb_options = "" } })' >/dev/null 2>&1 || true

[[ -x "$HOME/.config/hypr/scripts/cursor-refresh.sh" ]] && \
    "$HOME/.config/hypr/scripts/cursor-refresh.sh" sync 2>/dev/null || true

count=$(hyprctl binds -j 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
if [[ "${count:-0}" -lt 1 ]]; then
    hyprctl reload
fi
