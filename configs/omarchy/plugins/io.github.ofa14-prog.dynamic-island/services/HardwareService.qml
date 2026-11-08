import QtQuick
import Quickshell
import Quickshell.Io

// Hardware statistics service: live CPU, RAM, Disk, and GPU stats.
// Runs bin/dynamic-island-hardware only while active (when expanded on Home).
Item {
  id: hw

  property bool active: false

  property real cpuUsage: 0.0     // 0.0 .. 1.0
  property int cpuTemp: 0
  property string cpuModel: "CPU"

  property real memUsage: 0.0     // 0.0 .. 1.0
  property real memUsed: 0.0      // GB
  property real memTotal: 0.0     // GB

  property real diskUsage: 0.0    // 0.0 .. 1.0
  property real diskUsed: 0.0     // GB
  property real diskTotal: 0.0    // GB

  property bool hasGpu: false
  property string gpuName: "GPU"
  property real gpuUsage: 0.0     // 0.0 .. 1.0
  property int gpuTemp: 0
  property real gpuMemUsed: 0.0   // GB
  property real gpuMemTotal: 0.0  // GB

  readonly property string binPath: {
    var u = String(Qt.resolvedUrl("../bin/dynamic-island-hardware"))
    return u.indexOf("file://") === 0 ? decodeURIComponent(u.substring(7)) : u
  }

  Process {
    id: proc
    running: hw.active
    command: [hw.binPath]
    stdout: SplitParser {
      onRead: line => {
        try {
          var d = JSON.parse(line)
          if (!d) return
          if (d.cpu_pct !== undefined) hw.cpuUsage = Math.max(0, Math.min(1, d.cpu_pct / 100.0))
          if (d.cpu_temp !== undefined) hw.cpuTemp = d.cpu_temp
          if (d.cpu_model) hw.cpuModel = d.cpu_model
          if (d.mem_pct !== undefined) hw.memUsage = Math.max(0, Math.min(1, d.mem_pct / 100.0))
          if (d.mem_used !== undefined) hw.memUsed = d.mem_used
          if (d.mem_total !== undefined) hw.memTotal = d.mem_total
          if (d.disk_pct !== undefined) hw.diskUsage = Math.max(0, Math.min(1, d.disk_pct / 100.0))
          if (d.disk_used !== undefined) hw.diskUsed = d.disk_used
          if (d.disk_total !== undefined) hw.diskTotal = d.disk_total
          if (d.has_gpu !== undefined) hw.hasGpu = d.has_gpu
          if (d.gpu_name) hw.gpuName = d.gpu_name
          if (d.gpu_util !== undefined) hw.gpuUsage = Math.max(0, Math.min(1, d.gpu_util / 100.0))
          if (d.gpu_temp !== undefined) hw.gpuTemp = d.gpu_temp
          if (d.gpu_mem_used !== undefined) hw.gpuMemUsed = d.gpu_mem_used
          if (d.gpu_mem_total !== undefined) hw.gpuMemTotal = d.gpu_mem_total
        } catch (e) {}
      }
    }
  }
}
