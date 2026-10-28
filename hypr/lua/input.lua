hl.config({
    input = {
        kb_layout = "us,tr",
        kb_variant = ",",
        kb_model = "pc105",
        kb_options = "",
        numlock_by_default = true,
        mouse_refocus = false,
        follow_mouse = 0,
        float_switch_override_focus = 0,
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
            scroll_factor = 1.0,
        },
    },
})

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})
