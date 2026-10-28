#!/usr/bin/env python3
"""BlueZ pairing agent — centered rofi confirmation popup."""

import os
import subprocess
import sys
import time

import dbus
import dbus.exceptions
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/bluez/Agent"
AGENT_IFACE = "org.bluez.Agent1"
ROFI_CFG = os.path.expanduser("~/.config/rofi/config-bt-pair.rasi")
ROFI_FALLBACK = os.path.expanduser("~/.config/rofi/config-compact.rasi")

ACCEPT = "Accept"
REJECT = "Reject"

_recent_pair_ok: dict[str, float] = {}

PROFILE_NAMES = {
    "0000110b-0000-1000-8000-00805f9b34fb": "Media audio",
    "0000110a-0000-1000-8000-00805f9b34fb": "Audio source",
    "0000111f-0000-1000-8000-00805f9b34fb": "Phone calls",
    "0000111e-0000-1000-8000-00805f9b34fb": "Hands-free",
    "0000110e-0000-1000-8000-00805f9b34fb": "Remote control",
    "0000110c-0000-1000-8000-00805f9b34fb": "AVRCP target",
    "00001106-0000-1000-8000-00805f9b34fb": "File transfer (OBEX)",
    "00001105-0000-1000-8000-00805f9b34fb": "OBEX",
}


def profile_label(uuid: str) -> str:
    key = str(uuid).lower()
    if key in PROFILE_NAMES:
        return PROFILE_NAMES[key]
    return "Bluetooth service"


def mark_paired_ok(device: str) -> None:
    _recent_pair_ok[device] = time.time()


def recently_paired_ok(device: str, seconds: float = 20.0) -> bool:
    return (time.time() - _recent_pair_ok.get(device, 0.0)) < seconds


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Rejected"


class Canceled(dbus.DBusException):
    _dbus_error_name = "org.bluez.Error.Canceled"


def device_label(device_path: str) -> str:
    try:
        bus = dbus.SystemBus()
        props = dbus.Interface(
            bus.get_object("org.bluez", device_path),
            "org.freedesktop.DBus.Properties",
        )
        name = props.Get("org.bluez.Device1", "Name")
        address = props.Get("org.bluez.Device1", "Address")
        if name and str(name).strip():
            return f"{name}\n{address}"
        return str(address)
    except Exception:
        return device_path.rsplit("/", 1)[-1]


def notify(title: str, body: str = "") -> None:
    try:
        subprocess.run(
            ["notify-send", "-a", "Bluetooth", "-t", "8000", title, body],
            check=False,
            env=os.environ,
        )
    except Exception:
        pass


def rofi_choice(title: str, message: str) -> str:
    cfg = ROFI_CFG if os.path.isfile(ROFI_CFG) else ROFI_FALLBACK
    subprocess.run(["pkill", "-x", "rofi"], check=False, stderr=subprocess.DEVNULL)

    proc = subprocess.run(
        [
            "rofi",
            "-dmenu",
            "-i",
            "-lines",
            "2",
            "-p",
            title,
            "-mesg",
            message,
            "-config",
            cfg,
        ],
        input=f"{ACCEPT}\n{REJECT}\n",
        capture_output=True,
        text=True,
        env=os.environ.copy(),
    )
    if proc.returncode != 0:
        return ""
    return proc.stdout.strip()


def confirm(title: str, message: str, device: str | None = None) -> None:
    if rofi_choice(title, message) == ACCEPT:
        if device:
            mark_paired_ok(device)
        notify(title, "Accepted")
        return
    notify(title, "Rejected")
    raise Rejected("Rejected")


class Agent(dbus.service.Object):
    def __init__(self, bus: dbus.SystemBus) -> None:
        super().__init__(bus, AGENT_PATH)

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device: str) -> str:
        label = device_label(device)
        if rofi_choice("Bluetooth PIN", f"{label}\n\nEnter this PIN on the other device.") != ACCEPT:
            raise Rejected("Rejected")
        pin = rofi_choice("PIN code", f"{label}\n\nPIN shown on this computer:")
        if not pin or pin == REJECT:
            raise Rejected("Rejected")
        return pin[:16]

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device: str) -> int:
        confirm("Bluetooth pairing", f"{device_label(device)}\n\nPasskey requested.", device)
        return 0

    @dbus.service.method(AGENT_IFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device: str, passkey: int, entered: int) -> None:
        notify("Bluetooth PIN", f"{device_label(device)}\nPIN: {int(passkey):06d}")

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def DisplayPinCode(self, device: str, pincode: str) -> None:
        notify("Bluetooth PIN", f"{device_label(device)}\nPIN: {pincode}")

    @dbus.service.method(AGENT_IFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device: str, passkey: int) -> None:
        label = device_label(device)
        confirm(
            "Bluetooth pairing request",
            f"{label}\n\nPairing code: {int(passkey):06d}\n\nAllow connection?",
            device,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device: str) -> None:
        label = device_label(device)
        confirm(
            "Bluetooth connection request",
            f"{label}\n\nThis device wants to connect.\nProfiles: calls and audio.\n\nAllow?",
            device,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device: str, uuid: str) -> None:
        if recently_paired_ok(device):
            return
        label = device_label(device)
        profile = profile_label(uuid)
        confirm(
            "Bluetooth profile request",
            f"{label}\n\nRequested access:\n• {profile}\n\nAllow?",
            device,
        )

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self) -> None:
        subprocess.run(["pkill", "-x", "rofi"], check=False, stderr=subprocess.DEVNULL)
        raise Canceled("Canceled")


def main() -> int:
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SystemBus()

    manager = dbus.Interface(
        bus.get_object("org.bluez", "/org/bluez"),
        "org.bluez.AgentManager1",
    )

    Agent(bus)
    manager.RegisterAgent(AGENT_PATH, "DisplayYesNo")
    manager.RequestDefaultAgent(AGENT_PATH)

    subprocess.run(
        [os.path.expanduser("~/.config/hypr/scripts/bt-visibility.sh"), "once"],
        check=False,
        env=os.environ,
    )
    subprocess.run(
        [os.path.expanduser("~/.config/hypr/scripts/bt-obex.sh"), "start"],
        check=False,
        env=os.environ,
    )

    notify("Bluetooth", "Pairing agent ready")
    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(0)
