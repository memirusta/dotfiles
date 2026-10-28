#!/bin/bash
# GRUB dual-boot teması — siyah arka plan, beyaz logolar, Windows varsayılan
# Kullanım: sudo grub-dualboot-setup.sh [install|windows-default|status]

set -euo pipefail

ESP="/boot"
GRUB_DEFAULT_FILE="/etc/default/grub"
THEME_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/grub-theme/dualboot-light"
THEME_DST="$ESP/grub/themes/dualboot-light"
SIGN_SCRIPT="$(dirname "${BASH_SOURCE[0]}")/secure-boot-setup.sh"
RES_W=1920
RES_H=1080
ICON_SIZE=112

msg() { printf '==> %s\n' "$*" >&2; }
warn() { printf '!! %s\n' "$*" >&2; }
need_root() { [ "$(id -u)" -eq 0 ] || { warn "sudo gerekli"; exit 1; }; }

ensure_tools() {
    pacman -S --needed --noconfirm python-pillow grub >/dev/null
}

find_logo_sources() {
    local d
    for d in /tmp/hyperfluent/windows-light/icons \
             /usr/share/grub/themes/*/icons \
             "$THEME_SRC/icons"; do
        [ -f "$d/arch.png" ] && [ -f "$d/windows.png" ] && { echo "$d"; return 0; }
    done
    return 1
}

fetch_logo_sources() {
    local tmp=/tmp/hyperfluent-logos
    if [ -f "$tmp/arch.png" ] && [ -f "$tmp/windows.png" ]; then
        echo "$tmp"
        return 0
    fi
    msg "Logo dosyaları indiriliyor..."
    mkdir -p "$tmp"
    curl -fsSL -o "$tmp/arch.png" \
        "https://raw.githubusercontent.com/Coopydood/HyperFluent-GRUB-Theme/main/windows-light/icons/arch.png"
    curl -fsSL -o "$tmp/windows.png" \
        "https://raw.githubusercontent.com/Coopydood/HyperFluent-GRUB-Theme/main/windows-light/icons/windows.png"
    echo "$tmp"
}

generate_icon_small() {
    local src="$1" dst="$2"
    python3 - "$src" "$dst" "$ICON_SIZE" <<'PY'
import sys
from PIL import Image

src, dst, size = sys.argv[1:4]
size = int(size)
icon = Image.open(src).convert("RGBA")
_, _, _, alpha = icon.split()
white = Image.new("RGBA", icon.size, (255, 255, 255, 255))
white.putalpha(alpha)
white.thumbnail((size, size), Image.Resampling.LANCZOS)
canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
x = (size - white.width) // 2
y = (size - white.height) // 2
canvas.alpha_composite(white, (x, y))
canvas.save(dst, "PNG")
PY
}

copy_theme_chrome() {
    local src_dir=""
    for src_dir in /tmp/hyperfluent/windows-light \
                   /tmp/hyperfluent/arch \
                   /usr/share/grub/themes/starfield; do
        [ -d "$src_dir" ] || continue
        for f in select_c.png select_e.png select_w.png select_n.png \
                 select_s.png select_ne.png select_nw.png select_se.png select_sw.png \
                 terminal_box_c.png terminal_box_e.png terminal_box_n.png terminal_box_s.png \
                 terminal_box_w.png terminal_box_ne.png terminal_box_nw.png terminal_box_se.png terminal_box_sw.png; do
            [ -f "$src_dir/$f" ] && cp -f "$src_dir/$f" "$THEME_DST/$f"
        done
        return 0
    done
    warn "Highlight dosyalari bulunamadi; basit secim kutusu olusturuluyor..."
    python3 - "$THEME_DST" <<'PY'
import sys
from PIL import Image, ImageDraw
dst = sys.argv[1]
for name in ("select_c.png", "select_w.png", "select_e.png"):
    img = Image.new("RGBA", (140, 140), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((4, 4, 135, 135), radius=18, outline=(255, 255, 255, 220), width=4)
    img.save(f"{dst}/{name}")
PY
}

build_theme_assets() {
    need_root
    ensure_tools
    local logos
    logos="$(find_logo_sources 2>/dev/null || true)"
    logos="${logos:-$(fetch_logo_sources)}"

    if [ ! -d /tmp/hyperfluent/windows-light ]; then
        git clone --depth 1 https://github.com/Coopydood/HyperFluent-GRUB-Theme.git /tmp/hyperfluent 2>/dev/null || true
    fi

    mkdir -p "$THEME_DST/icons"
    cp -f "$THEME_SRC/theme.txt" "$THEME_DST/theme.txt"

    for pf in terminus-16.pf2; do
        if [ -f "$THEME_SRC/$pf" ]; then
            cp -f "$THEME_SRC/$pf" "$THEME_DST/$pf"
        elif [ -f /tmp/hyperfluent/windows-light/$pf ]; then
            cp -f /tmp/hyperfluent/windows-light/$pf "$THEME_DST/$pf"
        elif [ -f /usr/share/grub/themes/starfield/$pf ]; then
            cp -f /usr/share/grub/themes/starfield/$pf "$THEME_DST/$pf"
        else
            grub-mkfont -o "$THEME_DST/$pf" /usr/share/fonts/liberation/LiberationMono-Regular.ttf -s 16
        fi
    done

    msg "Beyaz logolar (menu ikonlari) olusturuluyor..."
    generate_icon_small "$logos/arch.png" "$THEME_DST/icons/arch.png"
    generate_icon_small "$logos/windows.png" "$THEME_DST/icons/windows.png"
    generate_icon_small "$logos/arch.png" "$THEME_DST/icons/gnu-linux.png"
    generate_icon_small "$logos/arch.png" "$THEME_DST/icons/os.png"
    generate_icon_small "$logos/windows.png" "$THEME_DST/icons/efi.png"
    rm -f "$THEME_DST/background.png"
    copy_theme_chrome
    chmod -R a+rX "$THEME_DST"
}

simplify_grub_menu() {
    need_root
    [ -x /etc/grub.d/35_fwupd ] && chmod -x /etc/grub.d/35_fwupd
    if grep -q '^GRUB_DISABLE_SUBMENU=' "$GRUB_DEFAULT_FILE"; then
        sed -i 's|^GRUB_DISABLE_SUBMENU=.*|GRUB_DISABLE_SUBMENU=y|' "$GRUB_DEFAULT_FILE"
    else
        echo 'GRUB_DISABLE_SUBMENU=y' >> "$GRUB_DEFAULT_FILE"
    fi
    msg "Ekstra menüler azaltıldı (UEFI gizli, alt menü düz)."
}

windows_menu_id() {
    grep "menuentry 'Windows Boot Manager" "$ESP/grub/grub.cfg" 2>/dev/null \
        | sed -n "s/.*'\(osprober-efi-[^']*\)'.*/\1/p" | head -1
}

set_grub_default_windows() {
    need_root
    local win_id win_title
    win_title="Windows Boot Manager (on /dev/nvme0n1p1)"
    win_id="$(windows_menu_id || true)"

    if [ -z "$win_id" ]; then
        warn "Windows menuentry bulunamadi; once grub-mkconfig calistiriliyor..."
        grub-mkconfig -o "$ESP/grub/grub.cfg" >/dev/null
        win_id="$(windows_menu_id || true)"
    fi

    if [ -z "$win_id" ]; then
        warn "Windows ID yok; baslik kullanilacak: $win_title"
        win_id="$win_title"
    fi
    if grep -q '^GRUB_DEFAULT=' "$GRUB_DEFAULT_FILE"; then
        sed -i "s|^GRUB_DEFAULT=.*|GRUB_DEFAULT=\"$win_id\"|" "$GRUB_DEFAULT_FILE"
    else
        echo "GRUB_DEFAULT=\"$win_id\"" >> "$GRUB_DEFAULT_FILE"
    fi
    if grep -q '^GRUB_THEME=' "$GRUB_DEFAULT_FILE"; then
        sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DST/theme.txt\"|" "$GRUB_DEFAULT_FILE"
    else
        echo "GRUB_THEME=\"$THEME_DST/theme.txt\"" >> "$GRUB_DEFAULT_FILE"
    fi

    if grep -q '^GRUB_GFXMODE=' "$GRUB_DEFAULT_FILE"; then
        sed -i 's|^GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080,1280x800,auto|' "$GRUB_DEFAULT_FILE"
    else
        echo 'GRUB_GFXMODE=1920x1080,1280x800,auto' >> "$GRUB_DEFAULT_FILE"
    fi

    grep -q '^GRUB_GFXPAYLOAD_LINUX=' "$GRUB_DEFAULT_FILE" || \
        echo 'GRUB_GFXPAYLOAD_LINUX=keep' >> "$GRUB_DEFAULT_FILE"
    grep -q '^GRUB_DISABLE_OS_PROBER=' "$GRUB_DEFAULT_FILE" || \
        echo 'GRUB_DISABLE_OS_PROBER=false' >> "$GRUB_DEFAULT_FILE"

    msg "Varsayılan önyükleme: Windows"
    [ -n "$win_id" ] && echo "  GRUB ID: $win_id"
}

regenerate_grub() {
    need_root
    grub-mkconfig -o "$ESP/grub/grub.cfg"
    if [ -x "$SIGN_SCRIPT" ]; then
        msg "Secure Boot imzaları güncelleniyor..."
        "$SIGN_SCRIPT" sign-all
    fi
}

install_all() {
    build_theme_assets
    simplify_grub_menu
    set_grub_default_windows
    regenerate_grub
    msg "GRUB teması kuruldu."
    echo
    echo "Reboot ile test et."
    echo "Arch ve Windows logolari alt alta; yukari/asagi ile sec, Enter ile ac."
    echo "5 sn secim yoksa Windows acilir."
}

status() {
    echo "=== GRUB dual-boot ==="
    grep -E '^GRUB_DEFAULT=|^GRUB_THEME=|^GRUB_GFXMODE=' "$GRUB_DEFAULT_FILE" 2>/dev/null || true
    echo
    [ -f "$THEME_DST/theme.txt" ] && echo "✓ Tema: $THEME_DST" || echo "✗ Tema kurulu değil"
    windows_menu_id && echo "Windows ID: $(windows_menu_id)" || echo "Windows ID bulunamadı"
}

case "${1:-install}" in
    install) install_all ;;
    windows-default) need_root; set_grub_default_windows; regenerate_grub ;;
    status) status ;;
    *)
        echo "Kullanım: sudo $0 [install|windows-default|status]"
        exit 1
        ;;
esac
