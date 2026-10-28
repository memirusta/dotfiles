#!/bin/bash
# Duvar kağıdı değişince: renk üretimi (matugen + Caelestia şeması), blur cache, UI yenileme

use_cache=0
[ -f "$HOME/.config/hypr/settings/wallpaper_cache" ] && use_cache=1

force_generate=0
generatedversions="$HOME/.config/hypr/cache/wallpaper-generated"
waypaperrunning="$HOME/.config/hypr/cache/waypaper-running"
cachefile="$HOME/.config/hypr/cache/current_wallpaper"
blurredwallpaper="$HOME/.config/hypr/cache/blurred_wallpaper.png"
squarewallpaper="$HOME/.config/hypr/cache/square_wallpaper.png"
rasifile="$HOME/.config/hypr/cache/current_wallpaper.rasi"
framefile="$HOME/.config/hypr/cache/wallpaper-frame.jpg"
blurfile="$HOME/.config/hypr/settings/blur.sh"
defaultwallpaper="$HOME/wallpaper/default.jpg"
wallpapereffect="$HOME/.config/hypr/settings/wallpaper-effect.sh"
blur=$(cat "$blurfile")

is_video() {
    [[ "$1" =~ \.(mp4|webm|mkv|mov|gif|MP4|WEBM|MKV|GIF)$ ]]
}

color_source_from() {
    local src="$1"
    if is_video "$src" && command -v ffmpeg >/dev/null; then
        ffmpeg -y -loglevel error -i "$src" -vframes 1 -q:v 2 "$framefile" 2>/dev/null
        if [ -f "$framefile" ]; then
            echo "$framefile"
            return
        fi
    fi
    echo "$src"
}

matugen_bin="${MATUGEN_BIN:-$HOME/.cargo/bin/matugen}"
command -v matugen >/dev/null && matugen_bin="$(command -v matugen)"

if [ -f "$waypaperrunning" ] && [ -z "${1:-}" ]; then
    rm -f "$waypaperrunning"
    exit 0
fi
rm -f "$waypaperrunning"

mkdir -p "$generatedversions"

if [ -z "$1" ]; then
    if [ -f "$cachefile" ]; then
        wallpaper=$(cat "$cachefile")
    else
        wallpaper=$defaultwallpaper
    fi
else
    wallpaper=$1
fi

# Waypaper boşlukları backslash ile kaçırır: Mehmet\ Emir\ USTA → Mehmet Emir USTA
wallpaper="${wallpaper//\\ / }"

used_wallpaper=$wallpaper
tmpwallpaper=$wallpaper
effect="off"

echo "$wallpaper" >"$cachefile"

wallpaperfilename=$(basename "$wallpaper")

apply_wallpaper_video() {
    local src="$1"
    [ -f "$src" ] || return 1
    [ -f "$HOME/.config/hypr/settings/wallpaper-disabled" ] && return 0
    [ -x "$HOME/.config/hypr/scripts/wallpaper-boot.sh" ] || return 1
    VIDEO="$src" "$HOME/.config/hypr/scripts/wallpaper-boot.sh"
}

# Görsel efektler yalnızca statik görsellerde (video/gif'te mpvpaper zaten oynatıyor)
if [ -f "$wallpapereffect" ] && ! is_video "$wallpaper"; then
    effect=$(cat "$wallpapereffect")
    if [ "$effect" != "off" ]; then
        used_wallpaper="$generatedversions/$effect-$wallpaperfilename"
        if [ ! -f "$used_wallpaper" ] || [ "$force_generate" == "1" ] || [ "$use_cache" == "0" ]; then
            notify-send --replace-id=1 "Wallpaper effect: $effect" "$wallpaperfilename" -h int:value:33
            # shellcheck source=/dev/null
            source "$HOME/.config/hypr/effects/wallpaper/$effect"
        fi
        touch "$waypaperrunning"
        waypaper --wallpaper "$used_wallpaper"
    fi
fi

# Duvar kağıdını hemen uygula (renk üretimi beklenmesin)
apply_wallpaper_video "$used_wallpaper"

color_source=$(color_source_from "$used_wallpaper")

echo ":: matugen ← $color_source"
"$matugen_bin" image "$color_source" -m "dark"

command -v walcord >/dev/null && walcord
command -v pywalfox >/dev/null && pywalfox update

# Caelestia (bar/launcher/notifications + end4-pC widgets + snappy) derives its scheme from this wallpaper.
# Videos are fine: caelestia-cli takes their first frame itself. When this script was started BY caelestia
# (launcher ">wallpaper" -> cli.json wallpaper.postHook), the scheme is already done, so skip it.
if [ -z "${EMIR_FROM_CAELESTIA:-}" ] && command -v caelestia >/dev/null; then
    EMIR_WALLPAPER_SH=1 caelestia wallpaper --no-smart -f "$used_wallpaper" >/dev/null 2>&1 || true
fi

blur_cache="$generatedversions/blur-$blur-$effect-$wallpaperfilename.png"
if command -v magick >/dev/null; then
    if [ ! -f "$blur_cache" ] || [ "$force_generate" == "1" ] || [ "$use_cache" == "0" ]; then
        magick "$color_source" -resize 75% "$blurredwallpaper"
        if [ "$blur" != "0x0" ]; then
            magick "$blurredwallpaper" -blur "$blur" "$blurredwallpaper"
        fi
        cp "$blurredwallpaper" "$blur_cache"
    fi
    [ -f "$blur_cache" ] && cp "$blur_cache" "$blurredwallpaper"
    echo "* { current-image: url(\"$blurredwallpaper\", height); }" >"$rasifile"
    magick "$color_source" -gravity Center -extent 1:1 "$squarewallpaper"
    cp "$squarewallpaper" "$generatedversions/square-$wallpaperfilename.png"
fi
