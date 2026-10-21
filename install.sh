#!/usr/bin/env bash
# ==============================================================================
# Wallpaper Engine Desktop Plugin Installer
# https://github.com/ryguy/omarchy-wallpaper-engine
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
CFG_DIR="$HOME/.config/wallpaper-engine"
APP_DIR="$HOME/.local/share/applications"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"

echo "󰏘 Installing Wallpaper Engine Desktop Widget..."

# 1. Install CLI helper to ~/.local/bin
mkdir -p "$BIN_DIR"
if [[ -f "$SCRIPT_DIR/bin/wallpaper-engine" ]]; then
  cp "$SCRIPT_DIR/bin/wallpaper-engine" "$BIN_DIR/wallpaper-engine"
  chmod +x "$BIN_DIR/wallpaper-engine"
  echo "  ✓ Installed CLI helper to $BIN_DIR/wallpaper-engine"
fi

# 2. Setup user configuration directory
mkdir -p "$CFG_DIR/gui"
if [[ ! -f "$CFG_DIR/config.json" && -f "$SCRIPT_DIR/config.json" ]]; then
  cp "$SCRIPT_DIR/config.json" "$CFG_DIR/config.json"
  echo "  ✓ Installed default configuration to $CFG_DIR/config.json"
fi

if [[ -f "$SCRIPT_DIR/SettingsWindow.qml" ]]; then
  cp "$SCRIPT_DIR/SettingsWindow.qml" "$CFG_DIR/gui/SettingsWindow.qml"
  echo "  ✓ Installed GUI settings to $CFG_DIR/gui/SettingsWindow.qml"
fi

if [[ -f "$SCRIPT_DIR/WALLPAPER_ENGINE.md" ]]; then
  cp "$SCRIPT_DIR/WALLPAPER_ENGINE.md" "$CFG_DIR/WALLPAPER_ENGINE.md"
  cp "$SCRIPT_DIR/WALLPAPER_ENGINE.md" "$CFG_DIR/README.md"
fi

# 3. Install Desktop Application entry
mkdir -p "$APP_DIR"
cat << 'EOF' > "$APP_DIR/wallpaper-engine-gui.desktop"
[Desktop Entry]
Type=Application
Name=Wallpaper Engine Settings
GenericName=Desktop Widget Customizer
Comment=Configure position, modules, colors, hardware stats and wallpapers
Exec=wallpaper-engine gui
Icon=preferences-desktop-wallpaper
Terminal=false
Categories=Settings;DesktopSettings;Utility;
Keywords=wallpaper;engine;widget;clock;weather;visualizer;customizer;
EOF
chmod +x "$APP_DIR/wallpaper-engine-gui.desktop"
echo "  ✓ Created launcher shortcut in $APP_DIR/wallpaper-engine-gui.desktop"

# 4. Enable plugin if installed in Omarchy
if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable ryguy.wallpaper-engine 2>/dev/null || true
  echo "  ✓ Enabled plugin in Omarchy shell"
fi

echo ""
echo "🚀 Installation complete!"
echo "  • Open Settings GUI:   wallpaper-engine gui"
echo "  • View Hardware Stats: wallpaper-engine hw"
echo "  • CLI Cheatsheet:      wallpaper-engine help"
echo "  • Restart Shell:       omarchy restart shell"
