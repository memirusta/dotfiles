#!/bin/bash
# One-time: Bluetooth file transfer (OBEX)

set -e
echo "Installing Bluetooth file transfer packages…"
sudo pacman -S --needed bluez-obex zenity

echo "Enabling OBEX service…"
systemctl --user enable --now obex.service

mkdir -p "$HOME/Downloads/Bluetooth"

echo "Starting OBEX receive agent…"
pkill -f bt-obex-agent.py 2>/dev/null || true
nohup python3 "$HOME/.config/hypr/scripts/bt-obex-agent.py" >/tmp/bt-obex-agent.log 2>&1 &

notify-send -a "Bluetooth" "File transfer ready" "Received files: ~/Downloads/Bluetooth" 2>/dev/null || true
echo "Done. Send from Waybar → Bluetooth → Send file"
