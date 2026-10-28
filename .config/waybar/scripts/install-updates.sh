#!/bin/bash
term=$(cat "$HOME/.config/hypr/settings/terminal.sh")
$term --class dotfiles-floating -e sudo pacman -Syu
