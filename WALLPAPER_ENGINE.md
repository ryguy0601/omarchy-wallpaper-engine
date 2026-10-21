# Wallpaper Engine — AI Agent & Developer Reference Manual

> **Purpose**: This document provides an exhaustive, machine-readable and human-friendly guide for any AI coding assistant (Antigravity, Claude, ChatGPT, Gemini, Copilot, Hermes) or user to inspect, customize, script, and troubleshoot the **Wallpaper Engine** desktop system.

---

## 1. Quick Agent Cheatsheet

If a user asks an AI agent to customize their wallpaper or desktop widget, use these commands:

| Goal | Agent Action / Command |
|------|------------------------|
| **View current settings** | `wallpaper-engine status` or read `~/.config/wallpaper-engine/config.json` |
| **Inspect hardware telemetry** | `wallpaper-engine hw` or `wallpaper-engine hwinfo` (JSON output) |
| **Toggle hardware items** | `wallpaper-engine hw toggle <cputemp\|fanspeed\|cpuload\|ram\|gputemp\|unit>` |
| **List dock shortcuts** | `wallpaper-engine shortcut list` |
| **Add dock shortcut** | `wallpaper-engine shortcut add <name> <icon> <cmd>` |
| **Remove dock shortcut** | `wallpaper-engine shortcut remove <index>` |
| **Reset dock shortcuts** | `wallpaper-engine shortcut reset` |
| **Toggle Customize button** | `wallpaper-engine toggle customize-button` |
| **Move widget** | `wallpaper-engine position <center\|top-left\|top-right\|bottom-left\|bottom-right\|top-center\|bottom-center\|custom>` |
| **Set exact pixel position** | `wallpaper-engine coords <x> <y>` |
| **Toggle any module** | `wallpaper-engine toggle <clock\|date\|weather\|media\|visualizer\|sysinfo\|shortcuts\|quote\|footer\|customize-button>` |
| **Change accent color** | `wallpaper-engine color "#e20074"` (or any `#hex`) |
| **Switch 12h / 24h clock** | `wallpaper-engine format 12` or `wallpaper-engine format 24` |
| **Toggle running seconds** | `wallpaper-engine seconds on` or `wallpaper-engine seconds off` |
| **Adjust clock font size** | `wallpaper-engine clock-size 84` (pixels) |
| **Set custom quote/notes** | `wallpaper-engine quote "Stay hungry, stay foolish." "Steve Jobs"` |
| **Set wallpaper image** | `wallpaper-engine wallpaper /path/to/image.png` |
| **Adjust widget width** | `wallpaper-engine width 800` |
| **Set card opacity** | `wallpaper-engine opacity 0.85` (0.30 - 1.0) |
| **Set corner radius** | `wallpaper-engine radius 20` (pixels) |
| **Launch GUI customizer** | `wallpaper-engine gui` |
| **Restart shell & apply** | `omarchy restart shell` or `wallpaper-engine restart` |

---

## 2. File Architecture & Paths

```
~/.config/wallpaper-engine/
├── config.json                 <-- Primary JSON state. Watched live by FileView.
├── gui/
│   └── SettingsWindow.qml     <-- Standalone Quickshell GUI overlay customizer (7 tabs).
└── WALLPAPER_ENGINE.md         <-- This documentation file.

~/.config/omarchy/plugins/ryguy.wallpaper-engine/
├── WallpaperEngine.qml         <-- Main layer-shell bottom QML widget (60 FPS visualizer, hardware telemetry, dock).
├── SettingsWindow.qml          <-- Mirror copy for plugin distribution.
├── manifest.json               <-- Omarchy shell plugin manifest.
└── cava.conf                   <-- PipeWire audio capture spectrum configuration.

~/.local/bin/
├── wallpaper-engine            <-- Python CLI & GUI control helper + hardware sensor collector.
└── cava                        <-- Lightweight PipeWire audio visualizer binary.

~/.local/share/applications/
└── wallpaper-engine-gui.desktop <-- Desktop entry for application search / launcher.
```

---

## 3. Configuration Schema (`config.json`)

All configuration is stored in `~/.config/wallpaper-engine/config.json`. The running widget has a live `FileView` watcher; modifying this file updates the desktop widget **in real time**.

```json
{
  "layout": {
    "position": "center",
    "customX": 100,
    "customY": 100,
    "width": 720,
    "spacing": 22
  },
  "modules": {
    "clock": true,
    "date": true,
    "weather": true,
    "media": true,
    "visualizer": true,
    "sysinfo": true,
    "shortcuts": true,
    "quote": false,
    "footer": true,
    "customizeButton": true
  },
  "clock": {
    "format12h": true,
    "showAmPm": true,
    "showSeconds": false,
    "fontSize": 76
  },
  "hardware": {
    "showCpuLoad": true,
    "showCpuTemp": true,
    "showFanSpeed": true,
    "showRam": true,
    "showGpuTemp": false,
    "tempUnit": "C"
  },
  "shortcuts": [
    { "icon": "󰈹", "label": "Browser", "cmd": "omarchy-cmd-default-browser || xdg-open https://google.com" },
    { "icon": "󰆍", "label": "Terminal", "cmd": "omarchy-default-terminal || foot" },
    { "icon": "󰉋", "label": "Files", "cmd": "thunar || omarchy-file-select" },
    { "icon": "󰨞", "label": "Editor", "cmd": "omarchy-default-editor || code || foot -e nvim" },
    { "icon": "󰎆", "label": "Music", "cmd": "playerctl play-pause 2>/dev/null || true" },
    { "icon": "", "label": "Settings", "cmd": "wallpaper-engine gui" }
  ],
  "quote": {
    "text": "The best way to predict the future is to invent it.",
    "author": "Alan Kay"
  },
  "visualizer": {
    "height": 70,
    "bars": 28,
    "idleWave": true
  },
  "style": {
    "accentColor": "#e20074",
    "cardBackground": "#0c0c12",
    "cardOpacity": 0.85,
    "cardRadius": 20,
    "borderGlow": true,
    "borderWidth": 1.5,
    "userName": "auto",
    "autoRestartShell": false
  }
}
```

### Detailed Key Reference

#### `layout`
- `position` (*string*): Preset position. Options: `"center"`, `"top-left"`, `"top-right"`, `"bottom-left"`, `"bottom-right"`, `"top-center"`, `"bottom-center"`, `"custom"`.
- `customX` (*int*): Horizontal pixel offset when `position == "custom"`.
- `customY` (*int*): Vertical pixel offset when `position == "custom"`.
- `width` (*int*): Width of the widget card stack in pixels (range: `500` to `1000`, default: `720`).
- `spacing` (*int*): Vertical spacing between cards in pixels (range: `10` to `40`, default: `22`).

#### `modules`
- `clock` (*bool*): Bold digital clock.
- `date` (*bool*): Full weekday, month, day, year.
- `weather` (*bool*): Omarchy weather icon, city name, temperature.
- `media` (*bool*): MPRIS now-playing track title, artist, album art, and interactive playback controls.
- `visualizer` (*bool*): 60 FPS animated PipeWire audio spectrum bars.
- `sysinfo` (*bool*): Hardware monitoring card (CPU load, CPU temp, fan speed, RAM, GPU temp).
- `shortcuts` (*bool*): Quick launch dock for custom apps.
- `quote` (*bool*): Daily inspiration / custom motivation quote banner.
- `footer` (*bool*): Personal branding text (`<USER> // WALLPAPER ENGINE`).
- `customizeButton` (*bool*): The `[  Customize Widget ]` pill button at the bottom of the widget card. If `false`, the button is hidden; settings can still be opened via dock shortcut, right-click, app menu, or `wallpaper-engine gui`.

#### `hardware`
- `showCpuLoad` (*bool*): Show 1-minute CPU load average.
- `showCpuTemp` (*bool*): Show CPU core package temperature with heat indicator colors.
- `showFanSpeed` (*bool*): Show hardware fan speeds in RPM.
- `showRam` (*bool*): Show RAM memory usage and animated progress bar.
- `showGpuTemp` (*bool*): Show GPU temperature if available.
- `tempUnit` (*string*): `"C"` for Celsius or `"F"` for Fahrenheit.

#### `shortcuts`
Array of application buttons in the desktop dock. Each item has:
- `icon` (*string*): Nerd Font glyph or unicode icon (e.g. `"󰈹"`, `"󰆍"`, `"󰒱"`, `"󰓓"`).
- `label` (*string*): App name shown on hover tooltip.
- `cmd` (*string*): Bash command executed via `Quickshell.execDetached`.

---

## 4. How AI Agents Can Edit Programmatically

### Method A: Single Command via CLI
```bash
# Example: Change accent color to cyan and move to top-left
wallpaper-engine color "#00e5ff"
wallpaper-engine position top-left

# Example: Hide the Customize Widget button
wallpaper-engine toggle customize-button

# Example: Toggle Fan speeds and CPU temps
wallpaper-engine hw toggle fanspeed
wallpaper-engine hw toggle cputemp

# Example: Add Discord to the dock
wallpaper-engine shortcut add Discord "󰒱" "discord"
```

### Method B: Applying a Full JSON Payload
An agent can write directly to `config.json` or use `apply-json`:
```bash
python3 -c '
import json
p = "/home/ryguy/.config/wallpaper-engine/config.json"
with open(p, "r") as f: d = json.load(f)
d["layout"]["position"] = "top-left"
d["modules"]["customizeButton"] = False
d["hardware"]["showFanSpeed"] = True
d["hardware"]["showCpuTemp"] = True
with open(p, "w") as f: json.dump(d, f, indent=2)
'
```
*Note*: Because `WallpaperEngine.qml` uses `FileView { watchChanges: true }`, any write to `config.json` updates the desktop **instantaneously** without restarting anything!

---

## 5. Technical Gotchas & Rules for Agents

1. **Wayland Layer-Shell Input Mask & Button Clicks**:
   - The desktop background operates on `WlrLayer.Bottom` with `mask: Region { item: widgetHub }`.
   - The input mask is bounded directly to `widgetHub`, ensuring all buttons (dock shortcuts, media player controls, customize pill) receive click events immediately while all remaining desktop space is 100% click-through.
2. **Process Execution**:
   - All app shortcuts and external commands run via `Quickshell.execDetached(["bash", "-lc", cmd])` to prevent blocking the QML event loop.
3. **Audio Spectrum Feed (CAVA)**:
   - CAVA runs against PipeWire using raw 16-bit stdout parsed by `SplitParser`.
   - If CAVA is killed, `restartCavaTimer` in `WallpaperEngine.qml` restarts it automatically within 2 seconds.
4. **Hardware Sensor Telemetry**:
   - Telemetry is gathered ultra-fast (< 90ms) by `wallpaper-engine hwinfo` scanning `/sys/class/hwmon` and `/proc/loadavg` without waking up unnecessary disk or bus devices.
