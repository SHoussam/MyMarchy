# MyMarchy Universal Setup Master Prompt

> **Instructions for the AI Agent**:
> You are executing an automated, end-to-end deployment of **MyMarchy** on this Arch Linux / Omarchy system.
> Follow every step sequentially. Do not stop until all components are deployed, permissions are set, services are active, and verification checks pass.

---

## 🎯 Target System Profile
- **Base OS**: Arch Linux / Omarchy (EndeavourOS compatible)
- **Window Manager**: Hyprland 0.56+ (Native Lua Configuration Engine)
- **Status Bar & Shell**: Quickshell / Omarchy Shell (`lobo.islands`, `hous.menu`, `io.github.ofa14-prog.dynamic-island`)
- **App Launcher**: Flow Launcher styled search (`io.github.hominluo.launcher`)
- **Keybinding Philosophy**: 1:1 Windows GlazeWM v3.10.1 + Universal Phone Back (`Alt+Z`/`Alt+X`) + 60%/100% Keyboard Collaboration (`keyd` CapsLock `IJKL` nav layer + shared Hyprland aliases) + Flow Launcher shortcuts
- **Target Hardware**: Acer Nitro V 15 (ANV15-52) / Intel Core i9 + NVIDIA RTX Hybrid / UK English keyboard (`gb`) + NUOBIDA 60% USB keyboard (`342d:e50e`) / High-refresh dual monitor (180Hz internal, 240Hz external).

---

## 📥 STEP 1: Clone the MyMarchy Repository

Clone the master setup repository into your workspace:

```bash
git clone https://github.com/SHoussam/MyMarchy.git ~/MyMarchy
cd ~/MyMarchy
```

---

## 📦 STEP 2: Install Required System & AUR Packages

Ensure standard tools, Hyprland dependencies, Qt6 Quick dev toolchain, audio/RNNoise utilities, phone integration, text editor, and keyboard remapping tools are present:

### 1. Official Arch Packages (`pacman`):
```bash
sudo pacman -S --needed --noconfirm \
  hyprland quickshell foot ghostty btop grim slurp jq \
  pipewire pipewire-pulse wireplumber alsa-utils noise-suppression-for-voice \
  keyd micro kdeconnect sshfs breeze-icons \
  qt6-base qt6-declarative qt6-wayland python-gobject \
  dkms base-devel git eza bat fzf fastfetch starship \
  brightnessctl udiskie xdg-utils desktop-file-utils
```
*(Also ensure your running kernel headers package—e.g. `linux-omarchy-headers` or `linux-headers`—is installed if building DKMS drivers.)*

### 2. Optional Companion Packages (`pacman` / AUR via `yay`):
```bash
# Built-in screenshot / container TUI / casting helpers
yay -S --needed --noconfirm omasnap lazydocker-bin
```

---

## ⚙️ STEP 3: Deploy Configurations, Companion App & Services

Run the automated installer (pass `--with-system` to also configure root-level `keyd`, `systemd-logind` lid hibernation, and NVIDIA sleep services):

```bash
cd ~/MyMarchy
chmod +x install.sh
./install.sh --with-system
```

*(Running `./install.sh` without `--with-system` deploys all user-level configs, scripts, systemd user services, MIME associations, and compiles `apps/dynamic-island` into `~/.local/bin/dynamic-island` without invoking `sudo`.)*

### Detailed File Placement & Purpose Reference:

1. **Hyprland Window Manager (`~/.config/hypr/`)**:
   - `configs/hypr/hyprland.lua` -> `~/.config/hypr/hyprland.lua`: Main entry point loading Omarchy defaults, personal Lua modules, and the centered floating rule for `^dynamic-island$` (`480x484`).
   - `configs/hypr/bindings.lua` -> `~/.config/hypr/bindings.lua`: GlazeWM keybindings (`Alt+Enter`, `Alt+Shift+Q`, `Alt+H/J/K/L`, `Alt+1..9`, `Alt+R` resize submap), Flow Launcher (`Shift+Space`), Task Manager (`Ctrl+Shift+Escape`), Screenshot (`Super+Shift+S`), Smart Close/Stop (`Super+W`), Dynamic Island Focus Mode (`Super+Alt+F`), Universal Phone Back/Forward (`Alt+Z` / `Alt+X`), and 60%/100% shared aliases (`Super+'`, `Super+Alt+R/C/X`, `Super+[/]`, `Super+Ctrl+M`, `Super+Ctrl+Alt+M`).
   - `configs/hypr/input.lua` -> `~/.config/hypr/input.lua`: Touchpad gestures (2-finger pinch zoom, 3-finger horizontal app travel, 3-finger vertical window grab, 4-finger workspace swipe) and UK keyboard layout.
   - `configs/hypr/monitors.lua` -> `~/.config/hypr/monitors.lua`: High-refresh rate displays (1920x1080@180Hz on `eDP-1`, 1920x1080@240Hz on `HDMI-A-1` with 1.25 fractional scale).
   - `configs/hypr/looknfeel.lua` -> `~/.config/hypr/looknfeel.lua`: GlazeWM gaps (2px inner/outer), 1px borders, rounded corners (6px), and terminal opacity.
   - `configs/hypr/autostart.lua` -> `~/.config/hypr/autostart.lua`: Starts required user daemons and PipeWire audio unmute.
   - `configs/hypr/scripts/lid-close-handler.sh` -> `~/.config/hypr/scripts/lid-close-handler.sh`: Dynamic laptop lid handling (single-screen clamshell on external display when plugged in; true SSD hibernation when on battery).

2. **Omarchy Shell, Branding & Dynamic Island (`~/.config/omarchy/`)**:
   - `configs/omarchy/shell.json` -> `~/.config/omarchy/shell.json`: Islands top bar with `hous.menu`, left-side `omarchy.tray`, opaque bar styling, disabled stock `omarchy.menu`, and pinned `dynamic-island` + `org.kde.kdeconnect.app` dock entries.
   - `configs/omarchy/dynamic-island.json` -> `~/.config/omarchy/dynamic-island.json`: Dynamic Island behavior (`hoverExpand`, `priority: ["agent", "music", "timer", "recording"]`, `idleClock`).
   - `configs/omarchy/extensions/omarchy-menu.jsonc` -> `~/.config/omarchy/extensions/omarchy-menu.jsonc`: Flow Launcher keywords (`wp`, `kill`, `remind`, `gh`, `setup`, `restart-island`/`fix-island`/`revive-island`).
   - `configs/omarchy/plugins/hous.menu` + `pixmaps/hs_logo.png` -> `~/.config/omarchy/plugins/hous.menu` & `~/.config/omarchy/assets/hs_logo.png`: Custom top-left HS monogram menu widget.
   - `configs/omarchy/themes/vantablack/colors.toml` -> `~/.config/omarchy/themes/vantablack/colors.toml`: Obsidian Vantablack accent theme overlay.
   - `configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island` -> `~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island`:
     - Hardware telemetry (`bin/dynamic-island-hardware`, `services/HardwareService.qml`).
     - Wayland clamshell/wake layer-surface recovery (`SurfaceHost.qml`, `Island.qml` `recoverSurface()`).
     - OpenCode v2 `ServerPlugin` + SQLite feed (`agents/opencode/dynamic-island.js`, `bin/dynamic-island-scan`, `bin/dynamic-island-transcript`) & LM Studio / `llama-server` telemetry (`bin/dynamic-island-lmstudio`, `icons/brand/lmstudio.svg`).
     - KDE Connect phone D-Bus bridge (`bin/dynamic-island-phones`, `services/PhoneService.qml`, `icons/phone.svg`), compact phone indicator dot, and Home mid-space card.
     - Compact model activity capsule (`CompactView.qml`) & icon-only `TabStrip.qml`.

3. **Native Dynamic Island Companion App (`apps/dynamic-island/`)**:
   - Compiled & installed via `apps/dynamic-island/bin/install-local` into `~/.local/bin/dynamic-island`, `~/.local/share/applications/dynamic-island.desktop`, and `~/.local/share/icons/hicolor/scalable/apps/dynamic-island.svg`.
   - Provides a floating Qt6 GUI (`480x484`) and headless CLI (`--status --json`, `--restart`, `--revive`, `--toggle`, `--focus`, `--reset`).

4. **Terminal, Prompt & Telemetry (`~/.config/`)**:
   - `configs/foot/foot.ini` -> `~/.config/foot/foot.ini` & `configs/ghostty/config` -> `~/.config/ghostty/config`.
   - `configs/starship.toml` -> `~/.config/starship.toml`: Powerline prompt.
   - `configs/fastfetch/{config.jsonc,hs_logo.txt}` -> `~/.config/fastfetch/`: Custom HS Unicode block art HUD.
   - `configs/bash/bashrc.additions` -> Appended to `~/.bashrc`.

5. **Audio (RNNoise Noise Cancellation + Microphone Unmute Guardian)**:
   - `configs/pipewire/mic-noise-cancellation.conf` & `configs/pipewire/mic-noise-cancellation.conf.d/90-rnnoise-mic.conf` -> `~/.config/pipewire/`: Standalone PipeWire RNNoise filter publishing `rnnoise_mic_source`. *(Note: Update `target.object` in `90-rnnoise-mic.conf` if your hardware mic node differs from `alsa_input.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Mic1__source`.)*
   - `configs/wireplumber/scripts/device/state-routes.lua` -> `~/.config/wireplumber/scripts/device/state-routes.lua`: Prevents WirePlumber from saving or re-applying `mute: true` on input routes.
   - `scripts/bin/mic-guardian.py` + `configs/systemd/user/mic-guardian.service`: Subscribes to `logind` `PrepareForSleep` on D-Bus to unmute both PipeWire `@DEFAULT_AUDIO_SOURCE@` and ALSA `Dmic0` on boot and suspend resume.
   - `scripts/bin/mic-noise-cancellation-set-default` + `configs/systemd/user/mic-noise-cancellation.service`: Launches the RNNoise PipeWire host and routes default input to `rnnoise_mic_source`.

6. **Custom Utilities, KDE Connect & Micro Default Editor (`~/.local/`)**:
   - `scripts/bin/omarchy-kill-active` -> `~/.local/bin/omarchy-kill-active`: Safely closes focused windows in multi-window apps (`chromium`, terminals, VS Code), protects shell/Antigravity, falls back to `SIGTERM`.
   - `scripts/bin/omarchy-toggle-focus-mode` (`~/.local/bin/focus-mode` symlink): Toggles Dynamic Island `hoverExpand`.
   - `scripts/bin/kdeconnect-sftp-automount` + `configs/systemd/user/{kdeconnect-indicator,kdeconnect-sftp-automount}.service`: Tray icon & D-Bus SFTP auto-mounter (supports `KDECONNECT_DEVICE_ID` env var or `--device`).
   - `scripts/bin/omarchy-launch-docker-tui`, `scripts/bin/sklauncher`, `scripts/bin/damx` -> `~/.local/bin/`.
   - `desktop-entries/micro.desktop` + `configs/mime/user-text-extension.xml`: Makes `micro` the default opener for `text/plain` (including `*.text`), `text/markdown`, and `text/x-markdown`.

7. **60% / 100% Keyboard Collaboration (`keyd`, System-Level)**:
   - `configs/keyd/nuobida-60.conf` -> `/etc/keyd/nuobida-60.conf`: Hardware-scoped (`342d:e50e`) `capslock = overload(nav, capslock)` providing inverted-T `I/J/K/L` arrows, `U/O` (`Home`/`End`), `[/]` (`PageUp`/`PageDown`), `Esc` (`` ` ``), `Backspace` (`Delete`), `P` (`PrintScreen`), `1..=` (`F1..F12`), and media/brightness keys without affecting the laptop's built-in 100% keyboard or external wireless keyboards. *(Verify your USB ID via `lsusb` or `sudo keyd monitor` if using another 60% keyboard model.)*

---

## ⚡ STEP 4: System-Level Services, Firewall & Hardware Drivers (Manual / Verification)

If you did not run `./install.sh --with-system`:

```bash
# 1. Laptop lid hibernation & NVIDIA sleep resilience
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service
sudo mkdir -p /etc/systemd/logind.conf.d /etc/keyd
sudo cp ~/MyMarchy/configs/systemd/system/30-laptop-lid.conf /etc/systemd/logind.conf.d/30-laptop-lid.conf
sudo systemctl kill -s HUP systemd-logind.service

# 2. 60% keyboard CapsLock+IJKL nav layer (keyd)
sudo cp ~/MyMarchy/configs/keyd/nuobida-60.conf /etc/keyd/nuobida-60.conf
sudo systemctl enable --now keyd.service
```

### KDE Connect Firewall (`ufw`) on Local Wi-Fi:
If `ufw` is active with inbound `DROP`, allow KDE Connect ports on your Wi-Fi interface (replace `wlp62s0` and `192.168.1.0/24` with your LAN values):
```bash
sudo ufw allow in on wlp62s0 from 192.168.1.0/24 to any port 1714:1764 proto tcp
sudo ufw allow in on wlp62s0 from 192.168.1.0/24 to any port 1714:1764 proto udp
sudo ufw reload
```

---

## 🎮 STEP 5: Acer Nitro Fan Control & Performance Driver (Optional for Acer Laptops)

If running on an Acer Nitro or Predator laptop:

```bash
cd ~/MyMarchy
sudo bash scripts/hardware/acer-nitrosense/install.sh
```

This installs the `linuwu-sense-dkms-git` kernel module and starts `damx-daemon.service`.

---

## 🔄 STEP 6: Reload & Verify Everything

Run these verification checks to confirm active state:

```bash
# 1. Reload Hyprland and verify zero config errors
hyprctl reload && hyprctl configerrors

# 2. Verify keyd 60% config & daemon status
sudo keyd check /etc/keyd/nuobida-60.conf && systemctl is-active keyd.service

# 3. Verify user systemd services
systemctl --user is-active mic-guardian.service mic-noise-cancellation.service kdeconnect-indicator.service kdeconnect-sftp-automount.service

# 4. Verify RNNoise noise-canceled microphone is the default source
pactl get-default-source   # Expected: rnnoise_mic_source

# 5. Verify Micro MIME defaults
xdg-mime query default text/plain && xdg-mime query default text/markdown

# 6. Verify Dynamic Island plugin & companion app health
dynamic-island --status --json

# 7. Verify logind lid switch configuration & displays
systemd-analyze cat-config systemd/logind.conf | grep HandleLidSwitch
hyprctl monitors
```
