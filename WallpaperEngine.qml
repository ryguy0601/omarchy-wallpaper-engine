import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Hyprland

Item {
  id: root

  property var shell: null
  property var manifest: null

  // Configuration Properties (loaded dynamically from ~/.config/wallpaper-engine/config.json)
  property int cfgClockSize: 64
  property bool cfgFormat12h: true
  property bool cfgShowAmPm: true
  property bool cfgShowSeconds: false

  property int cfgVisBars: 32
  property string cfgWeatherOverride: "auto" // "auto", "rain", "snow", "cloudy", "thunder", "clear", "fog"

  // Billboard visibility toggles
  property bool cfgShowClock: true
  property bool cfgShowCpu: true
  property bool cfgShowRam: true
  property bool cfgShowGpu: true
  property bool cfgShowMedia: true

  // Billboard custom title names
  property string cfgNameClock: "LIVE BROADCAST // ONE TIMES SQUARE NYC"
  property string cfgNameCpu: "NASDAQ // CPU CORE"
  property string cfgNameRam: "BANK // RAM STORAGE"
  property string cfgNameGpu: "POWER // GPU & FANS"
  property string cfgNameMedia: "BROADWAY JUMBOTRON"

  property color cfgAccent: "#e20074"
  property string cfgCardBg: "#0c0c12"
  property real cfgCardOpacity: 0.88
  property int cfgCardRadius: 12
  property bool cfgBorderGlow: true
  property real cfgBorderWidth: 1.5

  readonly property color cardFillColor: Qt.rgba(0.06, 0.05, 0.09, cfgCardOpacity)
  readonly property color cardBorderColor: Qt.rgba(cfgAccent.r, cfgAccent.g, cfgAccent.b, 0.45)
  readonly property color surfaceFillColor: Qt.rgba(0.09, 0.07, 0.13, 0.92)

  // Live FileView for Hot-Reloading configuration
  property FileView configFile: FileView {
    id: configFile
    path: Quickshell.env("HOME") + "/.config/wallpaper-engine/config.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
  }

  function applyConfig(rawJson) {
    try {
      var d = JSON.parse(rawJson)
      if (d.clock) {
        if (typeof d.clock.format12h === "boolean") root.cfgFormat12h = d.clock.format12h
        if (typeof d.clock.showAmPm === "boolean") root.cfgShowAmPm = d.clock.showAmPm
        if (typeof d.clock.showSeconds === "boolean") root.cfgShowSeconds = d.clock.showSeconds
        if (typeof d.clock.fontSize === "number") root.cfgClockSize = Math.max(36, Math.min(100, d.clock.fontSize))
      }
      if (d.style) {
        if (d.style.accentColor) root.cfgAccent = d.style.accentColor
        if (d.style.cardBackground) root.cfgCardBg = d.style.cardBackground
        if (typeof d.style.cardOpacity === "number") root.cfgCardOpacity = Math.max(0.1, Math.min(1.0, d.style.cardOpacity))
        if (typeof d.style.cardRadius === "number") root.cfgCardRadius = Math.max(0, Math.min(30, d.style.cardRadius))
      }
      if (d.billboards) {
        if (typeof d.billboards.clock === "boolean") root.cfgShowClock = d.billboards.clock
        if (typeof d.billboards.cpu === "boolean") root.cfgShowCpu = d.billboards.cpu
        if (typeof d.billboards.ram === "boolean") root.cfgShowRam = d.billboards.ram
        if (typeof d.billboards.gpu === "boolean") root.cfgShowGpu = d.billboards.gpu
        if (typeof d.billboards.media === "boolean") root.cfgShowMedia = d.billboards.media

        if (typeof d.billboards.nameClock === "string" && d.billboards.nameClock.length > 0) root.cfgNameClock = d.billboards.nameClock
        if (typeof d.billboards.nameCpu === "string" && d.billboards.nameCpu.length > 0) root.cfgNameCpu = d.billboards.nameCpu
        if (typeof d.billboards.nameRam === "string" && d.billboards.nameRam.length > 0) root.cfgNameRam = d.billboards.nameRam
        if (typeof d.billboards.nameGpu === "string" && d.billboards.nameGpu.length > 0) root.cfgNameGpu = d.billboards.nameGpu
        if (typeof d.billboards.nameMedia === "string" && d.billboards.nameMedia.length > 0) root.cfgNameMedia = d.billboards.nameMedia
      } else if (d.modules) {
        if (typeof d.modules.clock === "boolean") root.cfgShowClock = d.modules.clock
        if (typeof d.modules.sysinfo === "boolean") {
          root.cfgShowCpu = d.modules.sysinfo
          root.cfgShowRam = d.modules.sysinfo
          root.cfgShowGpu = d.modules.sysinfo
        }
        if (typeof d.modules.media === "boolean") root.cfgShowMedia = d.modules.media
      }
      if (d.weatherEffect) {
        root.cfgWeatherOverride = String(d.weatherEffect).toLowerCase()
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

  // =========================================================================
  // LIVE REAL-WORLD WEATHER FETCHING & CLASSIFICATION
  // =========================================================================
  property string weatherCity: "Ronkonkoma"
  property string weatherTemp: "56°F"
  property string weatherConditionRaw: "Overcast"
  property string weatherWind: "↙16mph"
  property string weatherIcon: ""

  readonly property string effectiveWeatherType: {
    if (root.cfgWeatherOverride && root.cfgWeatherOverride !== "auto") {
      return root.cfgWeatherOverride.toLowerCase()
    }
    var c = root.weatherConditionRaw.toLowerCase()
    if (c.indexOf("snow") !== -1 || c.indexOf("blizzard") !== -1 || c.indexOf("sleet") !== -1 || c.indexOf("ice") !== -1) {
      return "snow"
    }
    if (c.indexOf("thunder") !== -1 || c.indexOf("storm") !== -1 || c.indexOf("lightning") !== -1) {
      return "thunder"
    }
    if (c.indexOf("rain") !== -1 || c.indexOf("drizzle") !== -1 || c.indexOf("shower") !== -1) {
      return "rain"
    }
    if (c.indexOf("fog") !== -1 || c.indexOf("mist") !== -1 || c.indexOf("haze") !== -1) {
      return "fog"
    }
    if (c.indexOf("cloud") !== -1 || c.indexOf("overcast") !== -1) {
      return "cloudy"
    }
    return "clear"
  }

  Process {
    id: weatherFetchProc
    command: [
      "bash", "-c",
      "loc=$(omarchy-weather-location 2>/dev/null || echo ''); curl -fsS --max-time 3 \"https://wttr.in/${loc}?format=%C|%t|%w\" 2>/dev/null || echo 'Overcast|+56°F|↙16mph'"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str.length > 0) {
          var parts = str.split("|")
          if (parts.length >= 2) {
            root.weatherConditionRaw = parts[0].trim()
            root.weatherTemp = parts[1].replace("+", "").trim()
            if (parts.length >= 3) root.weatherWind = parts[2].trim()
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

  Process {
    id: weatherLocProc
    command: ["/usr/share/omarchy/bin/omarchy", "weather", "location"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var str = String(text || "").trim()
        if (str.length > 0) root.weatherCity = str
      }
    }
  }

  Timer {
    interval: 180000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      weatherFetchProc.running = true
      weatherIconProc.running = true
      weatherLocProc.running = true
    }
  }

  // =========================================================================
  // INTEGRATED HARDWARE SENSOR TELEMETRY
  // =========================================================================
  property string sysCpuLoad: "0.0"
  property int sysCpuTemp: 45
  property int sysFanSpeed: 0
  property string sysRamUsed: "0G"
  property string sysRamTotal: "0G"
  property int sysRamPercent: 0
  property int sysGpuTemp: 0

  Process {
    id: hwinfoProc
    command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "hwinfo"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          if (d.cpuLoad !== undefined) root.sysCpuLoad = String(d.cpuLoad)
          if (d.ramUsed) root.sysRamUsed = d.ramUsed
          if (d.ramTotal) root.sysRamTotal = d.ramTotal
          if (d.ramPercent !== undefined) root.sysRamPercent = d.ramPercent
          if (d.cpuTemp !== undefined) root.sysCpuTemp = d.cpuTemp
          if (d.fanSpeed !== undefined) root.sysFanSpeed = d.fanSpeed
          if (d.gpuTemp !== undefined) root.sysGpuTemp = d.gpuTemp
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 2500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: hwinfoProc.running = true
  }

  // =========================================================================
  // MPRIS MEDIA STATE
  // =========================================================================
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
  readonly property string trackArtist: activePlayer && activePlayer.trackArtist ? activePlayer.trackArtist : "Play audio to animate building lights"
  readonly property string trackAlbum: activePlayer && activePlayer.trackAlbum ? activePlayer.trackAlbum : ""
  readonly property string trackArt: activePlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""

  // =========================================================================
  // AUDIO SPECTRUM STATE & 60 FPS PHYSICS (CAVA)
  // =========================================================================
  property var rawBars: []
  property var displayBars: []
  property var peakBars: []
  property real animTime: 0
  property real idlePhase: 0
  property bool hasActiveAudio: false
  readonly property bool isSoundActive: root.hasActiveAudio || root.isPlaying

  // Atmospheric lightning state
  property real lightningAlpha: 0
  property real nextLightningTime: 12

  // Weather Particles State
  property var rainDrops: []
  property var snowFlakes: []
  property var cloudPuffs: []

  Component.onCompleted: {
    var b = []
    var p = []
    for (var i = 0; i < root.cfgVisBars; i++) {
      b.push(0)
      p.push(0)
    }
    rawBars = b
    displayBars = b
    peakBars = p

    // Optimized 35 Rain Drops
    var r = []
    for (var rd = 0; rd < 35; rd++) {
      r.push({
        x: Math.random() * 3840,
        y: Math.random() * 2160,
        vy: 16 + Math.random() * 9,
        len: 12 + Math.random() * 10
      })
    }
    rainDrops = r

    // Optimized 25 Snow Flakes
    var s = []
    for (var sn = 0; sn < 25; sn++) {
      s.push({
        x: Math.random() * 3840,
        y: Math.random() * 2160,
        vy: 1.4 + Math.random() * 2.2,
        size: 1.2 + Math.random() * 2.4,
        drift: Math.random() * 6.28
      })
    }
    snowFlakes = s

    // Optimized 3 Cloud Puffs
    var c = []
    for (var cp = 0; cp < 3; cp++) {
      c.push({
        x: (cp * 1280) % 3840,
        y: 80 + (cp % 3) * 60,
        radius: 240 + (cp % 3) * 80,
        speed: 0.18 + (cp % 3) * 0.10
      })
    }
    cloudPuffs = c

    updateTime()
  }

  Timer {
    interval: root.isSoundActive ? 33 : 100
    running: true
    repeat: true
    onTriggered: {
      var dt = (interval / 1000.0)
      root.animTime += dt
      root.idlePhase += dt * 2.5
      var disp = []
      var peaks = []
      var audioSum = 0

      for (var i = 0; i < root.cfgVisBars; i++) {
        var raw = (root.rawBars && root.rawBars[i]) ? root.rawBars[i] : 0
        audioSum += raw

        var cur = (root.displayBars && root.displayBars[i]) ? root.displayBars[i] : 0
        // Strictly only real sound from PipeWire — no fake idle wave so buildings don't change color without sound
        var target = raw

        if (target > cur) {
          cur += (target - cur) * 0.45
        } else {
          cur += (target - cur) * 0.16
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

      root.hasActiveAudio = (audioSum > 3)
      root.displayBars = disp
      root.peakBars = peaks

      // Thunderstorm Lightning Physics
      if (root.effectiveWeatherType === "thunder") {
        if (root.animTime > root.nextLightningTime) {
          root.lightningAlpha = 0.38
          root.nextLightningTime = root.animTime + 8 + Math.random() * 12
        }
      }
      if (root.lightningAlpha > 0) {
        root.lightningAlpha = Math.max(0, root.lightningAlpha - 0.025)
      }
    }
  }

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
    onTriggered: cavaProc.running = true
  }

  Process {
    id: openGuiProc
    command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-engine", "gui"]
  }

  Process {
    id: runCmdProc
  }

  function runCmd(cmd) {
    runCmdProc.command = ["sh", "-c", cmd]
    runCmdProc.running = true
  }

  function onBillboardClick() {
    openGuiProc.running = true
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

      // Click mask: Only interactive individual building billboards capture clicks!
      mask: Region {
        Region { item: timeBillboard }
        Region { item: cpuBillboard }
        Region { item: mediaBillboard }
        Region { item: ramBillboard }
        Region { item: gpuBillboard }
      }

      Item {
        anchors.fill: parent
        property bool isPortrait: parent.width < 1400 && parent.width < parent.height

        // =========================================================================
        // ANIMATED NIGHT CITY SKYLINE (TWO ROWS OF BUILDINGS) & WEATHER CANVAS
        // =========================================================================
        Canvas {
          id: cityCanvas
          anchors.fill: parent
          renderTarget: Canvas.FramebufferObject
          renderStrategy: Canvas.Cooperative

          // Pause animation if any fullscreen window is active on this monitor's workspace
          readonly property bool isObscured: {
            var ws = Hyprland.focusedWorkspace
            return ws !== null && ws.hasFullscreen
          }

          Timer {
            interval: root.isSoundActive ? 33 : 100
            running: !cityCanvas.isObscured
            repeat: true
            onTriggered: cityCanvas.requestPaint()
          }

          onPaint: {
            var ctx = getContext("2d")
            var W = width
            var H = height
            var time = root.animTime
            var isSoundPlaying = root.isSoundActive
            var weather = root.effectiveWeatherType

            // 1. Sky Gradient
            var skyGrad = ctx.createLinearGradient(0, 0, 0, H)
            if (weather === "rain" || weather === "thunder") {
              skyGrad.addColorStop(0, "#020204")
              skyGrad.addColorStop(0.4, "#06050b")
              skyGrad.addColorStop(0.7, "#0c0816")
              skyGrad.addColorStop(1, "#07050d")
            } else if (weather === "cloudy") {
              skyGrad.addColorStop(0, "#040307")
              skyGrad.addColorStop(0.4, "#080612")
              skyGrad.addColorStop(0.7, "#12091d")
              skyGrad.addColorStop(1, "#0a0613")
            } else if (weather === "snow") {
              skyGrad.addColorStop(0, "#050409")
              skyGrad.addColorStop(0.4, "#0a0815")
              skyGrad.addColorStop(0.7, "#150d22")
              skyGrad.addColorStop(1, "#0e0918")
            } else {
              skyGrad.addColorStop(0, "#030206")
              skyGrad.addColorStop(0.35, "#070510")
              skyGrad.addColorStop(0.65, "#10071a")
              skyGrad.addColorStop(0.88, "#1e0926")
              skyGrad.addColorStop(1, "#090510")
            }
            ctx.fillStyle = skyGrad
            ctx.fillRect(0, 0, W, H)

            // Lightning Flash (thunder)
            if (root.lightningAlpha > 0) {
              ctx.fillStyle = "rgba(215, 225, 255, " + root.lightningAlpha + ")"
              ctx.fillRect(0, 0, W, H)
            }

            // 2. Stars (Optimized 20 key twinkling stars)
            var starOpacityMult = (weather === "rain" || weather === "thunder") ? 0.25 : ((weather === "cloudy") ? 0.60 : 1.0)
            for (var s = 0; s < 20; s++) {
              var sx = (s * 197.3) % W
              var sy = (s * 89.1) % (H * 0.48)
              var tw = (0.35 + 0.65 * (0.5 + 0.5 * Math.sin(time * 2.2 + s * 1.6))) * starOpacityMult
              if (s % 6 === 0) ctx.fillStyle = "rgba(255, 96, 136, " + tw + ")"
              else if (s % 4 === 0) ctx.fillStyle = "rgba(0, 229, 255, " + tw + ")"
              else ctx.fillStyle = "rgba(255, 255, 255, " + tw + ")"
              var sr = (s % 5 === 0) ? 2.5 : 1.5
              ctx.beginPath()
              ctx.arc(sx, sy, sr, 0, Math.PI * 2)
              ctx.fill()
            }

            // 3. Moon
            var mx = W * 0.88
            var my = H * 0.16
            var moonHalo = ctx.createRadialGradient(mx, my, 10, mx, my, 100)
            moonHalo.addColorStop(0, (weather === "rain" || weather === "thunder") ? "rgba(226, 0, 116, 0.15)" : "rgba(226, 0, 116, 0.30)")
            moonHalo.addColorStop(0.5, "rgba(226, 0, 116, 0.08)")
            moonHalo.addColorStop(1, "rgba(226, 0, 116, 0)")
            ctx.fillStyle = moonHalo
            ctx.beginPath()
            ctx.arc(mx, my, 100, 0, Math.PI * 2)
            ctx.fill()

            ctx.fillStyle = "#ffe6f2"
            ctx.beginPath()
            ctx.arc(mx, my, 30, 0, Math.PI * 2)
            ctx.fill()
            ctx.fillStyle = "#080512"
            ctx.beginPath()
            ctx.arc(mx + 12, my - 6, 27, 0, Math.PI * 2)
            ctx.fill()
            ctx.strokeStyle = "rgba(226, 0, 116, 0.85)"
            ctx.lineWidth = 1.6
            ctx.beginPath()
            ctx.arc(mx, my, 31, 0, Math.PI * 2)
            ctx.stroke()

            // Overcast Clouds
            if (weather === "cloudy" || weather === "rain" || weather === "thunder" || weather === "fog") {
              for (var cp = 0; cp < root.cloudPuffs.length; cp++) {
                var cloud = root.cloudPuffs[cp]
                cloud.x = (cloud.x + cloud.speed)
                if (cloud.x > W + cloud.radius) cloud.x = -cloud.radius
                var cGrad = ctx.createRadialGradient(cloud.x, cloud.y, 10, cloud.x, cloud.y, cloud.radius)
                cGrad.addColorStop(0, "rgba(22, 16, 32, 0.45)")
                cGrad.addColorStop(0.6, "rgba(16, 12, 24, 0.25)")
                cGrad.addColorStop(1, "rgba(10, 8, 16, 0)")
                ctx.fillStyle = cGrad
                ctx.beginPath()
                ctx.arc(cloud.x, cloud.y, cloud.radius, 0, Math.PI * 2)
                ctx.fill()
              }
            }

            // Distant Silhouettes
            var numBg = 30
            var bgColW = W / numBg
            ctx.fillStyle = "#080710"
            for (var bg = 0; bg < numBg; bg++) {
              var bgx = bg * bgColW
              var bgh = H * (0.35 + ((bg * 11 + 3) % 13) * 0.02)
              ctx.fillRect(bgx, H - bgh, bgColW * 0.95, bgh)
              if (bg % 3 === 0) {
                var dMidX = bgx + bgColW * 0.45
                ctx.strokeStyle = isSoundPlaying ? "#e20074" : "rgba(35, 30, 48, 0.5)"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(dMidX, H - bgh)
                ctx.lineTo(dMidX, H - bgh - 20)
                ctx.stroke()
                ctx.fillStyle = isSoundPlaying ? ((bg % 2 === 0) ? "#ff3388" : "#00e5ff") : "rgba(140, 25, 40, 0.35)"
                ctx.beginPath()
                ctx.arc(dMidX, H - bgh - 20, 1.8, 0, Math.PI * 2)
                ctx.fill()
              }
            }

            var barCount = root.cfgVisBars
            var isPort = (W < 1400 && W < H)

            // =========================================================================
            // TIMES SQUARE CANYON: 5 DEDICATED FLAGSHIP SKYSCRAPERS & MIDGROUND SKYLINE
            // =========================================================================

            // 1. Distant Background Fill Towers
            var numBgSky = 18
            var colW_bg = W / numBgSky
            for (var bi = 0; bi < numBgSky; bi++) {
              var bgx = bi * colW_bg + colW_bg * 0.05
              var bgh = H * (0.32 + ((bi * 7 + 3) % 7) * 0.03)
              ctx.fillStyle = "#0c0a15"
              ctx.fillRect(bgx, H - bgh, colW_bg * 0.90, bgh)
              ctx.strokeStyle = "rgba(40, 32, 54, 0.35)"
              ctx.lineWidth = 1
              ctx.strokeRect(bgx, H - bgh, colW_bg * 0.90, bgh)
            }

            // Function to render an authentic Times Square skyscraper
            function drawTower(cx, w, h, barIdx, accentColor, hasAntenna, isCenter) {
              var left = cx - w / 2
              var top = H - h
              var raw = (root.displayBars && root.displayBars[barIdx]) ? root.displayBars[barIdx] : 0
              var aud = Math.min(1.0, (raw / 100.0) * 1.6)
              if (isSoundPlaying && aud < 0.22 && root.isPlaying) {
                aud = 0.22 + 0.16 * Math.sin(time * 3.5 + barIdx * 0.8)
              }

              // Building body gradient
              var bGrad = ctx.createLinearGradient(left, top, left + w, H)
              bGrad.addColorStop(0, "#161226")
              bGrad.addColorStop(0.4, "#0e0b19")
              bGrad.addColorStop(1, "#07050e")
              ctx.fillStyle = bGrad
              ctx.fillRect(left, top, w, h)

              // Outer neon facade trim
              ctx.strokeStyle = isSoundPlaying ? accentColor : "rgba(50, 42, 65, 0.40)"
              ctx.lineWidth = 1.5
              ctx.strokeRect(left, top, w, h)

              // Antenna / Spire
              if (hasAntenna) {
                var antTop = top - (isCenter ? 55 : 32)
                ctx.strokeStyle = isSoundPlaying ? "#ffffff" : "rgba(160, 150, 180, 0.65)"
                ctx.lineWidth = isCenter ? 2.5 : 1.5
                ctx.beginPath()
                ctx.moveTo(cx, top)
                ctx.lineTo(cx, antTop)
                ctx.stroke()

                // Beacon / Crystal Ball
                if (isCenter) {
                  // THE TIMES SQUARE NEW YEAR'S EVE CRYSTAL BALL DROP!
                  var ballPulse = isSoundPlaying ? (1.0 + aud * 0.5) : 1.0
                  var ballY = antTop + 14

                  var bGlow = ctx.createRadialGradient(cx, ballY, 2, cx, ballY, 28 * ballPulse)
                  bGlow.addColorStop(0, isSoundPlaying ? "rgba(0, 229, 255, 0.70)" : "rgba(0, 229, 255, 0.25)")
                  bGlow.addColorStop(0.5, isSoundPlaying ? "rgba(226, 0, 116, 0.35)" : "rgba(226, 0, 116, 0.10)")
                  bGlow.addColorStop(1, "rgba(0, 0, 0, 0)")
                  ctx.fillStyle = bGlow
                  ctx.beginPath()
                  ctx.arc(cx, ballY, 28 * ballPulse, 0, Math.PI * 2)
                  ctx.fill()

                  ctx.fillStyle = isSoundPlaying ? "#ffffff" : "#ffe6f2"
                  ctx.beginPath()
                  ctx.arc(cx, ballY, 7 * ballPulse, 0, Math.PI * 2)
                  ctx.fill()

                  ctx.strokeStyle = isSoundPlaying ? "#00e5ff" : "#e20074"
                  ctx.lineWidth = 1.6
                  ctx.beginPath()
                  ctx.arc(cx, ballY, 10 * ballPulse, 0, Math.PI * 2)
                  ctx.stroke()
                } else {
                  ctx.fillStyle = isSoundPlaying ? accentColor : "rgba(160, 30, 45, 0.6)"
                  ctx.beginPath()
                  ctx.arc(cx, antTop, 2.5, 0, Math.PI * 2)
                  ctx.fill()
                }
              }

              // Skyscraper Window Matrix (spanning full height)
              var stepY = 19
              var winH = 11
              var floors = Math.floor((h - 35) / stepY)
              var stepX = 22
              var winW = 14
              var cols = Math.floor((w - 20) / stepX)
              var padX = (w - (cols * stepX - (stepX - winW))) / 2

              for (var fl = 0; fl < floors; fl++) {
                var flProg = fl / floors
                var winY = H - 24 - fl * stepY - winH
                if (winY < top + 25) continue

                var isAudioLit = isSoundPlaying && (flProg <= aud * 1.15)

                for (var c = 0; c < cols; c++) {
                  var winX = left + padX + c * stepX
                  if (isAudioLit) {
                    if (flProg > 0.8) ctx.fillStyle = "#ffffff"
                    else if (flProg > 0.5) ctx.fillStyle = "#00e5ff"
                    else ctx.fillStyle = (flProg > 0.25) ? "#ff3399" : "#e20074"
                    ctx.fillRect(winX, winY, winW, winH)
                  } else {
                    var seed = Math.abs(Math.sin(cx * 11.13 + fl * 23.41 + c * 47.19)) * 10000
                    var rand = seed - Math.floor(seed)
                    if (rand < 0.32) {
                      ctx.fillStyle = rand < 0.12 ? "rgba(255, 240, 215, 0.42)" : (rand < 0.24 ? "rgba(255, 225, 175, 0.30)" : "rgba(195, 225, 255, 0.25)")
                      ctx.fillRect(winX, winY, winW, winH)
                    }
                  }
                }
              }
            }

            // 2. THE 5 FLAGSHIP SKYSCRAPERS ACROSS TIMES SQUARE
            var t1_cx = isPort ? (W * 0.50) : Math.max(115, Math.round(W * 0.10))
            var t1_w = isPort ? Math.min(280, W - 30) : Math.min(260, Math.max(195, W * 0.16 + 24))
            var t1_h = H * 0.78

            var t2_cx = isPort ? (W * 0.50) : Math.round(W * 0.28)
            var t2_w = isPort ? Math.min(280, W - 30) : Math.min(260, Math.max(195, W * 0.16 + 24))
            var t2_h = H * 0.60

            var t3_cx = (W * 0.50)
            var t3_w = isPort ? Math.min(410, W - 20) : Math.min(410, Math.max(330, W * 0.26 + 30))
            var t3_h = H * 0.88

            var t4_cx = isPort ? (W * 0.50) : Math.round(W * 0.72)
            var t4_w = isPort ? Math.min(280, W - 30) : Math.min(260, Math.max(195, W * 0.16 + 24))
            var t4_h = H * 0.60

            var t5_cx = isPort ? (W * 0.50) : Math.min(W - 145, Math.round(W * 0.90))
            var t5_w = isPort ? Math.min(340, W - 30) : Math.min(330, Math.max(255, W * 0.21 + 24))
            var t5_h = H * 0.78

            // Tower 1 (Far-Left Skyscraper: CPU Telemetry Tower)
            drawTower(t1_cx, t1_w, t1_h, 4, "#ff3388", true, false)

            // Tower 2 (Mid-Left Skyscraper: RAM Memory Tower)
            drawTower(t2_cx, t2_w, t2_h, 9, "#00e5ff", true, false)

            // Tower 3 (Center Landmark Skyscraper: ONE TIMES SQUARE)
            // Stepped Crown Setback Tier
            ctx.fillStyle = "#120e20"
            ctx.fillRect(t3_cx - (t3_w * 0.25), H - t3_h - 16, t3_w * 0.5, 16)
            ctx.strokeStyle = isSoundPlaying ? "#00e5ff" : "rgba(0, 229, 255, 0.35)"
            ctx.lineWidth = 1.2
            ctx.strokeRect(t3_cx - (t3_w * 0.25), H - t3_h - 16, t3_w * 0.5, 16)

            drawTower(t3_cx, t3_w, t3_h, 16, "#e20074", true, true)

            // Tower 4 (Mid-Right Skyscraper: GPU & Cooling Tower)
            drawTower(t4_cx, t4_w, t4_h, 22, "#10e782", true, false)

            // Tower 5 (Far-Right Skyscraper: Broadway Media Jumbotron Tower)
            drawTower(t5_cx, t5_w, t5_h, 28, "#00e5ff", true, false)

            // 3. Times Square Vertical Neon Blade Signs
            if (W > 1050 && !isPort) {
              // Broadway Blade Sign (flanking left of One Times Square)
              var s1X = t3_cx - (t3_w / 2 + 18)
              var s1Y = H * 0.46
              ctx.fillStyle = "rgba(10, 8, 16, 0.92)"
              ctx.fillRect(s1X, s1Y, 14, 115)
              ctx.strokeStyle = isSoundPlaying ? "#00e5ff" : "rgba(0, 229, 255, 0.4)"
              ctx.lineWidth = 1
              ctx.strokeRect(s1X, s1Y, 14, 115)
              ctx.fillStyle = isSoundPlaying ? "#00e5ff" : "#88ccdd"
              ctx.font = "bold 8.5px monospace"
              ctx.textAlign = "center"
              var let1 = ["B","R","O","A","D","W","A","Y"]
              for (var i1 = 0; i1 < let1.length; i1++) ctx.fillText(let1[i1], s1X + 7, s1Y + 15 + i1 * 12.5)

              // NYC Blade Sign (flanking right of One Times Square)
              var s2X = t3_cx + (t3_w / 2 + 5)
              var s2Y = H * 0.48
              ctx.fillStyle = "rgba(10, 8, 16, 0.92)"
              ctx.fillRect(s2X, s2Y, 14, 65)
              ctx.strokeStyle = isSoundPlaying ? "#e20074" : "rgba(226, 0, 116, 0.4)"
              ctx.lineWidth = 1
              ctx.strokeRect(s2X, s2Y, 14, 65)
              ctx.fillStyle = isSoundPlaying ? "#ff3388" : "#dd88aa"
              var let2 = ["N","Y","C"]
              for (var i2 = 0; i2 < let2.length; i2++) ctx.fillText(let2[i2], s2X + 7, s2Y + 18 + i2 * 18)
            }

            // 4. Foreground Shrunk Row (Street Canyon Lower Third)
            var numFg = Math.max(18, Math.min(28, Math.round(W / 95)))
            var colW_fg = W / numFg
            var bW_fg = colW_fg * 0.90

            for (var fg = 0; fg < numFg; fg++) {
              var fgx = fg * colW_fg + colW_fg * 0.05
              var fgIdx = Math.min(barCount - 1, Math.floor((fg / numFg) * barCount))
              var fgRaw = (root.displayBars && root.displayBars[fgIdx]) ? root.displayBars[fgIdx] : 0
              var fgAudio = fgRaw / 100.0
              var fgH = H * (0.22 + ((fg * 7 + 2) % 5) * 0.024)

              var fgGrad = ctx.createLinearGradient(fgx, H - fgH, fgx + bW_fg, H)
              fgGrad.addColorStop(0, "#151124")
              fgGrad.addColorStop(0.5, "#0d0a16")
              fgGrad.addColorStop(1, "#07050d")
              ctx.fillStyle = fgGrad
              ctx.fillRect(fgx, H - fgH, bW_fg, fgH)

              ctx.strokeStyle = isSoundPlaying ? "rgba(226, 0, 116, 0.40)" : "rgba(55, 45, 70, 0.30)"
              ctx.lineWidth = 1
              ctx.strokeRect(fgx, H - fgH, bW_fg, fgH)

              var fgFloors = 8
              var fgCols = 3
              var fgPad = 4
              var fgW = (bW_fg - fgPad * 2 - (fgCols - 1) * 3) / fgCols
              var fgWinH = (fgH - 16) / fgFloors - 3

              for (var ffl = 0; ffl < fgFloors; ffl++) {
                var fflProg = ffl / fgFloors
                var fgWinY = H - 12 - ffl * (fgWinH + 3) - fgWinH
                var isFgAudio = isSoundPlaying && (fflProg <= fgAudio * 1.1)
                var isFgBase = ((fg * 3 + ffl * 4) % 5 === 0)

                for (var fgc = 0; fgc < fgCols; fgc++) {
                  var fgWinX = fgx + fgPad + fgc * (fgW + 3)
                  if (isFgAudio) {
                    if (fflProg > 0.8) ctx.fillStyle = "#ffffff"
                    else if (fflProg > 0.5) ctx.fillStyle = (fg % 2 === 0) ? "#00e5ff" : "#ff80bf"
                    else ctx.fillStyle = (fflProg > 0.25) ? "#ff3399" : "#e20074"
                    ctx.fillRect(fgWinX, fgWinY, fgW, fgWinH)
                  } else if (isFgBase) {
                    ctx.fillStyle = "rgba(255, 235, 205, 0.32)"
                    ctx.fillRect(fgWinX, fgWinY, fgW, fgWinH)
                  }
                }
              }
            }

            // Weather Rain Particles
            if (weather === "rain" || weather === "thunder") {
              ctx.strokeStyle = "rgba(190, 220, 255, 0.60)"
              ctx.lineWidth = 1.3
              ctx.beginPath()
              for (var rd = 0; rd < root.rainDrops.length; rd++) {
                var d = root.rainDrops[rd]
                d.y += d.vy
                d.x -= 2.5
                if (d.y > H) { d.y = -15; d.x = Math.random() * (W + 200); }
                if (d.x < -15) d.x = W + 15
                ctx.moveTo(d.x, d.y)
                ctx.lineTo(d.x - 2.5, d.y + d.len)
              }
              ctx.stroke()
            }

            // Weather Snow Particles
            if (weather === "snow") {
              for (var sn = 0; sn < root.snowFlakes.length; sn++) {
                var sf = root.snowFlakes[sn]
                sf.y += sf.vy
                sf.x += Math.sin(time * 1.5 + sf.drift) * 0.9
                if (sf.y > H) { sf.y = -10; sf.x = Math.random() * W; }
                if (sf.x < -10) sf.x = W + 10
                if (sf.x > W + 10) sf.x = -10
                ctx.fillStyle = "rgba(255, 255, 255, 0.75)"
                ctx.beginPath()
                ctx.arc(sf.x, sf.y, sf.size, 0, Math.PI * 2)
                ctx.fill()
              }
            }

            // Street-Level Fog
            var fogGrad = ctx.createLinearGradient(0, H - 80, 0, H)
            fogGrad.addColorStop(0, "rgba(226, 0, 116, 0)")
            fogGrad.addColorStop(0.7, isSoundPlaying ? "rgba(226, 0, 116, 0.20)" : "rgba(226, 0, 116, 0.08)")
            fogGrad.addColorStop(1, "rgba(7, 5, 12, 0.95)")
            ctx.fillStyle = fogGrad
            ctx.fillRect(0, H - 80, W, 80)
          }
        }

        // =========================================================================
        // TIMES SQUARE MEGA JUMBOTRONS & TELEMETRY BILLBOARDS (ACROSS 5 BUILDINGS)
        // =========================================================================
        Item {
          id: billboardsContainer
          anchors.fill: parent
          property bool isPortrait: parent.isPortrait

          // -----------------------------------------------------------------------
          // BILLBOARD 1: ONE TIMES SQUARE DIGITAL CLOCK & BROADWAY WEATHER TICKER
          // -----------------------------------------------------------------------
          Rectangle {
            id: timeBillboard
            visible: root.cfgShowClock
            x: parent.width * 0.50 - width / 2
            y: parent.isPortrait ? parent.height * 0.08 : Math.round(parent.height * 0.14)
            width: parent.isPortrait ? Math.min(390, parent.width - 30) : Math.min(380, Math.max(300, parent.width * 0.26))
            height: 136
            radius: root.cfgCardRadius
            color: root.cardFillColor
            border.color: root.cardBorderColor
            border.width: root.cfgBorderWidth

            // Cyberpunk Corner Brackets
            Rectangle { x: -2; y: -2; width: 14; height: 3; color: "#00e5ff" }
            Rectangle { x: -2; y: -2; width: 3; height: 14; color: "#00e5ff" }
            Rectangle { x: parent.width - 12; y: -2; width: 14; height: 3; color: "#00e5ff" }
            Rectangle { x: parent.width - 1; y: -2; width: 3; height: 14; color: "#00e5ff" }

            Column {
              anchors.centerIn: parent
              spacing: 5

              // Times Square Broadcast Header
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 7
                Rectangle { width: 5; height: 5; radius: 2.5; color: root.cfgAccent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.cfgNameClock; color: "#a0a0cc"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; Layout.maximumWidth: timeBillboard.width - 40 }
                Rectangle { width: 5; height: 5; radius: 2.5; color: "#00e5ff"; anchors.verticalCenter: parent.verticalCenter }
              }

              // Giant Clock Digits
              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                Text { text: root.currentTime; color: "#ffffff"; font.pixelSize: Math.min(root.cfgClockSize, Math.round(timeBillboard.width * 0.165)); font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                Text { visible: root.cfgShowSeconds; text: root.currentSeconds; color: root.cfgAccent; font.pixelSize: Math.round(Math.min(root.cfgClockSize, timeBillboard.width * 0.165) * 0.45); font.bold: true; font.family: "JetBrainsMono Nerd Font"; anchors.baseline: parent.children[0].baseline }
                Text { visible: root.cfgShowAmPm && root.currentAmPm !== ""; text: root.currentAmPm; color: root.cfgAccent; font.pixelSize: Math.round(Math.min(root.cfgClockSize, timeBillboard.width * 0.165) * 0.38); font.bold: true; font.family: "JetBrainsMono Nerd Font"; anchors.baseline: parent.children[0].baseline }
              }

              // Broadway Weather & News Ticker Ribbon
              Rectangle {
                width: timeBillboard.width - 24
                height: 25
                radius: 6
                color: "#0a0712"
                border.color: "#251d36"
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter

                Row {
                  anchors.centerIn: parent
                  spacing: 7

                  Text { text: root.currentDate; color: "#c2c2d6"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                  Text { text: "•"; color: root.cfgAccent; font.pixelSize: 10 }
                  Row {
                    spacing: 4
                    Text { text: root.weatherIcon; color: root.cfgAccent; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font" }
                    Text { text: root.weatherTemp + "  " + root.weatherConditionRaw; color: "#00e5ff"; font.pixelSize: 10; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                  }
                  Text { visible: root.weatherWind !== ""; text: "•"; color: root.cfgAccent; font.pixelSize: 10 }
                  Text { visible: root.weatherWind !== ""; text: root.weatherWind; color: "#ffb347"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.onBillboardClick()
            }
          }

          // -----------------------------------------------------------------------
          // BILLBOARD 2: CPU TELEMETRY JUMBOTRON (MOUNTED ON FAR-LEFT TOWER)
          // -----------------------------------------------------------------------
          Rectangle {
            id: cpuBillboard
            visible: root.cfgShowCpu
            x: parent.isPortrait ? (parent.width * 0.50 - width / 2) : Math.max(15, Math.round(parent.width * 0.10 - width / 2))
            y: parent.isPortrait ? Math.round(parent.height * 0.22) : Math.round(parent.height * 0.26)
            width: parent.isPortrait ? Math.min(260, parent.width - 40) : Math.min(235, Math.max(175, parent.width * 0.16))
            height: 82
            radius: 10
            color: root.cardFillColor
            border.color: root.cardBorderColor
            border.width: root.cfgBorderWidth

            Rectangle { x: -2; y: -2; width: 10; height: 2.5; color: root.cfgAccent }
            Rectangle { x: -2; y: -2; width: 2.5; height: 10; color: root.cfgAccent }

            Column {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 4

              Row {
                spacing: 6
                width: parent.width
                clip: true
                Text { text: "󰍛"; color: root.cfgAccent; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                Text { text: root.cfgNameCpu; color: "#9a9abb"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.width - 25 }
              }

              Row {
                spacing: 8
                Text { text: "LOAD: " + root.sysCpuLoad; color: "#ffffff"; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                Text { text: "•"; color: "#443c55"; font.pixelSize: 12 }
                Text {
                  text: root.sysCpuTemp + "°C"
                  color: root.sysCpuTemp >= 80 ? "#ff3b69" : (root.sysCpuTemp >= 65 ? "#ffb347" : "#10e782")
                  font.pixelSize: 12
                  font.bold: true
                  font.family: "JetBrainsMono Nerd Font"
                }
              }

              // Segmented Cyber Activity Meter
              Row {
                width: parent.width
                spacing: 2.5
                Repeater {
                  model: 16
                  Rectangle {
                    width: Math.max(4, Math.floor((cpuBillboard.width - 16 - 15 * 2.5) / 16))
                    height: 5
                    radius: 1.5
                    property bool active: (index / 16.0) <= (parseFloat(root.sysCpuLoad) / 8.0)
                    color: active ? ((index > 12) ? "#ff3b69" : ((index > 8) ? "#ffb347" : root.cfgAccent)) : "#181424"
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCmd("foot -e btop 2>/dev/null || true")
            }
          }

          // -----------------------------------------------------------------------
          // BILLBOARD 3: RAM MEMORY LED WALL (MOUNTED ON MID-LEFT TOWER)
          // -----------------------------------------------------------------------
          Rectangle {
            id: ramBillboard
            visible: root.cfgShowRam
            x: parent.isPortrait ? (parent.width * 0.50 - width / 2) : Math.round(parent.width * 0.28 - width / 2)
            y: parent.isPortrait ? Math.round(parent.height * 0.32) : Math.round(parent.height * 0.44)
            width: parent.isPortrait ? Math.min(260, parent.width - 40) : Math.min(235, Math.max(175, parent.width * 0.16))
            height: 82
            radius: 10
            color: root.cardFillColor
            border.color: "#00e5ff"
            border.width: root.cfgBorderWidth

            Rectangle { x: -2; y: -2; width: 10; height: 2.5; color: "#00e5ff" }
            Rectangle { x: -2; y: -2; width: 2.5; height: 10; color: "#00e5ff" }

            Column {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 4

              Row {
                spacing: 6
                width: parent.width
                clip: true
                Text { text: "󰘚"; color: "#00e5ff"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                Text { text: root.cfgNameRam; color: "#9a9abb"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.width - 25 }
              }

              Row {
                spacing: 7
                Text { text: root.sysRamUsed + " / " + root.sysRamTotal; color: "#ffffff"; font.pixelSize: 12; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                Text { text: root.sysRamPercent + "%"; color: "#00e5ff"; font.pixelSize: 11; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
              }

              // Segmented Cyan Memory Gauge
              Row {
                width: parent.width
                spacing: 2.5
                Repeater {
                  model: 16
                  Rectangle {
                    width: Math.max(4, Math.floor((ramBillboard.width - 16 - 15 * 2.5) / 16))
                    height: 5
                    radius: 1.5
                    property bool active: (index / 16.0) <= (root.sysRamPercent / 100.0)
                    color: active ? "#00e5ff" : "#181424"
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCmd("foot -e btop 2>/dev/null || true")
            }
          }

          // -----------------------------------------------------------------------
          // BILLBOARD 4: GPU & COOLING TOWER (MOUNTED ON MID-RIGHT TOWER)
          // -----------------------------------------------------------------------
          Rectangle {
            id: gpuBillboard
            visible: root.cfgShowGpu
            x: parent.isPortrait ? (parent.width * 0.50 - width / 2) : Math.round(parent.width * 0.72 - width / 2)
            y: parent.isPortrait ? Math.round(parent.height * 0.42) : Math.round(parent.height * 0.44)
            width: parent.isPortrait ? Math.min(260, parent.width - 40) : Math.min(235, Math.max(175, parent.width * 0.16))
            height: 82
            radius: 10
            color: root.cardFillColor
            border.color: "#10e782"
            border.width: root.cfgBorderWidth

            Rectangle { x: parent.width - 12; y: -2; width: 12; height: 2.5; color: "#10e782" }
            Rectangle { x: parent.width - 1; y: -2; width: 2.5; height: 12; color: "#10e782" }

            Column {
              anchors.fill: parent
              anchors.margins: 8
              spacing: 4

              Row {
                spacing: 6
                width: parent.width
                clip: true
                Text { text: "󰢮"; color: "#ffb347"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                Text { text: root.cfgNameGpu; color: "#9a9abb"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.width - 25 }
              }

              Row {
                spacing: 8
                Row {
                  spacing: 4
                  Text { text: "GPU:"; color: "#8a8aa4"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                  Text { text: (root.sysGpuTemp > 0 ? (root.sysGpuTemp + "°C") : "STANDBY"); color: "#ffb347"; font.pixelSize: 11; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                }
                Row {
                  spacing: 4
                  Text { text: "FAN:"; color: "#8a8aa4"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                  Text { text: (root.sysFanSpeed > 0 ? (root.sysFanSpeed + " RPM") : "SILENT"); color: "#10e782"; font.pixelSize: 11; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                }
              }

              // Segmented Emerald Cooling Bar
              Row {
                width: parent.width
                spacing: 2.5
                Repeater {
                  model: 16
                  Rectangle {
                    width: Math.max(4, Math.floor((gpuBillboard.width - 16 - 15 * 2.5) / 16))
                    height: 5
                    radius: 1.5
                    property bool active: (index / 16.0) <= (root.sysFanSpeed / 7000.0)
                    color: active ? "#10e782" : "#181424"
                  }
                }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.runCmd("foot -e btop 2>/dev/null || true")
            }
          }

          // -----------------------------------------------------------------------
          // BILLBOARD 5: BROADWAY MEDIA JUMBOTRON (MOUNTED ON FAR-RIGHT TOWER)
          // -----------------------------------------------------------------------
          Rectangle {
            id: mediaBillboard
            visible: root.cfgShowMedia
            x: parent.isPortrait ? (parent.width * 0.50 - width / 2) : Math.min(parent.width - width - 15, Math.round(parent.width * 0.90 - width / 2))
            y: parent.isPortrait ? Math.round(parent.height * 0.52) : Math.round(parent.height * 0.26)
            width: parent.isPortrait ? Math.min(320, parent.width - 40) : Math.min(300, Math.max(235, parent.width * 0.21))
            height: 108
            radius: 10
            color: root.cardFillColor
            border.color: root.isSoundActive ? root.cfgAccent : root.cardBorderColor
            border.width: root.cfgBorderWidth

            Rectangle { x: parent.width - 12; y: -2; width: 12; height: 2.5; color: "#00e5ff" }
            Rectangle { x: parent.width - 1; y: -2; width: 2.5; height: 12; color: "#00e5ff" }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              z: -1
              onClicked: root.runCmd("spotify 2>/dev/null || uwsm-app -- spotify || true")
            }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: 7
              spacing: 3

              // Top row: Header badge + live indicator
              RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                  Layout.preferredWidth: root.isSoundActive ? 56 : 48
                  Layout.preferredHeight: 14
                  radius: 3
                  color: root.isSoundActive ? Qt.rgba(root.cfgAccent.r, root.cfgAccent.g, root.cfgAccent.b, 0.25) : Qt.rgba(0.4, 0.4, 0.4, 0.2)
                  Text {
                    anchors.centerIn: parent
                    text: root.isSoundActive ? "󰐊 AUDIO" : "󰏤 IDLE"
                    color: root.isSoundActive ? root.cfgAccent : "#9090a8"
                    font.pixelSize: 8
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                  }
                }
                Text { text: root.cfgNameMedia; color: "#8a8aa0"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.0; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; Layout.fillWidth: true }
              }

              // Middle row: Album Art, Info, Playback Controls
              RowLayout {
                Layout.fillWidth: true
                spacing: 7

                // Album Art
                Rectangle {
                  Layout.preferredWidth: 38
                  Layout.preferredHeight: 38
                  radius: 6
                  color: "#13101c"
                  border.color: root.isSoundActive ? root.cfgAccent : "#2a2238"
                  border.width: 1
                  clip: true

                  Image {
                    anchors.fill: parent
                    source: root.trackArt
                    visible: root.trackArt !== ""
                    fillMode: Image.PreserveAspectCrop
                  }

                  Text {
                    anchors.centerIn: parent
                    visible: root.trackArt === ""
                    text: root.isPlaying ? "󰎆" : "󰐊"
                    color: root.isSoundActive ? root.cfgAccent : "#7a7a92"
                    font.pixelSize: 16
                    font.family: "JetBrainsMono Nerd Font"
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runCmd("spotify 2>/dev/null || uwsm-app -- spotify || true")
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 1

                  Text {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    color: "#a0a0c0"
                    font.pixelSize: 9
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.runCmd("spotify 2>/dev/null || uwsm-app -- spotify || true")
                  }
                }

                // Playback Buttons
                RowLayout {
                  spacing: 3

                  Rectangle {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12; color: prevM.containsMouse ? "#2b223c" : "#191526"
                    Text { anchors.centerIn: parent; text: "󰒮"; color: "#ffffff"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: prevM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.activePlayer && root.activePlayer.canGoPrevious) root.activePlayer.previous(); else root.runCmd("playerctl previous 2>/dev/null || true"); } }
                  }

                  Rectangle {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14; color: root.cfgAccent
                    Text { anchors.centerIn: parent; text: root.isPlaying ? "󰏤" : "󰐊"; color: "#ffffff"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: playM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying(); else root.runCmd("playerctl play-pause 2>/dev/null || true"); } }
                  }

                  Rectangle {
                    Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 12; color: nextM.containsMouse ? "#2b223c" : "#191526"
                    Text { anchors.centerIn: parent; text: "󰒭"; color: "#ffffff"; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
                    MouseArea { id: nextM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next(); else root.runCmd("playerctl next 2>/dev/null || true"); } }
                  }
                }
              }

              // Mini Real-Time Audio Visualizer inside the Jumbotron
              Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 12
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Repeater {
                  model: 20
                  Rectangle {
                    width: Math.max(3, Math.floor((mediaBillboard.width - 24 - 19 * 2) / 20))
                    height: Math.max(2, root.isSoundActive ? Math.min(12, Math.max(3, (root.displayBars && root.displayBars[index]) ? (root.displayBars[index] * 0.12) : (root.isPlaying ? (4 + 3 * Math.sin(root.animTime * 6 + index)) : 2))) : 2)
                    radius: 1
                    color: root.isSoundActive ? ((index % 2 === 0) ? "#00e5ff" : root.cfgAccent) : "#201c2a"
                    anchors.bottom: parent.bottom
                  }
                }
              }
            }
          }


        }
      }
    }
  }
}
