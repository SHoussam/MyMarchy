# Changelog

## 1.20.6

- Artwork cache bounded against a media player that sends many large artwork URLs: at most 8
  URLs and 32 Mi characters wait for the helper (oldest dropped first; the playing track's art is
  always the newest), a URL longer than the helper would ever read (22 Mi characters, its 16 MiB
  source cap as base64) is refused before it is queued, and results are keyed by a short hash
  instead of the URL itself.
- A promo video in the README (animated preview, full MP4 in `docs/`), made with Remotion.

## 1.20.5

- New README screenshots and preview: every page in all four looks (Dark, Light, and both with
  Liquid Glass), on a clean wallpaper, with demo sessions, a demo track and demo files.

## 1.20.4

- HyprGlass: smooth rounded corners. The glass follows the island's anti-aliased shape again
  (`mask_mode = "alpha"` with `mask_feather`) instead of a blur region, which HyprGlass draws as
  whole-pixel rectangles (stepped corners, and a plain box past 64 rectangles). The music's
  ambient glow, which alpha mode would turn into glass, now has a layer of its own under the
  island (`dynamic-island-glow`) while HyprGlass is on.
- Light Liquid Glass with HyprGlass: a light haze instead of the grey milky look (suggested
  config: about half the white tint and lift), still readable over dark windows.

## 1.20.3

- Fixed the suggested HyprGlass config, which could keep Hyprland from starting (black screen
  after login). It loaded the plugin only `if not hl.plugin.hyprglass`; Hyprland re-runs the
  config after loading a plugin and unloads any config plugin a pass leaves out, so the plugin
  was loaded and unloaded forever (thousands of config passes in uwsm's 30 s start window, then
  the session was killed). The plugin is now registered on every pass, and only if its file
  exists. If you copied the old snippet, replace it (README).
- HyprGlass detection no longer waits for its shaders to be "ready": they are only compiled at
  the first glass drawn, so after a fresh start the island never turned the glass on.

## 1.20.2

- HyprGlass only runs with the Liquid Glass theme: the island turns HyprGlass's layer glass on
  while it runs with Liquid Glass and off when the theme is switched off or the island goes away
  (`dynamic-island-hyprglass on|off`); the suggested Hyprland config now starts it off.
- Fixed: the plugin was not detected while it had nothing to draw (its status says "inactive"
  then); detection now checks that it is loaded, matches Hyprland and has its shaders ready.

## 1.20.1

- HyprGlass: the island asks for glass exactly on its rounded shape and bubbles (a blur region,
  `ext-background-effect-v1`; set `mask_mode = "region"` for the layer, see the README), so the
  music's ambient glow is back around the island and its bubble as plain light instead of being
  turned into glass. The open music page keeps more of its colors (a 60 % wash).

## 1.20.0

- Real Liquid Glass with the HyprGlass Hyprland plugin (optional): when it is loaded, Hyprland
  draws refracting glass behind the island and the island steps back, with no smoky or milky
  tint of its own, no painted rim or shadow, and the music colors kept inside the glass instead
  of an outer glow. Detected live (`bin/dynamic-island-hyprglass`), and its dark / light look
  follows the island's appearance. Setup in the README.
- The island's layer surface is no longer a full-width 720 px band: it is the island's open
  width plus a margin, and short while closed (tall only while open). Less for the compositor to
  blur or glass every frame, with or without HyprGlass.

## 1.19.1

- Tab switching with the wheel follows the scroll: each notch (or the same distance on a
  touchpad) is one tab, so a slow scroll moves one at a time and a fast or long one skips
  several, stopping at the ends. Replaces 1.19.0's one-tab-per-gesture pause.

## 1.19.0

- Scroll on the open island to switch tabs: down (or right) is the next tab, up (or left) the
  previous; it stops at the ends. Deltas add up and each step is followed by a short pause, so a
  touchpad swipe or a fast spin moves one tab at a time. Only while the pointer is on the open
  island; the compact island still sets the volume, and the agent page's live feed keeps its own
  scroll. Not while typing a message or answering a permission prompt.
- Shelf: up/down wheel switches tabs there too; sideways scrolling moves through the files.
- Timer: the wheel no longer changes the minutes (use − / + or the presets), so it switches tabs
  like everywhere else.

## 1.18.2

- Liquid Glass: gentler edge light in both appearances. Buttons, tiles, cards and rows now carry
  one hairline ring (`shaders/rim.frag`) that is brightest along the top and fades smoothly down
  the sides, instead of two clipped bright rims that stopped in hard steps halfway down; the top
  wash is softer, and the island's own outer rim is wider and dimmer.

## 1.18.2

- Album art and shelf images are no longer decoded in the shell. A media player's artwork URL
  is untrusted, and Qt's `sourceSize` does not bound a progressive JPEG's coefficient
  allocation, so a tiny file declaring a huge size could exhaust the whole shell. The new
  `bin/dynamic-island-art` reads the original in its own process (byte cap; HTTPS/HTTP with a
  timeout; the URL over stdin), checks the header without decoding (JPEG, PNG, WebP, GIF, BMP,
  AVIF or HEIC, at most 4096x4096), decodes under ImageMagick limits, a memory ulimit and a
  timeout, and writes a 256x256 PNG to `$XDG_RUNTIME_DIR/dynamic-island/art`.
  `components/ArtCache.qml` runs it once per URL; `Art` and the color quantizer only ever load
  that PNG. Artwork that fails the checks shows the placeholder.

## 1.18.1

- Liquid Glass: hovering a button, tile, card, session row, shelf item or menu row no longer lays
  a lighter highlight over it. The glass body swells a few pixels in place with a soft
  water-balloon overshoot (and gives a little when pressed); only the body moves, so text and
  icons stay sharp and nothing around it shifts. Normal theme unchanged.

## 1.18.0

- Session scan (`bin/dynamic-island-scan`): finds the agent sessions open right now from /proc
  and the agents' own state (Claude Code's session records, Antigravity's log, Codex's rollout
  file), so sessions show up without waiting for a hook: at start (after a shell restart) and
  from a new refresh button on the AI page. Read-only; only processes on a terminal count.
- The AI page's agent bar always offers every installed agent (running ones first), so an
  agent's controls are reachable even while it is not running.

## 1.17.3

- Removed the sideways shake on notifications (permission, question, agent error).
- Closed Liquid Glass island: no more swell toward the pointer; hovering only grows it slightly,
  as in the Normal theme.

## 1.17.2

- The AI page favours no agent. It opens on the agent you picked, else the one working or
  waiting on you, else the only agent with a live session; otherwise on a neutral overview of
  every agent (a card each with its state, usage, Connect and a new-session button; click a
  card for its page). Before, an idle island always opened on the default agent (Claude), even
  when only another agent was open.

## 1.17.1

- AI page with no agent running: the agent bar lists every installed agent (not just the
  default one); picking one switches the page, its usage, Connect and "New session" to it.
  While agents run, the bar still lists only the running ones.

## 1.17.0

- **Light appearance**: a white island with near-black content, iOS light system colors, light
  popups and fills. Liquid Glass is now a separate switch that works in both appearances:
  dark glass (smoky) or light glass (clear, with a faint dark outline; milkier while open so
  text stays readable over dark windows).
- Theme picker on Home: Dark / Light, plus a Liquid Glass on/off switch.
- Everything that assumed a black island now follows the theme: text, fills, borders, popups,
  the tab bar, glass finishes, the music accent and backdrop, and near-white agent marks
  (Codex, OpenCode…), which turn near-black on white.

## 1.16.0

- Liquid Glass reaches every surface: buttons, shortcut tiles, usage cards, session rows, the
  live feed, the message box, shelf tiles, the player chip and picker, the permission card, the
  tab bar and the theme/language popups get a glass finish (`components/GlassSheen.qml`: a soft
  top highlight, a bright rim along the upper curve, a faint edge; brighter on hover). Popups
  turn translucent. Plain rectangles, no shaders; Normal theme unchanged.

## 1.15.3

- Liquid Glass: the swell toward the pointer answers at once (stiff spring on its position,
  90 ms rise) instead of trailing behind; it still lets go softly. No extra work per frame.

## 1.15.2

- Normal theme no longer borrows Liquid Glass motion: the tab selection is a plain pill that
  slides as a whole (both edges on one spring, no stretching) and cannot be grabbed. The drop
  stretch and the draggable lens are Liquid Glass only.

## 1.15.1

- Closed island: fixed the uneven sliding on hover. The lean toward the pointer measured the
  pointer against the island's already-leaned position, so every lean leaned it again.
  Under glass it no longer leans at all: the glass swells softly toward the pointer instead (a
  smooth bump in the shader's distance field, so it stretches but never tears) and flows back
  when the pointer leaves.
- Tab bar: grab the selection lens and drag it; it follows the pointer, stretching like liquid,
  and lands on the nearest tab when released. Clicking a tab works as before. The selection's
  two edges now run on a small spring integrator (only while moving).

## 1.15.0

- Theme picker on Home (next to the flag): Normal or Liquid Glass.
- Tab bar: the selection is a liquid glass lens. Its leading edge springs ahead and the trailing
  edge follows, so it stretches like a drop toward the new tab, flashes, and settles. The
  shader draws only inside the tab bar and only while the island is open. The plain pill
  (Normal theme) moves the same way.

## 1.14.1

- Bubbles no longer look dimmed under Liquid Glass: they sat below the island's glass layer, so
  the glass was painted over their icons. With glass on they are drawn above it.
- The music's ambient colors now live in the glass: a faint left-to-right film across it and
  colored light gathered at its edges, following the sound, instead of a glow showing through
  from underneath.

## 1.14.0

- **Liquid Glass** (dark): the island, its split halves and the bubbles are drawn as one glass
  surface by a custom shader (`shaders/liquid.frag`): translucent tint over a real backdrop blur,
  edge lensing and a specular highlight that follows the pointer. Bodies merge through a smooth
  minimum, so bubbles pinch off and flow back like droplets and split halves part with a bridge.
  The glass flexes ("jelly") and lights up on open, close, peek, split and touch.
- Backdrop blur for the island's layer only, at runtime (`bin/dynamic-island-glass`): blur on,
  every window opted out, original values saved and restored with `"glass": false`; reapplied
  after Hyprland reloads its config. No config file is written.
- Home: usage cards for every installed agent (Antigravity included), running ones first.
- Shelf: **Copy all** puts every shelf file on the clipboard as files (right-click: paths).

## 1.13.0

- Home: quick-timer buttons removed; roomier spacing. Usage rings for every running agent (a card
  per agent with its mark, 5-hour and weekly rings; click to open it), the battery next to the
  clock, and shortcuts as a 3-column grid of tiles.
- Shelf: Ctrl+V on the open shelf adds what you copied; clicking the shelf bubble or the empty
  shelf no longer pastes (the bubble opens the shelf). Click a file to copy it to the clipboard
  as a file (✓ on the tile), double-click to open it.
- Notifications that want you (permission, question, agent error) give the island a short,
  light horizontal shake instead of a vertical dip; ordinary banners don't.
- Hover only grows the island; a click opens it, leaving closes it as before (`hoverExpand`
  now defaults to `false`).
- Usage is kept per agent (several at once).

## 1.12.1

- Split island: the halves act on their own. Hovering a half opens that half's agent page; the
  half under the pointer lights up in its agent's color (no whole-island grow or lean).
- Answering Antigravity's permission on the island no longer focuses its terminal: the key goes
  to agy's window through Hyprland's `send_shortcut` (tmux stays in the background; the old
  focus-and-type path is only a fallback for older Hyprland). Claude, Codex and OpenCode never
  moved focus.

## 1.12.0

- Closed island: Antigravity's spinner stayed off-center and spilled past the island's edge
  (braille glyphs overflow their font cell). Braille spinners are now drawn as real dots on a
  2×4 grid, centered.
- The agent tab is now **AI**: the running agent's mark and name, only marks when several run
  (two, then "…"), "AI" when none does. The AI tab always keeps the mark; the name gives way.
- The agent bar switches between the agents that are *running* (a live session), not the ones
  installed; the page opens on the most urgent one and goes back to it when the island closes.
  The choice is no longer written to the config.
- Two different agents working at once split the closed island into two halves (gap springs
  open, merges back seamlessly), one agent per side, side kept while it works; click a half to
  open that agent.
- Antigravity usage (5-hour / weekly) from `agy -p /usage`; usage follows the agent on screen.
- "New session" starts the agent on screen.

## 1.11.0

- **Antigravity CLI** (`agy`) replaces Gemini CLI: live sessions and states, the live feed from
  its transcript, the message box, and permission Allow · Always (this conversation) · Deny from
  the island. agy reports its prompt only in its own log, and ignores a hook's "allow", so the
  island watches that log (matched to the hook's step) and answers with the prompt's key in
  agy's terminal (tmux, or its own window matched by process). Answers given in the terminal,
  and Esc there, close the island's card. Hooks go to `~/.gemini/config/hooks.json`; the hook
  never blocks or prints a decision for agy (a failing hook would block the tool call).
- Gemini CLI hooks removed (`dynamic-island-agent-setup --remove gemini` cleans up older
  installs; `--remove all` includes it). Gemini stays as a branding-only profile for Omarchy's
  default agent.
- **Agent bar**: with several supported agents installed, the agent page's mark opens sideways
  onto all of them; picking one switches the page, tab, colors, Connect and "New session" (a
  non-default agent opens in Omarchy's agent terminal). Dots show other agents' activity.

## 1.10.2

- New preview image (closed island with bubbles, Home, permission, Music and Timer) and a
  screenshot gallery in the README (`docs/screenshots/`). Third-party artwork is blurred.

## 1.10.1

- Privacy: a message typed in the agent message box is never a command-line argument (those are
  readable by every local user through the process list). The island writes it to
  `bin/dynamic-island-send` on stdin, which hands it on through stdin as well
  (`tmux load-buffer -` + `paste-buffer`, `wtype -`). "Copy paths" on the shelf also goes
  through stdin.

## 1.10.0

- Recommended setup: on a bar other than Islands (`lobo.islands`), or with widgets in the bar
  center, the Home page offers one-click setup (`dynamic-island-bar-setup --recommended`:
  adds/enables the Islands bar, clears the center, backs up `shell.json`; `--undo` restores).
  Nothing changes until it is pressed; the card can be dismissed.
- On slim bars (Omarchy's stock bar) the closed island keeps a small margin instead of filling
  the bar's height.

## 1.9.0

- Languages: English (now the default), Spanish, Russian and Turkish, picked from a flag button
  on the Home page (saved to the config). Translations live in `components/Translations.js`;
  counts use the right plural form per language. Tabs adapt to long labels (smaller font,
  then no icon, then an ellipsis).
- Security: no rich text anywhere untrusted text is shown. The permission page's command/diff
  preview is plain text line by line; ShimmerText escapes its input. `tests/check_qml.py`
  fails on any `Text` without a safe `textFormat`.
- The shelf only deletes clipboard files it saved itself (no `..` paths).
- Restart uses `omarchy-restart-shell` only.
- Bounded reads: clipboard file lists (64 KiB, 24 entries), pasted images (50 MiB) and text
  (10 MiB); the agent feed's JSON is capped at 1 MiB.
- `dynamic-island-bar-setup` writes backups and restores through a temp file and rename, so a
  symlink at the destination is replaced, never written through.
- CI: manifest, QML text safety, translation coverage, script syntax.
- README: full dependency list (all part of Omarchy; `cava` and the timer sound optional) and
  a note that enabling the plugin changes nothing on the system.

## 1.8.2

- Music backdrop: opening onto the music page brings the colors in with the card (no black
  first, no pop); tab switches cross-fade quickly (280 ms, ease-out).

## 1.8.1

- Music backdrop: no more square-cornered color block while the island morphs (the blur drew
  past the card, and the colors kept fading while the shape shrank). The colors now appear
  once the card has finished opening, vanish the instant it closes, and cross-fade softly
  (900 ms) between tabs.

## 1.8.0

- Music page backdrop: open on the music tab, the card fills with the artwork's colors as
  large blurred blobs drifting slowly (like Apple Music); the outer glow is only for the
  closed island now. Off with `"ambient": false`.

## 1.7.1

- Players: the one that starts playing takes over, even over an earlier pick, so switching
  apps switches the island (art, colors, controls). Several playing: the newest wins.
- No artwork: neutral colors instead of the previous track's (the color extractor kept its
  last result).
- Agent feed: compact keeps short "… +N" summaries; expanded shows every line of every
  output and full commands, wrapped. Expanding starts at once and eases out (260 ms).

## 1.7.0

- Player switcher on the music page: with several media players, a chip next to the transport
  buttons names the one shown and opens a list to pick the one to follow (kept until it
  closes; "Automatic" follows whatever plays). Right-click or scroll it for the next one.
- Agent live feed: scrollable (wheel or drag), follows new output only while at the bottom,
  a jump-to-newest button, and an expand button for a taller feed with more output per
  command. Terminal color codes are stripped from output.

## 1.6.2

- Fixed the squashed island after a manual shell restart: a starting bar grows in steps
  (26 → 30 → its real height), and the first step was taken as final. The island now waits
  until the bar's size has been the same for three probes in a row before dropping in.

## 1.6.1

- The refresh button on Home now restarts the Omarchy shell on click; right-click only clears
  the island.

## 1.6.0

- No more squashed island after a shell restart: it stays hidden until the bar has been
  measured (re-measured every 300 ms until found), then drops in from above as a circle and
  springs open into the island. A bar that reloads keeps the last fit instead of the fallback.

## 1.5.1

- The ambient light glows only around the player: the island when music is in the middle (or
  the music page is open), otherwise the music bubble. Softer backlight that swells and settles
  with the sound instead of flashing.

## 1.5.0

- Ambient light: an artwork-colored glow around the island while music plays, pulsing with
  the sound through cava (optional; `services/AudioLevel.qml`). cava runs only while music
  plays and the island is on screen. Config: `ambient`, `ambientAudio`.
- `omarchy-shell dynamicisland status` reports the ambient state and audio level.

## 1.4.0

- Message box on the agent page (Claude Code, Codex): send a message to the watched session
  from the island (`bin/dynamic-island-send`). tmux panes get it in the background; otherwise
  the session's own window is focused and typed into, and only when it is found exactly.
- `dynamic-island-focus --exact`: no fallback window.

## 1.3.0

- Live feed on the agent page for Claude Code and Codex: the last prompts, replies, tool calls
  and their output, read from the session transcript (`bin/dynamic-island-transcript`) only
  while the page is open. Click a session row to watch it when several run.
- Shelf bubble: while the shelf holds anything it shows as a side bubble with the item count
  and a fill ring. Clicking it shelves the clipboard: copied files as they are, a copied image
  or text saved as a file (removed again when it leaves the shelf). Alone, it never takes the
  center unless you double-click it there.
- "Add clipboard" on the shelf page, and a click on the empty shelf does the same.

## 1.2.0

- Double-click a bubble to swap it with the center; the center activity takes that bubble's
  place, and the arrangement is kept while those activities stay live.
- The music activity shows only while something plays and leaves as soon as it is paused or
  the player closes.
- Refresh button on Home: click clears a stuck island, right-click restarts the Omarchy shell
  (`omarchy-shell dynamicisland reset | restartShell`).
- Agent state labels now update on every event (they could stick, e.g. "Idle" while the agent
  worked).
- Agent state machine rewritten and documented trigger by trigger in
  services/AgentBridge.qml: tool failures, API errors, manual compaction, questions
  (AskUserQuestion), permissions answered in the terminal, and interrupts (read from the
  transcript, since no hook reports them) are all handled.
- Shortcuts: Files opens through Omarchy's launcher, an "Opening…" banner confirms the click,
  and repeated clicks are ignored for a moment.

## 1.1.0

- Follows Omarchy's default coding agent: name, mark, colors and spinner on the agent page,
  tab, shortcut and banners. New `agent` setting to override it.
- Codex (hooks, allow/deny), OpenCode (plugin, allow/always/deny) and Gemini CLI (hooks, live
  sessions; permissions shown) join Claude Code. `bin/dynamic-island-agent-setup` connects any of
  them; `dynamic-island-claude-setup` still works.
- Sharp rendering at fractional scales: no offscreen pass for the island's content, hinted text,
  icons painted as vectors in their final color.
- Fewer false alerts: headless runs (`claude -p`) are ignored, a compaction no longer reads as
  "ready", only "waiting for you" notifications raise a banner, track changes and charging are
  debounced, and hook events are acknowledged so none get lost.
- `omarchy-shell dynamicisland sessions` / `events` for troubleshooting.

## 1.0.0

- Dynamic Island service for the Omarchy shell: compact, peek and expanded states with spring
  physics, blur-morph content transitions, pointer lean, press sink and shake.
- Live activities: Claude Code, screen recording, timer/stopwatch, music; extra activities split
  into independent bubbles on the right and left.
- Pages: Home (default-app shortcuts, usage and battery rings, quick timers), Music, Claude Code,
  Timer, Shelf; Claude permission alerts with Allow / Always / Deny.
- Claude Code bridge over a private unix socket, with installer/remover for the hooks.
- Island size and position measured from the running bar.
- English and Turkish interface.
