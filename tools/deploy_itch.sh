#!/usr/bin/env bash
# Exports the browser build and pushes it to itch.io (moonlightart/cannonade:HTML5).
# One-time setup: /home/womb/.local/bin/butler login
# GODOT=... overrides the engine, BUTLER=... the butler binary.
set -eu
cd "$(dirname "$0")/.."
PATH="$HOME/.local/bin:$PATH"
BUTLER=${BUTLER:-butler}
tools/export_web.sh
ver=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
if [ -z "$ver" ]; then
	echo "deploy_itch: no application/config/version in project.godot" >&2
	exit 1
fi
"$BUTLER" push build/web moonlightart/cannonade:HTML5 --userversion "$ver"
"$BUTLER" status moonlightart/cannonade:HTML5
