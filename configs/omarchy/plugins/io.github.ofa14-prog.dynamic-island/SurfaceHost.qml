import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "components"
import "pages"

// Hosted dynamically via Loader in Island.qml so both Wayland layer surfaces
// (dynamic-island and dynamic-island-glow) can be torn down cleanly and recreated
// against a settled real QScreen across suspend/wake, DPMS, or monitor changes.
Item {
  id: surfaceRoot

  required property var host
  property bool tearingDown: false

  readonly property bool hovered: hover.hovered
  readonly property real hoverX: hover.point.position.x
  readonly property real stageWidth: stage.width
  readonly property int pageH: pageStack.currentHeight

  function focusInput() { focusScope.forceActiveFocus() }

  Component.onDestruction: tearingDown = true

  Timer {
    id: backingCheckTimer
    interval: 600
    onTriggered: {
      if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady && window.visible && !window.backingWindowVisible)
        surfaceRoot.host.recoverSurface()
    }
  }

  // ================================================================ glow

  // HyprGlass turns every visible pixel of the island's layer into glass,
  // so the music's ambient glow lives on a layer of its own while it is on:
  // same size and place, one layer level down (Top, under the island's
  // Overlay) so it always stays beneath it, no input, and not glassed.
  // Without HyprGlass the glow stays in the island.
  PanelWindow {
    id: glowWindow
    screen: surfaceRoot.host.targetScreen
    visible: !surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady && !!surfaceRoot.host.targetScreen
    anchors { top: true }
    implicitWidth: window.implicitWidth
    implicitHeight: window.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dynamic-island-glow"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    onClosed: if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady) surfaceRoot.host.recoverSurface()
    onResourcesLost: if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady) surfaceRoot.host.recoverSurface()

    // The island's glow, following the stage (place, scale, fade).
    Item {
      visible: surfaceRoot.host.hyprGlassOn && ambient.visible
      x: stage.x
      y: stage.y
      width: stage.width
      height: stage.height
      scale: stage.scale
      transformOrigin: Item.Top
      opacity: stage.opacity * ambient.opacity

      RectangularShadow {
        x: 0
        width: Math.round(parent.width * 0.7)
        height: parent.height
        radius: shape.radius
        blur: 24 + ambient.level * 10
        spread: -2 + ambient.level * 3
        color: Qt.rgba(ambient.leftColor.r, ambient.leftColor.g, ambient.leftColor.b, ambient.strength)
      }
      RectangularShadow {
        x: Math.round(parent.width * 0.3)
        width: parent.width - x
        height: parent.height
        radius: shape.radius
        blur: 24 + ambient.level * 10
        spread: -2 + ambient.level * 3
        color: Qt.rgba(ambient.rightColor.r, ambient.rightColor.g, ambient.rightColor.b, ambient.strength)
      }
    }

    // A music bubble's glow, following the bubble.
    Repeater {
      model: [rightBubble, leftBubble]
      delegate: RectangularShadow {
        required property var modelData
        readonly property var b: modelData
        readonly property real level: surfaceRoot.host.audio.available && surfaceRoot.host.audio.active ? surfaceRoot.host.audio.level : 0.45
        readonly property bool on: surfaceRoot.host.hyprGlassOn && surfaceRoot.host.ambientOn && b.kind === "music" && b.shown
        x: b.x
        y: b.y
        width: b.width
        height: b.height
        radius: width / 2
        scale: b.bodyScale
        blur: 14 + level * 6
        spread: -2 + level * 2
        color: Qt.rgba(ambient.leftColor.r, ambient.leftColor.g, ambient.leftColor.b, 0.28 + level * 0.3)
        opacity: on ? b.opacity : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.ms(900); easing.type: Easing.InOutQuad } }
      }
    }
  }

  // ================================================================ window

  PanelWindow {
    id: window

    screen: surfaceRoot.host.targetScreen
    visible: !surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady && !!surfaceRoot.host.targetScreen
    onWindowConnected: {
      if (surfaceRoot.tearingDown) return
      backingCheckTimer.stop()
      surfaceRoot.host.onSurfaceWindowConnected()
    }
    onBackingWindowVisibleChanged: {
      if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady && visible && !backingWindowVisible) backingCheckTimer.restart()
      else backingCheckTimer.stop()
    }
    onClosed: if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady) surfaceRoot.host.recoverSurface()
    onResourcesLost: if (!surfaceRoot.tearingDown && surfaceRoot.host.surfaceReady) surfaceRoot.host.recoverSurface()
    // Centred at the top (no left/right anchor). Tall enough for the biggest
    // page (the agent page with its feed expanded) while open; the surface is
    // transparent and clicks pass through.
    anchors { top: true }
    implicitWidth: Math.min(screen ? screen.width : surfaceRoot.host.surfaceW, surfaceRoot.host.surfaceW)
    implicitHeight: surfaceRoot.host.surfaceH
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "dynamic-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: surfaceRoot.host.mode === "expanded" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the island (and its bubble) take input; everything else on this
    // surface clicks straight through to the bar and windows.
    mask: Region {
      item: surfaceRoot.host.fullscreenHidden ? null : maskItem
      Region { item: surfaceRoot.host.fullscreenHidden || !rightBubble.shown ? null : rightHit }
      Region { item: surfaceRoot.host.fullscreenHidden || !leftBubble.shown ? null : leftHit }
    }

    FocusScope {
      id: focusScope
      anchors.fill: parent
      focus: true

      Keys.onPressed: event => {
        var h = surfaceRoot.host
        if (event.key === Qt.Key_Escape) {
          if (h.page === "permission" && h.agents.currentRequest) h.agents.respond("", "deny")
          else if (h.page === "timer" && h.timer.ringing) h.timer.dismissRing()
          else h.collapse()
          event.accepted = true
        } else if (h.page === "permission" && h.agents.currentRequest) {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Y) {
            h.agents.respond("", "allow"); event.accepted = true
          } else if (event.key === Qt.Key_A && h.agents.currentRequest.canAlways) {
            h.agents.respond("", "always"); event.accepted = true
          } else if (event.key === Qt.Key_N) {
            h.agents.respond("", "deny"); event.accepted = true
          } else if (event.key === Qt.Key_T) {
            h.agents.focusTerminal(h.agents.sessions[h.agents.currentRequest.session]); event.accepted = true
          }
        } else if (h.mode === "expanded" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Tab) {
          h.cyclePage(1); event.accepted = true
        } else if (h.mode === "expanded" && event.key === Qt.Key_BracketRight) {
          h.cyclePage(1); event.accepted = true
        } else if (h.mode === "expanded" && event.key === Qt.Key_BracketLeft) {
          h.cyclePage(-1); event.accepted = true
        } else if (h.page === "shelf" && h.mode === "expanded" && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
          // Ctrl+V on the open shelf: what you copied goes on it.
          h.shelf.addFromClipboard(); event.accepted = true
        } else if (h.page === "music" && event.key === Qt.Key_Space && h.mode === "expanded") {
          h.music.togglePlaying(); event.accepted = true
        }
      }

      // ------------------------------------------------------------ shape

      Item {
        id: stage
        width: shape.width
        height: shape.height
        x: Math.round((parent.width - width) / 2 + surfaceRoot.host.shakeX + leanX)
        y: Math.min(0, Math.round(surfaceRoot.host.introY))
        opacity: surfaceRoot.host.fullscreenHidden || surfaceRoot.host.intro === "hidden" ? 0 : 1
        scale: (surfaceRoot.host.fullscreenHidden ? 0.6 : 1) * pressScale
        transformOrigin: Item.Top

        property real leanX: 0
        property real pressScale: 1

        Behavior on opacity { NumberAnimation { duration: Theme.ms(220) } }
        Behavior on scale {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: Theme.snapSpring; damping: Theme.snapDamping; epsilon: 0.002 }
        }
        Behavior on leanX {
          enabled: !Theme.reduceMotion
          SpringAnimation { spring: 3; damping: 0.4; epsilon: 0.05 }
        }

        // The glass's light leans toward the pointer while it is over the
        // island (from the top-left otherwise).
        Binding {
          target: surfaceRoot.host
          property: "lightX"
          value: hover.hovered ? (hover.point.position.x - stage.width / 2) / Math.max(1, stage.width / 2) * 0.9 - 0.2 : -0.55
        }
        Binding {
          target: surfaceRoot.host
          property: "lightY"
          value: hover.hovered ? (hover.point.position.y - stage.height / 2) / Math.max(1, stage.height / 2) * 0.7 - 0.6 : -0.83
        }

        // The glass reaches for the pointer (compact, glass on).
        Binding {
          target: surfaceRoot.host
          property: "pullAmp"
          // Off: hovering the closed island only grows it a little.
          value: 0
        }
        Binding {
          target: surfaceRoot.host
          property: "pullX"
          when: hover.hovered
          value: hover.point.position.x / Math.max(0.01, stage.scale)
        }
        Binding {
          target: surfaceRoot.host
          property: "pullY"
          when: hover.hovered
          value: hover.point.position.y / Math.max(0.01, stage.scale)
        }

        // The pointer gently pulls the compact island toward itself.
        Binding {
          target: stage
          property: "leanX"
          // Measured against where the island rests (position + leanX), not
          // where it has leaned to, or each lean moves the pointer's
          // relative position and leans it again: that was the jitter.
          // Under glass the glass itself reaches for the pointer instead.
          value: surfaceRoot.host.mode === "compact" && hover.hovered && !surfaceRoot.host.halvesOn && !surfaceRoot.host.glassOn
            ? Math.max(-1, Math.min(1, (hover.point.position.x + stage.leanX - stage.width / 2) / (stage.width / 2))) * 3.5
            : 0
        }

        // Ambient light, like YouTube's ambient mode: the artwork's colors
        // glow softly out of the island's edges while music plays (left and
        // right take the two most vivid colors) and breathe with the sound
        // when cava is installed. Kept small: a halo, not a lamp.
        Item {
          id: ambient
          anchors.fill: shape
          // Only around the player: the island glows when music is the
          // activity in the middle (or the open music page); when music sits
          // in a bubble, that bubble glows instead (pages/Bubble.qml).
          readonly property bool here: surfaceRoot.host.mode === "expanded" ? surfaceRoot.host.page === "music"
            : surfaceRoot.host.mode === "compact" && surfaceRoot.host.primary === "music"
          // Open on the music page, the light moves inside the card instead
          // (musicBackdrop below), so the outer glow steps aside.
          opacity: surfaceRoot.host.ambientOn && here && surfaceRoot.host.mode !== "expanded" ? 1 : 0
          visible: opacity > 0.01
          Behavior on opacity { NumberAnimation { duration: Theme.ms(900); easing.type: Easing.InOutQuad } }

          // A backlight: wide and faint, starting just inside the edge so it
          // seems to come from behind the island, and swelling softly with
          // the sound (no flashes).
          readonly property bool moving: surfaceRoot.host.audio.available && surfaceRoot.host.audio.active
          readonly property real level: moving ? surfaceRoot.host.audio.level : 0.45
          readonly property real strength: 0.26 + level * 0.3
          property color leftColor: surfaceRoot.host.music.ambient[0]
          property color rightColor: surfaceRoot.host.music.ambient[1]
          Behavior on leftColor { ColorAnimation { duration: 1500 } }
          Behavior on rightColor { ColorAnimation { duration: 1500 } }

          // With HyprGlass these are drawn on the glow layer instead (see
          // glowWindow), where HyprGlass cannot turn them into glass.
          RectangularShadow {
            visible: !surfaceRoot.host.hyprGlassOn
            x: 0
            width: Math.round(parent.width * 0.7)
            height: parent.height
            radius: shape.radius
            blur: 24 + ambient.level * 10
            spread: -2 + ambient.level * 3
            color: Qt.rgba(ambient.leftColor.r, ambient.leftColor.g, ambient.leftColor.b, ambient.strength)
          }
          RectangularShadow {
            visible: !surfaceRoot.host.hyprGlassOn
            x: Math.round(parent.width * 0.3)
            width: parent.width - x
            height: parent.height
            radius: shape.radius
            blur: 24 + ambient.level * 10
            spread: -2 + ambient.level * 3
            color: Qt.rgba(ambient.rightColor.r, ambient.rightColor.g, ambient.rightColor.b, ambient.strength)
          }
        }

        // Soft drop shadow, only once the island leaves the bar.
        RectangularShadow {
          anchors.fill: shape
          radius: shape.radius
          blur: 28
          spread: 0
          offset.y: 8
          // Under glass a dark shadow would show through: kept light, and
          // below the blur threshold so it is never frosted.
          color: Qt.rgba(0, 0, 0, surfaceRoot.host.hyprGlassOn ? 0 : Theme.light ? (surfaceRoot.host.glassOn ? 0.14 : 0.22) : (surfaceRoot.host.glassOn ? 0.28 : 0.55))
          opacity: surfaceRoot.host.mode === "compact" ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: Theme.ms(260) } }
        }

        // ---- Liquid Glass surface (the glass bodies of the island, its
        // halves and the bubbles, in one liquid field). Spans the bubbles'
        // reach on both sides; coordinates are the stage's own.
        LiquidGlass {
          id: liquid
          visible: surfaceRoot.host.glassOn && opacity > 0.01
          opacity: surfaceRoot.host.idleHidden ? 0 : 1
          Behavior on opacity { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }
          readonly property real s: Math.max(0.01, stage.scale)
          x: -padX
          y: -12
          width: shape.width + padX * 2
          height: shape.height + 80
          readonly property real padX: Math.max(80, surfaceRoot.host.compactH * 2 + 40)
          // Jelly: the glass stretches and settles on its own while the
          // content stays put. Top edge is tucked 36px above screen y=0 so no top rim/halo shows.
          readonly property real jw: shape.width * surfaceRoot.host.jelly
          readonly property real jh: -shape.height * surfaceRoot.host.jelly * 0.55
          function box(x, y, w, h) { return Qt.vector4d(x + padX - jw / 2, y - 24, w + jw, h + jh + 36) }
          rectA: surfaceRoot.host.halvesOn ? box(0, 0, (shape.width - surfaceRoot.host.splitGap) / 2, shape.height)
                                           : box(0, 0, shape.width, shape.height)
          radA: {
            var r = shape.radius, h = shape.height / 2, inner = Math.min(h, surfaceRoot.host.splitGap * 2.2)
            return surfaceRoot.host.halvesOn ? Qt.vector4d(inner, 0, h, 0) : Qt.vector4d(r, 0, r, 0)
          }
          rectB: surfaceRoot.host.halvesOn ? box(shape.width - (shape.width - surfaceRoot.host.splitGap) / 2, 0, (shape.width - surfaceRoot.host.splitGap) / 2, shape.height)
                                           : Qt.vector4d(0, 0, 0, 0)
          radB: {
            var h = shape.height / 2, inner = Math.min(h, surfaceRoot.host.splitGap * 2.2)
            return Qt.vector4d(h, 0, inner, 0)
          }
          function bubbleAt(b) {
            void b.x; void b.y; void b.bodyScale; void b.opacity; void stage.x; void stage.y; void stage.scale
            if (!b.visible || b.opacity < 0.02) return Qt.vector4d(0, 0, 0, 0)
            var c = stage.mapFromItem(b, b.width / 2, b.height / 2)
            var r = b.width / 2 * b.bodyScale * Math.min(1, b.opacity * 1.6) / s
            return Qt.vector4d(c.x + padX, c.y + 12, r, 0)
          }
          bub0: bubbleAt(rightBubble)
          bub1: bubbleAt(leftBubble)
          blend: surfaceRoot.host.mode === "compact" ? 11 : 4
          // Dark glass is smoky; light glass is clear, a thin milky tint.
          // With HyprGlass the compositor draws the glass: only a trace of
          // the surface is left, enough for HyprGlass to find its shape.
          tint: surfaceRoot.host.hyprGlassOn ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.04)
            : Theme.light
            // Clear while compact; milkier when open, so dark text stays
            // readable even over a dark window behind (no adaptive vibrancy here).
            ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Math.max(0.08, Math.min(0.95,
                (Number(surfaceRoot.host.cfg("glassOpacityLight")) || 0.26) + (surfaceRoot.host.mode === "compact" ? 0.10 : 0.48))))
            : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Math.max(0.36, Math.min(0.95, Number(surfaceRoot.host.cfg("glassOpacity")) || 0.56)))
          dark: Theme.light && !surfaceRoot.host.hyprGlassOn
          rim: surfaceRoot.host.hyprGlassOn ? 0 : 1
          light: surfaceRoot.host.glassLight
          energy: surfaceRoot.host.glassEnergy
          ambL: ambient.leftColor
          ambR: ambient.rightColor
          ambMix: ambient.opacity * (0.55 + ambient.level * 0.45)
          pull: Qt.vector4d(surfaceRoot.host.pullX + padX, surfaceRoot.host.pullY + 12, surfaceRoot.host.pullAmp, 22)
        }

        // Drawn directly (no offscreen texture) so text and icons inside stay
        // pixel-sharp at fractional scales. `clip` is a scissor rectangle:
        // content keeps clear of the rounded corners.
        Rectangle {
          id: shape
          clip: true
          width: surfaceRoot.host.targetW
          height: Math.max(6, surfaceRoot.host.targetH + surfaceRoot.host.bounceY)
          radius: surfaceRoot.host.targetR
          topLeftRadius: 0
          topRightRadius: 0
          bottomLeftRadius: surfaceRoot.host.targetR
          bottomRightRadius: surfaceRoot.host.targetR
          color: surfaceRoot.host.idleHidden || surfaceRoot.host.halvesOn || surfaceRoot.host.glassOn ? "transparent" : Theme.bg
          border.width: 0
          antialiasing: true

          // Theme-synced side & bottom border (top edge tucked at y=-1 so y=0 stays flush with screen top)
          Rectangle {
            anchors.fill: parent
            anchors.topMargin: -1
            color: "transparent"
            radius: shape.radius
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: shape.bottomLeftRadius
            bottomRightRadius: shape.bottomRightRadius
            border.width: surfaceRoot.host.idleHidden || surfaceRoot.host.halvesOn ? 0 : 1
            border.color: Theme.edge
            z: 99
          }

          Behavior on width {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: surfaceRoot.host.springK; damping: surfaceRoot.host.springD; mass: Theme.mass; epsilon: 0.25 }
          }
          Behavior on height {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: surfaceRoot.host.springK; damping: Math.min(0.9, surfaceRoot.host.springD + 0.03); mass: Theme.mass; epsilon: 0.25 }
          }
          Behavior on radius {
            enabled: !Theme.reduceMotion
            SpringAnimation { spring: Theme.closeSpring; damping: 0.5; epsilon: 0.1 }
          }

          // Music page backdrop, like Apple Music: the artwork's colors fill
          // the open card as large, heavily blurred blobs that drift slowly.
          // Masked to the card's rounded shape; only this layer is rendered
          // offscreen, the text above stays sharp.
          Item {
            id: musicBackdrop
            anchors.fill: parent
            // Opening onto the music page, the colors come in with the card
            // as it grows (no black first). Between tabs they cross-fade
            // quickly. Closing, they vanish at once, so nothing is drawn
            // while the card shrinks into the compact island.
            readonly property bool expanded: surfaceRoot.host.mode === "expanded"
            readonly property bool on: surfaceRoot.host.cfg("ambient") && expanded
              && surfaceRoot.host.page === "music" && surfaceRoot.host.music.available
            readonly property bool moving: on && !Theme.reduceMotion
            // Over HyprGlass a lighter wash, so the colors tint the glass
            // and the refraction still shows through.
            opacity: on ? (surfaceRoot.host.hyprGlassOn ? 0.6 : 1) : 0
            visible: opacity > 0.005
            Behavior on opacity {
              enabled: musicBackdrop.expanded
              NumberAnimation { duration: Theme.ms(280); easing.type: Easing.OutCubic }
            }

            // Dark: deepened so white text reads; light: washed out so dark
            // text does.
            property color c1: Theme.light ? Qt.tint(surfaceRoot.host.music.ambient[0], Qt.rgba(1, 1, 1, 0.55)) : Qt.darker(surfaceRoot.host.music.ambient[0], 1.5)
            property color c2: Theme.light ? Qt.tint(surfaceRoot.host.music.ambient[1], Qt.rgba(1, 1, 1, 0.55)) : Qt.darker(surfaceRoot.host.music.ambient[1], 1.5)
            Behavior on c1 { ColorAnimation { duration: 1500 } }
            Behavior on c2 { ColorAnimation { duration: 1500 } }

            // Blob positions as fractions of the card, each drifting on its
            // own slow loop so the pattern never visibly repeats.
            property real ax: 0.18
            property real ay: 0.25
            property real bx: 0.82
            property real by: 0.7
            property real cx: 0.5
            property real cy: 0.9
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "ax"; to: 0.08; duration: 9000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "ax"; to: 0.45; duration: 9000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "ay"; to: 0.15; duration: 11000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "ay"; to: 0.75; duration: 11000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "bx"; to: 0.92; duration: 10000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "bx"; to: 0.5; duration: 10000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "by"; to: 0.85; duration: 12500; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "by"; to: 0.2; duration: 12500; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "cx"; to: 0.3; duration: 13000; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "cx"; to: 0.75; duration: 13000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation {
              loops: Animation.Infinite
              running: musicBackdrop.moving
              NumberAnimation { target: musicBackdrop; property: "cy"; to: 0.95; duration: 9500; easing.type: Easing.InOutSine }
              NumberAnimation { target: musicBackdrop; property: "cy"; to: 0.45; duration: 9500; easing.type: Easing.InOutSine }
            }

            Item {
              id: blobs
              anchors.fill: parent
              visible: false
              // Kept ready while the card is open, so a fade-in never starts
              // with an unblurred frame.
              layer.enabled: musicBackdrop.expanded
              // Rendered small and scaled up: blurring a low-resolution
              // texture gives the very soft, edgeless look.
              layer.textureSize: Qt.size(Math.max(8, Math.round(width / 8)), Math.max(8, Math.round(height / 8)))
              layer.smooth: true
              readonly property real d: Math.max(width, height) * 0.95
              Rectangle {
                width: blobs.d; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.ax - width / 2
                y: blobs.height * musicBackdrop.ay - height / 2
                color: musicBackdrop.c1
              }
              Rectangle {
                width: blobs.d * 0.9; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.bx - width / 2
                y: blobs.height * musicBackdrop.by - height / 2
                color: musicBackdrop.c2
              }
              Rectangle {
                width: blobs.d * 0.6; height: width; radius: width / 2
                x: blobs.width * musicBackdrop.cx - width / 2
                y: blobs.height * musicBackdrop.cy - height / 2
                color: Qt.tint(musicBackdrop.c1, Qt.rgba(musicBackdrop.c2.r, musicBackdrop.c2.g, musicBackdrop.c2.b, 0.5))
              }
            }
            Rectangle {
              id: backdropMask
              anchors.fill: parent
              radius: shape.radius
              topLeftRadius: 0
              topRightRadius: 0
              bottomLeftRadius: shape.radius
              bottomRightRadius: shape.radius
              visible: false
              layer.enabled: musicBackdrop.expanded
            }
            MultiEffect {
              anchors.fill: parent
              source: blobs
              blurEnabled: true
              blur: 1
              blurMax: 64
              // No padding: the effect must not draw past the card.
              autoPaddingEnabled: false
              maskEnabled: true
              maskSource: backdropMask
              opacity: 0.7
            }
          }

          // Two agents at work: the pill as two halves with a gap between.
          // At gap 0 they are exactly the whole pill, so the split and the
          // merge are seamless.
          Repeater {
            model: surfaceRoot.host.halvesOn ? [0, 1] : []
            delegate: Rectangle {
              required property int modelData
              readonly property real inner: Math.min(height / 2, surfaceRoot.host.splitGap * 2.2)
              width: (shape.width - surfaceRoot.host.splitGap) / 2
              height: shape.height
              x: modelData === 0 ? 0 : shape.width - width
              readonly property bool lit: surfaceRoot.host.hoveredHalf === modelData
              readonly property color agentTint: surfaceRoot.host.profile(surfaceRoot.host.splitOrder[modelData] || "").color
              color: surfaceRoot.host.glassOn ? "transparent" : Theme.bg
              border.width: lit ? 1.5 : 1
              border.color: lit ? Qt.rgba(agentTint.r, agentTint.g, agentTint.b, 0.6) : surfaceRoot.host.glassOn ? "transparent" : Theme.edge
              Behavior on border.color { ColorAnimation { duration: Theme.ms(160) } }
              topLeftRadius: 0
              bottomLeftRadius: modelData === 0 ? height / 2 : inner
              topRightRadius: 0
              bottomRightRadius: modelData === 1 ? height / 2 : inner
            }
          }

          // Background press target: compact/peek expand on click.
          MouseArea {
            id: shapeMouse
            anchors.fill: parent
            cursorShape: surfaceRoot.host.mode === "expanded" ? Qt.ArrowCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPressed: if (surfaceRoot.host.mode !== "expanded") { stage.pressScale = 0.95; surfaceRoot.host.wobble(-0.03) }
            onReleased: { stage.pressScale = 1; if (surfaceRoot.host.mode !== "expanded") surfaceRoot.host.flash() }
            onCanceled: stage.pressScale = 1
            onClicked: mouseEvent => {
              var h = surfaceRoot.host
              if (h.mode === "expanded") return
              if (mouseEvent.button === Qt.MiddleButton && h.primary === "music") { h.music.togglePlaying(); return }
              if (mouseEvent.button === Qt.RightButton) { h.openPage("home", "pointer"); return }
              var target = h.mode === "peek" && h.peekData.target ? h.peekData.target : h.defaultPage()
              h.openPage(target, "pointer")
            }
            onWheel: wheel => {
              if (surfaceRoot.host.mode === "expanded") { surfaceRoot.host.wheelTabs(wheel); return }
              // Scroll on the compact island nudges the volume, as on macOS notch apps.
              Quickshell.execDetached(["omarchy-audio-output-volume", wheel.angleDelta.y > 0 ? "+5" : "-5"])
            }

            Accessible.role: Accessible.Button
            Accessible.name: "Dynamic Island"
            Accessible.description: surfaceRoot.host.mode === "expanded" ? I18n.t("Açık") : I18n.t("Açmak için tıklayın")
          }

          // Drag files in → the shelf opens under the pointer.
          DropArea {
            anchors.fill: parent
            keys: ["text/uri-list"]
            onEntered: drag => {
              if (!drag.hasUrls) { drag.accepted = false; return }
              surfaceRoot.host.dragHover = true
              if (surfaceRoot.host.page !== "shelf" || surfaceRoot.host.mode !== "expanded") surfaceRoot.host.openPage("shelf", "pointer")
            }
            onExited: surfaceRoot.host.dragHover = false
            onDropped: drop => {
              surfaceRoot.host.dragHover = false
              var n = surfaceRoot.host.shelf.addUrls(drop.urls)
              if (n > 0) {
                drop.acceptProposedAction()
                surfaceRoot.host.bounce()
              }
            }
          }

          // ---------------------------------------------------- compact
          CompactView {
            anchors.fill: parent
            shown: surfaceRoot.host.mode === "compact" && surfaceRoot.host.introDone
            island: surfaceRoot.host
          }

          // ---------------------------------------------------- peek
          PeekView {
            anchors.fill: parent
            shown: surfaceRoot.host.mode === "peek"
            island: surfaceRoot.host
          }

          // ---------------------------------------------------- expanded
          TabStrip {
            id: tabs
            anchors.top: parent.top
            anchors.topMargin: 8
            x: Math.round((parent.width - width) / 2)
            width: surfaceRoot.host.expandedW - 28
            shown: surfaceRoot.host.mode === "expanded" && surfaceRoot.host.page !== "permission"
            island: surfaceRoot.host
          }

          Item {
            id: pageStack
            anchors.top: parent.top
            anchors.topMargin: surfaceRoot.host.expandedChromeH + 4
            x: Math.round((parent.width - width) / 2)
            width: surfaceRoot.host.expandedW - 40
            height: currentHeight

            readonly property bool open: surfaceRoot.host.mode === "expanded"
            readonly property int currentHeight: {
              switch (surfaceRoot.host.page) {
                case "music": return musicPage.implicitHeight
                case "agent": return agentPage.implicitHeight
                case "permission": return permissionPage.implicitHeight
                case "timer": return timerPage.implicitHeight
                case "shelf": return shelfPage.implicitHeight
                default: return homePage.implicitHeight
              }
            }

            HomePage       { slide: surfaceRoot.host.pageSlide; id: homePage;       island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "home" }
            MusicPage      { slide: surfaceRoot.host.pageSlide; id: musicPage;      island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "music" }
            AgentPage      { slide: surfaceRoot.host.pageSlide; id: agentPage;      island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "agent" }
            PermissionPage { slide: surfaceRoot.host.pageSlide; id: permissionPage; island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "permission" }
            TimerPage      { slide: surfaceRoot.host.pageSlide; id: timerPage;      island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "timer" }
            ShelfPage      { slide: surfaceRoot.host.pageSlide; id: shelfPage;      island: surfaceRoot.host; width: parent.width; shown: pageStack.open && surfaceRoot.host.page === "shelf" }
          }

          // Hover is tracked strictly on the island shape itself.
          HoverHandler {
            id: hover
          }
        }
      }

      // Input mask follows the exact shape size.
      Item {
        id: maskItem
        x: stage.x
        y: stage.y
        width: shape.width
        height: shape.height
      }

      // ------------------------------------------------------------ bubbles
      // Extra live activities split off as small circles, like iOS: the
      // second to the right, a third to the left. Each works on its own.
      Bubble {
        id: rightBubble
        island: surfaceRoot.host
        anchor: stage
        side: 1
        activity: surfaceRoot.host.secondary
      }
      Bubble {
        id: leftBubble
        island: surfaceRoot.host
        anchor: stage
        side: -1
        activity: surfaceRoot.host.tertiary
      }
      Item { id: rightHit; x: rightBubble.x; y: rightBubble.y; width: rightBubble.width; height: rightBubble.height }
      Item { id: leftHit; x: leftBubble.x; y: leftBubble.y; width: leftBubble.width; height: leftBubble.height }
    }
  }
}
