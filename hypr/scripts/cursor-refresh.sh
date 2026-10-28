#!/bin/bash
# Cursor yenileme davranışı — 60 Hz'de monitör düzeltmesi ve smooth scroll kapalı

SETTINGS_HZ="$HOME/.config/hypr/settings/laptop-refresh-hz"
CURSOR_SETTINGS="$HOME/.config/Cursor/User/settings.json"
CURSOR_BACKUP="$HOME/.config/hypr/settings/cursor-refresh-backup.json"

preferred_hz() {
    if [ -f "$SETTINGS_HZ" ]; then
        local hz
        hz=$(tr -d '[:space:]' <"$SETTINGS_HZ")
        case "$hz" in
            60|165) echo "$hz"; return ;;
        esac
    fi
    echo 165
}

cursor_refresh_enabled() {
    [ "$(preferred_hz)" != "60" ]
}

apply_cursor_settings() {
    python3 - <<'PY' "$CURSOR_SETTINGS" "$CURSOR_BACKUP" "$(preferred_hz)"
import json, sys
from pathlib import Path

settings_path = Path(sys.argv[1])
backup_path = Path(sys.argv[2])
hz = sys.argv[3]

data = {}
if settings_path.exists():
    data = json.loads(settings_path.read_text())

low_power = {
    "editor.smoothScrolling": False,
    "workbench.list.smoothScrolling": False,
    "terminal.integrated.smoothScrolling": False,
    "editor.cursorSmoothCaretAnimation": "off",
    "workbench.reduceMotion": "on",
}

high_refresh = {
    "editor.smoothScrolling": True,
    "workbench.list.smoothScrolling": True,
    "terminal.integrated.smoothScrolling": True,
    "editor.cursorSmoothCaretAnimation": "on",
    "workbench.reduceMotion": "off",
}

if hz == "60":
    if not backup_path.exists():
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        saved = {k: data.get(k) for k in low_power if k in data}
        backup_path.write_text(json.dumps(saved, indent=4) + "\n")
    data.update(low_power)
else:
    if backup_path.exists():
        try:
            saved = json.loads(backup_path.read_text())
            for key, value in saved.items():
                data[key] = value
        except json.JSONDecodeError:
            pass
        backup_path.unlink(missing_ok=True)
    else:
        data.update(high_refresh)

settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(data, indent=4) + "\n")
PY
}

case "${1:-sync}" in
    sync)
        apply_cursor_settings
        ;;
    enabled)
        cursor_refresh_enabled && echo yes || echo no
        ;;
    *)
        echo "Kullanım: $0 [sync|enabled]"
        exit 1
        ;;
esac
