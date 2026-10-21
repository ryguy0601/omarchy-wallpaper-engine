import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris

Item {
  id: root

  property var shell: null
  property var manifest: null

  // Configuration Properties (loaded dynamically from ~/.config/wallpaper-engine/config.json)
  property string cfgPosition: "center"
  property int cfgCustomX: 100
  property int cfgCustomY: 100
  property int cfgWidth: 720
  property int cfgSpacing: 22

  property bool modClock: true
  property bool modDate: true
  property bool modWeather: true
  property bool modMedia: true
  property bool modVisualizer: true
  property bool modSysinfo: true
  property bool modShortcuts: true
  property bool modQuote: false
  property bool modFooter: true
  property bool modCustomizeButton: true

  property bool cfgFormat12h: true
  property bool cfgShowAmPm: true
  property bool cfgShowSeconds: false
  property int cfgClockSize: 76

  property string cfgQuoteText: "The best way to predict the future is to invent it."
  property string cfgQuoteAuthor: "Alan Kay"

  property int cfgVisHeight: 70
  property int cfgVisBars: 28
  property bool cfgIdleWave: true

  property color cfgAccent: "#e20074"
  property string cfgCardBg: "#0c0c12"
  property real cfgCardOpacity: 0.85
  property int cfgCardRadius: 20
  property bool cfgBorderGlow: true
  property real cfgBorderWidth: 1.5
  property string cfgUserName: "auto"

  // Hardware Telemetry Configuration
  property bool cfgHwCpuLoad: true
  property bool cfgHwCpuTemp: true
  property bool cfgHwFanSpeed: true
  property bool cfgHwRam: true
  property bool cfgHwGpuTemp: false
  property string cfgHwTempUnit: "C"

  // Dynamic Dock Application Shortcuts
  property var cfgShortcuts: [
    { icon: "󰈹", label: "Browser", cmd: "omarchy-cmd-default-browser || xdg-open https://google.com" },
    { icon: "󰆍", label: "Terminal", cmd: "omarchy-default-terminal || foot" },
    { icon: "󰉋", label: "Files", cmd: "thunar || omarchy-file-select" },
    { icon: "󰨞", label: "Editor", cmd: "omarchy-default-editor || code || foot -e nvim" },
    { icon: "󰎆", label: "Music", cmd: "playerctl play-pause 2>/dev/null || true" },
    { icon: "", label: "Settings", cmd: Quickshell.env("HOME") + "/.local/bin/wallpaper-engine gui" }
  ]

  readonly property color cardFillColor: Qt.rgba(
    cfgAccent.r * 0.05 + 0.05,
    cfgAccent.g * 0.05 + 0.05,
    cfgAccent.b * 0.05 + 0.07,
    cfgCardOpacity
  )
  readonly property color cardBorderColor: Qt.rgba(cfgAccent.r, cfgAccent.g, cfgAccent.b, 0.45)
  readonly property color surfaceFillColor: Qt.rgba(cfgAccent.r * 0.08 + 0.08, cfgAccent.g * 0.08 + 0.08, cfgAccent.b * 0.08 + 0.12, 0.92)

  readonly property string resolvedUserName: {
    if (root.cfgUserName && root.cfgUserName !== "auto") return root.cfgUserName
    var envUser = Quickshell.env("USER") || "USER"
    return envUser.toUpperCase()
  }

  function displayTemp(tempC) {
    if (!tempC || tempC <= 0) return "--°"
    if (root.cfgHwTempUnit === "F") {
      var f = Math.round(tempC * 9.0 / 5.0 + 32)
      return f + "°F"
    }
    return tempC + "°C"
  }

  // Live FileView for Hot-Reloading configuration
  property FileView configFile: FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/wallpaper-engine/config.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
  }

  function applyConfig(rawJson) {
    try {
      var d = JSON.parse(rawJson)
      if (d.layout) {
        if (d.layout.position) root.cfgPosition = String(d.layout.position).toLowerCase()
        if (typeof d.layout.customX === "number") root.cfgCustomX = d.layout.customX
        if (typeof d.layout.customY === "number") root.cfgCustomY = d.layout.customY
        if (typeof d.layout.width === "number") root.cfgWidth = d.layout.width
        if (typeof d.layout.spacing === "number") root.cfgSpacing = d.layout.spacing
      }
      if (d.modules) {
        if (typeof d.modules.clock === "boolean") root.modClock = d.modules.clock
        if (typeof d.modules.date === "boolean") root.modDate = d.modules.date
        if (typeof d.modules.weather === "boolean") root.modWeather = d.modules.weather
        if (typeof d.modules.media === "boolean") root.modMedia = d.modules.media
        if (typeof d.modules.visualizer === "boolean") root.modVisualizer = d.modules.visualizer
        if (typeof d.modules.sysinfo === "boolean") root.modSysinfo = d.modules.sysinfo
        if (typeof d.modules.shortcuts === "boolean") root.modShortcuts = d.modules.shortcuts
        if (typeof d.modules.quote === "boolean") root.modQuote = d.modules.quote
        if (typeof d.modules.footer === "boolean") root.modFooter = d.modules.footer
        if (typeof d.modules.customizeButton === "boolean") root.modCustomizeButton = d.modules.customizeButton
        else if (typeof d.style === "object" && typeof d.style.showCustomizeButton === "boolean") root.modCustomizeButton = d.style.showCustomizeButton
      }
      if (d.clock) {
        if (typeof d.clock.format12h === "boolean") root.cfgFormat12h = d.clock.format12h
        if (typeof d.clock.showAmPm === "boolean") root.cfgShowAmPm = d.clock.showAmPm
        if (typeof d.clock.showSeconds === "boolean") root.cfgShowSeconds = d.clock.showSeconds
        if (typeof d.clock.fontSize === "number") root.cfgClockSize = d.clock.fontSize
      }
      if (d.hardware) {
        if (typeof d.hardware.showCpuLoad === "boolean") root.cfgHwCpuLoad = d.hardware.showCpuLoad
        if (typeof d.hardware.showCpuTemp === "boolean") root.cfgHwCpuTemp = d.hardware.showCpuTemp
        if (typeof d.hardware.showFanSpeed === "boolean") root.cfgHwFanSpeed = d.hardware.showFanSpeed
        if (typeof d.hardware.showRam === "boolean") root.cfgHwRam = d.hardware.showRam
        if (typeof d.hardware.showGpuTemp === "boolean") root.cfgHwGpuTemp = d.hardware.showGpuTemp
        if (typeof d.hardware.tempUnit === "string") root.cfgHwTempUnit = d.hardware.tempUnit.toUpperCase()
      }
      if (Array.isArray(d.shortcuts) && d.shortcuts.length > 0) {
        root.cfgShortcuts = d.shortcuts
      }
      if (d.quote) {
        if (typeof d.quote.text === "string") root.cfgQuoteText = d.quote.text
        if (typeof d.quote.author === "string") root.cfgQuoteAuthor = d.quote.author
      }
      if (d.visualizer) {
        if (typeof d.visualizer.height === "number") root.cfgVisHeight = d.visualizer.height
        if (typeof d.visualizer.bars === "number") root.cfgVisBars = d.visualizer.bars
        if (typeof d.visualizer.idleWave === "boolean") root.cfgIdleWave = d.visualizer.idleWave
      }
      if (d.style) {
        if (d.style.accentColor) root.cfgAccent = d.style.accentColor
        if (d.style.cardBackground) root.cfgCardBg = d.style.cardBackground
        if (typeof d.style.cardOpacity === "number") root.cfgCardOpacity = d.style.cardOpacity
        if (typeof d.style.cardRadius === "number") root.cfgCardRadius = d.style.cardRadius
        if (typeof d.style.borderGlow === "boolean") root.cfgBorderGlow = d.style.borderGlow
        if (typeof d.style.borderWidth === "number") root.cfgBorderWidth = d.style.borderWidth
        if (d.style.userName) root.cfgUserName = d.style.userName
      }
      root.updateTime()
    } catch (e) {
      console.warn("WallpaperEngine: Error parsing config:", e)
    }
  }

  // Time & Date State
  property string currentTime: "12:00"
  property string currentSeconds: ":00"
  property string currentAmPm: "PM"
  property string currentDate: ""

  function updateTime() {
    var d = new Date()
    var hours = d.getHours()
    var minutes = d.getMinutes()
    var seconds = d.getSeconds()
    var minutesStr = minutes < 10 ? ("0" + minutes) : minutes
    var secondsStr = seconds < 10 ? ("0" + seconds) : seconds

    if (root.cfgFormat12h) {
      var ampm = hours >= 12 ? "PM" : "AM"
      hours = hours % 12
      hours = hours ? hours : 12
      currentTime = hours + ":" + minutesStr
      currentAmPm = ampm
    } else {
      var hoursStr = hours < 10 ? ("0" + hours) : hours
      currentTime = hoursStr + ":" + minutesStr
      currentAmPm = ""
    }
    currentSeconds = ":" + secondsStr
    currentDate = Qt.formatDateTime(d, "dddd, MMMM d, yyyy")
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.updateTime()
  }

  // Weather State
  property string weatherCity: "Omarchy"
  property string weatherTemp: "--°"
  property string weatherIcon: "󰖐"

  Process {
    id: weatherProc
    command: ["/usr/share/omarchy/bin/omarchy", "weather", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str.length > 0) {
          var parts = str.split("·")
          if (parts.length >= 2) {
            root.weatherCity = parts[0].trim()
            root.weatherTemp = parts[1].replace("Temp", "").trim()
          }
        }
      }
    }
  }

  Process {
    id: weatherIconProc
    command: ["/usr/share/omarchy/bin/omarchy", "weather", "icon"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str.length > 0) root.weatherIcon = str
      }
    }
  }

  Timer {
    interval: 180000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      weatherProc.running = true
      weatherIconProc.running = true
    }
  }

  // System Hardware Stats (CPU load, CPU temp, Fan speed, RAM, GPU temp)
  property string sysCpuLoad: "0.0"
  property string sysRamUsed: "0G"
  property string sysRamTotal: "0G"
  property int sysRamPercent: 0
  property int sysCpuTemp: 0
  property int sysFanSpeed: 0
  property int sysGpuTemp: 0

  Process {
    id: sysinfoProc
    command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "hwinfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var str = String(text || "").trim()
          if (str.length > 0) {
            var data = JSON.parse(str)
            if (data.cpuLoad !== undefined) root.sysCpuLoad = String(data.cpuLoad)
            if (data.ramUsed !== undefined) root.sysRamUsed = String(data.ramUsed)
            if (data.ramTotal !== undefined) root.sysRamTotal = String(data.ramTotal)
            if (data.ramPercent !== undefined) root.sysRamPercent = data.ramPercent
            if (data.cpuTemp !== undefined) root.sysCpuTemp = data.cpuTemp
            if (data.fanSpeed !== undefined) root.sysFanSpeed = data.fanSpeed
            if (data.gpuTemp !== undefined) root.sysGpuTemp = data.gpuTemp
          }
        } catch (e) {
          console.warn("WallpaperEngine: Error parsing hwinfo:", e)
        }
      }
    }
  }

  Timer {
    interval: 2500
    running: root.modSysinfo
    repeat: true
    triggeredOnStart: true
    onTriggered: sysinfoProc.running = true
  }

  // MPRIS Media State
  function getActivePlayer() {
    var list = Mpris.players ? Mpris.players.values : []
    if (!list || list.length === 0) return null
    for (var i = 0; i < list.length; i++) {
      if (list[i].playbackState === MprisPlaybackState.Playing) return list[i]
    }
    return list[0]
  }

  readonly property var activePlayer: getActivePlayer()
  readonly property bool isPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing
  readonly property string trackTitle: activePlayer && activePlayer.trackTitle ? activePlayer.trackTitle : "No Media Playing"
  readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Play music or audio to visualize"
  readonly property string trackAlbum: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string trackArt: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

  // Audio Spectrum State & Physics (60 FPS)
  property var rawBars: []
  property var displayBars: []
  property var peakBars: []
  property real idlePhase: 0

  Component.onCompleted: {
    var b = []
    var p = []
    for (var i = 0; i < cfgVisBars; i++) {
      b.push(0)
      p.push(0)
    }
    rawBars = b
    displayBars = b
    peakBars = p
    updateTime()
  }

  Timer {
    interval: 16
    running: root.modVisualizer
    repeat: true
    onTriggered: {
      root.idlePhase += 0.05
      var disp = []
      var peaks = []
      var hasAudio = false

      for (var i = 0; i < root.cfgVisBars; i++) {
        var raw = (root.rawBars && root.rawBars[i]) ? root.rawBars[i] : 0
        if (raw > 2) hasAudio = true

        var cur = (root.displayBars && root.displayBars[i]) ? root.displayBars[i] : 0
        var target = raw

        if (!hasAudio && !root.isPlaying && root.cfgIdleWave) {
          target = Math.max(3, Math.sin(root.idlePhase + i * 0.3) * 6 + 8)
        }

        if (target > cur) {
          cur += (target - cur) * 0.45
        } else {
          cur += (target - cur) * 0.15
        }
        disp.push(cur)

        var peak = (root.peakBars && root.peakBars[i]) ? root.peakBars[i] : 0
        if (cur >= peak) {
          peak = cur
        } else {
          peak = Math.max(cur, peak - 1.2)
        }
        peaks.push(peak)
      }

      root.displayBars = disp
      root.peakBars = peaks
    }
  }

  Process {
    id: cavaProc
    command: [
      Quickshell.env("HOME") + "/.local/bin/cava",
      "-p",
      Quickshell.env("HOME") + "/.config/omarchy/plugins/ryguy.wallpaper-engine/cava.conf"
    ]
    running: root.modVisualizer
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.trim().split(/\s+/)
        if (parts.length >= root.cfgVisBars) {
          var vals = []
          for (var i = 0; i < root.cfgVisBars; i++) {
            vals.push(Math.min(100, Math.max(0, parseInt(parts[i]) || 0)))
          }
          root.rawBars = vals
        }
      }
    }
    onExited: restartCavaTimer.start()
  }

  Timer {
    id: restartCavaTimer
    interval: 2000
    onTriggered: cavaProc.running = root.modVisualizer
  }

  // High-reliability detached execution helpers
  function runCmd(cmd) {
    if (!cmd || cmd.trim() === "") return
    Quickshell.execDetached(["bash", "-lc", cmd])
  }

  function openGui() {
    Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "gui"])
  }

  // Multi-Screen LayerShell Windows
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData
      screen: modelData

      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      WlrLayershell.namespace: "ryguy-wallpaper-engine"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      exclusionMode: ExclusionMode.Ignore

      // The mask bounds exactly to widgetHub so all buttons and interactive controls
      // are completely clickable, while leaving all empty desktop areas 100% click-through.
      mask: Region {
        item: widgetHub
      }

      Item {
        anchors.fill: parent

        // Main Widget Hub Container with Smooth Animated Positioning
        Item {
          id: widgetHub
          width: root.cfgWidth
          height: contentColumn.height

          readonly property real computedX: {
            var pos = root.cfgPosition
            if (pos === "top-left" || pos === "bottom-left") return 60
            if (pos === "top-right" || pos === "bottom-right") return parent.width - width - 60
            if (pos === "custom") return root.cfgCustomX
            return (parent.width - width) / 2
          }
          readonly property real computedY: {
            var pos = root.cfgPosition
            if (pos === "top-left" || pos === "top-right" || pos === "top-center") return 60
            if (pos === "bottom-left" || pos === "bottom-right" || pos === "bottom-center") return parent.height - height - 60
            if (pos === "custom") return root.cfgCustomY
            return (parent.height - height) / 2
          }

          x: computedX
          y: computedY

          Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
          Behavior on y { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

          Column {
            id: contentColumn
            width: parent.width
            spacing: root.cfgSpacing

            // ==========================================
            // MODULE 1: Clock, Date & Weather Card
            // ==========================================
            Rectangle {
              id: clockCard
              visible: root.modClock || root.modDate || root.modWeather
              width: parent.width
              height: clockCol.implicitHeight + 40
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: root.cfgBorderWidth

              // Right-click shortcut to open customizer GUI
              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openGui()
              }

              // Glow Pill
              Rectangle {
                visible: root.cfgBorderGlow
                anchors.centerIn: parent
                width: 380
                height: 100
                radius: 50
                color: root.cfgAccent
                opacity: 0.08
              }

              Column {
                id: clockCol
                anchors.centerIn: parent
                spacing: 8
                width: parent.width - 48

                // 12h / 24h Clock Row
                Row {
                  visible: root.modClock
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: 8

                  Text {
                    text: root.currentTime
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: root.cfgClockSize
                    font.weight: Font.Bold
                    color: "#ffffff"
                  }

                  Text {
                    visible: root.cfgShowSeconds
                    text: root.currentSeconds
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(root.cfgClockSize * 0.42)
                    font.weight: Font.Bold
                    color: Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.85)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(root.cfgClockSize * 0.12)
                  }

                  Text {
                    visible: root.cfgShowAmPm && root.currentAmPm !== ""
                    text: root.currentAmPm
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Math.round(root.cfgClockSize * 0.34)
                    font.weight: Font.ExtraBold
                    color: root.cfgAccent
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Math.round(root.cfgClockSize * 0.14)
                  }
                }

                // Date Row
                Text {
                  visible: root.modDate
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: root.currentDate
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 17
                  font.weight: Font.Medium
                  color: "#dcdcfa"
                  font.letterSpacing: 2
                }

                // Weather Pill
                Rectangle {
                  visible: root.modWeather
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: weatherRow.implicitWidth + 24
                  height: 32
                  radius: 16
                  color: root.surfaceFillColor
                  border.color: root.cardBorderColor
                  border.width: 1

                  Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                      text: root.weatherIcon
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 15
                      color: root.cfgAccent
                    }

                    Text {
                      text: root.weatherCity + "  " + root.weatherTemp
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 13
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }
                  }
                }
              }
            }

            // ==========================================
            // MODULE: Quick-Launch Shortcuts Dock (Fully Customizable)
            // ==========================================
            Rectangle {
              id: shortcutsDock
              visible: root.modShortcuts && root.cfgShortcuts.length > 0
              width: parent.width
              height: 56
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: root.cfgBorderWidth

              RowLayout {
                anchors.centerIn: parent
                spacing: 20

                Repeater {
                  model: root.cfgShortcuts

                  Item {
                    id: dockItem
                    required property var modelData
                    width: 42
                    height: 42

                    Rectangle {
                      id: dockBtn
                      anchors.fill: parent
                      radius: 21
                      color: dockMouse.containsMouse ? Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.40) : root.surfaceFillColor
                      border.color: dockMouse.containsMouse ? root.cfgAccent : root.cardBorderColor
                      border.width: dockMouse.containsMouse ? 1.5 : 1

                      Behavior on color { ColorAnimation { duration: 120 } }
                      scale: dockMouse.pressed ? 0.90 : (dockMouse.containsMouse ? 1.14 : 1.0)
                      Behavior on scale { NumberAnimation { duration: 120 } }

                      Text {
                        anchors.centerIn: parent
                        text: dockItem.modelData.icon || "󰈹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 20
                        color: dockMouse.containsMouse ? "#ffffff" : root.cfgAccent
                      }

                      MouseArea {
                        id: dockMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runCmd(dockItem.modelData.cmd)
                      }
                    }

                    // Hover Label Tooltip Pill
                    Rectangle {
                      visible: dockMouse.containsMouse && dockItem.modelData.label !== undefined && dockItem.modelData.label.length > 0
                      anchors.bottom: dockBtn.top
                      anchors.bottomMargin: 8
                      anchors.horizontalCenter: dockBtn.horizontalCenter
                      width: ttText.implicitWidth + 14
                      height: 22
                      radius: 11
                      color: "#181824"
                      border.color: root.cfgAccent
                      border.width: 1
                      z: 100

                      Text {
                        id: ttText
                        anchors.centerIn: parent
                        text: dockItem.modelData.label || ""
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: "#ffffff"
                      }
                    }
                  }
                }
              }
            }

            // ==========================================
            // MODULE: Daily Quote / Inspiration Card
            // ==========================================
            Rectangle {
              id: quoteCard
              visible: root.modQuote && root.cfgQuoteText.length > 0
              width: parent.width
              height: quoteCol.implicitHeight + 28
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: root.cfgBorderWidth

              ColumnLayout {
                id: quoteCol
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "󰝗"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 20
                    color: root.cfgAccent
                  }

                  Text {
                    Layout.fillWidth: true
                    text: root.cfgQuoteText
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.italic: true
                    color: "#f0f0ff"
                    wrapMode: Text.WordWrap
                  }
                }

                Text {
                  visible: root.cfgQuoteAuthor.length > 0
                  Layout.alignment: Qt.AlignRight
                  text: "— " + root.cfgQuoteAuthor
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  font.weight: Font.Bold
                  color: root.cfgAccent
                }
              }
            }

            // ==========================================
            // MODULE 2: Media Player & Audio Visualizer
            // ==========================================
            Rectangle {
              id: mediaCard
              visible: root.modMedia || root.modVisualizer
              width: parent.width
              height: mediaCol.implicitHeight + 36
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: root.cfgBorderWidth

              Column {
                id: mediaCol
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 18

                // Track Info Header & Interactive Playback Controls
                RowLayout {
                  visible: root.modMedia
                  width: parent.width
                  spacing: 16

                  // Track Art / Icon
                  Rectangle {
                    width: 54
                    height: 54
                    radius: 12
                    color: root.surfaceFillColor
                    border.color: root.cardBorderColor
                    border.width: 1

                    Image {
                      anchors.fill: parent
                      anchors.margins: 2
                      source: root.trackArt
                      fillMode: Image.PreserveAspectCrop
                      visible: root.trackArt !== ""
                      layer.enabled: true
                    }

                    Text {
                      visible: root.trackArt === ""
                      anchors.centerIn: parent
                      text: root.isPlaying ? "󰎈" : "󰎊"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 24
                      color: root.cfgAccent
                    }
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Row {
                      spacing: 8
                      Text {
                        text: root.isPlaying ? "󰐊 PLAYING" : "󰏤 IDLE"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.ExtraBold
                        color: root.cfgAccent
                        font.letterSpacing: 2
                      }
                    }

                    Text {
                      text: root.trackTitle
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 17
                      font.weight: Font.Bold
                      color: "#ffffff"
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: root.trackArtist + (root.trackAlbum ? (" · " + root.trackAlbum) : "")
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      color: "#9e9eb8"
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  // Interactive Playback Controls Pill
                  Row {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    // Previous Track Button
                    Rectangle {
                      width: 32
                      height: 32
                      radius: 16
                      color: prevMouse.containsMouse ? Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.35) : root.surfaceFillColor
                      border.color: prevMouse.containsMouse ? root.cfgAccent : root.cardBorderColor
                      border.width: 1
                      scale: prevMouse.pressed ? 0.92 : 1.0

                      Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: prevMouse.containsMouse ? "#ffffff" : root.cfgAccent
                      }

                      MouseArea {
                        id: prevMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runCmd("playerctl previous")
                      }
                    }

                    // Play / Pause Toggle Button
                    Rectangle {
                      width: 36
                      height: 36
                      radius: 18
                      color: root.cfgAccent
                      scale: ppMouse.pressed ? 0.92 : 1.0

                      Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "󰏤" : "󰐊"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color: "#ffffff"
                      }

                      MouseArea {
                        id: ppMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runCmd("playerctl play-pause")
                      }
                    }

                    // Next Track Button
                    Rectangle {
                      width: 32
                      height: 32
                      radius: 16
                      color: nextMouse.containsMouse ? Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.35) : root.surfaceFillColor
                      border.color: nextMouse.containsMouse ? root.cfgAccent : root.cardBorderColor
                      border.width: 1
                      scale: nextMouse.pressed ? 0.92 : 1.0

                      Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color: nextMouse.containsMouse ? "#ffffff" : root.cfgAccent
                      }

                      MouseArea {
                        id: nextMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runCmd("playerctl next")
                      }
                    }
                  }
                }

                // CAVA Animated Audio Visualizer Spectrum
                Rectangle {
                  id: visContainer
                  visible: root.modVisualizer
                  width: parent.width
                  height: root.cfgVisHeight
                  color: "transparent"

                  Row {
                    anchors.fill: parent
                    spacing: Math.max(2, (parent.width - (root.cfgVisBars * 14)) / root.cfgVisBars)

                    Repeater {
                      model: root.cfgVisBars

                      Item {
                        required property int index
                        width: 14
                        height: parent.height

                        readonly property real barVal: (root.displayBars && root.displayBars[index]) ? root.displayBars[index] : 0
                        readonly property real peakVal: (root.peakBars && root.peakBars[index]) ? root.peakBars[index] : 0

                        // Spectrum Bar Column
                        Rectangle {
                          anchors.bottom: parent.bottom
                          width: parent.width
                          height: Math.max(3, (barVal / 100.0) * parent.height)
                          radius: 4
                          color: {
                            var ratio = index / Math.max(1, root.cfgVisBars - 1)
                            return Qt.rgba(
                              root.cfgAccent.r * (1 - ratio * 0.2),
                              root.cfgAccent.g * (1 + ratio * 0.3),
                              root.cfgAccent.b * (1 + ratio * 0.5),
                              0.88
                            )
                          }
                        }

                        // Floating Peak Indicator
                        Rectangle {
                          anchors.bottom: parent.bottom
                          anchors.bottomMargin: Math.max(4, (peakVal / 100.0) * parent.height)
                          width: parent.width
                          height: 2
                          radius: 1
                          color: "#ffffff"
                          opacity: 0.85
                        }
                      }
                    }
                  }
                }
              }
            }

            // ==========================================
            // MODULE 3: Hardware Monitor (CPU Temps, Fan Speeds, RAM, GPU)
            // ==========================================
            Rectangle {
              id: sysinfoCard
              visible: root.modSysinfo
              width: parent.width
              height: 48
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: root.cfgBorderWidth

              Row {
                anchors.centerIn: parent
                spacing: 20

                // CPU Load Meter
                Row {
                  visible: root.cfgHwCpuLoad
                  spacing: 8
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: "󰍛 CPU"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  Text {
                    text: root.sysCpuLoad + " load"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#ffffff"
                  }
                }

                // CPU Temperature Meter
                Row {
                  visible: root.cfgHwCpuTemp && root.sysCpuTemp > 0
                  spacing: 8
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: 1
                    height: 18
                    color: root.cardBorderColor
                    visible: root.cfgHwCpuLoad
                  }

                  Text {
                    text: "󰈸 TEMP"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  Text {
                    text: root.displayTemp(root.sysCpuTemp)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.sysCpuTemp >= 80 ? "#ff5555" : (root.sysCpuTemp >= 65 ? "#ffb86c" : "#50fa7b")
                  }
                }

                // Fan Speed Meter
                Row {
                  visible: root.cfgHwFanSpeed && root.sysFanSpeed > 0
                  spacing: 8
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: 1
                    height: 18
                    color: root.cardBorderColor
                    visible: root.cfgHwCpuLoad || (root.cfgHwCpuTemp && root.sysCpuTemp > 0)
                  }

                  Text {
                    text: "󰠝 FAN"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  Text {
                    text: root.sysFanSpeed + " RPM"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#ffffff"
                  }
                }

                // RAM Memory Meter
                Row {
                  visible: root.cfgHwRam
                  spacing: 8
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: 1
                    height: 18
                    color: root.cardBorderColor
                    visible: root.cfgHwCpuLoad || (root.cfgHwCpuTemp && root.sysCpuTemp > 0) || (root.cfgHwFanSpeed && root.sysFanSpeed > 0)
                  }

                  Text {
                    text: "󰘚 RAM"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  // Progress Bar for RAM
                  Rectangle {
                    width: 70
                    height: 8
                    radius: 4
                    color: root.surfaceFillColor
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                      width: Math.max(4, (root.sysRamPercent / 100.0) * parent.width)
                      height: parent.height
                      radius: 4
                      color: root.cfgAccent
                    }
                  }

                  Text {
                    text: root.sysRamUsed + " (" + root.sysRamPercent + "%)"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#ffffff"
                  }
                }

                // GPU Temp Meter (optional)
                Row {
                  visible: root.cfgHwGpuTemp && root.sysGpuTemp > 0
                  spacing: 8
                  anchors.verticalCenter: parent.verticalCenter

                  Rectangle {
                    width: 1
                    height: 18
                    color: root.cardBorderColor
                  }

                  Text {
                    text: "󰢮 GPU"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  Text {
                    text: root.displayTemp(root.sysGpuTemp)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: "#ffffff"
                  }
                }
              }
            }

            // ==========================================
            // MODULE 4: Dynamic Personal Branding & Customizer
            // ==========================================
            Column {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: 8

              Text {
                visible: root.modFooter
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.resolvedUserName + " // WALLPAPER ENGINE"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 6
                color: root.cfgAccent
                opacity: 0.7

                MouseArea {
                  anchors.fill: parent
                  acceptedButtons: Qt.RightButton | Qt.LeftButton
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openGui()
                }
              }

              // Interactive Quick-Customize Button (Can be toggled off)
              Rectangle {
                id: customizeBtn
                visible: root.modCustomizeButton
                anchors.horizontalCenter: parent.horizontalCenter
                width: custRow.implicitWidth + 20
                height: 26
                radius: 13
                color: custMouse.containsMouse ? Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.35) : Qt.rgba(root.cfgAccent.r * 0.05 + 0.05, root.cfgAccent.g * 0.05 + 0.05, root.cfgAccent.b * 0.05 + 0.07, 0.70)
                border.color: custMouse.containsMouse ? root.cfgAccent : root.cardBorderColor
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                  id: custRow
                  anchors.centerIn: parent
                  spacing: 6

                  Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: root.cfgAccent
                  }

                  Text {
                    text: "Customize Widget"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: custMouse.containsMouse ? "#ffffff" : "#c0c0d8"
                  }
                }

                MouseArea {
                  id: custMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.openGui()
                }
              }
            }
          }
        }
      }
    }
  }
}
