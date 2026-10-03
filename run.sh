#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${GODOT_BIN:-}" ]]; then
  engine="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  engine="$(command -v godot)"
elif command -v godot4 >/dev/null 2>&1; then
  engine="$(command -v godot4)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  engine=/Applications/Godot.app/Contents/MacOS/Godot
elif [[ -x "$PROJECT_DIR/tools/Godot.app/Contents/MacOS/Godot" ]]; then
  engine="$PROJECT_DIR/tools/Godot.app/Contents/MacOS/Godot"
else
  echo 'Install Godot 4, or set GODOT_BIN to its executable path.' >&2
  exit 1
fi
exec "$engine" --path "$PROJECT_DIR" "$@"
