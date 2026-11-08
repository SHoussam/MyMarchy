-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- Acer Nitro V 15 (ANV15-52): Ensure internal display runs at 1920x1080 @ 180Hz (hardware max)
hl.monitor({ output = "eDP-1", mode = "1920x1080@180", position = "0x0", scale = 1.25 })

local omarchy_monitor_scale = "auto"
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@240", position = "auto", scale = 1.25 })

local omarchy_gdk_scale = 1
hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
