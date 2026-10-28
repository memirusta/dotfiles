-- Fallback monitor rules. scripts/monitors.sh adjusts these at login/hotplug.
-- Laptop: 1920x1200@165, scale 1.5 | External: 1920x1080@300, scale 1.

hl.monitor({
    output = "desc:N153JMA-G51",
    mode = "1920x1200@165",
    position = "0x0",
    scale = 1.5,
    vrr = 0,
})

hl.monitor({
    output = "desc:25G4S",
    mode = "1920x1080@300",
    position = "1280x0",
    scale = 1,
    vrr = 0,
})

-- Safe fallback for a projector/unknown display.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto-right",
    scale = 1,
})
