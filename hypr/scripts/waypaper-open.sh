#!/bin/bash
# Waypaper galerisini aç veya öne getir

CACHE="$HOME/.cache/waypaper"
MARKER="$HOME/.config/hypr/cache/waypaper-running"
KEYBINDINGS="$HOME/.config/waypaper/keybindings.ini"
WALLPAPER_DIR="$HOME/wallpaper"

STATE="$HOME/.local/state/waypaper/state.ini"
CONFIG="$HOME/.config/waypaper/config.ini"
mkdir -p "$(dirname "$STATE")" "$HOME/.config/waypaper" "$CACHE"
[ -f "$KEYBINDINGS" ] || printf '[keybindings]\n' >"$KEYBINDINGS"

if [ -f "$CONFIG" ]; then
    sed -i 's/^backend = .*/backend = none/' "$CONFIG"
fi
if [ -f "$STATE" ]; then
    sed -i 's/^backend = .*/backend = none/' "$STATE"
else
    printf '[State]\nbackend = none\n' >"$STATE"
fi

# Waypaper mp4 önizlemelerini bozuk .png olarak kaydediyor — ffmpeg ile düzelt
rebuild_video_thumbs() {
    command -v ffmpeg >/dev/null || return 0
    local f out hash
    while IFS= read -r -d '' f; do
        hash=$(python3 -c "import hashlib, os; print(hashlib.md5(os.path.realpath('$f').encode()).hexdigest())")
        out="$CACHE/${hash}.png"
        if [ ! -s "$out" ]; then
            ffmpeg -y -loglevel error -i "$f" -vframes 1 -vf "scale=240:-1" "$out" 2>/dev/null || rm -f "$out"
        fi
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \) -print0 2>/dev/null)
}

# Bozuk küçük thumbnail'ler
find "$CACHE" -name '*.png' -size -2k -delete 2>/dev/null

waypaper_addr() {
    hyprctl clients -j 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError:
    sys.exit(1)
for c in data:
    cls = (c.get('class') or '').lower()
    title = (c.get('title') or '').lower()
    if 'waypaper' in cls or title == 'waypaper':
        print(c['address'])
        break
"
}

focus_waypaper() {
    local addr
    addr=$(waypaper_addr) || return 1
    [ -n "$addr" ] || return 1
    local selector code
    selector="address:${addr}"
    code=$(python3 - "$selector" <<'PYLUA'
import json, sys
print("hl.dsp.focus({ window = %s })" % json.dumps(sys.argv[1]))
PYLUA
)
    hyprctl dispatch "$code" 2>/dev/null
    code=$(python3 - "$selector" <<'PYLUA'
import json, sys
print('hl.dsp.window.alter_zorder({ mode = "top", window = %s })' % json.dumps(sys.argv[1]))
PYLUA
)
    hyprctl dispatch "$code" 2>/dev/null
}

if focus_waypaper; then
    exit 0
fi

pkill -9 -f '/usr/bin/waypaper' 2>/dev/null || true
pkill -9 -f 'python.*waypaper' 2>/dev/null || true
sleep 0.25

rebuild_video_thumbs

: >/tmp/waypaper.log
setsid waypaper >>/tmp/waypaper.log 2>&1 </dev/null &
disown

for _ in $(seq 1 30); do
    sleep 0.25
    if focus_waypaper; then
        exit 0
    fi
done

notify-send -a "Waypaper" "Galeri açılamadı" "Log: /tmp/waypaper.log"
exit 1
