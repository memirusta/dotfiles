#!/usr/bin/env python3
"""Hyprland ayarlar penceresi — GNOME Settings tarzı GTK4/libadwaita arayüzü."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Adw", "1")
gi.require_version("Gtk", "4.0")
from gi.repository import Adw, Gio, GLib, GObject, Gtk

HOME = Path.home()
HYPR = HOME / ".config/hypr"
SCRIPTS = HYPR / "scripts"
SETTINGS = HYPR / "settings"
CAELESTIA = HOME / ".config/caelestia"


def run(*cmd: str) -> None:
    try:
        subprocess.Popen(
            list(cmd),
            env=os.environ.copy(),
            cwd=str(HOME),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def run_script(name: str, *args: str) -> None:
    path = SCRIPTS / name
    if path.is_file():
        try:
            subprocess.Popen(
                ["/bin/bash", str(path), *args],
                env=os.environ.copy(),
                cwd=str(HOME),
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
                close_fds=True,
            )
        except OSError:
            pass


def read_setting(name: str, default: str = "") -> str:
    path = SETTINGS / name
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    return default


def write_setting(name: str, value: str) -> None:
    SETTINGS.mkdir(parents=True, exist_ok=True)
    (SETTINGS / name).write_text(f"{value}\n", encoding="utf-8")


def on_battery() -> bool:
    for pattern in ("AC*/online", "ADP*/online"):
        for path in Path("/sys/class/power_supply").glob(pattern):
            try:
                if path.read_text(encoding="utf-8").strip() == "1":
                    return False
            except OSError:
                continue
    return True


def open_file(path: Path) -> None:
    if shutil_which("cursor"):
        run("cursor", str(path))
    elif shutil_which("code"):
        run("code", str(path))
    else:
        term = read_setting("terminal.sh", "kitty")
        run(term, "-e", "nvim", str(path))


def shutil_which(cmd: str) -> str | None:
    from shutil import which

    return which(cmd)


def power_profile() -> str:
    try:
        out = subprocess.check_output(
            ["powerprofilesctl", "get"], text=True, stderr=subprocess.DEVNULL
        )
        return out.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "?"


def gpu_label() -> str:
    try:
        out = subprocess.check_output(
            [str(SCRIPTS / "gpu-status.sh")], text=True, stderr=subprocess.DEVNULL
        )
        import json

        return json.loads(out).get("text", "?")
    except Exception:
        return "?"


class SettingsApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id="com.memir.hypr-settings",
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        Adw.init()

    def do_activate(self) -> None:
        win = self.props.active_window
        if not win:
            win = SettingsWindow(application=self)
        win.present()


class SettingsWindow(Adw.ApplicationWindow):
    def __init__(self, **kwargs) -> None:
        super().__init__(**kwargs, title="Ayarlar")
        self.set_default_size(920, 660)
        self.set_icon_name("preferences-system")

        self._stack = Gtk.Stack()
        self._stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self._stack.set_transition_duration(180)
        self._stack.set_vexpand(True)
        self._stack.set_hexpand(True)

        self._build_pages()
        self._stack.set_visible_child_name("appearance")

        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL)
        paned.set_resize_start_child(False)
        paned.set_shrink_start_child(False)
        paned.set_position(250)
        paned.set_vexpand(True)
        paned.set_hexpand(True)
        paned.set_start_child(self._build_sidebar())
        paned.set_end_child(self._stack)

        toolbar = Adw.HeaderBar()
        title = Adw.WindowTitle(title="Ayarlar", subtitle="Hyprland · Waybar")
        toolbar.set_title_widget(title)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        box.set_vexpand(True)
        box.set_hexpand(True)
        box.append(toolbar)
        box.append(paned)
        self.set_content(box)

    def _build_sidebar(self) -> Gtk.Widget:
        frame = Gtk.Frame()
        frame.add_css_class("view")
        frame.set_vexpand(True)
        frame.set_hexpand(False)
        frame.set_size_request(250, -1)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)

        listbox = Gtk.ListBox()
        listbox.add_css_class("navigation-sidebar")
        listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)

        self._nav_rows: list[tuple[Gtk.ListBoxRow, str]] = []
        items = [
            ("appearance", "Görünüm", "preferences-desktop-symbolic"),
            ("display", "Ekran", "video-display-symbolic"),
            ("power", "Güç", "battery-level-100-symbolic"),
            ("network", "Ağ ve Bluetooth", "network-wireless-symbolic"),
            ("apps", "Uygulamalar", "applications-system-symbolic"),
            ("system", "Sistem", "emblem-system-symbolic"),
            ("config", "Gelişmiş", "applications-utilities-symbolic"),
        ]

        for i, (key, label, icon) in enumerate(items):
            row = Gtk.ListBoxRow()
            row.set_name(key)
            action = Adw.ActionRow(title=label)
            action.add_prefix(Gtk.Image.new_from_icon_name(icon))
            row.set_child(action)
            listbox.append(row)
            self._nav_rows.append((row, key))
            if i == 0:
                GLib.idle_add(listbox.select_row, row)

        def on_row_selected(_lb: Gtk.ListBox, row: Gtk.ListBoxRow | None) -> None:
            if row:
                self._stack.set_visible_child_name(row.get_name())

        listbox.connect("row-selected", on_row_selected)
        listbox.connect(
            "row-activated",
            lambda _lb, row: self._stack.set_visible_child_name(row.get_name()),
        )

        scrolled.set_child(listbox)
        frame.set_child(scrolled)
        return frame

    def _build_pages(self) -> None:
        self._stack.add_named(self._page_appearance(), "appearance")
        self._stack.add_named(self._page_display(), "display")
        self._stack.add_named(self._page_power(), "power")
        self._stack.add_named(self._page_network(), "network")
        self._stack.add_named(self._page_apps(), "apps")
        self._stack.add_named(self._page_system(), "system")
        self._stack.add_named(self._page_config(), "config")

    def _scrolled_page(self, *groups: Gtk.Widget) -> Gtk.Widget:
        page = Adw.PreferencesPage()
        for g in groups:
            page.add(g)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)
        scrolled.set_hexpand(True)
        scrolled.set_child(page)
        return scrolled

    def _group(self, title: str, description: str = "") -> Adw.PreferencesGroup:
        g = Adw.PreferencesGroup(title=title, description=description)
        return g

    def _action_row(
        self,
        title: str,
        subtitle: str = "",
        icon: str | None = None,
        callback=None,
    ) -> Adw.ActionRow:
        row = Adw.ActionRow(title=title, subtitle=subtitle)
        if icon:
            row.add_prefix(Gtk.Image.new_from_icon_name(icon))
        if callback:
            row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
            row.set_activatable(True)
            row.connect("activated", lambda *_: callback())
        return row

    def _page_appearance(self) -> Gtk.Widget:
        wp = self._group("Duvar kağıdı", "Arka plan ve görsel efektler")
        wp_disabled = SETTINGS / "wallpaper-disabled"

        sw = Gtk.Switch()
        sw.set_active(not wp_disabled.is_file())
        sw.set_valign(Gtk.Align.CENTER)

        self._wp_busy = False

        def on_wp(_sw: Gtk.Switch, _spec: GObject.ParamSpec) -> None:
            if self._wp_busy:
                return
            run_script("wallpaper-toggle.sh")

        wp_row = Adw.ActionRow(title="Duvar kağıdı", subtitle="Kapalıyken siyah ekran")
        wp_row.add_suffix(sw)
        wp_row.set_activatable_widget(sw)
        self._wp_busy = True
        sw.connect("notify::active", on_wp)
        wp_row.connect("map", lambda *_: setattr(self, "_wp_busy", False))
        wp.add(wp_row)

        wp.add(
            self._action_row(
                "Waypaper galerisi",
                "Duvar kağıdı seç veya indir",
                "folder-pictures-symbolic",
                lambda: run_script("waypaper-open.sh"),
            )
        )
        wp.add(
            self._action_row(
                "Rastgele duvar kağıdı",
                icon="media-playlist-shuffle-symbolic",
                callback=lambda: run("waypaper", "--random"),
            )
        )
        wp.add(
            self._action_row(
                "Duvar kağıdı efekti",
                callback=lambda: run_script("wallpaper-effects.sh"),
            )
        )
        wp.add(
            self._action_row(
                "Otomatik değiştir",
                "Belirli aralıklarla rastgele",
                callback=lambda: run_script("wallpaper-automation.sh"),
            )
        )

        fx = self._group("Görünüm", "Animasyon ve Waybar")
        fx.add(
            self._action_row(
                "Hyprshade filtresi",
                "Gece modu / mavi ışık",
                "display-brightness-symbolic",
                lambda: run_script("hyprshade.sh", "rofi"),
            )
        )
        fx.add(
            self._action_row(
                "Animasyonları aç/kapat",
                callback=lambda: run_script("toggle-animations.sh"),
            )
        )
        fx.add(
            self._action_row(
                "Gamemode",
                "Blur ve animasyonları kapatır",
                "applications-games-symbolic",
                lambda: run_script("gamemode.sh"),
            )
        )
        fx.add(
            self._action_row(
                "Caelestia shell'i yeniden başlat",
                callback=lambda: run("sh", "-c", "qs -c caelestia kill; sleep .2; caelestia shell -d"),
            )
        )
        fx.add(
            self._action_row(
                "Dashboard aç / kapat",
                callback=lambda: run("caelestia", "shell", "drawers", "toggle", "dashboard"),
            )
        )

        return self._scrolled_page(wp, fx)

    def _page_display(self) -> Gtk.Widget:
        hz = self._group("Yenileme hızı")

        laptop_combo = Adw.ComboRow(title="Laptop paneli")
        laptop_model = Gtk.StringList.new(["60 Hz — pil", "165 Hz — akıcı"])
        laptop_combo.set_model(laptop_model)
        cur_laptop = read_setting("laptop-refresh-hz", "165")
        laptop_combo.set_selected(0 if cur_laptop == "60" else 1)

        def on_laptop_hz(*_) -> None:
            val = "60" if laptop_combo.get_selected() == 0 else "165"
            write_setting("laptop-refresh-hz", val)
            run_script("refresh-rate.sh", "apply")
            run_script("cursor-refresh.sh", "sync")

        laptop_combo.connect("notify::selected", on_laptop_hz)
        hz.add(laptop_combo)

        ext_combo = Adw.ComboRow(title="Harici monitör (prizde)")
        ext_model = Gtk.StringList.new(
            ["60 Hz", "120 Hz", "144 Hz", "165 Hz", "240 Hz", "300 Hz"]
        )
        ext_combo.set_model(ext_model)
        ext_vals = ["60", "120", "144", "165", "240", "300"]
        cur_ext = read_setting("external-refresh-hz", "300")
        try:
            ext_combo.set_selected(ext_vals.index(cur_ext))
        except ValueError:
            ext_combo.set_selected(5)

        def on_ext_hz(*_) -> None:
            if on_battery():
                return
            write_setting("external-refresh-hz", ext_vals[ext_combo.get_selected()])
            run_script("monitors.sh", "force")

        ext_combo.connect("notify::selected", on_ext_hz)
        if on_battery():
            ext_combo.set_sensitive(False)
            ext_combo.set_subtitle("Pilde otomatik 60 Hz")
        hz.add(ext_combo)

        mon = self._group("Monitör düzeni")
        mon.add(
            self._action_row(
                "Düzeni uygula",
                "Hotplug sonrası konum ve ölçek",
                callback=lambda: run_script("monitors.sh", "force"),
            )
        )
        mon.add(
            self._action_row(
                "Düzelt",
                "Cursor veya Hz sorunlarında",
                callback=lambda: run_script("monitors.sh", "fix"),
            )
        )

        return self._scrolled_page(hz, mon)

    def _page_power(self) -> Gtk.Widget:
        pwr = self._group("Güç profili", "CPU ve platform güç yönetimi")

        combo = Adw.ComboRow(title="Profil")
        model = Gtk.StringList.new(
            ["Güç tasarrufu", "Dengeli", "Performans"]
        )
        combo.set_model(model)
        profiles = ["power-saver", "balanced", "performance"]
        cur = power_profile()
        try:
            combo.set_selected(profiles.index(cur))
        except ValueError:
            combo.set_selected(1)

        def on_profile(*_) -> None:
            idx = combo.get_selected()
            if 0 <= idx < len(profiles):
                run("powerprofilesctl", "set", profiles[idx])

        combo.connect("notify::selected", on_profile)
        pwr.add(combo)

        gpu = self._group("Ekran kartı", "NVIDIA ↔ AMD integrated (yeniden başlatma gerekir)")
        gpu_row = Adw.ActionRow(
            title="GPU modu",
            subtitle=f"Şu an: {gpu_label()} — değiştirmek için tıkla",
        )
        gpu_row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
        gpu_row.set_activatable(True)
        gpu_row.connect("activated", lambda *_: run_script("gpu-switch.sh"))
        gpu.add(gpu_row)

        bat = self._group("Pil")
        state = "Pilde" if on_battery() else "Prize takılı"
        bat.add(
            self._action_row(
                "Pil modunu uygula",
                f"Durum: {state}",
                "battery-level-50-symbolic",
                lambda: run_script(
                    "battery-mode.sh", "battery" if on_battery() else "ac"
                ),
            )
        )

        return self._scrolled_page(pwr, gpu, bat)

    def _page_network(self) -> Gtk.Widget:
        net = self._group("Bağlantılar")
        net.add(
            self._action_row(
                "WiFi ve Bluetooth",
                "Kontrol merkezi",
                "network-wireless-symbolic",
                lambda: run("caelestia", "shell", "drawers", "toggle", "utilities"),
            )
        )
        net.add(
            self._action_row(
                "Bluetooth cihazları",
                "Eşleştir ve bağlan",
                "bluetooth-symbolic",
                lambda: run_script("bt-manager.sh"),
            )
        )
        net.add(
            self._action_row(
                "Ağ ayarları (nmtui)",
                callback=lambda: run("kitty", "--class", "dotfiles-floating", "-e", "nmtui"),
            )
        )
        net.add(
            self._action_row(
                "Bağlantı düzenleyici",
                callback=lambda: run("nm-connection-editor"),
            )
        )
        return self._scrolled_page(net)

    def _page_apps(self) -> Gtk.Widget:
        apps = self._group(
            "Varsayılan uygulamalar",
            "Değişiklikten sonra lua/keybindings.lua ve keybindings-help.tsv dosyalarını güncellemeyi unutma",
        )

        def combo_row(title: str, setting: str, options: list[str]) -> Adw.ComboRow:
            row = Adw.ComboRow(title=title)
            model = Gtk.StringList.new(options)
            row.set_model(model)
            cur = read_setting(setting, options[0])
            try:
                row.set_selected(options.index(cur))
            except ValueError:
                row.set_selected(0)

            def on_change(r: Adw.ComboRow, _p: GObject.ParamSpec) -> None:
                write_setting(setting, options[r.get_selected()])

            row.connect("notify::selected", on_change)
            return row

        apps.add(
            combo_row(
                "Terminal",
                "terminal.sh",
                ["kitty", "alacritty", "foot"],
            )
        )
        apps.add(
            combo_row(
                "Tarayıcı",
                "browser.sh",
                ["google-chrome-stable", "firefox", "chromium", "brave"],
            )
        )
        apps.add(
            combo_row(
                "Dosya yöneticisi",
                "filemanager.sh",
                ["dolphin", "thunar", "nautilus", "pcmanfm-qt"],
            )
        )
        apps.add(
            combo_row(
                "Hesap makinesi",
                "calculator.sh",
                ["gnome-calculator", "qalculate-gtk"],
            )
        )
        apps.add(
            self._action_row(
                "GTK teması uygula",
                callback=lambda: run_script("gtk.sh"),
            )
        )
        return self._scrolled_page(apps)

    def _page_system(self) -> Gtk.Widget:
        sysg = self._group("Hyprland")
        sysg.add(
            self._action_row(
                "Kısayollar",
                "Tüm Super kombinasyonları",
                "input-keyboard-symbolic",
                lambda: run_script("keybindings.sh"),
            )
        )
        sysg.add(
            self._action_row(
                "Config yeniden yükle",
                callback=lambda: run("hyprctl", "reload"),
            )
        )
        sysg.add(
            self._action_row(
                "Uyanık tut (kafein)",
                "Boşta kalma kilidini/uykuyu engelle",
                callback=lambda: run("caelestia", "shell", "idleInhibitor", "toggle"),
            )
        )

        sec = self._group("Güvenlik")
        sec.add(
            self._action_row(
                "Ekran kilidi",
                callback=lambda: run("caelestia", "shell", "lock", "lock"),
            )
        )
        sec.add(
            self._action_row(
                "Secure Boot kurulumu",
                "sudo secure-boot-setup.sh install",
                "security-high-symbolic",
                lambda: run_script("secure-boot-setup.sh", "guide"),
            )
        )

        pwr = self._group("Güç")
        pwr.add(
            self._action_row(
                "Güç menüsü",
                "Kapat, yeniden başlat, uyku",
                "system-shutdown-symbolic",
                lambda: run("caelestia", "shell", "drawers", "toggle", "session"),
            )
        )
        return self._scrolled_page(sysg, sec, pwr)

    def _page_config(self) -> Gtk.Widget:
        cfg = self._group("Yapılandırma dosyaları", "Cursor veya editörde aç")

        files = [
            ("Hyprland ana config", HYPR / "hyprland.lua"),
            ("Kısayollar", HYPR / "lua" / "keybindings.lua"),
            ("Caelestia shell", CAELESTIA / "shell.json"),
            ("Sabitlenmiş uygulamalar", CAELESTIA / "emir.json"),
            ("Monitör script", SCRIPTS / "monitors.sh"),
        ]
        for title, path in files:
            cfg.add(
                self._action_row(
                    title,
                    str(path.relative_to(HOME)),
                    "text-x-generic-symbolic",
                    lambda p=path: open_file(p),
                )
            )
        return self._scrolled_page(cfg)


def main() -> int:
    app = SettingsApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
