# Session 63: the flat shell arc

Sebastian, 2026-10-22: "Currently cannon balls take a long time to arrive. I think it would be nicer for
them to arrive in maybe 0.6 of the current time. Also they fly really high on a balistic curve to arrive
anywhere. I think were they shot with less force on a less high curve it would look cooler: Since now due
to the high curve they always fly out of sight / camera range. So the balistic curve should be such, that
the cannonball can reach any tile on the map, but no higher. The combo of speed and curve should make it
so that balls arrive in 0.6 of the time they need currently."
Roadmap: I102 (game). J6 asked for a flatter arc and rules v2 section 3 promised a flat arc of about 2 s.
No paid generation, session cap 0.

## What ships

1. **The low ballistic solution, always** (I102). `Shooter.try_aim` solves sin(2θ) = d·g/v² and now always
   takes the low solution; the steep branch (90° − θ) is gone. With the whole-map range
   `maxDesiredRange = 65` the farthest tile needs θ = 36.5°, so the arc rises just high enough to reach any
   tile and no higher: the far corner climbs 11.5 tiles, a 20-tile shot 0.8, mid-range stays under 3. The
   steep arc lobbed a 20-tile shot about 30 tiles high and left the camera for most of its flight. The low
   solution's angle and apex do not depend on gravity (sin 2θ = d / R), so the branch alone fixes the arc's
   shape.
2. **Gravity 5 to 7.5** (same item). `gravity` in Shooter.gd's default and CannonBehaviour.gd; no `.tres`
   overrides it. vOpt = sqrt(65 · 7.5) = 22.1. Fly time is the gravity-dependent half: the 62-tile map
   diagonal lands in 3.50 s, 0.603 of the steep arc's 5.80 s, and every shorter shot lands in a smaller
   fraction still (a 16-tile shot: 0.73 s against 7.16 s, a tenth). Rules v2 section 3 now states the
   shipped numbers instead of the old "flat arc of about 2 s" promise.

## Checks

[weapons.gd](../../tests/weapons.gd) grows the arc block: the barrel stays at or under 45° at 10, 30 and
62 tiles, the diagonal lands in 3.50 s ± 0.15, and a real mid-range shot rides under 3 tiles of arc and
scars its tile (peak 1.74, sampled on the flying shell every frame). The splash patch moved south of the
flak's intercept box, because the flat arc crosses a box the steep one flew over and the flak ate the
splash shell; open_patch picks its tiles now, the first move sat on the AI's 3x3 start castle, whose
upgrade cluster pooled the splash into one block and dismantled all nine tiles. The nose test fires at a
42-tile far target: the flat arc's pitch swing shrinks with distance, at the old 11-tile range it was a
5-degree waver. The human test waits out the reload before each shot, because the flat arc lands in under
a second at close range, sooner than the 2 s reload, and the old test clicked into the cooldown and never
fired. Watched red, each restored green: the steep branch back (barrels 85.6°, 76.3° and 53.5°, 4.74 s
diagonal, peak 32.91) and gravity back at 5 (4.28 s diagonal, angles and peak unchanged, gravity guards
fly time alone). Suite green, 23 PASS, on a tree that merges master (I100 and I101 landed mid-session).

Visual: tools/godot_render.sh, versus mode, seed 4, the same gun and target on both sides. A 16-tile shot
flies 7.16 s before and 0.73 s after; an 8.5-tile shot 7.20 s and 0.39 s. Boards at /tmp/board_wide.png
and /tmp/board_prof.png hold the flight moments, before on top and after below. 3x barrel crops at
/tmp/crop_barrel_before.png and /tmp/crop_barrel_after.png show the muzzle instant: 83° against 7°. The
board-band crops /tmp/crop_board_before.png and /tmp/crop_board_after.png show the old apex time with no
shell anywhere in frame (it is 32 tiles up, 98° off the camera axis) against the shell skimming the board.
The peak 1.74 comes from the test sampling the real shell; the crops are unverified by eye.
