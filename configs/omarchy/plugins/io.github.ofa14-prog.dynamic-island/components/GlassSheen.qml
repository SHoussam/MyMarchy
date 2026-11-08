import QtQuick

// Liquid Glass body for a surface (button, tile, card, row, popup): its
// fill, a soft highlight across the top and a hairline edge light that is
// brightest on top and fades smoothly down the sides. Drawn only with the Liquid Glass theme, behind
// the surface's content.
//
// Hover does not add a highlight layer: the glass body swells a few pixels
// like a water balloon (a soft overshoot), and shrinks a touch when pressed.
// Only this body moves; the surface's text and icons stay put and sharp,
// and nothing around it shifts.
//
// takeFill: the body draws the surface's fill itself (the surface's own
// color is cleared while glass is on), so the fill swells with it and hover
// adds no extra layer. Set on hoverable surfaces, with `fill` the resting
// (or selected) color.
Item {
  id: sheen

  property real radius: parent ? parent.radius || 0 : 0
  property real strength: 1          // 0..1, e.g. lower for small rows
  property bool lit: false           // hovered: swell
  property bool pressed: false       // pressed: give a little
  property bool takeFill: false
  property color fill: Theme.fill
  readonly property real k: strength

  readonly property real target: Theme.reduceMotion ? 0 : pressed ? -1.2 : lit ? 2.6 : 0
  property real inflate: target
  Behavior on inflate {
    enabled: !Theme.reduceMotion
    SpringAnimation { spring: 5.5; damping: 0.26; epsilon: 0.02 }
  }

  visible: Theme.glass
  z: -1
  anchors.fill: parent
  anchors.margins: -inflate

  // The surface's own fill steps aside so the swelling body carries it.
  Binding {
    target: sheen.parent
    property: "color"
    value: "transparent"
    when: sheen.visible && sheen.takeFill
  }

  readonly property real r: Math.max(0, sheen.radius + inflate)

  // Fill.
  Rectangle {
    anchors.fill: parent
    radius: sheen.r
    visible: sheen.takeFill
    color: sheen.fill
  }
  // Highlight across the top: a soft wash that thins out by the middle.
  Rectangle {
    anchors.fill: parent
    radius: sheen.r
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, (Theme.light ? 0.26 : 0.06) * sheen.k) }
      GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, (Theme.light ? 0.06 : 0.01) * sheen.k) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, (Theme.light ? 0.02 : 0.04) * sheen.k) }
    }
  }
  // Edge light: one hairline ring, brightest along the top and easing out
  // down the sides (shaders/rim.frag), so it never ends in a hard step.
  ShaderEffect {
    anchors.fill: parent
    readonly property size size: Qt.size(width, height)
    readonly property real radius: sheen.r
    readonly property color light: Qt.rgba(1, 1, 1, (Theme.light ? 0.5 : 0.17) * sheen.k)
    readonly property color edge: Theme.light ? Qt.rgba(0, 0, 0, 0.06 * sheen.k) : Qt.rgba(1, 1, 1, 0.05 * sheen.k)
    readonly property real reach: 0.7
    fragmentShader: Qt.resolvedUrl("../shaders/rim.frag.qsb")
  }
}
