#!/usr/bin/env bash
# ==============================================================================
# Wallpaper Engine Desktop Plugin Uninstaller
# ==============================================================================
set -euo pipefail

echo "Removing Wallpaper Engine Desktop Widget..."

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable ryguy.wallpaper-engine 2>/dev/null || true
  echo "  ✓ Disabled Omarchy plugin"
fi

rm -f "$HOME/.local/bin/wallpaper-engine"
rm -f "$HOME/.local/share/applications/wallpaper-engine-gui.desktop"

read -r -p "Delete user settings (~/.config/wallpaper-engine)? [y/N] " response
case "$response" in
  [yY][eE][sS]|[yY])
    rm -rf "$HOME/.config/wallpaper-engine"
    echo "  ✓ Removed configuration directory"
    ;;
  *)
    echo "  • Preserved configuration in ~/.config/wallpaper-engine"
    ;;
esac

echo "✓ Uninstallation complete."
