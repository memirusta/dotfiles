#!/bin/bash
# Secure Boot — Arch + GRUB + nvidia-open (Legion 5)
# Kullanım: secure-boot-setup.sh [guide|status|prepare|enroll|sign-all|install]

set -euo pipefail

ESP="/boot"
GRUB_EFI="$ESP/EFI/GRUB/grubx64.efi"
KERNEL="/boot/vmlinuz-linux"
KEY_DIR="/var/lib/sbctl/keys/db"
DB_KEY="$KEY_DIR/db.key"
DB_CERT="$KEY_DIR/db.pem"
KVER="$(uname -r)"
EXTRA_MOD_DIR="/usr/lib/modules/$KVER/extramodules"
MOK_MOD_DIR="/var/lib/sbctl/keys/mok"
MOK_MOD_KEY="$MOK_MOD_DIR/mok.key"
MOK_MOD_CERT="$MOK_MOD_DIR/mok.pem"
SIGN_FILE="/usr/lib/modules/$KVER/build/scripts/sign-file"

msg() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
need_root() { [ "$(id -u)" -eq 0 ] || { warn "Bu adım sudo gerektirir."; exit 1; }; }

resolve_mok_keys() {
    MOK_MOD_KEY="$MOK_MOD_DIR/mok.key"
    MOK_MOD_CERT="$MOK_MOD_DIR/mok.pem"
}

guide() {
    local text
    text="$(cat <<'EOF'
Secure Boot — Legion 5 (Arch + GRUB + nvidia-open)

ÖNEMLİ
• Windows dual-boot: enroll-keys -m Microsoft anahtarlarını da ekler.
• BIOS'ta Secure Boot, imzalama bitene kadar KAPALI kalsın.
• enroll-keys sonrası mavi MOK ekranında şifre belirle — bir yere yaz.

ADIMLAR (terminalde sırayla)

1) BIOS → Secure Boot → "Setup Mode" / "Custom Mode" aç
   (Henüz Secure Boot'u AÇMA)

2) Hazırlık (imzalama, GRUB, paketler)
   sudo ~/.config/hypr/scripts/secure-boot-setup.sh prepare

3) Anahtarları firmware + MOK'a kaydet
   sudo ~/.config/hypr/scripts/secure-boot-setup.sh enroll
   → yeniden başlat
   → MOK Manager: "Enroll key" / "Continue" / "Yes" → şifre gir

4) Açılış testi (Secure Boot hâlâ kapalı)
   nvidia-smi çalışıyor mu?
   sudo ~/.config/hypr/scripts/secure-boot-setup.sh status

5) BIOS'ta Secure Boot AÇ → kaydet → yeniden başlat

6) Her kernel / nvidia-open güncellemesinden sonra
   sudo ~/.config/hypr/scripts/secure-boot-setup.sh sign-all

Sorun olursa BIOS'tan Secure Boot kapat — sistem yine açılır.

Tek komut (2–4 arası elle onaylar):
   sudo ~/.config/hypr/scripts/secure-boot-setup.sh full-install
EOF
)"
    if command -v zenity >/dev/null; then
        printf '%s' "$text" | zenity --text-info --title="Secure Boot" --width=680 --height=560 2>/dev/null && return
    fi
    printf '%s\n' "$text"
}

status() {
    echo "=== Secure Boot durumu ==="
    mokutil --sb-state 2>/dev/null || warn "mokutil yok"
    echo
    if command -v sbctl >/dev/null; then
        sbctl status 2>/dev/null || warn "sbctl status için sudo gerekebilir"
        echo
        sbctl verify 2>/dev/null || true
    else
        warn "sbctl kurulu değil"
    fi
    echo
    echo "Kernel: $KVER"
    echo "NVIDIA: $(pacman -Q nvidia-open 2>/dev/null || echo yok)"
    ls -la "$KERNEL" "$GRUB_EFI" 2>/dev/null || true
    echo
    if command -v nvidia-smi >/dev/null; then
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader 2>/dev/null || warn "nvidia-smi başarısız"
    fi
}

install_packages() {
    need_root
    msg "Paketler kuruluyor..."
    pacman -S --needed --noconfirm sbctl mokutil sbsigntools linux-headers
}

reinstall_grub() {
    need_root
    msg "GRUB Secure Boot uyumlu yeniden kuruluyor..."
    grub-install \
        --target=x86_64-efi \
        --efi-directory="$ESP" \
        --bootloader-id=GRUB \
        --modules="tpm normal linux search configfile part_gpt fat ext2 btrfs gzio echo" \
        --disable-shim-lock
    grub-mkconfig -o "$ESP/grub/grub.cfg"
}

resolve_keys() {
    if [ -f /var/lib/sbctl/keys/db/db.key ]; then
        DB_KEY=/var/lib/sbctl/keys/db/db.key
        DB_CERT=/var/lib/sbctl/keys/db/db.pem
    elif [ -f /usr/share/secureboot/keys/DB.key ]; then
        DB_KEY=/usr/share/secureboot/keys/DB.key
        DB_CERT=/usr/share/secureboot/keys/DB.pem
    fi
}

create_keys() {
    need_root
    resolve_keys
    if [ ! -f "$DB_KEY" ]; then
        msg "sbctl anahtarları oluşturuluyor..."
        sbctl create-keys
        resolve_keys
        msg "sbctl pacman entegrasyonu kuruluyor..."
        sbctl setup --setup || warn "sbctl setup atlandı."
    else
        msg "sbctl anahtarları zaten var."
    fi
}

sign_boot_files() {
    need_root
    resolve_keys
    [ -f "$DB_KEY" ] || { warn "Önce create-keys çalıştır."; exit 1; }

    msg "Önyükleme dosyaları imzalanıyor..."
    for f in "$KERNEL" "$GRUB_EFI"; do
        [ -f "$f" ] || { warn "Dosya yok: $f"; continue; }
        sbctl sign -s "$f"
    done

    # GRUB modülleri (güncelleme sonrası)
    shopt -s nullglob
    for f in "$ESP/grub/x86_64-efi/"*.efi; do
        sbctl sign -s "$f" 2>/dev/null || true
    done

    # Fallback boot yolu
    if [ -f "$GRUB_EFI" ]; then
        mkdir -p "$ESP/EFI/Boot"
        cp -f "$GRUB_EFI" "$ESP/EFI/Boot/bootx64.efi"
        sbctl sign -s "$ESP/EFI/Boot/bootx64.efi"
    fi
}

mok_cert_is_ca() {
    resolve_mok_keys
    [ -f "$MOK_MOD_CERT" ] || return 1
    openssl x509 -in "$MOK_MOD_CERT" -noout -text 2>/dev/null | grep -q "CA:TRUE"
}

create_mok_module_keys() {
    need_root
    resolve_mok_keys
    mkdir -p "$MOK_MOD_DIR"
    chmod 700 "$MOK_MOD_DIR"
    if [ -f "$MOK_MOD_KEY" ] && [ -f "$MOK_MOD_CERT" ]; then
        if mok_cert_is_ca; then
            warn "Mevcut MOK sertifikası CA:TRUE — kernel modül imzasını kabul etmez."
            warn "Yenile: sudo $0 renew-mok-keys"
            return 1
        fi
        msg "MOK modül anahtarları zaten var."
        return 0
    fi
    msg "NVIDIA modülleri için MOK anahtarı oluşturuluyor (CA:FALSE, codeSigning)..."
    openssl req -new -x509 -newkey rsa:2048 \
        -keyout "$MOK_MOD_KEY" -out "$MOK_MOD_CERT" \
        -nodes -days 3650 -subj "/CN=Arch NVIDIA Module Signing" \
        -addext "basicConstraints=critical,CA:FALSE" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=codeSigning" \
        -addext "subjectKeyIdentifier=hash"
    chmod 600 "$MOK_MOD_KEY" "$MOK_MOD_CERT"
}

renew_mok_keys() {
    need_root
    resolve_mok_keys
    local backup="$MOK_MOD_DIR/backup-$(date +%Y%m%d%H%M%S)"
    local old_der="/var/lib/sbctl/keys/mok/mok-old-delete.der"
    local old_pem="/var/lib/sbctl/keys/mok/mok-old.pem"
    mkdir -p "$backup"
    if [ -f "$MOK_MOD_CERT" ]; then
        cp -a "$MOK_MOD_KEY" "$MOK_MOD_CERT" "$backup/" 2>/dev/null || true
        cp -a "$MOK_MOD_CERT" "$old_pem"
        openssl x509 -in "$MOK_MOD_CERT" -outform DER -out "$old_der"
        chmod 600 "$old_pem" "$old_der"
        msg "Eski MOK sertifikası (silme için): $old_der"
        warn "Kayıtlı eski CA anahtarını sil:"
        echo "  sudo mokutil --delete $old_der"
    fi
    rm -f "$MOK_MOD_KEY" "$MOK_MOD_CERT"
    create_mok_module_keys
    enroll_mok
    cat <<EOF

Sonraki adımlar:
1) Eski CA anahtarını sil:  sudo mokutil --delete /var/lib/sbctl/keys/mok/mok-old-delete.der
2) Shim MOK boot:           sudo ~/.config/hypr/scripts/secure-boot-mok-boot.sh efi
3) Yeniden başlat, Shim MOK seç, yeni anahtarı onayla
4) İmzala:                  sudo $0 sign-all
5) Normal reboot, kontrol:  journalctl -k -b 0 | grep -i "module verification"
EOF
}

sign_nvidia_modules() {
    need_root
    resolve_mok_keys
    [ -f "$MOK_MOD_KEY" ] || create_mok_module_keys
    [ -f "$MOK_MOD_KEY" ] || { warn "MOK modül anahtarı yok."; exit 1; }

    local extra_dir kver sign_file f tmp signed=0
    shopt -s nullglob
    for extra_dir in /usr/lib/modules/*/extramodules; do
        [ -d "$extra_dir" ] || continue
        kver="$(basename "$(dirname "$extra_dir")")"
        sign_file="/usr/lib/modules/$kver/build/scripts/sign-file"
        [ -x "$sign_file" ] || { warn "sign-file yok ($kver), atlanıyor"; continue; }

        local found=0
        for f in "$extra_dir"/nvidia*.ko.zst; do found=1; break; done
        [ "$found" -eq 0 ] && continue

        msg "NVIDIA modülleri imzalanıyor ($extra_dir)..."
        for f in "$extra_dir"/nvidia*.ko.zst; do
            tmp="$(mktemp --suffix=.ko)"
            zstd -d -q -f -o "$tmp" "$f"
            "$sign_file" sha512 "$MOK_MOD_KEY" "$MOK_MOD_CERT" "$tmp"
            zstd -q -f "$tmp" -o "$f"
            rm -f "$tmp"
            echo "  ✓ $kver: $(basename "$f")"
            signed=1
        done
    done
    [ "$signed" -eq 0 ] && warn "İmzalanacak NVIDIA modülü bulunamadı."
}

sign_all() {
    need_root
    resolve_keys
    resolve_mok_keys
    sign_boot_files
    sign_nvidia_modules
    mkinitcpio -P
    grub-mkconfig -o "$ESP/grub/grub.cfg"
    msg "İmzalama tamam."
    sbctl verify 2>/dev/null || true
    if command -v notify-send >/dev/null && [ -n "${DISPLAY:-}" ]; then
        notify-send -a "Secure Boot" "İmzalama tamam" "Kernel/NVIDIA güncellemesi sonrası boot dosyaları imzalandı."
    fi
}

install_pacman_hook() {
    need_root
    local hook_src
    hook_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/secure-boot-sign.hook"
    [ -f "$hook_src" ] || { warn "Hook dosyası yok: $hook_src"; exit 1; }
    mkdir -p /etc/pacman.d/hooks
    command install -Dm644 "$hook_src" /etc/pacman.d/hooks/secure-boot-sign.hook
    msg "Pacman hook kuruldu."
    echo "  linux / nvidia-open / grub güncellenince otomatik: sign-all"
}

prepare() {
    need_root
    install_packages
    reinstall_grub
    create_keys
    sign_all
    msg "Hazırlık bitti. Şimdi: sudo $0 enroll"
}

enroll_mok() {
    need_root
    create_mok_module_keys
    resolve_mok_keys
    local der="/tmp/sbctl-mok.der"
    openssl x509 -in "$MOK_MOD_CERT" -outform DER -out "$der"
    msg "MOK'a NVIDIA modül anahtarı ekleniyor..."
    warn "Şifre belirle — yeniden başlatınca MOK Manager'da onayla."
    if ! mokutil --import "$der"; then
        warn "Import başarısız. Zaten kayıtlı olabilir: mokutil --list-new"
    fi
    rm -f "$der"
    msg "Modülleri MOK anahtarıyla yeniden imzala: sudo $0 sign-all"
}

enroll() {
    need_root
    resolve_keys
    [ -f "$DB_KEY" ] || { warn "Önce prepare çalıştır."; exit 1; }
    msg "Anahtarlar firmware'e kaydediliyor..."
    sbctl enroll-keys -m
    echo
    warn "Firmware kaydı tamam. NVIDIA için ayrı MOK anahtarı:"
    enroll_mok
    if command -v notify-send >/dev/null && [ -n "${DISPLAY:-}" ]; then
        notify-send -a "Secure Boot" "Yeniden başlat" "MOK Manager'da anahtarı onayla"
    fi
}

export_mok_for_bios() {
    need_root
    create_mok_module_keys
    resolve_mok_keys
    local out="/home/${SUDO_USER:-$USER}/MOK-NVIDIA.der"
    openssl x509 -in "$MOK_MOD_CERT" -outform DER -out "$out"
    chown "$SUDO_USER:${SUDO_GID:-$(id -g "$SUDO_USER")}" "$out" 2>/dev/null || chown "$SUDO_USER:" "$out"
    msg "BIOS için anahtar dosyası: $out"
    cat <<'EOF'

Lenovo BIOS — manuel MOK kaydı:
1) Bu dosyayı FAT32 USB'ye kopyala: MOK-NVIDIA.der
2) BIOS (F2) → Security → Secure Boot
3) "Key Management" / "Install Default Keys" yanında
   "Enroll MOK" veya "Append key from file" / "Custom Mode"
4) USB'den MOK-NVIDIA.der seç → onayla
5) Kaydet → reboot

Sonra:
  sudo ~/.config/hypr/scripts/secure-boot-setup.sh sign-all
  nvidia-smi
EOF
}

mok_status() {
    echo "=== MOK durumu ==="
    mokutil --sb-state 2>/dev/null
    echo
    if mokutil --list-new 2>/dev/null | grep -q "Certificate"; then
        echo "⏳ Bekleyen anahtar VAR — henüz onaylanmadı (MOK Manager veya BIOS gerekli)"
    else
        echo "✓ Bekleyen anahtar yok"
    fi
    echo
    if mokutil --list-enrolled 2>/dev/null | grep -qE '^\[key'; then
        echo "✓ Kayıtlı MOK anahtarları var"
    else
        echo "✗ Henüz kayıtlı MOK anahtarı yok (veya mokutil okunamadı)"
    fi
    if mok_cert_is_ca 2>/dev/null; then
        echo "!! MOK dosyası CA:TRUE — modül imzası reddedilir; renew-mok-keys gerekli"
    fi
}

full_install() {
    need_root
    prepare
    echo
    read -r -p "enroll-keys şimdi çalıştırılsın mı? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
        enroll
        echo "Yeniden başlat, MOK'u onayla, test et, sonra BIOS'ta Secure Boot aç."
    else
        echo "Sonra çalıştır: sudo $0 enroll"
    fi
}

case "${1:-guide}" in
    guide) guide ;;
    status) status ;;
    prepare) prepare ;;
    enroll) enroll ;;
    enroll-mok) enroll_mok ;;
    renew-mok-keys) renew_mok_keys ;;
    export-mok) export_mok_for_bios ;;
    mok-status) mok_status ;;
    sign-all) sign_all ;;
    install-hook) install_pacman_hook ;;
    full-install) full_install ;;
    install)
        warn "'install' yerine 'install-hook' veya 'prepare' kullan."
        warn "Pacman hook için: sudo $0 install-hook"
        exit 1
        ;;
    *)
        echo "Kullanım: $0 [guide|status|mok-status|prepare|enroll|enroll-mok|renew-mok-keys|export-mok|sign-all|install-hook|full-install]"
        exit 1
        ;;
esac
