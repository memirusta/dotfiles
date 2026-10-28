#!/bin/bash
# RTX 5060 <-> AMD integrated (envycontrol)

export PATH="$HOME/.local/bin:/usr/bin:$PATH"
ENVYCONTROL="/home/memir/.local/bin/envycontrol"
ROOT_HELPER="$HOME/.config/hypr/scripts/gpu-switch-root.sh"
[ -x /usr/bin/envycontrol ] && ENVYCONTROL="/usr/bin/envycontrol"

notify() {
    notify-send -a "GPU Switch" -t 12000 "$1" "$2"
}

if [ ! -x "$ENVYCONTROL" ]; then
    notify "Kurulum gerekli" "envycontrol bulunamadı."
    exit 1
fi

current=$("$ENVYCONTROL" -q 2>/dev/null | tr -d '[:space:]')
[ -z "$current" ] && current="unknown"

case "$current" in
    integrated)
        next=nvidia
        label="NVIDIA RTX 5060"
        ;;
    nvidia)
        next=integrated
        label="AMD Integrated"
        ;;
    hybrid)
        next=nvidia
        label="NVIDIA RTX 5060"
        ;;
    *)
        next=nvidia
        label="NVIDIA RTX 5060"
        ;;
esac

if ! sudo -n -E "$ROOT_HELPER" "$next" 2>/tmp/gpu-switch.err; then
    err=$(tail -3 /tmp/gpu-switch.err 2>/dev/null)
    notify "GPU geçişi başarısız" "${err:-Bilinmeyen hata}

Önce: sudo $HOME/.config/hypr/scripts/gpu-sudo-setup.sh"
    exit 1
fi

notify "GPU → $label" "Önceki: $current → $next

Lütfen bilgisayarı yeniden başlat.

Not: Harici monitör (USB-C/DP) genelde yalnızca NVIDIA veya Hybrid modda çalışır."
