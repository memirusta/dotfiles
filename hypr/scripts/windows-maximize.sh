#!/usr/bin/env bash

set -euo pipefail

STATE_DIR="/tmp/hypr-windows-maximize-$UID"
mkdir -p "$STATE_DIR"

window="$(hyprctl -j activewindow)"

addr="$(jq -r '.address' <<< "$window")"
monitor_id="$(jq -r '.monitor' <<< "$window")"

[[ -z "$addr" || "$addr" == "null" ]] && exit 0

key="${addr#0x}"
state="$STATE_DIR/$key"

# Restore
if [[ -f "$state" ]]; then
    read -r old_x old_y old_w old_h < "$state"

    hyprctl dispatch \
        "hl.dsp.window.resize({ x = $old_w, y = $old_h, relative = false, window = \"address:$addr\" })"

    hyprctl dispatch \
        "hl.dsp.window.move({ x = $old_x, y = $old_y, relative = false, window = \"address:$addr\" })"

    hyprctl dispatch \
        "hl.dsp.window.alter_zorder({ mode = \"top\", window = \"address:$addr\" })"

    rm -f "$state"
    exit 0
fi

# Save current geometry
x="$(jq -r '.at[0]' <<< "$window")"
y="$(jq -r '.at[1]' <<< "$window")"
w="$(jq -r '.size[0]' <<< "$window")"
h="$(jq -r '.size[1]' <<< "$window")"

printf '%s %s %s %s\n' "$x" "$y" "$w" "$h" > "$state"

monitor="$(hyprctl -j monitors | jq ".[] | select(.id == $monitor_id)")"

mx="$(jq -r '.x' <<< "$monitor")"
my="$(jq -r '.y' <<< "$monitor")"
mw="$(jq -r '.width' <<< "$monitor")"
mh="$(jq -r '.height' <<< "$monitor")"
scale="$(jq -r '.scale' <<< "$monitor")"

left="$(jq -r '.reserved[0]' <<< "$monitor")"
top="$(jq -r '.reserved[1]' <<< "$monitor")"
right="$(jq -r '.reserved[2]' <<< "$monitor")"
bottom="$(jq -r '.reserved[3]' <<< "$monitor")"

# width/height are physical; window coordinates are logical.
logical_w="$(awk "BEGIN { printf \"%d\", $mw / $scale }")"
logical_h="$(awk "BEGIN { printf \"%d\", $mh / $scale }")"
class="$(jq -r '.class // ""' <<< "$window" | tr '[:upper:]' '[:lower:]')"

case "$class" in
    *cosmic*|*google-chrome*|steam|code|code-oss)
        BAR_HEIGHT=0
        ;;
    *)
        BAR_HEIGHT=38
        ;;
esac

target_x=$((mx + left))
target_y=$((my + top + BAR_HEIGHT))
target_w=$((logical_w - left - right))
target_h=$((logical_h - top - bottom - BAR_HEIGHT))

# Since Hyprland 0.54+, resize first, then move.
hyprctl dispatch \
    "hl.dsp.window.resize({ x = $target_w, y = $target_h, relative = false, window = \"address:$addr\" })"

hyprctl dispatch \
    "hl.dsp.window.move({ x = $target_x, y = $target_y, relative = false, window = \"address:$addr\" })"

hyprctl dispatch \
    "hl.dsp.window.alter_zorder({ mode = \"top\", window = \"address:$addr\" })"
