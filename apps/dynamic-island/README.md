# Dynamic Island

Omarchy desktop companion & instant recovery app for the Dynamic Island shell plugin (`io.github.ofa14-prog.dynamic-island`).

Inspect live Wayland layer attachment (`dynamic-island`, `dynamic-island-glow`), IPC health, active screen/mode, and Focus Mode — and revive or restart the shell in one click, keyboard press, launcher Search query, or CLI command.

## Keyboard Shortcuts

| Key | Action |
| --- | --- |
| `Space` / `Enter` / `R` | Restart Dynamic Island (`omarchy-restart-shell`) & confirm layer attachment |
| `V` | Revive Wayland layer surface (`recoverSurface`), escalating to restart if unreachable |
| `T` | Toggle expanded / compact Dynamic Island card |
| `F` | Toggle Focus Mode (`hoverExpand` on/off) |
| `Z` | Reset Dynamic Island alerts & sessions to compact |
| `S` | Refresh layer & IPC status |
| `?` | Show or hide the keyboard shortcuts overlay |
| `Q` / `Esc` | Close overlay or quit window |

## CLI

```sh
dynamic-island --status [--json]   # Inspect layer attachment, IPC status, and Focus Mode
dynamic-island --restart           # Restart Omarchy shell and wait until surface attaches
dynamic-island --revive            # Soft-rebuild layer surface (escalates to restart if needed)
dynamic-island --toggle            # Expand / collapse Dynamic Island
dynamic-island --focus             # Toggle Focus Mode
dynamic-island --reset             # Clear stuck alerts/sessions
```

## Build & Test

```sh
./bin/build
./bin/test
./bin/install-local   # Installs into ~/.local/{bin,share/applications,share/icons}
./bin/install         # Builds Arch package via pkgbuild/PKGBUILD (makepkg -fsi)
```
