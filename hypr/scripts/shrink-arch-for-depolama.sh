#!/bin/bash
# Arch (nvme0n1p3) 200G → 100G; sağda ~100G unallocated bırakır (sonra GParted ile D:'ye).
# Kullanım: sudo ~/.config/hypr/scripts/shrink-arch-for-depolama.sh

set -euo pipefail

DISK=/dev/nvme0n1
PART=/dev/nvme0n1p3
PARTNUM=3
TARGET_FS=100G
# p3 start=444416; 100GiB = 209715200 sektör → end = 444416+209715200-1
NEW_END_SECTOR=210159615
BACKUP_DIR="/home/memir/.config/hypr/backup"
BACKUP="$BACKUP_DIR/nvme0n1-partition-table-$(date +%Y%m%d-%H%M%S).txt"

msg() { printf '==> %s\n' "$*"; }
warn() { printf '!! %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

[ "$(id -u)" -eq 0 ] || die "sudo gerekli"

msg "Bölüm tablosu yedekleniyor → $BACKUP"
mkdir -p "$BACKUP_DIR"
sfdisk -d "$DISK" > "$BACKUP"
chown memir:memir "$BACKUP" 2>/dev/null || true

msg "Mevcut durum:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
echo
btrfs filesystem show "$PART"
df -h /

USED_G=$(btrfs filesystem usage -b / | awk '/Used:/{print int($2/1024/1024/1024); exit}')
[ "${USED_G:-999}" -lt 90 ] || die "Kullanım ~${USED_G}G — 100G'ye sığmayabilir, iptal."

msg "btrfs → $TARGET_FS (online shrink)..."
btrfs filesystem resize "$TARGET_FS" /
sync
btrfs filesystem show "$PART"
df -h /

msg "Bölüm $PARTNUM sonu → sektör $NEW_END_SECTOR (~100GiB)..."
# Mounted partition: parted -s bile onay ister → pretend-input-tty
printf 'Yes\nYes\n' | parted ---pretend-input-tty "$DISK" unit s resizepart "$PARTNUM" "${NEW_END_SECTOR}s"
partprobe "$DISK" 2>/dev/null || true
sleep 1
# Çekirdek tabloyu yenilemezse:
partx -u "$PART" 2>/dev/null || true
blockdev --rereadpt "$DISK" 2>/dev/null || true

msg "Dosya sistemi yeni bölüme oturtuluyor..."
btrfs filesystem resize max / || warn "resize max atlandı (zaten tam olabilir)"
sync

echo
msg "Tamam. Yeni düzen:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DISK"
echo
sfdisk -d "$DISK" | grep -E "nvme0n1p3|nvme0n1p4"
df -h /

cat <<'EOF'

Sonraki adım — D: (Depolama) büyütmek için GParted canlı USB:

1) GParted Live USB ile boot (Secure Boot: imzalı GParted veya geçici SB kapat)
2) Sıra (soldan sağa, birer birer uygula):
   a) ntfs (C:, ~344G) → sola kaydır (Move/Resize), soldaki boşluğu doldur
   b) ntfs recovery (~816M) → sola kaydır
   c) Depolama (D:) → sola genişlet (+~100G)
3) Apply → bitince reboot → Windows → D: boyutunu kontrol et

UYARI: C: kaydırma uzun sürer; kesme / uyku yok. Bitmeden kapatma.

Yedek tablo: ~/.config/hypr/backup/nvme0n1-partition-table-*.txt
EOF
