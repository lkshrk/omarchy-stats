import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "lkshrk.stats"

  readonly property var stats: bar?.shell?.serviceFor("lkshrk.stats") ?? fallback
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
  // Each card's last details, kept so a reopened card shows them at once while fresh ones load.
  property var details: ({})
  readonly property var cpuDetail: details.cpu || null
  readonly property var ramDetail: details.ram || null
  readonly property var netDetail: details.net || null
  readonly property var diskDetail: details.disk || null
  readonly property var gpuDetail: details.gpu || null
  property string openModule: ""

  // A list setting may also be a comma-separated string: `omarchy bar set` cannot store an array.
  function listSetting(name, fallback) {
    var value = setting(name, null)
    if (value instanceof Array) return value
    if (typeof value === "string" && value.trim() !== "")
      return value.split(",").map(function(s) { return s.trim() }).filter(function(s) { return s !== "" })
    return fallback
  }

  // Connector names or models to show on (Hyprland passes no serial); empty shows it on every screen.
  readonly property var screens: listSetting("screens", [])
  readonly property string diskMount: setting("diskMount", "/")
  readonly property var items: listSetting("items", ["net", "cpu", "ram", "disk", "gpu"])
  onItemsChanged: if (openModule !== "" && items.indexOf(openModule) < 0) close()
  readonly property bool showPublicIp: setting("publicIp", false) === true
  readonly property var tempIds: listSetting("temps", ["cpu"])
  readonly property bool showCharts: setting("charts", true) !== false
  readonly property var driveMounts: listSetting("drives", null)

  function sensorById(id) {
    var list = root.stats.sensors
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
    return null
  }

  // The disk card's drives: the bar's first, then the `drives` mounts in that order, else every drive but /boot and /efi.
  readonly property var shownDrives: {
    var all = root.diskDetail && root.diskDetail.drives ? root.diskDetail.drives : []
    var main = root.diskDetail ? root.diskDetail.source : ""
    var first = all.filter(function(d) { return d.source === main }).map(function(d) {
      return Object.assign({}, d, { mount: root.stats.diskMount })
    })
    var others = all.filter(function(d) { return d.source !== main })
    others = driveMounts === null
      ? others.filter(function(d) { return !/^\/(boot|efi)(\/|$)/.test(d.mount) })
      : driveMounts.map(function(m) { return others.filter(function(d) { return d.mount === m })[0] }).filter(Boolean)
    return first.concat(others)
  }
  // Repeaters key on these strings, which change only when the set changes, so the blocks are not rebuilt every sample.
  readonly property string driveKeys: shownDrives.map(function(d) { return d.source }).join("\n")
  readonly property string sensorKeys: root.stats.sensors.map(function(t) { return t.id }).join("\n")
  function keys(joined) { return joined === "" ? [] : joined.split("\n") }
  function partitionName(part) {
    var all = root.diskDetail && root.diskDetail.drives ? root.diskDetail.drives : []
    for (var i = 0; i < all.length; i++) if (all[i].partition === part.name) return all[i].mount
    return (part.label || part.name) + (part.fstype ? "  ·  " + part.fstype : "")
  }
  function driveBySource(source) { return shownDrives.filter(function(d) { return d.source === source })[0] || null }
  readonly property var screen: QsWindow.window ? QsWindow.window.screen : null
  visible: !(screens instanceof Array) || screens.length === 0
    || (screen !== null && screens.some(function(s) { return s === screen.name || s === screen.model || s === screen.serialNumber }))

  Binding { target: root.stats; property: "diskMount"; value: root.diskMount; when: root.stats !== fallback }
  Binding { target: root.stats; property: "publicIpEnabled"; value: root.showPublicIp; when: root.stats !== fallback }
  Binding { target: root.stats; property: "gpuEnabled"; value: root.items.indexOf("gpu") >= 0 || root.items.indexOf("temp") >= 0; when: root.stats !== fallback }

  QtObject {
    id: fallback
    readonly property int interval: 2
    readonly property string diskMount: "/"
    readonly property int historySize: 60
    readonly property int cpu: 0
    readonly property int cpuUser: 0
    readonly property int cpuSystem: 0
    readonly property int ram: 0
    readonly property int disk: 0
    readonly property real rx: 0
    readonly property real tx: 0
    readonly property real diskRead: 0
    readonly property real diskWrite: 0
    readonly property var cpuHistory: []
    readonly property var ramHistory: []
    readonly property var rxHistory: []
    readonly property var txHistory: []
    readonly property var readHistory: []
    readonly property var writeHistory: []
    readonly property string publicIp: ""
    readonly property var cores: []
    readonly property real cpuTemp: -1
    readonly property real diskTemp: -1
    readonly property var sensors: []
    readonly property var diskTemps: ({})
    readonly property var diskRates: ({})
    readonly property var sensorHistories: ({})
    readonly property var diskHistories: ({})
    readonly property string gpuKind: ""
    readonly property string gpuName: ""
    readonly property int gpu: 0
    readonly property real gpuVramUsed: 0
    readonly property real gpuVramTotal: 0
    readonly property real gpuTemp: -1
    readonly property real gpuPower: -1
    readonly property real gpuPowerLimit: -1
    readonly property var cpuInfo: ({ model: "", cores: 0, threads: 0 })
    readonly property var diskTotals: ({})
    readonly property int gpuFan: -1
    readonly property var gpuHistory: []
    function refreshPublicIp() {}
  }

  function close() { openModule = "" }
  function toggle(name) { openModule = openModule === name ? "" : name }

  readonly property color barText: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color popupText: Commons.Color.popups.text
  readonly property color muted: Commons.Color.muted
  readonly property color accent: Commons.Color.accent
  readonly property color downloadColor: "#3b82f6"
  readonly property color uploadColor: "#ef4444"
  readonly property color systemColor: "#ef4444"
  readonly property color userColor: "#3b82f6"
  readonly property color cacheColor: "#eab308"
  readonly property var seriesColors: ["#ef4444", "#3b82f6", "#eab308", "#22c55e", "#a855f7", "#06b6d4"]
  readonly property color idleColor: Qt.rgba(Commons.Color.muted.r, Commons.Color.muted.g, Commons.Color.muted.b, 0.35)

  function scaled(value, units, base) {
    var unit = 0
    while (value >= base && unit < units.length - 1) {
      value /= base
      unit++
    }
    var digits = value === 0 || unit === 0 ? 0 : (value < 10 ? 2 : (value < 100 ? 1 : 0))
    return value.toFixed(digits) + " " + units[unit]
  }
  function speed(bytes) { return scaled(bytes, ["B/s", "KB/s", "MB/s", "GB/s"], 1000) }
  function size(bytes) { return scaled(bytes, ["B", "KB", "MB", "GB", "TB"], 1024) }
  function duration(seconds) {
    var d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60)
    return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
  }
  function temperature(celsius) { return celsius >= 0 ? Math.round(celsius) + " °C" : "–" }
  function pressureLevel(avg10) {
    if (avg10 >= 30) return "Critical"
    if (avg10 >= 10) return "Warning"
    return "Normal"
  }

  // Sections waiting for stats-detail, which runs one at a time; a section already queued is not added again.
  property var detailQueue: []
  readonly property var detailSections: ["cpu", "ram", "net", "disk", "gpu"]

  function fetchDetail(section) {
    if (detailSections.indexOf(section) < 0 || detailQueue.indexOf(section) >= 0) return
    detailQueue = detailQueue.concat([section])
    pumpDetail()
  }

  function pumpDetail() {
    if (detailProc.running || detailQueue.length === 0) return
    detailProc.section = detailQueue[0]
    detailQueue = detailQueue.slice(1)
    detailProc.running = true
  }

  Process {
    id: detailProc
    property string section: ""
    command: [root.pluginDir + "stats-detail", section, root.stats.diskMount]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var next = Object.assign({}, root.details)
          next[detailProc.section] = JSON.parse(String(text))
          root.details = next
        } catch (e) {}
      }
    }
    onExited: Qt.callLater(root.pumpDetail)
  }

  onOpenModuleChanged: {
    if (openModule === "net") stats.refreshPublicIp()
    fetchDetail(openModule)
  }

  Timer {
    interval: root.stats.interval * 1000
    running: root.openModule !== ""
    repeat: true
    onTriggered: root.fetchDetail(root.openModule)
  }

  // The drive list is fetched ahead, so the drive card is complete the first time it opens.
  Timer {
    interval: 30000
    running: root.visible && root.items.indexOf("disk") >= 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.fetchDetail("disk")
  }

  implicitWidth: row.implicitWidth + Style.spaceReal(8)
  implicitHeight: root.barSize

  component BarText: Text {
    color: root.barText
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    verticalAlignment: Text.AlignVCenter
  }

  component Module: Item {
    id: module
    property string name
    default property alias content: inner.data
    property alias popupContent: popupColumn.data
    property int popupWidth: Style.space(320)
    readonly property bool active: root.openModule === module.name

    visible: root.items.indexOf(module.name) >= 0 && (module.name !== "gpu" || root.stats.gpuKind !== "")

    function close() { if (module.active) root.close() }
    // The bar calls this on the open card while another popout opens; reading `active` here would be a binding loop.
    function closeForPopoutSwitch() {
      Qt.callLater(function() { if (root.openModule === module.name) root.close() })
    }

    implicitWidth: inner.implicitWidth
    implicitHeight: root.barSize

    RowLayout {
      id: inner
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spaceReal(1.5)
    }

    // Same mark the bar draws under a module with an open panel, but per stat.
    Rectangle {
      visible: opacity > 0
      opacity: module.active ? 0.9 : 0
      color: Commons.Color.accent
      width: Math.max(Style.space(10), Math.round(module.width * 0.55))
      height: Style.space(2)
      radius: height / 2
      x: Math.floor((module.width - width) / 2)
      y: module.height - height - Style.space(2)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          root.close()
          if (root.bar) root.bar.run("uwsm-app -- missioncenter")
        } else {
          root.toggle(module.name)
        }
      }
    }

    PopupCard {
      id: popup
      anchorItem: module
      bar: root.bar
      owner: module
      open: module.active
      contentWidth: popup.fittedContentWidth(module.popupWidth)
      contentHeight: popup.fittedContentHeight(popupColumn.implicitHeight)

      ColumnLayout {
        id: popupColumn
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(4)
      }
    }
  }

  // Card title and section heading: bold text, with an optional muted detail on the right.
  component Heading: RowLayout {
    property string text
    property string detail
    Layout.fillWidth: true
    Layout.topMargin: Style.space(6)
    spacing: Style.space(6)
    Text {
      Layout.fillWidth: true
      text: parent.text
      color: root.popupText
      elide: Text.ElideRight
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
    Text {
      visible: parent.detail !== ""
      text: parent.detail
      color: root.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
  }

  component Dot: Rectangle {
    width: 6
    height: 6
    radius: 3
  }

  component FieldText: Text {
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  component Field: RowLayout {
    property string name
    property string value
    property color dot: "transparent"
    Layout.fillWidth: true
    spacing: Style.space(6)

    Dot { visible: parent.dot.a > 0; color: parent.dot }
    FieldText { Layout.fillWidth: true; text: parent.name; color: root.muted; elide: Text.ElideRight }
    FieldText { text: parent.value; color: root.popupText }
  }

  // Two values on one line, each with the dot of its chart line.
  component PairField: RowLayout {
    property string name
    property string first
    property color firstDot
    property string second
    property color secondDot
    Layout.fillWidth: true
    spacing: Style.space(6)

    FieldText { Layout.fillWidth: true; text: parent.name; color: root.muted; elide: Text.ElideRight }
    Dot { color: parent.firstDot }
    FieldText { text: parent.first; color: root.popupText }
    Dot { Layout.leftMargin: Style.space(6); color: parent.secondDot }
    FieldText { text: parent.second; color: root.popupText }
  }

  component History: StatsChart {
    visible: root.showCharts
    Layout.fillWidth: true
    Layout.preferredHeight: Style.space(70)
    grid: Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.25)
    capacity: root.stats.historySize
  }

  component DonutRow: RowLayout {
    property var slices: []
    property var outerSlices: []
    property string centerText
    default property alias details: legend.data
    Layout.fillWidth: true
    spacing: Style.space(12)

    Item {
      Layout.preferredWidth: Style.space(84)
      Layout.preferredHeight: Style.space(84)
      StatsChart {
        anchors.fill: parent
        kind: "donut"
        slices: parent.parent.slices
        outerSlices: parent.parent.outerSlices
        grid: Qt.rgba(root.muted.r, root.muted.g, root.muted.b, 0.25)
      }
      Text {
        anchors.centerIn: parent
        text: parent.parent.centerText
        color: root.popupText
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }
    ColumnLayout {
      id: legend
      Layout.fillWidth: true
      spacing: Style.space(4)
    }
  }

  component Meter: Rectangle {
    property real fraction: 0
    Layout.fillWidth: true
    implicitHeight: Style.space(6)
    radius: height / 2
    color: root.idleColor
    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, parent.fraction))
      height: parent.height
      radius: parent.radius
      color: root.accent
    }
  }

  // One bar per core, filled from the bottom by its usage.
  component CoreBars: RowLayout {
    property var values: []
    Layout.fillWidth: true
    Layout.preferredHeight: Style.space(36)
    spacing: Style.space(2)
    Repeater {
      model: parent.values
      Rectangle {
        required property var modelData
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Style.space(1)
        color: root.idleColor
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: parent.height * Math.max(0, Math.min(1, modelData / 100))
          radius: parent.radius
          color: modelData >= 90 ? root.systemColor : root.accent
        }
      }
    }
  }

  // One drive as a section of the disk card, laid out like the other cards' sections.
  component DriveBlock: ColumnLayout {
    id: block
    required property var modelData
    readonly property var drive: root.driveBySource(modelData) || ({ mount: "", disk: "", source: modelData, total: 0, used: 0, free: 0 })
    readonly property var rates: root.stats.diskRates[drive.disk] || null
    readonly property var history: root.stats.diskHistories[drive.disk] || null
    readonly property var totals: root.stats.diskTotals[drive.disk] || null
    readonly property int percent: drive.total > 0 ? Math.round(100 * drive.used / drive.total) : 0
    readonly property var breakdown: drive.breakdown || ({ kind: "plain" })
    readonly property bool btrfs: breakdown.kind === "btrfs"
    readonly property real reserved: Math.max(0, drive.total - drive.used - drive.free)
    readonly property var fsSlices: btrfs
      ? [{ value: breakdown.data, color: root.accent }, { value: breakdown.metadata + breakdown.system, color: root.cacheColor }, { value: drive.free, color: root.idleColor }]
      : [{ value: drive.used, color: root.accent }, { value: reserved, color: root.cacheColor }, { value: drive.free, color: root.idleColor }]
    // The physical disk's partitions, this drive's in the accent color; slivers under 1% are left out.
    readonly property var parts: {
      var layout = drive.layout
      if (!layout || !layout.parts) return []
      var palette = ["#a855f7", "#06b6d4", "#22c55e", "#f97316", "#ec4899"]
      var list = []
      var allocated = 0
      var k = 0
      for (var i = 0; i < layout.parts.length; i++) {
        var part = layout.parts[i]
        allocated += part.size
        var mine = part.name === drive.partition
        if (!mine && part.size < layout.size * 0.01) continue
        list.push({ name: root.partitionName(part), size: part.size, color: mine ? root.accent : palette[k++ % palette.length] })
      }
      var unallocated = layout.size - allocated
      if (unallocated > layout.size * 0.01) list.push({ name: "Unallocated", size: unallocated, color: root.idleColor })
      return list.length > 1 ? list : []
    }
    Layout.fillWidth: true
    spacing: Style.space(4)

    Heading {
      text: block.drive.mount
      detail: [block.drive.model, block.drive.fstype].filter(function(part) { return !!part }).join("  ·  ")
    }
    History {
      series: [
        { values: block.history ? block.history.read : [], color: root.downloadColor },
        { values: block.history ? block.history.write : [], color: root.uploadColor }
      ]
    }
    PairField {
      name: "Read / write"
      first: block.rates ? root.speed(block.rates.read) : "–"
      firstDot: root.downloadColor
      second: block.rates ? root.speed(block.rates.write) : "–"
      secondDot: root.uploadColor
    }
    DonutRow {
      centerText: block.percent + "%"
      slices: block.fsSlices
      outerSlices: block.parts.map(function(p) { return { value: p.size, color: p.color } })
      Field { visible: block.btrfs; name: "Data"; dot: root.accent; value: root.size(block.breakdown.data || 0) }
      Field { visible: block.btrfs; name: "Metadata"; dot: root.cacheColor; value: root.size((block.breakdown.metadata || 0) + (block.breakdown.system || 0)) }
      Field { visible: !block.btrfs; name: "Used"; dot: root.accent; value: root.size(block.drive.used) }
      Field { visible: !block.btrfs && block.reserved > 0; name: "Reserved"; dot: root.cacheColor; value: root.size(block.reserved) }
      Field { name: "Free"; dot: root.idleColor; value: root.size(block.drive.free) }
      Field { name: "Total"; value: root.size(block.drive.total) }
    }
    Heading {
      visible: block.parts.length > 0
      text: "Disk layout"
      detail: block.drive.disk + (block.drive.layout ? "  ·  " + root.size(block.drive.layout.size) : "")
    }
    Repeater {
      model: block.parts
      Field {
        required property var modelData
        name: modelData.name
        dot: modelData.color
        value: root.size(modelData.size)
      }
    }
    Field {
      name: "Operations / s"
      value: block.rates ? block.rates.readOps + " read  ·  " + block.rates.writeOps + " write" : "–"
    }
    Field { name: "Busy"; value: block.rates ? block.rates.busy + "%" : "–" }
    Field {
      name: "Since boot"
      value: block.totals ? root.size(block.totals.read) + " read  ·  " + root.size(block.totals.write) + " written" : "–"
    }
    Field {
      name: "Device"
      value: block.drive.disk + (block.drive.source && block.drive.source.indexOf(block.drive.disk) < 0 ? "  ·  " + block.drive.source : "")
    }
  }

  component TopList: Repeater {
    id: topList
    property bool memory: false
    Field {
      required property var modelData
      name: modelData.name
      value: topList.memory ? root.size(modelData.value) : modelData.value.toFixed(1) + "%"
    }
  }

  Text { id: percentProbe; visible: false; text: "100%"; font.family: Style.font.family; font.pixelSize: Style.font.body }
  Text { id: tempProbe; visible: false; text: "100 °C"; font.family: Style.font.family; font.pixelSize: Style.font.body }
  Text { id: speedProbe; visible: false; text: "99.9 KB/s"; font.family: Style.font.family; font.pixelSize: Style.font.body }

  // Every card: a title with a detail, the history chart, the current values, then sections; top processes last.
  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Style.spaceReal(6)

    Module {
      name: "net"
      BarText { text: "↑"; color: root.uploadColor }
      BarText { text: root.speed(root.stats.tx); Layout.minimumWidth: speedProbe.implicitWidth; horizontalAlignment: Text.AlignLeft }
      BarText { text: "↓"; color: root.downloadColor; Layout.leftMargin: Style.spaceReal(4) }
      BarText { text: root.speed(root.stats.rx); Layout.minimumWidth: speedProbe.implicitWidth; horizontalAlignment: Text.AlignLeft }

      popupContent: [
        Heading { text: "Network"; detail: root.netDetail && root.netDetail.interface ? root.netDetail.interface : ""; Layout.topMargin: 0 },
        History {
          series: [
            { values: root.stats.rxHistory, color: root.downloadColor },
            { values: root.stats.txHistory, color: root.uploadColor }
          ]
        },
        PairField {
          name: "Download / upload"
          first: root.speed(root.stats.rx)
          firstDot: root.downloadColor
          second: root.speed(root.stats.tx)
          secondDot: root.uploadColor
        },
        Heading { text: "Details" },
        Field { name: "Local IP"; value: root.netDetail && root.netDetail.ip ? root.netDetail.ip : "–" },
        Field { name: "Public IP"; visible: root.showPublicIp; value: root.stats.publicIp || "–" },
        Field { name: "Physical address"; value: root.netDetail && root.netDetail.mac ? root.netDetail.mac : "–" },
        Field { name: "DNS server"; value: root.netDetail && root.netDetail.dns ? root.netDetail.dns : "–" },
        Field { name: "Total download"; value: root.netDetail ? root.size(root.netDetail.totalDownload) : "–" },
        Field { name: "Total upload"; value: root.netDetail ? root.size(root.netDetail.totalUpload) : "–" }
      ]
    }

    Module {
      name: "cpu"
      BarText { text: "󰻠" }
      BarText { text: root.stats.cpu + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: "CPU"; detail: root.stats.cpuInfo.model; Layout.topMargin: 0 },
        History { max: 100; series: [{ values: root.stats.cpuHistory, color: root.accent }] },
        DonutRow {
          centerText: root.stats.cpu + "%"
          slices: [
            { value: root.stats.cpuSystem, color: root.systemColor },
            { value: root.stats.cpuUser, color: root.userColor },
            { value: Math.max(0, 100 - root.stats.cpuSystem - root.stats.cpuUser), color: root.idleColor }
          ]
          Field { name: "System"; dot: root.systemColor; value: root.stats.cpuSystem + "%" }
          Field { name: "User"; dot: root.userColor; value: root.stats.cpuUser + "%" }
          Field { name: "Idle"; dot: root.idleColor; value: Math.max(0, 100 - root.stats.cpu) + "%" }
        },
        Heading {
          text: "Cores"
          visible: root.stats.cores.length > 0
          detail: root.stats.cpuInfo.cores > 0 ? root.stats.cpuInfo.cores + " cores / " + root.stats.cpuInfo.threads + " threads" : ""
        },
        CoreBars { visible: root.stats.cores.length > 0; values: root.stats.cores },
        Heading { text: "Details" },
        Field { name: "Frequency"; value: root.cpuDetail ? (root.cpuDetail.frequency / 1e9).toFixed(2) + " GHz" : "–" },
        Field { name: "Average load"; value: root.cpuDetail ? root.cpuDetail.load.map(function(l) { return l.toFixed(2) }).join("  ") : "–" },
        Field { name: "Uptime"; value: root.cpuDetail ? root.duration(root.cpuDetail.uptime) : "–" },
        Heading { text: "Top processes" },
        TopList { model: root.cpuDetail ? root.cpuDetail.top : [] }
      ]
    }

    Module {
      name: "ram"
      BarText { text: "󰍛" }
      BarText { text: root.stats.ram + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: "Memory"; detail: root.ramDetail ? root.size(root.ramDetail.total) : ""; Layout.topMargin: 0 },
        History { max: 100; series: [{ values: root.stats.ramHistory, color: root.accent }] },
        DonutRow {
          centerText: root.stats.ram + "%"
          slices: root.ramDetail ? [
            { value: root.ramDetail.app, color: root.userColor },
            { value: root.ramDetail.cache, color: root.cacheColor },
            { value: root.ramDetail.free, color: root.idleColor }
          ] : []
          Field { name: "App"; dot: root.userColor; value: root.ramDetail ? root.size(root.ramDetail.app) : "–" }
          Field { name: "Cache"; dot: root.cacheColor; value: root.ramDetail ? root.size(root.ramDetail.cache) : "–" }
          Field { name: "Free"; dot: root.idleColor; value: root.ramDetail ? root.size(root.ramDetail.free) : "–" }
        },
        Heading { text: "Details" },
        Field { name: "Used"; value: root.ramDetail ? root.size(root.ramDetail.used) + " / " + root.size(root.ramDetail.total) : "–" },
        Field { name: "Swap"; value: root.ramDetail ? root.size(root.ramDetail.swapUsed) + " / " + root.size(root.ramDetail.swapTotal) : "–" },
        Field { name: "Memory pressure"; value: root.ramDetail ? root.pressureLevel(root.ramDetail.pressure) : "–" },
        Heading { text: "Top processes" },
        TopList { memory: true; model: root.ramDetail ? root.ramDetail.top : [] }
      ]
    }

    Module {
      name: "disk"
      BarText { text: "󰋊" }
      BarText { text: root.stats.disk + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading {
          text: "Drives"
          detail: root.shownDrives.length > 1 ? root.shownDrives.length + " drives" : ""
          Layout.topMargin: 0
        },
        Repeater { model: root.keys(root.driveKeys); DriveBlock {} }
      ]
    }

    Module {
      name: "gpu"
      BarText { text: "󰢮" }
      BarText { text: root.stats.gpu + "%"; Layout.minimumWidth: percentProbe.implicitWidth }

      popupContent: [
        Heading { text: "GPU"; detail: root.stats.gpuName; Layout.topMargin: 0 },
        History { max: 100; series: [{ values: root.stats.gpuHistory, color: root.accent }] },
        Field { name: "Usage"; dot: root.accent; value: root.stats.gpu + "%" },
        Heading { text: "Video memory" },
        Meter { fraction: root.stats.gpuVramTotal > 0 ? root.stats.gpuVramUsed / root.stats.gpuVramTotal : 0 },
        Field { name: "Used"; value: root.size(root.stats.gpuVramUsed) + " / " + root.size(root.stats.gpuVramTotal) },
        Heading { text: "Details" },
        Field {
          name: "Power"
          visible: root.stats.gpuPower >= 0
          value: root.stats.gpuPower.toFixed(0) + " W" + (root.stats.gpuPowerLimit > 0 ? " / " + root.stats.gpuPowerLimit.toFixed(0) + " W" : "")
        },
        Field { name: "Fan"; visible: root.stats.gpuFan >= 0; value: root.stats.gpuFan + "%" },
        Heading { text: "Top processes"; visible: gpuTop.count > 0 },
        TopList { id: gpuTop; memory: true; model: root.gpuDetail ? root.gpuDetail.top : [] }
      ]
    }

    Module {
      name: "temp"
      BarText { text: "󰔏" }
      Repeater {
        model: root.tempIds
        BarText {
          required property var modelData
          required property int index
          readonly property var sensor: root.sensorById(modelData)
          text: root.tempIds.length > 1
            ? (sensor ? sensor.short : modelData) + " " + (sensor ? Math.round(sensor.value) + "°" : "–")
            : (sensor ? root.temperature(sensor.value) : "–")
          Layout.leftMargin: index > 0 ? Style.spaceReal(4) : 0
          Layout.minimumWidth: root.tempIds.length > 1 ? 0 : tempProbe.implicitWidth
        }
      }

      popupContent: [
        Heading { text: "Temperatures"; Layout.topMargin: 0 },
        History {
          max: 100
          fill: false
          series: root.tempIds.map(function(id, i) {
            return { values: root.stats.sensorHistories[id] || [], color: root.seriesColors[i % root.seriesColors.length] }
          })
        },
        Repeater {
          model: root.tempIds
          Field {
            required property var modelData
            required property int index
            readonly property var sensor: root.sensorById(modelData)
            name: sensor ? sensor.name : modelData
            dot: root.seriesColors[index % root.seriesColors.length]
            value: sensor ? root.temperature(sensor.value) : "–"
          }
        },
        Heading { text: "All sensors" },
        Repeater {
          model: root.keys(root.sensorKeys)
          Field {
            required property var modelData
            readonly property var sensor: root.sensorById(modelData)
            name: sensor ? sensor.name : modelData
            value: sensor ? root.temperature(sensor.value) : "–"
          }
        }
      ]
    }
  }
}
