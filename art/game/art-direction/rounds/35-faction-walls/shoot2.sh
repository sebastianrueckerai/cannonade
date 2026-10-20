#!/usr/bin/env bash
# Round 35, second pass: the accent schemes on the D78 walkway, into /tmp/fw2, then a four-player frame. Run from
# the game repo root. Each scheme at the default view and at the near fort's corner.
set -eu
cd "$(dirname "$0")/../../../../.."
OUT=/tmp/fw2
mkdir -p "$OUT"
shot() {  # shot <stem> <args...>
	local stem=$1; shift
	[ -f "$OUT/${stem}_050.png" ] && return 0
	timeout 120 tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=5 --out="$OUT/$stem" "$@" > "$OUT/$stem.log" 2>&1 || echo "FAIL $stem"
}
for spec in walk=0.6 walk=0.35 walk=1 walk=0.6,rim=0.6 walk=0.6,band=0.6 walk=0,rim=0.6 walk=0,band=0.6 walk=0.6,floor=0.25 walk=0.6,rim=0.6,floor=0.25; do
	stem="accent_$(echo "$spec" | tr -d '=' | tr ',' '_')"
	shot "$stem" --team="$spec"
	shot "${stem}_close" --team="$spec" --look=4,3
done
[ -f "$OUT/ai4_400.png" ] || timeout 300 tools/godot_render.sh res://tools/screenshot.tscn -- --mode=ai4 --at=40 --seed=3 --out="$OUT/ai4" > "$OUT/ai4.log" 2>&1 || echo "FAIL ai4"
echo done
