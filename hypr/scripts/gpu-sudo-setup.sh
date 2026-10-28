#!/bin/bash
# Bir kez çalıştır: sudo /home/memir/.config/hypr/scripts/gpu-sudo-setup.sh

set -euo pipefail

user="${SUDO_USER:-$USER}"
envy="/home/memir/.local/bin/envycontrol"
wrapper="/home/memir/.config/hypr/scripts/gpu-switch-root.sh"

[ -x /usr/bin/envycontrol ] && envy="/usr/bin/envycontrol"
[ -x "$envy" ] || { echo "envycontrol bulunamadı: $envy"; exit 1; }
chmod +x "$wrapper"

file="/etc/sudoers.d/envycontrol"
cat > "$file" <<EOF
# GPU geçişi — Waybar ($user)
Defaults:$user !requiretty
$user ALL=(ALL) NOPASSWD:SETENV: $envy *
$user ALL=(ALL) NOPASSWD:SETENV: $wrapper *
EOF

chmod 440 "$file"
visudo -cf "$file"
echo "Tamam. Test: sudo -n -E $wrapper nvidia"
