import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component {
    id: hsIcon
    Image {
      source: Quickshell.env("HOME") + "/.config/omarchy/assets/hs_logo.png"
      fillMode: Image.PreserveAspectFit
      mipmap: true
      smooth: true
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: hsIcon
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
