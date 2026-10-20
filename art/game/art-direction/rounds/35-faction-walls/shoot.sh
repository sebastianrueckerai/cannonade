#!/usr/bin/env bash
# Round 35: every battle screenshot of the boards, into /tmp/fw. Run from the game repo root (the worktree
# that holds the synced wall_* looks). Same seed and battle time for every frame; the AI sides play on.
set -eu
cd "$(dirname "$0")/../../../../.."
OUT=/tmp/fw
mkdir -p "$OUT"
shot() {  # shot <stem> <args...>
	local stem=$1; shift
	[ -f "$OUT/${stem}_050.png" ] && return 0
	timeout 120 tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=5 --out="$OUT/$stem" "$@" > "$OUT/$stem.log" 2>&1 || echo "FAIL $stem"
}
for look in plain arch corbel pilaster course caps; do
	shot "model_$look" --wall=wall_$look,wall_$look
	shot "close_$look" --wall=wall_$look,wall_$look --look=4,3
done
for pair in arch,pilaster corbel,course arch,corbel caps,arch; do
	a=${pair%,*}; b=${pair#*,}
	shot "pair_${a}_${b}" --wall=wall_$a,wall_$b
done
for spec in none deck=0.35 deck=0.6 deck=1 deck=0.6,merlons=0.6 merlons=0.6 body=0.2 deck=0.6,floor=0.25 floor=0.4; do
	stem="colour_$(echo "$spec" | tr -d '=' | tr ',' '_')"
	if [ "$spec" = none ]; then shot "$stem" --wall=wall_plain,wall_plain; else shot "$stem" --wall=wall_plain,wall_plain --team="$spec"; fi
done

# the low-angle model check: not a game view, the faces of a run from 29 degrees
for look in plain arch corbel pilaster course caps; do
	shot "low_$look" --wall=wall_$look,wall_$look --look=4,3 --eye=4,8
done
echo done2
