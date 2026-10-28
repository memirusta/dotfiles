#!/usr/bin/env python3
"""OBEX incoming file transfer agent — centered Accept/Reject popup."""

import os
import subprocess

import dbus
import dbus.exceptions
import dbus.mainloop.glib
import dbus.service
from gi.repository import GLib

AGENT_PATH = "/org/bluez/obex/Agent"
AGENT_IFACE = "org.bluez.obex.Agent1"
ROFI_CFG = os.path.expanduser("~/.config/rofi/config-bt-pair.rasi")
ROFI_FALLBACK = os.path.expanduser("~/.config/rofi/config-compact.rasi")
RECEIVE_DIR = os.path.expanduser("~/Downloads/Bluetooth")

ACCEPT = "Accept"
REJECT = "Reject"


class Rejected(dbus.DBusException):
    _dbus_error_name = "org.bluez.obex.Error.Rejected"


def ensure_receive_dir() -> str:
    os.makedirs(RECEIVE_DIR, exist_ok=True)
    return RECEIVE_DIR


def rofi_confirm(title: str, message: str) -> bool:
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
    return proc.returncode == 0 and proc.stdout.strip() == ACCEPT


class ObexAgent(dbus.service.Object):
    def __init__(self, bus: dbus.SessionBus) -> None:
        super().__init__(bus, AGENT_PATH)

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Release(self) -> None:
        pass

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="s")
    def RequestAuthorization(self, device: str) -> str:
        folder = ensure_receive_dir()
        name = str(device).rsplit("/", 1)[-1]
        if not rofi_confirm(
            "Incoming Bluetooth file",
            f"Device: {name}\n\nAccept incoming file transfer?\nSave to: {folder}",
        ):
            raise Rejected("Rejected")
        return folder

    @dbus.service.method(AGENT_IFACE, in_signature="o", out_signature="")
    def AuthorizePush(self, device: str) -> None:
        name = str(device).rsplit("/", 1)[-1]
        if not rofi_confirm(
            "Incoming Bluetooth file",
            f"Device: {name}\n\nAccept file push?",
        ):
            raise Rejected("Rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="os", out_signature="")
    def AuthorizeTransfer(self, transfer: str, filename: str) -> None:
        folder = ensure_receive_dir()
        if not rofi_confirm(
            "Incoming Bluetooth file",
            f"File: {filename}\n\nSave to:\n{folder}",
        ):
            raise Rejected("Rejected")

    @dbus.service.method(AGENT_IFACE, in_signature="", out_signature="")
    def Cancel(self) -> None:
        subprocess.run(["pkill", "-x", "rofi"], check=False, stderr=subprocess.DEVNULL)


def main() -> int:
    ensure_receive_dir()
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.SessionBus()

    try:
        manager = dbus.Interface(
            bus.get_object("org.bluez.obex", "/org/bluez/obex"),
            "org.bluez.obex.AgentManager1",
        )
    except dbus.DBusException:
        return 1

    ObexAgent(bus)
    manager.RegisterAgent(AGENT_PATH)
    manager.RequestDefaultAgent(AGENT_PATH)

    GLib.MainLoop().run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
