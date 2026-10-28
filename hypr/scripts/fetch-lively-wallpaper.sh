#!/bin/bash
# Windows Lively Wallpaper → 1080p video kopyala
# Kullanım: ~/.config/hypr/scripts/fetch-lively-wallpaper.sh

set -euo pipefail

WIN_MOUNT="${WIN_MOUNT:-/mnt/win}"
DEST_1080="$HOME/wallpaper/default-1080.mp4"
DEST_MAIN="$HOME/wallpaper/default.mp4"
BACKUP="$HOME/wallpaper/default-4k.mp4.bak"

die() { echo "HATA: $*" >&2; exit 1; }

if [ ! -d "$WIN_MOUNT/Users" ]; then
    cat <<'EOF'
Windows bölümü bağlı değil:

  sudo mkdir -p /mnt/win
  sudo mount -o ro /dev/nvme0n1p3 /mnt/win

Sonra tekrar çalıştır:
  ~/.config/hypr/scripts/fetch-lively-wallpaper.sh
EOF
    exit 1
fi

command -v ffprobe >/dev/null || die "ffprobe gerekli (ffmpeg paketi)"

mapfile -t LIVELY_ROOTS < <(find "$WIN_MOUNT/Users" -type d \( \
    -path '*/AppData/Local/Lively Wallpaper/Library/wallpapers/*' \
    -o -path '*/AppData/Local/Lively Wallpaper/Library/*' \
    -o -path '*/AppData/Local/Packages/*LivelyWallpaper*/LocalState/Library/wallpapers/*' \
    -o -path '*/AppData/Local/Packages/*LivelyWallpaper*/LocalCache/Local/Lively Wallpaper/*' \
    \) 2>/dev/null | sort -u)

if [ "${#LIVELY_ROOTS[@]}" -eq 0 ]; then
    mapfile -t LIVELY_ROOTS < <(find "$WIN_MOUNT/Users" -type d -iname '*lively*wallpaper*' 2>/dev/null | head -20)
fi

[ "${#LIVELY_ROOTS[@]}" -gt 0 ] || die "Lively Wallpaper klasörü bulunamadı"

echo "→ Lively klasörleri taranıyor..."

best_file=""
best_score=0

video_wh() {
    ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
        -of csv=p=0 "$1" 2>/dev/null | tr -d '[:space:]'
}

while IFS= read -r -d '' file; do
  case "$file" in
    *.mp4|*.webm|*.mkv) ;;
    *) continue ;;
  esac

  meta=$(video_wh "$file")
  [ -n "$meta" ] || continue
  w=${meta%%,*}
  h=${meta##*,}
  [[ "$w" =~ ^[0-9]+$ && "$h" =~ ^[0-9]+$ ]] || continue

  score=0
  if [ "$w" -eq 1920 ] && [ "$h" -eq 1080 ]; then score=$((score + 1000)); fi
  if [ "$w" -eq 1280 ] && [ "$h" -eq 720 ]; then score=$((score + 500)); fi
  if [ "$w" -ge 3840 ]; then score=$((score - 500)); fi
  case "$(basename "$file" | tr '[:upper:]' '[:lower:]')" in
    video.mp4|*.1080p*|*1080p*|*fhd*) score=$((score + 200)) ;;
    lq.mp4|low*|thumb*) score=$((score - 300)) ;;
  esac
  size=$(stat -c %s "$file" 2>/dev/null || echo 0)
  if [ "$size" -gt 500000 ] && [ "$size" -lt 15000000 ]; then score=$((score + 100)); fi

  if [ "$score" -gt "$best_score" ]; then
    best_score=$score
    best_file=$file
  fi
done < <(find "${LIVELY_ROOTS[@]}" -type f \( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \) -print0 2>/dev/null)

if [ -z "$best_file" ] || [ "$best_score" -lt 800 ]; then
  while IFS= read -r -d '' file; do
    meta=$(video_wh "$file")
    [ "$meta" = "1920,1080" ] || continue
    best_file=$file
    best_score=1000
    break
  done < <(find "$WIN_MOUNT/Users" -type f -iname '*.mp4' -size +500k -size -20M -print0 2>/dev/null)
fi

[ -n "$best_file" ] || die "1080p video bulunamadı"

echo "→ Bulundu: $best_file"
ffprobe -v error -select_streams v:0 -show_entries stream=width,height,codec_name,r_frame_rate -of default=nw=1 "$best_file" 2>/dev/null || true

mkdir -p "$HOME/wallpaper"
cp -f "$best_file" "$DEST_1080"

if [ -f "$DEST_MAIN" ] && [ ! -f "$BACKUP" ]; then
    meta_main=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$DEST_MAIN" 2>/dev/null || echo 0)
    if [ "${meta_main:-0}" -ge 3840 ] 2>/dev/null; then
        mv -f "$DEST_MAIN" "$BACKUP"
        echo "→ 4K yedek: $BACKUP"
    fi
fi

cp -f "$DEST_1080" "$DEST_MAIN"
echo "→ Kopyalandı: $DEST_MAIN"

rm -rf "$HOME/.cache/hypr-wallpaper"
pkill -x mpvpaper 2>/dev/null || true
sleep 0.3
[ -x "$HOME/.config/hypr/scripts/wallpaper-boot.sh" ] && "$HOME/.config/hypr/scripts/wallpaper-boot.sh"

echo ""
echo "Tamam. Harici monitörde de video kullanılabilir (1080p kaynak)."
