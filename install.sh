#!/bin/bash
# =============================================================================
# EPIS - Ultimate Vault Kurulum Betiği
# Kullanım: cd ~/dotfiles && ./install.sh
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

echo "EPIS: Ultimate Vault kurulumu başlıyor..."

if [ ! -d "$DOTFILES_DIR/.config" ]; then
    echo "Hata: $DOTFILES_DIR/.config bulunamadı. Scripti dotfiles klasöründen çalıştır."
    exit 1
fi

echo "Mevcut ~/.config yedekleniyor -> $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
for dir in hypr waybar kitty rofi dunst; do
    if [ -d "$HOME/.config/$dir" ]; then
        cp -a "$HOME/.config/$dir" "$BACKUP_DIR/"
    fi
done

echo "Sistem paketleri kuruluyor..."
sudo pacman -S --needed --noconfirm \
    hyprland waybar kitty rofi dunst \
    polkit-gnome hypridle swww mpvpaper mpv wireplumber \
    wl-clipboard grim slurp cliphist \
    thunar pavucontrol brightnessctl pipewire-pulse \
    qt6ct xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    ttf-font-awesome ttf-firacode-nerd ttf-jetbrains-mono-nerd ttf-fira-sans papirus-icon-theme \
    pacman-contrib

if ! command -v brave >/dev/null 2>&1; then
  echo "Brave kurulu değil. AUR'dan kurmak için: yay -S brave-bin"
fi

echo "Konfigürasyon dosyaları yerleştiriliyor..."
mkdir -p "$HOME/.config"/{hypr/scripts,waybar/scripts,kitty,rofi,dunst}
mkdir -p "$HOME/wallpaper"

cp -a "$DOTFILES_DIR/.config/hypr/." "$HOME/.config/hypr/"
cp -a "$DOTFILES_DIR/.config/waybar/." "$HOME/.config/waybar/"
cp -a "$DOTFILES_DIR/.config/kitty/." "$HOME/.config/kitty/"
cp -a "$DOTFILES_DIR/.config/rofi/." "$HOME/.config/rofi/"
cp -a "$DOTFILES_DIR/.config/dunst/." "$HOME/.config/dunst/"

chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null || true
chmod +x "$HOME/.config/waybar/scripts/"*.sh 2>/dev/null || true

if [ ! -f "$HOME/.epis_mode" ]; then
    echo "logical" > "$HOME/.epis_mode"
fi

if [ ! -f "$HOME/wallpaper/default.mp4" ] && [ ! -f "$HOME/wallpaper/default.jpg" ]; then
    echo "Not: ~/wallpaper/default.mp4 veya default.jpg yok."
    echo "     Windows duvar kağıdını şuraya koy: ~/wallpaper/default.mp4"
fi

if systemctl --user is-enabled swaync.service >/dev/null 2>&1 || systemctl --user is-active swaync.service >/dev/null 2>&1; then
    echo "swaync kapatılıyor (dunst ile çakışıyor)..."
    systemctl --user disable --now swaync.service 2>/dev/null || true
    systemctl --user mask swaync.service 2>/dev/null || true
fi

mkdir -p "$HOME/.config/systemd/user"
cp "$DOTFILES_DIR/.config/systemd/user/epis-autostart.service" "$HOME/.config/systemd/user/"
systemctl --user daemon-reload
systemctl --user enable epis-autostart.service

sed -i "s|/home/memir|$HOME|g" "$HOME/.config/hypr/hyprland.conf"

if systemctl is-enabled sddm >/dev/null 2>&1; then
    echo "SDDM zaten etkin. Yeniden başlatınca Hyprland oturumu açılır."
else
    echo "Otomatik giriş için SDDM kur:"
    echo "  sudo pacman -S sddm && sudo systemctl enable --now sddm"
fi

echo ""
echo "Kurulum tamamlandı."
echo "1) reboot"
echo "2) SDDM'de 'Hyprland' oturumunu seç"
echo "3) Giriş yap"
echo ""
echo "Hyprland zaten açıksa: hyprctl reload"
