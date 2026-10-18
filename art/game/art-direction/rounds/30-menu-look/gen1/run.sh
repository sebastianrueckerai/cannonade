#!/usr/bin/env bash
# Gen 1: two textures per textured direction, style anchors as refs. Dies after critique.
set -eu
cd "$(dirname "$0")/../../../../.."   # art/
R=game/art-direction/rounds/30-menu-look
A1=game/art-direction/anchors/marketing_style.png
A2=game/art-direction/anchors/world_style.png
for n in a-panel a-button b-panel b-button d-panel d-button; do
  seed=$((1000 + RANDOM % 9000))
  uv run --script pipeline/img.py gen \
    --model google/nano-banana-2.1 \
    --prompt-file "$R/gen1/$n.txt" \
    --ref "$A1" --ref "$A2" \
    --param seed=$seed \
    --label "gen1 $n" \
    --out "$R/gen1/$n.png"
done
uv run --script pipeline/img.py cost
