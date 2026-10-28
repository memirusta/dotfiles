-- Aero Snap: drag a floating window to a screen edge/corner to snap it (Windows style).
--   left/right edge -> half screen    top edge -> maximize    corners -> quarter
--   dragging a snapped window away restores its previous size
-- Plugin source: ~/.local/src/hypr-aero-snap (rebuilt by scripts/rebuild-plugins.sh)
-- Keyboard / title-bar control: see lua/windows.lua (hl.plugin.aero_snap.*)

hl.plugin.load("/home/memir/.local/lib/hyprland-plugins/aero_snap.so")

hl.config({
    plugin = {
        aero_snap = {
            enabled         = true,
            restore_on_drag = true,

            edge_threshold = 8,    -- px from the screen edge that triggers a snap
            corner_size    = 160,  -- px size of the corner zones (quarter snaps)
            gap            = 0,    -- px between snapped windows and screen/bar edges

            preview_blur         = true,
            preview_rounding     = 10,
            preview_border_size  = 2,
            preview_color        = "rgba(ffffff26)",
            preview_border_color = "rgba(ffffff99)",
            animation_ms         = 160,
        },
    },
})
