#!/usr/bin/env bash

if command -v yay >/dev/null 2>&1; then
    exec kitty --class dotfiles-floating -e yay -Syu
else
    exec kitty --class dotfiles-floating -e sudo pacman -Syu
fi
