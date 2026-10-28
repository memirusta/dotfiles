#!/bin/bash
# Windows (dual boot) → ttf-ms-win11 font kurulumu
# Kullanım: ./install-win-fonts.sh
# Önce Windows partition'ı mount etmen gerekir (aşağıdaki adımlar)

set -euo pipefail

PKG_DIR="${HOME}/.cache/yay/ttf-ms-win11"
WIN_MOUNT="${WIN_MOUNT:-/mnt/win}"

die() { echo "HATA: $*" >&2; exit 1; }

# Olası Windows bölümleri (nvme0n1p3/p4 veya sda1)
if [ ! -d "$WIN_MOUNT/Windows/Fonts" ]; then
    cat <<'EOF'
Windows bölümü mount edilmemiş.

Terminalde (şifreni gir):

  sudo mkdir -p /mnt/win
  sudo mount -o ro /dev/nvme0n1p3 /mnt/win

Fonts yoksa diğer bölümü dene:

  sudo umount /mnt/win
  sudo mount -o ro /dev/nvme0n1p4 /mnt/win

Kontrol:

  ls /mnt/win/Windows/Fonts/segoeui.ttf

Sonra tekrar çalıştır:

  ~/.config/hypr/scripts/install-win-fonts.sh
EOF
    exit 1
fi

[ -d "$PKG_DIR" ] || die "Önce: yay -S ttf-ms-win11 (build hatası normal, PKGBUILD indirilsin yeter)"

FONTS_SRC="$WIN_MOUNT/Windows/Fonts"
LICENSE_SRC=""
for candidate in \
    "$WIN_MOUNT/Windows/System32/Licenses/neutral/_Default/Core/license.rtf" \
    "$WIN_MOUNT/Windows/System32/Licenses/neutral/OEM/Professional/license.rtf" \
    "$WIN_MOUNT/Windows/System32/Licenses/neutral/Volume/Professional/license.rtf"
do
    if [ -f "$candidate" ]; then
        LICENSE_SRC="$candidate"
        break
    fi
done

if [ -n "$LICENSE_SRC" ]; then
    cp -f "$LICENSE_SRC" "$PKG_DIR/license.rtf"
    echo "→ license.rtf kopyalandı"
else
    echo "UYARI: license.rtf bulunamadı"
fi

echo "→ Fontlar kopyalanıyor: $FONTS_SRC → $PKG_DIR"

copied=0
missing=0
while IFS= read -r line; do
    for f in $line; do
        case "$f" in
            *.ttf|*.ttc)
                if [ -f "$FONTS_SRC/$f" ]; then
                    cp -f "$FONTS_SRC/$f" "$PKG_DIR/"
                    copied=$((copied + 1))
                else
                    echo "  eksik: $f"
                    missing=$((missing + 1))
                fi
                ;;
        esac
    done
done < <(rg -o '[A-Za-z0-9_.-]+\.(ttf|ttc)' "$PKG_DIR/PKGBUILD" | sort -u)

echo "→ $copied font kopyalandı, $missing eksik"

[ "$copied" -gt 50 ] || die "Çok az font kopyalandı — yanlış Windows bölümü olabilir"

echo "→ Paket derleniyor (--skipinteg: SegoeIcons sürüm farkı)..."
cd "$PKG_DIR"
makepkg -si --noconfirm --skipinteg

fc-cache -fv >/dev/null 2>&1 || true

echo ""
echo "Kontrol: fc-match 'Segoe UI'"
fc-match "Segoe UI" || true
echo ""
echo "Chrome font ayarı + yeniden başlat:"
echo "  pkill -f google-chrome; ~/.config/hypr/scripts/chrome-fonts.sh; google-chrome-stable"
