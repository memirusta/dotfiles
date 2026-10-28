#!/bin/bash
# Ayarlar — GTK pencere (varsayılan) veya rofi yedek

APP="$HOME/.config/hypr/settings-app/hypr-settings.py"
ROFI="$HOME/.config/hypr/scripts/settings-rofi.sh"

case "${1:-}" in
    --rofi)
        exec "$ROFI"
        ;;
    *)
        if [ -f "$APP" ]; then
            exec python3 "$APP" "$@"
        fi
        exec "$ROFI"
        ;;
esac
