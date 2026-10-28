//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_LOGGING_RULES=qt.text.font.db.info=false

// Emir: end4-pC, desktop widgets only.
// Caelestia owns the bar, notifications, OSD, lock, polkit and launcher, so none of pC's panels are loaded here
// and none of its startup jobs run (no first-run wizard, no wallpaper switching, no autostart apps).
// The background surface is transparent because background.wallpaperPath points at a video
// (~/.config/hypr/cache/emir-transparent.mp4): pC then expects mpvpaper underneath — which is exactly
// what ~/.config/hypr/scripts/wallpaper.sh provides.
// Colours: ~/.local/state/quickshell/user/generated/colors.json, written by caelestia-theme-hook.sh.
//
// Run:  qs -n -d -p ~/.config/quickshell/end4-pC/emir-widgets.qml

import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.ii.background
import qs.modules.ii.desktopMenu

ShellRoot {
    Component.onCompleted: MaterialThemeLoader.reapplyTheme()

    LazyLoader {
        active: Config.ready
        component: Background {}
    }

    LazyLoader {
        active: Config.ready
        component: DesktopMenu {}
    }
}
