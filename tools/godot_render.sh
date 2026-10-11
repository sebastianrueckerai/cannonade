#!/usr/bin/env bash
# Runs Godot with a renderer but without a window on the real display, through Xvfb.
# Use it for every tool that saves a screenshot: preview_glb, shoot_ui, screenshot.
#   tools/godot_render.sh res://tools/shoot_ui.tscn -- --scene=res://scenes/menu.tscn --out=/tmp/menu.png
set -eu
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64")}
exec xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --fixed-fps 30 "$@"
