#!/bin/bash
# Ekran görüntüsü — grim + slurp (grimblast gerekmez)

source ~/.config/hypr/settings/screenshot-filename.sh
source ~/.config/hypr/settings/screenshot-folder.sh

EDITOR_APP="$(tr -d '[:space:]' < ~/.config/hypr/settings/screenshot-editor.sh)"

option_1="Immediate"
option_2="Delayed"

option_capture_1="Capture Everything"
option_capture_2="Capture Active Display"
option_capture_3="Capture Selection"

option_time_1="5s"
option_time_2="10s"
option_time_3="20s"
option_time_4="30s"
option_time_5="60s"

copy='Copy'
save='Save'
copy_save='Copy & Save'
edit='Edit'

rofi_cmd() {
    rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 2 -width 30 -p "Take screenshot"
}

run_rofi() {
    echo -e "$option_1\n$option_2" | rofi_cmd
}

timer_cmd() {
    rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 5 -width 30 -p "Choose timer"
}

timer_exit() {
    echo -e "$option_time_1\n$option_time_2\n$option_time_3\n$option_time_4\n$option_time_5" | timer_cmd
}

timer_run() {
    selected_timer="$(timer_exit)"
    case "$selected_timer" in
        "$option_time_1") countdown=5 ;;
        "$option_time_2") countdown=10 ;;
        "$option_time_3") countdown=20 ;;
        "$option_time_4") countdown=30 ;;
        "$option_time_5") countdown=60 ;;
        *) exit ;;
    esac
}

type_screenshot_cmd() {
    rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 3 -width 30 -p "Type of screenshot"
}

type_screenshot_exit() {
    echo -e "$option_capture_1\n$option_capture_2\n$option_capture_3" | type_screenshot_cmd
}

type_screenshot_run() {
    selected_type_screenshot="$(type_screenshot_exit)"
    case "$selected_type_screenshot" in
        "$option_capture_1") option_type_screenshot=screen ;;
        "$option_capture_2") option_type_screenshot=output ;;
        "$option_capture_3") option_type_screenshot=area ;;
        *) exit ;;
    esac
}

copy_save_editor_cmd() {
    rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 4 -width 30 -p "How to save"
}

copy_save_editor_exit() {
    echo -e "$copy\n$save\n$copy_save\n$edit" | copy_save_editor_cmd
}

copy_save_editor_run() {
    selected_chosen="$(copy_save_editor_exit)"
    case "$selected_chosen" in
        "$copy") option_chosen=copy ;;
        "$save") option_chosen=save ;;
        "$copy_save") option_chosen=copysave ;;
        "$edit") option_chosen=edit ;;
        *) exit ;;
    esac
}

focused_monitor() {
    hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m.get('focused'):
        print(m['name'])
        break
"
}

timer() {
    while [[ "$countdown" -gt 0 ]]; do
        notify-send -t 1000 "Screenshot" "Taking screenshot in ${countdown}s"
        countdown=$((countdown - 1))
        sleep 1
    done
}

capture_to_file() {
    local outfile="$1"
    case "$option_type_screenshot" in
        screen)
            grim "$outfile" || return 1
            ;;
        output)
            local monitor
            monitor="$(focused_monitor)"
            [ -n "$monitor" ] || return 1
            grim -o "$monitor" "$outfile" || return 1
            ;;
        area)
            local geom
            geom="$(slurp)" || return 1
            [ -n "$geom" ] || return 1
            grim -g "$geom" "$outfile" || return 1
            ;;
        *)
            return 1
            ;;
    esac
}

capture_to_clipboard() {
    case "$option_type_screenshot" in
        screen) grim - | wl-copy ;;
        output)
            local monitor
            monitor="$(focused_monitor)"
            [ -n "$monitor" ] || return 1
            grim -o "$monitor" - | wl-copy
            ;;
        area)
            local geom
            geom="$(slurp)" || return 1
            [ -n "$geom" ] || return 1
            grim -g "$geom" - | wl-copy
            ;;
        *)
            return 1
            ;;
    esac
}

apply_action() {
    mkdir -p "$screenshot_folder"
    local outfile="$screenshot_folder/$NAME"

    case "$option_chosen" in
        copy)
            capture_to_clipboard || return 1
            notify-send -t 3000 "Screenshot" "Copied to clipboard"
            ;;
        save)
            capture_to_file "$outfile" || return 1
            notify-send -t 3000 "Screenshot" "Saved to $outfile"
            ;;
        copysave)
            capture_to_file "$outfile" || return 1
            wl-copy < "$outfile"
            notify-send -t 3000 "Screenshot" "Saved and copied: $outfile"
            ;;
        edit)
            capture_to_file "$outfile" || return 1
            notify-send -t 3000 "Screenshot" "Opening in $EDITOR_APP"
            command -v "$EDITOR_APP" >/dev/null && "$EDITOR_APP" "$outfile" &
            ;;
    esac
}

takescreenshot() {
    sleep 0.3
    apply_action
}

takescreenshot_timer() {
    timer
    sleep 0.3
    apply_action
}

run_cmd() {
    if [[ "$1" == '--opt1' ]]; then
        type_screenshot_run
        copy_save_editor_run
        takescreenshot
    elif [[ "$1" == '--opt2' ]]; then
        timer_run
        type_screenshot_run
        copy_save_editor_run
        takescreenshot_timer
    fi
}

chosen="$(run_rofi)"
case ${chosen} in
    "$option_1") run_cmd --opt1 ;;
    "$option_2") run_cmd --opt2 ;;
esac
