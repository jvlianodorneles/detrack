#!/usr/bin/env bash
# ==============================================================================
# DeTrack — Installer Script for Omarchy
# URL Tracker Cleaner & QR Code Generator
# (https://github.com/jvlianodorneles/DeTrack)
# ==============================================================================

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
STATE_DIR="${HOME}/.local/state/omarchy/detrack"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.detrack"

echo "🛡️  Installing DeTrack (URL Tracker Cleaner & QR Code)..."

# 1. Install CLI Tool
mkdir -p "${BIN_DIR}"
install -Dm755 "${SOURCE_DIR}/scripts/detrack-cli.py" "${BIN_DIR}/detrack"
echo "✓ Installed CLI tool to ${BIN_DIR}/detrack"

# 2. Install Omarchy Quickshell Plugin
mkdir -p "${OMARCHY_PLUGIN_DIR}"
mkdir -p "${STATE_DIR}"

cp "${SOURCE_DIR}/manifest.json" "${SOURCE_DIR}/BarWidget.qml" "${SOURCE_DIR}/Panel.qml" "${SOURCE_DIR}/Engine.js" "${SOURCE_DIR}/QRCode.js" "${OMARCHY_PLUGIN_DIR}/"
echo "✓ Installed Omarchy Quickshell Plugin to ${OMARCHY_PLUGIN_DIR}"

# 3. Register in Omarchy shell.json bar layout
if [ -f "${SHELL_CONFIG}" ]; then
  DETRACK_CONFIG_PATH="${SHELL_CONFIG}" python3 -c "
import json, os
config_path = os.environ.get('DETRACK_CONFIG_PATH')
try:
    with open(config_path, 'r') as f:
        content = f.read()
    if 'dorneles.detrack' not in content:
        data = json.loads(content)
        bar_layout = data.setdefault('bar', {}).setdefault('layout', {})
        right_list = bar_layout.setdefault('right', [])
        right_list.insert(0, {'id': 'dorneles.detrack'})
        with open(config_path, 'w') as f:
            json.dump(data, f, indent=2)
        print('✓ Registered dorneles.detrack in Omarchy bar layout (shell.json)')
    else:
        print('✓ dorneles.detrack is already registered in shell.json')
except Exception as e:
    print('Note: Could not automatically update shell.json:', e)
"
fi

# 4. Restart shell if running
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
  echo "✓ Omarchy shell reloaded"
fi

echo ""
echo "✨ Installation complete!"
echo "• Status Bar Plugin: Active on your Omarchy bar"
echo "• CLI Tool: Try 'detrack --help' or 'detrack --clipboard --qr'"
