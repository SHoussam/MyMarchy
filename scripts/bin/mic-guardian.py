#!/usr/bin/env python3
"""
Mic Guardian:
Ensures the microphone is always unmuted on desktop startup, login, and upon waking
from suspend/sleep/hibernate. Subscribes to logind PrepareForSleep signal via D-Bus.
"""

import subprocess
import time
import sys
import gi
from gi.repository import Gio, GLib


def unmute():
    # Allow sound server and hardware codec to settle after wake/boot
    time.sleep(1.2)
    try:
        subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "0"], check=False)
        subprocess.run(
            ["pactl", "set-source-mute",
             "alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source", "0"],
            check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        subprocess.run(["amixer", "-c", "1", "sset", "Dmic0", "cap"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        sys.stderr.write(f"Error unmuting: {e}\n")


def on_sleep_signal(connection, sender_name, object_path, interface_name, signal_name, parameters, user_data):
    if signal_name == "PrepareForSleep":
        try:
            (going_to_sleep,) = parameters.unpack()
            if not going_to_sleep:
                # Waking up from sleep / suspend!
                unmute()
        except Exception as e:
            sys.stderr.write(f"Error handling signal: {e}\n")


def main():
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        bus.signal_subscribe(
            "org.freedesktop.login1",
            "org.freedesktop.login1.Manager",
            "PrepareForSleep",
            "/org/freedesktop/login1",
            None,
            Gio.DBusSignalFlags.NONE,
            on_sleep_signal,
            None
        )
    except Exception as e:
        sys.stderr.write(f"Failed to connect to system bus: {e}\n")
        sys.exit(1)

    # Initial unmute on startup
    unmute()

    loop = GLib.MainLoop()
    try:
        loop.run()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
