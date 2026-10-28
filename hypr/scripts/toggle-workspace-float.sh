#!/usr/bin/env bash
set -euo pipefail

workspace=$(hyprctl activeworkspace -j | jq -r '.id')
state_file="$HOME/.cache/hypr-allfloat-workspace-${workspace}"
action="set"

if [[ -f "$state_file" ]]; then
    action="unset"
    rm -f "$state_file"
else
    mkdir -p "$(dirname "$state_file")"
    touch "$state_file"
fi

mapfile -t addresses < <(
    hyprctl clients -j | jq -r --argjson ws "$workspace" '.[] | select(.workspace.id == $ws) | .address'
)

for address in "${addresses[@]}"; do
    code=$(python3 - "$action" "$address" <<'PY'
import json, sys
print(
    'hl.dsp.window.float({ action = %s, window = %s })'
    % (json.dumps(sys.argv[1]), json.dumps("address:" + sys.argv[2]))
)
PY
)
    hyprctl dispatch "$code" >/dev/null
done
