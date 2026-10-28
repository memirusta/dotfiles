#!/bin/bash
# Monitör düzeni — soğuk açılış + Cursor Hz düşmesi

EXTERNAL_RES="1920x1080@300"
SETTINGS_HZ="$HOME/.config/hypr/settings/laptop-refresh-hz"
SETTINGS_EXT_HZ="$HOME/.config/hypr/settings/external-refresh-hz"

on_battery() {
    local ac online
    for ac in /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online; do
        [ -f "$ac" ] || continue
        online=$(tr -d '[:space:]' <"$ac")
        [ "$online" = "1" ] && return 1
    done
    return 0
}

laptop_hz() {
    if [ -f "$SETTINGS_HZ" ]; then
        local hz
        hz=$(tr -d '[:space:]' <"$SETTINGS_HZ")
        case "$hz" in
            60|165) echo "$hz"; return ;;
        esac
    fi
    echo 165
}

laptop_res() {
    echo "1920x1200@$(laptop_hz)"
}

external_hz() {
    if on_battery; then
        echo 60
        return
    fi
    if [ -f "$SETTINGS_EXT_HZ" ]; then
        local hz
        hz=$(tr -d '[:space:]' <"$SETTINGS_EXT_HZ")
        case "$hz" in
            60|120|144|165|240|300) echo "$hz"; return ;;
        esac
    fi
    echo 300
}

external_res() {
    echo "1920x1080@$(external_hz)"
}
LAPTOP_SCALE="1.5"
EXTERNAL_SCALE="1"
LAPTOP_X="0x0"
EXTERNAL_X="1280x0"
LAPTOP_MATCH="N153JMA"
EXTERNAL_MATCH="25G4S"
LOCK_FILE="/tmp/hypr-monitors.lock"
STATE_FILE="$HOME/.cache/hypr-monitor-state"
HZ_STATE_FILE="$HOME/.cache/hypr-monitor-hz-state"

mkdir -p "$(dirname "$STATE_FILE")"

need_apply() {
    python3 - <<'PY'
import json, subprocess, sys
from pathlib import Path

LAPTOP_MATCH, EXT_MATCH = "N153JMA", "25G4S"
LAPTOP_SCALE, EXT_SCALE = 1.5, 1.0
LAPTOP_X, EXT_X = 0, 1280
try:
    LAPTOP_HZ = int(Path.home().joinpath(".config/hypr/settings/laptop-refresh-hz").read_text().strip())
except Exception:
    LAPTOP_HZ = 165
if LAPTOP_HZ not in (60, 165):
    LAPTOP_HZ = 165

def on_battery():
    base = Path("/sys/class/power_supply")
    for pattern in ("AC*/online", "ADP*/online"):
        for path in base.glob(pattern):
            try:
                if path.read_text().strip() == "1":
                    return False
            except OSError:
                pass
    return True

EXT_HZ = 60 if on_battery() else 300
if not on_battery():
    try:
        ext = int(Path.home().joinpath(".config/hypr/settings/external-refresh-hz").read_text().strip())
        if ext in (60, 120, 144, 165, 240, 300):
            EXT_HZ = ext
    except Exception:
        pass

raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
mons = json.loads(raw)

laptop = external = None
for m in mons:
    desc = m.get("description", "")
    if LAPTOP_MATCH.lower() in desc.lower() or m.get("name", "").startswith("eDP"):
        laptop = m
    elif EXT_MATCH.lower() in desc.lower():
        external = m

if not laptop:
    sys.exit(1)

def ok(m, want_x, want_refresh, want_scale):
    if m is None:
        return False
    refresh = float(m.get("refreshRate", 0) or 0)
    if abs(refresh - want_refresh) > 2:
        return False
    if abs(float(m.get("scale", 1)) - want_scale) > 0.01:
        return False
    if int(m.get("x", -1)) != want_x:
        return False
    return True

if external:
    if not (ok(laptop, LAPTOP_X, LAPTOP_HZ, LAPTOP_SCALE) and ok(external, EXT_X, EXT_HZ, EXT_SCALE)):
        sys.exit(0)
else:
    if not ok(laptop, 0, LAPTOP_HZ, LAPTOP_SCALE):
        sys.exit(0)

sys.exit(2)
PY
}

detect_monitors() {
    python3 - <<'PY'
import json, subprocess
LAPTOP_MATCH, EXT_MATCH = "N153JMA", "25G4S"
raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
mons = json.loads(raw)
laptop = external = ""
for m in mons:
    desc = m.get("description", "")
    name = m.get("name", "")
    if LAPTOP_MATCH.lower() in desc.lower() or name.startswith("eDP"):
        laptop = name
    elif EXT_MATCH.lower() in desc.lower():
        external = name
if not laptop:
    for m in mons:
        if m.get("name", "").startswith("eDP"):
            laptop = m["name"]
            break
if not external:
    for m in mons:
        n = m.get("name", "")
        if n != laptop and not n.startswith("eDP"):
            external = n
            break
print(laptop)
print(external)
PY
}

apply_monitor_lua() {
    local output="$1" mode="$2" position="$3" scale="$4"
    local code
    code=$(python3 - "$output" "$mode" "$position" "$scale" <<'PYLUA'
import json, sys
output, mode, position, scale = sys.argv[1:]
print(
    "hl.monitor({ output = %s, mode = %s, position = %s, scale = %s, vrr = 0 })"
    % (json.dumps(output), json.dumps(mode), json.dumps(position), float(scale))
)
PYLUA
)
    hyprctl eval "$code"
}

apply_layout() {
    mapfile -t ids < <(detect_monitors)
    laptop="${ids[0]:-}"
    external="${ids[1]:-}"
    local laptop_res ext_res
    laptop_res=$(laptop_res)
    ext_res=$(external_res)

    if [ -n "$laptop" ] && [ -n "$external" ]; then
        apply_monitor_lua "${laptop}" "${laptop_res}" "${LAPTOP_X}" "${LAPTOP_SCALE}"
        apply_monitor_lua "${external}" "${ext_res}" "${EXTERNAL_X}" "${EXTERNAL_SCALE}"
        return 0
    elif [ -n "$laptop" ]; then
        apply_monitor_lua "${laptop}" "${laptop_res}" "0x0" "${LAPTOP_SCALE}"
        return 0
    elif [ -n "$external" ]; then
        apply_monitor_lua "${external}" "${ext_res}" "0x0" "${EXTERNAL_SCALE}"
        return 0
    fi
    return 1
}

monitor_signature() {
    hyprctl monitors -j | python3 -c "
import json,sys
mons=json.load(sys.stdin)
print('|'.join(sorted(m['name'] for m in mons)))
"
}

hz_signature() {
    hyprctl monitors -j | python3 -c "
import json,sys
for m in sorted(json.load(sys.stdin), key=lambda x: x['name']):
    print(f\"{m['name']}:{float(m.get('refreshRate',0)):.0f}:{m['width']}x{m['height']}:{m.get('scale',1)}\")
"
}

wallpaper_ok() {
    local monitor count=0
    while IFS= read -r monitor; do
        [ -n "$monitor" ] || continue
        count=$((count + 1))
        pgrep -f "mpvpaper.*[[:space:]]${monitor}[[:space:]]" >/dev/null 2>&1 || return 1
    done < <(hyprctl monitors 2>/dev/null | awk '/^Monitor / {gsub(/:$/, "", $2); print $2}')
    [ "$count" -gt 0 ] || return 1
    return 0
}

restart_wallpaper() {
    pkill -x mpvpaper 2>/dev/null || true
    sleep 0.25
    [ -x "$HOME/.config/hypr/scripts/wallpaper-boot.sh" ] && \
        "$HOME/.config/hypr/scripts/wallpaper-boot.sh"
}

ensure_wallpaper() {
    monitors_ready || return 0

    if [ -f "$HOME/.config/hypr/settings/wallpaper-disabled" ]; then
        "$HOME/.config/hypr/scripts/wallpaper-toggle.sh" black
        return 0
    fi

    local hz_sig prev_hz
    hz_sig=$(hz_signature | md5sum | awk '{print $1}')
    prev_hz=""
    [ -f "$HZ_STATE_FILE" ] && prev_hz=$(cat "$HZ_STATE_FILE")

    if wallpaper_ok && [ "$hz_sig" = "$prev_hz" ]; then
        return 0
    fi

    printf '%s\n' "$hz_sig" >"$HZ_STATE_FILE"
    printf '%s\n' "$(monitor_signature)" >"$STATE_FILE"
    restart_wallpaper
}

run_once() {
    exec 9>"$LOCK_FILE"
    flock -n 9 || return 0

    local check
    check=$(need_apply; echo $?)
    case $check in
        2) ensure_wallpaper; return 0 ;;
        1) return 1 ;;
    esac

    apply_layout || return 1
    sleep 0.3
    ensure_wallpaper
}

# Hz yanlışsa hemen düzelt (Cursor açılınca — yalnızca 165 Hz)
fix_if_needed() {
    [ "$(laptop_hz)" = "60" ] && return 0
    monitors_ready && return 0
    apply_layout 2>/dev/null || true
    sleep 0.3
    ensure_wallpaper
}

apply_with_retry() {
    local attempt
    for attempt in $(seq 1 60); do
        sleep 1
        if monitors_ready; then
            ensure_wallpaper
            return 0
        fi
        apply_layout 2>/dev/null || true
    done
    return 1
}

monitors_ready() {
    local check
    check=$(need_apply; echo $?)
    [ "$check" -eq 2 ]
}

wait_monitors_ready() {
    local attempt stable=0
    for attempt in $(seq 1 60); do
        if monitors_ready; then
            stable=$((stable + 1))
            [ "$stable" -ge 3 ] && return 0
        else
            stable=0
            apply_layout 2>/dev/null || true
        fi
        sleep 1
    done
    return 1
}

boot_warmup() {
    local i stable=0
    for i in $(seq 1 40); do
        if monitors_ready; then
            stable=$((stable + 1))
            [ "$stable" -ge 4 ] && break
        else
            stable=0
            apply_layout 2>/dev/null || true
        fi
        sleep 2
    done
    ensure_wallpaper

  for i in 5 10 15 20; do
        sleep "$i"
        [ "$(laptop_hz)" = "60" ] && continue
        fix_if_needed || true
    done
}

watch_loop() {
    while true; do
        if [ "$(laptop_hz)" = "60" ]; then
            sleep 12
            continue
        fi
        if monitors_ready; then
            ensure_wallpaper
            sleep 8
        else
            fix_if_needed || true
            sleep 2
        fi
    done
}

case "${1:-}" in
    listen|poll)
        apply_with_retry
        boot_warmup &
        watch_loop
        ;;
    force)
        apply_layout
        sleep 0.3
        rm -f "$HZ_STATE_FILE"
        ensure_wallpaper
        ;;
    fix)
        fix_if_needed
        ;;
    ready)
        monitors_ready
        ;;
    wait-ready)
        wait_monitors_ready
        ;;
    *)
        apply_with_retry
        ;;
esac
