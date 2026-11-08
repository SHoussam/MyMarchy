#!/bin/bash
# Handles laptop lid close event dynamically based on power source

# Check if running on external AC power
if omarchy-power-present; then
  # Plugged in: Do not sleep or hibernate.
  # If external monitor is connected, clamshell mode will turn off internal display eDP-1.
  if omarchy-hw-external-monitors; then
    omarchy-hyprland-monitor-clamshell
  else
    # Plugged in with no external display: lock and turn off internal display via DPMS
    omarchy-system-lock >/dev/null 2>&1 || true
    hyprctl dispatch dpms off >/dev/null 2>&1 || true
  fi
else
  # On battery: hibernate directly to SSD (save entire session and power off)
  # Lock screen first so on resume the session is password-protected
  omarchy-system-lock >/dev/null 2>&1 || true
  systemctl hibernate
fi
