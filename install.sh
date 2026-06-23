#!/bin/bash
# =============================================================================
# EPIS - Ultimate Vault (Legion 5 - RTX 5060) Otomatik Kurulum Betiği
# =============================================================================

echo "🧠 EPIS: Ultimate Vault inşası başlatılıyor..."
sleep 2

# 1. Sistemin Tamamen Güncellenmesi
echo "📦 Sistem paketleri güncelleniyor..."
sudo pacman -Syu --noconfirm

# 2. Temel Arch/Wayland Paketlerinin Kurulumu
echo "⚙️ Çekirdek bileşenler, Wayland ve UI araçları kuruluyor..."
sudo pacman -S --noconfirm \
    hyprland waybar kitty rofi-wayland dunst \
    polkit-gnome hypridle swww \
    wl-clipboard grim slurp \
    brave-browser thunar ttf-font-awesome \
    pavucontrol brightnessctl pipewire-pulse

# 3. Klasör Hiyerarşisinin Oluşturulması ve Kopyalama
echo "📂 Temiz .config dizinleri oluşturuluyor..."
mkdir -p ~/.config/{hypr,waybar,kitty,rofi,dunst}
mkdir -p ~/.config/waybar/scripts

echo "🔄 Konfigürasyon dosyaları yerleştiriliyor..."
# (Bu scripti dotfile klasörünün içinden çalıştırdığını varsayıyoruz)
cp -r hypr/* ~/.config/hypr/
cp -r waybar/* ~/.config/waybar/
cp -r kitty/* ~/.config/kitty/
# Eğer rofi ve dunst için de kendi temiz ayarların varsa buraya eklenecek.

# 4. EPIS Scriptlerine Çalıştırma İzni Verilmesi
echo "🔑 EPIS Zihin Modu yöneticilerine yetki veriliyor..."
chmod +x ~/.config/waybar/scripts/epis_status.sh
chmod +x ~/.config/waybar/scripts/epis_toggle.sh

echo "✅ Kurulum Tamamlandı! Sistemi yeniden başlatın (reboot) veya 'Hyprland' yazarak arayüze geçin."