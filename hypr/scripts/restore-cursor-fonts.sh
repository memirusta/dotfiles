#!/bin/bash
# Cursor / GTK arayüz fontunu eski haline (Adwaita Sans) döndürür
# Not: Chrome da sistem fontunu kullanır — sadece Cursor için ayrı UI fontu yok

set -euo pipefail

for f in "$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"; do
    [ -f "$f" ] || continue
    sed -i 's/^gtk-font-name=.*/gtk-font-name=Adwaita Sans 11/' "$f"
done

[ -x "$HOME/.config/hypr/scripts/gtk.sh" ] && "$HOME/.config/hypr/scripts/gtk.sh" >/dev/null 2>&1 || true

SETTINGS="$HOME/.config/Cursor/User/settings.json"
python3 - "$SETTINGS" <<'PY'
import json, sys
from pathlib import Path

path = Path(sys.argv[1])
data = {}
if path.exists():
    data = json.loads(path.read_text())

# Cursor/VS Code Linux varsayılanı — editör monospace
defaults = {
    "editor.fontFamily": "'Droid Sans Mono', 'monospace', monospace",
    "editor.fontLigatures": False,
}
for key, value in defaults.items():
    data[key] = value

path.write_text(json.dumps(data, indent=4) + "\n")
print("ok: Cursor settings.json güncellendi")
PY

echo ""
echo "Cursor'u tamamen kapatıp yeniden aç."
echo "Chrome Segoe kalsın istiyorsan gtk-font-name'i 'Segoe UI 11' yap."
