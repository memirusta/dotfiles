#!/bin/bash
# Arch güncelleme sayacı — waybar custom/updates modülü

threshhold_green=0
threshhold_yellow=25
threshhold_red=100

if ! command -v checkupdates-with-aur >/dev/null 2>&1; then
    printf '{"text": "?", "alt": "0", "tooltip": "checkupdates-with-aur not installed", "class": "green"}'
    exit 0
fi

while [ -f /var/lib/pacman/db.lck ] || [ -f "${TMPDIR:-/tmp}/checkup-db-${UID}/db.lck" ]; do
    sleep 1
done

updates=$(checkupdates-with-aur 2>/dev/null | wc -l)
css_class="green"

[ "$updates" -gt "$threshhold_yellow" ] && css_class="yellow"
[ "$updates" -gt "$threshhold_red" ] && css_class="red"

if [ "$updates" -gt "$threshhold_green" ]; then
    printf '{"text": "%s", "alt": "%s", "tooltip": "Click to update system", "class": "%s"}' "$updates" "$updates" "$css_class"
else
    printf '{"text": "0", "alt": "0", "tooltip": "No updates available", "class": "green"}'
fi
