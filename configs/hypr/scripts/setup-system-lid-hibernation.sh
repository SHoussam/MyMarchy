#!/bin/bash
set -euo pipefail

echo "========================================================"
echo "Configuring NVIDIA Power Management & Laptop Lid Behavior"
echo "========================================================"

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root (use sudo)." >&2
  exit 1
fi

echo "[1/3] Enabling NVIDIA power management services..."
systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

echo "[2/3] Writing /etc/systemd/logind.conf.d/30-laptop-lid.conf..."
mkdir -p /etc/systemd/logind.conf.d
cat <<'EOF' > /etc/systemd/logind.conf.d/30-laptop-lid.conf
[Login]
# When running on battery, closing the lid will hibernate to SSD (save state & power off)
HandleLidSwitch=hibernate

# When connected to external AC power, closing the lid is ignored by logind
# Hyprland handles turning off the internal screen for single-screen clamshell mode
HandleLidSwitchExternalPower=ignore

# When connected to external monitor(s) (docked), do not suspend/hibernate
HandleLidSwitchDocked=ignore

# Inhibit delay max to allow screen locker and GPU quiesce to complete
InhibitDelayMaxSec=15
EOF

echo "[3/3] Reloading systemd-logind..."
systemctl kill -s HUP systemd-logind.service

echo ""
echo "Verification:"
echo "--- NVIDIA Services ---"
systemctl is-enabled nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
echo "--- Logind Lid Switch Settings ---"
systemd-analyze cat-config systemd/logind.conf | grep -E "HandleLidSwitch"
echo ""
echo "✓ System configuration completed successfully!"
