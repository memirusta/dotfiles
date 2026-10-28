# Noctalia → Caelestia geçişi

```bash
cd ~/dotfiles/caelestia-migration
./install.sh        # yedek alır, paketleri kurar, Caelestia'yı derler, ayarları yerleştirir, canlı geçer
./rollback.sh       # yedekten geri döner, Noctalia'yı başlatır
```

## Ne nerede

| Parça | Kim yapıyor | Dosya |
|---|---|---|
| Bar (dikey, sol) | Caelestia + Emir modülleri | `~/.config/caelestia/shell.json` → `bar.entries` |
| Sabit uygulamalar | Emir `pinnedApps` | `~/.config/caelestia/emir.json` |
| Display grubu / updates / donanım | Emir modülleri, senin `scripts/status/*.sh` scriptlerin | `patches/0001-emir-bar.patch` |
| Launcher, bildirim, OSD, kilit, idle, oturum | Caelestia | `shell.json` |
| Masaüstü widget'ları | end4-pC (sadece arka plan katmanı) | `~/.config/quickshell/end4-pC/emir-widgets.qml`, `~/.config/illogical-impulse/config.json` |
| Alt+Tab | snappy-switcher | `~/.config/snappy-switcher/config.ini` |
| Pano (Super+V) | Vicinae | — |
| Video duvar kağıdı | senin `wallpaper.sh` + mpvpaper | değişmedi, sadece sonunda `caelestia wallpaper` çağırıyor |
| Renkler | caelestia-cli → `theme.postHook` → pC + snappy | `~/.config/caelestia/cli.json`, `hypr/scripts/caelestia-theme-hook.sh` |

## Bar sırası (yukarıdan aşağı)

Arch logosu · sabit uygulamalar · wallpaper/Hz/GPU · — workspaces — · güncellemeler · ses/ağ/BT/pil/klavye · CPU (üstüne gelince RAM + disk) · tray · güç · saat

Sırayı değiştirmek: `shell.json` → `bar.entries` (Caelestia dosyayı kendisi yeniden yükler).

## Yeni / değişen kısayollar

| Kısayol | |
|---|---|
| Alt+Tab / Alt+Shift+Tab | snappy-switcher (küçültülmüş pencereler dahil) |
| Super+V | Vicinae pano geçmişi |
| Super+A | Hızlı ayarlar (eski control center) |
| Super+N | Bildirim paneli |
| Super+Ctrl+B | Dashboard (eskiden bar gizle/göster — Caelestia'da yok) |
| Super+Shift+B | Caelestia'yı yeniden başlat |
| Super+Ctrl+E | Emoji (caelestia emoji, fuzzel) |

Geri kalan her şey aynı.

## Bilinmesi gerekenler

- Caelestia `~/.local/src/caelestia-shell` altında, `emir` dalında, sabit bir commit + bar patch'i olarak derleniyor.
  Güncellemek: `git fetch && git rebase origin/main`, sonra install.sh'teki cmake adımları.
- end4-pC'nin masaüstü sağ tık menüsünden sadece **Widgets** kısmını kullan. "Wallpaper & style" / "Live Wallpaper"
  pC'nin kendi duvar kağıdı scriptini çalıştırır ve mpvpaper'ı öldürür.
- Vicinae'nin kendi teması var, Caelestia renklerini almaz (Vicinae ayarlarından koyu bir tema seç).
