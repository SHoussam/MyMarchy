-- Houssam's Input Configuration (Acer Nitro V 15 ANV15-52 + GlazeWM feel)
-- UK English (gb) keyboard, fast repeat (250ms / 35Hz), sloppy focus, no cursor warp.

hl.config({
  input = {
    kb_layout = "gb",
    kb_options = "omarchy:shift_caps_compose",

    repeat_rate = 35,
    repeat_delay = 250,
    numlock_by_default = true,

    -- GlazeWM: focus_follows_cursor = true
    follow_mouse = 1,
    mouse_refocus = false,
    sensitivity = 0.2,

    touchpad = {
      natural_scroll = true,
      clickfinger_behavior = true,
      scroll_factor = 0.4,
      tap_to_click = true,
      disable_while_typing = true,
    },
  },

  -- Fine-tune gesture mechanics
  gestures = {
    workspace_swipe_distance = 250,          -- Distance in px to swipe workspace
    workspace_swipe_cancel_ratio = 0.2,      -- Less drag needed before gesture commits
    workspace_swipe_min_speed_to_force = 20, -- Fast swipe triggers immediately
    workspace_swipe_create_new = true,       -- Swiping past the last workspace creates a new one
    scrolling = {
      move_snap_to_grid = true,              -- Snap cleanly to application columns
      move_snap_cursor = true,               -- Snap cursor to newly focused application
    },
  },

  -- GlazeWM: cursor_jump.enabled = false
  cursor = {
    no_warps = true,
  },
})

-- =============================================================================
-- Touchpad Gestures (Hyprland 0.56+ Native Gesture Engine)
-- =============================================================================

-- --- 2 FINGERS: Live Desktop Zoom ---

-- 1. Two-finger pinch: Smooth live cursor zoom in / out (Desktop Magnifier)
hl.gesture({
  fingers = 2,
  direction = "pinch",
  action = "cursor_zoom",
  mode = "live",
})

-- --- 3 FINGERS: Horizontal Application Travel & Window Grab ---

-- 2. Three-finger horizontal swipe: Travel / scroll between applications along the horizontal path
hl.gesture({
  fingers = 3,
  direction = "horizontal",
  action = "scroll_move",
})

-- 3. Three-finger vertical swipe: Grab active window and travel / reposition it
hl.gesture({
  fingers = 3,
  direction = "vertical",
  action = "move",
})

-- --- 4 FINGERS: Workspace Switching & Window Swapping ---

-- 4. Four-finger horizontal swipe: 1:1 smooth animated workspace switching (1 -> 2 -> 3...)
hl.gesture({
  fingers = 4,
  direction = "horizontal",
  action = "workspace",
})

-- 5. Four-finger vertical swipe: Swap active window up / down
hl.gesture({
  fingers = 4,
  direction = "up",
  action = function() hl.dispatch(hl.dsp.window.swap({ direction = "u" })) end,
})

hl.gesture({
  fingers = 4,
  direction = "down",
  action = function() hl.dispatch(hl.dsp.window.swap({ direction = "d" })) end,
})
