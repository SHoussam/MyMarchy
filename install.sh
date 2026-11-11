#!/usr/bin/env bash
# =============================================================================
# MyMarchy - Complete Turnkey Installation Script
# Deploys GlazeWM + Universal Phone Back + 60%/100% Keyboard Collaboration,
# Flow Launcher Universal Search, Liquid Glass Dynamic Island (Telemetry,
# OpenCode/LM Studio, KDE Connect Phones, Surface Recovery Companion App),
# RNNoise Microphone Noise Cancellation + Mic Guardian, Micro Default Editor,
# Touchpad Gestures, Laptop Lid Hibernation & Hardware Power Profiles.
# =============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_APPS="$HOME/.local/share/applications"
LOCAL_PIXMAPS="$HOME/.local/share/pixmaps"
LOCAL_MIME_DIR="$HOME/.local/share/mime"
SYSTEMD_USER_DIR="$CONFIG_DIR/systemd/user"
TIMESTAMP="$(date +%s)"
BACKUP_ROOT="$HOME/.local/state/mymarchy-backups/$TIMESTAMP"

echo "=================================================================="
echo "               Installing MyMarchy Environment                   "
echo "=================================================================="
echo "Target User: $USER"
echo "Repository:  $REPO_DIR"
echo "Backups:     $BACKUP_ROOT"
echo ""

# Helper for safe backup and copy (handles both files and directories cleanly
# without leaving .bak.* files inside config/plugin/systemd scan directories)
safe_copy() {
  local src="$1"
  local dst="$2"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    local rel="${dst#"$HOME"/}"
    local bak="$BACKUP_ROOT/$rel"
    mkdir -p "$(dirname "$bak")"
    cp -aL "$dst" "$bak" 2>/dev/null || cp -a "$dst" "$bak"
  fi

  mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
  else
    cp -f "$src" "$dst"
  fi
  echo "  ✓ Installed: $dst"
}

# 1. Create directory structure
echo "[1/8] Creating required user directories..."
mkdir -p "$CONFIG_DIR/hypr/scripts" \
         "$CONFIG_DIR/omarchy/assets" \
         "$CONFIG_DIR/omarchy/extensions" \
         "$CONFIG_DIR/omarchy/themes/vantablack" \
         "$CONFIG_DIR/omarchy/plugins" \
         "$CONFIG_DIR/foot" \
         "$CONFIG_DIR/ghostty" \
         "$CONFIG_DIR/fastfetch" \
         "$CONFIG_DIR/pipewire/mic-noise-cancellation.conf.d" \
         "$CONFIG_DIR/wireplumber/scripts/device" \
         "$SYSTEMD_USER_DIR" \
         "$LOCAL_BIN" \
         "$LOCAL_APPS" \
         "$LOCAL_PIXMAPS" \
         "$LOCAL_MIME_DIR/packages"

# 2. Deploy Hyprland Configurations
echo "[2/8] Deploying Hyprland Lua configuration & scripts..."
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

# 3. Deploy Omarchy, Dynamic Island Plugin & Companion App
echo "[3/8] Deploying Omarchy shell, menu extensions, branding & Dynamic Island..."
safe_copy "$REPO_DIR/configs/omarchy/shell.json" "$CONFIG_DIR/omarchy/shell.json"
safe_copy "$REPO_DIR/configs/omarchy/shell.toml" "$CONFIG_DIR/omarchy/shell.toml"
safe_copy "$REPO_DIR/configs/omarchy/dynamic-island.json" "$CONFIG_DIR/omarchy/dynamic-island.json"
safe_copy "$REPO_DIR/configs/omarchy/extensions/omarchy-menu.jsonc" "$CONFIG_DIR/omarchy/extensions/omarchy-menu.jsonc"
safe_copy "$REPO_DIR/configs/omarchy/themes/vantablack/colors.toml" "$CONFIG_DIR/omarchy/themes/vantablack/colors.toml"

if [ -f "$REPO_DIR/pixmaps/hs_logo.png" ]; then
  safe_copy "$REPO_DIR/pixmaps/hs_logo.png" "$CONFIG_DIR/omarchy/assets/hs_logo.png"
  safe_copy "$REPO_DIR/pixmaps/hs_logo.png" "$LOCAL_PIXMAPS/hs_logo.png"
fi

if [ -d "$REPO_DIR/configs/omarchy/plugins/hous.menu" ]; then
  safe_copy "$REPO_DIR/configs/omarchy/plugins/hous.menu" "$CONFIG_DIR/omarchy/plugins/hous.menu"
fi

# Deploy customized Dynamic Island plugin (Hardware telemetry, OpenCode/LM Studio, KDE Connect phones, SurfaceHost)
safe_copy "$REPO_DIR/configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island" "$CONFIG_DIR/omarchy/plugins/io.github.ofa14-prog.dynamic-island"
chmod +x "$CONFIG_DIR/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/"*

# Build & install native Qt6 Dynamic Island control/recovery companion app
if [ -d "$REPO_DIR/apps/dynamic-island" ]; then
  if command -v qmake6 >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
    echo "  -> Building Dynamic Island Qt6 companion app..."
    bash "$REPO_DIR/apps/dynamic-island/bin/install-local"
  else
    echo "  ! Skipping dynamic-island companion build (qmake6 / make not found; install qt6-base qt6-declarative qt6-wayland base-devel)"
  fi
fi

# Ensure upstream companion plugins exist
if [ ! -d "$CONFIG_DIR/omarchy/plugins/io.github.hominluo.launcher" ]; then
  echo "  -> Cloning launcher plugin..."
  git clone --depth 1 https://github.com/hominluo/omarchy-launcher.git "$CONFIG_DIR/omarchy/plugins/io.github.hominluo.launcher" 2>/dev/null || true
fi

if [ ! -d "$CONFIG_DIR/omarchy/plugins/lobo.islands" ]; then
  echo "  -> Cloning Islands status bar plugin..."
  git clone --depth 1 https://github.com/DanielLob-o/Islands.git "$CONFIG_DIR/omarchy/plugins/lobo.islands" 2>/dev/null || true
fi

# 4. Deploy Terminal, Prompt & Fastfetch Configurations
echo "[4/8] Deploying Foot, Ghostty, Starship & Fastfetch configurations..."
safe_copy "$REPO_DIR/configs/foot/foot.ini" "$CONFIG_DIR/foot/foot.ini"
safe_copy "$REPO_DIR/configs/ghostty/config" "$CONFIG_DIR/ghostty/config"
safe_copy "$REPO_DIR/configs/starship.toml" "$CONFIG_DIR/starship.toml"
safe_copy "$REPO_DIR/configs/fastfetch/config.jsonc" "$CONFIG_DIR/fastfetch/config.jsonc"
safe_copy "$REPO_DIR/configs/fastfetch/hs_logo.txt" "$CONFIG_DIR/fastfetch/hs_logo.txt"

if [ -f "$HOME/.bashrc" ] && ! grep -qE "MyMarchy Environment|Houssam's Local Paths" "$HOME/.bashrc"; then
  {
    echo ""
    cat "$REPO_DIR/configs/bash/bashrc.additions"
  } >> "$HOME/.bashrc"
  echo "  ✓ Appended MyMarchy additions to: $HOME/.bashrc"
fi

# 5. Deploy Audio (RNNoise + WirePlumber) & Micro Text/Markdown MIME Defaults
echo "[5/8] Deploying PipeWire RNNoise filter, WirePlumber input guard & Micro MIME defaults..."
safe_copy "$REPO_DIR/configs/pipewire/mic-noise-cancellation.conf" "$CONFIG_DIR/pipewire/mic-noise-cancellation.conf"
safe_copy "$REPO_DIR/configs/pipewire/mic-noise-cancellation.conf.d/90-rnnoise-mic.conf" "$CONFIG_DIR/pipewire/mic-noise-cancellation.conf.d/90-rnnoise-mic.conf"
safe_copy "$REPO_DIR/configs/wireplumber/scripts/device/state-routes.lua" "$CONFIG_DIR/wireplumber/scripts/device/state-routes.lua"

safe_copy "$REPO_DIR/configs/mime/user-text-extension.xml" "$LOCAL_MIME_DIR/packages/user-text-extension.xml"
if command -v update-mime-database >/dev/null 2>&1; then
  update-mime-database "$LOCAL_MIME_DIR" 2>/dev/null || true
fi

# 6. Deploy Custom Binaries, Scripts & Desktop Entries
echo "[6/8] Deploying custom utilities and application entries..."
for bin_file in "$REPO_DIR/scripts/bin"/*; do
  if [ -f "$bin_file" ]; then
    fname="$(basename "$bin_file")"
    safe_copy "$bin_file" "$LOCAL_BIN/$fname"
    chmod +x "$LOCAL_BIN/$fname"
  fi
done
ln -sf "$LOCAL_BIN/omarchy-toggle-focus-mode" "$LOCAL_BIN/focus-mode"
echo "  ✓ Linked: $LOCAL_BIN/focus-mode -> omarchy-toggle-focus-mode"

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

if command -v xdg-mime >/dev/null 2>&1; then
  xdg-mime default micro.desktop text/plain text/markdown text/x-markdown 2>/dev/null || true
  echo "  ✓ Set micro.desktop as default for .txt, .text & .md"
fi

# 7. Deploy and enable user Systemd services
echo "[7/8] Setting up user systemd services..."
# Retire legacy one-shot unmute service if present
systemctl --user disable --now unmute-microphone.service 2>/dev/null || true
rm -f "$SYSTEMD_USER_DIR/unmute-microphone.service"

for unit in mic-guardian.service mic-noise-cancellation.service kdeconnect-indicator.service kdeconnect-sftp-automount.service; do
  if [ -f "$REPO_DIR/configs/systemd/user/$unit" ]; then
    safe_copy "$REPO_DIR/configs/systemd/user/$unit" "$SYSTEMD_USER_DIR/$unit"
  fi
done

systemctl --user daemon-reload 2>/dev/null || true
systemctl --user enable --now mic-guardian.service 2>/dev/null || true
if [ -f /usr/lib/ladspa/librnnoise_ladspa.so ]; then
  systemctl --user enable --now mic-noise-cancellation.service 2>/dev/null || true
else
  systemctl --user enable mic-noise-cancellation.service 2>/dev/null || true
fi
if command -v kdeconnect-indicator >/dev/null 2>&1; then
  systemctl --user enable --now kdeconnect-indicator.service 2>/dev/null || true
  systemctl --user enable --now kdeconnect-sftp-automount.service 2>/dev/null || true
fi
systemctl --user restart wireplumber.service 2>/dev/null || true

# 8. System-level setup prompt (Lid Hibernation, NVIDIA Power & keyd 60% Keyboard Layer)
echo "[8/8] Checking system-level configurations..."
if [[ "${1:-}" == "--with-system" ]] || [[ $EUID -eq 0 ]]; then
  echo "  -> Installing /etc/systemd/logind.conf.d/30-laptop-lid.conf..."
  sudo mkdir -p /etc/systemd/logind.conf.d
  sudo cp "$REPO_DIR/configs/systemd/system/30-laptop-lid.conf" /etc/systemd/logind.conf.d/30-laptop-lid.conf
  sudo systemctl kill -s HUP systemd-logind.service 2>/dev/null || true
  sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service 2>/dev/null || true
  echo "  ✓ System lid hibernation configured."

  if command -v keyd >/dev/null 2>&1; then
    echo "  -> Installing /etc/keyd/nuobida-60.conf..."
    sudo mkdir -p /etc/keyd
    sudo cp "$REPO_DIR/configs/keyd/nuobida-60.conf" /etc/keyd/nuobida-60.conf
    sudo chmod 644 /etc/keyd/nuobida-60.conf
    sudo systemctl enable --now keyd.service 2>/dev/null || true
    sudo keyd reload 2>/dev/null || sudo systemctl restart keyd.service 2>/dev/null || true
    echo "  ✓ keyd 60% keyboard collaboration layer active."
  else
    echo "  ! keyd not installed; run 'sudo pacman -S keyd' then copy configs/keyd/nuobida-60.conf to /etc/keyd/"
  fi
else
  echo "  Tip: Run './install.sh --with-system' to configure:"
  echo "       - Laptop lid SSD hibernation + NVIDIA power services"
  echo "       - keyd 60% keyboard CapsLock+IJKL navigation layer (/etc/keyd/nuobida-60.conf)"
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
echo "  • Shift + Space               : Universal Flow Launcher Search"
echo "  • Alt + Enter                 : Open Foot Terminal"
echo "  • Alt + Shift + Q             : Close Window"
echo "  • Alt + Z / Alt + X           : Universal Phone Back / Forward"
echo "  • Ctrl + Shift + Esc          : Task Manager (btop)"
echo "  • Super + Shift + S           : Region Screenshot (omasnap)"
echo "  • Super + W                   : Smart Close Window / Stop App"
echo "  • CapsLock (Hold, 60% kbd)    : I/J/K/L arrows, U/O Home/End, [] PgUp/Dn, Esc=\`, Bksp=Del, 1..==F1..F12"
echo "  • Super + ' / Alt+R/C/X / []  : Shared 60% + 100% keyboard aliases"
echo "  • 2-Finger Pinch              : Live Desktop Zoom"
echo "  • 3-Finger Horizontal         : Scroll/Travel Applications"
echo "  • 3-Finger Vertical           : Drag/Move Active Window"
echo "  • 4-Finger Horizontal         : Switch Workspaces"
echo "=================================================================="
