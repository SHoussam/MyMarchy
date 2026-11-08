-- Extra autostart processes.
-- Ensure microphone is unmuted and active on session startup
o.launch_on_start("sh -c 'sleep 1 && wpctl set-mute @DEFAULT_AUDIO_SOURCE@ 0 && amixer -c 1 sset Dmic0 cap 2>/dev/null'")

