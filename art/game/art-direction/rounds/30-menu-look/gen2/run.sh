#!/usr/bin/env bash
# Gen 2: the two finalists, a (flat painted plank) and b (harbour chart), gen-1 learnings
# in the prompts. Run from art/.
set -eu
cd "$(dirname "$0")/../../../../.."   # art/
R=game/art-direction/rounds/30-menu-look
A1=game/art-direction/anchors/marketing_style.png
A2=game/art-direction/anchors/world_style.png
names=("$@")
[ $# -eq 0 ] && names=(a-panel a-button b-panel b-button)
for n in "${names[@]}"; do
  seed=$((2000 + RANDOM % 9000))
  uv run --script pipeline/img.py gen \
    --model google/nano-banana-2.1 \
    --prompt-file "$R/gen2/$n.txt" \
    --ref "$A1" --ref "$A2" \
    --param seed=$seed \
    --label "gen2 $n" \
    --out "$R/gen2/$n.png"
done
uv run --script pipeline/img.py cost
