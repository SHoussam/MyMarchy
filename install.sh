#!/usr/bin/env bash
# =============================================================================
# MyMarchy - Complete Turnkey Installation Script
# Deploys GlazeWM keybindings, Flow Launcher Universal Search,
# Liquid Glass Dynamic Island with Hardware Telemetry, Touchpad Gestures,
# Laptop Lid Hibernation & Hardware Power Profiles on Arch / Omarchy.
# =============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_APPS="$HOME/.local/share/applications"
LOCAL_PIXMAPS="$HOME/.local/share/pixmaps"
SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
TIMESTAMP="$(date +%s)"

echo "=================================================================="
echo "               Installing MyMarchy Environment                   "
echo "=================================================================="
echo "Target User: $USER"
echo "Repository:  $REPO_DIR"
echo ""

# Helper for safe backup and copy
safe_copy() {
  local src="$1"
  local dst="$2"
  if [ -e "$dst" ]; then
    cp -L "$dst" "${dst}.bak.${TIMESTAMP}"
  fi
  mkdir -p "$(dirname "$dst")"
  cp -rf "$src" "$dst"
  echo "  ✓ Installed: $dst"
}

# 1. Create directory structure
echo "[1/7] Creating required user directories..."
mkdir -p "$CONFIG_DIR/hypr/scripts" \
         "$CONFIG_DIR/omarchy/extensions" \
         "$CONFIG_DIR/omarchy/themes/vantablack" \
         "$CONFIG_DIR/omarchy/plugins" \
         "$CONFIG_DIR/foot" \
         "$SYSTEMD_USER_DIR" \
         "$LOCAL_BIN" \
         "$LOCAL_APPS" \
         "$LOCAL_PIXMAPS"

# 2. Deploy Hyprland Configurations
echo "[2/7] Deploying Hyprland Lua configuration & scripts..."
for file in autostart.lua bindings.lua hyprland.lua hyprsunset.conf input.lua looknfeel.lua monitors.lua xdph.conf; do
  if [ -f "$REPO_DIR/configs/hypr/$file" ]; then
    safe_copy "$REPO_DIR/configs/hypr/$file" "$CONFIG_DIR/hypr/$file"
  fi
done

for script in lid-close-handler.sh setup-system-lid-hibernation.sh; do
  if [ -f "$REPO_DIR/configs/hypr/scripts/$script" ]; then
    safe_copy "$REPO_DIR/configs/hypr/scripts/$script" "$CONFIG_DIR/hypr/scripts/$script"
    chmod +x "$CONFIG_DIR/hypr/scripts/$script"
  fi
done

# 3. Deploy Omarchy & Dynamic Island
echo "[3/7] Deploying Omarchy shell, menu extensions, themes & Dynamic Island..."
safe_copy "$REPO_DIR/configs/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
safe_copy "$REPO_DIR/configs/omarchy/shell.toml" "$CONFIG_DIR/omarchy/shell.toml"
safe_copy "$REPO_DIR/configs/omarchy/dynamic-island.json" "$CONFIG_DIR/omarchy/dynamic-island.json"
safe_copy "$REPO_DIR/configs/omarchy/extensions/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
safe_copy "$REPO_DIR/configs/omarchy/themes/vantablack/colors.toml" "$CONFIG_DIR/omarchy/themes/vantablack/colors.toml"

# Deploy customized Dynamic Island with hardware stats
safe_copy "$REPO_DIR/configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island" "$CONFIG_DIR/omarchy/plugins/io.github.ofa14-prog.dynamic-island"
chmod +x "$CONFIG_DIR/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-hardware"

# Ensure upstream companion plugins exist
if [ ! -d "$CONFIG_DIR/omarchy/plugins/io.github.hominluo.launcher" ]; then
  echo "  -> Cloning launcher plugin..."
  git clone --depth 1 https://github.com/hominluo/omarchy-launcher.git "$CONFIG_DIR/omarchy/plugins/io.github.hominluo.launcher" 2>/dev/null || true
fi

if [ ! -d "$CONFIG_DIR/omarchy/plugins/lobo.islands" ]; then
  echo "  -> Cloning Islands status bar plugin..."
  git clone --depth 1 https://github.com/DanielLob-o/Islands.git "$CONFIG_DIR/omarchy/plugins/lobo.islands" 2>/dev/null || true
fi

# 4. Deploy Foot Terminal configuration
echo "[4/7] Deploying Foot terminal configuration..."
safe_copy "$REPO_DIR/configs/foot/foot.ini" "$CONFIG_DIR/foot/foot.ini"

# 5. Deploy Custom Binaries, Scripts & Desktop Entries
echo "[5/7] Deploying custom utilities and application entries..."
for bin_file in "$REPO_DIR/scripts/bin"/*; do
  if [ -f "$bin_file" ]; then
    fname="$(basename "$bin_file")"
    safe_copy "$bin_file" "$LOCAL_BIN/$fname"
    chmod +x "$LOCAL_BIN/$fname"
  fi
done

for desktop in "$REPO_DIR/desktop-entries"/*.desktop; do
  if [ -f "$desktop" ]; then
    fname="$(basename "$desktop")"
    safe_copy "$desktop" "$LOCAL_APPS/$fname"
  fi
done

if [ -f "$REPO_DIR/pixmaps/sklauncher.png" ]; then
  safe_copy "$REPO_DIR/pixmaps/sklauncher.png" "$LOCAL_PIXMAPS/sklauncher.png"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$LOCAL_APPS" 2>/dev/null || true
fi

# 6. Deploy and enable user Systemd services
echo "[6/7] Setting up user systemd services..."
safe_copy "$REPO_DIR/configs/systemd/user/unmute-microphone.service" "$SYSTEMD_USER_DIR/unmute-microphone.service"
systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now unmute-microphone.service 2>/dev/null || true

# 7. System-level setup prompt (Lid Hibernation & NVIDIA Power)
echo "[7/7] Checking system-level configurations..."
if [[ "${1:-}" == "--with-system" ]] || [[ $EUID -eq 0 ]]; then
  echo "  -> Installing /etc/systemd/logind.conf.d/30-laptop-lid.conf..."
  sudo mkdir -p /etc/systemd/logind.conf.d
  sudo cp "$REPO_DIR/configs/systemd/system/30-laptop-lid.conf" /etc/systemd/logind.conf.d/30-laptop-lid.conf
  sudo systemctl kill -s HUP systemd-logind.service 2>/dev/null || true
  sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true
  echo "  ✓ System lid hibernation configured."
else
  echo "  Tip: Run 'sudo bash configs/hypr/scripts/setup-system-lid-hibernation.sh' to configure laptop lid SSD hibernation & NVIDIA power services."
fi

# Reload Hyprland if active
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
  echo "==> Reloading Hyprland configuration..."
  hyprctl reload >/dev/null 2>&1 || true
fi

echo ""
echo "=================================================================="
echo "          ✓ MyMarchy Installation Complete!                       "
echo "=================================================================="
echo "Shortcuts summary:"
echo "  • Shift + Space         : Universal Flow Launcher Search"
echo "  • Alt + Enter           : Open Foot Terminal"
echo "  • Alt + Shift + Q       : Close Window"
echo "  • Ctrl + Shift + Esc    : Task Manager (btop)"
echo "  • Super + Shift + S     : Region Screenshot (omasnap)"
echo "  • Super + W             : Emergency Process Killer"
echo "  • 2-Finger Pinch        : Live Desktop Zoom"
echo "  • 3-Finger Horizontal   : Scroll/Travel Applications"
echo "  • 3-Finger Vertical     : Drag/Move Active Window"
echo "  • 4-Finger Horizontal   : Switch Workspaces"
echo "=================================================================="
