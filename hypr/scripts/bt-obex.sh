#!/bin/bash
# Bluetooth OBEX file transfer (send + receive)

SCRIPTS="$HOME/.config/hypr/scripts"
RECEIVE_DIR="$HOME/Downloads/Bluetooth"
ROFI_CFG="$HOME/.config/rofi/config-compact.rasi"
[ -f "$ROFI_CFG" ] || ROFI_CFG="$HOME/.config/rofi/config.rasi"

notify() {
    notify-send -a "Bluetooth" -t 4000 "$1" "${2:-}" 2>/dev/null || true
}

obex_installed() {
    [ -x /usr/lib/bluetooth/obexd ] || command -v obexctl >/dev/null 2>&1
}

install_hint() {
    notify "Bluetooth files" "Run once:\n$SCRIPTS/bt-obex-install.sh"
}

obex_start() {
    obex_installed || return 1
    mkdir -p "$RECEIVE_DIR"
    systemctl --user enable obex.service 2>/dev/null || true
    systemctl --user start obex.service 2>/dev/null || true
    pgrep -f bt-obex-agent.py >/dev/null 2>&1 || \
        nohup python3 "$SCRIPTS/bt-obex-agent.py" >/tmp/bt-obex-agent.log 2>&1 &
    sleep 0.4
    systemctl --user is-active obex.service >/dev/null 2>&1
}

list_paired_devices() {
    bluetoothctl devices Paired 2>/dev/null | awk '/^Device / {print $2 " " substr($0, index($0,$3))}'
}

pick_device() {
    local -a lines=() macs=() name mac
    while read -r mac name; do
        [ -z "$mac" ] && continue
        lines+=("$name ($mac)")
        macs+=("$mac")
    done < <(list_paired_devices)

    [ ${#lines[@]} -eq 0 ] && return 1

    local pick
    pick=$(printf '%s\n' "${lines[@]}" | rofi -dmenu -i -p "Send to" -config "$ROFI_CFG" 2>/dev/null) || return 1
    local i
    for i in "${!lines[@]}"; do
        [ "${lines[$i]}" = "$pick" ] && echo "${macs[$i]}" && return 0
    done
    return 1
}

pick_file() {
    local file
    if command -v zenity >/dev/null 2>&1; then
        file=$(zenity --file-selection --title="Send via Bluetooth" 2>/dev/null) || return 1
        [ -f "$file" ] && echo "$file" && return 0
    fi
    if command -v fd >/dev/null 2>&1; then
        file=$(fd -H -t f -d 5 . "$HOME/Downloads" "$HOME/Pictures" "$HOME/Documents" 2>/dev/null \
            | rofi -dmenu -i -p "Send file" -config "$ROFI_CFG" 2>/dev/null) || return 1
        [ -f "$file" ] && echo "$file" && return 0
    fi
    notify "Bluetooth files" "Install zenity for file picker:\nsudo pacman -S zenity"
    return 1
}

send_file() {
    local mac file

    obex_installed || { install_hint; return 1; }
    obex_start || { notify "Bluetooth files" "Could not start OBEX service"; return 1; }

    mac=$(pick_device) || { notify "Bluetooth files" "No paired device selected"; return 1; }
    file=$(pick_file) || return 1

    notify "Bluetooth" "Sending…" "$(basename "$file")"

    if command -v obexctl >/dev/null 2>&1; then
        {
            echo "connect $mac"
            sleep 2
            echo "send $file"
            sleep 8
            echo "disconnect"
            echo "quit"
        } | obexctl >/tmp/bt-obex-send.log 2>&1 &
        wait $! 2>/dev/null
        if rg -q "complete|Complete|successful|Status: complete" /tmp/bt-obex-send.log 2>/dev/null; then
            notify "Bluetooth" "File sent" "$(basename "$file")"
        else
            notify "Bluetooth" "Transfer started" "Confirm on the other device"
        fi
        return 0
    fi

    notify "Bluetooth files" "obexctl not found — install bluez-obex"
    return 1
}

open_receive_folder() {
    mkdir -p "$RECEIVE_DIR"
    if command -v dolphin >/dev/null 2>&1; then
        dolphin "$RECEIVE_DIR" >/dev/null 2>&1 &
    else
        xdg-open "$RECEIVE_DIR" >/dev/null 2>&1 &
    fi
}

case "${1:-menu}" in
    start) obex_start ;;
    send) send_file ;;
    receive|folder) open_receive_folder ;;
    menu)
        pkill rofi 2>/dev/null
        choice=$(printf '%s\n' "Send file" "Received files folder" \
            | rofi -dmenu -i -p "Bluetooth files" -config "$ROFI_CFG" 2>/dev/null) || exit 0
        case "$choice" in
            "Send file") send_file ;;
            "Received files folder") open_receive_folder ;;
        esac
        ;;
    *) send_file ;;
esac
