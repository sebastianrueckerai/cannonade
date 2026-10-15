#!/usr/bin/env bash
# D34 route test: the three guns through Tripo and Meshy, every method and input. Run from the repo root:
#   game/assets/3d/route-test.sh cannon [tripo|meshy]   one gun, optionally one API. Runs whose output exists are skipped
#   game/assets/3d/route-test.sh cannon report           one sheet per experiment in previews/
#   game/assets/3d/route-test.sh cannon views            Meshy only: how many views, and which model
# Inputs per gun in refs/: a-sketch (the painted sketch cut out), b-clean (a clean three-quarter view),
# c-front/left/back/right (views of a turnaround), barrel and mount (the parts painted apart).
set -u
g=$1
only=${2:-}
r=game/assets/3d/$g/refs
o=game/assets/3d/$g/raw
case $g in
  cannon)    mid=1000; lo=300;  hi=3000; part=1000 ;;
  cannon22a) mid=1500; lo=500;  hi=4000; part=1000 ;;
  cannon33a) mid=3000; lo=1000; hi=8000; part=1500 ;;
esac
right=$r/c-right.png; [ -f "$right" ] || right=-
fp=${g#cannon}; fp=${fp:0:1}; fp=${fp:-1}

if [ "$only" = report ]; then
  sheet() { uv run --quiet pipeline/meshsheet.py game/assets/3d/$g --footprint $fp --out "$1" --title "$2" --only "${@:3}"; }
  sheet 1-api "$g: the same clean view and face count through both APIs" tripo-b-$mid meshy-b-$mid
  sheet 2-inputs "$g: painted sketch (a), clean view (b), four views (c4), front and back (c2)" \
    tripo-a-$mid tripo-b-$mid tripo-c4-$mid tripo-c2-$mid meshy-a-$mid meshy-b-$mid meshy-c4-$mid
  sheet 3-barrel "$g: whole gun, the API's parts, barrel and mount made apart" \
    tripo-b-$mid tripo-b-parts meshy-b-$mid tripo-barrel tripo-mount meshy-barrel meshy-mount
  sheet 4-faces "$g: the face-count ladder" meshy-b-$lo meshy-b-$mid meshy-b-$hi tripo-b-$mid tripo-b-$hi
  sheet 5-views "$g: how many views, and which Meshy model (t2 low-poly or 7.1)" \
    meshy-b-$mid meshy-v1-left-$mid meshy-v1-b71-$mid meshy-v2-fl-$mid meshy-v2-bl-$mid meshy-v3-$mid meshy-c4-$mid
  exit
fi
TRIPO_LP="--param texture=true --param pbr=false --param smart_low_poly=true"
T2="--param model_type=smart-topology --param ai_model=meshy-t2"

run() {  # run <out stem> <provider> <args...>
  local out=$o/$1.glb; shift
  [ -f "$out" ] && return
  [ -n "$only" ] && [ "$1" != "$only" ] && return
  uv run --quiet pipeline/mesh.py "$@" --label "$g $(basename "$out" .glb)" --out "$out" || echo "FAILED $out"
}

if [ "$only" = views ]; then
  only=""
  M71="--param ai_model=meshy-7.1 --param should_remesh=true --param topology=triangle --param target_polycount=$mid"
  run meshy-v1-left-$mid   meshy --image $r/c-left.png $T2 --param target_polycount=$mid &
  run meshy-v1-b71-$mid    meshy --image $r/b-clean.png $M71 &
  run meshy-v2-fl-$mid     meshy --views $r/c-front.png $r/c-left.png $M71 &
  run meshy-v2-bl-$mid     meshy --views $r/b-clean.png $r/c-left.png $M71 &
  run meshy-v3-$mid        meshy --views $r/c-front.png $r/c-left.png $r/c-back.png $M71 &
  wait
  exit
fi

run tripo-a-$mid       tripo --image $r/a-sketch.png $TRIPO_LP --param face_limit=$mid &
run tripo-b-$mid       tripo --image $r/b-clean.png $TRIPO_LP --param face_limit=$mid &
run tripo-b-$hi        tripo --image $r/b-clean.png $TRIPO_LP --param face_limit=$hi &
run tripo-c4-$mid      tripo --views $r/c-front.png $r/c-left.png $r/c-back.png $right $TRIPO_LP --param face_limit=$mid &
run tripo-c2-$mid      tripo --views $r/c-front.png - $r/c-back.png - $TRIPO_LP --param face_limit=$mid &
run tripo-b-parts      tripo --image $r/b-clean.png --param texture=false --param pbr=false --param generate_parts=true --param face_limit=$mid &
run meshy-a-$mid       meshy --image $r/a-sketch.png $T2 --param target_polycount=$mid &
run meshy-b-$mid       meshy --image $r/b-clean.png $T2 --param target_polycount=$mid &
run meshy-b-$lo        meshy --image $r/b-clean.png $T2 --param target_polycount=$lo &
run meshy-b-$hi        meshy --image $r/b-clean.png $T2 --param target_polycount=$hi &
run meshy-c4-$mid      meshy --views $r/c-front.png $r/c-left.png $r/c-back.png $r/b-clean.png --param ai_model=meshy-7.1 \
                         --param should_remesh=true --param topology=triangle --param target_polycount=$mid &
if [ -f $r/barrel.png ] && [ -f $r/mount.png ]; then
  run tripo-barrel     tripo --image $r/barrel.png $TRIPO_LP --param face_limit=1000 &
  run tripo-mount      tripo --image $r/mount.png $TRIPO_LP --param face_limit=$mid &
  run meshy-barrel     meshy --image $r/barrel.png $T2 --param target_polycount=$part &
  run meshy-mount      meshy --image $r/mount.png $T2 --param target_polycount=$mid &
fi
wait
