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

  property string currentTime: "12:00"
  property string currentAmPm: "PM"
  property string currentDate: ""
  property string weatherText: "Loading weather..."
  property string weatherTemp: "--°"
  property string weatherCity: "Omarchy"
  property string weatherIcon: "󰖐"
  property var rawBars: []
  property var displayBars: []
  property var peakBars: []
  property real idlePhase: 0

  readonly property int barCount: 28

  function updateTime() {
    var d = new Date()
    var formatted = Qt.formatDateTime(d, "h:mm AP")
    var parts = formatted.split(" ")
    currentTime = parts[0]
    currentAmPm = parts.length > 1 ? parts[1] : ""
    currentDate = Qt.formatDateTime(d, "dddd, MMMM d, yyyy")
  }

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

  Component.onCompleted: {
    var b = []
    var p = []
    for (var i = 0; i < barCount; i++) {
      b.push(0)
      p.push(0)
    }
    rawBars = b
    displayBars = b
    peakBars = p
    updateTime()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.updateTime()
  }

  // Smooth 60 FPS animation loop for visualizer physics and idle wave
  Timer {
    interval: 16
    running: true
    repeat: true
    onTriggered: {
      root.idlePhase += 0.05
      var disp = []
      var peaks = []
      var hasAudio = false

      for (var i = 0; i < root.barCount; i++) {
        var raw = (root.rawBars && root.rawBars[i]) ? root.rawBars[i] : 0
        if (raw > 2) hasAudio = true

        var cur = (root.displayBars && root.displayBars[i]) ? root.displayBars[i] : 0
        var target = raw

        // Idle gentle wave if no sound is playing
        if (!hasAudio && !root.isPlaying) {
          target = Math.max(3, Math.sin(root.idlePhase + i * 0.3) * 6 + 8)
        }

        // Smooth spring interpolation
        if (target > cur) {
          cur += (target - cur) * 0.45
        } else {
          cur += (target - cur) * 0.15
        }
        disp.push(cur)

        // Floating peak drop logic
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

  // Process to stream CAVA audio spectrum
  Process {
    id: cavaProc
    command: [
      Quickshell.env("HOME") + "/.local/bin/cava",
      "-p",
      Quickshell.env("HOME") + "/.config/omarchy/plugins/ryguy.wallpaper-engine/cava.conf"
    ]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        var parts = line.trim().split(/\s+/)
        if (parts.length >= root.barCount) {
          var vals = []
          for (var i = 0; i < root.barCount; i++) {
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
    onTriggered: cavaProc.running = true
  }

  // Weather fetch processes
  Process {
    id: weatherProc
    command: ["/usr/share/omarchy/bin/omarchy", "weather", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str.length > 0) {
          root.weatherText = str
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
    interval: 180000 // 3 minutes
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      weatherProc.running = true
      weatherIconProc.running = true
    }
  }

  // Multi-screen LayerShell Window
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

        // Main Centered Wallpaper Engine Hub
        Column {
          anchors.centerIn: parent
          spacing: 22
          width: 720

          // Top Card: Clock, Date, Weather
          Rectangle {
            width: parent.width
            height: 195
            radius: 20
            color: "#0c0c12e0"
            border.color: "#e2007466"
            border.width: 1.5

            // Ambient Magenta Glow behind clock
            Rectangle {
              anchors.centerIn: parent
              width: 360
              height: 100
              radius: 50
              color: "#e20074"
              opacity: 0.08
            }

            Column {
              anchors.centerIn: parent
              spacing: 8
              width: parent.width - 48

              // 12-Hour Time Row
              Row {
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
                  text: root.currentAmPm
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 26
                  font.weight: Font.ExtraBold
                  color: "#e20074"
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: 14
                }
              }

              // Date Row
              Text {
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
                anchors.horizontalCenter: parent.horizontalCenter
                height: 34
                width: weatherRow.implicitWidth + 32
                radius: 17
                color: "#181826ee"
                border.color: "#e200744d"
                border.width: 1

                Row {
                  id: weatherRow
                  anchors.centerIn: parent
                  spacing: 10

                  Text {
                    text: root.weatherIcon
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 18
                    color: "#ff3399"
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
                    color: "#e20074"
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

          // Bottom Card: Now Playing & Audio Visualizer
          Rectangle {
            width: parent.width
            height: 195
            radius: 20
            color: "#0c0c12e0"
            border.color: "#e2007466"
            border.width: 1.5

            Column {
              anchors.centerIn: parent
              spacing: 16
              width: parent.width - 48

              // Now Playing Row
              Row {
                width: parent.width
                spacing: 16

                // Album Art / Music Glyph
                Rectangle {
                  width: 54
                  height: 54
                  radius: 12
                  color: "#181826"
                  border.color: root.isPlaying ? "#e20074" : "#303042"
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
                    color: root.isPlaying ? "#e20074" : "#707088"
                  }
                }

                // Track Info
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

              // Animated Spectrum Visualizer Bars
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                height: 70

                Repeater {
                  model: root.barCount

                  Item {
                    required property int index
                    width: 8
                    height: 70
                    anchors.bottom: parent.bottom

                    readonly property real val: (root.displayBars && root.displayBars[index]) ? root.displayBars[index] : 0
                    readonly property real peak: (root.peakBars && root.peakBars[index]) ? root.peakBars[index] : 0
                    readonly property real barHeight: Math.max(5, (val / 100.0) * 62)
                    readonly property real peakY: 70 - Math.max(6, (peak / 100.0) * 66)

                    // Main Bar with Vibrant Magenta Gradient
                    Rectangle {
                      anchors.bottom: parent.bottom
                      anchors.horizontalCenter: parent.horizontalCenter
                      width: 8
                      height: parent.barHeight
                      radius: 4
                      gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ff4d94" }
                        GradientStop { position: 0.5; color: "#e20074" }
                        GradientStop { position: 1.0; color: "#6e0037" }
                      }
                    }

                    // Floating Peak Dot
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

          // Subtle personal branding footer
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "RYGUY // WALLPAPER ENGINE"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 6
            color: "#e20074"
            opacity: 0.7
          }
        }
      }
    }
  }
}
