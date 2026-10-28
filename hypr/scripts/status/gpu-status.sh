#!/bin/bash
# Aktif GPU modu (waybar)

export PATH="$HOME/.local/bin:/usr/bin:$PATH"

if command -v envycontrol >/dev/null; then
    mode=$(envycontrol -q 2>/dev/null | tr -d '[:space:]')
    case "$mode" in
        nvidia)
            echo '{"text":"󰢮 NV","tooltip":"NVIDIA RTX 5060 — tıkla değiştir","class":"gpu-nvidia"}'
            ;;
        integrated)
            echo '{"text":"󰢮 iGPU","tooltip":"AMD Integrated — harici monitör USB-C ile çalışmayabilir. Tıkla: NVIDIA","class":"gpu-igpu"}'
            ;;
        hybrid)
            echo '{"text":"󰢮 HY","tooltip":"Hybrid — harici monitör destekli. Tıkla değiştir","class":"gpu-hybrid"}'
            ;;
        *)
            echo '{"text":"󰢮 ?","tooltip":"GPU modu bilinmiyor","class":"gpu-unknown"}'
            ;;
    esac
    exit 0
fi

if nvidia-smi >/dev/null 2>&1; then
    echo '{"text":"󰢮 NV","tooltip":"NVIDIA aktif","class":"gpu-nvidia"}'
else
    echo '{"text":"󰢮 iGPU","tooltip":"AMD aktif","class":"gpu-igpu"}'
fi
