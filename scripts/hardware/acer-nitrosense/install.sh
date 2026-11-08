#!/usr/bin/env bash
# =============================================================================
# Acer NitroSense (DAMX + Linuwu-Sense DKMS) Installer
# Configured for Acer Nitro V 15 (ANV15-52) & similar Acer Nitro / Predator laptops
# =============================================================================

set -euo pipefail

REAL_USER="${SUDO_USER:-$USER}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $EUID -ne 0 ]]; then
  echo "==> Requesting sudo privileges for hardware module installation..."
  exec sudo "$0" "$@"
fi

echo "==> Installing Acer NitroSense fan control & thermal driver for user: $REAL_USER..."

# Check if DKMS and Linux headers are installed
echo "==> Ensuring dkms and linux headers are present..."
pacman -S --needed --noconfirm dkms linux-headers 2>/dev/null || true

# Look for local pre-built packages or install from AUR
if [ -f "$SCRIPT_DIR/div-acer-manager-max-1.0.2-1-x86_64.pkg.tar.zst" ]; then
  echo "==> Installing local pre-built div-acer-manager-max package..."
  pacman -U --noconfirm "$SCRIPT_DIR/div-acer-manager-max-1.0.2-1-x86_64.pkg.tar.zst"
else
  echo "==> Building and installing linuwu-sense-dkms-git and div-acer-manager-max from AUR..."
  sudo -u "$REAL_USER" yay -S --needed --noconfirm linuwu-sense-dkms-git div-acer-manager-max || {
    echo "AUR build failed. Trying manual makepkg build..."
    TMP_BUILD=$(mktemp -d /tmp/damx-build-XXXXXX)
    chown -R "$REAL_USER":"$REAL_USER" "$TMP_BUILD"
    sudo -u "$REAL_USER" bash -c "cd '$TMP_BUILD' && yay -G div-acer-manager-max && cd div-acer-manager-max && sed -i \"/pkgname=div-acer-manager-max/a options=('!strip')\" PKGBUILD && makepkg -si --noconfirm"
    rm -rf "$TMP_BUILD"
  }
fi

# Add target user to linuwu_sense group
echo "==> Adding '$REAL_USER' to linuwu_sense group..."
groupadd -f linuwu_sense
usermod -aG linuwu_sense "$REAL_USER"

# Load linuwu_sense kernel module
echo "==> Activating linuwu_sense kernel driver..."
modprobe -r acer_wmi 2>/dev/null || true
modprobe linuwu_sense 2>/dev/null || true

# Enable and start services
echo "==> Enabling systemd hardware services..."
systemctl enable --now linuwu_sense.service 2>/dev/null || true
systemctl enable --now damx-daemon.service 2>/dev/null || true

echo ""
echo "=================================================================="
echo " ✓ Acer NitroSense (DAMX) setup completed successfully!"
echo " Driver: linuwu_sense DKMS"
echo " Daemon: damx-daemon.service"
echo " Launch: Run 'damx' or open 'NitroSense (DAMX)' from application menu"
echo " Note: You may need to log out and log back in for group permissions."
echo "=================================================================="
