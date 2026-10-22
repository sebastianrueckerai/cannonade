#!/usr/bin/env bash
# Exports the browser build and pushes it to itch.io (moonlightart/cannonade:HTML5).
# One-time setup: /home/womb/.local/bin/butler login
# GODOT=... overrides the engine, BUTLER=... the butler binary.
set -eu
cd "$(dirname "$0")/.."
PATH="$HOME/.local/bin:$PATH"
BUTLER=${BUTLER:-butler}
tools/export_web.sh
"$BUTLER" push build/web moonlightart/cannonade:HTML5
"$BUTLER" status moonlightart/cannonade:HTML5
