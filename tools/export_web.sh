#!/usr/bin/env bash
# Builds the browser version into build/web/. GODOT=/path/to/godot overrides the binary.
set -eu
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64")}
mkdir -p build/web
"$GODOT" --headless --import >/dev/null 2>&1 || true
"$GODOT" --headless --export-release Web build/web/index.html
ls -la build/web
echo "serve it with tools/serve_web.sh"
