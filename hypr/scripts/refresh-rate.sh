#!/bin/bash
# Laptop panel yenileme hızı — 60 Hz (pil) / 165 Hz (akıcılık)

SETTINGS="$HOME/.config/hypr/settings/laptop-refresh-hz"
MONITORS="$HOME/.config/hypr/scripts/monitors.sh"
LAPTOP_MATCH="N153JMA"

mkdir -p "$(dirname "$SETTINGS")"

preferred_hz() {
    if [ -f "$SETTINGS" ]; then
        local hz
        hz=$(tr -d '[:space:]' <"$SETTINGS")
        case "$hz" in
            60|165) echo "$hz"; return ;;
        esac
    fi
    echo 165
}

current_hz() {
    hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
match = sys.argv[1].lower()
for m in json.load(sys.stdin):
    desc = m.get('description', '').lower()
    name = m.get('name', '')
    if match in desc or name.startswith('eDP'):
        print(int(round(float(m.get('refreshRate', 0) or 0))))
        break
" "$LAPTOP_MATCH"
}

set_hz() {
    local hz="${1:-}"
    case "$hz" in
        60|165) ;;
        *)
            echo "Geçersiz Hz: $hz (60 veya 165)" >&2
            return 1
            ;;
    esac
    printf '%s\n' "$hz" >"$SETTINGS"
}

apply() {
  local hz
  hz=$(preferred_hz)
  if [ -x "$MONITORS" ]; then
      "$MONITORS" force >/dev/null 2>&1 || "$MONITORS" fix >/dev/null 2>&1 || true
  else
      code=$(python3 - "$LAPTOP_MATCH" "$hz" <<'PYLUA'
import json, sys
print(
    "hl.monitor({ output = %s, mode = %s, position = \"0x0\", scale = 1.5, vrr = 0 })"
    % (json.dumps("desc:" + sys.argv[1]), json.dumps("1920x1200@" + sys.argv[2]))
)
PYLUA
)
      hyprctl eval "$code" 2>/dev/null || true
  fi
  if [ -x "$HOME/.config/hypr/scripts/cursor-refresh.sh" ]; then
      "$HOME/.config/hypr/scripts/cursor-refresh.sh" sync
  fi
}

notify_change() {
    local hz label extra=""
    hz=$(preferred_hz)
    if [ "$hz" = "60" ]; then
        label="60 Hz — pil tasarrufu"
        extra="
Cursor monitör düzeltmesi kapalı"
    else
        label="165 Hz — akıcı görüntü"
    fi
    notify-send -a "Yenileme hızı" -t 6000 "$label" "Tıkla: değiştir${extra}

Cursor açıksa yeniden başlat."
}

toggle() {
    local cur next
    cur=$(preferred_hz)
    if [ "$cur" = "60" ]; then
        next=165
    else
        next=60
    fi
    set_hz "$next"
    apply
    notify_change
}

menu() {
    local choice cur
    cur=$(preferred_hz)
    choice=$(printf '60 Hz — pil tasarrufu\n165 Hz — akıcı görüntü' | rofi -dmenu -i -p "Panel Hz" -selected-row "$([ "$cur" = "60" ] && echo 0 || echo 1)" 2>/dev/null) || return 0

    case "$choice" in
        60*) set_hz 60 ;;
        165*) set_hz 165 ;;
        *) return 0 ;;
    esac
    apply
    notify_change
}

case "${1:-toggle}" in
    toggle) toggle ;;
    60|165) set_hz "$1"; apply; notify_change ;;
    apply) apply ;;
    query) preferred_hz ;;
    current) current_hz ;;
    menu) menu ;;
    *)
        echo "Kullanım: $0 [toggle|60|165|apply|query|current|menu]"
        exit 1
        ;;
esac
