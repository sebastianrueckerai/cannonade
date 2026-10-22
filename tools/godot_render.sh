#!/usr/bin/env bash
# Runs Godot with a renderer but without a window on the real display, through Xvfb.
# Use it for every tool that saves a screenshot: preview_glb, shoot_ui, screenshot.
#   tools/godot_render.sh res://tools/shoot_ui.tscn -- --scene=res://scenes/menu.tscn --out=/tmp/menu.png
set -eu
cd "$(dirname "$0")/.."
GODOT=${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot_v4.7.2-stable_linux.x86_64")}
# Displays from :200 up: Flatpak apps see the real display as :99 and would reach a host Xvfb there.
exec xvfb-run -a -n 200 -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 "$@"
