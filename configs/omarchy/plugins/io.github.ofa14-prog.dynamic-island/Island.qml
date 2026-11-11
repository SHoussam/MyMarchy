import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.UPower
import qs.Commons as Commons
import "components"
import "services"
import "pages"
import "components/Agents.js" as Agents

// Dynamic Island for the Omarchy bar.
//
// One black shape, three sizes:
//   compact  – sits in the bar; idle clock or a live activity's leading/trailing
//   peek     – a brief wider banner (track change, agent finished, charging…)
//   expanded – the full card; pages for home, music, agent, timer and shelf
// Alerts (an agent permission request, a finished timer) expand on their own
// and hold the island open until answered.
//
// ═══════════════════════════════════════════════ WHAT THE ISLAND REACTS TO
//
//   trigger                                  island reaction
//   ──────────────────────────────────────────────────────────────────────
//   agent permission request                 opens on the permission page
//                                            (autoExpandPermission) or banner;
//                                            stays open until answered
//   permission answered on the island        closes + "Allowed" / "Denied" banner
//   permission answered in the terminal      closes quietly
//   agent turn finished (Stop)               "<agent> finished" banner
//                                            (peekOnAgentDone), ✓ in compact for 8 s
//   agent turn failed (StopFailure)          "<agent> stopped on an error" banner
//   agent waiting for you (question,         "<agent> is waiting for you" banner,
//   elicitation, idle prompt)                pulsing dot in compact until you act
//   Antigravity at its permission prompt     same as a permission request: the
//                                            island opens on it; answers are
//                                            pressed as keys in agy's terminal
//   agent turn interrupted / quiet           no banner; compact falls back
//   timer finished                           opens on the timer, shakes, chimes
//   new track (settled 1.5 s, playing)       banner (peekOnTrackChange)
//   charger plugged in (settled 1.5 s)       "Charging" banner
//   screen recording starts/stops            red activity appears/disappears
//   file dragged over the island             opens the shelf
//   message typed on the agent page          sent to the session's prompt
//                                            (tmux, or its terminal is focused
//                                            and typed into); banner after
//   music playing                            ambient glow in the artwork's
//                                            colors, moving with the sound
//                                            when cava is installed
//   shell (re)start                          hidden until the bar's size has
//                                            settled (it grows in steps),
//                                            then drops in as a circle and
//                                            springs open (intro)
//   files on the shelf                       shelf bubble (count + fill ring);
//                                            Ctrl+V on the open shelf shelves
//                                            the clipboard
//   pointer hover                            grows slightly (opens only with
//                                            hoverExpand); click opens
//   pointer leaves (opened by pointer)       closes after collapseDelay
//
//   Agent session states and the events behind them are documented in
//   services/AgentBridge.qml.
Item {
  id: island

  // Host injection (unused but accepted so the shell can hand them over).
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)).replace(/\/$/, "") : u
  }
  readonly property string home: Quickshell.env("HOME") || ""

  // ================================================================ config

  readonly property var defaults: ({
    hoverExpand: true,      // true: open on hover when touching the top-connected notch
    hoverDelay: 80,
    collapseDelay: 420,
    reduceMotion: false,
    idleClock: true,
    clockFormat: "ddd HH:mm",
    language: "en",         // en | es | ru | tr | auto (follow the system)
    locale: "",
    priority: ["agent", "recording", "timer", "music"],
    compactHeight: "auto",
    topOffset: 0,
    expandedWidth: 550,
    appearance: "auto",     // auto | dark | light (auto follows active Omarchy theme)
    color: "auto",          // island color, dark appearance ("auto" follows Color.bar.background)
    lightColor: "auto",     // island color, light appearance ("auto" follows Color.bar.background)
    glassOpacityLight: 0.42, // how milky the light glass is (0..1; low = clear)
    screen: "",
    peekOnTrackChange: false,
    peekOnAgentDone: false,
    autoExpandPermission: false,
    hideOnFullscreen: true,
    glass: true,            // Liquid Glass: translucent, blurred, light on the edges, liquid merges
    glassOpacity: 0.84,     // how rich the theme glass tint is (0..1)
    ambient: true,          // artwork-colored glow around the island while music plays
    ambientAudio: true,     // …breathing with the sound (needs cava)
    shortcuts: [],
    showStats: true,
    agent: "",
    agentQuietSeconds: 180
  })
  property var userConfig: ({})
  function cfg(key) { return userConfig[key] !== undefined ? userConfig[key] : defaults[key] }

  FileView {
    id: configFile
    path: island.home + "/.config/omarchy/dynamic-island.json"
    atomicWrites: true
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { island.userConfig = JSON.parse(text()) || {} } catch (e) { console.warn("dynamic-island: bad config", e) } }
    onLoadFailed: island.userConfig = ({})
  }

  Binding { target: Theme; property: "reduceMotion"; value: island.cfg("reduceMotion") === true }

  // English unless set; "auto" follows the system language when the island
  // has it (en, es, ru, tr) and falls back to English.
  readonly property string language: {
    var l = String(cfg("language") || "en")
    if (l === "auto") {
      var sys = (Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "").substring(0, 2)
      l = sys
    }
    return I18n.codes.indexOf(l) !== -1 ? l : "en"
  }
  Binding { target: I18n; property: "lang"; value: island.language }
  readonly property string localeName: cfg("locale") || I18n.localeFor(language)

  // Saves one setting to the user's config file (only on an explicit choice
  // in the UI, such as the language picker); every other key is kept.
  function setConfig(key, value) {
    var next = {}
    for (var k in userConfig) next[k] = userConfig[k]
    next[key] = value
    userConfig = next
    configFile.setText(JSON.stringify(next, null, 2) + "\n")
  }
  readonly property string appearanceCfg: String(cfg("appearance") || "auto")
  readonly property bool lightMode: appearanceCfg === "light" ? true
    : appearanceCfg === "dark" ? false
    : Theme.themeLight
  readonly property string colorCfg: String((lightMode ? cfg("lightColor") : cfg("color")) || "auto")
  Binding { target: Theme; property: "light"; value: island.lightMode }
  Binding {
    target: Theme
    property: "bg"
    value: island.colorCfg === "auto"
      ? Commons.Color.bar.background
      : Qt.color(island.colorCfg)
  }
  Binding { target: Theme; property: "glass"; value: island.glassOn }

  // Text follows the Omarchy system font (omarchy font set …).
  Process {
    id: fontProbe
    command: ["omarchy-font-current"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: { var f = text.trim(); if (f) Theme.font = f }
    }
  }

  // Omarchy's default agent, unless the island's own `agent` setting overrides it.
  property string omarchyAgent: ""
  readonly property string agentId: cfg("agent") || omarchyAgent
  FileView {
    path: island.home + "/.config/omarchy/defaults/agent"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: island.omarchyAgent = text().trim()
  }
  // ---- agents installed here (the ones the island connects to), for the
  // usage cards on Home.
  property var installedAgents: []
  Process {
    id: agentProbe
    running: true
    command: ["sh", "-c", "for a; do id=${a%%:*}; bin=${a#*:}; if [ \"$id\" = lmstudio ]; then { command -v \"$bin\" || command -v lms || [ -x \"$HOME/.lmstudio/bin/lms\" ]; } >/dev/null 2>&1 && echo \"$id\"; else command -v \"$bin\" >/dev/null 2>&1 && echo \"$id\"; fi; done", "sh"]
      .concat(Agents.connectable.map(id => id + ":" + Agents.get(id).bin))
    stdout: StdioCollector { onStreamFinished: island.installedAgents = text.split("\n").filter(l => l !== "") }
  }
  Timer { interval: 120000; repeat: true; running: true; onTriggered: if (!agentProbe.running) agentProbe.running = true }
  // Usage cards: running agents first (most urgent first), then the other
  // installed ones, then the island's own agent if it is neither.
  readonly property var usageAgents: {
    var out = runningAgents.slice()
    installedAgents.forEach(id => { if (out.indexOf(id) === -1) out.push(id) })
    if (agentId && out.indexOf(agentId) === -1) out.push(agentId)
    return out
  }

  // ---- agents that are running right now (a live session), most urgent
  // first: waiting on you, then working, then idle. They drive the AI tab's
  // label, the agent bar on its page and the split compact island.
  readonly property var runningAgents: {
    void agents.revision
    var rank = id => {
      var mine = agents.sessionList.filter(x => x.agent === id)
      if (agents.pending.some(r => r.agent === id) || mine.some(x => agents.needsYou(x))) return 0
      if (mine.some(x => agents.isBusy(x))) return 1
      return 2
    }
    var ids = []
    agents.sessionList.forEach(x => { if (x.agent && ids.indexOf(x.agent) === -1) ids.push(x.agent) })
    return ids.sort((a, b) => rank(a) - rank(b))
  }
  // Agents with a turn in progress (or waiting on you): two or more split
  // the compact island in half, one agent per side.
  readonly property var workingAgents: {
    void agents.revision
    return runningAgents.filter(id => agents.pending.some(r => r.agent === id)
      || agents.sessionList.some(x => x.agent === id && (agents.isBusy(x) || agents.needsYou(x))))
  }
  readonly property bool splitIsland: workingAgents.length >= 2 && primary === "agent"
  // Which agent sits on which half. An agent keeps its side for as long as
  // it works; a newcomer takes the free side. Never more than two.
  property var splitOrder: []
  onWorkingAgentsChanged: {
    var keep = splitOrder.filter(id => workingAgents.indexOf(id) !== -1)
    workingAgents.forEach(id => { if (keep.indexOf(id) === -1) keep.push(id) })
    keep = keep.slice(0, 2)
    if (JSON.stringify(keep) !== JSON.stringify(splitOrder)) splitOrder = keep
  }
  // The gap between the two halves springs open and closed; while it is
  // open the island is drawn as two pills (CompactView's halves) instead of
  // one shape. Only in compact: opening the island always starts whole.
  property real splitGap: splitIsland && mode === "compact" && introDone ? 8 : 0
  Behavior on splitGap {
    enabled: !Theme.reduceMotion
    SpringAnimation { spring: 4; damping: 0.38; epsilon: 0.05 }
  }
  readonly property bool halvesOn: mode === "compact" && (splitIsland || splitGap > 0.05)
  // The agent the AI page shows: the one picked in its bar while it still
  // runs, else the most urgent running one, else the island's agent.
  property string viewAgent: ""
  onModeChanged: {
    if (mode === "compact") viewAgent = ""
    glassModeMotion()
  }
  // The agents the AI page's bar offers: the running ones; with none
  // running, every installed agent (so you can still pick one, see its
  // usage, connect it or start a session of it).
  // Every installed agent stays reachable: running ones first (most urgent
  // first), then the rest.
  readonly property var barAgents: {
    var out = runningAgents.slice()
    usageAgents.forEach(id => { if (out.indexOf(id) === -1) out.push(id) })
    return out
  }
  // Which agent the AI page shows. Nobody is favoured:
  //   the one you picked in its bar or overview (until the island closes);
  //   else the agent that is working or waiting on you (most urgent);
  //   else the only agent with a live session;
  //   else "" — the neutral overview of every agent.
  readonly property string pageAgent: {
    if (viewAgent && barAgents.indexOf(viewAgent) !== -1) return viewAgent
    if (workingAgents.length) return workingAgents[0]
    if (runningAgents.length === 1) return runningAgents[0]
    return ""
  }
  function showAgent(id) {
    viewAgent = id || ""
    openPage(agents.pending.some(r => r.agent === id) ? "permission" : "agent", "pointer")
  }

  // The agent Omarchy launches by default shapes the agent page: its name,
  // mark, colors and spinner. Sessions of other agents keep their own look.
  readonly property var agent: profile(agentId)
  readonly property string agentName: agentId ? agent.name : I18n.t("Ajan")
  readonly property string agentProduct: agentId ? agent.product : I18n.t("Ajan")
  readonly property color agentColor: agent.color
  readonly property string agentLogo: logoFor(agentId || "claude")
  // Profile with real colors synced with the active Omarchy theme.
  function profile(id) {
    var key = id || agentId || "claude"
    var p = Agents.get(key)
    var out = {}
    for (var k in p) out[k] = p[k]
    if (key === "antigravity" || key === "gemini") {
      out.color = Theme.blue
      out.glow = Qt.lighter(Theme.blue, 1.35)
    } else if (key === "codex" || key === "opencode") {
      out.color = Theme.fg
      out.glow = Qt.lighter(Theme.blue, 1.25)
    } else {
      out.color = Qt.lighter(p.color, 1.0)
      out.glow = Qt.lighter(p.glow, 1.0)
    }
    // Near-white brand colors vanish on a light island: turn near-black.
    if (Theme.light && out.color.hslLightness > 0.82) { out.color = Theme.fg; out.glow = Theme.blue }
    return out
  }
  function logoFor(id) {
    var p = Agents.get(id)
    return p.logo ? Qt.resolvedUrl("icons/brand/" + p.logo + ".svg") : ""
  }

  readonly property var editorLabels: ({
    code: "Code", cursor: "Cursor", zed: "Zed", sublime_text: "Sublime", nvim: "Neovim",
    vim: "Vim", helix: "Helix", hx: "Helix", emacs: "Emacs"
  })

  // Built-in shortcuts follow the system defaults (agent, editor, browser,
  // file manager, terminal) and show each app's own icon. `shortcuts` in the
  // config replaces them.
  // ---- bar center
  // The island sits over the middle of the bar. Omarchy's stock layout keeps
  // widgets there (clock, indicators, weather…), so the Home page offers to
  // move them to the right (bin/dynamic-island-bar-setup: `omarchy bar move`,
  // backed up, `--undo` restores). Nothing moves until that button is pressed.
  // It is designed with the Islands bar (lobo.islands); on another bar the
  // same card offers that setup ("--recommended"), which the user can undo.
  property int barCenterCount: 0
  property string activeBar: ""
  readonly property bool onIslandsBar: activeBar === "lobo.islands"
  readonly property bool barHint: activeBar !== "" && (!onIslandsBar || barCenterCount > 0)
    && cfg("barHintDismissed") !== true
  Process {
    id: barCenterProbe
    running: true
    command: ["sh", "-c",
      "f=\"$HOME/.config/omarchy/shell.json\"; [ -f \"$f\" ] || f=\"${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json\"; " +
      "printf '%s\\n' \"$(jq -r '.bar.layout.center | length' \"$f\" 2>/dev/null)\"; " +
      "omarchy plugin list --json 2>/dev/null | jq -r '[.[] | select(.enabled and ((.kinds // []) | index(\"bar\")))][0].id // \"\"' | head -c 256"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        island.barCenterCount = parseInt(lines[0]) || 0
        island.activeBar = (lines[1] || "").trim()
      }
    }
  }
  Process {
    id: barSetup
    onExited: barCenterProbe.running = true
  }
  function makeRoomInBar() {
    if (barSetup.running) return
    barSetup.command = [pluginDir + "/bin/dynamic-island-bar-setup"].concat(onIslandsBar ? [] : ["--recommended"])
    barSetup.running = true
  }

  readonly property var shortcuts: {
    var list = cfg("shortcuts")
    if (list && list.length) return list
    return [
      { action: "agent", label: agentName, image: agentLogo, icon: "sparkles" },
      { action: "editor", label: editorLabels[apps.editor] || apps.editorName, image: apps.editorIcon, icon: "code" },
      { action: "browser", label: I18n.t("Tarayıcı"), image: apps.browserIcon, icon: "globe" },
      { action: "files", label: I18n.t("Dosyalar"), image: apps.filesIcon, icon: "folder" },
      { action: "terminal", label: I18n.t("Terminal"), image: apps.terminalIcon, icon: "terminal" },
      { action: "screenshot", label: I18n.t("Ekran"), icon: "camera" }
    ]
  }

  // Models hand nested arrays to JS as list wrappers, not Arrays; copy.
  function argv(value) {
    if (!value) return []
    if (typeof value === "string") return ["sh", "-c", value]
    var out = []
    for (var i = 0; i < value.length; i++) out.push(String(value[i]))
    return out
  }

  // A second click on the same shortcut while its app is still starting
  // would open it twice: ignore repeats for a moment.
  property string lastShortcut: ""
  property double lastShortcutAt: 0

  function runShortcut(item) {
    if (!item) return
    var action = item.action || ""
    var key = action + "|" + (item.label || "")
    if (key === lastShortcut && Date.now() - lastShortcutAt < 2000) return
    lastShortcut = key
    lastShortcutAt = Date.now()
    if (action === "stopwatch") { timer.startStopwatch(); openPage("timer"); return }
    if (action === "timer") { timer.startCountdown(Number(item.seconds) || 300); openPage("timer"); return }
    if (action.indexOf("page:") === 0) { openPage(action.substring(5)); return }
    if (action === "agent") agents.newSession()
    else if (action === "editor") apps.openEditor()
    else if (action === "browser") apps.openBrowser()
    else if (action === "files") apps.openFiles()
    else if (action === "terminal") apps.openTerminal()
    else if (action === "screenshot") Quickshell.execDetached(["omarchy-capture-screenshot"])
    else {
      var cmd = argv(item.command)
      if (!cmd.length) { console.warn("dynamic-island: shortcut has no action or command:", JSON.stringify(item)); return }
      Quickshell.execDetached(cmd)
    }
    collapse()
    // Apps take a second or two to show up; say it's coming.
    if (action !== "screenshot")
      peek(item.image ? "app:" + item.image : (item.icon || "arrow-up-right"), I18n.t("Açılıyor"), item.label || "", Theme.fg, 1600)
  }

  // ================================================================ services

  AgentBridge {
    id: agentsSvc
    pluginDir: island.pluginDir
    defaultAgent: island.agentId
    omarchyAgent: island.omarchyAgent
    usageAgent: island.pageAgent
    usageAgents: island.usageAgents
    agentPageShown: island.mode === "expanded" && island.page === "agent"
    quietAfterMs: Math.max(20, Number(island.cfg("agentQuietSeconds")) || 180) * 1000
    onPermissionArrived: request => {
      if (island.cfg("autoExpandPermission")) {
        island.openPage("permission", "alert")
      } else {
        island.peek("agent:" + request.agent, I18n.t("%1 izin istiyor").arg(island.profile(request.agent).name), request.project + " · " + request.tool, island.profile(request.agent).color, 3500)
      }
    }
    onPermissionResolved: (requestId, how) => {
      if (pending.length > 0) return
      if (island.page === "permission") {
        island.collapse()
        if (how === "allow" || how === "always") island.peek("check", I18n.t("İzin verildi"), "", Theme.green, 1300)
        else if (how === "deny") island.peek("x", I18n.t("Reddedildi"), "", Theme.red, 1300)
      }
    }
    onSessionFailed: s => {
      if (island.mode !== "expanded") {
        island.peek("agent:" + s.agent, I18n.t("%1 bir hatayla durdu").arg(island.profile(s.agent).name), s.project + (s.error ? " · " + s.error : ""), Theme.red, 3600, "agent")
      }
    }
    onSessionFinished: s => {
      if (island.cfg("peekOnAgentDone") !== false && island.cfg("peekOnClaudeDone") !== false && island.mode !== "expanded")
        island.peek("agent:" + s.agent, I18n.t("%1 bitirdi").arg(island.profile(s.agent).name), s.project + (s.lastDuration ? " · " + island.duration(s.lastDuration) : ""), island.profile(s.agent).color, 2600, "agent")
    }
    onSessionNeedsInput: (s, message) => {
      if (island.mode === "expanded") return
      var title = (s.state === "notice" ? I18n.t("%1 izin istiyor") : message ? I18n.t("%1 soruyor") : I18n.t("%1 seni bekliyor")).arg(island.profile(s.agent).name)
      var detail = s.state === "notice" ? (s.title || s.project) : (message || s.project)
      island.peek("agent:" + s.agent, title, detail, island.profile(s.agent).color, 4000, "agent")
    }
  }

  MusicService {
    id: musicSvc
    tracking: island.mode === "expanded" && island.page === "music"
    light: island.lightMode
    onTrackChanged: {
      if (island.cfg("peekOnTrackChange") && island.mode === "compact" && island.primary === "music")
        island.peek("music", music.title, music.artist, Theme.fg, 2400, "music")
    }
  }

  TimerService {
    id: timerSvc
    onFinished: {
      island.openPage("timer", "alert")
      island.shake()
      Quickshell.execDetached(["notify-send", "-a", "Dynamic Island", "-i", "alarm-symbolic", I18n.t("Süre doldu"), timer.label || I18n.t("Zamanlayıcı bitti")])
    }
  }

  Connections {
    target: agentsSvc
    function onMessageSent(sessionId, ok) {
      var s = agentsSvc.sessions[sessionId]
      var name = s ? (s.project || island.profile(s.agent).name) : ""
      if (ok) island.peek("agent:" + (s ? s.agent : island.agentId), I18n.t("Mesaj gönderildi"), name, Theme.green, 1500)
      else island.peek("terminal", I18n.t("Gönderilemedi"), I18n.t("Oturumun terminal penceresi bulunamadı"), Theme.red, 2600)
    }
  }

  ShelfService {
    id: shelfSvc
    onPasted: (added, what) => {
      if (added > 0) {
        island.bounce()
        island.peek("shelf", what === "image" ? I18n.t("Görsel rafa eklendi") : what === "text" ? I18n.t("Metin rafa eklendi")
          : added === 1 ? I18n.t("Rafa eklendi") : I18n.t("%1 dosya rafa eklendi").arg(added),
          I18n.t("Rafta: %1").arg(I18n.count(shelfSvc.count, "item")), Theme.blue, 1600, "shelf")
      } else if (what === "known") {
        island.peek("shelf", I18n.t("Zaten rafta"), "", Theme.secondary, 1300, "shelf")
      } else {
        island.openPage("shelf", "pointer")
      }
    }
  }
  DefaultApps { id: appsSvc }
  HardwareService {
    id: hardwareSvc
    active: island.mode === "expanded" && island.page === "home"
  }
  property double phoneGraceUntil: 0
  PhoneService {
    id: phonesSvc
    onDeviceConnected: device => {
      if (Date.now() < island.phoneGraceUntil) return
      var sub = device.battery >= 0
        ? I18n.t("Pil %1%").arg(device.battery) + (device.charging ? " · " + I18n.t("Şarj oluyor") : "")
        : I18n.t("Yerel Wi-Fi")
      island.peek("phone", I18n.t("%1 bağlandı").arg(device.name), sub, Qt.color(Theme.light ? "#248A3D" : "#30D158"), 2800, "home")
    }
    onDeviceDisconnected: (device, remaining) => {
      if (Date.now() < island.phoneGraceUntil) return
      var sub = remaining > 0
        ? I18n.t("%1 telefon hâlâ bağlı").arg(remaining)
        : I18n.t("Bağlı telefon yok")
      island.peek("phone", I18n.t("%1 bağlantısı kesildi").arg(device.name), sub, Qt.color(Theme.light ? "#C93400" : "#FF9F0A"), 2800, "home")
    }
    onIncomingCall: call => {
      if (Date.now() < island.phoneGraceUntil) return
      var who = call.caller || call.number || I18n.t("Bilinmeyen")
      if (call.event === "ringing") {
        island.peek("phone", I18n.t("%1 arıyor").arg(who), call.deviceName || "", Qt.color(Theme.light ? "#248A3D" : "#30D158"), 4500, "home")
      } else if (call.event === "missedCall") {
        island.peek("phone", I18n.t("Cevapsız arama"), who, Qt.color(Theme.light ? "#C93400" : "#FF9F0A"), 3600, "home")
      }
    }
  }
  RecordingService { id: recordingSvc }
  AudioLevel {
    id: audioSvc
    active: island.ambientOn && island.cfg("ambientAudio") && !Theme.reduceMotion
  }
  readonly property alias audio: audioSvc
  readonly property bool ambientOn: cfg("ambient") && musicLive && !fullscreenHidden

  readonly property alias agents: agentsSvc
  readonly property alias music: musicSvc
  readonly property alias timer: timerSvc
  readonly property alias shelf: shelfSvc
  readonly property alias apps: appsSvc
  readonly property alias recording: recordingSvc
  readonly property alias hardware: hardwareSvc
  readonly property alias phones: phonesSvc

  // Charging peek, the same moment iOS shows the green battery.
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: battery && battery.isLaptopBattery
  readonly property real batteryPercent: hasBattery ? (battery.percentage <= 1 ? battery.percentage * 100 : battery.percentage) : 0
  property bool lastOnBattery: true
  // Debounced: a loose cable or a dock can flap the power state.
  Connections {
    target: UPower
    function onOnBatteryChanged() { chargeSettle.restart() }
  }
  Timer {
    id: chargeSettle
    interval: 1500
    onTriggered: {
      if (!island.hasBattery) return
      if (!UPower.onBattery && island.lastOnBattery)
        island.peek("battery-charge", I18n.t("Şarj oluyor"), Math.round(island.batteryPercent) + "%", Theme.green, 2200)
      island.lastOnBattery = UPower.onBattery
    }
  }
  Component.onCompleted: {
    phoneGraceUntil = Date.now() + 3500
    lastOnBattery = UPower.onBattery
    var initial = resolveTargetScreen()
    if (initial) {
      targetScreen = initial
      lastScreenName = String(initial.name)
      setSurfaceReady(true)
    } else {
      syncTargetScreen(false)
    }
  }

  // ================================================================ clock

  property double nowMs: Date.now()
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: island.nowMs = Date.now()
  }
  readonly property string clockText: Qt.locale(localeName).toString(new Date(nowMs), cfg("clockFormat"))
  readonly property string shortClockText: Qt.locale(localeName).toString(new Date(nowMs), "HH:mm")

  function duration(ms) {
    var s = Math.max(0, Math.floor(ms / 1000))
    if (s < 60) return s + I18n.t(" sn")
    var m = Math.floor(s / 60)
    if (m < 60) return m + ":" + ((s % 60) < 10 ? "0" : "") + (s % 60)
    return Math.floor(m / 60) + I18n.t(" sa ") + (m % 60) + I18n.t(" dk")
  }

  // ================================================================ activities

  // Music is a live activity only while it plays: pausing or closing the
  // player leaves the compact notch clean and empty until hovered.
  readonly property bool musicLive: music.available && music.playing
  readonly property var live: {
    // "claude" is the pre-1.1 name of the agent activity.
    var order = (cfg("priority") || ["agent", "recording", "timer", "music"]).map(k => k === "claude" ? "agent" : k)
    var out = []
    for (var i = 0; i < order.length; i++) {
      var k = order[i]
      if (k === "agent" && (agents.live || recentlyFinished)) out.push(k)
      else if (k === "music" && musicLive) out.push(k)
      else if (k === "timer" && timer.active) out.push(k)
      else if (k === "recording" && recording.active) out.push(k)
      else if (k === "shelf" && shelf.count > 0) out.push(k)
    }
    // Activities missing from a user's custom priority still show, last.
    var all = ["agent", "recording", "timer", "music", "shelf"]
    for (var j = 0; j < all.length; j++) {
      var a = all[j]
      if (out.indexOf(a) !== -1 || order.indexOf(a) !== -1) continue
      if ((a === "agent" && (agents.live || recentlyFinished)) || (a === "timer" && timer.active)
          || (a === "music" && musicLive) || (a === "recording" && recording.active)
          || (a === "shelf" && shelf.count > 0)) out.push(a)
    }
    return out
  }
  // A finished agent turn lingers in compact for a moment with a checkmark.
  // A turn that just ended (done, stopped or failed) lingers in compact for a
  // moment so you see how it ended.
  readonly property bool recentlyFinished: agents.revision >= 0 && agents.focusSession !== null
    && ["done", "interrupted", "error"].indexOf(agents.focusSession.state) !== -1
    && nowMs - (agents.focusSession.finishedAt || 0) < 8000
  // ---- slots: [center pill, right bubble, left bubble]
  // By default activities fill the slots in priority order. Double-clicking
  // a bubble swaps it with the center, and that arrangement is kept: an
  // activity that ends just leaves its slot (the others close up), a new one
  // takes the next free slot. Once nothing is live the arrangement resets.
  property var arrangement: []
  // The shelf is a side bubble: alone, it leaves the center to the clock
  // ("idle") unless you double-click it into the middle.
  readonly property var slots: {
    var out = arrangement.filter(k => live.indexOf(k) !== -1)
    for (var i = 0; i < live.length; i++) if (out.indexOf(live[i]) === -1) out.push(live[i])
    if (out.length === 1 && out[0] === "shelf" && arrangement[0] !== "shelf") out.unshift("idle")
    return out
  }
  onLiveChanged: if (live.length === 0 && arrangement.length) arrangement = []

  function swapToCenter(kind) {
    var s = slots.slice()
    var i = s.indexOf(kind)
    if (i <= 0) return
    s[i] = s[0]
    s[0] = kind
    arrangement = s
  }

  readonly property string primary: slots.length ? slots[0] : "idle"
  readonly property string secondary: slots.length > 1 && slots[1] !== "idle" ? slots[1] : ""
  readonly property string tertiary: slots.length > 2 && slots[2] !== "idle" ? slots[2] : ""

  // ================================================================ state

  property string mode: "compact"      // compact | peek | expanded
  property string page: "home"
  property string openedBy: "pointer"  // pointer | key | alert
  property bool pointerVisited: false
  property bool dragHover: false
  readonly property bool alertActive: agents.pending.length > 0 || timer.ringing
  property bool feedExpanded: false    // the agent page's live feed, taller
  property bool composing: false       // a message is being typed on the agent page
  readonly property bool locked: (page === "permission" && agents.pending.length > 0) || (page === "timer" && timer.ringing) || dragHover || composing

  readonly property var pages: {
    var list = ["home"]
    if (music.available) list.push("music")
    list.push("agent", "timer", "shelf")
    return list
  }

  function defaultPage() {
    if (agents.pending.length > 0) return "permission"
    if (timer.ringing) return "timer"
    return primary === "idle" || primary === "recording" ? "home" : primary
  }

  // -1 / +1 while switching tabs in the open island (pages slide), 0 when the
  // island itself opens (pages blur-morph). Set before `page` changes so the
  // outgoing and incoming page agree on it.
  property int pageSlide: 0
  function setPage(name) {
    if (!name || name === page) return
    var from = pages.indexOf(page), to = pages.indexOf(name)
    pageSlide = mode === "expanded" && from !== -1 && to !== -1 ? (to > from ? 1 : -1) : 0
    springMode = "resize"
    page = name
  }

  // Wheel over the open island steps through its tabs: down/right is the
  // next tab, up/left the previous. It follows the scroll: every notch (or
  // the same distance on a touchpad) is one tab, so a slow scroll moves one
  // at a time and a fast or long one moves several. Stops at the ends.
  // Parts with a scroll of their own (the live feed) keep it.
  property real wheelSum: 0
  Timer { id: wheelDecay; interval: 260; onTriggered: island.wheelSum = 0 }
  function wheelTabs(wheel) {
    if (mode !== "expanded" || composing || page === "permission") return
    var d = Math.abs(wheel.angleDelta.y) >= Math.abs(wheel.angleDelta.x) ? wheel.angleDelta.y : wheel.angleDelta.x
    if (d === 0 && wheel.pixelDelta) d = (Math.abs(wheel.pixelDelta.y) >= Math.abs(wheel.pixelDelta.x) ? wheel.pixelDelta.y : wheel.pixelDelta.x) * 2
    if (d === 0) return
    wheelDecay.restart()
    // A turn of direction starts over, so the first notch back counts.
    if (wheelSum !== 0 && (wheelSum < 0) !== (d < 0)) wheelSum = 0
    wheelSum += d
    var steps = Math.trunc(wheelSum / 120)
    if (steps === 0) return
    wheelSum -= steps * 120
    var i = pages.indexOf(page)
    if (i === -1) return
    var next = Math.max(0, Math.min(pages.length - 1, i - steps))
    if (next === i) { wheelSum = 0; return }
    setPage(pages[next])
  }

  function openPage(name, by) {
    peekTimer.stop()
    if (name === "claude") name = "agent"
    if (name === "permission" && agents.pending.length === 0) name = "agent"
    name = name || defaultPage()
    if (mode === "expanded") { setPage(name); openedBy = by || openedBy; focusInput(); return }
    pageSlide = 0
    page = name
    openedBy = by || "pointer"
    pointerVisited = island.hovered
    springMode = "open"
    mode = "expanded"
    collapseTimer.stop()
    focusInput()
  }

  // ---- refresh
  // Quick: clears stuck agent sessions and requests, alerts, banners and
  // motion, and returns to compact. Nothing else on the desktop is touched.
  function resetIsland() {
    agents.reset()
    timer.dismissRing()
    peekTimer.stop()
    hoverTimer.stop()
    collapseTimer.stop()
    shakeAnim.stop(); shakeX = 0
    bounceAnim.stop(); bounceY = 0
    arrangement = []
    dragHover = false
    springMode = "close"
    pageSlide = 0
    page = "home"
    mode = "compact"
    peek("restart", I18n.t("Ada yenilendi"), "", Theme.green, 1500)
  }

  // Full: restarts the whole Omarchy shell (bar included), which reloads the
  // island from disk; it then drops back in (intro). Uses Omarchy's own
  // `omarchy-restart-shell`, in its own session so it outlives the shell it
  // restarts.
  function restartShell() {
    Quickshell.execDetached(["setsid", "omarchy-restart-shell"])
  }

  function toggle() {
    if (mode === "expanded") collapse()
    else openPage(defaultPage(), "key")
  }

  function collapse() {
    if (mode === "compact") return
    springMode = "close"
    pageSlide = 0
    mode = "compact"
    collapseTimer.stop()
  }

  function cyclePage(delta) {
    if (page === "permission") return
    var i = pages.indexOf(page)
    if (i === -1) i = 0
    setPage(pages[(i + delta + pages.length) % pages.length])
  }

  // ---- peek
  property var peekData: ({ icon: "", title: "", subtitle: "", tint: "#ffffff", target: "" })
  function peek(icon, title, subtitle, tint, ms, target) {
    if (mode === "expanded" || !introDone) return
    peekData = { icon: icon, title: title || "", subtitle: subtitle || "", tint: tint || Theme.fg, target: target || "" }
    springMode = "open"
    mode = "peek"
    peekTimer.interval = ms || 2200
    peekTimer.restart()
  }
  Timer {
    id: peekTimer
    onTriggered: if (island.mode === "peek" && !island.hovered) island.collapse(); else if (island.mode === "peek") restart()
  }

  // ---- motion helpers
  property string springMode: "open"     // open | close | resize
  readonly property real springK: springMode === "open" ? Theme.openSpring : springMode === "close" ? Theme.closeSpring : Theme.resizeSpring
  readonly property real springD: springMode === "open" ? Theme.openDamping : springMode === "close" ? Theme.closeDamping : Theme.resizeDamping
  property real shakeX: 0
  function shake() {
    if (Theme.reduceMotion) return
    shakeAnim.restart()
  }
  SequentialAnimation {
    id: shakeAnim
    NumberAnimation { target: island; property: "shakeX"; to: -11; duration: 55; easing.type: Easing.OutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 10; duration: 80; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: -8; duration: 75; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 6; duration: 70; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: -3; duration: 65; easing.type: Easing.InOutSine }
    NumberAnimation { target: island; property: "shakeX"; to: 0; duration: 60; easing.type: Easing.OutSine }
  }

  // A soft vertical "drop" for alerts: the shape dips and springs back.
  property real bounceY: 0
  function bounce() {
    if (Theme.reduceMotion) return
    bounceAnim.restart()
  }
  SequentialAnimation {
    id: bounceAnim
    NumberAnimation { target: island; property: "bounceY"; to: 4; duration: 110; easing.type: Easing.OutQuad }
    SpringAnimation { target: island; property: "bounceY"; to: 0; spring: 5; damping: 0.22; epsilon: 0.05 }
  }

  // ================================================================ geometry

  // ---- fit the bar in use. Measured from the bar's layer surface so the
  // island lines up with the stock 26 px bar, floating island bars, or any
  // replacement bar, unless compactHeight / topOffset are set explicitly.
  property var barGeom: null    // { y, h } of a top bar on the island's monitor
  property int barStable: 0     // probes in a row that saw the same size
  property bool barSettled: false
  Process {
    id: barProbe
    property string monitor: ""
    command: ["hyprctl", "layers", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          var found = null
          for (var mon in data) {
            if (barProbe.monitor && mon !== barProbe.monitor) continue
            var levels = data[mon].levels || {}
            for (var lv in levels) {
              var list = levels[lv]
              for (var i = 0; i < list.length; i++) {
                var l = list[i]
                if (l.namespace === "omarchy-bar" && l.w > l.h && l.y <= 4) found = { y: l.y, h: l.h }
              }
            }
          }
          // A bar that is reloading is briefly missing: keep the last fit
          // rather than snapping to the fallback size.
          if (!found) return
          // A freshly started bar grows in steps (26 → 30 → its real size,
          // over about half a second): only call it settled once the same
          // size comes back three times in a row.
          var same = island.barGeom && island.barGeom.y === found.y && island.barGeom.h === found.h
          island.barStable = same ? island.barStable + 1 : 0
          if (!same) island.barGeom = found
          if (island.barStable >= 2) island.barSettled = true
        } catch (e) {}
      }
    }
  }
  Timer {
    // Right after a shell (re)start the bar may not exist yet: look again
    // quickly until it does, then only now and then.
    interval: island.barSettled ? 10000 : 250
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      barProbe.monitor = island.targetScreen ? String(island.targetScreen.name) : ""
      if (!barProbe.running) barProbe.running = true
    }
  }

  readonly property bool idleHidden: false
  readonly property int compactH: {
    var v = cfg("compactHeight")
    if (typeof v === "number" && v > 0) return v
    return 22
  }
  readonly property int topY: {
    var v = cfg("topOffset")
    if (typeof v === "number" && v >= 0) return v
    return 0
  }
  // ---- Liquid Glass
  // The island is a translucent glass body (components/LiquidGlass.qml) on
  // a backdrop blur only behind its own layer (bin/dynamic-island-glass,
  // runtime only, undone with "glass": false or Hyprland's reload). It moves
  // like liquid: the glass flexes ("jelly") on opening, closing and touch,
  // lights up when touched ("energy"), and its specular edge follows the
  // pointer.
  readonly property bool glassOn: cfg("glass") !== false
  onGlassOnChanged: glassSetup.run()
  QtObject {
    id: glassSetup
    function run() {
      blurProc.command = [island.pluginDir + "/bin/dynamic-island-glass", island.glassOn ? "on" : "off"]
      blurProc.running = true
    }
  }
  Process { id: blurProc }
  Timer { id: glassRefresh; running: true; interval: 60; onTriggered: { glassSetup.run(); hyprGlassSetup.run() } }
  // Hyprland reloads its config (and drops runtime rules) on every save,
  // and monitor hotplug/wake events can precede or reorder Quickshell screens.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") {
        if (island.glassOn) glassSetup.run()
        hyprGlassSetup.run()
        return
      }
      if (event.name === "monitoradded" || event.name === "monitoraddedv2"
          || event.name === "monitorremoved" || event.name === "monitorremovedv2") {
        island.syncTargetScreen(false)
      }
    }
  }

  // HyprGlass (a Hyprland plugin) loaded: the compositor draws real
  // refracting glass behind the island's layer, and the island drops its
  // own smoky / milky tint, rim and shadow so nothing covers it. Checked
  // now and then, so loading or unloading the plugin is picked up live.
  // HyprGlass's layer glass is off unless the island turns it on: only
  // while it runs with the Liquid Glass theme. Off again when the theme is
  // switched off or the island goes away.
  property bool hyprGlass: false
  readonly property bool hyprGlassOn: hyprGlass && glassOn
  onHyprGlassOnChanged: hyprGlassSetup.run()
  onLightModeChanged: hyprGlassSetup.run()
  QtObject {
    id: hyprGlassSetup
    function run() {
      if (!island.hyprGlass) return
      hyprGlassProc.command = island.hyprGlassOn
        ? [island.pluginDir + "/bin/dynamic-island-hyprglass", "on", island.lightMode ? "light" : "dark"]
        : [island.pluginDir + "/bin/dynamic-island-hyprglass", "off"]
      hyprGlassProc.running = true
    }
  }
  Component.onDestruction: if (hyprGlass) Quickshell.execDetached([pluginDir + "/bin/dynamic-island-hyprglass", "off"])
  Process { id: hyprGlassProc }
  Process {
    id: hyprGlassProbe
    command: [island.pluginDir + "/bin/dynamic-island-hyprglass", "status"]
    stdout: StdioCollector { onStreamFinished: island.hyprGlass = text.trim() === "active" }
  }
  Timer { running: true; repeat: true; triggeredOnStart: true; interval: 15000; onTriggered: hyprGlassProbe.running = true }

  property real jelly: 0
  function wobble(amount) {
    if (!glassOn || Theme.reduceMotion) return
    jellyAnim.amount = amount
    jellyAnim.restart()
  }
  SequentialAnimation {
    id: jellyAnim
    property real amount: 0
    NumberAnimation { target: island; property: "jelly"; to: jellyAnim.amount; duration: 110; easing.type: Easing.OutQuad }
    SpringAnimation { target: island; property: "jelly"; to: 0; spring: 2.6; damping: 0.16; epsilon: 0.0005 }
  }
  // The pointer's pull on the glass. Its position trails the pointer on a
  // soft spring (liquid lag) and its strength fades in and out, so leaving
  // lets the glass flow back.
  property real pullX: 0
  property real pullY: 0
  property real pullAmp: 0
  // Stiff and quick: it answers the pointer at once, with just enough
  // trail to read as liquid. Rises in 90 ms; lets go a little softer.
  Behavior on pullX { enabled: !Theme.reduceMotion; SpringAnimation { spring: 16; damping: 0.75; epsilon: 0.1 } }
  Behavior on pullY { enabled: !Theme.reduceMotion; SpringAnimation { spring: 16; damping: 0.75; epsilon: 0.1 } }
  Behavior on pullAmp {
    enabled: !Theme.reduceMotion
    NumberAnimation { duration: island.pullAmp > 0.1 && !island.hovered ? 260 : 90; easing.type: Easing.OutCubic }
  }
  property real glassEnergy: 0
  function flash() {
    if (!glassOn || Theme.reduceMotion) return
    flashAnim.restart()
  }
  SequentialAnimation {
    id: flashAnim
    NumberAnimation { target: island; property: "glassEnergy"; to: 1; duration: 90; easing.type: Easing.OutQuad }
    NumberAnimation { target: island; property: "glassEnergy"; to: 0; duration: 520; easing.type: Easing.OutCubic }
  }
  function glassModeMotion() {
    if (mode === "expanded") { wobble(0.035); flash() }
    else if (mode === "peek") wobble(0.03)
    else wobble(-0.025)
  }
  onSplitIslandChanged: wobble(splitIsland ? 0.03 : -0.02)
  // The light: from the top-left at rest; toward the pointer over the
  // island, so the edge highlight slides around as you move.
  property real lightX: -0.55
  property real lightY: -0.83
  Behavior on lightX { SpringAnimation { spring: 3; damping: 0.5; epsilon: 0.002 } }
  Behavior on lightY { SpringAnimation { spring: 3; damping: 0.5; epsilon: 0.002 } }
  readonly property point glassLight: {
    var l = Math.sqrt(lightX * lightX + lightY * lightY) || 1
    return Qt.point(lightX / l, lightY / l)
  }

  // ---- intro
  // The island stays hidden until it knows where the bar is (so it never
  // shows at a wrong, squashed size), then drops in from above the screen as
  // a small circle and springs open into the island.
  //   hidden → drop (circle falls into place) → done (morphs to full width)
  readonly property bool geometryKnown: barSettled
    || (typeof cfg("compactHeight") === "number" && typeof cfg("topOffset") === "number")
  property string intro: "hidden"
  readonly property bool introDone: intro === "done"
  property real introY: 0
  onGeometryKnownChanged: if (geometryKnown) introStart.restart()
  Timer {
    // Bar never found or never still (none, or a different one): start anyway.
    interval: 4000
    running: island.intro === "hidden"
    onTriggered: introStart.restart()
  }
  Timer {
    id: introStart
    interval: 120          // let the size settle on the measured bar first
    onTriggered: {
      if (island.intro !== "hidden") return
      if (Theme.reduceMotion) { island.intro = "done"; return }
      introDrop.from = -(island.topY + island.compactH + 16)
      island.intro = "drop"
      introDrop.restart()
    }
  }
  SequentialAnimation {
    id: introDrop
    property real from: -60
    SpringAnimation { target: island; property: "introY"; from: introDrop.from; to: 0; spring: 3.2; damping: 0.32; epsilon: 0.2 }
    PauseAnimation { duration: 60 }
    ScriptAction { script: island.intro = "done" }
  }

  readonly property int expandedW: cfg("expandedWidth")

  // The layer surface is only as big as the island can get: its open width
  // plus room for the shadow, shake and jelly, and short while closed, tall
  // only while open (and a moment after, for the closing spring). Anything
  // that composites the surface (Hyprland's blur, HyprGlass) then works on
  // that area instead of a full-width 720 px band.
  readonly property bool expandedNow: mode === "expanded"
  onExpandedNowChanged: if (!expandedNow) tallHold.restart()
  Timer { id: tallHold; interval: 900 }
  readonly property int surfaceW: expandedW + 180
  readonly property int surfaceH: expandedNow || tallHold.running || !introDone ? 720
    : Math.max(topY, 0) + Math.max(compactH, 64) + 72
  readonly property bool hovered: surfaceLoader.item ? surfaceLoader.item.hovered : false
  // Split in two, each half reacts on its own: no whole-island grow or lean;
  // the half under the pointer lights up and hovering opens its agent.
  readonly property int hoveredHalf: halvesOn && hovered && surfaceLoader.item ? (surfaceLoader.item.hoverX < surfaceLoader.item.stageWidth / 2 ? 0 : 1) : -1
  readonly property string hoveredAgent: hoveredHalf >= 0 ? (splitOrder[hoveredHalf] || "") : ""
  readonly property int hoverGrowW: mode === "compact" && hovered && !halvesOn ? 12 : 0
  readonly property int hoverGrowH: mode === "compact" && hovered && !halvesOn ? 2 : 0

  readonly property int phoneDotPad: phones.connected && !splitIsland ? 12 : 0
  readonly property int idleW: (cfg("idleClock") ? Math.max(124, Math.ceil(clockMetrics.advanceWidth) + 48) : 56) + phoneDotPad
  readonly property int liveW: {
    if (splitIsland) return 344
    if (primary === "agent") return (cfg("idleClock") ? 248 : 206) + phoneDotPad
    if (primary === "timer") return 220 + phoneDotPad
    if (primary === "music") return 256 + phoneDotPad
    if (primary === "recording") return 200 + phoneDotPad
    return idleW
  }

  readonly property int expandedChromeH: page === "permission" ? 0 : 44
  readonly property int pageH: surfaceLoader.item ? surfaceLoader.item.pageH : 0
  readonly property int targetW: !introDone ? compactH
    : mode === "expanded" ? expandedW
    : mode === "peek" ? Math.min(expandedW, Math.max(320, Math.ceil(peekMetrics.advanceWidth) + 130))
    : liveW + hoverGrowW
  readonly property int targetH: !introDone ? compactH
    : mode === "expanded" ? expandedChromeH + pageH + 14
    : mode === "peek" ? 56
    : compactH + hoverGrowH
  readonly property real targetR: !introDone ? compactH / 2
    : mode === "expanded" ? 24 : mode === "peek" ? 22 : Math.min(12, (compactH + hoverGrowH) * 0.65)

  TextMetrics {
    id: clockMetrics
    font.family: Theme.font
    font.pixelSize: 12
    font.weight: Font.DemiBold
    text: island.clockText
  }
  TextMetrics {
    id: peekMetrics
    font.family: Theme.font
    font.pixelSize: 15
    font.weight: Font.DemiBold
    text: island.peekData.title.length > island.peekData.subtitle.length ? island.peekData.title : island.peekData.subtitle
  }

  // ================================================================ timers

  Timer {
    id: hoverTimer
    interval: island.cfg("hoverDelay")
    onTriggered: {
      if (!island.hovered || island.mode === "expanded") return
      // Over one half of a split island: that half's agent.
      if (island.hoveredAgent) island.showAgent(island.hoveredAgent)
      else island.openPage(island.defaultPage(), "pointer")
    }
  }

  Timer {
    id: collapseTimer
    interval: island.cfg("collapseDelay")
    onTriggered: if (!island.hovered && !island.locked && island.mode === "expanded") island.collapse()
  }

  onHoveredChanged: {
    if (hovered) {
      pointerVisited = true
      collapseTimer.stop()
      if (mode !== "expanded" && cfg("hoverExpand")) hoverTimer.restart()
    } else {
      hoverTimer.stop()
      if (mode === "expanded" && !locked && (openedBy === "pointer" || pointerVisited)) collapseTimer.restart()
    }
  }
  onLockedChanged: if (!locked && mode === "expanded" && !hovered && pointerVisited) collapseTimer.restart()

  // ================================================================ fullscreen

  readonly property var focusedMonitor: Hyprland.focusedMonitor
  readonly property bool fullscreenHidden: cfg("hideOnFullscreen") && !alertActive && mode === "compact"
    && focusedMonitor && focusedMonitor.activeWorkspace && focusedMonitor.activeWorkspace.hasFullscreen === true

  // ================================================================ surfaces & wake recovery

  // Guard against Qt Wayland's zero-output placeholder screens ("", "FALLBACK")
  // and tear down / recreate both PanelWindows across disconnect/suspend/wake
  // transitions or compositor layer-surface closes so neither surface ends up
  // bound to a closed zwlr_layer_surface_v1 or dangling QScreen.
  property var targetScreen: null
  property string lastScreenName: ""
  property bool surfaceReady: false
  property int surfaceRecoverCount: 0

  function isRealScreen(s) {
    if (!s) return false
    var n = String(s.name || "").trim()
    if (n === "" || n === "FALLBACK") return false
    if (s.width <= 0 || s.height <= 0) return false
    return true
  }

  function resolveTargetScreen() {
    var screens = Quickshell.screens
    if (!screens || screens.length === 0) return null
    var real = []
    for (var i = 0; i < screens.length; i++) {
      if (isRealScreen(screens[i])) real.push(screens[i])
    }
    if (real.length === 0) return null
    var want = String(cfg("screen") || (focusedMonitor ? focusedMonitor.name : "") || "")
    if (want) {
      for (var j = 0; j < real.length; j++) {
        if (String(real[j].name) === want) return real[j]
      }
    }
    return real[0]
  }

  function setSurfaceReady(ready) {
    if (!ready && surfaceLoader.item) surfaceLoader.item.tearingDown = true
    if (surfaceReady !== ready) surfaceReady = ready
  }

  function onSurfaceWindowConnected() {
    surfaceRecoverCount = 0
    glassRefresh.restart()
    if (mode === "expanded") Qt.callLater(focusInput)
  }

  function focusInput() {
    if (surfaceLoader.item) surfaceLoader.item.focusInput()
  }

  function syncTargetScreen(forceRemap) {
    var next = resolveTargetScreen()
    if (!next) {
      surfaceSettle.stop()
      setSurfaceReady(false)
      targetScreen = null
      return
    }
    var same = (targetScreen === next)
    if (!same) {
      setSurfaceReady(false)
      if (lastScreenName && String(next.name) !== lastScreenName) {
        barStable = 0
        barSettled = false
      }
      targetScreen = next
      lastScreenName = String(next.name)
      surfaceSettle.interval = 180
      surfaceSettle.restart()
    } else if (forceRemap) {
      setSurfaceReady(false)
      surfaceSettle.interval = 180
      surfaceSettle.restart()
    } else if (!surfaceReady && !surfaceSettle.running) {
      surfaceSettle.interval = 180
      surfaceSettle.restart()
    }
  }

  function recoverSurface() {
    if (surfaceSettle.running) return
    setSurfaceReady(false)
    surfaceRecoverCount = Math.min(surfaceRecoverCount + 1, 6)
    surfaceSettle.interval = surfaceRecoverCount > 3 ? 1000 : 200
    surfaceSettle.restart()
  }

  function forceRebuildSurface() {
    surfaceRecoverCount = 0
    syncTargetScreen(true)
  }

  Timer {
    id: surfaceSettle
    onTriggered: {
      var next = island.resolveTargetScreen()
      if (!next) {
        island.setSurfaceReady(false)
        island.targetScreen = null
        return
      }
      if (next !== island.targetScreen) {
        island.targetScreen = next
        island.lastScreenName = String(next.name)
        surfaceSettle.interval = 180
        surfaceSettle.restart()
        return
      }
      island.setSurfaceReady(true)
      if (!barProbe.running) {
        barProbe.monitor = String(next.name)
        barProbe.running = true
      }
    }
  }

  Timer {
    id: surfaceMoveRemap
    interval: 220
    onTriggered: {
      if (!island.isRealScreen(island.targetScreen)) return
      island.syncTargetScreen(true)
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() { island.syncTargetScreen(false) }
  }

  Connections {
    target: island.targetScreen
    ignoreUnknownSignals: true
    function onXChanged() { surfaceMoveRemap.restart() }
    function onYChanged() { surfaceMoveRemap.restart() }
    function onNameChanged() { island.syncTargetScreen(false) }
    function onWidthChanged() { if (!island.isRealScreen(island.targetScreen)) island.syncTargetScreen(false) }
    function onHeightChanged() { if (!island.isRealScreen(island.targetScreen)) island.syncTargetScreen(false) }
  }

  onFocusedMonitorChanged: syncTargetScreen(false)
  onUserConfigChanged: syncTargetScreen(false)

  // ================================================================ IPC

  IpcHandler {
    target: "dynamicisland"
    function toggle(): string { island.toggle(); return "ok" }
    function reset(): string { island.resetIsland(); return "ok" }
    function recoverSurface(): string { island.forceRebuildSurface(); return "ok" }
    function restartShell(): string { island.restartShell(); return "ok" }
    function open(page: string): string { island.openPage(page || island.defaultPage(), "key"); return "ok" }
    function close(): string { island.collapse(); return "ok" }
    function approve(): string { return island.agents.respond("", "allow") ? "ok" : "no-request" }
    function always(): string { return island.agents.respond("", "always") ? "ok" : "no-request" }
    function deny(): string { return island.agents.respond("", "deny") ? "ok" : "no-request" }
    function timer(seconds: string): string { island.timer.startCountdown(Number(seconds) || 300); island.peek("timer", I18n.t("Zamanlayıcı"), island.timer.display, Theme.orange, 1600); return "ok" }
    function stopwatch(): string { island.timer.startStopwatch(); return "ok" }
    function timerStop(): string { island.timer.cancel(); return "ok" }
    function shelfAdd(path: string): string { return island.shelf.addUrls([path]) > 0 ? "ok" : "invalid" }
    function notify(title: string, subtitle: string): string { island.peek("bell", title, subtitle, Theme.fg, 3000); return "ok" }
    function shortcut(index: string): string { island.runShortcut(island.shortcuts[Number(index)]); return "ok" }
    function events(): string {
      var out = []
      var log = island.agents.eventLog
      for (var i = 0; i < log.length; i++) {
        var e = log[i], s = island.agents.sessions[Object.keys(island.agents.sessions).filter(k => k.indexOf(e.session) === 0)[0]]
        out.push(new Date(e.at).toISOString().substring(11, 23) + " " + e.agent + " " + e.session + " " + e.event + (e.tool ? "(" + e.tool + ")" : "") + " entry=" + e.entry + " ts=" + e.ts + " was=" + e.before + (e.note ? "  ← " + e.note : ""))
      }
      return out.join("\n")
    }
    function sessions(): string {
      return JSON.stringify(island.agents.sessionList.map(s => ({
        id: s.agent === "lmstudio" ? s.id : s.id.substring(0, 12),
        agent: s.agent,
        state: island.agents.displayState(s),
        tool: s.tool,
        model: s.model || "",
        provider: s.provider || "",
        project: s.project,
        lastTs: s.lastTs,
        transcript: s.transcript,
        turnStartedAt: s.turnStartedAt
      })))
    }
    function status(): string {
      return JSON.stringify({ agent: island.agentId, mode: island.mode, page: island.page, primary: island.primary, secondary: island.secondary, tertiary: island.tertiary,
        pending: agents.pending.length, sessions: agents.sessionList.length, listening: agents.listening,
        running: island.runningAgents, working: island.workingAgents, split: island.splitIsland, pageAgent: island.pageAgent,
        usage: island.agents.usage,
        phones: { connected: island.phones.connectedCount, paired: island.phones.pairedCount, devices: island.phones.devices },
        screen: island.targetScreen ? String(island.targetScreen.name) : "",
        surfaceReady: island.surfaceReady,
        ambient: island.ambientOn, audio: island.audio.active ? Math.round(island.audio.level * 100) / 100 : -1 })
    }
  }

  // ================================================================ surfaces

  Loader {
    id: surfaceLoader
    active: island.surfaceReady && island.targetScreen !== null
    asynchronous: false
    sourceComponent: surfaceHostComponent
  }

  Component {
    id: surfaceHostComponent
    SurfaceHost {
      host: island
    }
  }
}
