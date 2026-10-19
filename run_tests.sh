#!/usr/bin/env bash
# Runs the headless test suite of the Godot port.
#   ./run_tests.sh            (uses `godot` from PATH, or set GODOT=/path/to/godot)
set -u
cd "$(dirname "$0")"
GODOT=${GODOT:-$(command -v godot || echo "$HOME/Applications/Godot_v4.7.1-stable_linux.x86_64")}
"$GODOT" --headless --import >/dev/null 2>&1
fail=0
run() {
	local name=$1
	shift
	local out code
	out=$(timeout "${TEST_TIMEOUT:-600}" "$GODOT" --headless "$@" 2>&1)
	code=$?
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|INVARIANT FAILED|^ERROR:" <<<"$out"; then
		echo "FAIL  $name (exit $code)"
		grep -E "ERROR|FAIL|at: " <<<"$out" | head -20
		fail=1
	else
		echo "PASS  $name  $(grep -E 'frames=' <<<"$out" | tr '\n' ' ')"
	fi
}
run scripts      res://tests/check_scripts.tscn
run art          res://tools/check_art.tscn
run flood-fill   res://tests/flood_test.tscn
run human-input  --fixed-fps 30 res://tests/human.tscn
run weapons      --fixed-fps 30 res://tests/weapons.tscn
run menu         --fixed-fps 30 res://tests/menu_test.tscn
run practice     --fixed-fps 30 res://tests/practice_test.tscn
run check        --fixed-fps 30 res://tests/check_test.tscn
run camera       --fixed-fps 30 res://tests/camera_test.tscn
run previews     --fixed-fps 30 res://tests/preview_test.tscn
run ai           --fixed-fps 30 res://tests/ai_test.tscn
run catalog      --fixed-fps 30 res://tests/catalog_test.tscn
run sandbox      --fixed-fps 30 res://tests/sandbox_test.tscn
run lab          res://tests/lab_test.tscn
run sim-versus   --fixed-fps 30 res://tests/sim.tscn -- --mode=versus --seconds=60 --seed=2 --autobuild --report=1000
run sim-ai2      --fixed-fps 30 res://tests/sim.tscn -- --mode=ai2 --seconds=130 --seed=1 --report=1000
exit $fail
