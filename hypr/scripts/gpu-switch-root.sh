#!/bin/bash
# sudo ile çağrılır — envycontrol geçişi

set -euo pipefail

export PATH="/home/memir/.local/bin:/usr/bin:$PATH"
ENVY="/home/memir/.local/bin/envycontrol"

mode="${1:-}"
case "$mode" in
    integrated|nvidia|hybrid) ;;
    *) echo "Geçersiz mod: $mode" >&2; exit 1 ;;
esac

# xrandr Wayland'da root ile çalışmaz; envycontrol modesetting'e düşer (patch'li)
exec "$ENVY" -s "$mode" --dm sddm
