import QtQml
import QtQuick
import Quickshell.Io

Item {
  id: root

  property var shell: null

  readonly property int interval: 2
  property string diskMount: "/"
  property bool publicIpEnabled: false
  property bool gpuEnabled: false
  readonly property int historySize: 60

  property int cpu: 0
  property int cpuUser: 0
  property int cpuSystem: 0
  property int ram: 0
  property int disk: 0
  property real rx: 0
  property real tx: 0
  property real diskRead: 0
  property real diskWrite: 0
  property var cores: []
  property real cpuTemp: -1
  property real diskTemp: -1
  property var sensors: []
  property var diskTemps: ({})
  property var diskRates: ({})
  property var diskHistories: ({})
  property var diskTotals: ({})

  property int gpu: 0
  property real gpuVramUsed: 0
  property real gpuVramTotal: 0
  property real gpuTemp: -1
  property real gpuPower: -1
  property real gpuPowerLimit: -1
  property int gpuFan: -1

  property var cpuHistory: []
  property var ramHistory: []
  property var rxHistory: []
  property var txHistory: []
  property var readHistory: []
  property var writeHistory: []
  property var gpuHistory: []
  property var sensorHistories: ({})

  property string publicIp: ""

  property string diskDevice: ""
  property var prev: null
  property var sensorInfo: null
  readonly property var gpuInfo: sensorInfo && sensorInfo.gpu ? sensorInfo.gpu : ({ kind: "" })
  readonly property string gpuKind: gpuInfo.kind || ""
  readonly property var cpuInfo: sensorInfo && sensorInfo.cpuInfo ? sensorInfo.cpuInfo : ({ model: "", cores: 0, threads: 0 })
  readonly property string gpuName: gpuInfo.name || ""

  function pushed(list, value) {
    var next = list.slice(Math.max(0, list.length - historySize + 1))
    next.push(value)
    return next
  }

  function read(view) {
    view.reload()
    return view.loaded ? view.text() : ""
  }

  function cpuTimes(fields) {
    var f = fields.trim().split(/\s+/).map(Number)
    return {
      user: f[0] + f[1],
      sys: f[2] + f[5] + f[6],
      idle: f[3] + f[4],
      total: f[0] + f[1] + f[2] + f[3] + f[4] + f[5] + f[6] + f[7]
    }
  }

  function cpuSample(text) {
    var m = text.match(/^cpu\s+(.*)$/m)
    if (!m) return null
    var sample = cpuTimes(m[1])
    sample.cores = []
    var core = /^cpu\d+\s+(.*)$/gm
    var c
    while ((c = core.exec(text)) !== null) sample.cores.push(cpuTimes(c[1]))
    return sample
  }

  function busy(now, before) {
    var total = now.total - before.total
    return total > 0 ? Math.round(100 * (total - (now.idle - before.idle)) / total) : 0
  }

  function number(text) {
    var trimmed = String(text).trim()
    var n = Number(trimmed)
    return trimmed !== "" && isFinite(n) ? n : -1
  }

  function celsius(text) {
    var n = number(text)
    return n < 0 ? -1 : n / 1000
  }

  function sensorValue(list, path) {
    if (!path) return -1
    for (var i = 0; i < list.length; i++) if (list[i].path === path) return list[i].value
    return -1
  }

  function readSensors() {
    var list = []
    for (var i = 0; i < sensorViews.count; i++) {
      var view = sensorViews.objectAt(i)
      if (!view) continue
      var value = view.sensorPath === "" ? (gpuKind === "nvidia" ? gpuTemp : -1) : celsius(read(view))
      if (value >= 0) list.push({ id: view.sensorId, name: view.name, short: view.short, value: value, path: view.sensorPath })
    }
    sensors = list
    cpuTemp = sensorValue(list, sensorInfo ? sensorInfo.cpu : "")
    var byDisk = {}
    var diskPaths = sensorInfo && sensorInfo.disks ? sensorInfo.disks : {}
    for (var disk in diskPaths) byDisk[disk] = sensorValue(list, diskPaths[disk])
    diskTemps = byDisk
    diskTemp = diskDevice in byDisk ? byDisk[diskDevice] : -1
    var histories = {}
    for (var j = 0; j < list.length; j++) histories[list[j].id] = pushed(sensorHistories[list[j].id] || [], list[j].value)
    sensorHistories = histories
  }

  function readAmdGpu() {
    gpu = Math.max(0, Math.round(number(read(amdBusy))))
    gpuVramUsed = Math.max(0, number(read(amdVramUsed)))
    gpuVramTotal = Math.max(0, number(read(amdVramTotal)))
    gpuTemp = celsius(read(amdTemp))
    var microwatts = number(read(amdPower))
    gpuPower = microwatts > 0 ? microwatts / 1e6 : -1
    gpuHistory = pushed(gpuHistory, gpu)
  }

  function nvidiaLine(line) {
    var f = String(line).split(",")
    if (f.length < 7) return
    gpu = Math.max(0, Math.round(number(f[0])))
    gpuVramUsed = Math.max(0, number(f[1])) * 1048576
    gpuVramTotal = Math.max(0, number(f[2])) * 1048576
    gpuTemp = number(f[3])
    gpuPower = number(f[4])
    gpuPowerLimit = number(f[5])
    gpuFan = Math.round(number(f[6]))
    gpuHistory = pushed(gpuHistory, gpu)
  }

  function ramPercent(text) {
    var t = text.match(/^MemTotal:\s+(\d+)/m)
    var a = text.match(/^MemAvailable:\s+(\d+)/m)
    if (!t || !a || Number(t[1]) <= 0) return null
    return Math.round(100 * (Number(t[1]) - Number(a[1])) / Number(t[1]))
  }

  function netSample(text) {
    if (text === "") return null
    var rx = 0, tx = 0
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var colon = lines[i].indexOf(":")
      if (colon < 0) continue
      var name = lines[i].slice(0, colon).trim()
      if (/^(lo|docker.*|veth.*|br-.*|virbr.*|tailscale.*)$/.test(name)) continue
      var f = lines[i].slice(colon + 1).trim().split(/\s+/).map(Number)
      rx += f[0]
      tx += f[8]
    }
    return { rx: rx, tx: tx }
  }

  function diskSample(text) {
    var bytes = {}
    var lines = text.split("\n")
    for (var i = 0; i < lines.length; i++) {
      var f = lines[i].trim().split(/\s+/)
      if (f.length > 12)
        bytes[f[2]] = { read: Number(f[5]) * 512, write: Number(f[9]) * 512, readOps: Number(f[3]), writeOps: Number(f[7]), busyMs: Number(f[12]) }
    }
    return bytes
  }

  function rate(now, before) {
    return now !== null && before !== null ? Math.max(0, Math.round((now - before) / interval)) : 0
  }

  function sample() {
    var c = cpuSample(read(statFile))
    var r = ramPercent(read(meminfoFile))
    var n = netSample(read(netFile))
    var disks = diskSample(read(diskstatsFile))
    var d = diskDevice !== "" ? disks[diskDevice] || null : null
    var cur = {
      cpu: c,
      rx: n ? n.rx : null, tx: n ? n.tx : null,
      dr: d ? d.read : null, dw: d ? d.write : null,
      disks: disks
    }
    var p = prev
    prev = cur
    readSensors()
    if (gpuEnabled && gpuKind === "amd") readAmdGpu()
    if (p === null) return

    var dt = c && p.cpu ? c.total - p.cpu.total : 0
    if (dt > 0) {
      cpu = Math.round(100 * (dt - (c.idle - p.cpu.idle)) / dt)
      cpuUser = Math.round(100 * (c.user - p.cpu.user) / dt)
      cpuSystem = Math.round(100 * (c.sys - p.cpu.sys) / dt)
    } else {
      cpu = 0; cpuUser = 0; cpuSystem = 0
    }
    var usage = []
    if (c && p.cpu && c.cores.length === p.cpu.cores.length)
      for (var k = 0; k < c.cores.length; k++) usage.push(busy(c.cores[k], p.cpu.cores[k]))
    cores = usage
    if (r !== null) ram = r
    rx = rate(cur.rx, p.rx)
    tx = rate(cur.tx, p.tx)
    diskRead = rate(cur.dr, p.dr)
    diskWrite = rate(cur.dw, p.dw)
    var rates = {}
    var histories = {}
    var totals = {}
    var blocks = sensorInfo && sensorInfo.blocks ? sensorInfo.blocks : [diskDevice]
    for (var b = 0; b < blocks.length; b++) {
      var name = blocks[b]
      if (!(name in cur.disks) || !p.disks || !(name in p.disks)) continue
      var now = cur.disks[name]
      var before = p.disks[name]
      var r = {
        read: rate(now.read, before.read),
        write: rate(now.write, before.write),
        readOps: rate(now.readOps, before.readOps),
        writeOps: rate(now.writeOps, before.writeOps),
        busy: Math.min(100, Math.max(0, Math.round((now.busyMs - before.busyMs) / (interval * 10))))
      }
      totals[name] = { read: now.read, write: now.write }
      var h = diskHistories[name] || { read: [], write: [] }
      rates[name] = r
      histories[name] = { read: pushed(h.read, r.read), write: pushed(h.write, r.write) }
    }
    diskRates = rates
    diskHistories = histories
    diskTotals = totals

    cpuHistory = pushed(cpuHistory, cpu)
    ramHistory = pushed(ramHistory, ram)
    rxHistory = pushed(rxHistory, rx)
    txHistory = pushed(txHistory, tx)
    readHistory = pushed(readHistory, diskRead)
    writeHistory = pushed(writeHistory, diskWrite)
  }

  FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
  FileView { id: meminfoFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }
  FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true; printErrors: false }
  FileView { id: diskstatsFile; path: "/proc/diskstats"; blockLoading: true; printErrors: false }

  Process {
    id: sensorsProc
    command: [Qt.resolvedUrl("stats-sensors").toString().replace("file://", "")]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.sensorInfo = JSON.parse(String(text)) } catch (e) {}
      }
    }
  }

  Instantiator {
    id: sensorViews
    model: root.sensorInfo ? root.sensorInfo.sensors : []
    delegate: FileView {
      required property var modelData
      readonly property string sensorId: modelData.id
      readonly property string name: modelData.name
      readonly property string short: modelData.short
      readonly property string sensorPath: modelData.path
      path: modelData.path
      blockLoading: true
      printErrors: false
    }
  }

  FileView { id: amdBusy; path: root.gpuInfo.busy || ""; blockLoading: true; printErrors: false }
  FileView { id: amdVramUsed; path: root.gpuInfo.vramUsed || ""; blockLoading: true; printErrors: false }
  FileView { id: amdVramTotal; path: root.gpuInfo.vramTotal || ""; blockLoading: true; printErrors: false }
  FileView { id: amdTemp; path: root.gpuInfo.temp || ""; blockLoading: true; printErrors: false }
  FileView { id: amdPower; path: root.gpuInfo.power || ""; blockLoading: true; printErrors: false }

  // One nvidia-smi streams a line per interval; it runs only while the GPU item is shown.
  Process {
    id: nvidiaProc
    command: ["nvidia-smi", "--id=0",
      "--query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw,power.limit,fan.speed",
      "--format=csv,noheader,nounits", "-lms", String(root.interval * 1000)]
    stdout: SplitParser {
      onRead: function(data) { root.nvidiaLine(data) }
    }
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.gpuEnabled && root.gpuKind === "nvidia"
    triggeredOnStart: true
    onTriggered: if (!nvidiaProc.running) nvidiaProc.running = true
  }

  onGpuEnabledChanged: if (!gpuEnabled && nvidiaProc.running) nvidiaProc.running = false

  Timer {
    interval: root.interval * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.sample()
  }

  function start(proc) {
    if (proc.running) return
    proc.mount = diskMount
    proc.running = true
  }

  onDiskMountChanged: {
    diskDevice = ""
    disk = 0
    start(deviceProc)
    start(dfProc)
  }

  // Each run keeps the mount it started for: a result for an older mount is dropped and the run repeated.
  Process {
    id: deviceProc
    property string mount: ""
    command: [Qt.resolvedUrl("stats-detail").toString().replace("file://", ""), "device", mount]
    stdout: StdioCollector {
      onStreamFinished: if (deviceProc.mount === root.diskMount) root.diskDevice = String(text).trim()
    }
    onExited: if (mount !== root.diskMount) Qt.callLater(root.start, deviceProc)
  }

  Process {
    id: dfProc
    property string mount: ""
    command: ["df", "-P", mount]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = String(text).match(/\s(\d+)%\s/)
        if (m && dfProc.mount === root.diskMount) root.disk = Number(m[1])
      }
    }
    onExited: if (mount !== root.diskMount) Qt.callLater(root.start, dfProc)
  }

  Component.onCompleted: start(deviceProc)

  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.start(dfProc)
  }

  Process {
    id: publicIpProc
    command: ["curl", "-fsS", "--max-time", "4", "https://1.1.1.1/cdn-cgi/trace"]
    stdout: StdioCollector {
      onStreamFinished: {
        var m = String(text).match(/^ip=(.+)$/m)
        if (m) root.publicIp = m[1].trim()
      }
    }
  }

  onPublicIpEnabledChanged: if (!publicIpEnabled) publicIp = ""
  function refreshPublicIp() { if (publicIpEnabled && !publicIpProc.running) publicIpProc.running = true }
}
