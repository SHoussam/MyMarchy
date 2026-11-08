# MyMarchy Universal Setup Master Prompt

> **Instructions for the AI Agent**:
> You are executing an automated, end-to-end deployment of **MyMarchy** on this Arch Linux / Omarchy system.
> Follow every step sequentially. Do not stop until all components are deployed, permissions are set, services are active, and verification checks pass.

---

## 🎯 Target System Profile
- **Base OS**: Arch Linux / Omarchy (EndeavourOS compatible)
- **Window Manager**: Hyprland 0.56+ (Native Lua Configuration Engine)
- **Status Bar & Shell**: Quickshell / Omarchy Shell (`lobo.islands`, `io.github.ofa14-prog.dynamic-island`)
- **App Launcher**: Flow Launcher styled search (`io.github.hominluo.launcher`)
- **Keybinding Philosophy**: 1:1 Windows GlazeWM v3.10.1 + Flow Launcher shortcuts + Windows ergonomics
- **Target Hardware**: Acer Nitro V 15 (ANV15-52) / Intel Core i9 + NVIDIA RTX Hybrid / UK English keyboard (`gb`) / High-refresh dual monitor (180Hz internal, 240Hz external).

---

## 📥 STEP 1: Clone the MyMarchy Repository

Clone the master setup repository into your workspace:

```bash
git clone https://github.com/SHoussam/MyMarchy.git ~/MyMarchy
cd ~/MyMarchy
```

---

## 📦 STEP 2: Install Required System & AUR Packages

Ensure standard tools, Hyprland dependencies, audio utilities, and performance monitors are present:

### 1. Official Arch Packages (`pacman`):
```bash
sudo pacman -S --needed --noconfirm \
  hyprland quickshell foot btop grim slurp jq \
  pipewire pipewire-pulse wireplumber alsa-utils \
  dkms linux-headers base-devel git eza bat fzf \
  fastfetch brightnessctl udiskie
```

### 2. AUR Packages (`yay`):
```bash
yay -S --needed --noconfirm \
  omasnap \
  lazydocker-bin
```

---

## ⚙️ STEP 3: Deploy Configurations & Custom Files

Deploy the configurations to their exact filesystem locations. Run the automated installer or copy manually:

```bash
cd ~/MyMarchy
chmod +x install.sh
./install.sh
```

### Detailed File Placement & Purpose Reference:

1. **Hyprland Window Manager (`~/.config/hypr/`)**:
   - `configs/hypr/hyprland.lua` -> `~/.config/hypr/hyprland.lua`: Main entry point loading Omarchy defaults and personal Lua modules.
   - `configs/hypr/bindings.lua` -> `~/.config/hypr/bindings.lua`: Complete GlazeWM keybindings (`Alt+Enter`, `Alt+Shift+Q`, `Alt+H/J/K/L`, `Alt+1..9`, `Alt+R` resize submap), Flow Launcher (`Shift+Space`), Task Manager (`Ctrl+Shift+Escape`), Screenshot (`Super+Shift+S`), and Emergency Window Killer (`Super+W`).
   - `configs/hypr/input.lua` -> `~/.config/hypr/input.lua`: Touchpad gestures (2-finger pinch zoom, 3-finger horizontal app travel, 3-finger vertical window grab, 4-finger workspace swipe) and UK keyboard layout.
   - `configs/hypr/monitors.lua` -> `~/.config/hypr/monitors.lua`: High-refresh rate displays (1920x1080@180Hz on `eDP-1`, 1920x1080@240Hz on `HDMI-A-1` with 1.25 fractional scale).
   - `configs/hypr/looknfeel.lua` -> `~/.config/hypr/looknfeel.lua`: GlazeWM gaps (2px inner/outer), 1px borders, rounded corners (6px), and terminal opacity.
   - `configs/hypr/autostart.lua` -> `~/.config/hypr/autostart.lua`: Starts required user daemons and PipeWire audio unmute.
   - `configs/hypr/scripts/lid-close-handler.sh` -> `~/.config/hypr/scripts/lid-close-handler.sh`: Dynamic laptop lid handling (single-screen clamshell on external display when plugged in; true SSD hibernation when on battery).

2. **Omarchy Desktop Shell & Dynamic Island (`~/.config/omarchy/`)**:
   - `configs/omarchy/shell.json` -> `~/.config/omarchy/shell.json`: Layout configuration with thinner top bar, islands layout, and dock apps.
   - `configs/omarchy/extensions/omarchy-menu.jsonc` -> `~/.config/omarchy/extensions/omarchy-menu.jsonc`: Flow Launcher keywords (`wp` wallpaper, `kill` process manager, `remind` timer, `gh` repos, `setup` editor).
   - `configs/omarchy/themes/vantablack/colors.toml` -> `~/.config/omarchy/themes/vantablack/colors.toml`: Custom Vantablack theme overlay with Obsidian dark background, `#4cc9f0` cyan accent, and `#bea3c7` lavender borders.
   - `configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island` -> `~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island`: Full liquid glass Dynamic Island with live hardware statistics telemetry (`bin/dynamic-island-hardware`, `services/HardwareService.qml`, SVG icons).

3. **Custom Binaries & Scripts (`~/.local/bin/`)**:
   - `scripts/bin/omarchy-kill-active` -> `~/.local/bin/omarchy-kill-active`: Safely and forcefully kills stubborn processes without crashing the compositor.
   - `scripts/bin/omarchy-launch-docker-tui` -> `~/.local/bin/omarchy-launch-docker-tui`: Launches lazydocker in a floating terminal.
   - `scripts/bin/sklauncher` -> `~/.local/bin/sklauncher`: Modern Minecraft launcher wrapper.
   - `scripts/bin/damx` -> `~/.local/bin/damx`: Acer NitroSense CLI runner.

4. **Desktop Applications & Icons**:
   - `desktop-entries/*.desktop` -> `~/.local/share/applications/`
   - `pixmaps/sklauncher.png` -> `~/.local/share/pixmaps/sklauncher.png`

5. **Audio & Microphone Startup Service (`~/.config/systemd/user/`)**:
   - `configs/systemd/user/unmute-microphone.service` -> `~/.config/systemd/user/unmute-microphone.service`: Runs `wpctl` and `amixer` to unmute Dmic0 on login.

---

## ⚡ STEP 4: System-Level Laptop Lid & Power Management (Sudo)

Configure true SSD hibernation and NVIDIA sleep resilience:

```bash
# 1. Enable NVIDIA power management services
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

# 2. Deploy logind lid configuration
sudo mkdir -p /etc/systemd/logind.conf.d
sudo cp ~/MyMarchy/configs/systemd/system/30-laptop-lid.conf /etc/systemd/logind.conf.d/30-laptop-lid.conf

# 3. Reload systemd-logind
sudo systemctl kill -s HUP systemd-logind.service
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

Run the verification commands to confirm active state:

```bash
# 1. Reload Hyprland
hyprctl reload

# 2. Check Hyprland configuration errors
hyprctl configerrors

# 3. Verify user systemd services
systemctl --user is-active unmute-microphone.service

# 4. Verify logind lid switch configuration
systemd-analyze cat-config systemd/logind.conf | grep HandleLidSwitch

# 5. Check display refresh rates
hyprctl monitors
```

---

## 🏆 Key Shortcuts Checklist for the User
- **Universal Search**: Press `Shift + Space` to open Flow Launcher.
- **Terminal**: Press `Alt + Enter` to open Foot.
- **Close Window**: Press `Alt + Shift + Q`.
- **Task Manager**: Press `Ctrl + Shift + Escape` to open `btop`.
- **Screenshot**: Press `Super + Shift + S` for region crop.
- **Kill Process**: Press `Super + W` for instant active window kill.
- **Dynamic Island**: Hover over the top bar notch to see real-time CPU, RAM, GPU, and Disk telemetry!
