#!/usr/bin/env bash
# Stages each candidate direction into assets/art/ui/, shoots the real menu at both
# widths, then restores the live slots. Run from the repo root.
set -eu
cd "$(dirname "$0")/../../../../.."   # repo root
R=art/game/art-direction/rounds/30-menu-look
UI=assets/art/ui
GODOT=${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64")}

python3 "$R/build_candidates.py"
mkdir -p "$R/shots"

dirs=("$@")
[ $# -eq 0 ] && dirs=(a b c)
for d in "${dirs[@]}"; do
  cp "$R/candidates/original-theme.tres" "$UI/theme.tres"
  cp "$R/candidates/$d/ui/"* "$UI/"
  "$GODOT" --headless --import --path . >/dev/null 2>&1 || true
  for w in 1280 390; do
    tools/godot_render.sh res://tools/shoot_ui.tscn -- \
      --scene=res://scenes/menu.tscn --width=$w --height=720 --frames=12 \
      --out="$R/shots/$d-$w.png"
  done
  cp "$R/candidates/original-theme.tres" "$UI/theme.tres"
  rm -f "$UI/font.ttf" "$UI/button.png" "$UI/panel.png" "$UI/manifest.json"
  rm -f "$UI/font.ttf.import" "$UI/button.png.import" "$UI/panel.png.import"
  echo "== $d done"
done

for f in font.ttf button.png panel.png manifest.json; do
  [ ! -e "$UI/$f" ] || echo "LEFTOVER $UI/$f"
done
git status --porcelain assets/art/ui | grep -v '^$' || echo "ui slots clean"
