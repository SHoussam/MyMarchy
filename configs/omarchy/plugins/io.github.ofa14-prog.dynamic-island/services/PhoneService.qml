import QtQuick
import Quickshell
import Quickshell.Io

// Live KDE Connect bridge: tracks paired phones, battery levels, SFTP status,
// and emits connection / disconnection / incoming-call events cleanly via D-Bus.
Item {
  id: phones

  property bool active: true
  property bool daemonAvailable: false
  property var devices: []
  property string lastEventMessage: ""
  property double lastEventAt: 0

  signal deviceConnected(var device)
  signal deviceDisconnected(var device, int remainingConnected)
  signal incomingCall(var call)

  readonly property var connectedDevices: devices.filter(d => d.reachable === true)
  readonly property int connectedCount: connectedDevices.length
  readonly property int pairedCount: devices.length
  readonly property bool connected: connectedCount > 0
  readonly property var primaryDevice: connectedDevices.length > 0 ? connectedDevices[0] : (devices.length > 0 ? devices[0] : null)

  property bool _seeded: false
  property var _prevById: ({})

  readonly property string binPath: {
    var u = String(Qt.resolvedUrl("../bin/dynamic-island-phones"))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
  }

  function handleMessage(d) {
    if (!d) return
    if (d.type === "call") {
      if (d.event === "ringing" || d.event === "missedCall") {
        phones.lastEventAt = Date.now()
        phones.incomingCall(d)
      }
      return
    }
    if (d.type !== "state") return

    var nextDaemon = !!d.daemonAvailable
    var list = Array.isArray(d.devices) ? d.devices : []
    var nextById = {}
    var connectedNow = 0
    for (var i = 0; i < list.length; i++) {
      var dev = list[i]
      if (!dev || !dev.id) continue
      nextById[dev.id] = dev
      if (dev.reachable) connectedNow++
    }

    var newlyConnected = []
    var newlyDisconnected = []
    if (phones._seeded) {
      for (var id in nextById) {
        var cur = nextById[id]
        var prev = phones._prevById[id]
        if (cur.reachable && (!prev || !prev.reachable)) newlyConnected.push(cur)
        else if (!cur.reachable && prev && prev.reachable) newlyDisconnected.push(cur)
      }
      for (var oldId in phones._prevById) {
        var oldDev = phones._prevById[oldId]
        if (oldDev && oldDev.reachable && !nextById[oldId]) newlyDisconnected.push(oldDev)
      }
    }

    phones.daemonAvailable = nextDaemon
    phones.devices = list
    phones._prevById = nextById
    if (nextDaemon) phones._seeded = true

    for (var c = 0; c < newlyConnected.length; c++) {
      phones.lastEventMessage = newlyConnected[c].name
      phones.lastEventAt = Date.now()
      phones.deviceConnected(newlyConnected[c])
    }
    for (var x = 0; x < newlyDisconnected.length; x++) {
      phones.lastEventMessage = newlyDisconnected[x].name
      phones.lastEventAt = Date.now()
      phones.deviceDisconnected(newlyDisconnected[x], connectedNow)
    }
  }

  Process {
    id: proc
    running: phones.active
    command: [phones.binPath]
    stdout: SplitParser {
      onRead: line => {
        try {
          var d = JSON.parse(line)
          phones.handleMessage(d)
        } catch (e) {}
      }
    }
  }
}
