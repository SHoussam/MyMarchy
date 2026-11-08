import QtQuick
import "../components"

// Home: time and battery at a glance, the usage of every agent that is
// running (rings, like Claude Code's), and the launch shortcuts as a grid.
Page {
  id: page

  property var island
  property bool showStats: island.cfg("showStats") !== undefined ? island.cfg("showStats") : true
  implicitHeight: col.implicitHeight + 8

  // Usage cards: every installed agent with usage data (running ones first).
  readonly property var usageAgents: island.usageAgents

  component StatCard: Rectangle {
    id: statCard
    property string iconName: ""
    property string title: ""
    property string badge: ""
    property string subtitle: ""
    property real progress: 0
    property color tone: Theme.blue

    width: Math.floor((col.width - 8) / 2)
    height: 64
    radius: 18
    color: statMouse.pressed ? Theme.fillPressed : statMouse.containsMouse ? Theme.fillHover : Theme.fill
    GlassSheen { takeFill: true; lit: statMouse.containsMouse }
    scale: statMouse.pressed ? 0.96 : 1
    Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
    }

    Row {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 12

      Item {
        width: 38; height: 38
        anchors.verticalCenter: parent.verticalCenter
        ProgressRing {
          anchors.fill: parent
          thickness: 4
          progress: statCard.progress
          color: statCard.tone
        }
        Label {
          anchors.centerIn: parent
          text: Math.round(statCard.progress * 100)
          font.pixelSize: 11
          strong: true
          tabular: true
          horizontalAlignment: Text.AlignHCenter
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 50
        spacing: 2

        Row {
          width: parent.width
          spacing: 6
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: statCard.iconName
            size: 14
            color: statCard.tone
          }
          Label {
            anchors.verticalCenter: parent.verticalCenter
            text: statCard.title
            font.pixelSize: 12
            strong: true
          }
          Rectangle {
            visible: statCard.badge !== ""
            anchors.verticalCenter: parent.verticalCenter
            height: 16
            radius: 8
            width: badgeTxt.implicitWidth + 8
            color: Qt.rgba(statCard.tone.r, statCard.tone.g, statCard.tone.b, 0.16)
            Label {
              id: badgeTxt
              anchors.centerIn: parent
              text: statCard.badge
              font.pixelSize: 9
              strong: true
              color: statCard.tone
            }
          }
        }

        Label {
          width: parent.width
          text: statCard.subtitle
          font.pixelSize: 11
          color: Theme.secondary
          tabular: true
        }
      }
    }

    MouseArea {
      id: statMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
    }

    Accessible.role: Accessible.Button
    Accessible.name: statCard.title + " " + Math.round(statCard.progress * 100) + "%, " + statCard.subtitle
    Accessible.onPressAction: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
  }

  component Gauge: Column {
    id: gauge
    property real value: 0
    property string caption: ""
    property color tone: island.agentColor
    property int ring: 40
    spacing: 4
    Item {
      width: gauge.ring; height: gauge.ring
      anchors.horizontalCenter: parent.horizontalCenter
      ProgressRing {
        anchors.fill: parent
        thickness: 4
        progress: gauge.value
        color: gauge.tone
      }
      Label {
        anchors.centerIn: parent
        text: Math.round(gauge.value * 100)
        font.pixelSize: gauge.ring >= 40 ? 12 : 11
        strong: true
        tabular: true
        horizontalAlignment: Text.AlignHCenter
      }
    }
    Label {
      anchors.horizontalCenter: parent.horizontalCenter
      text: gauge.caption
      font.pixelSize: 11
      color: Theme.tertiary
      horizontalAlignment: Text.AlignHCenter
    }
    Accessible.role: Accessible.ProgressBar
    Accessible.name: caption + I18n.t(" yüzde ") + Math.round(value * 100)
  }

  Column {
    id: col
    width: parent.width
    spacing: 10

    // ---- unified top row: agent usage cards on the left, battery + controls card on the right
    Item {
      width: parent.width
      height: 68

      Row {
        id: usageRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        readonly property var shown: page.usageAgents.filter(id => {
          var u = island.agents.usageOf(id)
          return u.session >= 0 || u.weekly >= 0
        })
        Repeater {
          model: usageRow.shown
          delegate: Rectangle {
            id: card
            required property string modelData
            readonly property var u: island.agents.usageOf(modelData)
            readonly property color tint: island.profile(modelData).color
            width: cardRow.implicitWidth + 22
            height: 66
            radius: 18
            color: Theme.fill
            GlassSheen {}
            Row {
              id: cardRow
              anchors.centerIn: parent
              spacing: 10
              Icon {
                anchors.verticalCenter: parent.verticalCenter
                source: island.logoFor(card.modelData)
                name: source ? "" : "sparkles"
                color: card.tint
                size: 20
              }
              Gauge {
                visible: card.u.session >= 0
                ring: 34
                value: Math.max(0, card.u.session)
                caption: I18n.t("5 sa")
                tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : card.tint
              }
              Gauge {
                visible: card.u.weekly >= 0
                ring: 34
                value: Math.max(0, card.u.weekly)
                caption: I18n.t("Hafta")
                tone: value >= 0.9 ? Theme.red : value >= 0.7 ? Theme.orange : card.tint
              }
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: island.showAgent(card.modelData)
            }
            Accessible.role: Accessible.Button
            Accessible.name: island.profile(modelData).product + ", " + I18n.t("5 sa") + " " + Math.round(Math.max(0, u.session) * 100) + "%, "
              + I18n.t("Hafta") + " " + Math.round(Math.max(0, u.weekly) * 100) + "%"
          }
        }
      }

      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: controlsRow.implicitWidth + 22
        height: 66
        radius: 18
        color: Theme.fill
        GlassSheen {}

        Row {
          id: controlsRow
          anchors.centerIn: parent
          spacing: 12
          Gauge {
            visible: island.hasBattery
            ring: 34
            value: island.batteryPercent / 100
            caption: I18n.t("Pil")
            tone: island.batteryPercent <= 15 ? Theme.red : Theme.green
          }
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            // Theme: Normal or Liquid Glass; click for the list.
            Rectangle {
              width: 30; height: 30
              radius: 15
              color: themeMouse.containsMouse || page.themeOpen ? Theme.fillHover : Theme.fill
              GlassSheen { takeFill: true; fill: page.themeOpen ? Theme.fillHover : Theme.fill; lit: themeMouse.containsMouse; pressed: themeMouse.pressed }
              Icon {
                anchors.centerIn: parent
                name: island.glassOn ? "droplet" : island.lightMode ? "sun" : "moon"
                size: 15
                color: Theme.fg
              }
              MouseArea {
                id: themeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { page.langOpen = false; page.themeOpen = !page.themeOpen }
              }
              Accessible.role: Accessible.ComboBox
              Accessible.name: I18n.t("Tema") + ": " + (island.lightMode ? I18n.tc("Açık|appearance") : I18n.t("Koyu")) + (island.glassOn ? ", Liquid Glass" : "")
              Accessible.onPressAction: page.themeOpen = !page.themeOpen
            }
            // Language: the current flag; click for the list.
            Rectangle {
              id: langButton
              width: 30; height: 30
              radius: 15
              color: langMouse.containsMouse || page.langOpen ? Theme.fillHover : Theme.fill
              GlassSheen { takeFill: true; fill: page.langOpen ? Theme.fillHover : Theme.fill; lit: langMouse.containsMouse; pressed: langMouse.pressed }
              Flag {
                anchors.centerIn: parent
                code: I18n.lang
                size: 18
              }
              MouseArea {
                id: langMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { page.themeOpen = false; page.langOpen = !page.langOpen }
              }
              Accessible.role: Accessible.ComboBox
              Accessible.name: I18n.t("Dil") + ": " + (I18n.languages.find(l => l.code === I18n.lang) || {}).name
              Accessible.onPressAction: page.langOpen = !page.langOpen
            }
            // Refresh: click restarts the Omarchy shell (bar and island reload,
            // the island drops back in); right-click only clears a stuck island.
            IslandButton {
              size: 30
              iconSize: 15
              icon: "restart"
              accessibleName: I18n.t("Omarchy kabuğunu yeniden başlat")
              hint: I18n.t("Sağ tık: yalnızca adayı yenile")
              onClicked: island.restartShell()
              onRightClicked: island.resetIsland()
            }
          }
        }
      }
    }

    // ---- screen recording in progress
    Rectangle {
      visible: island.recording.active
      width: parent.width
      height: 46
      radius: 23
      color: Qt.rgba(1, 0.27, 0.23, 0.14)
      Row {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 12; height: 12; radius: 6
          color: Theme.red
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: I18n.t("Ekran kaydı  ") + island.timer.format(island.nowMs - island.recording.startedAt, false)
          font.pixelSize: 14
          strong: true
          tabular: true
          color: Theme.red
        }
      }
      IslandButton {
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        size: 34
        text: I18n.t("Durdur")
        prominent: true
        tint: Theme.red
        accessibleName: I18n.t("Ekran kaydını durdur")
        onClicked: { island.recording.stop(); island.collapse() }
      }
    }

    // ---- Section Header: title, btop shortcut and view switcher
    Item {
      width: parent.width
      height: 26

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Icon {
          anchors.verticalCenter: parent.verticalCenter
          name: page.showStats ? "activity" : "arrow-up-right"
          size: 13
          color: Theme.secondary
        }
        Label {
          anchors.verticalCenter: parent.verticalCenter
          text: page.showStats ? I18n.t("Donanım İstatistikleri") : I18n.t("Kısayollar")
          font.pixelSize: 11
          strong: true
          color: Theme.secondary
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        IslandButton {
          width: 26; height: 26
          size: 26
          iconSize: 12
          icon: "terminal"
          accessibleName: I18n.t("btop sistem monitörünü aç")
          hint: I18n.t("btop sistem monitörü")
          onClicked: Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"])
        }

        IslandButton {
          width: 26; height: 26
          size: 26
          iconSize: 12
          icon: page.showStats ? "arrow-up-right" : "activity"
          accessibleName: page.showStats ? I18n.t("Kısayolları göster") : I18n.t("Donanım istatistiklerini göster")
          hint: page.showStats ? I18n.t("Kısayollara geç") : I18n.t("Donanıma geç")
          onClicked: { page.showStats = !page.showStats; island.setConfig("showStats", page.showStats) }
        }
      }
    }

    // ---- Hardware statistics view
    Grid {
      id: hardwareGrid
      visible: page.showStats
      width: parent.width
      columns: 2
      columnSpacing: 8
      rowSpacing: 8

      // CPU
      StatCard {
        iconName: "cpu"
        title: I18n.t("CPU")
        badge: island.hardware.cpuTemp > 0 ? (island.hardware.cpuTemp + "°C") : ""
        subtitle: island.hardware.cpuModel || "Intel Core"
        progress: island.hardware.cpuUsage
        tone: progress >= 0.85 ? Theme.red : progress >= 0.65 ? Theme.orange : Theme.blue
      }

      // RAM
      StatCard {
        iconName: "ram"
        title: I18n.t("Bellek")
        badge: island.hardware.memUsed > 0 ? (island.hardware.memUsed.toFixed(1) + " GB") : ""
        subtitle: island.hardware.memTotal > 0 ? (island.hardware.memUsed.toFixed(1) + " / " + island.hardware.memTotal.toFixed(0) + " GB") : I18n.t("RAM")
        progress: island.hardware.memUsage
        tone: progress >= 0.85 ? Theme.red : progress >= 0.70 ? Theme.orange : Theme.green
      }

      // GPU
      StatCard {
        iconName: "gpu"
        title: island.hardware.gpuName || I18n.t("GPU")
        badge: island.hardware.gpuTemp > 0 ? (island.hardware.gpuTemp + "°C") : ""
        subtitle: island.hardware.hasGpu && island.hardware.gpuMemTotal > 0 ? ("VRAM " + island.hardware.gpuMemUsed.toFixed(1) + " / " + island.hardware.gpuMemTotal.toFixed(0) + " GB") : I18n.t("Grafik")
        progress: island.hardware.gpuUsage
        tone: progress >= 0.85 ? Theme.red : progress >= 0.65 ? Theme.orange : Theme.cyan
      }

      // Storage
      StatCard {
        iconName: "disk"
        title: I18n.t("Depolama")
        badge: island.hardware.diskTotal > 0 ? (island.hardware.diskTotal.toFixed(0) + " GB") : ""
        subtitle: island.hardware.diskTotal > 0 ? (island.hardware.diskUsed.toFixed(0) + " GB / " + island.hardware.diskTotal.toFixed(0) + " GB") : I18n.t("Kök dizin")
        progress: island.hardware.diskUsage
        tone: progress >= 0.90 ? Theme.red : progress >= 0.75 ? Theme.orange : Theme.orange
      }
    }

    // ---- shortcuts: a grid of tiles (icon and name side by side), three
    // per row, so marks have room and the page stays short.
    Grid {
      id: grid
      visible: !page.showStats
      width: parent.width
      columns: 3
      columnSpacing: 8
      rowSpacing: 8
      readonly property real cell: (width - columnSpacing * (columns - 1)) / columns

      Repeater {
        model: island.shortcuts
        delegate: Rectangle {
          id: tile
          required property var modelData
          width: grid.cell
          height: 46
          radius: 16
          color: tileMouse.pressed ? Theme.fillPressed : tileMouse.containsMouse ? Theme.fillHover : Theme.fill
          GlassSheen { takeFill: true; lit: tileMouse.containsMouse }
          scale: tileMouse.pressed ? 0.96 : 1
          Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
          Behavior on scale {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
          }
          Icon {
            id: tileIcon
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            size: 22
            name: tile.modelData.image ? "" : (tile.modelData.icon || "arrow-up-right")
            source: tile.modelData.image || ""
            color: Theme.fg
          }
          Label {
            anchors.left: tileIcon.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: tile.modelData.label || ""
            font.pixelSize: 13
          }
          MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.runShortcut(tile.modelData)
          }
          Accessible.role: Accessible.Button
          Accessible.name: modelData.label || I18n.t("Kısayol")
          Accessible.onPressAction: island.runShortcut(modelData)
        }
      }
    }

  }

  // ---- language list
  property bool langOpen: false
  onShownChanged: if (!shown) { langOpen = false; themeOpen = false }

  MouseArea {
    anchors.fill: parent
    visible: page.langOpen
    z: 9
    onClicked: page.langOpen = false
  }
  Rectangle {
    z: 10
    anchors.right: parent.right
    y: 64
    width: 176
    height: langList.implicitHeight + 12
    radius: 16
    color: Theme.popup
    GlassSheen {}
    border.width: 1
    border.color: Theme.edge
    opacity: page.langOpen ? 1 : 0
    visible: opacity > 0.01
    scale: page.langOpen ? 1 : 0.94
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.005 }
    }

    Column {
      id: langList
      x: 6; y: 6
      width: parent.width - 12
      spacing: 2
      Repeater {
        model: I18n.languages
        delegate: Rectangle {
          id: langRow
          required property var modelData
          readonly property bool current: modelData.code === I18n.lang
          width: parent.width
          height: 36
          radius: 11
          color: rowMouse.containsMouse && !Theme.glass ? Theme.fillHover : current ? Theme.fill : "transparent"
          GlassSheen { strength: 0.8; visible: Theme.glass && parent.current; takeFill: true; lit: rowMouse.containsMouse; pressed: rowMouse.pressed }
          Flag {
            id: rowFlag
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            code: langRow.modelData.code
            size: 20
          }
          Label {
            anchors.left: rowFlag.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: langRow.modelData.name
            font.pixelSize: 13
            strong: langRow.current
          }
          Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: langRow.current
            name: "check"
            size: 15
            color: Theme.blue
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { island.setConfig("language", langRow.modelData.code); page.langOpen = false }
          }
          Accessible.role: Accessible.ListItem
          Accessible.name: langRow.modelData.name
        }
      }
    }
  }

  // ---- theme list
  property bool themeOpen: false
  MouseArea {
    anchors.fill: parent
    visible: page.themeOpen
    z: 9
    onClicked: page.themeOpen = false
  }
  Rectangle {
    z: 10
    anchors.right: parent.right
    y: 64
    width: 196
    height: themeList.implicitHeight + 12
    radius: 16
    color: Theme.popup
    GlassSheen {}
    border.width: 1
    border.color: Theme.edge
    opacity: page.themeOpen ? 1 : 0
    visible: opacity > 0.01
    scale: page.themeOpen ? 1 : 0.94
    transformOrigin: Item.TopRight
    Behavior on opacity { NumberAnimation { duration: Theme.ms(140) } }
    Behavior on scale {
      enabled: !Theme.reduceMotion
      SpringAnimation { spring: 5; damping: 0.45; epsilon: 0.005 }
    }
    Column {
      id: themeList
      x: 6; y: 6
      width: parent.width - 12
      spacing: 2
      // Appearance: auto (Omarchy theme), dark, or light.
      Repeater {
        model: [
          { mode: "auto", name: "Auto (Theme)", icon: "sparkles" },
          { mode: "dark", name: I18n.t("Koyu"), icon: "moon" },
          { mode: "light", name: I18n.tc("Açık|appearance"), icon: "sun" }
        ]
        delegate: Rectangle {
          id: modeRow
          required property var modelData
          readonly property bool current: modelData.mode === island.appearanceCfg
          width: parent.width
          height: 36
          radius: 11
          color: modeMouse.containsMouse && !Theme.glass ? Theme.fillHover : current ? Theme.fill : "transparent"
          GlassSheen { strength: 0.8; visible: Theme.glass && parent.current; takeFill: true; lit: modeMouse.containsMouse; pressed: modeMouse.pressed }
          Icon {
            id: modeIcon
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            name: modeRow.modelData.icon
            size: 18
            color: Theme.fg
          }
          Label {
            anchors.left: modeIcon.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: modeRow.modelData.name
            font.pixelSize: 13
            strong: modeRow.current
          }
          Icon {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: modeRow.current
            name: "check"
            size: 15
            color: Theme.blue
          }
          MouseArea {
            id: modeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: island.setConfig("appearance", modeRow.modelData.mode)
          }
          Accessible.role: Accessible.RadioButton
          Accessible.name: modeRow.modelData.name
          Accessible.checked: modeRow.current
        }
      }
      Rectangle { width: parent.width - 16; x: 8; height: 1; color: Theme.hairline }
      // Liquid Glass: on or off, in either appearance.
      Rectangle {
        width: parent.width
        height: 38
        radius: 11
        color: glassMouse.containsMouse && !Theme.glass ? Theme.fillHover : "transparent"
        Icon {
          id: glassIcon
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          name: "droplet"
          size: 18
          color: Theme.fg
        }
        Label {
          anchors.left: glassIcon.right
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: "Liquid Glass"
          font.pixelSize: 13
          strong: island.glassOn
        }
        // Switch, iOS style.
        Rectangle {
          id: track
          anchors.right: parent.right
          anchors.rightMargin: 8
          anchors.verticalCenter: parent.verticalCenter
          width: 38; height: 22; radius: 11
          color: island.glassOn ? Theme.green : Theme.ink(Theme.light ? 0.16 : 0.22)
          Behavior on color { ColorAnimation { duration: Theme.ms(160) } }
          Rectangle {
            width: 18; height: 18; radius: 9
            y: 2
            x: island.glassOn ? parent.width - width - 2 : 2
            color: "#ffffff"
            Behavior on x {
              enabled: !Theme.reduceMotion
              SpringAnimation { spring: 6; damping: 0.55; epsilon: 0.2 }
            }
          }
        }
        MouseArea {
          id: glassMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: island.setConfig("glass", !island.glassOn)
        }
        Accessible.role: Accessible.CheckBox
        Accessible.name: "Liquid Glass"
        Accessible.checked: island.glassOn
        Accessible.onPressAction: island.setConfig("glass", !island.glassOn)
      }
    }
  }
}
