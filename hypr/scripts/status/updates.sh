#!/usr/bin/env bash

threshold_yellow=25
threshold_red=100

json_escape() {
    python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))'
}

if ! command -v checkupdates >/dev/null 2>&1; then
    printf '%s\n' \
        '{"text":"?","alt":"error","tooltip":"pacman-contrib kurulu değil","class":"red"}'
    exit 0
fi

# Pacman başka bir işlem yapıyorsa çakışmamak için kısa süre bekle.
while [[ -e /var/lib/pacman/db.lck ]]; do
    sleep 1
done

repo_output="$(checkupdates --nocolor 2>/dev/null || true)"
aur_output=""

if command -v yay >/dev/null 2>&1; then
    aur_output="$(yay -Qu --aur 2>/dev/null || true)"
fi

count_lines() {
    awk 'NF { count++ } END { print count + 0 }'
}

repo_count="$(printf '%s\n' "$repo_output" | count_lines)"
aur_count="$(printf '%s\n' "$aur_output" | count_lines)"
total=$((repo_count + aur_count))

css_class="green"

if (( total > threshold_red )); then
    css_class="red"
elif (( total > threshold_yellow )); then
    css_class="yellow"
fi

if (( total == 0 )); then
    tooltip="Sistem güncel"
else
    tooltip="Toplam: $total güncelleme\nResmî depolar: $repo_count\nAUR: $aur_count"

    if [[ -n "$repo_output" ]]; then
        tooltip+="\n\nResmî paketler:\n$repo_output"
    fi

    if [[ -n "$aur_output" ]]; then
        tooltip+="\n\nAUR paketleri:\n$aur_output"
    fi
fi

escaped_tooltip="$(printf '%s' "$tooltip" | json_escape)"

printf \
    '{"text":"%s","alt":"%s","tooltip":%s,"class":"%s"}\n' \
    "$total" \
    "$total" \
    "$escaped_tooltip" \
    "$css_class"
