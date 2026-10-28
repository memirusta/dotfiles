#!/usr/bin/env bash
# caelestia-cli theme.postHook (see ~/.config/caelestia/cli.json).
# Runs after every scheme change and hands the new colours to the apps Caelestia doesn't theme itself:
#   - end4-pC desktop widgets  (Material colours JSON, hot-reloaded by its FileView)
#   - snappy-switcher (Alt+Tab) theme + live reload

theme_dir="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/theme"

# end4-pC: copy in place (not a symlink) so its file watcher sees the change
if [ -f "$theme_dir/ii-colors.json" ]; then
    out="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/user/generated/colors.json"
    mkdir -p "$(dirname "$out")"
    cat "$theme_dir/ii-colors.json" >"$out"
fi

# snappy-switcher
if [ -f "$theme_dir/snappy-caelestia.ini" ]; then
    mkdir -p "$HOME/.config/snappy-switcher/themes"
    cat "$theme_dir/snappy-caelestia.ini" >"$HOME/.config/snappy-switcher/themes/caelestia.ini"
    pgrep -x snappy-switcher >/dev/null && snappy-switcher --reload-config >/dev/null 2>&1
fi

exit 0
