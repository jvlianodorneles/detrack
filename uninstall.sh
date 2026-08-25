#!/usr/bin/env bash
# ==============================================================================
# DeTrack — Uninstaller Script for Omarchy
# ==============================================================================

set -e

BIN_FILE="${HOME}/.local/bin/detrack"
SHELL_CONFIG="${HOME}/.config/omarchy/shell.json"
OMARCHY_PLUGIN_DIR="${HOME}/.config/omarchy/plugins/dorneles.detrack"

echo "🗑️  Uninstalling DeTrack..."

# 1. Remove CLI tool
if [ -f "${BIN_FILE}" ]; then
  rm -f "${BIN_FILE}"
  echo "✓ Removed ${BIN_FILE}"
fi

# 2. Remove Plugin Directory
if [ -d "${OMARCHY_PLUGIN_DIR}" ]; then
  rm -rf "${OMARCHY_PLUGIN_DIR}"
  echo "✓ Removed plugin directory ${OMARCHY_PLUGIN_DIR}"
fi

# 3. Unregister from shell.json
if [ -f "${SHELL_CONFIG}" ]; then
  DETRACK_CONFIG_PATH="${SHELL_CONFIG}" python3 -c "
import json, os
config_path = os.environ.get('DETRACK_CONFIG_PATH')
try:
    with open(config_path, 'r') as f:
        data = json.load(f)
    bar_layout = data.get('bar', {}).get('layout', {})
    for section in ['left', 'center', 'right']:
        if section in bar_layout:
            bar_layout[section] = [item for item in bar_layout[section] if (item.get('id') if isinstance(item, dict) else item) != 'dorneles.detrack']
    with open(config_path, 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ Removed dorneles.detrack from Omarchy shell.json')
except Exception as e:
    pass
"
fi

# 4. Reload shell
if command -v omarchy-restart-shell >/dev/null 2>&1; then
  omarchy-restart-shell >/dev/null 2>&1 || true
  echo "✓ Omarchy shell reloaded"
fi

echo "✨ DeTrack has been successfully uninstalled."
