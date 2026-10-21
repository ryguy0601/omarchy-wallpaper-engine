import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
  id: win
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.namespace: "wallpaper-engine-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

  // Live Configuration State
  property string currentPos: "center"
  property int customX: 100
  property int customY: 100
  property int currentWidth: 720
  property int currentSpacing: 22

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

  property bool cfg12h: true
  property bool cfgShowAmPm: true
  property bool cfgShowSeconds: false
  property int cfgClockSize: 76

  property string quoteText: "The best way to predict the future is to invent it."
  property string quoteAuthor: "Alan Kay"

  property int visHeight: 70
  property int visBars: 28
  property bool visIdleWave: true

  property color accentColor: "#e20074"
  property string cardBg: "#0c0c12"
  property real cardOpacity: 0.85
  property int cardRadius: 20
  property bool borderGlow: true
  property real borderWidth: 1.5
  property string userName: "auto"
  property bool autoRestartShell: false

  // Hardware Telemetry Config
  property bool hwCpuLoad: true
  property bool hwCpuTemp: true
  property bool hwFanSpeed: true
  property bool hwRam: true
  property bool hwGpuTemp: false
  property string hwTempUnit: "C"

  // Live Telemetry Cache
  property var liveHw: ({
    cpuLoad: "0.0",
    ramUsed: "0G",
    ramTotal: "0G",
    ramPercent: 0,
    cpuTemp: 0,
    fanSpeed: 0,
    gpuTemp: 0
  })

  // Customizable Shortcuts List
  property var shortcutsList: [
    { icon: "󰈹", label: "Browser", cmd: "omarchy-cmd-default-browser || xdg-open https://google.com" },
    { icon: "󰆍", label: "Terminal", cmd: "omarchy-default-terminal || foot" },
    { icon: "󰉋", label: "Files", cmd: "thunar || omarchy-file-select" },
    { icon: "󰨞", label: "Editor", cmd: "omarchy-default-editor || code || foot -e nvim" },
    { icon: "󰎆", label: "Music", cmd: "playerctl play-pause 2>/dev/null || true" },
    { icon: "", label: "Settings", cmd: "wallpaper-engine gui" }
  ]

  property string statusNotice: ""
  property int activeTab: 0 // 0: Layout, 1: Modules, 2: Apps & Dock, 3: Hardware, 4: Colors, 5: Visualizer, 6: Wallpapers

  readonly property color bgDark: "#0c0c12"
  readonly property color bgCard: Qt.rgba(accentColor.r * 0.06 + 0.07, accentColor.g * 0.06 + 0.07, accentColor.b * 0.06 + 0.09, 0.95)
  readonly property color bgInput: Qt.rgba(accentColor.r * 0.08 + 0.10, accentColor.g * 0.08 + 0.10, accentColor.b * 0.08 + 0.14, 0.95)
  readonly property color borderActive: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.65)
  readonly property color borderMuted: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)

  function formatTemp(tempC) {
    if (!tempC || tempC <= 0) return "--°"
    if (win.hwTempUnit === "F") {
      return Math.round(tempC * 9.0 / 5.0 + 32) + "°F"
    }
    return tempC + "°C"
  }

  // Live Hardware Telemetry Poller
  Process {
    id: hwPollerProc
    command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "hwinfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var str = String(text || "").trim()
          if (str.length > 0) {
            win.liveHw = JSON.parse(str)
          }
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: hwPollerProc.running = true
  }

  // Config Reader
  FileView {
    id: configFileView
    path: Quickshell.env("HOME") + "/.config/wallpaper-engine/config.json"
    watchChanges: true
    printErrors: false
    onLoaded: win.loadConfig(text())
  }

  function loadConfig(jsonText) {
    try {
      var d = JSON.parse(jsonText)
      if (d.layout) {
        if (d.layout.position) win.currentPos = String(d.layout.position).toLowerCase()
        if (typeof d.layout.customX === "number") win.customX = d.layout.customX
        if (typeof d.layout.customY === "number") win.customY = d.layout.customY
        if (typeof d.layout.width === "number") win.currentWidth = d.layout.width
        if (typeof d.layout.spacing === "number") win.currentSpacing = d.layout.spacing
      }
      if (d.modules) {
        if (typeof d.modules.clock === "boolean") win.modClock = d.modules.clock
        if (typeof d.modules.date === "boolean") win.modDate = d.modules.date
        if (typeof d.modules.weather === "boolean") win.modWeather = d.modules.weather
        if (typeof d.modules.media === "boolean") win.modMedia = d.modules.media
        if (typeof d.modules.visualizer === "boolean") win.modVisualizer = d.modules.visualizer
        if (typeof d.modules.sysinfo === "boolean") win.modSysinfo = d.modules.sysinfo
        if (typeof d.modules.shortcuts === "boolean") win.modShortcuts = d.modules.shortcuts
        if (typeof d.modules.quote === "boolean") win.modQuote = d.modules.quote
        if (typeof d.modules.footer === "boolean") win.modFooter = d.modules.footer
        if (typeof d.modules.customizeButton === "boolean") win.modCustomizeButton = d.modules.customizeButton
        else if (typeof d.style === "object" && typeof d.style.showCustomizeButton === "boolean") win.modCustomizeButton = d.style.showCustomizeButton
      }
      if (d.clock) {
        if (typeof d.clock.format12h === "boolean") win.cfg12h = d.clock.format12h
        if (typeof d.clock.showAmPm === "boolean") win.cfgShowAmPm = d.clock.showAmPm
        if (typeof d.clock.showSeconds === "boolean") win.cfgShowSeconds = d.clock.showSeconds
        if (typeof d.clock.fontSize === "number") win.cfgClockSize = d.clock.fontSize
      }
      if (d.hardware) {
        if (typeof d.hardware.showCpuLoad === "boolean") win.hwCpuLoad = d.hardware.showCpuLoad
        if (typeof d.hardware.showCpuTemp === "boolean") win.hwCpuTemp = d.hardware.showCpuTemp
        if (typeof d.hardware.showFanSpeed === "boolean") win.hwFanSpeed = d.hardware.showFanSpeed
        if (typeof d.hardware.showRam === "boolean") win.hwRam = d.hardware.showRam
        if (typeof d.hardware.showGpuTemp === "boolean") win.hwGpuTemp = d.hardware.showGpuTemp
        if (typeof d.hardware.tempUnit === "string") win.hwTempUnit = d.hardware.tempUnit.toUpperCase()
      }
      if (Array.isArray(d.shortcuts) && d.shortcuts.length > 0) {
        win.shortcutsList = d.shortcuts
      }
      if (d.quote) {
        if (typeof d.quote.text === "string") win.quoteText = d.quote.text
        if (typeof d.quote.author === "string") win.quoteAuthor = d.quote.author
      }
      if (d.visualizer) {
        if (typeof d.visualizer.height === "number") win.visHeight = d.visualizer.height
        if (typeof d.visualizer.bars === "number") win.visBars = d.visualizer.bars
        if (typeof d.visualizer.idleWave === "boolean") win.visIdleWave = d.visualizer.idleWave
      }
      if (d.style) {
        if (d.style.accentColor) win.accentColor = d.style.accentColor
        if (d.style.cardBackground) win.cardBg = d.style.cardBackground
        if (typeof d.style.cardOpacity === "number") win.cardOpacity = d.style.cardOpacity
        if (typeof d.style.cardRadius === "number") win.cardRadius = d.style.cardRadius
        if (typeof d.style.borderGlow === "boolean") win.borderGlow = d.style.borderGlow
        if (typeof d.style.borderWidth === "number") win.borderWidth = d.style.borderWidth
        if (typeof d.style.autoRestartShell === "boolean") win.autoRestartShell = d.style.autoRestartShell
        if (d.style.userName) win.userName = d.style.userName
      }
    } catch (e) {
      console.warn("SettingsWindow: Error parsing config:", e)
    }
  }

  // Config Writer
  function saveCurrentConfig(andRestart) {
    var d = {
      "layout": {
        "position": win.currentPos,
        "customX": win.customX,
        "customY": win.customY,
        "width": win.currentWidth,
        "spacing": win.currentSpacing
      },
      "modules": {
        "clock": win.modClock,
        "date": win.modDate,
        "weather": win.modWeather,
        "media": win.modMedia,
        "visualizer": win.modVisualizer,
        "sysinfo": win.modSysinfo,
        "shortcuts": win.modShortcuts,
        "quote": win.modQuote,
        "footer": win.modFooter,
        "customizeButton": win.modCustomizeButton
      },
      "clock": {
        "format12h": win.cfg12h,
        "showAmPm": win.cfgShowAmPm,
        "showSeconds": win.cfgShowSeconds,
        "fontSize": win.cfgClockSize
      },
      "hardware": {
        "showCpuLoad": win.hwCpuLoad,
        "showCpuTemp": win.hwCpuTemp,
        "showFanSpeed": win.hwFanSpeed,
        "showRam": win.hwRam,
        "showGpuTemp": win.hwGpuTemp,
        "tempUnit": win.hwTempUnit
      },
      "shortcuts": win.shortcutsList,
      "quote": {
        "text": win.quoteText,
        "author": win.quoteAuthor
      },
      "visualizer": {
        "height": win.visHeight,
        "bars": win.visBars,
        "idleWave": win.visIdleWave
      },
      "style": {
        "accentColor": win.accentColor.toString(),
        "cardBackground": win.cardBg,
        "cardOpacity": win.cardOpacity,
        "cardRadius": win.cardRadius,
        "borderGlow": win.borderGlow,
        "borderWidth": win.borderWidth,
        "autoRestartShell": win.autoRestartShell,
        "userName": win.userName
      }
    }

    var cmd = [
      Quickshell.env("HOME") + "/.local/bin/wallpaper-engine",
      "apply-json",
      JSON.stringify(d, null, 2)
    ]
    if (andRestart) cmd.push("--restart")
    Quickshell.execDetached(cmd)

    win.statusNotice = andRestart ? "Restarting shell..." : "Synced Live"
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 2500
    onTriggered: win.statusNotice = ""
  }

  // Dim Backdrop
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.65)

    MouseArea {
      anchors.fill: parent
      onClicked: {
        if (win.autoRestartShell) Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy", "restart", "shell"])
        Qt.quit()
      }
    }
  }

  // Centered Modal Dialog Card
  Rectangle {
    id: dialogCard
    anchors.centerIn: parent
    width: Math.min(940, parent.width - 40)
    height: Math.min(680, parent.height - 40)
    color: win.bgDark
    border.color: win.borderActive
    border.width: 1.5
    radius: 14
    clip: true

    MouseArea {
      anchors.fill: parent
      // Intercept clicks so backdrop click doesn't close modal accidentally
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 12

      // ==========================================
      // HEADER BAR
      // ==========================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
          width: 36
          height: 36
          radius: 18
          color: Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.2)
          border.color: win.accentColor
          border.width: 1.5

          Text {
            anchors.centerIn: parent
            text: ""
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: win.accentColor
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            text: "WALLPAPER ENGINE // CONTROL CENTER"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            font.weight: Font.Bold
            color: "#ffffff"
            font.letterSpacing: 1.5
          }
          Text {
            text: "Interactive Desktop Customizer & Hardware Monitor"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: "#8e8ea8"
          }
        }

        // Live status pill
        Rectangle {
          visible: win.statusNotice !== ""
          height: 26
          radius: 13
          color: Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.3)
          border.color: win.accentColor
          border.width: 1
          implicitWidth: statusText.implicitWidth + 20

          Text {
            id: statusText
            anchors.centerIn: parent
            text: win.statusNotice
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: "#ffffff"
          }
        }

        // Restart Shell Header Button
        PillButton {
          label: "󰑓 Restart Shell"
          active: true
          accentColor: win.accentColor
          onClicked: win.saveCurrentConfig(true)
        }

        // Close button
        Rectangle {
          width: 30
          height: 30
          radius: 15
          color: closeMouse.containsMouse ? Qt.rgba(1, 0.2, 0.3, 0.4) : win.bgInput
          border.color: closeMouse.containsMouse ? "#ff4466" : win.borderMuted
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: closeMouse.containsMouse ? "#ffffff" : "#a0a0b8"
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (win.autoRestartShell) Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy", "restart", "shell"])
              Qt.quit()
            }
          }
        }
      }

      // ==========================================
      // TAB BAR (7 Comprehensive Tabs)
      // ==========================================
      RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
          model: [
            { icon: "󰉉", label: "Layout", idx: 0 },
            { icon: "󰄬", label: "Modules", idx: 1 },
            { icon: "󰈹", label: "Apps & Dock", idx: 2 },
            { icon: "󰍛", label: "Hardware", idx: 3 },
            { icon: "󰏘", label: "Colors", idx: 4 },
            { icon: "󰓃", label: "Visualizer", idx: 5 },
            { icon: "󰋩", label: "Wallpapers", idx: 6 }
          ]

          Rectangle {
            required property var modelData
            Layout.fillWidth: true
            height: 34
            radius: 8
            color: win.activeTab === modelData.idx ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.30) : win.bgInput
            border.color: win.activeTab === modelData.idx ? win.accentColor : win.borderMuted
            border.width: win.activeTab === modelData.idx ? 1.5 : 1

            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
              anchors.centerIn: parent
              spacing: 6
              Text {
                text: modelData.icon
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: win.activeTab === modelData.idx ? win.accentColor : "#b0b0c8"
              }
              Text {
                text: modelData.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: win.activeTab === modelData.idx ? Font.Bold : Font.Medium
                color: win.activeTab === modelData.idx ? "#ffffff" : "#b0b0c8"
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: win.activeTab = modelData.idx
            }
          }
        }
      }

      // Divider
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: win.borderMuted
      }

      // ==========================================
      // TAB CONTENT PAGES
      // ==========================================
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // ------------------------------------------
        // TAB 0: Position & Layout
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 0

          ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
              text: "SELECT WIDGET DESKTOP POSITION"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            // 7-Slot Screen Position Matrix
            Rectangle {
              Layout.fillWidth: true
              height: 165
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Top Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  PositionButton {
                    posId: "top-left"
                    label: "↖ Top-Left"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "top-left"; win.saveCurrentConfig(false) }
                  }
                  PositionButton {
                    posId: "top-center"
                    label: "↑ Top-Center"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "top-center"; win.saveCurrentConfig(false) }
                  }
                  PositionButton {
                    posId: "top-right"
                    label: "↗ Top-Right"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "top-right"; win.saveCurrentConfig(false) }
                  }
                }

                // Center Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  PositionButton {
                    posId: "center"
                    label: "⊙ Center Screen"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "center"; win.saveCurrentConfig(false) }
                  }
                  PositionButton {
                    posId: "custom"
                    label: "󰆾 Custom Pixel Coords"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "custom"; win.saveCurrentConfig(false) }
                  }
                }

                // Bottom Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 8
                  PositionButton {
                    posId: "bottom-left"
                    label: "↙ Bottom-Left"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "bottom-left"; win.saveCurrentConfig(false) }
                  }
                  PositionButton {
                    posId: "bottom-center"
                    label: "↓ Bottom-Center"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "bottom-center"; win.saveCurrentConfig(false) }
                  }
                  PositionButton {
                    posId: "bottom-right"
                    label: "↘ Bottom-Right"
                    currentPos: win.currentPos
                    onSelected: { win.currentPos = "bottom-right"; win.saveCurrentConfig(false) }
                  }
                }
              }
            }

            // Custom Coordinates Panel
            Rectangle {
              Layout.fillWidth: true
              height: 48
              radius: 10
              color: win.bgCard
              border.color: win.currentPos === "custom" ? win.accentColor : win.borderMuted
              border.width: win.currentPos === "custom" ? 1.5 : 1
              visible: win.currentPos === "custom"

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 16

                Text {
                  text: "Custom Coordinates:"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: "#ffffff"
                }

                Text { text: "X (px):"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0" }
                Rectangle {
                  width: 90
                  height: 28
                  radius: 6
                  color: win.bgInput
                  border.color: win.borderMuted
                  border.width: 1
                  TextInput {
                    anchors.fill: parent
                    anchors.margins: 5
                    text: String(win.customX)
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    validator: IntValidator { bottom: 0; top: 7680 }
                    onEditingFinished: { win.customX = parseInt(text) || 0; win.saveCurrentConfig(false) }
                  }
                }

                Text { text: "Y (px):"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0" }
                Rectangle {
                  width: 90
                  height: 28
                  radius: 6
                  color: win.bgInput
                  border.color: win.borderMuted
                  border.width: 1
                  TextInput {
                    anchors.fill: parent
                    anchors.margins: 5
                    text: String(win.customY)
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    validator: IntValidator { bottom: 0; top: 4320 }
                    onEditingFinished: { win.customY = parseInt(text) || 0; win.saveCurrentConfig(false) }
                  }
                }

                Item { Layout.fillWidth: true }
              }
            }

            // Size & Spacing Controls
            Rectangle {
              Layout.fillWidth: true
              height: 110
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Width Slider
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "Card Width:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 100
                  }

                  ModernSlider {
                    from: 520
                    to: 960
                    stepSize: 10
                    value: win.currentWidth
                    onMoved: function(v) {
                      win.currentWidth = Math.round(v)
                      win.saveCurrentConfig(false)
                    }
                  }

                  Text {
                    text: win.currentWidth + " px"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: win.accentColor
                    Layout.preferredWidth: 60
                  }
                }

                // Spacing Slider
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "Card Spacing:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 100
                  }

                  ModernSlider {
                    from: 10
                    to: 36
                    stepSize: 2
                    value: win.currentSpacing
                    onMoved: function(v) {
                      win.currentSpacing = Math.round(v)
                      win.saveCurrentConfig(false)
                    }
                  }

                  Text {
                    text: win.currentSpacing + " px"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: win.accentColor
                    Layout.preferredWidth: 60
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }
        }

        // ------------------------------------------
        // TAB 1: Widgets & Modules (Includes Customize Button Toggle!)
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 1

          Flickable {
            id: moduleFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: modCol.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: moduleFlick
              onWheel: function(event) {
                moduleFlick.contentY = Math.max(0, Math.min(moduleFlick.contentHeight - moduleFlick.height, moduleFlick.contentY - event.angleDelta.y))
              }
            }

            ColumnLayout {
              id: modCol
              width: parent.width - 16
              spacing: 8

              Text {
                text: "TOGGLE ACTIVE DESKTOP WIDGETS"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: win.accentColor
                font.letterSpacing: 1
              }

              // Clock Card
              ModuleToggleCard {
                icon: "󱑂"
                title: "Digital Clock"
                subtitle: "Bold 12h or 24h clock with second updates"
                checked: win.modClock
                accentColor: win.accentColor
                onToggled: { win.modClock = !win.modClock; win.saveCurrentConfig(false) }

                extraContent: ColumnLayout {
                  spacing: 8
                  RowLayout {
                    spacing: 10
                    Text { text: "Format:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0" }
                    PillButton {
                      label: "12-Hour"
                      active: win.cfg12h
                      accentColor: win.accentColor
                      onClicked: { win.cfg12h = true; win.saveCurrentConfig(false) }
                    }
                    PillButton {
                      label: "24-Hour"
                      active: !win.cfg12h
                      accentColor: win.accentColor
                      onClicked: { win.cfg12h = false; win.saveCurrentConfig(false) }
                    }
                    Item { width: 8 }
                    PillButton {
                      label: "Show AM/PM"
                      active: win.cfgShowAmPm
                      accentColor: win.accentColor
                      onClicked: { win.cfgShowAmPm = !win.cfgShowAmPm; win.saveCurrentConfig(false) }
                    }
                    PillButton {
                      label: "Running Seconds (:SS)"
                      active: win.cfgShowSeconds
                      accentColor: win.accentColor
                      onClicked: { win.cfgShowSeconds = !win.cfgShowSeconds; win.saveCurrentConfig(false) }
                    }
                  }

                  RowLayout {
                    spacing: 12
                    Text { text: "Font Size:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0"; Layout.preferredWidth: 70 }
                    ModernSlider {
                      from: 48
                      to: 110
                      stepSize: 4
                      value: win.cfgClockSize
                      onMoved: function(v) { win.cfgClockSize = Math.round(v); win.saveCurrentConfig(false) }
                    }
                    Text { text: win.cfgClockSize + " px"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold; color: win.accentColor; Layout.preferredWidth: 50 }
                  }
                }
              }

              // Customize Widget Button Pill Toggle (USER REQUESTED)
              ModuleToggleCard {
                icon: ""
                title: "Customize Widget Pill Button"
                subtitle: "Show or hide the '[  Customize Widget ]' pill on the desktop widget card"
                checked: win.modCustomizeButton
                accentColor: win.accentColor
                onToggled: { win.modCustomizeButton = !win.modCustomizeButton; win.saveCurrentConfig(false) }

                extraContent: RowLayout {
                  spacing: 10
                  Text {
                    text: "󰋼 Tip: When hidden, you can open settings anytime via the Shortcuts Dock  icon, app launcher, or right-clicking the widget."
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#9090b8"
                    Layout.fillWidth: true
                  }
                }
              }

              // Shortcuts Dock Card
              ModuleToggleCard {
                icon: "󰈹"
                title: "Quick-Launch Shortcuts Dock"
                subtitle: "Interactive desktop launcher bar (switch to 'Apps & Dock' tab to customize buttons)"
                checked: win.modShortcuts
                accentColor: win.accentColor
                onToggled: { win.modShortcuts = !win.modShortcuts; win.saveCurrentConfig(false) }
              }

              // System Stats Card
              ModuleToggleCard {
                icon: "󰍛"
                title: "System Hardware & Stats Monitor"
                subtitle: "Real-time CPU load, temperatures, fan speeds, and RAM memory gauge"
                checked: win.modSysinfo
                accentColor: win.accentColor
                onToggled: { win.modSysinfo = !win.modSysinfo; win.saveCurrentConfig(false) }
              }

              // Media Player Card
              ModuleToggleCard {
                icon: "󰎆"
                title: "Now Playing Media Player"
                subtitle: "MPRIS track info, artist name, interactive play/pause/skip buttons, and album art"
                checked: win.modMedia
                accentColor: win.accentColor
                onToggled: { win.modMedia = !win.modMedia; win.saveCurrentConfig(false) }
              }

              // Audio Visualizer Card
              ModuleToggleCard {
                icon: "󰓃"
                title: "Audio Spectrum Visualizer"
                subtitle: "Animated CAVA 60 FPS spectrum bars with floating peak physics"
                checked: win.modVisualizer
                accentColor: win.accentColor
                onToggled: { win.modVisualizer = !win.modVisualizer; win.saveCurrentConfig(false) }
              }

              // Date Card
              ModuleToggleCard {
                icon: "󰸗"
                title: "Date & Calendar Display"
                subtitle: "Weekday, month, day, and year formatted in clean monospace"
                checked: win.modDate
                accentColor: win.accentColor
                onToggled: { win.modDate = !win.modDate; win.saveCurrentConfig(false) }
              }

              // Weather Card
              ModuleToggleCard {
                icon: "󰖐"
                title: "Live Weather Pill"
                subtitle: "Real-time local temperature and weather condition glyph"
                checked: win.modWeather
                accentColor: win.accentColor
                onToggled: { win.modWeather = !win.modWeather; win.saveCurrentConfig(false) }
              }

              // Quote Card
              ModuleToggleCard {
                icon: "󰝗"
                title: "Inspirational Quote / Daily Banner"
                subtitle: "Display a custom quote, motivation message, or daily focus reminder"
                checked: win.modQuote
                accentColor: win.accentColor
                onToggled: { win.modQuote = !win.modQuote; win.saveCurrentConfig(false) }

                extraContent: ColumnLayout {
                  spacing: 6
                  RowLayout {
                    spacing: 10
                    Text { text: "Quote Text:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0"; Layout.preferredWidth: 80 }
                    Rectangle {
                      Layout.fillWidth: true
                      height: 28
                      radius: 6
                      color: win.bgInput
                      border.color: win.borderMuted
                      border.width: 1
                      TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        text: win.quoteText
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        onEditingFinished: { win.quoteText = text; win.saveCurrentConfig(false) }
                      }
                    }
                  }
                  RowLayout {
                    spacing: 10
                    Text { text: "Author / Tag:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: "#a0a0c0"; Layout.preferredWidth: 80 }
                    Rectangle {
                      Layout.fillWidth: true
                      height: 28
                      radius: 6
                      color: win.bgInput
                      border.color: win.borderMuted
                      border.width: 1
                      TextInput {
                        anchors.fill: parent
                        anchors.margins: 5
                        text: win.quoteAuthor
                        color: "#ffffff"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        onEditingFinished: { win.quoteAuthor = text; win.saveCurrentConfig(false) }
                      }
                    }
                  }
                }
              }

              // Footer Card
              ModuleToggleCard {
                icon: "󰮈"
                title: "Personal Branding Footer"
                subtitle: "Custom user label or automatic $USER branding tag"
                checked: win.modFooter
                accentColor: win.accentColor
                onToggled: { win.modFooter = !win.modFooter; win.saveCurrentConfig(false) }

                extraContent: RowLayout {
                  spacing: 10
                  Text {
                    text: "Display Name:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#a0a0c0"
                  }
                  Rectangle {
                    width: 160
                    height: 28
                    radius: 6
                    color: win.bgInput
                    border.color: win.borderMuted
                    border.width: 1

                    TextInput {
                      anchors.fill: parent
                      anchors.margins: 5
                      text: win.userName
                      color: "#ffffff"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      onEditingFinished: {
                        win.userName = text.trim() === "" ? "auto" : text.trim()
                        win.saveCurrentConfig(false)
                      }
                    }
                  }
                  PillButton {
                    label: "Use $USER (Auto)"
                    active: win.userName === "auto"
                    accentColor: win.accentColor
                    onClicked: { win.userName = "auto"; win.saveCurrentConfig(false) }
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------
        // TAB 2: Apps & Dock Customizer (USER REQUESTED)
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 2

          Flickable {
            id: dockFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: dockCol.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: dockFlick
              onWheel: function(event) {
                dockFlick.contentY = Math.max(0, Math.min(dockFlick.contentHeight - dockFlick.height, dockFlick.contentY - event.angleDelta.y))
              }
            }

            ColumnLayout {
              id: dockCol
              width: parent.width - 16
              spacing: 12

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "CUSTOMIZE SHORTCUTS DOCK APPLICATIONS"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 12
                  font.weight: Font.Bold
                  color: win.accentColor
                  font.letterSpacing: 1
                }
                Item { Layout.fillWidth: true }
                PillButton {
                  label: "↺ Reset Default Apps"
                  active: false
                  accentColor: win.accentColor
                  onClicked: {
                    win.shortcutsList = [
                      { icon: "󰈹", label: "Browser", cmd: "omarchy-cmd-default-browser || xdg-open https://google.com" },
                      { icon: "󰆍", label: "Terminal", cmd: "omarchy-default-terminal || foot" },
                      { icon: "󰉋", label: "Files", cmd: "thunar || omarchy-file-select" },
                      { icon: "󰨞", label: "Editor", cmd: "omarchy-default-editor || code || foot -e nvim" },
                      { icon: "󰎆", label: "Music", cmd: "playerctl play-pause 2>/dev/null || true" },
                      { icon: "", label: "Settings", cmd: "wallpaper-engine gui" }
                    ]
                    win.saveCurrentConfig(false)
                    win.statusNotice = "Reset apps to defaults"
                  }
                }
              }

              // Configured Apps List
              Repeater {
                model: win.shortcutsList

                Rectangle {
                  id: scRowItem
                  required property int index
                  required property var modelData
                  Layout.fillWidth: true
                  height: 52
                  radius: 8
                  color: win.bgCard
                  border.color: win.borderMuted
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Icon preview & field
                    Rectangle {
                      width: 36
                      height: 36
                      radius: 18
                      color: win.bgInput
                      border.color: win.accentColor
                      border.width: 1

                      TextInput {
                        anchors.centerIn: parent
                        text: scRowItem.modelData.icon || "󰈹"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                        color: win.accentColor
                        onEditingFinished: {
                          var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                          arr[scRowItem.index].icon = text.trim()
                          win.shortcutsList = arr
                          win.saveCurrentConfig(false)
                        }
                      }
                    }

                    // Label input
                    ColumnLayout {
                      Layout.preferredWidth: 120
                      spacing: 1
                      Text { text: "App Label:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: "#8080a0" }
                      Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 5
                        color: win.bgInput
                        border.color: win.borderMuted
                        border.width: 1
                        TextInput {
                          anchors.fill: parent
                          anchors.margins: 4
                          text: scRowItem.modelData.label || ""
                          font.family: "JetBrainsMono Nerd Font"
                          font.pixelSize: 11
                          font.weight: Font.Bold
                          color: "#ffffff"
                          onEditingFinished: {
                            var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                            arr[scRowItem.index].label = text.trim()
                            win.shortcutsList = arr
                            win.saveCurrentConfig(false)
                          }
                        }
                      }
                    }

                    // Command input
                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1
                      Text { text: "Launch Command:"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: "#8080a0" }
                      Rectangle {
                        Layout.fillWidth: true
                        height: 24
                        radius: 5
                        color: win.bgInput
                        border.color: win.borderMuted
                        border.width: 1
                        TextInput {
                          anchors.fill: parent
                          anchors.margins: 4
                          text: scRowItem.modelData.cmd || ""
                          font.family: "JetBrainsMono Nerd Font"
                          font.pixelSize: 11
                          color: "#d0d0f0"
                          onEditingFinished: {
                            var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                            arr[scRowItem.index].cmd = text.trim()
                            win.shortcutsList = arr
                            win.saveCurrentConfig(false)
                          }
                        }
                      }
                    }

                    // Move Up
                    Rectangle {
                      width: 28
                      height: 28
                      radius: 6
                      color: upM.containsMouse ? win.bgInput : "transparent"
                      border.color: win.borderMuted
                      border.width: 1
                      visible: scRowItem.index > 0
                      Text { anchors.centerIn: parent; text: "󰜮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#ffffff" }
                      MouseArea {
                        id: upM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                          var item = arr.splice(scRowItem.index, 1)[0]
                          arr.splice(scRowItem.index - 1, 0, item)
                          win.shortcutsList = arr
                          win.saveCurrentConfig(false)
                        }
                      }
                    }

                    // Move Down
                    Rectangle {
                      width: 28
                      height: 28
                      radius: 6
                      color: dnM.containsMouse ? win.bgInput : "transparent"
                      border.color: win.borderMuted
                      border.width: 1
                      visible: scRowItem.index < win.shortcutsList.length - 1
                      Text { anchors.centerIn: parent; text: "󰜲"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#ffffff" }
                      MouseArea {
                        id: dnM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                          var item = arr.splice(scRowItem.index, 1)[0]
                          arr.splice(scRowItem.index + 1, 0, item)
                          win.shortcutsList = arr
                          win.saveCurrentConfig(false)
                        }
                      }
                    }

                    // Delete Button
                    Rectangle {
                      width: 28
                      height: 28
                      radius: 6
                      color: delM.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.4) : win.bgInput
                      border.color: delM.containsMouse ? "#ff4466" : win.borderMuted
                      border.width: 1
                      Text { anchors.centerIn: parent; text: "󰆴"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: delM.containsMouse ? "#ffffff" : "#ff7799" }
                      MouseArea {
                        id: delM
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                          arr.splice(scRowItem.index, 1)
                          win.shortcutsList = arr
                          win.saveCurrentConfig(false)
                        }
                      }
                    }
                  }
                }
              }

              // Add New App Section
              Rectangle {
                Layout.fillWidth: true
                height: 80
                radius: 10
                color: win.bgCard
                border.color: win.accentColor
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 6

                  Text {
                    text: "ADD NEW APP SHORTCUT"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    color: win.accentColor
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                      width: 44
                      height: 28
                      radius: 6
                      color: win.bgInput
                      border.color: win.borderMuted
                      border.width: 1
                      TextInput {
                        id: newIconInput
                        anchors.fill: parent
                        anchors.margins: 4
                        text: "󰐕"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 14
                        color: win.accentColor
                      }
                    }

                    Rectangle {
                      Layout.preferredWidth: 130
                      height: 28
                      radius: 6
                      color: win.bgInput
                      border.color: win.borderMuted
                      border.width: 1
                      TextInput {
                        id: newNameInput
                        anchors.fill: parent
                        anchors.margins: 5
                        text: "New App"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#ffffff"
                      }
                    }

                    Rectangle {
                      Layout.fillWidth: true
                      height: 28
                      radius: 6
                      color: win.bgInput
                      border.color: win.borderMuted
                      border.width: 1
                      TextInput {
                        id: newCmdInput
                        anchors.fill: parent
                        anchors.margins: 5
                        text: "foot"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#d0d0f0"
                      }
                    }

                    PillButton {
                      label: "󰐕 Add Button"
                      active: true
                      accentColor: win.accentColor
                      onClicked: {
                        var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                        arr.push({
                          icon: newIconInput.text.trim() || "󰈹",
                          label: newNameInput.text.trim() || "App",
                          cmd: newCmdInput.text.trim() || "foot"
                        })
                        win.shortcutsList = arr
                        win.saveCurrentConfig(false)
                        newNameInput.text = "New App"
                        newCmdInput.text = ""
                      }
                    }
                  }
                }
              }

              // Quick Preset App Buttons
              Text {
                text: "QUICK 1-CLICK PRESET APP LAUNCHERS"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.weight: Font.Bold
                color: "#a0a0c0"
              }

              Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                  model: [
                    { icon: "󰈹", label: "Browser", cmd: "omarchy-cmd-default-browser || xdg-open https://google.com" },
                    { icon: "󰆍", label: "Terminal", cmd: "omarchy-default-terminal || foot" },
                    { icon: "󰉋", label: "Files", cmd: "thunar || omarchy-file-select" },
                    { icon: "󰨞", label: "Code", cmd: "omarchy-default-editor || code || foot -e nvim" },
                    { icon: "󰎆", label: "Music", cmd: "playerctl play-pause 2>/dev/null || true" },
                    { icon: "󰒱", label: "Discord", cmd: "discord || vesktop" },
                    { icon: "󰓓", label: "Steam", cmd: "steam" },
                    { icon: "󰝚", label: "Spotify", cmd: "spotify" },
                    { icon: "󰍛", label: "Btop Monitor", cmd: "foot -e btop" },
                    { icon: "", label: "Settings", cmd: "wallpaper-engine gui" }
                  ]

                  Rectangle {
                    required property var modelData
                    width: qpRow.implicitWidth + 16
                    height: 28
                    radius: 14
                    color: qpM.containsMouse ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.35) : win.bgInput
                    border.color: qpM.containsMouse ? win.accentColor : win.borderMuted
                    border.width: 1

                    Row {
                      id: qpRow
                      anchors.centerIn: parent
                      spacing: 6
                      Text { text: parent.parent.modelData.icon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: win.accentColor }
                      Text { text: "+ " + parent.parent.modelData.label; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                    }

                    MouseArea {
                      id: qpM
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        var arr = JSON.parse(JSON.stringify(win.shortcutsList))
                        arr.push({
                          icon: parent.modelData.icon,
                          label: parent.modelData.label,
                          cmd: parent.modelData.cmd
                        })
                        win.shortcutsList = arr
                        win.saveCurrentConfig(false)
                        win.statusNotice = "Added " + parent.modelData.label
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------
        // TAB 3: Hardware & Stats Customizer (USER REQUESTED)
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 3

          Flickable {
            id: hwFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: hwCol.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: hwFlick
              onWheel: function(event) {
                hwFlick.contentY = Math.max(0, Math.min(hwFlick.contentHeight - hwFlick.height, hwFlick.contentY - event.angleDelta.y))
              }
            }

            ColumnLayout {
              id: hwCol
              width: parent.width - 16
              spacing: 12

              Text {
                text: "SYSTEM HARDWARE TELEMETRY & SENSORS"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: win.accentColor
                font.letterSpacing: 1
              }

              // Live Real-Time Telemetry Preview Card
              Rectangle {
                Layout.fillWidth: true
                height: 70
                radius: 10
                color: win.bgCard
                border.color: win.accentColor
                border.width: 1.5

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 10
                  spacing: 4

                  RowLayout {
                    Layout.fillWidth: true
                    Text {
                      text: "LIVE SENSOR READINGS (DETECTED FROM HARDWARE)"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 10
                      font.weight: Font.Bold
                      color: win.accentColor
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                      width: 8
                      height: 8
                      radius: 4
                      color: "#50fa7b"
                    }
                    Text { text: "Online"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: "#50fa7b" }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    Text {
                      text: "󰍛 CPU: " + win.liveHw.cpuLoad + " load"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }

                    Text {
                      text: "󰈸 TEMP: " + win.formatTemp(win.liveHw.cpuTemp)
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      font.weight: Font.Bold
                      color: win.liveHw.cpuTemp >= 80 ? "#ff5555" : (win.liveHw.cpuTemp >= 65 ? "#ffb86c" : "#50fa7b")
                    }

                    Text {
                      text: "󰠝 FAN: " + win.liveHw.fanSpeed + " RPM"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }

                    Text {
                      text: "󰘚 RAM: " + win.liveHw.ramUsed + " (" + win.liveHw.ramPercent + "%)"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }

                    Text {
                      visible: win.liveHw.gpuTemp > 0
                      text: "󰢮 GPU: " + win.formatTemp(win.liveHw.gpuTemp)
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      font.weight: Font.Bold
                      color: "#ffffff"
                    }
                  }
                }
              }

              // Temperature Unit Selector
              Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 14

                  Text {
                    text: "Temperature Display Unit:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: "#ffffff"
                  }

                  PillButton {
                    label: "°C (Celsius)"
                    active: win.hwTempUnit === "C"
                    accentColor: win.accentColor
                    onClicked: { win.hwTempUnit = "C"; win.saveCurrentConfig(false) }
                  }

                  PillButton {
                    label: "°F (Fahrenheit)"
                    active: win.hwTempUnit === "F"
                    accentColor: win.accentColor
                    onClicked: { win.hwTempUnit = "F"; win.saveCurrentConfig(false) }
                  }

                  Item { Layout.fillWidth: true }
                }
              }

              // Hardware Item Toggles
              ModuleToggleCard {
                icon: "󰍛"
                title: "CPU 1-Minute Load Average"
                subtitle: "Show real-time multi-core processor workload average on the desktop"
                checked: win.hwCpuLoad
                accentColor: win.accentColor
                onToggled: { win.hwCpuLoad = !win.hwCpuLoad; win.saveCurrentConfig(false) }
              }

              ModuleToggleCard {
                icon: "󰈸"
                title: "CPU Package Core Temperature"
                subtitle: "Real-time thermal sensor reading with green/amber/red heat indicators"
                checked: win.hwCpuTemp
                accentColor: win.accentColor
                onToggled: { win.hwCpuTemp = !win.hwCpuTemp; win.saveCurrentConfig(false) }
              }

              ModuleToggleCard {
                icon: "󰠝"
                title: "Chassis & CPU Fan Speeds (RPM)"
                subtitle: "Displays live tachometer RPM from hardware thermal controllers"
                checked: win.hwFanSpeed
                accentColor: win.accentColor
                onToggled: { win.hwFanSpeed = !win.hwFanSpeed; win.saveCurrentConfig(false) }
              }

              ModuleToggleCard {
                icon: "󰘚"
                title: "RAM System Memory Gauge"
                subtitle: "Live physical memory consumption, available gigabytes, and usage progress bar"
                checked: win.hwRam
                accentColor: win.accentColor
                onToggled: { win.hwRam = !win.hwRam; win.saveCurrentConfig(false) }
              }

              ModuleToggleCard {
                icon: "󰢮"
                title: "GPU Graphics Processor Temperature"
                subtitle: "Monitor dedicated graphics or integrated GPU silicon temperature"
                checked: win.hwGpuTemp
                accentColor: win.accentColor
                onToggled: { win.hwGpuTemp = !win.hwGpuTemp; win.saveCurrentConfig(false) }
              }
            }
          }
        }

        // ------------------------------------------
        // TAB 4: Style & Colors
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 4

          Flickable {
            id: styleFlick
            anchors.fill: parent
            contentWidth: width
            contentHeight: styleCol.implicitHeight + 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
              target: styleFlick
              onWheel: function(event) {
                styleFlick.contentY = Math.max(0, Math.min(styleFlick.contentHeight - styleFlick.height, styleFlick.contentY - event.angleDelta.y))
              }
            }

            ColumnLayout {
              id: styleCol
              width: parent.width - 16
              spacing: 12

              Text {
                text: "ACCENT COLORS & THEME STYLING"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: win.accentColor
                font.letterSpacing: 1
              }

              // Color Swatches Palette
              Rectangle {
                Layout.fillWidth: true
                height: 105
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 10

                  Text {
                    text: "Preset Theme Color Swatches:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                      model: [
                        { name: "Magenta", hex: "#e20074" },
                        { name: "Cyan", hex: "#00e5ff" },
                        { name: "Green", hex: "#50fa7b" },
                        { name: "Purple", hex: "#bd93f9" },
                        { name: "Orange", hex: "#ffb86c" },
                        { name: "Amber", hex: "#ffb300" },
                        { name: "Coral", hex: "#ff5555" },
                        { name: "White", hex: "#f8f8f2" }
                      ]

                      Rectangle {
                        required property var modelData
                        width: 32
                        height: 32
                        radius: 16
                        color: modelData.hex
                        border.color: win.accentColor.toString().toLowerCase() === modelData.hex.toLowerCase() ? "#ffffff" : win.borderMuted
                        border.width: win.accentColor.toString().toLowerCase() === modelData.hex.toLowerCase() ? 2.5 : 1
                        scale: swatchMouse.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }

                        MouseArea {
                          id: swatchMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            win.accentColor = parent.modelData.hex
                            win.saveCurrentConfig(false)
                          }
                        }
                      }
                    }

                    Item { Layout.fillWidth: true }
                  }
                }
              }

              // Custom Hex Input
              Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 12

                  Text {
                    text: "Custom Accent Hex:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                  }

                  Rectangle {
                    width: 110
                    height: 28
                    radius: 6
                    color: win.bgInput
                    border.color: win.borderMuted
                    border.width: 1

                    TextInput {
                      id: customHexInput
                      anchors.fill: parent
                      anchors.margins: 5
                      text: win.accentColor.toString()
                      color: "#ffffff"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 12
                      onEditingFinished: {
                        var h = text.trim()
                        if (!h.startsWith("#")) h = "#" + h
                        win.accentColor = h
                        win.saveCurrentConfig(false)
                      }
                    }
                  }

                  PillButton {
                    label: "Apply Hex"
                    active: true
                    accentColor: win.accentColor
                    onClicked: {
                      var h = customHexInput.text.trim()
                      if (!h.startsWith("#")) h = "#" + h
                      win.accentColor = h
                      win.saveCurrentConfig(false)
                    }
                  }

                  Item { Layout.fillWidth: true }
                }
              }

              // Sliders for Opacity, Radius, Glow
              Rectangle {
                Layout.fillWidth: true
                height: 155
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 14
                  spacing: 12

                  // Opacity
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                      text: "Card Opacity:"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      color: "#ffffff"
                      Layout.preferredWidth: 100
                    }

                    ModernSlider {
                      from: 0.3
                      to: 1.0
                      stepSize: 0.05
                      value: win.cardOpacity
                      onMoved: function(v) {
                        win.cardOpacity = Math.round(v * 100) / 100
                        win.saveCurrentConfig(false)
                      }
                    }

                    Text {
                      text: Math.round(win.cardOpacity * 100) + " %"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      font.weight: Font.Bold
                      color: win.accentColor
                      Layout.preferredWidth: 60
                    }
                  }

                  // Radius
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                      text: "Corner Radius:"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      color: "#ffffff"
                      Layout.preferredWidth: 100
                    }

                    ModernSlider {
                      from: 6
                      to: 36
                      stepSize: 2
                      value: win.cardRadius
                      onMoved: function(v) {
                        win.cardRadius = Math.round(v)
                        win.saveCurrentConfig(false)
                      }
                    }

                    Text {
                      text: win.cardRadius + " px"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      font.weight: Font.Bold
                      color: win.accentColor
                      Layout.preferredWidth: 60
                    }
                  }

                  // Border & Glow
                  RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                      text: "Neon Glow & Border:"
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 11
                      color: "#ffffff"
                      Layout.preferredWidth: 140
                    }

                    PillButton {
                      label: "Ambient Glow: " + (win.borderGlow ? "ON" : "OFF")
                      active: win.borderGlow
                      accentColor: win.accentColor
                      onClicked: { win.borderGlow = !win.borderGlow; win.saveCurrentConfig(false) }
                    }

                    PillButton {
                      label: "Border: " + win.borderWidth + "px"
                      active: true
                      accentColor: win.accentColor
                      onClicked: {
                        win.borderWidth = win.borderWidth >= 2.5 ? 1.0 : (win.borderWidth + 0.5)
                        win.saveCurrentConfig(false)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // ------------------------------------------
        // TAB 5: Audio Visualizer
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 5

          ColumnLayout {
            anchors.fill: parent
            spacing: 14

            Text {
              text: "AUDIO SPECTRUM VISUALIZER TUNING"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 12
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            Rectangle {
              Layout.fillWidth: true
              height: 165
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // Height Slider
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "Visualizer Height:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 120
                  }

                  ModernSlider {
                    from: 40
                    to: 130
                    stepSize: 5
                    value: win.visHeight
                    onMoved: function(v) {
                      win.visHeight = Math.round(v)
                      win.saveCurrentConfig(false)
                    }
                  }

                  Text {
                    text: win.visHeight + " px"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: win.accentColor
                    Layout.preferredWidth: 60
                  }
                }

                // Bars Slider
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "Spectrum Bars:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 120
                  }

                  ModernSlider {
                    from: 16
                    to: 40
                    stepSize: 2
                    value: win.visBars
                    onMoved: function(v) {
                      win.visBars = Math.round(v)
                      win.saveCurrentConfig(false)
                    }
                  }

                  Text {
                    text: win.visBars + " bars"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: win.accentColor
                    Layout.preferredWidth: 60
                  }
                }

                // Idle Wave Toggle
                RowLayout {
                  Layout.fillWidth: true
                  spacing: 12

                  Text {
                    text: "Ambient Wave Physics:"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: "#ffffff"
                    Layout.preferredWidth: 150
                  }

                  PillButton {
                    label: "Idle Sine Wave: " + (win.visIdleWave ? "ENABLED" : "DISABLED")
                    active: win.visIdleWave
                    accentColor: win.accentColor
                    onClicked: { win.visIdleWave = !win.visIdleWave; win.saveCurrentConfig(false) }
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }
        }

        // ------------------------------------------
        // TAB 6: Wallpapers & Backgrounds
        // ------------------------------------------
        Item {
          anchors.fill: parent
          visible: win.activeTab === 6

          ColumnLayout {
            anchors.fill: parent
            spacing: 14

            RowLayout {
              Layout.fillWidth: true
              Text {
                text: "INSTANT WALLPAPER SELECTION"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: win.accentColor
                font.letterSpacing: 1
              }
              Item { Layout.fillWidth: true }
              PillButton {
                label: "󰋩 Open Omarchy Wallpaper Picker"
                active: true
                accentColor: win.accentColor
                onClicked: {
                  Quickshell.execDetached(["omarchy-theme-bg-select"])
                  win.statusNotice = "Launched wallpaper picker"
                }
              }
            }

            // Theme Wallpapers Grid
            RowLayout {
              Layout.fillWidth: true
              spacing: 12

              Repeater {
                model: [
                  { title: "Horizon", path: Quickshell.env("HOME") + "/.config/omarchy/themes/ryguy/backgrounds/0-ryguy-horizon.png", sub: "Sunset Gradient" },
                  { title: "Monolith", path: Quickshell.env("HOME") + "/.config/omarchy/themes/ryguy/backgrounds/1-ryguy-monolith.png", sub: "Cyber Geometric" },
                  { title: "Void", path: Quickshell.env("HOME") + "/.config/omarchy/themes/ryguy/backgrounds/2-ryguy-void.png", sub: "Deep Minimalist" }
                ]

                Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  height: 140
                  radius: 10
                  color: win.bgCard
                  border.color: win.borderMuted
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Image {
                      Layout.fillWidth: true
                      Layout.fillHeight: true
                      source: parent.parent.modelData.path
                      fillMode: Image.PreserveAspectCrop
                      clip: true
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      ColumnLayout {
                        spacing: 1
                        Text { text: parent.parent.parent.parent.modelData.title; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffffff" }
                        Text { text: parent.parent.parent.parent.modelData.sub; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: "#8080a0" }
                      }
                      Item { Layout.fillWidth: true }
                      PillButton {
                        label: "Apply"
                        active: true
                        accentColor: win.accentColor
                        onClicked: {
                          Quickshell.execDetached(["omarchy-theme-bg-set", parent.parent.parent.parent.modelData.path])
                          win.statusNotice = "Applied " + parent.parent.parent.parent.modelData.title
                        }
                      }
                    }
                  }
                }
              }
            }

            // Custom Wallpaper Path Input
            Rectangle {
              Layout.fillWidth: true
              height: 52
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Text {
                  text: "Set Custom Path:"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  color: "#ffffff"
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 28
                  radius: 6
                  color: win.bgInput
                  border.color: win.borderMuted
                  border.width: 1

                  TextInput {
                    id: customWallInput
                    anchors.fill: parent
                    anchors.margins: 5
                    text: Quickshell.env("HOME") + "/Pictures/wallpaper.png"
                    color: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    onEditingFinished: {
                      var p = text.trim()
                      if (p !== "") {
                        Quickshell.execDetached(["omarchy-theme-bg-set", p])
                        win.statusNotice = "Wallpaper updated"
                      }
                    }
                  }
                }

                PillButton {
                  label: "Set Background"
                  active: true
                  accentColor: win.accentColor
                  onClicked: {
                    var p = customWallInput.text.trim()
                    if (p !== "") {
                      Quickshell.execDetached(["omarchy-theme-bg-set", p])
                      win.statusNotice = "Wallpaper updated"
                    }
                  }
                }
              }
            }

            Item { Layout.fillHeight: true }
          }
        }
      }

      // ==========================================
      // FOOTER ACTIONS
      // ==========================================
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: win.borderMuted
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        PillButton {
          label: "↺ Reset Defaults"
          active: false
          accentColor: win.accentColor
          onClicked: {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "reset"])
            configFileView.reload()
            win.statusNotice = "Reset to defaults"
          }
        }

        // Apply & Restart Shell
        PillButton {
          label: "󰑓 Apply & Restart Shell"
          active: true
          accentColor: win.accentColor
          onClicked: win.saveCurrentConfig(true)
        }

        Item { Layout.fillWidth: true }

        // Auto Restart Switch
        RowLayout {
          spacing: 6
          Layout.alignment: Qt.AlignVCenter

          Text {
            text: "Auto-restart on close:"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            color: "#a0a0c0"
          }

          Rectangle {
            width: 36
            height: 18
            radius: 9
            color: win.autoRestartShell ? win.accentColor : win.bgInput
            border.color: win.borderMuted
            border.width: 1

            Rectangle {
              width: 14
              height: 14
              radius: 7
              color: "#ffffff"
              anchors.verticalCenter: parent.verticalCenter
              x: win.autoRestartShell ? parent.width - width - 2 : 2
              Behavior on x { NumberAnimation { duration: 150 } }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                win.autoRestartShell = !win.autoRestartShell
                win.saveCurrentConfig(false)
              }
            }
          }
        }

        Item { width: 10 }

        PillButton {
          label: "Done & Close"
          active: true
          accentColor: win.accentColor
          onClicked: {
            if (win.autoRestartShell) Quickshell.execDetached(["/usr/share/omarchy/bin/omarchy", "restart", "shell"])
            Qt.quit()
          }
        }
      }
    }
  }

  // ==========================================
  // INLINE REUSABLE COMPONENTS
  // ==========================================
  component ModernSlider: Rectangle {
    id: sld
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property real value: 50
    signal moved(real val)

    Layout.fillWidth: true
    height: 22
    color: "transparent"

    Rectangle {
      id: track
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 6
      radius: 3
      color: Qt.rgba(0.2, 0.2, 0.3, 0.8)

      Rectangle {
        width: Math.max(0, Math.min(track.width, ((sld.value - sld.from) / (sld.to - sld.from)) * track.width))
        height: parent.height
        radius: 3
        color: win.accentColor
      }
    }

    Rectangle {
      id: handle
      width: 16
      height: 16
      radius: 8
      color: "#ffffff"
      border.color: win.accentColor
      border.width: 2.5
      anchors.verticalCenter: parent.verticalCenter
      x: Math.max(0, Math.min(sld.width - width, ((sld.value - sld.from) / (sld.to - sld.from)) * (sld.width - width)))

      Behavior on scale { NumberAnimation { duration: 100 } }
      scale: sldMouse.pressed ? 1.25 : (sldMouse.containsMouse ? 1.1 : 1.0)
    }

    MouseArea {
      id: sldMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      function updatePos(mouse) {
        var ratio = Math.max(0, Math.min(1, mouse.x / sld.width))
        var raw = sld.from + ratio * (sld.to - sld.from)
        if (sld.stepSize > 0) {
          raw = Math.round((raw - sld.from) / sld.stepSize) * sld.stepSize + sld.from
        }
        sld.value = raw
        sld.moved(raw)
      }

      onPressed: updatePos(mouse)
      onPositionChanged: if (pressed) updatePos(mouse)
    }
  }

  component PositionButton: Rectangle {
    id: pBtn
    property string posId: ""
    property string label: ""
    property string currentPos: ""
    signal selected()

    Layout.fillWidth: true
    height: 38
    radius: 7
    readonly property bool isSelected: currentPos === posId
    color: isSelected ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.35) : (pMouse.containsMouse ? win.bgInput : Qt.rgba(0.12, 0.12, 0.18, 0.9))
    border.color: isSelected ? win.accentColor : win.borderMuted
    border.width: isSelected ? 2 : 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
      anchors.centerIn: parent
      text: pBtn.label
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      font.weight: pBtn.isSelected ? Font.Bold : Font.Normal
      color: pBtn.isSelected ? "#ffffff" : "#c0c0d8"
    }

    MouseArea {
      id: pMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pBtn.selected()
    }
  }

  component PillButton: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    property color accentColor: "#e20074"
    signal clicked()

    implicitWidth: pillText.implicitWidth + 20
    implicitHeight: 28
    radius: 6
    color: active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35) : (pillMouse.containsMouse ? win.bgInput : Qt.rgba(0.14, 0.14, 0.20, 0.9))
    border.color: active ? accentColor : win.borderMuted
    border.width: active ? 1.5 : 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
      id: pillText
      anchors.centerIn: parent
      text: pill.label
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 11
      font.weight: pill.active ? Font.Bold : Font.Medium
      color: pill.active ? "#ffffff" : "#b0b0c8"
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: pill.clicked()
    }
  }

  component ModuleToggleCard: Rectangle {
    id: card
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property color accentColor: "#e20074"
    property alias extraContent: extraLoader.sourceComponent
    signal toggled()

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 20
    radius: 10
    color: win.bgCard
    border.color: checked ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.40) : win.borderMuted
    border.width: 1

    ColumnLayout {
      id: col
      anchors.fill: parent
      anchors.margins: 10
      spacing: 8

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: card.checked ? Qt.rgba(card.accentColor.r, card.accentColor.g, card.accentColor.b, 0.25) : win.bgInput
          border.color: card.checked ? card.accentColor : win.borderMuted
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: card.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: card.checked ? card.accentColor : "#8888a8"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text {
            text: card.title
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.weight: Font.Bold
            color: card.checked ? "#ffffff" : "#a0a0b8"
          }
          Text {
            text: card.subtitle
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            color: "#787898"
          }
        }

        // Animated Toggle Switch
        Rectangle {
          width: 46
          height: 24
          radius: 12
          color: card.checked ? card.accentColor : Qt.rgba(0.2, 0.2, 0.28, 0.9)
          border.color: card.checked ? Qt.lighter(card.accentColor, 1.2) : win.borderMuted
          border.width: 1

          Behavior on color { ColorAnimation { duration: 180 } }

          Rectangle {
            width: 18
            height: 18
            radius: 9
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: card.checked ? parent.width - width - 3 : 3

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: card.toggled()
          }
        }
      }

      Loader {
        id: extraLoader
        Layout.fillWidth: true
        visible: card.checked && sourceComponent !== null
      }
    }
  }
}
