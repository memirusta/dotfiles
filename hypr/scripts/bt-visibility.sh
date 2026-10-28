#!/bin/bash
# Bluetooth açıkken bilgisayarı bulunabilir tut

bt_make_visible() {
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes" || return 0
    bluetoothctl pairable on >/dev/null 2>&1 || true
    bluetoothctl discoverable on >/dev/null 2>&1 || true
    bluetoothctl discoverable-timeout 0 >/dev/null 2>&1 || true
}

case "${1:-once}" in
    watch)
        while true; do
            bt_make_visible
            sleep 45
        done
        ;;
    once|*)
        bt_make_visible
        ;;
esac
