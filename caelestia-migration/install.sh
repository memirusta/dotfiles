#!/usr/bin/env bash
# Emir — Noctalia -> Caelestia geçişi
#   Caelestia shell (dikey bar + Emir bar modülleri), end4-pC masaüstü widget'ları,
#   snappy-switcher (Alt+Tab), Vicinae (Super+V clipboard), polkit-gnome.
#
#   ./install.sh            kur
#   FORCE=1 ./install.sh    canlı hypr dosyaların repodakinden farklıysa bile üzerine yaz
#   SKIP_BUILD=1 ./install.sh  paket kurulumu + Caelestia derlemesini atla (yarıda kalan kurulumu sürdürmek için)
#   ./rollback.sh           her şeyi geri al
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
SRC="$HOME/.local/src"
CAELESTIA_REV="48b323fa9d7ada89939ba6b3ea4e4fdf93d126a6" # caelestia-dots/shell main, 2026-10-28
PC_REPO="https://github.com/pctrade/end4-pC.git"
BACKUP_ROOT="$HOME/.config-backups"
BACKUP="$BACKUP_ROOT/caelestia-migration-$(date +%Y%m%d-%H%M%S)"

say()  { printf '\n\033[1;36m:: %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!! %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "root olarak değil, kendi kullanıcınla çalıştır (sudo gerektiğinde sorulacak)."
command -v yay >/dev/null     || die "yay bulunamadı."
command -v hyprctl >/dev/null || die "hyprctl bulunamadı."

# ── 0. Canlı dosyalar repodakiyle aynı mı? ─────────────────────────────────────
# Değiştirilen dosyalar repodaki halinden üretildi; o zamandan beri elle değiştirdiysen üzerine yazmayalım.
changed=0
for f in lua/keybindings.lua lua/autostart.lua lua/windowrules.lua lua/workspaces.lua scripts/wallpaper.sh \
    settings-app/hypr-settings.py keybindings-help.tsv; do
    # repodaki orijinal ya da zaten bu paketin hali (tekrar çalıştırma) ise sorun yok
    if [ -f "$CFG/hypr/$f" ] && ! cmp -s "$CFG/hypr/$f" "$REPO/hypr/$f" && ! cmp -s "$CFG/hypr/$f" "$HERE/hypr/$f"; then
        warn "~/.config/hypr/$f repodaki halinden farklı:"
        diff -u "$REPO/hypr/$f" "$CFG/hypr/$f" | head -20 || true
        changed=1
    fi
done
if [ "$changed" = 1 ] && [ "${FORCE:-0}" != 1 ]; then
    die "Önce farkları repoya al (cp + commit) ya da bilerek ezmek için: FORCE=1 ./install.sh"
fi

# ── 1. Yedek ──────────────────────────────────────────────────────────────────
say "Yedek: $BACKUP"
mkdir -p "$BACKUP"
for d in hypr caelestia quickshell snappy-switcher illogical-impulse; do
    [ -e "$CFG/$d" ] && cp -aL "$CFG/$d" "$BACKUP/"
done
[ -d "$STATE/quickshell" ] && mkdir -p "$BACKUP/state" && cp -aL "$STATE/quickshell" "$BACKUP/state/"
# Geri dönüş noktası = ilk kurulumdan önceki hal. Tekrar çalıştırmalarda (zaten geçirilmiş config'in yedeği) ezilmesin.
[ -s "$BACKUP_ROOT/caelestia-migration-latest" ] || echo "$BACKUP" >"$BACKUP_ROOT/caelestia-migration-latest"

# ── 2. Paketler ───────────────────────────────────────────────────────────────
if [ "${SKIP_BUILD:-0}" != 1 ]; then
say "Paketler"
if pacman -Qq quickshell >/dev/null 2>&1; then
    warn "quickshell (stable) kurulu; Caelestia quickshell-git istiyor. yay değiştirmeyi sorarsa 'y' de."
fi
# Caelestia'nın bağımlılık listesini AUR'dan o an okuyoruz (paket adları değişirse kurulum bozulmasın).
# Paketin kendisini kurmuyoruz: shell'i aşağıda patch'li haliyle kendimiz derliyoruz.
aur_deps() {
    # (uzun satırlar girintili devam satırlarına bölünebiliyor, onları da topla)
    yay -Si "$1" \
        | awk '/^(Depends On|Make Deps)/ { f = 1; sub(/^[^:]*: */, ""); print; next } /^[^ ]/ { f = 0 } f { print }' \
        | tr -s ' \t' '\n\n' | sed 's/[<>=].*//' | grep -vE '^(None|)$' | sort -u || true
}
mapfile -t CAELESTIA_DEPS < <(aur_deps caelestia-shell-git)
[ "${#CAELESTIA_DEPS[@]}" -gt 0 ] || die "caelestia-shell-git bağımlılıkları okunamadı (yay -Si)."
PKGS=(
    "${CAELESTIA_DEPS[@]}" git cmake ninja caelestia-cli
    qt6-5compat                                    # end4-pC widget'ları
    snappy-switcher vicinae polkit-gnome           # Alt+Tab, clipboard, polkit
    fuzzel ffmpeg jq wl-clipboard pavucontrol btop
)
yay -S --needed "${PKGS[@]}"

# ── 3. Caelestia shell (sabit commit + Emir bar patch'i) ───────────────────────
say "Caelestia shell derleniyor ($CAELESTIA_REV)"
mkdir -p "$SRC" "$CFG/quickshell"
[ -d "$SRC/caelestia-shell/.git" ] || git clone https://github.com/caelestia-dots/shell.git "$SRC/caelestia-shell"
cd "$SRC/caelestia-shell"
git fetch --tags origin
git checkout -q -B emir "$CAELESTIA_REV"
if ! git -c user.name=emir -c user.email=emir@localhost am --3way "$HERE/patches/0001-emir-bar.patch"; then
    git am --abort || true
    die "Bar patch'i uygulanamadı."
fi
rm -rf build
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ \
    -DINSTALL_QSCONFDIR="$CFG/quickshell/caelestia"
cmake --build build
sudo cmake --install build
cd "$HERE"
fi # SKIP_BUILD

# sudo cmake --install ~/.config/quickshell'i root olarak oluşturabiliyor: sahipliği geri al
sudo chown "$USER:" "$CFG/quickshell"
sudo chown -R "$USER:" "$CFG/quickshell/caelestia"

# ── 4. Caelestia ayarları ─────────────────────────────────────────────────────
say "Caelestia ayarları"
mkdir -p "$CFG/caelestia/templates"
cp "$HERE/caelestia/shell.json" "$HERE/caelestia/cli.json" "$HERE/caelestia/emir.json" "$CFG/caelestia/"
cp "$HERE/caelestia/templates/"* "$CFG/caelestia/templates/"

# ── 5. Hyprland ───────────────────────────────────────────────────────────────
say "Hyprland: keybind / autostart / windowrules / wallpaper.sh"
cp "$HERE/hypr/lua/"*.lua "$CFG/hypr/lua/"
install -m755 "$HERE/hypr/scripts/wallpaper.sh" "$HERE/hypr/scripts/caelestia-theme-hook.sh" "$CFG/hypr/scripts/"
cp "$HERE/hypr/settings-app/hypr-settings.py" "$CFG/hypr/settings-app/"
cp "$HERE/hypr/keybindings-help.tsv" "$CFG/hypr/"

# ── 6. snappy-switcher ────────────────────────────────────────────────────────
say "snappy-switcher"
mkdir -p "$CFG/snappy-switcher/themes"
cp "$HERE/snappy-switcher/config.ini" "$CFG/snappy-switcher/config.ini"

# ── 7. end4-pC (sadece masaüstü widget'ları) ──────────────────────────────────
say "end4-pC masaüstü widget'ları"
if [ -d "$CFG/quickshell/end4-pC/.git" ]; then
    git -C "$CFG/quickshell/end4-pC" pull --ff-only || warn "end4-pC güncellenemedi, mevcut sürümle devam."
else
    git clone --depth 1 "$PC_REPO" "$CFG/quickshell/end4-pC"
fi
cp "$HERE/end4-pC/emir-widgets.qml" "$CFG/quickshell/end4-pC/"
# pC duvar kağıdı "video" olunca arka planını şeffaf bırakıp mpvpaper'a bırakıyor: sahte 1 sn'lik video
mkdir -p "$CFG/hypr/cache"
ffmpeg -loglevel error -y -f lavfi -i color=c=black:s=16x16:d=1 -c:v libx264 -pix_fmt yuv420p \
    "$CFG/hypr/cache/emir-transparent.mp4"
# İlk açılış sihirbazı duvar kağıdını değiştirip mpvpaper'ı öldürüyor: hiç çalışmasın
mkdir -p "$STATE/quickshell/user/generated"
echo "This file is just here to confirm you've been greeted :>" >"$STATE/quickshell/user/first_run.txt"
iicfg="$CFG/illogical-impulse/config.json"
mkdir -p "$(dirname "$iicfg")"
seed="$(sed "s|@HOME@|$HOME|g" "$HERE/illogical-impulse/config.json")"
if [ -s "$iicfg" ]; then
    jq -s '.[0] * .[1]' "$iicfg" <(printf '%s' "$seed") >"$iicfg.tmp" && mv "$iicfg.tmp" "$iicfg"
else
    printf '%s\n' "$seed" >"$iicfg"
fi

# ── 8. Renk şeması (mevcut duvar kağıdından) ──────────────────────────────────
say "Renk şeması"
wall="$(cat "$CFG/hypr/cache/current_wallpaper" 2>/dev/null || true)"
wall="${wall//\\ / }"
if [ -n "$wall" ] && [ -f "$wall" ]; then
    EMIR_WALLPAPER_SH=1 caelestia wallpaper --no-smart -f "$wall" || warn "caelestia wallpaper başarısız"
fi
EMIR_WALLPAPER_SH=1 caelestia scheme set -n dynamic -m dark || warn "caelestia scheme başarısız"

# ── 9. Canlı geçiş ────────────────────────────────────────────────────────────
say "Noctalia kapatılıyor, Caelestia başlatılıyor"
pkill -x noctalia 2>/dev/null || true
qs -c caelestia kill 2>/dev/null || true
pkill -f emir-widgets.qml 2>/dev/null || true
sleep 0.5
caelestia shell -d
sleep 1
qs -n -d -p "$CFG/quickshell/end4-pC/emir-widgets.qml"
pgrep -f polkit-gnome-authentication-agent-1 >/dev/null || (/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &>/dev/null & disown)
pgrep -x vicinae >/dev/null || (vicinae server &>/dev/null & disown)
pgrep -x snappy-switcher >/dev/null || (snappy-switcher --daemon &>/dev/null & disown)
hyprctl reload >/dev/null

say "Bitti. Yedek: $BACKUP — geri almak için: $HERE/rollback.sh"
