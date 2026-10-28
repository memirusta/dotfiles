#!/bin/bash
# Video/statik duvar kağıdı — yüksek Hz monitörlerde titreme önlenir

VIDEO="${VIDEO:-}"
VIDEO="${VIDEO//\\ / }"
CACHE_WALL="$HOME/.config/hypr/cache/current_wallpaper"

if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
    if [ -f "$CACHE_WALL" ]; then
        VIDEO=$(tr -d '\n' <"$CACHE_WALL")
        VIDEO="${VIDEO//\\ / }"
    fi
fi
if [ -z "$VIDEO" ] || [ ! -f "$VIDEO" ]; then
    VIDEO="$HOME/wallpaper/default-1080.mp4"
fi
[ -f "$VIDEO" ] || VIDEO="$HOME/wallpaper/default.mp4"
IMAGE="$HOME/wallpaper/default.jpg"
CACHE_DIR="$HOME/.cache/hypr-wallpaper"
LOCK_FILE="/tmp/hypr-wallpaper.lock"
HIGH_HZ=180
LAPTOP_MATCH="N153JMA"

MPV_VIDEO_OPTS='hwdec=auto-safe no-audio loop panscan=1.0 video-sync=display-resample interpolation=no'
MPV_STATIC_OPTS='hwdec=auto-safe no-audio loop video-sync=display-resample interpolation=no'

mkdir -p "$CACHE_DIR"

get_monitors_json() {
    hyprctl monitors -j
}

stop_wallpapers() {
    pkill -9 -x mpvpaper 2>/dev/null || true
    pkill -9 -f 'mpvpaper.*\*' 2>/dev/null || true
    sleep 0.25
}

mpvpaper_running() {
    local monitor="$1"
    pgrep -f "mpvpaper.*[[:space:]]${monitor}[[:space:]]" >/dev/null 2>&1
}

ensure_scaled_video() {
    local out="$1" w="$2" h="$3"
    local src_mtime dst_mtime
    [ -f "$VIDEO" ] || return 1

    src_mtime=$(stat -c %Y "$VIDEO" 2>/dev/null || echo 0)
    dst_mtime=$(stat -c %Y "$out" 2>/dev/null || echo 0)
    if [ -f "$out" ] && [ -f "${out}.source" ] && \
       [ "$(tr -d '\n' <"${out}.source")" = "$VIDEO" ] && \
       [ "$dst_mtime" -ge "$src_mtime" ]; then
        return 0
    fi

    command -v ffmpeg >/dev/null 2>&1 || return 1
    ffmpeg -y -loglevel error -i "$VIDEO" \
        -vf "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}" \
        -c:v libx264 -preset veryfast -crf 20 -pix_fmt yuv420p -an \
        "$out"
    printf '%s' "$VIDEO" >"${out}.source"
}

ensure_static_loop() {
    local out="$1" w="$2" h="$3"
    local src_mtime dst_mtime
    [ -f "$VIDEO" ] || return 1

    src_mtime=$(stat -c %Y "$VIDEO" 2>/dev/null || echo 0)
    dst_mtime=$(stat -c %Y "$out" 2>/dev/null || echo 0)
    if [ -f "$out" ] && [ -f "${out}.source" ] && \
       [ "$(tr -d '\n' <"${out}.source")" = "$VIDEO" ] && \
       [ "$dst_mtime" -ge "$src_mtime" ]; then
        return 0
    fi

    command -v ffmpeg >/dev/null 2>&1 || return 1
    ffmpeg -y -loglevel error -ss 0 -i "$VIDEO" -vframes 1 \
        -vf "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}" \
        -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p -r 30 -t 2 -an \
        "$out"
    printf '%s' "$VIDEO" >"${out}.source"
}

start_mpvpaper() {
    local monitor="$1" file="$2" opts="$3"
    pkill -f "mpvpaper.*[[:space:]]${monitor}[[:space:]]" 2>/dev/null || true
    sleep 0.1
    mpvpaper -f -p -o "$opts" "$monitor" "$file" &
    disown
    sleep 0.15
}

start_per_monitor() {
    command -v mpvpaper >/dev/null 2>&1 || return 1

    python3 - "$VIDEO" "$CACHE_DIR" "$HIGH_HZ" "$LAPTOP_MATCH" "$MPV_VIDEO_OPTS" "$MPV_STATIC_OPTS" <<'PY'
import hashlib, json, subprocess, sys

video, cache_dir, high_hz, laptop_match, video_opts, static_opts = sys.argv[1:7]
high_hz = float(high_hz)
src_id = hashlib.md5(video.encode()).hexdigest()[:8]

src_w = 0
try:
    meta = subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width", "-of", "csv=p=0", video
    ], text=True).strip()
    src_w = int(meta or 0)
except Exception:
    pass
use_static_on_high_hz = src_w > 1920

raw = subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)
mons = json.loads(raw)

for m in mons:
    name = m["name"]
    desc = m.get("description", "")
    refresh = float(m.get("refreshRate", 60) or 60)
    w = int(m["width"])
    h = int(m["height"])
    is_laptop = laptop_match.lower() in desc.lower() or name.startswith("eDP")
    tag = "laptop" if is_laptop else "external"
    scaled = f"{cache_dir}/{tag}-{w}x{h}-{src_id}.mp4"
    static = f"{cache_dir}/{tag}-{w}x{h}-{src_id}-static.mp4"
    print(f"ENSURE|{scaled}|{w}|{h}")
    if refresh >= high_hz and use_static_on_high_hz:
        print(f"ENSURE_STATIC|{static}|{w}|{h}")
        print(f"START|{name}|{static}|{static_opts}")
    else:
        print(f"START|{name}|{scaled}|{video_opts}")
PY
}

apply_plan() {
    local mode="${1:-all}"
    local line action file w h monitor opts
    while IFS='|' read -r action arg1 arg2 arg3 arg4; do
        case "$action" in
            ENSURE)
                [ "$mode" != "start" ] && ensure_scaled_video "$arg1" "$arg2" "$arg3" || true
                ;;
            ENSURE_STATIC)
                [ "$mode" != "start" ] && ensure_static_loop "$arg1" "$arg2" "$arg3" || true
                ;;
            START)
                [ "$mode" = "ensure" ] && continue
                monitor="$arg1"
                file="$arg2"
                opts="$arg3"
                [ -f "$file" ] || file="$VIDEO"
                [ -f "$file" ] || continue
                mpvpaper_running "$monitor" && continue
                start_mpvpaper "$monitor" "$file" "$opts"
                ;;
        esac
    done < <(start_per_monitor)
}

if [ ! -f "$VIDEO" ]; then
    [ -f "$IMAGE" ] && [ -x "$HOME/.config/hypr/scripts/wallpaper-restore.sh" ] && \
        exec "$HOME/.config/hypr/scripts/wallpaper-restore.sh"
    exit 0
fi

(
    flock -w 60 200 || exit 1

    if [ -x "$HOME/.config/hypr/scripts/monitors.sh" ]; then
        "$HOME/.config/hypr/scripts/monitors.sh" wait-ready || true
    fi

    if [ -f "$HOME/.config/hypr/settings/wallpaper-disabled" ]; then
        "$HOME/.config/hypr/scripts/wallpaper-toggle.sh" black
        exit 0
    fi

    stop_wallpapers
    apply_plan ensure
    exec 200>&-
    apply_plan start
) 200>"$LOCK_FILE"
