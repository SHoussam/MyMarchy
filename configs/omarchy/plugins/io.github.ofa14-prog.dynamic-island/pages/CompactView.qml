import QtQuick
import "../components"

// Compact island: content hugs the two ends (leading / trailing), the middle
// stays clean black, exactly like a live activity around the camera. Leading
// items are square and inset by the same amount from the top, bottom and
// left edge, so they sit centered in the rounded end.
Page {
  id: view

  property var island
  readonly property string kind: island.primary
  readonly property int lead: Math.round(island.compactH * 0.62)          // leading item size
  readonly property int edge: Math.round((island.compactH - lead) / 2) + 2 // inset from the end
  readonly property var session: island.agents.focusSession
  readonly property var agentProfile: island.profile(session ? session.agent : "")
  readonly property string agentState: island.agents.displayState(session)
  readonly property bool agentWorking: agentState === "thinking" || agentState === "tool" || agentState === "compacting"

  readonly property int activeSessionCount: {
    void island.agents.revision
    var n = 0
    var list = island.agents.sessionList
    for (var i = 0; i < list.length; i++) {
      if (island.agents.isBusy(list[i]) || island.agents.needsYou(list[i])) n++
    }
    return n
  }

  function shortToolName(raw) {
    var t = String(raw || "").trim()
    if (!t) return I18n.t("Çalışıyor")
    if (t.indexOf("mcp__") === 0) {
      var parts = t.split("__")
      var tool = parts.length > 2 ? parts.slice(2).join(" ") : (parts[1] || "mcp")
      t = tool.replace(/_/g, " ")
    } else if (t === "Call mcp tool") {
      t = "MCP"
    } else if (t.indexOf("_") !== -1 && t.indexOf(" ") === -1) {
      t = t.replace(/_/g, " ")
    }
    return t
  }

  function shortModelLabel(s) {
    var raw = String((s && (s.project || s.model)) || "").trim()
    if (!raw) return ""
    var slash = raw.lastIndexOf("/")
    if (slash !== -1) raw = raw.substring(slash + 1)
    return raw.length > 16 ? raw.substring(0, 15) + "…" : raw
  }

  // Labels and icons come from AgentBridge.stateLook, shared by all views.
  readonly property var look: island.agents.look(session)
  function agentVerb() {
    var s = session
    if (s && s.agent === "lmstudio" && agentState === "thinking") {
      var m = shortModelLabel(s)
      return m ? (m + "…") : I18n.t("Üretiyor…")
    }
    if (agentState === "tool") return shortToolName(s && s.tool) + "…"
    if (agentState === "input" && s && s.message) return I18n.t("Soru soruyor")
    return I18n.t(look.label)
  }

  // ---------------------------------------------------------------- idle (HS Monogram + clock)
  Page {
    anchors.fill: parent
    shown: view.kind === "idle"
    Row {
      anchors.verticalCenter: parent.verticalCenter
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.horizontalCenterOffset: island.phones.connected ? -5 : 0
      spacing: 6
      Image {
        id: hsLogo
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(island.compactH * 0.70)
        width: height
        source: "../assets/hs_logo.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: island.cfg("idleClock")
        text: island.clockText
        font.pixelSize: 11
        strong: true
        tabular: true
        color: Theme.fg
        Accessible.name: I18n.t("Saat ") + text
      }
    }
  }

  // ---------------------------------------------------------------- just the time when any non-idle/non-music/non-agent activity is shown
  Label {
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: island.phones.connected ? -5 : 0
    visible: view.kind !== "idle" && view.kind !== "music" && view.kind !== "agent" && !island.splitIsland
    text: island.shortClockText
    font.pixelSize: 11
    strong: true
    tabular: true
    color: Theme.secondary
  }

  // ---------------------------------------------------------------- music
  Page {
    anchors.fill: parent
    shown: view.kind === "music"
    Art {
      id: musicArt
      x: view.edge + 2
      anchors.verticalCenter: parent.verticalCenter
      width: view.lead; height: view.lead
      radius: 5
      source: island.music.artUrl
    }
    Label {
      anchors.left: musicArt.right
      anchors.leftMargin: 8
      anchors.right: musicEq.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: island.music.title ? (island.music.artist ? island.music.title + " — " + island.music.artist : island.music.title) : (island.music.identity || "Music")
      font.pixelSize: 12
      strong: true
      color: Theme.fg
    }
    Equalizer {
      id: musicEq
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 4 + (island.phones.connected ? 10 : 0)
      anchors.verticalCenter: parent.verticalCenter
      playing: island.music.playing
      color: island.music.accent
      barWidth: 3
      maxHeight: Math.round(view.lead * 0.72)
    }
  }

  // ---------------------------------------------------------------- two agents
  // Two agents at work: one per half (island.splitIsland). Each half shows
  // its agent's most urgent session; clicking it opens that agent's page.
  component AgentHalf: Item {
    id: half
    property string agentId: ""
    property bool trailPad: false
    readonly property var sessions: island.agents.sessionList.filter(x => x.agent === agentId)
    readonly property var session: {
      void island.agents.revision
      return sessions.find(x => island.agents.pending.some(r => r.session === x.id))
        || sessions.find(x => island.agents.needsYou(x))
        || sessions.find(x => island.agents.isBusy(x)) || sessions[0] || null
    }
    readonly property var prof: island.profile(agentId)
    readonly property string st: island.agents.displayState(session)
    readonly property bool working: st === "thinking" || st === "tool" || st === "compacting"
    readonly property bool waits: st === "waiting" || st === "input" || island.agents.pending.some(r => r.agent === agentId)
    readonly property var look: island.agents.look(session)

    Item {
      id: halfLead
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      AgentSpinner {
        agent: half.agentId
        anchors.centerIn: parent
        size: Math.round(view.lead * 0.78)
        visible: half.look.icon === ""
        running: half.working
      }
      Icon {
        anchors.centerIn: parent
        visible: half.look.icon !== ""
        name: half.look.icon
        size: Math.round(view.lead * 0.78)
        color: half.look.tone === "green" ? Theme.green : half.look.tone === "red" ? Theme.red : Theme.secondary
      }
    }
    Row {
      anchors.right: parent.right
      anchors.rightMargin: half.trailPad ? 18 : 10
      anchors.left: halfLead.right
      anchors.leftMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      layoutDirection: Qt.RightToLeft
      spacing: 5
      Rectangle {
        visible: half.waits
        width: 7; height: 7; radius: 3.5
        color: half.prof.color
        anchors.verticalCenter: parent.verticalCenter
        SequentialAnimation on opacity {
          running: parent.visible && !Theme.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
      }
      ShimmerText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width - (half.waits ? 12 : 0) - 18)
        label: half.waits ? I18n.t("İzin gerekiyor")
          : half.st === "tool" && half.session && half.session.tool ? view.shortToolName(half.session.tool) + "…"
          : half.agentId === "lmstudio" && half.st === "thinking" && half.session
            ? (view.shortModelLabel(half.session) ? view.shortModelLabel(half.session) + "…" : I18n.t("Üretiyor…"))
          : I18n.t(half.look.label)
        running: half.working
        font.pixelSize: 11
        font.weight: Font.DemiBold
        baseColor: half.look.tone === "green" ? Theme.green : half.look.tone === "red" ? Theme.red
          : half.look.tone === "dim" ? Theme.secondary : half.prof.color
        glowColor: half.prof.glow
      }
      // Whose half it is.
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        source: island.logoFor(half.agentId)
        name: source ? "" : "sparkles"
        size: 12
        color: half.prof.color
        opacity: 0.9
      }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: island.showAgent(half.agentId)
    }
    Accessible.role: Accessible.Button
    Accessible.name: prof.product + ", " + (waits ? I18n.t("İzin gerekiyor") : I18n.t(look.label))
  }

  Page {
    anchors.fill: parent
    shown: view.kind === "agent" && island.splitIsland
    AgentHalf {
      x: 0
      width: (parent.width - island.splitGap) / 2
      height: parent.height
      agentId: island.splitOrder[0] || ""
    }
    AgentHalf {
      x: parent.width - width
      width: (parent.width - island.splitGap) / 2
      height: parent.height
      agentId: island.splitOrder[1] || ""
      trailPad: island.phones.connected
    }
  }

  // ---------------------------------------------------------------- agent (compact clock + dedicated small status capsule)
  Page {
    anchors.fill: parent
    shown: view.kind === "agent" && !island.splitIsland

    Row {
      id: agentClock
      x: 9
      anchors.verticalCenter: parent.verticalCenter
      spacing: 5
      Image {
        anchors.verticalCenter: parent.verticalCenter
        height: Math.round(island.compactH * 0.68)
        width: height
        source: "../assets/hs_logo.png"
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
      }
      Label {
        anchors.verticalCenter: parent.verticalCenter
        visible: island.cfg("idleClock")
        text: island.shortClockText
        font.pixelSize: 11
        strong: true
        tabular: true
        color: Theme.secondary
        Accessible.name: I18n.t("Saat ") + text
      }
    }

    Rectangle {
      id: agentPill
      readonly property color accentTone: view.look.tone === "green" ? Theme.green
        : view.look.tone === "red" ? Theme.red
        : view.agentProfile.color
      anchors.left: agentClock.right
      anchors.leftMargin: 7
      anchors.right: parent.right
      anchors.rightMargin: island.phones.connected ? 18 : 4
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(15, island.compactH - 6)
      radius: height / 2
      color: Qt.rgba(accentTone.r, accentTone.g, accentTone.b, Theme.light ? 0.14 : 0.16)
      border.width: 1
      border.color: Qt.rgba(accentTone.r, accentTone.g, accentTone.b, Theme.light ? 0.28 : 0.32)
      clip: true

      Item {
        id: agentLead
        x: 5
        width: 11
        height: 11
        anchors.verticalCenter: parent.verticalCenter
        AgentSpinner {
          agent: view.session ? view.session.agent : island.agentId
          anchors.centerIn: parent
          size: 11
          visible: view.look.icon === "" && view.agentState !== "waiting" && view.agentState !== "input"
          running: view.agentWorking
        }
        // Waiting for you: pulsing dot in the mini-capsule's leading slot.
        Rectangle {
          anchors.centerIn: parent
          visible: view.look.icon === "" && (view.agentState === "waiting" || view.agentState === "input")
          width: 7; height: 7; radius: 3.5
          color: view.agentProfile.color
          SequentialAnimation on opacity {
            running: parent.visible && !Theme.reduceMotion
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
          }
        }
        Icon {
          anchors.centerIn: parent
          visible: view.look.icon !== ""
          name: view.look.icon
          size: 11
          color: view.look.tone === "green" ? Theme.green : view.look.tone === "red" ? Theme.red : Theme.secondary
        }
      }

      Row {
        id: agentMeta
        anchors.right: parent.right
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        visible: view.activeSessionCount > 1 || (view.agentWorking && view.session && view.session.turnStartedAt > 0)

        Label {
          anchors.verticalCenter: parent.verticalCenter
          visible: view.activeSessionCount > 1
          font.pixelSize: 10
          strong: true
          tabular: true
          color: Theme.secondary
          text: "×" + view.activeSessionCount
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          visible: view.agentWorking && view.session && view.session.turnStartedAt > 0
          font.pixelSize: 10
          tabular: true
          color: Theme.tertiary
          text: view.session ? island.duration(island.nowMs - view.session.turnStartedAt) : ""
        }
      }

      ShimmerText {
        anchors.left: agentLead.right
        anchors.leftMargin: 5
        anchors.right: agentMeta.visible ? agentMeta.left : parent.right
        anchors.rightMargin: agentMeta.visible ? 5 : 7
        anchors.verticalCenter: parent.verticalCenter
        label: view.agentVerb()
        running: view.agentWorking
        font.pixelSize: 11
        font.weight: Font.DemiBold
        baseColor: view.look.tone === "green" ? Theme.green : view.look.tone === "red" ? Theme.red
          : view.look.tone === "dim" ? Theme.secondary : view.agentProfile.color
        glowColor: view.agentProfile.glow
      }
    }
  }

  // ---------------------------------------------------------------- recording
  Page {
    anchors.fill: parent
    shown: view.kind === "recording"
    Item {
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      Rectangle {
        anchors.centerIn: parent
        width: Math.round(view.lead * 0.55); height: width; radius: width / 2
        color: Theme.red
        SequentialAnimation on opacity {
          running: view.kind === "recording" && !Theme.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 6 + (island.phones.connected ? 10 : 0)
      anchors.verticalCenter: parent.verticalCenter
      text: island.timer.format(island.nowMs - island.recording.startedAt, false)
      font.pixelSize: 16
      strong: true
      tabular: true
      color: Theme.red
      Accessible.name: I18n.t("Ekran kaydı ") + text
    }
  }

  // ---------------------------------------------------------------- shelf
  // Only when you double-click the shelf bubble into the middle.
  Page {
    anchors.fill: parent
    shown: view.kind === "shelf"
    Item {
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        progress: Math.max(0.04, island.shelf.fullness)
        color: Theme.blue
      }
      Icon {
        anchors.centerIn: parent
        name: "shelf"
        size: Math.round(view.lead * 0.5)
        color: Theme.blue
      }
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 6 + (island.phones.connected ? 10 : 0)
      anchors.verticalCenter: parent.verticalCenter
      text: I18n.count(island.shelf.count, "item")
      font.pixelSize: 14
      strong: true
      color: Theme.blue
      Accessible.name: I18n.t("Raf, ") + text
    }
  }

  // ---------------------------------------------------------------- timer
  Page {
    anchors.fill: parent
    shown: view.kind === "timer"
    Item {
      x: view.edge
      width: view.lead; height: view.lead
      anchors.verticalCenter: parent.verticalCenter
      ProgressRing {
        anchors.fill: parent
        thickness: 2.5
        progress: island.timer.mode === "countdown" ? 1 - island.timer.progress : 1
        color: Theme.orange
      }
      Icon {
        anchors.centerIn: parent
        name: island.timer.paused ? "pause" : "timer"
        size: Math.round(view.lead * 0.5)
        color: Theme.orange
      }
    }
    Label {
      anchors.right: parent.right
      anchors.rightMargin: view.edge + 6 + (island.phones.connected ? 10 : 0)
      anchors.verticalCenter: parent.verticalCenter
      text: island.timer.display
      font.pixelSize: 16
      strong: true
      tabular: true
      color: Theme.orange
      Accessible.name: I18n.t("Kalan süre ") + text
    }
  }

  // ---------------------------------------------------------------- connected phone indicator
  Rectangle {
    id: phoneDot
    z: 5
    visible: island.phones.connected
    width: island.splitIsland ? 5 : 6
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.rightMargin: island.splitIsland ? 6 : 8
    anchors.verticalCenter: parent.verticalCenter
    color: Theme.light ? "#248A3D" : "#30D158"
    border.width: 1
    border.color: Qt.rgba(0, 0, 0, Theme.light ? 0.15 : 0.45)

    Accessible.role: Accessible.Indicator
    Accessible.name: I18n.t("Telefon bağlı")
  }
}
