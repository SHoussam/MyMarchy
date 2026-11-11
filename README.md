# 🌌 MyMarchy

> **The ultimate Arch Linux & Omarchy desktop environment** — combining Windows **GlazeWM** tiling ergonomics, **Universal Phone Back (`Alt+Z`/`Alt+X`)**, seamless **60% + 100% keyboard collaboration (`keyd` CapsLock `IJKL` layer + shared aliases)**, **Flow Launcher Universal Search**, an **Apple-inspired Liquid Glass Dynamic Island** (with hardware telemetry, OpenCode/LM Studio agent tracking, KDE Connect phone status, Focus Mode, and a Qt6 recovery companion app), **always-on RNNoise mic noise cancellation**, **Hyprland 0.56+ native trackpad gestures**, and **laptop clamshell/hibernation + Acer Nitro thermal governance**.

[![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?logo=arch-linux&logoColor=white)](#)
[![Hyprland 0.56+](https://img.shields.io/badge/Hyprland-Lua_Engine-00ADD8?logo=hyprland&logoColor=white)](#)
[![Quickshell](https://img.shields.io/badge/Quickshell-QML_Dynamic_Island-34C759)](#)
[![Qt6 Companion](https://img.shields.io/badge/Qt6-Dynamic_Island_App-41CD52)](#)
[![GlazeWM](https://img.shields.io/badge/GlazeWM-1:1_Tiling_Shortcuts-9B59B6)](#)

---

## 📖 Table of Contents
1. [Architecture & Philosophy](#-architecture--philosophy)
2. [Hardware Profile](#-hardware-profile)
3. [File-by-File Catalog & Directory Guide](#-file-by-file-catalog--directory-guide)
   - [Hyprland Window Manager (`configs/hypr/`)](#1-hyprland-window-manager-configshypr)
   - [Omarchy Shell, Branding & Flow Launcher (`configs/omarchy/`)](#2-omarchy-shell-branding--flow-launcher-configsomarchy)
   - [Dynamic Island Plugin (`configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island/`)](#3-dynamic-island-plugin)
   - [Dynamic Island Companion App (`apps/dynamic-island/`)](#4-dynamic-island-companion-app-appsdynamic-island)
   - [Custom Utilities & Scripts (`scripts/bin/`)](#5-custom-utilities--scripts-scriptsbin)
   - [Audio Pipeline & Systemd Services (`configs/pipewire/`, `configs/wireplumber/`, `configs/systemd/`)](#6-audio-pipeline--systemd-services)
   - [60% Keyboard Layer, Micro MIME & Developer Configs](#7-60-keyboard-layer-micro-mime--developer-configs)
4. [Complete Shortcuts & Gestures Cheat Sheet](#-complete-shortcuts--gestures-cheat-sheet)
5. [Installation Guide](#-installation-guide)
   - [Option A: Automated Install](#option-a-automated-install)
   - [Option B: Autonomous AI Agent Install (`prompt.md`)](#option-b-autonomous-ai-agent-install)
   - [Option C: Manual Step-by-Step](#option-c-manual-step-by-step)
6. [Verification & Health Checks](#-verification--health-checks)

---

## 🏛 Architecture & Philosophy

**MyMarchy** transforms an Arch Linux / Omarchy installation into a cohesive workstation that eliminates rough edges across window management, dual keyboards, AI workflows, phone integration, and audio hardware:

1. **GlazeWM 1:1 Keybinding Layer + Universal Phone Back**:
   - Directional focus & swapping with `Alt + H/J/K/L` and `Alt + Arrows`, workspaces `Alt + 1..9`, direct resize (`Alt + U/P/O/I`) and modal resize submap (`Alt + R`).
   - **Universal "Phone Back & Forward" (`Alt + Z` / `Alt + X`)**: App-aware back/forward chord—sends `Escape` inside exclusive shell overlays/launchers, `Ctrl+Alt+Left/Right` in JetBrains IDEs & Obsidian, `Ctrl+Alt+-` / `Ctrl+Shift+-` in Antigravity/VS Code, and `Alt+Left/Right` everywhere else.
   - **Smart Close (`Super + W`)**: Cleanly closes only the focused window in Chromium, terminals, VS Code, and multi-window apps without killing sibling windows or Antigravity/shell processes.
2. **Seamless 60% + 100% Keyboard Collaboration**:
   - Hardware-scoped `keyd` profile (`/etc/keyd/nuobida-60.conf` matching USB ID `342d:e50e`) turns `CapsLock` into `overload(nav, capslock)` so tapping keeps normal `CapsLock` while holding `CapsLock` exposes an inverted-T arrow cluster (`I/J/K/L`), `U/O` (`Home/End`), `[/]` (`PageUp/PageDown`), `Esc` (`` ` ``), `Backspace` (`Delete`), `P` (`PrintScreen`), `F1..F12`, and media/brightness keys—combining natively with `Super`/`Ctrl`/`Alt`/`Shift` while leaving the laptop's 100% keyboard untouched.
   - Shared ergonomic aliases in `bindings.lua` (`Super+'` Quake console, `Super+Alt+R/C/X` screenrecord/colorpicker/OCR, `Super+[/]` window width, `Super+Ctrl+M` display toggles) work identically on both keyboards.
3. **Liquid Glass Dynamic Island + Native Qt6 Companion App**:
   - Native QML notch floating at top-center (`SurfaceHost.qml` hardens layer surfaces across clamshell/suspend monitor transitions), featuring custom **HS** monogram branding, **Focus Mode** (`Super + Alt + F`), hardware telemetry (`CPU`, `RAM`, `GPU`, `Disk`), **OpenCode v2** & **LM Studio** (`llama-server`) model telemetry + compact activity capsule, **icon-only tabs**, and **KDE Connect** live phone status, battery ring, and connect/disconnect/call peek banners.
   - Companion Qt6 Quick desktop/CLI utility (`apps/dynamic-island`) pinned to the dock (`480x484` floating card) and Flow Launcher (`restart-island`) to inspect, revive, or restart the shell in one keystroke.
4. **Always-On RNNoise Mic Noise Cancellation + Persistent Unmute Guardian**:
   - Standalone PipeWire filter-chain client (`mic-noise-cancellation.service`) running `librnnoise_ladspa` over the internal digital mic and exposing `rnnoise_mic_source` as `@DEFAULT_AUDIO_SOURCE@`.
   - `mic-guardian.py` D-Bus `PrepareForSleep` listener + patched WirePlumber `state-routes.lua` guarantee the physical microphone never wakes up muted after boot or lid resume.
5. **Fluid Multi-Touch Gestures, Clamshell Power & Micro Default Editor**:
   - 2-finger pinch zoom (`cursor_zoom`), 3-finger window travel/move, and 4-finger workspace swipes (`input.lua`).
   - AC clamshell / battery hibernation (`lid-close-handler.sh` + `30-laptop-lid.conf`) and Acer Nitro DAMX fan profiles.
   - `micro` configured as default `.txt`, `.text`, and `.md` opener via Omarchy TUI (`micro.desktop` + `user-text-extension.xml`).

---

## 💻 Hardware Profile

Engineered on and tuned for:
- **Laptop**: Acer Nitro V 15 (ANV15-52) — Intel Core i9-13900H + NVIDIA RTX Laptop GPU (Hybrid Prime)
- **Internal Display**: 1920x1080 @ 180Hz (`eDP-1`) with 1.25x scaling
- **External Display**: 1920x1080 @ 240Hz (`HDMI-A-1`) with 1.25x scaling
- **Keyboards**: UK English (`gb`) built-in 100% keyboard + NUOBIDA 60% mechanical USB keyboard (`342d:e50e`)

---

## 📂 File-by-File Catalog & Directory Guide

### 1. Hyprland Window Manager (`configs/hypr/`)

| File | Target Destination | Description |
|---|---|---|
| `hyprland.lua` | `~/.config/hypr/hyprland.lua` | Entry point loading Omarchy defaults, personal Lua modules, and floating rule for `^dynamic-island$` (`480x484`). |
| `bindings.lua` | `~/.config/hypr/bindings.lua` | GlazeWM shortcuts, Flow Launcher, Focus Mode (`Super+Alt+F`), Smart Close (`Super+W`), `Alt+Z`/`Alt+X` Universal Phone Back/Forward, and shared 60% aliases. |
| `input.lua` | `~/.config/hypr/input.lua` | UK English (`gb`) layout, 250ms/35Hz repeat, sloppy focus, natural touchpad scroll, and 2/3/4-finger gestures. |
| `monitors.lua` | `~/.config/hypr/monitors.lua` | Explicit refresh rates (`eDP-1` 180Hz, `HDMI-A-1` 240Hz) and 1.25 fractional scaling. |
| `looknfeel.lua` | `~/.config/hypr/looknfeel.lua` | 2px inner/outer gaps, 1px borders (`#bea3c7` active), 6px rounding, and 0.91 terminal opacity. |
| `autostart.lua` | `~/.config/hypr/autostart.lua` | Startup unmute hook alongside PipeWire/systemd initialization. |
| `xdph.conf` & `hyprsunset.conf` | `~/.config/hypr/` | XDG Desktop Portal Hyprland screen-share tokens and neutral color profile. |
| `scripts/lid-close-handler.sh` | `~/.config/hypr/scripts/` | Clamshell on external AC power; true SSD hibernation on battery. |
| `scripts/setup-system-lid-hibernation.sh` | `~/.config/hypr/scripts/` | Root helper configuring `logind` lid rules and NVIDIA power services. |

---

### 2. Omarchy Shell, Branding & Flow Launcher (`configs/omarchy/`)

| File | Target Destination | Description |
|---|---|---|
| `shell.json` | `~/.config/omarchy/shell.json` | Top `lobo.islands` bar (`hous.menu`, left `omarchy.tray`, opaque bar), disabled stock `omarchy.menu`, and pinned `dynamic-island` + `org.kde.kdeconnect.app` dock apps. |
| `shell.toml` | `~/.config/omarchy/shell.toml` | Bar typography configuration. |
| `dynamic-island.json` | `~/.config/omarchy/dynamic-island.json` | Runtime notch config (`hoverExpand`, `priority: ["agent", "music", "timer", "recording"]`, `idleClock`). |
| `extensions/omarchy-menu.jsonc` | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Flow Launcher keywords: `wp`, `kill`, `remind`, `gh`, `setup`, and `restart-island` (`fix-island`, `revive-island`). |
| `plugins/hous.menu/` | `~/.config/omarchy/plugins/hous.menu/` | Top-left bar widget displaying `hs_logo.png` (left-click menu, right-click terminal). |
| `themes/vantablack/colors.toml` | `~/.config/omarchy/themes/vantablack/colors.toml` | Obsidian background (`#08080a`), cyan accent (`#4cc9f0`), lavender borders (`#bea3c7`). |

---

### 3. Dynamic Island Plugin

Located in `configs/omarchy/plugins/io.github.ofa14-prog.dynamic-island/`:

| Component | Target Destination | Description |
|---|---|---|
| `Island.qml` & `SurfaceHost.qml` | `.../Island.qml`, `.../SurfaceHost.qml` | Liquid Glass notch + dynamically hosted Wayland layer surfaces (`recoverSurface()`, placeholder screen filtering for clamshell/wake resilience). |
| `pages/CompactView.qml` | `.../pages/CompactView.qml` | Compact pill with custom `HS` monogram (`assets/hs_logo.png`), live model mini-capsule + split-pill rendering, and KDE Connect green connection dot. |
| `pages/HomePage.qml` & `pages/TabStrip.qml` | `.../pages/` | Live hardware telemetry cards, responsive KDE Connect phones card (single/dual/offline + battery ring), and icon-only tab strip. |
| `bin/dynamic-island-hardware` & `services/HardwareService.qml` | `.../bin/`, `.../services/` | Low-overhead Python/QML telemetry stream (CPU, RAM, NVIDIA GPU, NVMe). |
| `agents/opencode/dynamic-island.js` & `bin/dynamic-island-{scan,transcript}` | `.../agents/`, `.../bin/` | OpenCode v2 `ServerPlugin` bridge, interactive TTY filtering, and SQLite live transcript feed. |
| `bin/dynamic-island-lmstudio` & `icons/brand/lmstudio.svg` | `.../bin/`, `.../icons/brand/` | `/proc` tick + `/api/v1/models` probe with GUI load/unload controls in `AgentPage.qml` & `AgentBridge.qml`. |
| `bin/dynamic-island-phones` & `services/PhoneService.qml` | `.../bin/`, `.../services/` | Zero-idle-CPU session D-Bus watcher for KDE Connect reachability, battery, SFTP mount state, and incoming call peek banners. |

---

### 4. Dynamic Island Companion App (`apps/dynamic-island/`)

| File | Target Destination | Description |
|---|---|---|
| `apps/dynamic-island/` (C++17 / Qt6 Quick) | Built via `./bin/install-local` -> `~/.local/bin/dynamic-island` | Native floating diagnostic/recovery GUI (`480x484`) + CLI (`--status --json`, `--restart`, `--revive`, `--toggle`, `--focus`, `--reset`), desktop file, and SVG icon. |

---

### 5. Custom Utilities & Scripts (`scripts/bin/`)

| File | Target Destination | Description |
|---|---|---|
| `omarchy-kill-active` | `~/.local/bin/omarchy-kill-active` | Bound to `Super + W`. Cleanly closes focused browser/terminal/VS Code/multi-window sibling windows, protects `omarchy-shell`/`waybar`/`antigravity`, and gracefully falls back to `SIGTERM`. |
| `omarchy-toggle-focus-mode` | `~/.local/bin/omarchy-toggle-focus-mode` (symlinked as `focus-mode`) | Bound to `Super + Alt + F`. Toggles Dynamic Island `hoverExpand` in `dynamic-island.json`. |
| `mic-guardian.py` | `~/.local/bin/mic-guardian.py` | Listens to `logind` `PrepareForSleep` on D-Bus to keep PipeWire `@DEFAULT_AUDIO_SOURCE@` & ALSA `Dmic0` unmuted across boot and resume. |
| `mic-noise-cancellation-set-default` | `~/.local/bin/mic-noise-cancellation-set-default` | Waits for `rnnoise_mic_source` and assigns it as the default PipeWire input source. |
| `kdeconnect-sftp-automount` | `~/.local/bin/kdeconnect-sftp-automount` | Keeps Android KDE Connect SFTP cleanly mounted on reconnect/resume and clears stale `sshfs` mounts (`KDECONNECT_DEVICE_ID` configurable). |
| `omarchy-launch-docker-tui`, `sklauncher`, `damx` | `~/.local/bin/` | Floating `lazydocker` launcher, Java-aware SKlauncher wrapper, and DivAcerManagerMax CLI wrapper. |

---

### 6. Audio Pipeline & Systemd Services

| File | Target Destination | Description |
|---|---|---|
| `configs/pipewire/mic-noise-cancellation.conf` & `90-rnnoise-mic.conf` | `~/.config/pipewire/` | Standalone PipeWire filter-chain running `librnnoise_ladspa` (`noise_suppressor_stereo`) exposing `rnnoise_mic_source`. |
| `configs/wireplumber/scripts/device/state-routes.lua` | `~/.config/wireplumber/scripts/device/state-routes.lua` | Overrides WirePlumber route persistence so audio input routes never save or restore `mute: true`. |
| `configs/systemd/user/mic-guardian.service` | `~/.config/systemd/user/mic-guardian.service` | Keeps `mic-guardian.py` active across the graphical session. |
| `configs/systemd/user/mic-noise-cancellation.service` | `~/.config/systemd/user/mic-noise-cancellation.service` | Starts RNNoise PipeWire host and sets `rnnoise_mic_source` as default input on login. |
| `configs/systemd/user/kdeconnect-indicator.service` | `~/.config/systemd/user/kdeconnect-indicator.service` | Keeps KDE Connect tray indicator visible in `omarchy.tray`. |
| `configs/systemd/user/kdeconnect-sftp-automount.service` | `~/.config/systemd/user/kdeconnect-sftp-automount.service` | Maintains phone SFTP mount automatically on reconnect & wake. |
| `configs/systemd/system/30-laptop-lid.conf` | `/etc/systemd/logind.conf.d/30-laptop-lid.conf` | `HandleLidSwitch=hibernate`, `HandleLidSwitchExternalPower=ignore`, `HandleLidSwitchDocked=ignore`. |
| `scripts/hardware/acer-nitrosense/install.sh` | Provisioning Script | Builds `linuwu-sense-dkms-git` and sets up `damx-daemon.service`. |

---

### 7. 60% Keyboard Layer, Micro MIME & Developer Configs

| File | Target Destination | Description |
|---|---|---|
| `configs/keyd/nuobida-60.conf` | `/etc/keyd/nuobida-60.conf` | Scoped to NUOBIDA 60% (`342d:e50e`). Maps `CapsLock` hold to `nav` (`I/J/K/L` arrows, `U/O` Home/End, `[/]` PgUp/Dn, `Esc=\``, `Bksp=Del`, `P=SysRq`, `1..==F1..F12`, media/brightness). |
| `desktop-entries/micro.desktop` & `configs/mime/user-text-extension.xml` | `~/.local/share/{applications,mime/packages}/` | Sets `micro` (`omarchy-launch-tui micro %F`) as default handler for `.txt`, `.text`, and `.md`. |
| `configs/foot/foot.ini` & `configs/ghostty/config` | `~/.config/{foot,ghostty}/` | Minimal JetBrainsMono Nerd Font 8pt terminals with CSI-u bindings and translucent styling. |
| `configs/starship.toml` & `configs/fastfetch/` | `~/.config/` | Cyberpunk powerline prompt + Fastfetch HUD featuring Unicode HS block art (`hs_logo.txt`). |
| `configs/bash/bashrc.additions` | Appended to `~/.bashrc` | PATH additions (`~/.local/bin`, `~/.bun/bin`, `~/.opencode/bin`, `~/.dotnet/tools`, `~/.lmstudio/bin`), aliases, and login `fastfetch`. |
| `configs/antigravity/settings.json` & `configs/mcp/mcp_config.template.json` | `~/.config/Antigravity/User/` & `~/.gemini/` | IDE settings and sanitized MCP template (`<YOUR_GITHUB_PERSONAL_ACCESS_TOKEN>` placeholder). |

---

## ⌨️ Complete Shortcuts & Gestures Cheat Sheet

### 🪟 GlazeWM Tiling & Window Management
| Shortcut | Action |
|---|---|
| `Alt + Enter` | Launch Terminal |
| `Alt + Shift + Q` | Close Window |
| `Alt + H/J/K/L` or `Alt + Arrows` | Focus left / down / up / right window |
| `Alt + Shift + H/J/K/L` or `Arrows` | Swap window in direction |
| `Alt + 1 .. 9` / `Alt + Shift + 1 .. 9` | Focus / Move window to workspace 1–9 |
| `Alt + A` / `Alt + S` / `Alt + D` | Previous / Next / Recent workspace |
| `Alt + F` / `Alt + V` / `Alt + Shift + Space` | Fullscreen / Toggle split / Toggle floating |
| `Alt + U` / `Alt + P` / `Alt + O` / `Alt + I` | Resize window width & height directly |
| `Alt + R` | Modal resize submap (`HJKL`/Arrows, `Esc`/`Enter` to exit) |
| `Alt + Shift + P` | Pause/resume keybindings (gaming/VMs) |

### ⌨️ Universal Navigation, Ergonomics & 60% Collaboration
| Shortcut | Action | Description |
|---|---|---|
| `Alt + Z` / `Alt + X` | **Universal Phone Back / Forward** | `Esc` on layers, `Ctrl+Alt+Left/Right` in JetBrains/Obsidian, `Ctrl+Alt+-`/`Ctrl+Shift+-` in VS Code/Antigravity, `Alt+Left/Right` elsewhere |
| `CapsLock` *(hold, 60% kbd)* | **Nav Layer (`keyd`)** | `I/J/K/L` Arrows, `U/O` Home/End, `[]` PgUp/PgDn, `Esc` `` ` ``, `Bksp` Del, `P` PrtSc, `1..=` F1–F12, `M , . / ; '` Media/Brightness |
| `Super + '` / `Super + Shift + '` | Quake Console *(60% alias)* | Toggle / move window to `special:qconsole` |
| `Super + [` / `Super + ]` | Window Width *(60% alias)* | Restore / save window width |
| `Super + Alt + R / C / X` | Capture Tools *(60% alias)* | Screenrecording / Hyprpicker / OCR text capture |
| `Super + Ctrl + M` / `Super + Ctrl + Alt + M` | Display Toggle *(60% alias)* | Toggle internal monitor / mirror mode |
| `Super + W` | **Smart Close / Stop** | Closes focused window cleanly (multi-window safe for browsers/terminals/VS Code) |
| `Ctrl + Shift + Escape` | Task Manager | Launches floating `btop` |
| `Super + Shift + S` | Region Screenshot | `omarchy-capture-screenshot` / `omasnap` |

### 🚀 Flow Launcher & Dynamic Island
| Trigger | Action | Description |
|---|---|---|
| `Shift + Space` | Universal Search | Flow Launcher styled Omarchy search (`wp`, `kill`, `remind`, `gh`, `setup`, `restart-island`) |
| `Ctrl + Alt + Space` / `Super + Alt + I` | Dynamic Island | Expand / collapse top notch |
| `Super + Alt + F` | **Focus Mode** | Toggle hover-to-expand on Dynamic Island |
| `Super + Alt + T` | Notch Timer | Open timer tab directly |
| `Ctrl + Alt + V` / `Ctrl + Alt + D` | Clipboard / Top Bar | Open clipboard panel / toggle Islands top bar |

### 🖐 Multi-Touch Trackpad Gestures
| Gesture | Action |
|---|---|
| **2-Finger Pinch** | Live cursor magnifier zoom (`cursor_zoom`) |
| **3-Finger Horizontal** | Travel between windows (`scroll_move`) |
| **3-Finger Vertical** | Grab & move focused window (`move`) |
| **4-Finger Horizontal** | 1:1 animated workspace switch |
| **4-Finger Vertical** | Swap window vertically |

---

## 🛠 Installation Guide

### Option A: Automated Install
```bash
git clone https://github.com/SHoussam/MyMarchy.git ~/MyMarchy
cd ~/MyMarchy
chmod +x install.sh
./install.sh --with-system
```
*(Omit `--with-system` for user-space-only installation without `sudo`.)*

### Option B: Autonomous AI Agent Install
Give `prompt.md` to your coding agent:
```text
Please read ~/MyMarchy/prompt.md and execute the complete setup out of the box.
```

### Option C: Manual Step-by-Step
See [`prompt.md`](prompt.md) for the exact Arch Linux `pacman` + AUR package list, KDE Connect `ufw` firewall rules, system service setup, and verification checklist.

---

## 🔍 Verification & Health Checks

```bash
# 1. Hyprland syntax
hyprctl reload && hyprctl configerrors

# 2. keyd 60% profile & daemon
sudo keyd check /etc/keyd/nuobida-60.conf && systemctl is-active keyd.service

# 3. User services & default RNNoise microphone
systemctl --user is-active mic-guardian.service mic-noise-cancellation.service kdeconnect-indicator.service kdeconnect-sftp-automount.service
pactl get-default-source

# 4. Dynamic Island telemetry & companion app health
dynamic-island --status --json
python3 ~/.config/omarchy/plugins/io.github.ofa14-prog.dynamic-island/bin/dynamic-island-hardware

# 5. Micro default MIME & logind lid configuration
xdg-mime query default text/plain && xdg-mime query default text/markdown
systemd-analyze cat-config systemd/logind.conf | grep HandleLidSwitch
```

---

## 📄 License
MIT License. Created by [SHoussam](https://github.com/SHoussam). Contributions and tweaks are welcome!
