import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win
    width: 480
    height: 484
    minimumWidth: 420
    minimumHeight: 420
    visible: true
    title: qsTr("Dynamic Island")
    color: theme.background

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    property bool quitAfterRestart: false

    readonly property color cardColor: Qt.tint(theme.background, Qt.rgba(1, 1, 1, 0.055))
    readonly property color cardHoverColor: Qt.tint(theme.background, Qt.rgba(1, 1, 1, 0.10))
    readonly property color borderColor: Qt.rgba(1, 1, 1, 0.11)
    readonly property color mutedTextColor: Qt.rgba(0.98, 0.99, 0.98, 0.62)
    readonly property color okColor: "#87a9b0"
    readonly property color warnColor: "#d99b52"
    readonly property color errColor: "#d4736c"

    readonly property color stateTint: {
        if (backend.busy)
            return theme.accent
        switch (backend.stateLevel) {
        case "ok": return okColor
        case "degraded": return warnColor
        default: return errColor
        }
    }

    Connections {
        target: backend
        function onActionCompleted(ok) {
            if (win.quitAfterRestart) {
                win.quitAfterRestart = false
                Qt.quit()
            }
        }
    }

    function requestClose() {
        if (backend.busy && backend.busyAction === "restart") {
            win.quitAfterRestart = true
            return
        }
        Qt.quit()
    }

    onClosing: function(close) {
        if (backend.busy && backend.busyAction === "restart") {
            close.accepted = false
            win.quitAfterRestart = true
        }
    }

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: { if (win.helpVisible) win.helpVisible = false; else win.requestClose() } }
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: win.requestClose() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.restartShell() }
    Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.restartShell() }
    Shortcut { sequence: "R"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.restartShell() }
    Shortcut { sequence: "V"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.reviveSurface() }
    Shortcut { sequence: "T"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.toggleExpand() }
    Shortcut { sequence: "F"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.toggleFocusMode() }
    Shortcut { sequence: "Z"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.resetState() }
    Shortcut { sequence: "S"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: backend.refresh() }

    component KeyBadge: Rectangle {
        property string keyText: ""
        property bool onAccent: false
        implicitWidth: Math.max(24, keyLabel.implicitWidth + 12)
        implicitHeight: 22
        radius: Math.min(4, theme.radius)
        color: onAccent
            ? (theme.accentForeground === "black" ? Qt.rgba(0, 0, 0, 0.15) : Qt.rgba(1, 1, 1, 0.16))
            : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: onAccent
            ? (theme.accentForeground === "black" ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.25))
            : Qt.rgba(1, 1, 1, 0.14)

        Label {
            id: keyLabel
            anchors.centerIn: parent
            text: parent.keyText
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.family: "monospace"
            color: parent.onAccent ? theme.accentForeground : win.mutedTextColor
        }
    }

    component ActionTile: Rectangle {
        id: tile
        property string titleText: ""
        property string subtitleText: ""
        property string keyHint: ""
        property bool activeHighlight: false
        signal triggered()

        Layout.fillWidth: true
        implicitHeight: 74
        radius: theme.radius
        color: !backend.busy && tileMouse.containsMouse ? win.cardHoverColor : win.cardColor
        border.width: 1
        border.color: activeHighlight
            ? Qt.rgba(Qt.color(theme.accent).r, Qt.color(theme.accent).g, Qt.color(theme.accent).b, 0.65)
            : (tileMouse.containsMouse && !backend.busy ? Qt.rgba(1, 1, 1, 0.22) : win.borderColor)
        opacity: backend.busy ? 0.55 : 1.0

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: tile.titleText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: theme.foreground
                    elide: Text.ElideRight
                }

                KeyBadge {
                    keyText: tile.keyHint
                }
            }

            Label {
                Layout.fillWidth: true
                text: tile.subtitleText
                font.pixelSize: 11
                color: win.mutedTextColor
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: !backend.busy
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: tile.triggered()
        }
    }

    // Right-to-left languages mirror the window; Translator sets layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // Header with mini island silhouette + state pill + help toggle
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Mini notch silhouette reflecting live attachment & mode
                Rectangle {
                    id: notchPreview
                    implicitWidth: 60
                    implicitHeight: 28
                    radius: Math.min(14, Math.max(4, theme.radius * 2))
                    color: backend.layerAttached ? "#060606" : "transparent"
                    border.width: backend.layerAttached ? 1 : 1.5
                    border.color: backend.layerAttached ? Qt.rgba(1, 1, 1, 0.22) : win.stateTint

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 8
                            height: 8
                            radius: 4
                            color: win.stateTint
                        }

                        Rectangle {
                            width: backend.islandMode === "expanded" ? 24 : 14
                            height: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, backend.layerAttached ? 0.85 : 0.35)
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Label {
                        text: qsTr("Dynamic Island")
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        color: theme.foreground
                    }

                    Label {
                        readonly property string _lang: translator.language
                        text: {
                            if (backend.layerAttached && backend.layerMonitor !== "")
                                return qsTr("Control center · %1").arg(backend.layerMonitor)
                            return qsTr("Omarchy bar notch control & recovery")
                        }
                        font.pixelSize: 11
                        color: win.mutedTextColor
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    implicitHeight: 24
                    implicitWidth: stateRow.implicitWidth + 16
                    radius: Math.min(4, theme.radius)
                    color: Qt.rgba(win.stateTint.r, win.stateTint.g, win.stateTint.b, 0.16)
                    border.width: 1
                    border.color: Qt.rgba(win.stateTint.r, win.stateTint.g, win.stateTint.b, 0.45)

                    RowLayout {
                        id: stateRow
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            color: win.stateTint
                        }

                        Label {
                            text: {
                                if (backend.busy) return qsTr("Working")
                                if (backend.stateLevel === "ok") return qsTr("Healthy")
                                if (backend.stateLevel === "degraded") return qsTr("Detached")
                                return qsTr("Offline")
                            }
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: win.stateTint
                        }
                    }
                }

                Rectangle {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Math.min(4, theme.radius)
                    color: helpMouse.containsMouse ? win.cardHoverColor : win.cardColor
                    border.width: 1
                    border.color: win.borderColor

                    Label {
                        anchors.centerIn: parent
                        text: "?"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: theme.foreground
                    }

                    MouseArea {
                        id: helpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.helpVisible = !win.helpVisible
                    }
                }
            }

            // Live Telemetry Card (2x2)
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: telemetryGrid.implicitHeight + 24
                radius: theme.radius
                color: win.cardColor
                border.width: 1
                border.color: win.borderColor

                GridLayout {
                    id: telemetryGrid
                    anchors.fill: parent
                    anchors.margins: 12
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: qsTr("Layer Surface")
                            font.pixelSize: 11
                            color: win.mutedTextColor
                        }
                        Label {
                            text: backend.layerAttached
                                ? (backend.glowAttached
                                    ? qsTr("Attached (%1 + glow)").arg(backend.layerMonitor || qsTr("active"))
                                    : qsTr("Attached (%1)").arg(backend.layerMonitor || qsTr("active")))
                                : qsTr("Detached")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: backend.layerAttached ? theme.foreground : win.warnColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: qsTr("Shell IPC")
                            font.pixelSize: 11
                            color: win.mutedTextColor
                        }
                        Label {
                            text: backend.ipcOnline
                                ? (backend.surfaceReady ? qsTr("Online · ready") : qsTr("Online · mounting"))
                                : qsTr("Unreachable")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: backend.ipcOnline ? theme.foreground : win.errColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: qsTr("Current State")
                            font.pixelSize: 11
                            color: win.mutedTextColor
                        }
                        Label {
                            text: {
                                if (!backend.ipcOnline) return qsTr("Unavailable")
                                return backend.islandPage !== ""
                                    ? qsTr("%1 · %2").arg(backend.islandMode).arg(backend.islandPage)
                                    : backend.islandMode
                            }
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: theme.foreground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            text: qsTr("Focus Mode")
                            font.pixelSize: 11
                            color: win.mutedTextColor
                        }
                        Label {
                            text: backend.focusMode
                                ? qsTr("On (click only)")
                                : qsTr("Off (hover expands)")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: backend.focusMode ? theme.accent : theme.foreground
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Explicit Warning / Error Banner (shown whenever broken or failed)
            Rectangle {
                Layout.fillWidth: true
                visible: backend.lastError !== "" || (!backend.busy && backend.stateLevel !== "ok")
                implicitHeight: visible ? noticeRow.implicitHeight + 16 : 0
                radius: theme.radius
                color: Qt.rgba((backend.lastError !== "" ? win.errColor : win.stateTint).r,
                               (backend.lastError !== "" ? win.errColor : win.stateTint).g,
                               (backend.lastError !== "" ? win.errColor : win.stateTint).b, 0.14)
                border.width: 1
                border.color: Qt.rgba((backend.lastError !== "" ? win.errColor : win.stateTint).r,
                                      (backend.lastError !== "" ? win.errColor : win.stateTint).g,
                                      (backend.lastError !== "" ? win.errColor : win.stateTint).b, 0.48)

                RowLayout {
                    id: noticeRow
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 12
                        color: theme.foreground
                        text: backend.lastError !== "" ? backend.lastError : backend.statusText
                    }
                }
            }

            // Primary Action: Instant Restart (Space / Enter / R)
            Rectangle {
                id: restartBtn
                Layout.fillWidth: true
                implicitHeight: 52
                radius: theme.radius
                color: {
                    const base = Qt.color(theme.accent)
                    if (backend.busy)
                        return Qt.rgba(base.r, base.g, base.b, 0.65)
                    if (restartMouse.pressed)
                        return Qt.darker(base, 1.15)
                    if (restartMouse.containsMouse)
                        return Qt.lighter(base, 1.08)
                    return base
                }

                Behavior on color { ColorAnimation { duration: 110 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 14
                    spacing: 10

                    BusyIndicator {
                        visible: backend.busy && backend.busyAction === "restart"
                        running: visible
                        implicitWidth: visible ? 18 : 0
                        implicitHeight: 18
                        Material.accent: theme.accentForeground
                    }

                    Label {
                        Layout.fillWidth: true
                        text: backend.busy && backend.busyAction === "restart"
                            ? (win.quitAfterRestart ? qsTr("Restarting — closing when ready...") : qsTr("Restarting Dynamic Island..."))
                            : qsTr("Restart Dynamic Island")
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        color: theme.accentForeground
                        elide: Text.ElideRight
                    }

                    KeyBadge {
                        keyText: "Space"
                        onAccent: true
                        visible: !backend.busy
                    }
                }

                MouseArea {
                    id: restartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !backend.busy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: backend.restartShell()
                }
            }

            // Secondary 2x2 Action Grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                columnSpacing: 10
                rowSpacing: 10

                ActionTile {
                    titleText: qsTr("Revive Surface")
                    subtitleText: qsTr("Rebuild Wayland layers")
                    keyHint: "V"
                    onTriggered: backend.reviveSurface()
                }

                ActionTile {
                    titleText: qsTr("Toggle Expand")
                    subtitleText: backend.islandMode === "expanded" ? qsTr("Collapse pill") : qsTr("Open card view")
                    keyHint: "T"
                    onTriggered: backend.toggleExpand()
                }

                ActionTile {
                    titleText: qsTr("Focus Mode")
                    subtitleText: backend.focusMode ? qsTr("Allow hover open") : qsTr("Click-only notch")
                    keyHint: "F"
                    activeHighlight: backend.focusMode
                    onTriggered: backend.toggleFocusMode()
                }

                ActionTile {
                    titleText: qsTr("Reset State")
                    subtitleText: qsTr("Clear stuck alerts")
                    keyHint: "Z"
                    onTriggered: backend.resetState()
                }
            }

            // Footer status & quick shortcut summary
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Label {
                    Layout.fillWidth: true
                    text: backend.statusText
                    font.pixelSize: 11
                    color: win.mutedTextColor
                    elide: Text.ElideRight
                }

                Label {
                    text: qsTr("? Help · S Refresh · Q Quit")
                    font.pixelSize: 11
                    color: win.mutedTextColor
                }
            }
        }

        // Keyboard Shortcuts Help Overlay (?)
        Rectangle {
            anchors.fill: parent
            visible: win.helpVisible
            color: Qt.rgba(0, 0, 0, 0.72)

            MouseArea {
                anchors.fill: parent
                onClicked: win.helpVisible = false
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 44, 380)
                implicitHeight: helpCol.implicitHeight + 32
                radius: theme.radius
                color: Qt.tint(theme.background, Qt.rgba(1, 1, 1, 0.08))
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)

                MouseArea {
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: helpCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("Keyboard Shortcuts")
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: theme.foreground
                        }
                        KeyBadge { keyText: "Esc" }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 8

                        KeyBadge { keyText: "Space / Enter / R" }
                        Label { text: qsTr("Restart Dynamic Island"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "V" }
                        Label { text: qsTr("Revive layer surface"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "T" }
                        Label { text: qsTr("Toggle expand / collapse"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "F" }
                        Label { text: qsTr("Toggle Focus Mode"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "Z" }
                        Label { text: qsTr("Reset island state"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "S" }
                        Label { text: qsTr("Refresh status now"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "?" }
                        Label { text: qsTr("Show or hide this overlay"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }

                        KeyBadge { keyText: "Q / Esc" }
                        Label { text: qsTr("Quit window"); font.pixelSize: 12; color: theme.foreground; Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
