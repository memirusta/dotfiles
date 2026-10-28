#!/bin/bash
# Bluetooth yöneticisi — cihaz listesi

ROFI_CFG="$HOME/.config/rofi/config-bluetooth.rasi"
[ -f "$ROFI_CFG" ] || ROFI_CFG="$HOME/.config/rofi/config-compact.rasi"

IDS_FILE=$(mktemp)
SEEN_CACHE=$(mktemp)
REFRESH_SEC=2
trap 'cleanup' EXIT INT TERM

cleanup() {
    if bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"; then
        bluetoothctl scan off >/dev/null 2>&1 || true
    fi
    rm -f "$IDS_FILE" "$SEEN_CACHE"
}

notify() {
    notify-send -a "Bluetooth" -t 2500 "$1" "${2:-}" 2>/dev/null || true
}

bt_on() {
    rfkill unblock bluetooth 2>/dev/null || true
    sleep 0.3
    bluetoothctl power on >/dev/null 2>&1
    "$HOME/.config/hypr/scripts/bt-visibility.sh" once
}

is_powered() {
    bluetoothctl show 2>/dev/null | grep -q "Powered: yes"
}

is_discovering() {
    bluetoothctl show 2>/dev/null | grep -q "Discovering: yes"
}

setup_session() {
    bt_on
    start_scan
}

start_scan() {
    is_powered || return 1
    is_discovering && return 0
    bluetoothctl scan on >/dev/null 2>&1 || true
}

device_icon() {
    local n="${1,,}"
    case "$n" in
        *airpod*|*buds*|*kulak*|*headphone*|*earbud*|*wh-1000*) printf '🎧' ;;
        *mouse*|*fare*|*mx*master*) printf '🖱 ' ;;
        *keyboard*|*klavye*) printf '⌨ ' ;;
        *phone*|*iphone*|*galaxy*|*pixel*|*telefon*|*a35*|*a55*|*samsung*) printf '📱' ;;
        *speaker*|*hoparlör*|*soundbar*) printf '🔊' ;;
        *watch*|*saat*) printf '⌚' ;;
        *) printf '󰂯' ;;
    esac
}

collect_devices() {
    BT_CACHE="$SEEN_CACHE" python3 - <<'PY'
import os, re, subprocess, time

cache_path = os.environ.get("BT_CACHE", "")

def run(*args):
    try:
        out = subprocess.check_output(list(args), text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return ""
    return out

def load_cache():
    items = {}
    if not cache_path or not os.path.exists(cache_path):
        return items
    with open(cache_path, encoding="utf-8") as f:
        for line in f:
            parts = line.strip().split("|", 3)
            if len(parts) >= 3:
                mac, name, seen = parts[0], parts[1], float(parts[2])
                items[mac.upper()] = (name, seen)
    return items

def save_cache(items):
    if not cache_path:
        return
    with open(cache_path, "w", encoding="utf-8") as f:
        for mac, (name, seen) in sorted(items.items()):
            f.write(f"{mac}|{name}|{seen:.0f}\n")

def bad_name(name):
    if re.fullmatch(r'[0-9A-F]{2}([-:][0-9A-F]{2}){5}', name, re.I):
        return True
    if re.fullmatch(r'[0-9A-F]{2}(-[0-9A-F]{2}){5}', name.replace(':', '-'), re.I):
        return True
    return not name.strip()

paired = {}
connected = set()
discovered = {}
now = time.time()

for line in run("bluetoothctl", "devices").splitlines():
    m = re.match(r"Device\s+(\S+)\s+(.*)", line.strip())
    if m:
        mac = m.group(1).upper()
        name = m.group(2).strip()
        if not bad_name(name):
            discovered[mac] = name

for line in run("bluetoothctl", "devices", "Paired").splitlines():
    m = re.match(r"Device\s+(\S+)\s+(.*)", line.strip())
    if m:
        paired[m.group(1).upper()] = m.group(2).strip()

for line in run("bluetoothctl", "devices", "Connected").splitlines():
    m = re.match(r"Device\s+(\S+)\s+(.*)", line.strip())
    if m:
        mac = m.group(1).upper()
        connected.add(mac)
        paired.setdefault(mac, m.group(2).strip())

cache = load_cache()
for mac, name in discovered.items():
    cache[mac] = (name, now)

rows = []
seen = set()

for mac, name in sorted(paired.items(), key=lambda x: x[1].lower()):
    seen.add(mac)
    state = "connected" if mac in connected else "paired"
    rows.append((mac, name, state))

# Yakında görülenler: BlueZ cache'den + oturum önbelleği (30 sn sonra kaybolmasın)
candidates = dict(discovered)
for mac, (name, seen_at) in cache.items():
    if mac in seen:
        continue
    if now - seen_at > 600:
        continue
    candidates.setdefault(mac, name)

for mac, name in sorted(candidates.items(), key=lambda x: x[1].lower()):
    if mac in seen:
        continue
    stale = mac not in discovered
    state = "stale" if stale else "new"
    rows.append((mac, name, state))

save_cache(cache)

for mac, name, state in rows:
    print(f"{mac}|{name}|{state}")
PY
}

build_menu() {
    local powered="$1"
    local -a labels=()
    local has_connected=0 has_saved=0 has_new=0
    local data

    : >"$IDS_FILE"

    if [ "$powered" = "yes" ]; then
        labels+=("󰂯  Bluetooth açık")
        echo "toggle:off" >>"$IDS_FILE"
    else
        labels+=("󰂲  Bluetooth kapalı")
        echo "toggle:on" >>"$IDS_FILE"
    fi

    data=$(collect_devices)

    if [ "$powered" = "yes" ] && [ -n "$data" ]; then
        while IFS='|' read -r mac name state; do
            [ -z "$mac" ] && continue
            case "$state" in
                connected) has_connected=1 ;;
                paired) has_saved=1 ;;
                new|stale) has_new=1 ;;
            esac
        done <<<"$data"
    fi

    if [ "$powered" = "yes" ]; then
        if [ "$has_connected" -eq 1 ]; then
            labels+=("── Bağlı cihazlar ──")
            echo "header:skip" >>"$IDS_FILE"

            while IFS='|' read -r mac name state; do
                [ "$state" = "connected" ] || continue
                local icon line
                icon=$(device_icon "$name")
                line=$(printf '%s  %-26s  %s' "$icon" "$name" "● Bağlı")
                labels+=("$line")
                echo "device|${mac}|connected" >>"$IDS_FILE"
            done <<<"$data"
        fi

        if [ "$has_saved" -eq 1 ]; then
            labels+=("── Kayıtlı cihazlar ──")
            echo "header:skip" >>"$IDS_FILE"

            while IFS='|' read -r mac name state; do
                [ "$state" = "paired" ] || continue
                local icon line
                icon=$(device_icon "$name")
                line=$(printf '%s  %-26s  %s' "$icon" "$name" "Eşleşmiş")
                labels+=("$line")
                echo "device|${mac}|paired" >>"$IDS_FILE"
            done <<<"$data"
        fi

        if [ "$has_new" -eq 1 ]; then
            labels+=("── Yakındaki cihazlar ──")
            echo "header:skip" >>"$IDS_FILE"

            while IFS='|' read -r mac name state; do
                [ "$state" = "new" ] || [ "$state" = "stale" ] || continue
                local icon line tag
                icon=$(device_icon "$name")
                if [ "$state" = "stale" ]; then
                    tag="Görüldü"
                else
                    tag="Yeni"
                fi
                line=$(printf '%s  %-26s  %s' "$icon" "$name" "$tag")
                labels+=("$line")
                echo "device|${mac}|new" >>"$IDS_FILE"
            done <<<"$data"
        fi

        if [ "$has_connected$has_saved$has_new" = "000" ]; then
            if is_discovering; then
                labels+=("Cihazlar aranıyor…")
            else
                labels+=("Yakında cihaz bulunamadı")
            fi
            echo "refresh|wait" >>"$IDS_FILE"
        fi

        if is_discovering; then
            labels+=("Aranıyor…")
            echo "header:skip" >>"$IDS_FILE"
        fi

        labels+=("󰑐  Yenile")
        echo "refresh|scan" >>"$IDS_FILE"

        labels+=("󰅧  Send file")
        echo "obex|send" >>"$IDS_FILE"

        labels+=("󰉋  Received files")
        echo "obex|folder" >>"$IDS_FILE"

        labels+=("󰏰  Cihazı unut…")
        echo "manage|forget" >>"$IDS_FILE"
    fi

    printf '%s\n' "${labels[@]}"
}

# Tarama sürerken liste REFRESH_SEC saniyede bir yenilenir
pick_index() {
    local powered="$1"
    local labels choice idx ret

    while true; do
        start_scan
        labels=$(build_menu "$powered")

        if is_discovering; then
            choice=$(printf '%s\n' "$labels" | timeout "$REFRESH_SEC" rofi -dmenu -i -p "Bluetooth" -config "$ROFI_CFG" 2>/dev/null)
            ret=$?
            if [ "$ret" -eq 124 ]; then
                continue
            fi
            [ "$ret" -ne 0 ] && return 1
        else
            choice=$(printf '%s\n' "$labels" | rofi -dmenu -i -p "Bluetooth" -config "$ROFI_CFG" 2>/dev/null) || return 1
        fi

        [ -z "$choice" ] && return 1
        idx=$(printf '%s\n' "$labels" | awk -v c="$choice" '$0 == c { print NR; exit }')
        [ -n "$idx" ] && echo "$idx" && return 0
    done
}

handle_device() {
    local mac="$1" state="$2"

    case "$state" in
        connected)
            bluetoothctl disconnect "$mac" >/dev/null 2>&1
            notify "Bluetooth" "Bağlantı kesildi"
            ;;
        paired)
            bluetoothctl connect "$mac" >/dev/null 2>&1 &
            notify "Bluetooth" "Bağlanılıyor…"
            ;;
        new)
            bluetoothctl pair "$mac" >/dev/null 2>&1
            sleep 1
            bluetoothctl trust "$mac" >/dev/null 2>&1
            bluetoothctl connect "$mac" >/dev/null 2>&1 &
            notify "Bluetooth" "Eşleştiriliyor…"
            ;;
    esac
}

forget_device_menu() {
    local -a labels=() macs=()
    local mac name state icon row pick i

    while IFS='|' read -r mac name state; do
        [ -z "$mac" ] || [ "$state" = "new" ] && continue
        icon=$(device_icon "$name")
        row=$(printf '%s  %s' "$icon" "$name")
        labels+=("$row")
        macs+=("$mac")
    done < <(collect_devices)

    [ ${#labels[@]} -eq 0 ] && notify "Bluetooth" "Kayıtlı cihaz yok" && return 0

    pick=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -p "Unut" -config "$ROFI_CFG" 2>/dev/null) || return 0
    for i in "${!labels[@]}"; do
        [ "${labels[$i]}" = "$pick" ] || continue
        bluetoothctl remove "${macs[$i]}" >/dev/null 2>&1
        notify "Bluetooth" "Cihaz unutuldu"
        return 0
    done
}

main_loop() {
    pkill rofi 2>/dev/null
    setup_session

    while true; do
        local powered idx id

        if is_powered; then powered=yes; else powered=no; fi
        start_scan

        idx=$(pick_index "$powered") || break
        id=$(sed -n "${idx}p" "$IDS_FILE")
        [ -z "$id" ] && continue

        case "$id" in
            toggle:on)
                bt_on
                sleep 0.3
                start_scan
                ;;
            toggle:off)
                bluetoothctl scan off >/dev/null 2>&1 || true
                bluetoothctl power off >/dev/null 2>&1
                notify "Bluetooth" "Kapatıldı"
                ;;
            header:skip)
                continue
                ;;
            refresh|wait)
                continue
                ;;
            refresh|scan)
                start_scan
                ;;
            manage|forget)
                forget_device_menu
                ;;
            obex|send)
                "$HOME/.config/hypr/scripts/bt-obex.sh" send
                ;;
            obex|folder)
                "$HOME/.config/hypr/scripts/bt-obex.sh" folder
                ;;
            device|*)
                local mac state
                IFS='|' read -r _ mac state <<<"$id"
                handle_device "$mac" "$state"
                sleep 0.5
                ;;
        esac
    done
}

main_loop
