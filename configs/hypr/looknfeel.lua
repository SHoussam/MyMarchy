-- Houssam's Look & Feel (1:1 match with GlazeWM gaps, borders, and terminal opacity)
-- GlazeWM: inner_gap = 4px (2px per side), outer_gap = 2px, border = 1px (#bea3c7 / #a1a1a1)

o.transparent_window("foot", "0.91 0.91")
o.transparent_window("org.wezfurlong.wezterm", "0.91 0.91")
o.transparent_window("com.mitchellh.ghostty", "0.91 0.91")

hl.config({
  general = {
    gaps_in = 2,
    gaps_out = 2,
    border_size = 1,
    ["col.active_border"] = "rgba(bea3c7ff)",
    ["col.inactive_border"] = "rgba(a1a1a1ff)",
  },

  decoration = {
    rounding = 6,
  },
})
