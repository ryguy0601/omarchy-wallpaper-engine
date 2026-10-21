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
  property bool modFooter: true

  property bool cfgFormat12h: true
  property bool cfgShowAmPm: true
  property int cfgVisHeight: 70
  property int cfgVisBars: 28
  property bool cfgIdleWave: true

  property color cfgAccent: "#e20074"
  property string cfgCardBg: "#0c0c12"
  property real cfgCardOpacity: 0.90
  property int cfgCardRadius: 20
  property string cfgUserName: "auto"

  readonly property color cardFillColor: Qt.rgba(
    cfgAccent.r * 0.05 + 0.05,
    cfgAccent.g * 0.05 + 0.05,
    cfgAccent.b * 0.05 + 0.07,
    cfgCardOpacity
  )
  readonly property color cardBorderColor: Qt.rgba(cfgAccent.r, cfgAccent.g, cfgAccent.b, 0.40)
  readonly property color surfaceFillColor: Qt.rgba(cfgAccent.r * 0.08 + 0.08, cfgAccent.g * 0.08 + 0.08, cfgAccent.b * 0.08 + 0.12, 0.92)

  readonly property string resolvedUserName: {
    if (root.cfgUserName && root.cfgUserName !== "auto") return root.cfgUserName
    var envUser = Quickshell.env("USER") || "USER"
    return envUser.toUpperCase()
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
        if (typeof d.modules.footer === "boolean") root.modFooter = d.modules.footer
      }
      if (d.clock) {
        if (typeof d.clock.format12h === "boolean") root.cfgFormat12h = d.clock.format12h
        if (typeof d.clock.showAmPm === "boolean") root.cfgShowAmPm = d.clock.showAmPm
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
        if (d.style.userName) root.cfgUserName = d.style.userName
      }
      root.updateTime()
    } catch (e) {
      console.warn("WallpaperEngine: Error parsing config:", e)
    }
  }

  // Time & Date State
  property string currentTime: "12:00"
  property string currentAmPm: "PM"
  property string currentDate: ""

  function updateTime() {
    var d = new Date()
    var hours = d.getHours()
    var minutes = d.getMinutes()
    var minutesStr = minutes < 10 ? ("0" + minutes) : minutes

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

  // System Stats (CPU & RAM) State
  property string sysCpuLoad: "0.0"
  property string sysRamUsed: "0G"
  property string sysRamTotal: "0G"
  property int sysRamPercent: 0

  Process {
    id: sysinfoProc
    command: [
      "sh", "-c",
      "awk '{printf \"%.1f\", $1}' /proc/loadavg; echo; free -h | awk '/Mem:/ {print $3, $2}'; free -m | awk '/Mem:/ {printf \"%d\", int($3*100/$2)}'"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        if (lines.length >= 3) {
          root.sysCpuLoad = lines[0].trim()
          var memParts = lines[1].trim().split(/\s+/)
          if (memParts.length >= 2) {
            root.sysRamUsed = memParts[0]
            root.sysRamTotal = memParts[1]
          }
          root.sysRamPercent = Math.min(100, Math.max(0, parseInt(lines[2]) || 0))
        }
      }
    }
  }

  Timer {
    interval: 3000
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
      mask: Region {}

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
              border.width: 1.5

              Rectangle {
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
                  spacing: 12

                  Text {
                    text: root.currentTime
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 76
                    font.weight: Font.Bold
                    color: "#ffffff"
                  }

                  Text {
                    visible: root.cfgShowAmPm && root.currentAmPm !== ""
                    text: root.currentAmPm
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 26
                    font.weight: Font.ExtraBold
                    color: root.cfgAccent
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
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
                  height: 34
                  width: weatherRow.implicitWidth + 32
                  radius: 17
                  color: root.surfaceFillColor
                  border.color: root.cardBorderColor
                  border.width: 1

                  Row {
                    id: weatherRow
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                      text: root.weatherIcon
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 18
                      color: root.cfgAccent
                    }

                    Text {
                      text: root.weatherTemp
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 14
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }

                    Text {
                      text: "•"
                      font.pixelSize: 12
                      color: root.cfgAccent
                    }

                    Text {
                      text: root.weatherCity
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 13
                      font.weight: Font.Medium
                      color: "#b0b0cb"
                    }
                  }
                }
              }
            }

            // ==========================================
            // MODULE 2: Now Playing & Audio Visualizer
            // ==========================================
            Rectangle {
              id: mediaCard
              visible: root.modMedia || root.modVisualizer
              width: parent.width
              height: mediaCol.implicitHeight + 36
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: 1.5

              Column {
                id: mediaCol
                anchors.centerIn: parent
                spacing: 16
                width: parent.width - 48

                // Track Info Row
                Row {
                  visible: root.modMedia
                  width: parent.width
                  spacing: 16

                  // Album Art / Music Glyph
                  Rectangle {
                    width: 54
                    height: 54
                    radius: 12
                    color: root.surfaceFillColor
                    border.color: root.isPlaying ? root.cfgAccent : "#303042"
                    border.width: 1.5
                    clip: true

                    Image {
                      anchors.fill: parent
                      source: root.trackArt
                      fillMode: Image.PreserveAspectCrop
                      visible: root.trackArt !== ""
                    }

                    Text {
                      anchors.centerIn: parent
                      visible: root.trackArt === ""
                      text: root.isPlaying ? "󰎆" : ""
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 26
                      color: root.isPlaying ? root.cfgAccent : "#707088"
                    }
                  }

                  // Track Text Column
                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 70
                    spacing: 4

                    Row {
                      spacing: 8
                      Text {
                        text: root.isPlaying ? "󰐊 PLAYING" : "󰏤 IDLE"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        color: root.isPlaying ? "#00e676" : "#ffb347"
                      }
                    }

                    Text {
                      text: root.trackTitle
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 16
                      font.weight: Font.Bold
                      color: "#ffffff"
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: root.trackArtist + (root.trackAlbum ? (" · " + root.trackAlbum) : "")
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      color: "#b0b0cb"
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }
                }

                // Audio Spectrum Visualizer
                Row {
                  visible: root.modVisualizer
                  anchors.horizontalCenter: parent.horizontalCenter
                  spacing: 6
                  height: root.cfgVisHeight

                  Repeater {
                    model: root.cfgVisBars

                    Item {
                      required property int index
                      width: 8
                      height: root.cfgVisHeight
                      anchors.bottom: parent.bottom

                      readonly property real val: (root.displayBars && root.displayBars[index]) ? root.displayBars[index] : 0
                      readonly property real peak: (root.peakBars && root.peakBars[index]) ? root.peakBars[index] : 0
                      readonly property real barHeight: Math.max(5, (val / 100.0) * (root.cfgVisHeight - 8))
                      readonly property real peakY: root.cfgVisHeight - Math.max(6, (peak / 100.0) * (root.cfgVisHeight - 4))

                      Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 8
                        height: parent.barHeight
                        radius: 4
                        gradient: Gradient {
                          GradientStop { position: 0.0; color: "#ff4d94" }
                          GradientStop { position: 0.5; color: root.cfgAccent }
                          GradientStop { position: 1.0; color: "#550026" }
                        }
                      }

                      Rectangle {
                        y: parent.peakY
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 8
                        height: 3
                        radius: 1.5
                        color: "#ffffff"
                        opacity: parent.val > 5 ? 1.0 : 0.4
                      }
                    }
                  }
                }
              }
            }

            // ==========================================
            // MODULE 3: System Stats (CPU & RAM)
            // ==========================================
            Rectangle {
              id: sysinfoCard
              visible: root.modSysinfo
              width: parent.width
              height: 52
              radius: root.cfgCardRadius
              color: root.cardFillColor
              border.color: root.cardBorderColor
              border.width: 1.5

              Row {
                anchors.centerIn: parent
                spacing: 36

                // CPU Load Meter
                Row {
                  spacing: 12
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: "󰍛 CPU"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  Text {
                    text: root.sysCpuLoad + " load"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color: "#ffffff"
                  }
                }

                // Vertical Divider
                Rectangle {
                  width: 1
                  height: 22
                  color: root.cardBorderColor
                  anchors.verticalCenter: parent.verticalCenter
                }

                // RAM Memory Meter
                Row {
                  spacing: 12
                  anchors.verticalCenter: parent.verticalCenter

                  Text {
                    text: "󰘚 RAM"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: root.cfgAccent
                  }

                  // Progress Bar for RAM
                  Rectangle {
                    width: 100
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
                    font.pixelSize: 13
                    color: "#ffffff"
                  }
                }
              }
            }

            // ==========================================
            // MODULE 4: Dynamic Personal Branding Footer
            // ==========================================
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
            }
          }
        }
      }
    }
  }
}
