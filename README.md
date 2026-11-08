# 🌌 MyMarchy

> **The ultimate Arch Linux & Omarchy desktop environment** — combining the razor-sharp tiling ergonomics of Windows **GlazeWM**, the speed of **Flow Launcher Universal Search**, an **Apple-inspired Liquid Glass Dynamic Island** with live real-time hardware telemetry, **Hyprland 0.56+ native multi-touch trackpad gestures**, and **industrial-grade laptop power and Acer Nitro fan management**.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)](#)
[![Hyprland 0.56+](https://img.shields.io/badge/Hyprland-Lua_Engine-00ADD8?logo=hyprland&logoColor=white)](#)
[![Quickshell](https://img.shields.io/badge/Quickshell-QML_Dynamic_Island-34C759)](#)
[![GlazeWM](https://img.shields.io/badge/GlazeWM-1:1_Tiling_Shortcuts-9B59B6)](#)

---

## 📖 Table of Contents
1. [Architecture & Philosophy](#-architecture--philosophy)
2. [Hardware Profile](#-hardware-profile)
3. [File-by-File Catalog & Directory Guide](#-file-by-file-catalog--directory-guide)
   - [Hyprland Window Manager (`configs/hypr/`)](#1-hyprland-window-manager-configshypr)
   - [Omarchy Shell & Flow Launcher (`configs/omarchy/`)](#2-omarchy-shell--flow-launcher-configsomarchy)
   - [Dynamic Island Hardware Plugin (`configs/omarchy/plugins/`)](#3-dynamic-island-hardware-plugin)
   - [Custom Utilities & Scripts (`scripts/bin/`)](#4-custom-utilities--scripts-scriptsbin)
   - [Hardware & Power Scripts (`scripts/hardware/` & `scripts/hypr/`)](#5-hardware--power-scripts)
   - [Systemd Services (`configs/systemd/`)](#6-systemd-services-configssystemd)
   - [Terminal, IDE & Developer Configs](#7-terminal-ide--developer-configs)
4. [Complete Shortcuts & Gestures Cheat Sheet](#-complete-shortcuts--gestures-cheat-sheet)
5. [Installation Guide](#-installation-guide)
   - [Option A: Automated One-Line Install](#option-a-automated-install)
   - [Option B: Autonomous AI Agent Install (`prompt.md`)](#option-b-autonomous-ai-agent-install)
   - [Option C: Manual Step-by-Step](#option-c-manual-step-by-step)
6. [Verification & Health Checks](#-verification--health-checks)

---

## 🏛 Architecture & Philosophy

**MyMarchy** transforms an Arch Linux / Omarchy installation into a cohesive workstation. Instead of fighting muscle memory, it ports the most productive components of Windows 11 and macOS power-user tooling natively into Wayland:

1. **GlazeWM 1:1 Keybinding Layer**:
   - Full directional focus with `Alt + H/J/K/L` and `Alt + Arrows`.
   - Window swapping with `Alt + Shift + H/J/K/L`.
   - Workspaces `1..9` with `Alt + 1..9` and `Alt + Shift + 1..9`.
   - Proportional resizing with `Alt + U/P/O/I` and dedicated resize modal submap (`Alt + R`).
2. **Flow Launcher Universal Search**:
   - `Shift + Space` summons a centered search bar.
   - Built-in keyword aliases: `wp` (wallpaper picker), `kill` (task manager), `remind` (reminders), `gh` (GitHub repositories), and `setup` (workspace editor).
3. **Liquid Glass Dynamic Island with Live Hardware Telemetry**:
   - Native QML notch floating gracefully at the top of the screen.
   - Hover-to-expand behavior with translucent frosted glass.
   - Custom hardware monitoring engine tracking real-time CPU %, RAM usage, NVIDIA GPU load, and SSD storage.
4. **Fluid Multi-Touch Gestures (Hyprland 0.56+)**:
   - **2-Finger Pinch**: Live animated desktop magnifier / zoom (`cursor_zoom`, mode `live`).
   - **3-Finger Horizontal Swipe**: Travel horizontally between applications (`scroll_move`).
   - **3-Finger Vertical Swipe**: Grab active window and travel / reposition it (`move`).
   - **4-Finger Horizontal Swipe**: 1:1 animated workspace switcher (`workspace`).
   - **4-Finger Vertical Swipe**: Swap window up / down.
5. **Intelligent Laptop Power & Thermal Governance**:
   - Clamshell docking: Closing the lid when plugged in routes everything seamlessly to the external high-refresh display without sleeping.
   - Battery protection: Closing the lid on battery triggers instant SSD hibernation to eliminate drain.
   - Acer Nitro thermal control: Custom DKMS driver (`linuwu_sense`) and DAMX management daemon for fan profiles.

---

## 💻 Hardware Profile

This configuration was engineered on and tuned for:
- **Laptop**: Acer Nitro V 15 (ANV15-52)
- **CPU**: Intel Core i9-13900H (14 cores, 20 threads)
- **GPU**: NVIDIA GeForce RTX Laptop GPU + Intel Iris Xe Graphics (Hybrid Prime)
- **Internal Display**: 1920x1080 @ 180Hz (hardware max) with 1.25x scaling
- **External Display**: 1920x1080 @ 240Hz on `HDMI-A-1` with 1.25x scaling
- **Keyboard**: UK English (`gb`) with 250ms repeat delay, 35Hz repeat rate

---

## 📂 File-by-File Catalog & Directory Guide

### 1. Hyprland Window Manager (`configs/hypr/`)

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `hyprland.lua` | `~/.config/hypr/hyprland.lua` | Master entry point for Hyprland's Lua parser. Requires Omarchy bootstrap and personal modules. | Entry point executed on Hyprland startup. Loads user overrides cleanly without clobbering upstream updates. | Placed in `~/.config/hypr/`. Kept clean; all logic is split into modular files. |
| `bindings.lua` | `~/.config/hypr/bindings.lua` | Definitive keybinding map. Binds GlazeWM shortcuts, Flow Launcher, task manager, screenshots, process killer, and lid switch. | Maps all keyboard interaction. Solves muscle-memory friction when transitioning from Windows GlazeWM. | Copy to `~/.config/hypr/bindings.lua`. Reload with `hyprctl reload`. |
| `input.lua` | `~/.config/hypr/input.lua` | Configures UK English keyboard, fast repeat, sloppy focus, natural touchpad scroll, and 2/3/4-finger touchpad gestures. | Configures mouse, touchpad gestures, and keyboard timings. Enables macOS-like zoom and trackpad swipes. | Copy to `~/.config/hypr/input.lua`. Tested via `hyprctl reload`. |
| `monitors.lua` | `~/.config/hypr/monitors.lua` | Explicit multi-monitor resolution, refresh rate (180Hz internal, 240Hz external), and fractional scaling (1.25). | Prevents Wayland from defaulting to 60Hz or wrong scales. Fixes HDMI black-screen bugs on lid toggle. | Adjust monitor IDs (`eDP-1`, `HDMI-A-1`) if hardware differs. |
| `looknfeel.lua` | `~/.config/hypr/looknfeel.lua` | Window gaps (2px in/out), 1px border styling (`#bea3c7` lavender active, `#a1a1a1` inactive), 6px rounding, and terminal opacity (0.91). | Gives the desktop the exact GlazeWM minimal aesthetic with subtle window borders and blur. | Copy to `~/.config/hypr/looknfeel.lua`. |
| `autostart.lua` | `~/.config/hypr/autostart.lua` | Startup hook for audio services. Executes PipeWire `wpctl` and `amixer` unmuting on session initialization. | Fixes persistent Linux issue where digital microphone (Dmic0) boots up muted. | Copy to `~/.config/hypr/autostart.lua`. |
| `xdph.conf` | `~/.config/hypr/xdph.conf` | XDG Desktop Portal Hyprland configuration. Enables window sharing tokens and preview share picker. | Enables screen sharing in Chromium, Discord, Slack, and OBS. | Copy to `~/.config/hypr/xdph.conf`. |
| `hyprsunset.conf` | `~/.config/hypr/hyprsunset.conf` | Blue light filter / night light profile manager. | Prevents random screen tinting and configures neutral color profiles. | Copy to `~/.config/hypr/hyprsunset.conf`. |
| `scripts/lid-close-handler.sh` | `~/.config/hypr/scripts/lid-close-handler.sh` | Smart script executed on `switch:on:Lid Switch`. Detects AC power: if docked, enters clamshell mode; if on battery, hibernates. | Prevents battery drain when closing laptop, and prevents accidental suspension when connected to an external monitor. | Must be executable (`chmod +x`). Triggered directly by `bindings.lua`. |
| `scripts/setup-system-lid-hibernation.sh` | `~/.config/hypr/scripts/setup-system-lid-hibernation.sh` | Sudo setup script that configures `systemd-logind` and enables NVIDIA hibernate services. | Root-level script run once during machine provisioning. | Run with `sudo bash setup-system-lid-hibernation.sh`. |

---

### 2. Omarchy Shell & Flow Launcher (`configs/omarchy/`)

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `shell.json` | `~/.config/omarchy/shell.json` | JSON configuration of the top status bar (Islands), system dock, idle timeouts, and active plugins. | Cleans up the top bar: removes redundant date/time clutter, creates space for Dynamic Island, and positions tray icons. | Copy to `~/.config/omarchy/shell.json`. |
| `shell.toml` | `~/.config/omarchy/shell.toml` | Font configuration for the Omarchy status bar (size 10). | Ensures consistent typography across bar widgets. | Copy to `~/.config/omarchy/shell.toml`. |
| `dynamic-island.json` | `~/.config/omarchy/dynamic-island.json` | Runtime behavior settings for the Dynamic Island: hover delay (80ms), collapse delay (420ms), clock format, stats toggle. | Controls how the liquid notch behaves when hovered over or clicked. | Copy to `~/.config/omarchy/dynamic-island.json`. |
| `extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Custom search aliases: `wp` (wallpaper), `kill` (process manager), `remind` (reminder), `gh` (GitHub), `setup` (editor). | Replicates Flow Launcher keyword triggers in Omarchy's application menu. | Copy to `~/.config/omarchy/extensions/omarchy-menu.jsonc`. |
| `themes/vantablack/colors.toml` | `~/.config/omarchy/themes/vantablack/colors.toml` | Color theme specification: Obsidian black background (`#08080a`), bright Cyan accent (`#4cc9f0`), Lavender border (`#bea3c7`). | Deep OLED dark theme with high contrast and cyan indicators. | Copy to `~/.config/omarchy/themes/vantablack/colors.toml`. |

---

### 3. Dynamic Island Hardware Plugin

Located in `configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island/`:

| Component | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `bin/dynamic-island-hardware` | `.../bin/dynamic-island-hardware` | Multi-threaded Python telemetry daemon. Computes real-time CPU % from `/proc/stat`, RAM from `/proc/meminfo`, NVIDIA GPU % via `nvidia-smi`, and disk space via `statvfs`. | Provides fast hardware telemetry without spawning heavy external subprocesses. | Executable script called automatically by QML service. |
| `services/HardwareService.qml` | `.../services/HardwareService.qml` | QML service interfacing with `dynamic-island-hardware` over stdout JSON streams. Exposes reactive properties. | Bridges backend Linux kernel statistics to Quickshell QML properties. | Imported in `Island.qml`. |
| `pages/HomePage.qml` | `.../pages/HomePage.qml` | UI page rendering live hardware telemetry cards (CPU, RAM, GPU, Disk) with progress bars, badges, and status colors. | Displayed when opening the Dynamic Island. Replaces generic window list with real-time hardware status. | Rendered inside the expanded notch. |
| `Island.qml` | `.../Island.qml` | Main notch geometry, liquid glass shader, hover mechanics, and multi-theme color bindings. | The visual notch itself: animates between compact pill, clock, music visualizer, and hardware hub. | Core QML file for the plugin. |
| `icons/*.svg` | `.../icons/` | Custom vector icons for CPU (`cpu.svg`), RAM (`ram.svg`), GPU (`gpu.svg`), Disk (`disk.svg`), and Activity (`activity.svg`). | Crisp UI icons matching theme accent colors. | Referenced by QML delegates. |

---

### 4. Custom Utilities & Scripts (`scripts/bin/`)

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `omarchy-kill-active` | `~/.local/bin/omarchy-kill-active` | Queries Hyprland active window JSON, resolves PID, issues `SIGTERM` followed by `SIGKILL` after 100ms, and closes the window. | Closes uncooperative applications (e.g. frozen games, heavy IDEs) instantly without crashing the compositor. Protects desktop shell from self-kill. | Bound to `Super + W`. Also callable directly from terminal. |
| `omarchy-launch-docker-tui` | `~/.local/bin/omarchy-launch-docker-tui` | Launches `lazydocker` in a floating terminal with proper terminal type and privilege escalation. | Provides immediate graphical/TUI monitoring and control of Docker containers. | Callable via `docker-ui` alias or Flow Launcher. |
| `sklauncher` | `~/.local/bin/sklauncher` | Resolves system Java (Java 17/21) or mise shims and launches `SKlauncher.jar`. | Portable, robust Minecraft launcher runner. | Executable wrapper mapped to desktop entry. |
| `damx` | `~/.local/bin/damx` | Resolves DivAcerManagerMax binary in `~/.local/share/damx`, `/usr/bin`, or `/opt`. | CLI command to launch Acer NitroSense thermal and fan control center. | Type `damx` in terminal or press `Shift + Space` and search "NitroSense". |

---

### 5. Hardware & Power Scripts

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `scripts/hardware/acer-nitrosense/install.sh` | Provisioning Script | Installs DKMS kernel driver `linuwu_sense`, adds user to group, sets up `damx-daemon.service`, and builds DAMX. | Grants hardware control over Acer Nitro fans, performance power profiles, and battery charging thresholds. | Run with `sudo bash scripts/hardware/acer-nitrosense/install.sh`. |
| `configs/systemd/system/30-laptop-lid.conf` | `/etc/systemd/logind.conf.d/30-laptop-lid.conf` | Overrides `systemd-logind`: `HandleLidSwitch=hibernate`, `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`. | Prevents sleep loops, allows external display clamshell gaming, and guarantees 0% battery drain in backpacks. | Copied to `/etc/systemd/logind.conf.d/` with sudo. |

---

### 6. Systemd Services (`configs/systemd/`)

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `unmute-microphone.service` | `~/.config/systemd/user/unmute-microphone.service` | Oneshot user systemd service waiting for WirePlumber and PipeWire, then unmuting the default audio source and Dmic0. | Solves boot-time muted microphone issues on laptops. | Enabled via `systemctl --user enable --now unmute-microphone.service`. |

---

### 7. Terminal, IDE & Developer Configs

| File | Target Destination | Work Description | When & Why Needed | Agent / User Usage |
|---|---|---|---|---|
| `configs/foot/foot.ini` | `~/.config/foot/foot.ini` | Foot terminal emulator configuration: JetBrainsMono Nerd Font (size 8), 14px padding, CSI-u key-bindings, beam cursor (`#507D00`). | Fast Wayland terminal with clean font rendering and proper Alt+Shift keybindings. | Copy to `~/.config/foot/foot.ini`. |
| `configs/bash/bashrc.additions` | Appended to `~/.bashrc` | Environment variables adding `~/.local/bin`, `~/.bun/bin`, `~/.opencode/bin`, and `~/.dotnet/tools` to `PATH`. | Ensures all installed CLI tools and custom scripts are immediately discoverable. | Append to `~/.bashrc`. |
| `configs/antigravity/settings.json` | `~/.config/Antigravity/User/settings.json` | IDE settings for Antigravity: `Aurora Nocturne Soft` theme, 24h clock, autosave, GCP project configuration. | Restores personalized IDE workflow. | Copy to `~/.config/Antigravity/User/settings.json`. |
| `configs/mcp/mcp_config.template.json` | `~/.gemini/config/mcp_config.json` | Template for AI MCP tools (Chrome DevTools, Context7, GitHub, NotebookLM, Playwright, PowerPoint, Shadcn). | Equips AI coding assistants with access to system tools, web browsers, and repositories. | Copy and replace `<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>`. |

---

## ⌨️ Complete Shortcuts & Gestures Cheat Sheet

### 🪟 GlazeWM Tiling & Window Management

| Shortcut | Action | Description |
|---|---|---|
| `Alt + Enter` | Launch Terminal | Opens Foot terminal emulator |
| `Alt + Shift + Q` | Close Window | Closes currently focused window |
| `Alt + H` / `Alt + Left` | Focus Left | Focuses adjacent window to the left |
| `Alt + L` / `Alt + Right` | Focus Right | Focuses adjacent window to the right |
| `Alt + K` / `Alt + Up` | Focus Up | Focuses adjacent window above |
| `Alt + J` / `Alt + Down` | Focus Down | Focuses adjacent window below |
| `Alt + Shift + H` / `Left` | Swap Left | Moves active window to the left |
| `Alt + Shift + L` / `Right` | Swap Right | Moves active window to the right |
| `Alt + Shift + K` / `Up` | Swap Up | Moves active window up |
| `Alt + Shift + J` / `Down` | Swap Down | Moves active window down |
| `Alt + 1 .. 9` | Focus Workspace | Switches to workspace 1 through 9 |
| `Alt + Shift + 1 .. 9` | Move to Workspace | Moves focused window to workspace 1 through 9 |
| `Alt + F` | Toggle Fullscreen | Maximizes window |
| `Alt + V` | Toggle Tiling Split | Toggles between horizontal and vertical split |
| `Alt + Shift + Space` | Toggle Floating | Toggles floating mode for active window |
| `Alt + U` / `Alt + P` | Resize Width | Shrinks / expands window width |
| `Alt + I` / `Alt + O` | Resize Height | Shrinks / expands window height |
| `Alt + R` | Resize Submap | Enters modal resize mode (`HJKL` / Arrows, `Esc` to exit) |
| `Alt + Shift + P` | Pause Keybindings | Pauses all keybindings for gaming/VMs (`Alt+Shift+P` to resume) |

### 🚀 Flow Launcher & Search Keywords

| Trigger | Action | Description |
|---|---|---|
| `Shift + Space` | Universal Search | Opens centered Flow Launcher style search bar |
| `wp` | Wallpaper Switcher | Quick action to change desktop background |
| `kill` | Process Manager | Launches `btop` system monitor |
| `remind` | Reminder Menu | Quick reminder / countdown timer creator |
| `gh` | GitHub Profile | Opens GitHub repositories in browser |
| `setup` | Workspace Editor | Opens setup configurations in IDE |

### ⚡ Windows Ergonomics & Emergency Tools

| Shortcut | Tool | Description |
|---|---|---|
| `Ctrl + Shift + Escape` | Task Manager | Launches terminal task manager (`btop`) |
| `Super + Shift + S` | Screenshot Tool | Interactive region screen capture (`omasnap`) |
| `Super + W` | Emergency Killer | Forcefully kills active application process (`SIGTERM` + `SIGKILL`) |
| `Ctrl + Alt + Space` | Dynamic Island | Expands / collapses top liquid glass notch |
| `Ctrl + Alt + V` | Clipboard History | Opens clipboard manager in Dynamic Island |
| `Ctrl + Alt + D` | Toggle Status Bar | Hides / reveals the top status bar |

### 🖐 Multi-Touch Trackpad Gestures

| Gesture | Action | Feature |
|---|---|---|
| **2-Finger Pinch** | Desktop Magnifier | Smooth live cursor zoom in and out (`cursor_zoom`) |
| **3-Finger Horizontal Swipe** | Application Travel | Smoothly travel across horizontal window columns (`scroll_move`) |
| **3-Finger Vertical Swipe** | Window Reposition | Grab and reposition the focused window (`move`) |
| **4-Finger Horizontal Swipe** | Workspace Switch | 1:1 animated gesture to transition between virtual desktops |
| **4-Finger Vertical Swipe** | Window Swap | Swap window vertically up / down |

---

## 🛠 Installation Guide

### Option A: Automated Install
Run the included turnkey installer:

```bash
git clone https://github.com/SHoussam/MyMarchy.git ~/MyMarchy
cd ~/MyMarchy
chmod +x install.sh
./install.sh
```

To automatically apply root-level laptop lid hibernation and NVIDIA power services, run:
```bash
./install.sh --with-system
```

---

### Option B: Autonomous AI Agent Install
If you are using an agentic coding assistant (Gemini, Claude, Antigravity, Cursor, Roo-Code, etc.), provide it with `prompt.md`:

```text
Please read ~/MyMarchy/prompt.md and execute the complete setup out of the box.
```

The agent will read the instructions, verify prerequisites, deploy all configs to their exact paths, configure systemd units, and run verification diagnostics automatically.

---

### Option C: Manual Step-by-Step

#### 1. Install Base Packages
```bash
sudo pacman -S --needed hyprland quickshell foot btop grim slurp jq \
  pipewire pipewire-pulse wireplumber alsa-utils dkms linux-headers base-devel git eza bat fzf
yay -S --needed omasnap lazydocker-bin
```

#### 2. Copy Configurations
```bash
mkdir -p ~/.config/hypr/scripts ~/.config/omarchy/extensions ~/.config/omarchy/themes/vantablack ~/.config/omarchy/plugins ~/.local/bin ~/.local/share/applications

cp -r configs/hypr/* ~/.config/hypr/
cp -r configs/omarchy/* ~/.config/omarchy/
cp configs/foot/foot.ini ~/.config/foot/foot.ini
cp scripts/bin/* ~/.local/bin/
chmod +x ~/.local/bin/* ~/.config/hypr/scripts/*
```

#### 3. Setup Dynamic Island & Upstream Plugins
```bash
cp -r configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island ~/.config/omarchy/plugins/
git clone --depth 1 https://github.com/hominluo/omarchy-launcher.git ~/.config/omarchy/plugins/io.github.hominluo.launcher
git clone --depth 1 https://github.com/DanielLob-o/Islands.git ~/.config/omarchy/plugins/lobo.islands
```

#### 4. Enable Services & Hardware Power
```bash
# User audio unmute service
cp configs/systemd/user/unmute-microphone.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now unmute-microphone.service

# System lid hibernation (root)
sudo cp configs/systemd/system/30-laptop-lid.conf /etc/systemd/logind.conf.d/
sudo systemctl kill -s HUP systemd-logind.service
sudo systemctl enable nvidia-suspend.service nvidia-hibernate.service nvidia-resume.service

# Acer NitroSense (if applicable)
sudo bash scripts/hardware/acer-nitrosense/install.sh
```

#### 5. Reload Hyprland
```bash
hyprctl reload
```

---

## 🔍 Verification & Health Checks

Verify your deployment with these sanity checks:

```bash
# 1. Check Hyprland configuration syntax
hyprctl configerrors

# 2. Test hardware telemetry daemon directly
python3 ~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-hardware

# 3. Check active display refresh rates
hyprctl monitors

# 4. Confirm systemd microphone service is running
systemctl --user status unmute-microphone.service

# 5. Confirm system logind lid switch rules
systemd-analyze cat-config systemd/logind.conf | grep HandleLidSwitch
```

---

## 📄 License
MIT License. Created by [SHoussam](https://github.com/SHoussam). Contributions and tweaks are welcome!
