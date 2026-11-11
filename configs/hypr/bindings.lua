-- =============================================================================
-- Houssam's Personal Keybindings (1:1 GlazeWM v3.10.1 + Flow Launcher + Dynamic Island)
-- Layered cleanly alongside Omarchy's built-in SUPER shortcuts.
-- =============================================================================

-- 1. Flow Launcher Equivalent: Shift + Space opens Universal Search (Cyan Dark Flow Launcher style)
o.bind("SHIFT + SPACE", "Flow Launcher Universal Search", "omarchy-shell shell toggle io.github.hominluo.launcher")

-- 2. Dynamic Island & Top Bar Controls
o.bind_toggle("CTRL + ALT + D", "Toggle top bar (Islands)", "bar")
o.bind("CTRL + ALT + SPACE", "Toggle Dynamic Island expand/collapse", "omarchy-shell -q dynamicisland toggle")
o.bind("SUPER + ALT + I", "Toggle Dynamic Island", "omarchy-shell -q dynamicisland toggle")
o.bind("SUPER + ALT + T", "Open Dynamic Island Timer", "omarchy-shell -q dynamicisland open timer")
o.bind("SUPER + ALT + F", "Toggle Dynamic Island Focus Mode", (os.getenv("HOME") or "") .. "/.local/bin/omarchy-toggle-focus-mode")
o.bind("CTRL + ALT + V", "Clipboard Manager (Dynamic Island)", { panel = "omarchy.clipboard" })

-- 3. Launch Terminal: Alt + Enter (GlazeWM)
o.bind("ALT + RETURN", "Terminal (GlazeWM)", o.launch_terminal())

-- 4. Close Active Window & Exit / System Menu: Alt + Shift + Q & Alt + Shift + E (GlazeWM)
o.bind("ALT + SHIFT + Q", "Close window (GlazeWM)", hl.dsp.window.close())
o.bind("ALT + SHIFT + E", "System / Exit menu (GlazeWM)", { menu = "system" })

-- 5. Reload Hyprland Config: Alt + Shift + R (GlazeWM)
o.bind("ALT + SHIFT + R", "Reload Hyprland config", "hyprctl reload")

-- 6. Focus Window in Direction: Alt + H/J/K/L and Alt + Arrows
o.bind("ALT + H", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("ALT + L", "Focus on right window", hl.dsp.focus({ direction = "r" }))
o.bind("ALT + K", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("ALT + J", "Focus on below window", hl.dsp.focus({ direction = "d" }))
o.bind("ALT + LEFT", "Focus on left window", hl.dsp.focus({ direction = "l" }))
o.bind("ALT + RIGHT", "Focus on right window", hl.dsp.focus({ direction = "r" }))
o.bind("ALT + UP", "Focus on above window", hl.dsp.focus({ direction = "u" }))
o.bind("ALT + DOWN", "Focus on below window", hl.dsp.focus({ direction = "d" }))

-- 7. Move / Swap Window in Direction: Alt + Shift + H/J/K/L and Alt + Shift + Arrows
o.bind("ALT + SHIFT + H", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("ALT + SHIFT + L", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.bind("ALT + SHIFT + K", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("ALT + SHIFT + J", "Swap window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("ALT + SHIFT + LEFT", "Swap window to the left", hl.dsp.window.swap({ direction = "l" }))
o.bind("ALT + SHIFT + RIGHT", "Swap window to the right", hl.dsp.window.swap({ direction = "r" }))
o.bind("ALT + SHIFT + UP", "Swap window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("ALT + SHIFT + DOWN", "Swap window down", hl.dsp.window.swap({ direction = "d" }))

-- 8. Direct Window Resize: Alt + U (-width), Alt + P (+width), Alt + O (+height), Alt + I (-height)
o.bind("ALT + U", "Shrink window width", hl.dsp.window.resize({ x = -38, y = 0, relative = true }), { repeating = true })
o.bind("ALT + P", "Expand window width", hl.dsp.window.resize({ x = 38, y = 0, relative = true }), { repeating = true })
o.bind("ALT + O", "Expand window height", hl.dsp.window.resize({ x = 0, y = 21, relative = true }), { repeating = true })
o.bind("ALT + I", "Shrink window height", hl.dsp.window.resize({ x = 0, y = -21, relative = true }), { repeating = true })

-- 8b. GlazeWM Resize Mode (Alt + R) & Pause Mode (Alt + Shift + P)
o.bind("ALT + R", "Enter GlazeWM resize mode (HJKL/Arrows, Esc/Enter to exit)", hl.dsp.submap("resize"))
hl.define_submap("resize", function()
  hl.bind("H", hl.dsp.window.resize({ x = -38, y = 0, relative = true }), { repeating = true })
  hl.bind("LEFT", hl.dsp.window.resize({ x = -38, y = 0, relative = true }), { repeating = true })
  hl.bind("L", hl.dsp.window.resize({ x = 38, y = 0, relative = true }), { repeating = true })
  hl.bind("RIGHT", hl.dsp.window.resize({ x = 38, y = 0, relative = true }), { repeating = true })
  hl.bind("K", hl.dsp.window.resize({ x = 0, y = -21, relative = true }), { repeating = true })
  hl.bind("UP", hl.dsp.window.resize({ x = 0, y = -21, relative = true }), { repeating = true })
  hl.bind("J", hl.dsp.window.resize({ x = 0, y = 21, relative = true }), { repeating = true })
  hl.bind("DOWN", hl.dsp.window.resize({ x = 0, y = 21, relative = true }), { repeating = true })
  hl.bind("ESCAPE", hl.dsp.submap("reset"))
  hl.bind("RETURN", hl.dsp.submap("reset"))
end)

o.bind("ALT + SHIFT + P", "Pause all keybindings (Alt+Shift+P to resume)", hl.dsp.submap("pause"))
hl.define_submap("pause", function()
  hl.bind("ALT + SHIFT + P", hl.dsp.submap("reset"))
end)

-- 9. Tiling / Floating / Fullscreen / Minimize States
o.bind("ALT + V", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("ALT + SHIFT + SPACE", "Toggle window floating/tiling", hl.dsp.window.float({ action = "toggle" }))
o.bind("ALT + T", "Pseudo window", hl.dsp.window.pseudo())
o.bind("ALT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
o.bind("ALT + M", "Minimize window to the dock", "omarchy-hyprland-window-minimize")

-- 10. Workspaces 1..9: Alt + 1..9 to focus, Alt + Shift + 1..9 to move window & follow
for workspace = 1, 9 do
  local key = "code:" .. tostring(workspace + 9)
  o.bind("ALT + " .. key, "Switch to workspace " .. workspace, o.workspaces.focus(workspace))
  o.bind("ALT + SHIFT + " .. key, "Move window to workspace " .. workspace, o.workspaces.move_window(workspace))
end

-- 11. Cycle Next / Previous / Former Workspace: Alt + S (next), Alt + A (prev), Alt + D (recent)
o.bind("ALT + S", "Next workspace", hl.dsp.focus({ workspace = "m+1" }))
o.bind("ALT + A", "Previous workspace", hl.dsp.focus({ workspace = "m-1" }))
o.bind("ALT + D", "Former workspace", hl.dsp.focus({ workspace = "previous_per_monitor" }))

-- 12. Move Current Workspace to Monitor in Direction: Alt + Shift + A/F/D/S
-- Note: ALT + SHIFT + D replaces Omarchy's default "Download Video from Web App"
o.bind("ALT + SHIFT + A", "Move workspace to left monitor", o.workspaces.move_to_monitor("l"))
o.bind("ALT + SHIFT + F", "Move workspace to right monitor", o.workspaces.move_to_monitor("r"))
o.rebind("ALT + SHIFT + D", "Move workspace to up monitor", o.workspaces.move_to_monitor("u"))
o.bind("ALT + SHIFT + S", "Move workspace to down monitor", o.workspaces.move_to_monitor("d"))

-- 13. Mouse Drag / Resize with Alt + Left/Right Click
o.bind("ALT + mouse:272", "Move window", hl.dsp.window.drag(), { mouse = true })
o.bind("ALT + mouse:273", "Resize window", hl.dsp.window.resize(), { mouse = true })

-- 14. Windows-style Utilities & Force Kill
-- Ctrl + Shift + Esc: Task Manager (btop in floating window)
o.bind("CTRL + SHIFT + ESCAPE", "Task Manager (btop)", { tui = "btop", focus = true })

-- Win + Shift + S: Snipping Tool Screenshot (replaces default Google Maps shortcut)
o.rebind("SUPER + SHIFT + S", "Screenshot (Snipping Tool)", "omarchy-capture-screenshot")

-- Win + W: Close focused window / stop active application cleanly (exits window for Chromium, terminals, and VS Code)
o.rebind("SUPER + W", "Close window or stop active app", (os.getenv("HOME") or "") .. "/.local/bin/omarchy-kill-active")

-- 15. Laptop Lid Switch Handling
-- Plugged in: Clamshell single-screen on external display (keep running)
-- On battery: True SSD Hibernation (save state and power off)
o.rebind("switch:on:Lid Switch", nil, (os.getenv("HOME") or "") .. "/.config/hypr/scripts/lid-close-handler.sh", { locked = true })
o.rebind("switch:off:Lid Switch", nil, "omarchy-hyprland-monitor-clamshell", { locked = true })

-- =============================================================================
-- 16. Universal "Phone Back & Forward" (ALT + Z / ALT + X)
-- =============================================================================
local function send_shortcut_once(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

local function has_exclusive_layer()
  for _, layer in ipairs(hl.get_layers()) do
    if layer.mapped and layer.interactivity == 1 then
      return true
    end
  end
  return false
end

local function universal_nav(direction)
  return function()
    local window = hl.get_active_window()
    if has_exclusive_layer() or not window then
      if direction == "back" then
        send_shortcut_once("", "ESCAPE")
      end
      return
    end

    local class = (window.class or ""):lower()

    if class:find("jetbrains", 1, true) or class:find("obsidian", 1, true) then
      send_shortcut_once("CTRL ALT", direction == "back" and "LEFT" or "RIGHT")
    elseif class:find("antigravity", 1, true) or class:find("code", 1, true) then
      if direction == "back" then
        send_shortcut_once("CTRL ALT", "minus")
      else
        send_shortcut_once("CTRL SHIFT", "minus")
      end
    else
      send_shortcut_once("ALT", direction == "back" and "LEFT" or "RIGHT")
    end
  end
end

o.bind("ALT + Z", "Universal Back", universal_nav("back"))
o.bind("ALT + X", "Universal Forward", universal_nav("forward"))

-- =============================================================================
-- 17. 60%-Friendly Shared Aliases (work identically on 60% and 100% keyboards)
-- =============================================================================
o.bind("SUPER + apostrophe", "Toggle Quake console (60% alias)", hl.dsp.workspace.toggle_special("qconsole"))
o.bind("SUPER + SHIFT + apostrophe", "Move window to Quake console (60% alias)", hl.dsp.window.move({ workspace = "special:qconsole", follow = false }))

o.bind("SUPER + ALT + R", "Screenrecording (60% alias)", "omarchy-capture-screenrecording --stop-recording || omarchy-menu toggle trigger.capture.screenrecord")
o.bind("SUPER + ALT + C", "Color picker (60% alias)", "pkill hyprpicker || hyprpicker -a")
o.bind("SUPER + ALT + X", "Extract text (OCR) from screenshot (60% alias)", "omarchy-capture-text")

o.bind("SUPER + bracketleft", "Restore window width (60% alias)", "omarchy-hyprland-window-width restore")
o.bind("SUPER + bracketright", "Save window width (60% alias)", "omarchy-hyprland-window-width save")

o.bind("SUPER + CTRL + M", "Toggle laptop display (60% alias)", "omarchy-hyprland-monitor-internal toggle")
o.bind("SUPER + CTRL + ALT + M", "Toggle laptop display mirroring (60% alias)", "omarchy-hyprland-monitor-internal-mirror toggle")



