#!/usr/bin/env bash
# Runs the headless test suite of the Godot port.
#   ./run_tests.sh            (uses `godot` from PATH, or set GODOT=/path/to/godot)
set -u
cd "$(dirname "$0")"
GODOT=${GODOT:-godot}
"$GODOT" --headless --import >/dev/null 2>&1
fail=0
run() {
	local name=$1
	shift
	local out code
	out=$("$GODOT" --headless "$@" 2>&1)
	code=$?
	if [ $code -ne 0 ] || grep -qE "SCRIPT ERROR|Parse Error|INVARIANT FAILED" <<<"$out"; then
		echo "FAIL  $name (exit $code)"
		grep -E "ERROR|FAIL|at: " <<<"$out" | head -20
		fail=1
	else
		echo "PASS  $name  $(grep -E 'checks=|ops=|frames=' <<<"$out" | tr '\n' ' ')"
	fi
}
run scripts      res://tests/check_scripts.tscn
run flood-fill   res://tests/flood_test.tscn
run human-input  --fixed-fps 30 res://tests/human.tscn
run weapons      --fixed-fps 30 res://tests/weapons.tscn
run menu         --fixed-fps 30 res://tests/menu_test.tscn
run sim-single   --fixed-fps 30 res://tests/sim.tscn -- --mode=single --seconds=60 --seed=2 --autobuild --report=1000
run sim-versus   --fixed-fps 30 res://tests/sim.tscn -- --mode=versus --seconds=60 --seed=4 --autobuild --report=1000
run sim-ai2      --fixed-fps 30 res://tests/sim.tscn -- --mode=ai2 --seconds=130 --seed=1 --report=1000
run sim-ai4      --fixed-fps 30 res://tests/sim.tscn -- --mode=ai4 --seconds=60 --seed=3 --report=1000
exit $fail
