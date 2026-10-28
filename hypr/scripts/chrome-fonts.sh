#!/bin/bash
# Chrome web fontlarını Windows varsayılanlarına yaklaştırır (Chrome kapalıyken çalıştır)

UI_FONT="Segoe UI"
SERIF_FONT="Liberation Serif"
MONO_FONT="CaskaydiaCove Nerd Font Mono"
DEFAULT_SIZE=16
FIXED_SIZE=13

SCRIPTS=(Arab Deva Grek Hang Hani Hebr Jpan Knda Khmr Kore Laoo Mlym Mymr Orya Sinh Taml Telu Thaa Thai Tibt Yiii Zyyy)

if pgrep -x chrome >/dev/null || pgrep -f google-chrome >/dev/null; then
    echo "Chrome açık — kapatıp tekrar çalıştır: $0"
    exit 1
fi

python3 - "$UI_FONT" "$SERIF_FONT" "$MONO_FONT" "$DEFAULT_SIZE" "$FIXED_SIZE" "${SCRIPTS[@]}" <<'PY'
import json, sys, glob
from pathlib import Path

ui, serif, mono = sys.argv[1:4]
default_size, fixed_size = int(sys.argv[4]), int(sys.argv[5])
scripts = sys.argv[6:]

profiles = glob.glob(str(Path.home() / ".config/google-chrome/*/Preferences"))
profiles += glob.glob(str(Path.home() / ".config/google-chrome/Profile */Preferences"))

for path in sorted(set(profiles)):
    p = Path(path)
    if not p.is_file():
        continue
    try:
        data = json.loads(p.read_text())
    except (json.JSONDecodeError, OSError):
        continue

    webprefs = data.setdefault("webkit", {}).setdefault("webprefs", {})
    webprefs["default_font_size"] = default_size
    webprefs["default_fixed_font_size"] = fixed_size
    webprefs["minimum_font_size"] = 0

    fonts = webprefs.setdefault("fonts", {})
    for group, family in (
        ("standard", ui),
        ("sansserif", ui),
        ("serif", serif),
        ("fixed", mono),
    ):
        bucket = fonts.setdefault(group, {})
        for script in scripts:
            bucket[script] = family

    p.write_text(json.dumps(data, separators=(",", ":")))
    print(f"ok: {p.parent.name}")
PY

fc-cache -f >/dev/null 2>&1 || true
