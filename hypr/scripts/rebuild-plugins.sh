#!/usr/bin/env bash
# Rebuild the Hyprland plugins (hyprbars + aero_snap) against the currently installed Hyprland headers.
#
# Hyprland refuses plugins built for a different build/library set ("Version mismatch"),
# so this runs after every relevant pacman upgrade (see /etc/pacman.d/hooks/hyprland-plugins.hook)
# and can be run by hand at any time:   ~/.config/hypr/scripts/rebuild-plugins.sh
#
# Strategy: build the pinned known-good commit first; if it no longer compiles against new
# headers, try the latest upstream main. On total failure, notify instead of leaving a broken bar.

set -u

SRC="$HOME/.local/src/hyprland-plugins"
OUT="$HOME/.local/lib/hyprland-plugins"
BUILD="$SRC/out"
PINNED="7644cecdb947060682891a0db2a0cdc5c0b9e704"
REPO="https://github.com/hyprwm/hyprland-plugins.git"
LOG="$HOME/.cache/rebuild-plugins.log"

mkdir -p "$OUT" "$(dirname "$LOG")" "$(dirname "$SRC")"
exec >>"$LOG" 2>&1
echo "=== $(date) — Hyprland $(pacman -Q hyprland 2>/dev/null)"

notify() { command -v notify-send >/dev/null && notify-send -a "Hyprland plugins" "$1" "${2:-}" 2>/dev/null; true; }

[ -d "$SRC/.git" ] || git clone "$REPO" "$SRC" || { notify "Plugin rebuild failed" "could not clone $REPO"; exit 1; }

build_at() {
    local rev="$1"
    git -C "$SRC" checkout -q "$rev" 2>/dev/null || return 1
    rm -rf "$BUILD"
    cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null || return 1
    cmake --build "$BUILD" --target hyprbars -j"$(nproc)" >/dev/null || return 1
    # Atomic replace: a running compositor may have the old file mapped.
    install -m755 "$BUILD/hyprbars/libhyprbars.so" "$OUT/hyprbars.so.new" && mv -f "$OUT/hyprbars.so.new" "$OUT/hyprbars.so"
}

RC=0
if build_at "$PINNED"; then
    echo "hyprbars rebuilt from pinned commit ${PINNED:0:7}"
else
    echo "pinned commit failed to build — trying upstream main"
    git -C "$SRC" fetch -q origin || true
    if build_at "origin/main"; then
        echo "hyprbars rebuilt from upstream main"
    else
        notify "hyprbars rebuild failed" "See $LOG — the title bars will be missing until fixed."
        RC=1
    fi
fi

# ---- aero_snap (own plugin, source in ~/.local/src/hypr-aero-snap) ----
AERO="$HOME/.local/src/hypr-aero-snap"
if [ -d "$AERO" ]; then
    rm -rf "$AERO/out"
    if cmake -S "$AERO" -B "$AERO/out" -DCMAKE_BUILD_TYPE=Release >/dev/null &&
        cmake --build "$AERO/out" -j"$(nproc)" >/dev/null &&
        install -m755 "$AERO/out/libaero_snap.so" "$OUT/aero_snap.so.new" && mv -f "$OUT/aero_snap.so.new" "$OUT/aero_snap.so"; then
        echo "aero_snap rebuilt"
    else
        notify "aero_snap rebuild failed" "See $LOG — window snapping will be unavailable until fixed."
        RC=1
    fi
fi
exit $RC
