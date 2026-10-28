#!/bin/bash
# Rofi yedek — GTK açılmazsa

HYPRSCRIPTS="$HOME/.config/hypr/scripts"
ROFI_CFG="$HOME/.config/rofi/config-compact.rasi"
choice=$(printf 'Görünüm ayarları (GTK önerilir)\nDuvar kağıdı aç/kapat\nWaypaper\nGPU değiştir\nBluetooth\nHyprland reload' | rofi -dmenu -i -p "Ayarlar (yedek)" -config "$ROFI_CFG") || exit 0

case "$choice" in
    *Duvar*) "$HYPRSCRIPTS/wallpaper-toggle.sh" ;;
    *Waypaper*) "$HYPRSCRIPTS/waypaper-open.sh" ;;
    *GPU*) "$HYPRSCRIPTS/gpu-switch.sh" ;;
    *Bluetooth*) "$HYPRSCRIPTS/bt-manager.sh" ;;
    *reload*) hyprctl reload ;;
    *) python3 "$HOME/.config/hypr/settings-app/hypr-settings.py" & ;;
esac
