#!/usr/bin/env bash
# Round 35, third pass: every piece alone and the junctions, under the shipped D79 colours, into /tmp/fw3. Run
# from the game repo root: the default view, a view straight down over the layout, and six close views.
set -eu
cd "$(dirname "$0")/../../../../.."
OUT=/tmp/fw3
mkdir -p "$OUT"
shot() {  # shot <stem> <args...>
	local stem=$1; shift
	[ -f "$OUT/${stem}_050.png" ] && return 0
	timeout 120 tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=5 --pieces --out="$OUT/$stem" "$@" > "$OUT/$stem.log" 2>&1 || echo "FAIL $stem"
}
shot pieces_default
shot pieces_top --look=11,7 --top=22
shot pieces_a1 --look=6,2 --eye=8,6
shot pieces_a2 --look=14,2 --eye=8,6
shot pieces_b1 --look=5,6 --eye=8,6
shot pieces_b2 --look=15,6 --eye=8,6
shot pieces_c1 --look=5,11 --eye=8,6
shot pieces_c2 --look=13,11 --eye=8,6
echo done
