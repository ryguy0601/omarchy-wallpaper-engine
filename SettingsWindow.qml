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

  // Responsive breakpoints
  readonly property bool isCompact: win.width < 768
  readonly property bool isSmallHeight: win.height < 700

  // Active Tab Index: 0: Atmosphere & Weather, 1: Billboards & Names, 2: Clock & Display, 3: Cyber Colors, 4: Live Telemetry
  property int activeTab: 0

  // Configuration Properties
  property string weatherEffect: "auto"

  property bool showClock: true
  property bool showCpu: true
  property bool showRam: true
  property bool showGpu: true
  property bool showMedia: true

  // Editable Billboard Header Names
  property string nameClock: "LIVE BROADCAST // ONE TIMES SQUARE NYC"
  property string nameCpu: "NASDAQ // CPU CORE"
  property string nameRam: "BANK // RAM STORAGE"
  property string nameGpu: "POWER // GPU & FANS"
  property string nameMedia: "BROADWAY JUMBOTRON"

  property bool cfg12h: true
  property bool cfgShowAmPm: true
  property bool cfgShowSeconds: false
  property int cfgClockSize: 64

  property color accentColor: "#e20074"
  property string cardBg: "#0c0c12"
  property real cardOpacity: 0.88
  property int cardRadius: 12
  property real borderWidth: 1.5

  property string statusNotice: ""

  // Live Hardware Telemetry
  property var liveHw: ({
    cpuLoad: "0.0",
    ramUsed: "0G",
    ramTotal: "0G",
    ramPercent: 0,
    cpuTemp: 0,
    fanSpeed: 0,
    gpuTemp: 0
  })

  readonly property color bgDark: "#0c0c12"
  readonly property color bgCard: Qt.rgba(accentColor.r * 0.08 + 0.08, accentColor.g * 0.08 + 0.08, accentColor.b * 0.08 + 0.10, 0.95)
  readonly property color bgInput: Qt.rgba(accentColor.r * 0.10 + 0.11, accentColor.g * 0.10 + 0.11, accentColor.b * 0.10 + 0.15, 0.95)
  readonly property color borderActive: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.70)
  readonly property color borderMuted: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.28)

  // Poller for live telemetry
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
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: hwPollerProc.running = true
  }

  // Live Config Sync
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
      if (d.weatherEffect) win.weatherEffect = String(d.weatherEffect).toLowerCase()

      if (d.billboards) {
        if (typeof d.billboards.clock === "boolean") win.showClock = d.billboards.clock
        if (typeof d.billboards.cpu === "boolean") win.showCpu = d.billboards.cpu
        if (typeof d.billboards.ram === "boolean") win.showRam = d.billboards.ram
        if (typeof d.billboards.gpu === "boolean") win.showGpu = d.billboards.gpu
        if (typeof d.billboards.media === "boolean") win.showMedia = d.billboards.media

        if (typeof d.billboards.nameClock === "string" && d.billboards.nameClock.length > 0) win.nameClock = d.billboards.nameClock
        if (typeof d.billboards.nameCpu === "string" && d.billboards.nameCpu.length > 0) win.nameCpu = d.billboards.nameCpu
        if (typeof d.billboards.nameRam === "string" && d.billboards.nameRam.length > 0) win.nameRam = d.billboards.nameRam
        if (typeof d.billboards.nameGpu === "string" && d.billboards.nameGpu.length > 0) win.nameGpu = d.billboards.nameGpu
        if (typeof d.billboards.nameMedia === "string" && d.billboards.nameMedia.length > 0) win.nameMedia = d.billboards.nameMedia
      } else if (d.modules) {
        if (typeof d.modules.clock === "boolean") win.showClock = d.modules.clock
        if (typeof d.modules.sysinfo === "boolean") {
          win.showCpu = d.modules.sysinfo
          win.showRam = d.modules.sysinfo
          win.showGpu = d.modules.sysinfo
        }
        if (typeof d.modules.media === "boolean") win.showMedia = d.modules.media
      }

      if (d.clock) {
        if (typeof d.clock.format12h === "boolean") win.cfg12h = d.clock.format12h
        if (typeof d.clock.showAmPm === "boolean") win.cfgShowAmPm = d.clock.showAmPm
        if (typeof d.clock.showSeconds === "boolean") win.cfgShowSeconds = d.clock.showSeconds
        if (typeof d.clock.fontSize === "number") win.cfgClockSize = d.clock.fontSize
      }

      if (d.style) {
        if (d.style.accentColor) win.accentColor = d.style.accentColor
        if (d.style.cardBackground) win.cardBg = d.style.cardBackground
        if (typeof d.style.cardOpacity === "number") win.cardOpacity = d.style.cardOpacity
        if (typeof d.style.cardRadius === "number") win.cardRadius = d.style.cardRadius
        if (typeof d.style.borderWidth === "number") win.borderWidth = d.style.borderWidth
      }
    } catch (e) {
      console.warn("SettingsWindow: Error parsing config:", e)
    }
  }

  function saveCurrentConfig() {
    var d = {
      "weatherEffect": win.weatherEffect,
      "billboards": {
        "clock": win.showClock,
        "cpu": win.showCpu,
        "ram": win.showRam,
        "gpu": win.showGpu,
        "media": win.showMedia,
        "nameClock": win.nameClock,
        "nameCpu": win.nameCpu,
        "nameRam": win.nameRam,
        "nameGpu": win.nameGpu,
        "nameMedia": win.nameMedia
      },
      "clock": {
        "format12h": win.cfg12h,
        "showAmPm": win.cfgShowAmPm,
        "showSeconds": win.cfgShowSeconds,
        "fontSize": win.cfgClockSize
      },
      "style": {
        "accentColor": win.accentColor.toString(),
        "cardBackground": win.cardBg,
        "cardOpacity": win.cardOpacity,
        "cardRadius": win.cardRadius,
        "borderWidth": win.borderWidth
      }
    }

    var cmd = [
      Quickshell.env("HOME") + "/.local/bin/wallpaper-engine",
      "apply-json",
      JSON.stringify(d, null, 2)
    ]
    Quickshell.execDetached(cmd)
    win.statusNotice = "Saved Live"
    statusTimer.restart()
  }

  Timer {
    id: statusTimer
    interval: 2000
    onTriggered: win.statusNotice = ""
  }

  // Backdrop Dimmer
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.70)
    MouseArea {
      anchors.fill: parent
      onClicked: Qt.quit()
    }
  }

  // Responsive Modal Dialog Card
  Rectangle {
    id: dialogCard
    anchors.centerIn: parent
    // Adaptive sizing to scale cleanly from small 1280x720/1280x800 screens up to 4K displays
    width: Math.min(920, Math.max(340, parent.width - (win.isCompact ? 24 : 64)))
    height: Math.min(720, Math.max(480, parent.height - (win.isSmallHeight ? 24 : 64)))
    color: win.bgDark
    border.color: win.borderActive
    border.width: 1.5
    radius: 14
    clip: true

    MouseArea {
      anchors.fill: parent
      // Intercept clicks so backdrop click does not close dialog
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: win.isCompact ? 12 : 20
      spacing: win.isSmallHeight ? 8 : 12

      // -------------------------------------------------------------
      // HEADER BAR
      // -------------------------------------------------------------
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          width: win.isCompact ? 32 : 38
          height: win.isCompact ? 32 : 38
          radius: 10
          color: Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.25)
          border.color: win.accentColor
          border.width: 1.5

          Text {
            anchors.centerIn: parent
            text: "󰸉"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: win.isCompact ? 16 : 20
            color: win.accentColor
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text {
            text: win.isCompact ? "TIMES SQUARE // CUSTOMIZER" : "TIMES SQUARE CANYON // CUSTOMIZER"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: win.isCompact ? 12 : 14
            font.weight: Font.Bold
            color: "#ffffff"
            font.letterSpacing: 1.1
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: "Atmosphere, Skyscraper Titles & Jumbotrons, Clocks & Cyber Neon"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
            color: "#8a8aa8"
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Live notification badge
        Rectangle {
          visible: win.statusNotice !== ""
          radius: 6
          color: Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.25)
          border.color: win.accentColor
          border.width: 1
          implicitWidth: statTxt.implicitWidth + 14
          implicitHeight: 24

          Text {
            id: statTxt
            anchors.centerIn: parent
            text: win.statusNotice
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
            font.bold: true
            color: win.accentColor
          }
        }

        // Close button
        Rectangle {
          width: 30
          height: 30
          radius: 8
          color: closeMouse.containsMouse ? "#ff3366" : win.bgInput
          border.color: win.borderMuted
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#ffffff"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            font.bold: true
          }

          MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Qt.quit()
          }
        }
      }

      // -------------------------------------------------------------
      // RESPONSIVE NAVIGATION TABS (SCROLLABLE ON COMPACT SCREENS)
      // -------------------------------------------------------------
      ScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff

        RowLayout {
          spacing: 6
          width: Math.max(dialogCard.width - (win.isCompact ? 24 : 40), implicitWidth)

          Repeater {
            model: [
              { icon: "󰼲", label: "Atmosphere", idx: 0 },
              { icon: "󱂬", label: "Billboards & Names", idx: 1 },
              { icon: "󱑂", label: "Clock & Display", idx: 2 },
              { icon: "󰏘", label: "Cyber Styling", idx: 3 },
              { icon: "󰍛", label: "Live Telemetry", idx: 4 }
            ]

            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitWidth: tabRow.implicitWidth + 18
              height: 34
              radius: 8
              color: win.activeTab === modelData.idx ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.32) : win.bgInput
              border.color: win.activeTab === modelData.idx ? win.accentColor : win.borderMuted
              border.width: win.activeTab === modelData.idx ? 1.5 : 1

              Behavior on color { ColorAnimation { duration: 150 } }

              Row {
                id: tabRow
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
                  font.pixelSize: 10
                  font.weight: win.activeTab === modelData.idx ? Font.Bold : Font.Medium
                  color: win.activeTab === modelData.idx ? "#ffffff" : "#b0b0c8"
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.activeTab = modelData.idx
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: win.borderMuted
      }

      // -------------------------------------------------------------
      // TAB PAGES CONTENT
      // -------------------------------------------------------------
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        // =========================================================
        // TAB 0: ATMOSPHERE & WEATHER
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: win.activeTab === 0
          clip: true

          ColumnLayout {
            width: parent.width - 14
            spacing: 14

            Text {
              text: "SELECT ATMOSPHERIC WEATHER SIMULATION"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            Text {
              text: "The cityscape renders real-time animated weather canvas effects including thunderstorm lightning, rain splashes, falling snowflakes, and ambient skyline gradients."
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
              color: "#a0a0c0"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            GridLayout {
              columns: win.isCompact ? 1 : 2
              Layout.fillWidth: true
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: [
                  { id: "auto", name: "Automatic Live Weather", desc: "Syncs with Open-Meteo & your local forecast", icon: "󰖐" },
                  { id: "thunder", name: "Cyber Thunderstorm", desc: "Dark stormy sky with random lightning flashes & rain", icon: "󰙝" },
                  { id: "rain", name: "Rainy Night", desc: "Atmospheric street rain particle physics", icon: "󰖗" },
                  { id: "snow", name: "Winter Snowfall", desc: "Gentle drifting snow flakes and cool winter lighting", icon: "󰼶" },
                  { id: "cloudy", name: "Overcast Clouds", desc: "Deep brooding clouds drifting across moon", icon: "󰖐" },
                  { id: "clear", name: "Clear Starry Night", desc: "Twinkling neon stars and glowing full moon", icon: "󰖔" },
                  { id: "fog", name: "Canyon Mist / Fog", desc: "Heavy ambient neon haze and ground fog", icon: "󰖑" }
                ]

                Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  height: 58
                  radius: 10
                  property bool isSelected: win.weatherEffect === modelData.id
                  color: isSelected ? Qt.rgba(win.accentColor.r, win.accentColor.g, win.accentColor.b, 0.28) : win.bgCard
                  border.color: isSelected ? win.accentColor : win.borderMuted
                  border.width: isSelected ? 2 : 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Rectangle {
                      width: 32
                      height: 32
                      radius: 16
                      color: parent.parent.isSelected ? win.accentColor : win.bgInput
                      Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                        color: parent.parent.isSelected ? "#ffffff" : win.accentColor
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 1
                      Text {
                        text: modelData.name
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.bold: true
                        color: parent.parent.parent.isSelected ? "#ffffff" : "#dedee8"
                      }
                      Text {
                        text: modelData.desc
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 8
                        color: "#8a8aa8"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    Text {
                      text: parent.parent.isSelected ? "ACTIVE" : ""
                      font.family: "JetBrainsMono Nerd Font"
                      font.pixelSize: 9
                      font.bold: true
                      color: win.accentColor
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      win.weatherEffect = modelData.id
                      win.saveCurrentConfig()
                    }
                  }
                }
              }
            }
          }
        }

        // =========================================================
        // TAB 1: BILLBOARDS & CUSTOM NAMES (USER REQUESTED)
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: win.activeTab === 1
          clip: true

          ColumnLayout {
            width: parent.width - 14
            spacing: 12

            Text {
              text: "CUSTOMIZE TOWER BILLBOARD NAMES & VISIBILITY"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            Text {
              text: "Toggle any skyscraper billboard on/off and type your own custom title/brand for each jumbotron below. Changes update live across the skyline."
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
              color: "#a0a0c0"
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }

            // Billboard 1: One Times Square Clock
            BillboardEditorCard {
              icon: "󱑂"
              title: "Flagship Tower (Center) // One Times Square"
              subtitle: "Digital clock, current date, weather readout, and wind ribbon"
              checked: win.showClock
              accentColor: win.accentColor
              customName: win.nameClock
              onToggled: {
                win.showClock = !win.showClock
                win.saveCurrentConfig()
              }
              onNameEdited: function(newName) {
                win.nameClock = newName
                win.saveCurrentConfig()
              }
            }

            // Billboard 2: CPU NASDAQ
            BillboardEditorCard {
              icon: "󰍛"
              title: "Tower 1 (Far-Left) // CPU Telemetry Tower"
              subtitle: "CPU Core load percentage, temperature, and 16-segment activity bar"
              checked: win.showCpu
              accentColor: "#ff3388"
              customName: win.nameCpu
              onToggled: {
                win.showCpu = !win.showCpu
                win.saveCurrentConfig()
              }
              onNameEdited: function(newName) {
                win.nameCpu = newName
                win.saveCurrentConfig()
              }
            }

            // Billboard 3: RAM Tower
            BillboardEditorCard {
              icon: "󰘚"
              title: "Tower 2 (Mid-Left) // Memory Bank Tower"
              subtitle: "RAM usage, total memory, and cyan segmented capacity gauge"
              checked: win.showRam
              accentColor: "#00e5ff"
              customName: win.nameRam
              onToggled: {
                win.showRam = !win.showRam
                win.saveCurrentConfig()
              }
              onNameEdited: function(newName) {
                win.nameRam = newName
                win.saveCurrentConfig()
              }
            }

            // Billboard 4: GPU Tower
            BillboardEditorCard {
              icon: "󰢮"
              title: "Tower 4 (Mid-Right) // GPU & Power Tower"
              subtitle: "GPU thermal readings, fan speeds in RPM, and emerald cooling bar"
              checked: win.showGpu
              accentColor: "#10e782"
              customName: win.nameGpu
              onToggled: {
                win.showGpu = !win.showGpu
                win.saveCurrentConfig()
              }
              onNameEdited: function(newName) {
                win.nameGpu = newName
                win.saveCurrentConfig()
              }
            }

            // Billboard 5: Media Jumbotron
            BillboardEditorCard {
              icon: "󰎆"
              title: "Tower 5 (Far-Right) // Broadway Media Jumbotron"
              subtitle: "Album artwork, song metadata, playback buttons, and real-time audio spectrum"
              checked: win.showMedia
              accentColor: "#00e5ff"
              customName: win.nameMedia
              onToggled: {
                win.showMedia = !win.showMedia
                win.saveCurrentConfig()
              }
              onNameEdited: function(newName) {
                win.nameMedia = newName
                win.saveCurrentConfig()
              }
            }
          }
        }

        // =========================================================
        // TAB 2: CLOCK & DISPLAY
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: win.activeTab === 2
          clip: true

          ColumnLayout {
            width: parent.width - 14
            spacing: 12

            Text {
              text: "CLOCK DISPLAY & TIME FORMATTING"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            Rectangle {
              Layout.fillWidth: true
              height: 95
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                  text: "Time Format Mode:"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#ffffff"
                }

                RowLayout {
                  spacing: 10
                  PillButton {
                    label: "12-Hour Mode (AM/PM)"
                    active: win.cfg12h
                    accentColor: win.accentColor
                    onClicked: {
                      win.cfg12h = true
                      win.saveCurrentConfig()
                    }
                  }
                  PillButton {
                    label: "24-Hour Military Format"
                    active: !win.cfg12h
                    accentColor: win.accentColor
                    onClicked: {
                      win.cfg12h = false
                      win.saveCurrentConfig()
                    }
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 70
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    text: "Show Running Seconds"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                  Text {
                    text: "Displays live ticking seconds beside main clock digits"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: "#8a8aa8"
                  }
                }

                PillButton {
                  label: win.cfgShowSeconds ? "ON" : "OFF"
                  active: win.cfgShowSeconds
                  accentColor: win.accentColor
                  onClicked: {
                    win.cfgShowSeconds = !win.cfgShowSeconds
                    win.saveCurrentConfig()
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 70
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 2
                  Text {
                    text: "Show AM/PM Indicator"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                  Text {
                    text: "Cyber AM/PM indicator badge (12h format only)"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 9
                    color: "#8a8aa8"
                  }
                }

                PillButton {
                  label: win.cfgShowAmPm ? "ON" : "OFF"
                  active: win.cfgShowAmPm
                  accentColor: win.accentColor
                  onClicked: {
                    win.cfgShowAmPm = !win.cfgShowAmPm
                    win.saveCurrentConfig()
                  }
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 90
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "Clock Typography Font Size"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: win.cfgClockSize + " px"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: win.accentColor
                  }
                }

                ModernSlider {
                  from: 40
                  to: 88
                  stepSize: 2
                  value: win.cfgClockSize
                  onMoved: function(v) {
                    win.cfgClockSize = Math.round(v)
                    win.saveCurrentConfig()
                  }
                }
              }
            }
          }
        }

        // =========================================================
        // TAB 3: CYBER STYLING
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: win.activeTab === 3
          clip: true

          ColumnLayout {
            width: parent.width - 14
            spacing: 12

            Text {
              text: "NEON ACCENTS & BILLBOARD SURFACE AESTHETICS"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            // Preset Swatches
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
                spacing: 8

                Text {
                  text: "Times Square Neon Accent Palette:"
                  font.family: "JetBrainsMono Nerd Font"
                  font.pixelSize: 11
                  font.bold: true
                  color: "#ffffff"
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: win.isCompact ? 6 : 10

                  Repeater {
                    model: [
                      { name: "Cyberpunk Magenta", hex: "#e20074" },
                      { name: "Broadway Cyan", hex: "#00e5ff" },
                      { name: "Emerald Matrix", hex: "#10e782" },
                      { name: "Tokyo Violet", hex: "#bd93f9" },
                      { name: "Amber Jumbotron", hex: "#ffb347" },
                      { name: "Hot Crimson", hex: "#ff3366" },
                      { name: "Pure Neon", hex: "#ffffff" }
                    ]

                    Rectangle {
                      required property var modelData
                      Layout.fillWidth: true
                      height: 32
                      radius: 8
                      color: modelData.hex
                      border.color: win.accentColor.toString().toLowerCase() === modelData.hex.toLowerCase() ? "#ffffff" : win.borderMuted
                      border.width: win.accentColor.toString().toLowerCase() === modelData.hex.toLowerCase() ? 2.5 : 1

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          win.accentColor = modelData.hex
                          win.saveCurrentConfig()
                        }
                      }
                    }
                  }
                }
              }
            }

            // Card Opacity
            Rectangle {
              Layout.fillWidth: true
              height: 85
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "Billboard Surface Translucency"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: Math.round(win.cardOpacity * 100) + "%"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: win.accentColor
                  }
                }

                ModernSlider {
                  from: 0.30
                  to: 1.0
                  stepSize: 0.02
                  value: win.cardOpacity
                  onMoved: function(v) {
                    win.cardOpacity = Math.round(v * 100) / 100
                    win.saveCurrentConfig()
                  }
                }
              }
            }

            // Card Corner Radius
            Rectangle {
              Layout.fillWidth: true
              height: 85
              radius: 10
              color: win.bgCard
              border.color: win.borderMuted
              border.width: 1

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 6

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    text: "Corner Chamfer / Radius"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#ffffff"
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    text: win.cardRadius + " px"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    color: win.accentColor
                  }
                }

                ModernSlider {
                  from: 4
                  to: 24
                  stepSize: 1
                  value: win.cardRadius
                  onMoved: function(v) {
                    win.cardRadius = Math.round(v)
                    win.saveCurrentConfig()
                  }
                }
              }
            }
          }
        }

        // =========================================================
        // TAB 4: LIVE TELEMETRY
        // =========================================================
        ScrollView {
          anchors.fill: parent
          visible: win.activeTab === 4
          clip: true

          ColumnLayout {
            width: parent.width - 14
            spacing: 12

            Text {
              text: "LIVE HARDWARE TELEMETRY SENSORS"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              font.weight: Font.Bold
              color: win.accentColor
              font.letterSpacing: 1
            }

            GridLayout {
              columns: win.isCompact ? 1 : 2
              Layout.fillWidth: true
              rowSpacing: 10
              columnSpacing: 10

              Rectangle {
                Layout.fillWidth: true
                height: 90
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 3
                  RowLayout {
                    Text { text: "󰍛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#ff3388" }
                    Text { text: "CPU TELEMETRY"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
                  }
                  Text { text: "Load: " + win.liveHw.cpuLoad; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; color: "#ffffff" }
                  Text { text: "Package Temp: " + win.liveHw.cpuTemp + "°C"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: "#ffb347" }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 90
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 3
                  RowLayout {
                    Text { text: "󰘚"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#00e5ff" }
                    Text { text: "RAM STORAGE"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
                  }
                  Text { text: win.liveHw.ramUsed + " / " + win.liveHw.ramTotal; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; color: "#ffffff" }
                  Text { text: "Memory Pressure: " + win.liveHw.ramPercent + "%"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: "#00e5ff" }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 90
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 3
                  RowLayout {
                    Text { text: "󰢮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#10e782" }
                    Text { text: "COOLING & FANS"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
                  }
                  Text { text: (win.liveHw.fanSpeed > 0 ? (win.liveHw.fanSpeed + " RPM") : "SILENT / PASSIVE"); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; color: "#10e782" }
                  Text { text: "Status: Thermally stable"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: "#8a8aa8" }
                }
              }

              Rectangle {
                Layout.fillWidth: true
                height: 90
                radius: 10
                color: win.bgCard
                border.color: win.borderMuted
                border.width: 1

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: 12
                  spacing: 3
                  RowLayout {
                    Text { text: "󰍛"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: "#ffb347" }
                    Text { text: "GPU ACCELERATOR"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; font.bold: true; color: "#ffffff" }
                  }
                  Text { text: (win.liveHw.gpuTemp > 0 ? (win.liveHw.gpuTemp + "°C") : "STANDBY"); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; font.bold: true; color: "#ffffff" }
                  Text { text: "Hardware Accel: Active (FBO)"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 10; color: "#ffb347" }
                }
              }
            }

            PillButton {
              label: "Launch Full Diagnostics (btop)"
              active: true
              accentColor: win.accentColor
              onClicked: {
                Quickshell.execDetached(["foot", "-e", "btop"])
              }
            }
          }
        }
      }

      // -------------------------------------------------------------
      // FOOTER ACTIONS
      // -------------------------------------------------------------
      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: win.borderMuted
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        PillButton {
          label: "󰑓 Re-sync Weather & Clock"
          active: false
          accentColor: win.accentColor
          onClicked: {
            win.saveCurrentConfig()
          }
        }

        Item { Layout.fillWidth: true }

        PillButton {
          label: "Done & Close"
          active: true
          accentColor: win.accentColor
          onClicked: Qt.quit()
        }
      }
    }
  }

  // =============================================================
  // REUSABLE HELPER COMPONENTS
  // =============================================================

  // Billboard Custom Name & Toggle Card
  component BillboardEditorCard: Rectangle {
    id: bCard
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    property color accentColor: "#e20074"
    property string customName: ""
    signal toggled()
    signal nameEdited(string newName)

    Layout.fillWidth: true
    implicitHeight: bCol.implicitHeight + 20
    radius: 10
    color: win.bgCard
    border.color: checked ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.45) : win.borderMuted
    border.width: 1

    ColumnLayout {
      id: bCol
      anchors.fill: parent
      anchors.margins: 12
      spacing: 8

      // Header row with toggle switch
      RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
          width: 32
          height: 32
          radius: 16
          color: bCard.checked ? Qt.rgba(bCard.accentColor.r, bCard.accentColor.g, bCard.accentColor.b, 0.25) : win.bgInput
          border.color: bCard.checked ? bCard.accentColor : win.borderMuted
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: bCard.icon
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: bCard.checked ? bCard.accentColor : "#8888a8"
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1
          Text {
            text: bCard.title
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: bCard.checked ? "#ffffff" : "#a0a0b8"
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Text {
            text: bCard.subtitle
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 9
            color: "#787898"
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Toggle Pill
        Rectangle {
          width: 44
          height: 22
          radius: 11
          color: bCard.checked ? bCard.accentColor : Qt.rgba(0.2, 0.2, 0.28, 0.9)
          border.color: bCard.checked ? Qt.lighter(bCard.accentColor, 1.2) : win.borderMuted
          border.width: 1

          Behavior on color { ColorAnimation { duration: 180 } }

          Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: bCard.checked ? parent.width - width - 3 : 3

            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: bCard.toggled()
          }
        }
      }

      // Editable Billboard Header Name Input Field
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: bCard.checked

        Text {
          text: "Billboard Title:"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 10
          font.bold: true
          color: bCard.accentColor
        }

        Rectangle {
          Layout.fillWidth: true
          height: 30
          radius: 6
          color: win.bgInput
          border.color: nameInput.activeFocus ? bCard.accentColor : win.borderMuted
          border.width: 1

          TextInput {
            id: nameInput
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            text: bCard.customName
            color: "#ffffff"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.bold: true
            selectByMouse: true
            clip: true

            onEditingFinished: {
              bCard.nameEdited(nameInput.text)
            }
          }
        }
      }
    }
  }

  component PillButton: Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    property color accentColor: "#e20074"
    signal clicked()

    implicitWidth: pillText.implicitWidth + 18
    implicitHeight: 28
    radius: 7
    color: active ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35) : (pillMouse.containsMouse ? win.bgInput : Qt.rgba(0.14, 0.14, 0.20, 0.9))
    border.color: active ? accentColor : win.borderMuted
    border.width: active ? 1.5 : 1

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
      id: pillText
      anchors.centerIn: parent
      text: pill.label
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 10
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

      scale: sldMouse.pressed ? 1.25 : (sldMouse.containsMouse ? 1.1 : 1.0)
      Behavior on scale { NumberAnimation { duration: 100 } }
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
}
