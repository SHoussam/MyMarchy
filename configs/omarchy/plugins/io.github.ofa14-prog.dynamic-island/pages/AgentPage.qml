import QtQuick
import "../components"

// Every coding-agent session: what it is doing right now, and a jump to it.
// Branded after the island's agent (Omarchy's default, or the one picked in
// the agent bar); each session row keeps its own agent.
Page {
  id: page

  property var island
  readonly property var agents: island.agents
  // With several agents installed the page is per agent (the bar switches);
  // otherwise it lists every session.
  // The page shows one agent at a time (island.pageAgent); the bar switches
  // between the agents that are running.
  readonly property string agentId: island.pageAgent
  // No agent at work and none picked: an overview of every agent instead.
  readonly property bool overview: agentId === ""

  // ---- refresh: look for open agent sessions now (bin/dynamic-island-scan)
  property string scanNote: ""
  Timer { id: scanNoteTimer; interval: 2200; onTriggered: page.scanNote = "" }
  Connections {
    target: page.agents
    function onScanned(found, added) {
      page.scanNote = added > 0 ? I18n.t("%1 yeni oturum bulundu").arg(added)
        : found > 0 ? I18n.t("Yeni oturum yok") : I18n.t("Açık oturum bulunamadı")
      scanNoteTimer.restart()
    }
  }
  component RefreshButton: IslandButton {
    size: 30
    iconSize: 15
    icon: "restart"
    text: page.agents.scanning ? I18n.t("Taranıyor…") : page.scanNote
    fontSize: 12
    accessibleName: I18n.t("Açık oturumları tara")
    onClicked: { page.agents.scan(); page.agents.pollLmStudio() }
  }
  readonly property bool perAgent: island.barAgents.length > 1
  readonly property var sessions: overview ? [] : agents.sessionList.filter(s => !perAgent || s.agent === agentId).slice(0, 4)
  readonly property string product: island.profile(agentId).product
  readonly property color tint: island.profile(agentId).color
  readonly property string logo: island.logoFor(agentId)

  implicitHeight: col.implicitHeight + 8

  readonly property var profile: island.profile(agentId)
  // "full" / "status": the agent reports sessions once connected;
  // "none": it has no event API, so there is nothing to connect.
  readonly property bool connectable: profile.integration !== "none"
  readonly property bool connected: agents.installed[agentId] === true

  onShownChanged: if (!shown) agentBar.open = false

  // ---- live preview (Claude Code, Codex and Antigravity)
  // Follows the focused session; with several, click a row to watch it.
  property string pickedId: ""
  readonly property var previewSession: {
    void agents.revision
    var picked = agents.sessions[pickedId]
    var mine = x => !!x && sessions.some(y => y.id === x.id)
    if (agents.canPreview(picked) && mine(picked)) return picked
    if (agents.canPreview(agents.focusSession) && mine(agents.focusSession)) return agents.focusSession
    return sessions.find(x => agents.canPreview(x)) || null
  }
  Binding {
    target: page.agents
    property: "previewCount"
    value: page.island.feedExpanded ? 120 : 40
  }
  Binding {
    target: page.agents
    property: "previewLines"
    value: page.island.feedExpanded ? 0 : 2      // 0: every line
  }
  Binding {
    target: page.agents
    property: "previewId"
    value: page.shown && page.previewSession ? page.previewSession.id : ""
  }

  // Transcript items → terminal lines, drawn the way the agent's own CLI
  // draws them: "● Bash(…)" / "  ⎿ output" for Claude Code, "•" / "└" for Codex.
  function feedLines(items, agent, busy) {
    var codex = agent === "codex"
    var out = []
    for (var i = 0; i < items.length; i++) {
      var it = items[i]
      var next = items[i + 1]
      switch (it.k) {
        case "prompt":
          out.push({ g: codex ? "›" : ">", t: it.t, c: Theme.tertiary })
          break
        case "text":
          it.t.split("\n").forEach((l, j) => out.push({ g: j === 0 ? (codex ? "•" : "●") : "", t: l, c: Theme.fg }))
          break
        case "tool": {
          // Green / red once its output is in; orange while it still runs.
          var tone = !it.done ? (busy ? Theme.orange : Theme.tertiary)
            : next && next.k === "result" && next.err ? Theme.red : Theme.green
          out.push({ g: codex ? "•" : "●", t: it.t + (it.d ? "(" + it.d + ")" : ""), c: Theme.fg, gc: tone, strong: true })
          break
        }
        case "result":
          it.t.split("\n").forEach((l, j) => out.push({ g: j === 0 ? (codex ? "└" : "⎿") : "", t: l, c: it.err ? Theme.red : Theme.secondary, indent: true }))
          break
        case "interrupt":
          out.push({ g: codex ? "└" : "⎿", t: I18n.t("Kullanıcı tarafından kesildi"), c: Theme.red, indent: true })
          break
      }
    }
    return out.slice(-400)
  }

  function working(s) {
    var st = agents.displayState(s)
    return st === "thinking" || st === "tool" || st === "compacting"
  }

  function formatTokens(n) {
    var v = Number(n) || 0
    if (v >= 1000000) return (v / 1000000).toFixed(1).replace(/\.0$/, "") + "M tok"
    if (v >= 1000) return Math.round(v / 1000) + "k tok"
    return v > 0 ? (v + " tok") : ""
  }

  function isLocalProvider(p) {
    var s = String(p || "").toLowerCase()
    return s === "lmstudio" || s === "local" || s === "ollama" || s === "llama.cpp" || s === "llamacpp" || s === "vllm"
  }

  function shortModelBadge(s) {
    if (!s || !s.model) return ""
    var m = String(s.model)
    var slash = m.lastIndexOf("/")
    if (slash !== -1) m = m.substring(slash + 1)
    var prov = String(s.provider || "")
    var out = (prov && isLocalProvider(prov) && m.indexOf(prov + "/") !== 0) ? (prov + "/" + m) : m
    return out.length > 24 ? out.substring(0, 23) + "…" : out
  }

  // Labels and tones come from AgentBridge.stateLook; rows add detail.
  function stateText(s) {
    var st = agents.displayState(s)
    if (s && s.agent === "lmstudio") {
      var meta = s.modelMeta ? " · " + s.modelMeta : ""
      if (st === "thinking") return I18n.t("Yanıt üretiyor…") + meta
      if (st === "done") return I18n.t("Bitti") + (s.lastDuration ? " · " + island.duration(s.lastDuration) : "") + meta
      return I18n.t("Hazır") + meta + (s.provider === "llama.cpp" ? " · llama.cpp" : "")
    }
    switch (st) {
      case "waiting": return I18n.t("İzin bekliyor · ") + (s.tool || "")
      case "input": return s.message || I18n.t("Seni bekliyor")
      case "compacting": return I18n.t("Bağlamı sıkıştırıyor…")
      case "tool": return (s.tool || I18n.t("Araç")) + (s.title ? " · " + s.title : "") + "…"
      case "done": return I18n.t("Bitti") + (s.lastDuration ? " · " + island.duration(s.lastDuration) : "")
      case "error": return I18n.t("Hata") + (s.error ? " · " + s.error : "")
    }
    return I18n.t(agents.look(s).label)
  }

  function stateColor(s) {
    var tone = agents.look(s).tone
    return tone === "agent" ? island.profile(s.agent).color : tone === "green" ? Theme.green
      : tone === "red" ? Theme.red : Theme.secondary
  }

  Column {
    id: col
    width: parent.width
    spacing: 12

    // ---- overview: every agent, none favoured. A card each with its
    // mark, state, usage and actions; the card opens that agent's page.
    Item {
      visible: page.overview
      width: parent.width
      height: 30
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Icon { anchors.verticalCenter: parent.verticalCenter; name: "sparkles"; size: 20; color: Theme.fg }
        Label { anchors.verticalCenter: parent.verticalCenter; text: "AI"; font.pixelSize: 16; strong: true }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.count(island.usageAgents.length, "agent")
          font.pixelSize: 13
          color: Theme.tertiary
        }
      }
      RefreshButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    Column {
      visible: page.overview
      width: parent.width
      spacing: 8
      Repeater {
        model: island.usageAgents
        delegate: Rectangle {
          id: agentCard
          required property string modelData
          readonly property var prof: island.profile(modelData)
          readonly property var mine: agents.sessionList.filter(x => x.agent === modelData)
          readonly property var u: agents.usageOf(modelData)
          readonly property var lmInfo: modelData === "lmstudio" ? agents.lmStudioInfo : null
          readonly property bool connected: agents.installed[modelData] === true
          width: parent.width
          height: 58
          radius: 18
          color: cardMouse.containsMouse ? Theme.fillHover : Theme.fill
          GlassSheen { takeFill: true; lit: cardMouse.containsMouse; pressed: cardMouse.pressed }
          MouseArea {
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.viewAgent = agentCard.modelData
          }
          Icon {
            id: cardIcon
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            source: island.logoFor(agentCard.modelData)
            name: source ? "" : "sparkles"
            color: agentCard.prof.color
            size: 24
          }
          Column {
            anchors.left: cardIcon.right
            anchors.leftMargin: 12
            anchors.right: cardActions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { width: parent.width; text: agentCard.prof.product; font.pixelSize: 14; strong: true }
            Label {
              width: parent.width
              font.pixelSize: 12
              color: Theme.secondary
              text: agentCard.modelData === "lmstudio"
                ? ((agentCard.mine.length ? I18n.t("Yüklü: %1").arg(agentCard.mine.length)
                    : agentCard.lmInfo && agentCard.lmInfo.running ? I18n.t("Model yüklü değil") : I18n.t("Aktif oturum yok"))
                   + (agentCard.lmInfo && agentCard.lmInfo.server ? "  ·  :" + agentCard.lmInfo.port : ""))
                : ((agentCard.mine.length ? I18n.count(agentCard.mine.length, "session")
                    : agentCard.connected || agentCard.prof.integration === "none" ? I18n.t("Aktif oturum yok") : I18n.t("Bağlı değil"))
                   + (agentCard.u.session >= 0 ? "  ·  " + I18n.t("5s") + " " + Math.round(agentCard.u.session * 100) + "%" : "")
                   + (agentCard.u.weekly >= 0 ? "  ·  " + I18n.t("7g") + " " + Math.round(agentCard.u.weekly * 100) + "%" : "")
                   + (agentCard.u.session < 0 && agentCard.u.todayTokens > 0 ? "  ·  " + I18n.t("Bugün") + " " + page.formatTokens(agentCard.u.todayTokens) : ""))
            }
          }
          Row {
            id: cardActions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            IslandButton {
              visible: !agentCard.connected && agentCard.prof.integration !== "none"
              size: 34
              text: I18n.t("Bağla")
              fontSize: 13
              tint: agentCard.prof.color
              accessibleName: I18n.t("%1 bağlantısını kur").arg(agentCard.prof.product)
              onClicked: agents.installHooks(agentCard.modelData)
            }
            IslandButton {
              size: 34
              icon: agentCard.prof.gui ? "arrow-up-right" : "plus"
              iconSize: 16
              accessibleName: agentCard.prof.gui ? I18n.t("LM Studio'yu aç") : (I18n.t("Yeni ") + agentCard.prof.name + I18n.t(" oturumu"))
              onClicked: { agents.newSession(agentCard.modelData); island.collapse() }
            }
          }
          Accessible.role: Accessible.Button
          Accessible.name: prof.product
        }
      }
    }

    // ---- header
    Item {
      visible: !page.overview
      width: parent.width
      height: 30
      Row {
        id: headRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        // Room left of the usage/status readout; the session count gives way first.
        readonly property real room: parent.width - (usageRow.visible ? usageRow.width + 14 : statusPill.visible ? statusPill.width + 14 : 0)
        Icon {
          visible: !agentBar.visible
          anchors.verticalCenter: parent.verticalCenter
          source: page.logo
          name: page.logo ? "" : "sparkles"
          color: page.tint
          size: 22
        }

        // ---- agent bar: the current agent's mark and a chevron; click to
        // open it sideways onto every installed agent, click one to switch.
        Rectangle {
          id: agentBar
          visible: island.barAgents.length > 1
          anchors.verticalCenter: parent.verticalCenter
          property bool open: false
          readonly property int chip: 30
          // Current agent first, the rest after it.
          readonly property var order: [page.agentId].concat(island.barAgents.filter(a => a !== page.agentId))
          readonly property int closedW: chip + 18
          readonly property int openW: order.length * (chip + 2) + 2
          // Another agent has a session running, or one that needs you.
          readonly property bool othersBusy: agents.sessionList.some(x => x.agent !== page.agentId && agents.isBusy(x))
          readonly property bool othersNeed: agents.sessionList.some(x => x.agent !== page.agentId && agents.needsYou(x))
            || agents.pending.some(r => r.agent !== page.agentId)
          width: open ? openW : closedW
          height: chip + 4
          radius: height / 2
          color: open ? Theme.fill : barMouse.containsMouse && !Theme.glass ? Theme.fillHover : "transparent"
GlassSheen { visible: Theme.glass && agentBar.open }
          clip: true
          Behavior on width {
            enabled: !Theme.reduceMotion
            NumberAnimation { duration: Theme.ms(240); easing.type: Easing.OutCubic }
          }
          Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

          Accessible.role: Accessible.ComboBox
          Accessible.name: I18n.t("Ajan") + ": " + page.product
          Accessible.description: I18n.t("Tıkla: ajanları göster")
          Accessible.onPressAction: open = !open

          // The closed bar's whole area toggles it.
          MouseArea {
            id: barMouse
            anchors.fill: parent
            enabled: !agentBar.open
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: agentBar.open = true
          }

          Row {
            x: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
              model: agentBar.order
              delegate: Item {
                id: chipItem
                required property string modelData
                required property int index
                readonly property bool current: modelData === page.agentId
                readonly property var mine: agents.sessionList.filter(x => x.agent === modelData)
                readonly property bool busy: mine.some(x => agents.isBusy(x))
                readonly property bool needs: mine.some(x => agents.needsYou(x)) || agents.pending.some(r => r.agent === modelData)
                width: agentBar.chip
                height: agentBar.chip
                opacity: agentBar.open || current ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.ms(160) } }

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: chipItem.current && agentBar.open ? Theme.fillHover
                    : chipMouse.containsMouse && !Theme.glass ? Theme.fill : "transparent"
                }
                Icon {
                  anchors.centerIn: parent
                  source: island.logoFor(chipItem.modelData)
                  name: source ? "" : "sparkles"
                  color: island.profile(chipItem.modelData).color
                  size: 19
                }
                // A session of this agent is running (dot) or needs you (pulsing).
                Rectangle {
                  visible: (chipItem.busy || chipItem.needs) && !chipItem.current
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.margins: 2
                  width: 8; height: 8; radius: 4
                  color: chipItem.needs ? Theme.orange : island.profile(chipItem.modelData).color
                  border.width: 1.5
                  border.color: Theme.bg
                  SequentialAnimation on opacity {
                    running: chipItem.needs && !Theme.reduceMotion && page.shown
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.opacity = 1
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                  }
                }
                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  enabled: agentBar.open
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    // Close first: switching reorders the chips and this
                    // delegate may be gone right after.
                    var pick = chipItem.modelData
                    agentBar.open = false
                    if (pick !== page.agentId) { page.pickedId = ""; island.viewAgent = pick }
                  }
                }
                Accessible.role: Accessible.RadioButton
                Accessible.name: island.profile(modelData).product
                Accessible.checked: current
              }
            }
          }
          // Chevron while closed; a dot on it when another agent is busy
          // (its color) or needs you (orange, pulsing).
          Icon {
            id: chevron
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-up"
            size: 13
            rotation: 90
            color: Theme.tertiary
            visible: !agentBar.open
          }
          Rectangle {
            visible: !agentBar.open && (agentBar.othersBusy || agentBar.othersNeed)
            x: chevron.x + 7
            y: chevron.y - 4
            width: 7; height: 7; radius: 3.5
            color: agentBar.othersNeed ? Theme.orange : Theme.secondary
            SequentialAnimation on opacity {
              running: agentBar.othersNeed && !Theme.reduceMotion && page.shown
              loops: Animation.Infinite
              onRunningChanged: if (!running) parent.opacity = 1
              NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
              NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
            }
          }
        }

        Label {
          id: productLabel
          anchors.verticalCenter: parent.verticalCenter
          text: page.product
          font.pixelSize: 16
          strong: true
          readonly property real lead: agentBar.visible ? agentBar.width : 22
          width: Math.min(implicitWidth, headRow.room - lead - 10)
        }
        Label {
          id: countLabel
          anchors.verticalCenter: parent.verticalCenter
          visible: !agentBar.open && productLabel.lead + productLabel.implicitWidth + implicitWidth + 20 <= headRow.room
          text: page.sessions.length > 0
            ? (page.agentId === "lmstudio" ? I18n.t("Yüklü: %1").arg(page.sessions.length) : I18n.count(page.sessions.length, "session"))
            : ""
          font.pixelSize: 13
          color: Theme.tertiary
        }
      }
      // Compact usage readout; click for Omarchy's full usage panel.
      Row {
        id: usageRow
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        visible: agents.usage.session >= 0
        Repeater {
          model: [
            { label: I18n.t("5s"), v: agents.usage.session },
            { label: I18n.t("7g"), v: agents.usage.weekly }
          ]
          delegate: Row {
            required property var modelData
            spacing: 6
            visible: modelData.v >= 0
            Label { text: modelData.label; font.pixelSize: 12; color: Theme.tertiary; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
              width: 40; height: 6; radius: 3
              anchors.verticalCenter: parent.verticalCenter
              color: Theme.fill
        GlassSheen {}
GlassSheen { strength: 0.7 }
              Rectangle {
                width: Math.max(6, parent.width * Math.min(1, modelData.v))
                height: parent.height; radius: 3
                color: modelData.v >= 0.9 ? Theme.red : modelData.v >= 0.7 ? Theme.orange : page.tint
              }
            }
            Label { text: Math.round(modelData.v * 100) + "%"; font.pixelSize: 12; tabular: true; color: Theme.secondary; anchors.verticalCenter: parent.verticalCenter }
          }
        }
      }
      MouseArea {
        anchors.fill: usageRow
        visible: usageRow.visible
        cursorShape: Qt.PointingHandCursor
        onClicked: agents.openUsage()
        Accessible.role: Accessible.Button
        Accessible.name: I18n.t("Kullanım ayrıntıları")
      }
      // Local token count (OpenCode) or LM Studio HTTP API port indicator
      Rectangle {
        id: statusPill
        readonly property bool lmServer: page.agentId === "lmstudio" && !!(agents.lmStudioInfo && agents.lmStudioInfo.server)
        readonly property string tokText: page.formatTokens(agents.usage.todayTokens)
        visible: !usageRow.visible && (lmServer || tokText !== "" || agents.usage.todayPrompts > 0)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        width: pillRow.implicitWidth + 16
        radius: 11
        color: Theme.fill
        GlassSheen {}
        Row {
          id: pillRow
          anchors.centerIn: parent
          spacing: 6
          Rectangle {
            visible: statusPill.lmServer
            anchors.verticalCenter: parent.verticalCenter
            width: 6; height: 6; radius: 3
            color: Theme.green
          }
          Label {
            anchors.verticalCenter: parent.verticalCenter
            text: statusPill.lmServer ? (":" + agents.lmStudioInfo.port)
              : (I18n.t("Bugün") + " · " + (statusPill.tokText || (agents.usage.todayPrompts + "×")))
            font.pixelSize: 11
            tabular: true
            color: Theme.secondary
          }
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: statusPill.lmServer ? agents.focusLmStudio(null) : agents.openUsage()
        }
      }
    }

    // ---- sessions
    Column {
      width: parent.width
      spacing: 8
      visible: page.sessions.length > 0

      Repeater {
        model: page.sessions
        delegate: Rectangle {
          id: row
          required property var modelData
          readonly property var s: modelData
          readonly property bool waiting: agents.displayState(s) === "waiting"
          // With several sessions, a click picks which one the feed shows.
          readonly property bool watched: page.sessions.length > 1 && page.previewSession !== null && page.previewSession.id === s.id
          readonly property bool watchable: page.sessions.length > 1 && !watched && agents.canPreview(s)
          width: parent.width
          height: 58
          radius: 18
          color: rowMouse.containsMouse || watched ? Theme.fillHover : Theme.fill
          GlassSheen { takeFill: true; fill: row.watched ? Theme.fillHover : Theme.fill; lit: rowMouse.containsMouse; pressed: rowMouse.pressed }
          border.width: waiting ? 1 : 0
          border.color: island.profile(s.agent).color
          Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (row.waiting) island.setPage("permission")
              else if (row.watchable) page.pickedId = row.s.id
              else if (row.s.agent === "lmstudio") agents.focusLmStudio(row.s)
              else agents.focusTerminal(row.s)
            }
          }

          Accessible.role: Accessible.ListItem
          Accessible.name: (s.project || "oturum") + ", " + page.stateText(s)

          Item {
            id: lead
            x: 14
            width: 24; height: 24
            anchors.verticalCenter: parent.verticalCenter
            AgentSpinner {
              anchors.centerIn: parent
              agent: row.s.agent || "claude"
              size: 20
              visible: agents.look(row.s).icon === ""
              running: page.working(row.s)
            }
            Icon { anchors.centerIn: parent; visible: agents.look(row.s).icon !== ""; name: agents.look(row.s).icon; size: 20; color: page.stateColor(row.s) }
          }

          Column {
            anchors.left: lead.right
            anchors.leftMargin: 12
            anchors.right: actions.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
              width: parent.width
              spacing: 8
              Label {
                text: row.s.project || "oturum"
                font.pixelSize: 14
                strong: true
                width: Math.max(40, Math.min(implicitWidth, parent.width - (modelBadge.visible ? modelBadge.width + 8 : 0) - (timeLabel.visible ? timeLabel.width + 8 : 0)))
              }
              Rectangle {
                id: modelBadge
                readonly property string labelText: page.shortModelBadge(row.s)
                readonly property bool isLocal: page.isLocalProvider(row.s.provider)
                visible: row.s.agent !== "lmstudio" && labelText !== ""
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: Math.min(modelBadgeText.implicitWidth + 10, 148)
                radius: 9
                color: isLocal ? Qt.rgba(0.616, 0.486, 0.957, 0.18) : Theme.ink(0.08)
                border.width: isLocal ? 1 : 0
                border.color: isLocal ? Qt.rgba(0.616, 0.486, 0.957, 0.36) : "transparent"
                Label {
                  id: modelBadgeText
                  anchors.centerIn: parent
                  width: Math.min(implicitWidth, parent.width - 10)
                  text: modelBadge.labelText
                  font.pixelSize: 10
                  strong: modelBadge.isLocal
                  color: modelBadge.isLocal ? "#9D7CF4" : Theme.secondary
                }
              }
              Label {
                id: timeLabel
                visible: agents.isBusy(row.s) && row.s.turnStartedAt > 0
                text: island.duration(island.nowMs - row.s.turnStartedAt) + (row.s.toolCount ? " · " + I18n.count(row.s.toolCount, "tool") : "")
                font.pixelSize: 12
                tabular: true
                color: Theme.tertiary
              }
            }
            ShimmerText {
              width: parent.width
              label: page.stateText(row.s)
              running: page.working(row.s)
              font.pixelSize: 13
              baseColor: page.stateColor(row.s)
              glowColor: island.profile(row.s.agent).glow
            }
          }

          Row {
            id: actions
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            IslandButton {
              visible: row.waiting
              size: 34
              text: I18n.t("Yanıtla")
              fontSize: 13
              prominent: true
              tint: island.profile(row.s.agent).color
              accessibleName: I18n.t("İzin isteğini yanıtla")
              onClicked: island.setPage("permission")
            }
            IslandButton {
              visible: !!row.s.cwd && row.s.agent !== "lmstudio"
              size: 34
              iconSource: island.apps.editorIcon
              icon: island.apps.editorIcon ? "" : "code"
              iconSize: 18
              accessibleName: I18n.t("Klasörü editörde aç")
              onClicked: { agents.openInEditor(row.s); island.collapse() }
            }
            IslandButton {
              visible: row.s.agent === "lmstudio" && !row.s.standalone
              size: 34
              icon: "x"
              enabled2: agents.lmActionKey === ""
              accessibleName: I18n.t("Modeli bellekten kaldır")
              onClicked: agents.unloadLmModel(row.s.model)
            }
            IslandButton {
              size: 34
              icon: row.s.agent === "lmstudio" ? "arrow-up-right" : "terminal"
              accessibleName: row.s.agent === "lmstudio" ? I18n.t("LM Studio'yu aç") : I18n.t("Terminale git")
              onClicked: {
                if (row.s.agent === "lmstudio") agents.focusLmStudio(row.s)
                else agents.focusTerminal(row.s)
                island.collapse()
              }
            }
          }
        }
      }
    }

    // ---- live feed
    // Compact by default; the corner button makes it taller. Either way it
    // scrolls (wheel or drag) and follows new output while you are at the
    // bottom; scroll up to read back and it stays where you left it.
    Rectangle {
      id: feed
      readonly property var s: page.previewSession
      readonly property bool busy: s !== null && agents.isBusy(s)
      readonly property var lines: page.feedLines(s && agents.previewOf === s.id ? agents.previewItems : [], s ? s.agent : "", busy)
      readonly property bool big: island.feedExpanded
      onLinesChanged: sync()
      Component.onCompleted: sync()
      function sync() {
        var src = lines
        for (var i = 0; i < src.length; i++) {
          var l = src[i]
          var row = { mark: l.g || "", body: l.t || "", tone: String(l.c), markTone: l.gc ? String(l.gc) : "",
            bold: !!l.strong, nested: !!l.indent }
          if (i < feedModel.count) {
            var old = feedModel.get(i)
            if (old.body !== row.body || old.mark !== row.mark || old.tone !== row.tone || old.markTone !== row.markTone) feedModel.set(i, row)
          } else feedModel.append(row)
        }
        if (feedModel.count > src.length) feedModel.remove(src.length, feedModel.count - src.length)
        if (feedList.follow) Qt.callLater(feedList.positionViewAtEnd)
      }
      visible: s !== null
      width: parent.width
      height: big ? 340 : 168
      radius: 16
      color: Theme.ink(0.05)
GlassSheen {}
      border.width: 1
      border.color: Theme.hairline
      // Quick and soft: starts at once, eases out.
      Behavior on height {
        enabled: !Theme.reduceMotion
        NumberAnimation { duration: 260; easing.type: Easing.OutQuint }
      }

      Accessible.role: Accessible.StaticText
      Accessible.name: I18n.t("Canlı akış") + ": " + lines.slice(-8).map(l => l.t).join(". ")

      Row {
        id: feedHead
        x: 14
        y: 10
        spacing: 7
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 6; height: 6; radius: 3
          color: feed.busy ? island.profile(feed.s ? feed.s.agent : "").color : Theme.tertiary
          SequentialAnimation on opacity {
            running: feed.busy && page.shown && !Theme.reduceMotion
            loops: Animation.Infinite
            onRunningChanged: if (!running) parent.opacity = 1
            NumberAnimation { to: 0.3; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
          }
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.t("Canlı akış") + (feed.s && feed.s.project ? " · " + feed.s.project : "")
          font.pixelSize: 11
          color: Theme.tertiary
        }
      }

      // Back to the newest line, when scrolled up.
      IslandButton {
        anchors.right: sizeButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: sizeButton.verticalCenter
        visible: !feedList.atYEnd && feedList.contentHeight > feedList.height
        size: 22
        iconSize: 12
        icon: "chevron-up"
        rotation: 180
        accessibleName: I18n.t("En alta git")
        onClicked: { feedList.follow = true; feedList.positionViewAtEnd() }
      }
      IslandButton {
        id: sizeButton
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: 5
        size: 22
        iconSize: 12
        icon: "chevron-up"
        rotation: feed.big ? 0 : 180
        accessibleName: feed.big ? I18n.t("Akışı küçült") : I18n.t("Akışı büyüt")
        onClicked: { island.springMode = "resize"; island.feedExpanded = !island.feedExpanded }
      }

      ListView {
        id: feedList
        anchors.top: feedHead.bottom
        anchors.topMargin: 7
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.right: parent.right
        anchors.rightMargin: 8
        clip: true
        spacing: 2
        // Updated row by row (not replaced) so the scroll position holds
        // while new output arrives.
        model: ListModel { id: feedModel }
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2400
        // Sticks to the newest line until you scroll up.
        property bool follow: true
        onMovementEnded: follow = atYEnd
        onContentHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
        onHeightChanged: if (follow) Qt.callLater(positionViewAtEnd)
        Component.onCompleted: positionViewAtEnd()
        WheelHandler {
          // Wheel scrolls the feed by lines, not the island.
          onWheel: event => {
            feedList.contentY = Math.max(0, Math.min(feedList.contentHeight - feedList.height,
              feedList.contentY - event.angleDelta.y / 120 * 51))
            feedList.follow = feedList.atYEnd
          }
        }

        delegate: Item {
          id: lineItem
          required property string mark
          required property string body
          required property string tone
          required property string markTone
          required property bool bold
          required property bool nested
          // Same shape as a feedLines() entry, for the drawing below.
          readonly property var modelData: ({ g: mark, t: body, c: tone, gc: markTone, strong: bold, indent: nested })
          width: ListView.view.width - 6
          // Expanded, long lines wrap so nothing is cut; compact, they end in "…".
          height: feed.big ? Math.max(15, lineText.implicitHeight) : 15
          Item {
            id: glyph
            x: modelData.indent ? 12 : 0
            width: 14
            height: 15
            // Bullets are drawn, not typed: fonts disagree on ● and ⏺.
            readonly property bool dot: modelData.g === "●" || modelData.g === "•"
            Rectangle {
              visible: glyph.dot
              anchors.verticalCenter: parent.verticalCenter
              x: 1
              width: modelData.g === "●" ? 7 : 5
              height: width
              radius: width / 2
              color: modelData.gc || modelData.c
            }
            Text {
              visible: !glyph.dot
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.g
              textFormat: Text.PlainText
              color: modelData.gc || modelData.c
              font.family: Theme.mono
              font.pixelSize: 11
              renderType: Text.NativeRendering
            }
          }
          Text {
            id: lineText
            anchors.left: glyph.right
            anchors.leftMargin: 3
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: feed.big ? 0 : Math.round((15 - implicitHeight) / 2)
            text: modelData.t
            color: modelData.c
            elide: feed.big ? Text.ElideNone : Text.ElideRight
            wrapMode: feed.big ? Text.WrapAnywhere : Text.NoWrap
            textFormat: Text.PlainText
            font.family: Theme.mono
            font.pixelSize: 12
            font.weight: modelData.strong ? Font.DemiBold : Font.Normal
            renderType: Text.NativeRendering
          }
        }

        Label {
          visible: feed.lines.length === 0
          anchors.centerIn: parent
          text: I18n.t("Henüz bir şey yok")
          font.pixelSize: 12
          color: Theme.tertiary
        }
      }

      // Scroll position, thin and only while there is more than fits.
      Rectangle {
        visible: feedList.contentHeight > feedList.height + 1
        anchors.right: parent.right
        anchors.rightMargin: 4
        y: feedList.y + feedList.visibleArea.yPosition * feedList.height
        width: 3
        height: Math.max(16, feedList.visibleArea.heightRatio * feedList.height)
        radius: 1.5
        color: Theme.ink(0.22)
      }
    }

    // ---- message box: type to the watched session
    Rectangle {
      id: composer
      readonly property var s: page.previewSession
      readonly property bool can: s !== null && agents.canMessage(s)
      readonly property color tint: island.profile(s ? s.agent : "").color
      visible: s !== null
      width: parent.width
      height: 42
      radius: 21
      color: field.activeFocus ? Theme.fillHover : Theme.fill
      GlassSheen {}
      border.width: field.activeFocus ? 1 : 0
      border.color: tint
      Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

      function send() {
        if (!agents.sendMessage(s, field.text)) return
        field.text = ""
        // Hands keyboard focus back before the text is typed into the terminal.
        island.collapse()
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: field.forceActiveFocus()
      }

      TextInput {
        id: field
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: sendButton.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        enabled: composer.can
        clip: true
        color: Theme.fg
        selectionColor: composer.tint
        selectedTextColor: Theme.onTint
        selectByMouse: true
        font.family: Theme.font
        font.pixelSize: 13
        renderType: Text.NativeRendering
        maximumLength: 4000
        Accessible.role: Accessible.EditableText
        Accessible.name: placeholder.text

        Keys.onReturnPressed: event => { composer.send(); event.accepted = true }
        Keys.onEnterPressed: event => { composer.send(); event.accepted = true }
        Keys.onEscapePressed: event => {
          if (text !== "") text = ""
          else island.collapse()
          event.accepted = true
        }

        Text {
          id: placeholder
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          visible: field.text === ""
          elide: Text.ElideRight
          text: !composer.s ? "" : composer.can
            ? I18n.t("%1 oturumuna yaz…").arg(composer.s.project || island.profile(composer.s.agent).name)
            : I18n.t("Önce terminaldeki soruyu yanıtla")
          color: Theme.tertiary
          font: field.font
          renderType: Text.NativeRendering
        }
      }

      IslandButton {
        id: sendButton
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        size: 30
        iconSize: 16
        icon: "arrow-up"
        prominent: field.text.trim() !== ""
        tint: composer.tint
        enabled2: composer.can && field.text.trim() !== ""
        accessibleName: I18n.t("Gönder")
        onClicked: composer.send()
      }
    }
    // Typing keeps the island open even if the pointer wanders off.
    Binding {
      target: page.island
      property: "composing"
      value: page.shown && field.activeFocus && field.text !== ""
    }

    // ---- empty / setup state
    Rectangle {
      // (only on an agent's own page)
      visible: page.sessions.length === 0 && !page.overview
      width: parent.width
      height: 72
      radius: 18
      color: Theme.fill
      Column {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.right: connect.visible ? connect.left : parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label {
          width: parent.width
          text: page.agentId === "lmstudio" ? I18n.t("Model yüklü değil")
            : !page.connectable ? I18n.t("%1 canlı oturum paylaşmıyor").arg(page.product)
            : page.connected ? I18n.t("Aktif oturum yok") : I18n.t("%1 bağlı değil").arg(page.product)
          font.pixelSize: 14
          strong: true
        }
        Label {
          width: parent.width
          text: page.agentId === "lmstudio"
            ? (agents.lmStudioInfo && agents.lmStudioInfo.running ? I18n.t("Yerel sunucu aktif") : I18n.t("LM Studio'yu başlatınca modeller burada görünür."))
            : !page.connectable ? I18n.t("Kısayol ve kullanım bilgisi yine burada.")
            : page.connected ? I18n.t("Bir oturum başlatınca burada görünür.")
            : page.profile.integration === "full" ? I18n.t("Bağlayınca oturumlar ve izinler burada.")
            : I18n.t("Bağlayınca oturumlar burada.")
          font.pixelSize: 13
          color: Theme.secondary
        }
      }
      IslandButton {
        id: connect
        visible: page.connectable && !page.connected
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 36
        text: I18n.t("Bağla")
        prominent: true
        tint: page.tint
        accessibleName: I18n.t("%1 bağlantısını kur").arg(page.product)
        onClicked: agents.installHooks(page.agentId)
      }
    }

    // ---- downloaded local models (LM Studio)
    Rectangle {
      id: lmLibrary
      readonly property var downloaded: (agents.lmStudioInfo && agents.lmStudioInfo.downloaded) ? agents.lmStudioInfo.downloaded : []
      visible: !page.overview && page.agentId === "lmstudio" && downloaded.length > 0
      width: parent.width
      height: 36 + Math.min(180, downloaded.length * 40)
      radius: 18
      color: Theme.ink(0.05)
      GlassSheen {}
      border.width: 1
      border.color: Theme.hairline

      Row {
        x: 14
        y: 10
        spacing: 6
        Icon { anchors.verticalCenter: parent.verticalCenter; source: island.logoFor("lmstudio"); size: 13; color: "#9D7CF4" }
        Label { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("Yerel modeller"); font.pixelSize: 11; color: Theme.tertiary }
      }

      ListView {
        anchors.top: parent.top
        anchors.topMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: lmLibrary.downloaded
        delegate: Item {
          id: mRow
          required property var modelData
          readonly property bool isLoaded: !!(agents.sessions["lmstudio:" + modelData.key])
          readonly property bool isBusyKey: agents.lmActionKey === modelData.key
          readonly property string metaStr: [modelData.params, modelData.quant].filter(x => !!x).join(" · ")
          width: ListView.view.width
          height: 40

          Column {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: mActionBtn.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label {
              width: parent.width
              text: modelData.name || modelData.key
              font.pixelSize: 13
              strong: mRow.isLoaded
              color: mRow.isLoaded ? "#9D7CF4" : Theme.fg
            }
            Label {
              visible: mRow.metaStr !== "" || modelData.type === "embedding"
              width: parent.width
              text: mRow.metaStr + (modelData.type === "embedding" ? (mRow.metaStr ? " · " : "") + "embedding" : "")
              font.pixelSize: 11
              color: Theme.tertiary
            }
          }

          IslandButton {
            id: mActionBtn
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            size: 28
            fontSize: 11
            text: mRow.isBusyKey ? I18n.t("Yükleniyor…") : mRow.isLoaded ? I18n.t("Kaldır") : I18n.t("Yükle")
            tint: mRow.isLoaded ? Theme.secondary : "#9D7CF4"
            prominent: !mRow.isLoaded
            enabled2: agents.lmActionKey === ""
            accessibleName: mRow.isLoaded ? I18n.t("Modeli bellekten kaldır") : I18n.t("Modeli yükle")
            onClicked: mRow.isLoaded ? agents.unloadLmModel(mRow.modelData.key) : agents.loadLmModel(mRow.modelData.key)
          }
        }
      }
    }

    // ---- shortcuts
    Row {
      visible: !page.overview
      spacing: 8
      RefreshButton { size: 36; anchors.verticalCenter: parent.verticalCenter }
      IslandButton {
        size: 36
        icon: page.agentId === "lmstudio" ? "arrow-up-right" : "plus"
        text: page.agentId === "lmstudio" ? I18n.t("LM Studio'yu aç") : I18n.t("Yeni oturum")
        fontSize: 13
        accessibleName: page.agentId === "lmstudio" ? I18n.t("LM Studio'yu aç") : (I18n.t("Yeni ") + page.profile.name + I18n.t(" oturumu"))
        onClicked: { agents.newSession(page.agentId); island.collapse() }
      }
      IslandButton {
        visible: page.agentId !== "lmstudio"
        size: 36
        icon: "terminal"
        text: I18n.t("Terminal")
        fontSize: 13
        enabled2: page.sessions.length > 0 || (agents.focusSession !== null && agents.focusSession.agent !== "lmstudio")
        accessibleName: I18n.t("Etkin oturumun terminaline git")
        onClicked: {
          var t = page.sessions.find(x => x.agent !== "lmstudio") || (agents.focusSession && agents.focusSession.agent !== "lmstudio" ? agents.focusSession : null)
          agents.focusTerminal(t)
          island.collapse()
        }
      }
      IslandButton {
        visible: page.agentId !== "lmstudio"
        size: 36
        iconSource: island.apps.editorIcon
        icon: island.apps.editorIcon ? "" : "code"
        text: island.editorLabels[island.apps.editor] || I18n.t("Editör")
        fontSize: 13
        enabled2: page.sessions.some(x => !!x.cwd) || (agents.focusSession !== null && !!agents.focusSession.cwd)
        accessibleName: I18n.t("Etkin oturumun klasörünü editörde aç")
        onClicked: {
          var t = page.sessions.find(x => !!x.cwd) || agents.focusSession
          agents.openInEditor(t)
          island.collapse()
        }
      }
      IslandButton {
        size: 36
        icon: "trash"
        filled: false
        tint: Theme.secondary
        visible: agents.sessionList.some(s => s.agent !== "lmstudio" && !agents.isBusy(s))
        accessibleName: I18n.t("Biten oturumları temizle")
        onClicked: agents.clearFinished()
      }
    }
  }
}
