#!/usr/bin/env bash
set -euo pipefail

target_workspace="${1:-}"
if [[ -z "$target_workspace" || ! "$target_workspace" =~ ^[0-9]+$ ]]; then
    echo "Kullanım: $0 <çalışma-alanı>" >&2
    exit 2
fi

current_workspace=$(hyprctl activeworkspace -j | jq -r '.id')
mapfile -t addresses < <(
    hyprctl clients -j | jq -r --argjson ws "$current_workspace" '.[] | select(.workspace.id == $ws) | .address'
)

for address in "${addresses[@]}"; do
    code=$(python3 - "$target_workspace" "$address" <<'PY'
import json, sys
print(
    'hl.dsp.window.move({ workspace = %d, follow = false, window = %s })'
    % (int(sys.argv[1]), json.dumps("address:" + sys.argv[2]))
)
PY
)
    hyprctl dispatch "$code" >/dev/null
done

hyprctl dispatch "hl.dsp.focus({ workspace = ${target_workspace} })" >/dev/null
