pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Dynamic Island theme singleton — dynamically synced with the active Omarchy
// theme (via qs.Commons.Color + ~/.local/state/omarchy/current/theme/colors.toml).
QtObject {
  id: theme

  // Set from config. Springs become short fades and nothing wobbles or shakes.
  property bool reduceMotion: false

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string currentThemeColorsPath: home + "/.local/state/omarchy/current/theme/colors.toml"

  // Extra semantic tokens parsed from colors.toml (green, orange, yellow, red, etc.)
  property string parsedMode: "dark"
  property color parsedGreen: "#30D158"
  property color parsedOrange: "#FF9F0A"
  property color parsedRed: "#FF453A"
  property color parsedBlue: "#0A84FF"
  property color parsedCyan: "#64D2FF"
  property color parsedMagenta: "#BF5AF2"
  property color parsedDarkerBg: "#101019"
  property color parsedLighterBg: "#313244"

  function parseThemeColors(raw) {
    var lines = String(raw || "").split("\n")
    var g = "", o = "", y = "", r = "", b = "", c = "", m = "", db = "", lb = "", mode = ""
    for (var i = 0; i < lines.length; i++) {
      var modeMatch = lines[i].match(/^\s*mode\s*=\s*["']?(light|dark)["']?/i)
      if (modeMatch) { mode = modeMatch[1].toLowerCase(); continue }
      var kv = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})["']?/)
      if (!kv) continue
      var k = kv[1], v = kv[2]
      if (k === "green" || (k === "color2" && !g)) g = v
      else if (k === "orange") o = v
      else if (k === "yellow" || (k === "color3" && !y)) y = v
      else if (k === "red" || (k === "color1" && !r)) r = v
      else if (k === "blue" || (k === "color4" && !b)) b = v
      else if (k === "cyan" || (k === "color6" && !c)) c = v
      else if (k === "magenta" || (k === "color5" && !m)) m = v
      else if (k === "darker_background" || (k === "dark_background" && !db)) db = v
      else if (k === "lighter_background") lb = v
    }
    parsedMode = mode || (Commons.Color.bar.background.hslLightness > 0.5 ? "light" : "dark")
    if (g) parsedGreen = g
    if (o || y) parsedOrange = o || y
    if (r) parsedRed = r
    if (b) parsedBlue = b
    if (c) parsedCyan = c
    if (m) parsedMagenta = m
    if (db) parsedDarkerBg = db
    if (lb) parsedLighterBg = lb
  }

  property FileView themeColorsFile: FileView {
    id: themeColorsFile
    path: theme.currentThemeColorsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: theme.parseThemeColors(text())
  }

  property Connections colorConnections: Connections {
    target: Commons.Color
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onForegroundChanged() { themeColorsFile.reload() }
    function onAccentChanged() { themeColorsFile.reload() }
    function onShellValuesChanged() { themeColorsFile.reload() }
  }

  // Automatic light/dark detection from active Omarchy theme
  readonly property bool themeLight: parsedMode === "light" || Commons.Color.bar.background.hslLightness > 0.52

  // Active island background color (defaults to active Omarchy theme bar background)
  property color bg: Commons.Color.bar.background
  Behavior on bg { ColorAnimation { duration: 240; easing.type: Easing.OutCubic } }

  // Light appearance (light theme or explicit override)
  property bool light: themeLight
  // Liquid Glass theme on: surfaces get GlassSheen, popups turn translucent.
  property bool glass: false

  readonly property color themeAccent: Commons.Color.accent
  readonly property color themeFg: Commons.Color.bar.text

  // Content ink: uses the active Omarchy theme's foreground color while ensuring readability
  readonly property color inkColor: {
    if (light) return themeFg.hslLightness < 0.55 ? themeFg : "#1d1d1f"
    return themeFg.hslLightness > 0.45 ? themeFg : "#ffffff"
  }
  function ink(a) { return Qt.rgba(inkColor.r, inkColor.g, inkColor.b, a) }
  readonly property color fg: inkColor
  readonly property color secondary: ink(light ? 0.68 : 0.68)
  readonly property color tertiary: ink(light ? 0.48 : 0.46)
  readonly property color fill: Qt.tint(
    ink(light ? 0.07 : 0.09),
    Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, light ? 0.035 : 0.045)
  )
  readonly property color fillHover: Qt.tint(
    ink(light ? 0.12 : 0.16),
    Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, light ? 0.06 : 0.08)
  )
  readonly property color fillPressed: Qt.tint(
    ink(light ? 0.18 : 0.22),
    Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, light ? 0.10 : 0.12)
  )
  readonly property color hairline: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, light ? 0.16 : 0.14)
  // The island's own edge, and borders of popups and cards.
  readonly property color edge: Qt.rgba(themeAccent.r, themeAccent.g, themeAccent.b, light ? 0.24 : 0.20)
  // Popup menus (language, theme, player list).
  readonly property color popup: glass
    ? Qt.rgba(bg.r, bg.g, bg.b, light ? 0.94 : 0.90)
    : (light ? Qt.darker(bg, 1.04) : Qt.lighter(bg, 1.25))
  // Small chips over content (e.g. the remove button on a shelf tile).
  readonly property color chip: light ? Qt.darker(bg, 1.12) : Qt.lighter(bg, 1.45)
  // Text on a solid colored (prominent) button.
  readonly property color onTint: themeAccent.hslLightness > 0.6 ? "#111116" : "#ffffff"
  readonly property color focusRing: themeAccent

  // Semantic colors mapped to the active Omarchy theme
  readonly property color orange: parsedOrange
  readonly property color green: parsedGreen
  readonly property color red: parsedRed
  readonly property color blue: themeAccent
  readonly property color cyan: parsedCyan
  readonly property color claude: "#D97757"
  readonly property color claudeGlow: "#F0B49B"

  // The Omarchy system font (`omarchy-font-current`), set by Island.qml.
  property string font: "JetBrainsMono Nerd Font"
  readonly property string mono: font
  readonly property string icons: "JetBrainsMono Nerd Font"

  readonly property string claudeLogo: Qt.resolvedUrl("../icons/brand/claude.svg")

  // Spring presets.
  readonly property real openSpring: 3.6
  readonly property real openDamping: 0.27
  readonly property real closeSpring: 4.6
  readonly property real closeDamping: 0.36
  readonly property real resizeSpring: 4.4
  readonly property real resizeDamping: 0.62
  readonly property real snapSpring: 6.0
  readonly property real snapDamping: 0.42
  readonly property real mass: 1.0

  function ms(value) { return reduceMotion ? Math.min(value, 90) : value }
}
