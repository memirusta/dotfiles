#!/bin/bash
# MOK Manager'ı bir kez başlat — BIOS'ta key management yoksa
# Kullanım: sudo secure-boot-mok-boot.sh [usb|efi]

set -euo pipefail

ESP="/boot"
SHIM_PKG="shim-signed"
SHIM_DIR="/usr/share/shim-signed"
SHIM="$SHIM_DIR/shimx64.efi"
MMX="$SHIM_DIR/mmx64.efi"
ESP_MOK="$ESP/EFI/MOK"
ESP_SHIM="$ESP_MOK/shimx64.efi"
ESP_MMX="$ESP_MOK/mmx64.efi"
ESP_SHIM_GRUB="$ESP_MOK/grubx64.efi"
GRUB_SRC="$ESP/EFI/GRUB/grubx64.efi"
DISK_DEV="${DISK_DEV:-/dev/nvme0n1}"
DISK_PART="${DISK_PART:-1}"

msg() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
need_root() { [ "$(id -u)" -eq 0 ] || { warn "sudo gerekli"; exit 1; }; }

ensure_shim() {
    if [ -f "$SHIM" ] && [ -f "$MMX" ]; then
        return 0
    fi
    msg "shim-signed kuruluyor (AUR)..."
    if command -v yay >/dev/null; then
        sudo -u "${SUDO_USER:-$USER}" yay -S --needed --noconfirm "$SHIM_PKG"
    elif command -v paru >/dev/null; then
        sudo -u "${SUDO_USER:-$USER}" paru -S --needed --noconfirm "$SHIM_PKG"
    else
        warn "yay/paru yok. Kur: yay -S shim-signed"
        exit 1
    fi
    [ -f "$SHIM" ] && [ -f "$MMX" ] || { warn "shim dosyaları bulunamadı: $SHIM_DIR"; exit 1; }
}

remove_mok_boot_entries() {
    while IFS= read -r line; do
        num="${line%%[*}"
        num="${num#Boot}"
        [ -n "$num" ] && efibootmgr -b "$num" -B 2>/dev/null || true
    done < <(efibootmgr 2>/dev/null | grep -iE 'MOK Manager|Shim MOK' || true)
}

check_pending() {
    local has_new=0 has_del=0
    if mokutil --list-new 2>/dev/null | grep -qE 'Certificate|Fingerprint'; then
        has_new=1
    fi
    if mokutil --list-delete 2>/dev/null | grep -qE 'Certificate|Fingerprint'; then
        has_del=1
    fi
    if [ "$has_new" -eq 0 ] && [ "$has_del" -eq 0 ]; then
        warn "Bekleyen MOK işlemi yok (kayıt veya silme)."
        warn "Kayıt için: sudo ~/.config/hypr/scripts/secure-boot-setup.sh enroll-mok"
        exit 1
    fi
    [ "$has_new" -eq 1 ] && msg "Bekleyen MOK anahtar kaydı var."
    [ "$has_del" -eq 1 ] && msg "Bekleyen MOK anahtar silme isteği var."
}

setup_usb() {
    need_root
    ensure_shim
    check_pending

    local usb_mount=""
    for m in /run/media/"${SUDO_USER:-$USER}"/RUFUS_BOOT \
             /run/media/"${SUDO_USER:-$USER}"/*/RUFUS_BOOT; do
        [ -d "$m" ] && usb_mount="$m" && break
    done

    if [ -z "$usb_mount" ]; then
        warn "RUFUS_BOOT USB takılı değil (FAT32 bölüm)."
        ls /run/media/"${SUDO_USER:-$USER}"/ 2>/dev/null || true
        exit 1
    fi

    msg "USB: $usb_mount"
    local need avail
    need=$(stat -c%s "$MMX")
    avail=$(df -B1 --output=avail "$usb_mount" | tail -1 | tr -d ' ')
    if [ "${avail:-0}" -lt "$need" ]; then
        warn "USB'de yer yok (${avail:-0} bayt boş, gerekli: $need)."
        warn "RUFUS_BOOT yalnızca ~1 MB — MOK için yetmez."
        echo
        echo "Bunun yerine (önerilen):"
        echo "  sudo ~/.config/hypr/scripts/secure-boot-mok-boot.sh efi"
        exit 1
    fi

    mkdir -p "$usb_mount/EFI/BOOT"
    cp -f "$MMX" "$usb_mount/EFI/BOOT/BOOTx64.EFI"
    sync

    cat <<EOF

Hazır. Şimdi:
1) USB'yi çıkarıp tekrar tak (gerekirse)
2) Yeniden başlat → F12 / Novo → USB'den boot
3) Mavi MOK Manager → Enroll MOK → şifre: secrets dosyandaki
4) Reboot → USB çıkar → normal Arch boot

EOF
}

setup_efi_entry() {
    need_root
    ensure_shim
    check_pending

    mkdir -p "$ESP_MOK"
    cp -f "$SHIM" "$ESP_SHIM"
    cp -f "$MMX" "$ESP_MMX"
    # grubx64.efi KOYMA — shim önce GRUB doğrulamaya çalışıp 0x1A veriyor
    rm -f "$ESP_SHIM_GRUB"
    chmod 644 "$ESP_SHIM" "$ESP_MMX"

    remove_mok_boot_entries

    msg "Shim + MOK boot girişi oluşturuluyor (grub yok, sadece MOK)..."
    efibootmgr --create \
        --disk "$DISK_DEV" --part "$DISK_PART" \
        --label "Shim MOK" \
        --loader "\\EFI\\MOK\\shimx64.efi" \
        --unicode

    local mok_num current_order new_order
    mok_num=$(efibootmgr 2>/dev/null | grep -i 'Shim MOK' | head -1 | sed -n 's/Boot\([0-9A-Fa-f]*\).*/\1/p')
    current_order=$(efibootmgr 2>/dev/null | awk -F': ' '/BootOrder/ {print $2}')
    new_order="${mok_num},${current_order}"
    new_order="${new_order//${mok_num},${mok_num},/${mok_num},}"
    efibootmgr -o "$new_order"

    cat <<EOF

Hazır. Yeniden başlat → "Shim MOK" seç (F12 boot menüsü).
Bekleyen kayıt veya silme varsa mavi MOK ekranı gelmeli.

Hâlâ 0x1A olursa OK → F12 → GRUB ile Arch aç:
  sudo ~/.config/hypr/scripts/secure-boot-mok-boot.sh cleanup

EOF
}

cleanup() {
    need_root
    remove_mok_boot_entries
    rm -f "$ESP_SHIM" "$ESP_MMX" "$ESP_SHIM_GRUB"
    rmdir "$ESP_MOK" 2>/dev/null || true
    msg "Shim/MOK boot girişi kaldırıldı."
}

case "${1:-}" in
    usb) setup_usb ;;
    efi) setup_efi_entry ;;
    cleanup) cleanup ;;
    *)
        echo "Kullanım: sudo $0 [usb|efi|cleanup]"
        echo "  usb  — RUFUS_BOOT USB'den MOK Manager (önerilen)"
        echo "  efi  — Geçici EFI boot girişi (disk üzerinde)"
        exit 1
        ;;
esac
