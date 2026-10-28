#!/usr/bin/env bash
# install.sh'in yaptığını geri alır: hypr/quickshell/snappy/illogical-impulse ayarlarını yedekten döndürür,
# Caelestia'yı kapatıp Noctalia'yı başlatır. Kurulan paketlere dokunmaz.
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
BACKUP="${1:-$(cat "$HOME/.config-backups/caelestia-migration-latest" 2>/dev/null || true)}"

[ -n "$BACKUP" ] && [ -d "$BACKUP" ] || { echo "Yedek bulunamadı. Kullanım: $0 [yedek-klasörü]" >&2; exit 1; }
echo ":: Geri dönülüyor: $BACKUP"

qs -c caelestia kill 2>/dev/null || true
pkill -f emir-widgets.qml 2>/dev/null || true
pkill -x snappy-switcher 2>/dev/null || true
pkill -x vicinae 2>/dev/null || true

for d in hypr caelestia quickshell snappy-switcher illogical-impulse; do
    rm -rf "${CFG:?}/$d"
    [ -e "$BACKUP/$d" ] && cp -a "$BACKUP/$d" "$CFG/"
done
if [ -d "$BACKUP/state/quickshell" ]; then
    rm -rf "${STATE:?}/quickshell"
    cp -a "$BACKUP/state/quickshell" "$STATE/"
fi

hyprctl reload >/dev/null || true
command -v noctalia >/dev/null && (noctalia --daemon &>/dev/null & disown)
echo ":: Tamam. Caelestia'nın derlenmiş eklentisi /usr/lib/qt6/qml/Caelestia altında duruyor, zararsız."
