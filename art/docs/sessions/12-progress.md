# Session 12 progress

- Budget: 14 USD cap from 2026-10-14T22:49 (`.env.session`). Spent: about 5.56 USD (4 sketch boards, 10 reference views, 10 Meshy runs, 2 critic calls).
- Worktree: `.claude/worktrees/session12` (branch `session12`), `.env.tools` and `.env.session` linked. Blender socket up on 9876. Game repo: Sebastian's uncommitted `tools/gun_test.tscn` and untracked `wall_straight.glb` stay untouched; game work goes through a game worktree.
- Round folder: [28-advanced-buildings](../../game/art-direction/rounds/28-advanced-buildings).

## Found while reading

- The depots go generative on Meshy with cleanup.py: the "Which route" table is binding and the plan defers to it. rules.md section 13 says "procedural", which the table overrides.
- The flak's `guns` anchor: `Flak.gd` aims it with `U.look_at`, which replaces the whole basis (scale kept). Art.attach keeps the anchor's prefab orientation and preserves the part's rotation relative to it, so a `guns` part posed pitched up would aim that far above every target. The glb part must aim along its own forward axis, and the anchor has to take the part's rest orientation so the flak rests pointing at the sky.
- The prefab's `Guns` node is a MeshInstance3D with no script, so Art.attach hides it, and a part reparented under it is hidden with it. The F8-style check of `guns` must catch this. Fix in Art.gd: the anchor shows again with its own mesh dropped.
- `Guns` has scale 0.7 in the prefab. The recoil scales it 0.7 to 0.595 and back. The art compensates at attach, so the art pulses to 85 percent on a shot. That is gameplay code and stays.
- Barrel anchors are turned 180 degrees about Y in the prefabs, and the Shooter keeps their rotation.y and z. So the take-the-part's-orientation rule must not apply to `barrel`.

## Round 28 sketches

- Painted with nano-banana-2.1/edit at 2K, the three style refs of round 19, plus gun_ladder.png for the guns and the round 19 depot board for the depots (plus resource_blocks.png for supply22).
- Faults found in crops: both depot boards paint raised roof tiles despite the prompt (the reference view flattens them, the round 19 lesson). supply33 design 3 has a plank roof, not orange tiles. supply33 design 2 is close to the 1x1 depot design 3, and design 1 to the 1x1 depot design 4.

## Picks (2026-10-14)

- Mortar: board 1, design 1, the pot mortar between cheek plates on an open ring. Flak: board 2, design 1, the twin gun.
- supply22 and supply33: "All of them lets have some variety just like with the smaller supply depots", "same here, all or them!". Six looks: `supply22` to `supply22.3`, `supply33` to `supply33.3`, in board order.

## Build

- Reference views: one three-quarter view per pick, nano-banana edit of the crop (`refs/a-sketch.png`, cut by the round's crops.py). supply22 and supply22.2 kept raised tiles, flattened by a second edit with supply33's view as the roof example (`c-view-flatroof.png`). supply33.3 retiled orange in its view.
- Meshy meshy-t2: guns at 1000 and 1450, depots at 550. Mortar 1450 came out at 1,520 triangles, over the 1,500 budget with the plate, so the final uses 1000 (1,107 with the plate). Flak 1000 (1,003 with the plate): the 1450 run spent 352 triangles on the ball.
- barrel.py gained `pitch` (a part that points up in the source is levelled about the pivot, so the game's tilt works) and `part: guns` (no projectile_spawn, the rest pitch stays as the part's rotation). The pivot takes all three coordinates of the pivot pieces.
- The flak's cradle swung into the pedestal above 70 degrees (sampled edges and faces against the pedestal). Fix `lift`: the ball and the guns up 0.3 m on a longer neck. Now clear from 0 to 90 at every yaw, and no sample enters the neck. Check script: the round's guns_check.py and the clearance sweep.
- Depots: cleanup.json at turn 0 and fit = footprint less 5 cm a side (1.9, 2.9), supply33.2 at turn 90 (the ramp to the camera). 393 to 488 triangles.
- Projectiles: cluster_bomb, an 8-segment ball with a proud band, 96 triangles, sphere UVs so the iron painter does not project a box. cluster_shard, a convex hull of 10 seeded points, 16 triangles, seed 28 for a compact chunk.
- Alignment gate (round 27 align.py): mount minus plate 0.0 / 0.0 on both new guns.
- Found for session 13: the Shooter sleeps every gun at -10 degrees. The mortar then lies with its mouth forward like a short cannon. A per-gun rest angle is gameplay code.

## Game side (worktree /home/womb/repos/cannonade-s12, branch session12)

- supply33.tres: 3x3, 16 supply, no recipe, model prefab Supply22.tscn (the art hides its placeholder).
- Art.gd: the probe found two faults with the flak. (1) The prefab's `Guns` is a MeshInstance3D placeholder, so attach hid it, and the art guns under it were invisible. (2) After look_at the art pointed 43 degrees above the target, because the anchor kept the prefab's orientation and the part kept its rest pitch relative to it. Fixed: the anchor of an AIMED part (guns) takes the part's rest orientation. A placeholder mesh anchor shows again with its mesh dropped. MOVING parts (barrel, guns) both lift the indicators. Probe after the fix: visible, aim error 0.000004 degrees.
- shoot_battle.gd: the forts widen to x 2..27 and hold supply33, cannon22b, flak22 and supply22. `--align` prints mount minus plate per gun after placement: 0.000 / 0.000 on all five guns of both forts.
- Trace: the bomb bursts about 19 m up at 4.0 s, and its five shards fall at 5 m/s to the ground by 7.3 s, all with the art attached.

## Gate critic (Gemini, round 28 critique/)

- Guns: FAIL with 5 faults. Checked: the mortar at -10 and +80 is false (the pot stays 1 to 9 cm above the rails at every tilt and never passes the cheek plates' outer face, 0.614 against 0.759 m). The flak joint at 80 and 90 is false (the dense sweep and the neck check are clear). The flak's guns passing through the mortar when aiming low in game is REAL.
- Depots: FAIL with 5 faults, all false in crops: supply22.2 shows its door. supply22.3's sawhorse is hidden behind the mortar in that frame. supply33's loading door is on its gable end, which faces the side. The supply33.2 roof has no holes at 2x. The "shredded" roof is 3x nearest-neighbour aliasing.
- The real fault: Flak.gd aims the guns at any target, down to level, and at low aims the 1.5 m guns reach 0.5 m over the next tile. The fix is a minimum aim elevation in Flak.gd, which is gameplay code outside the session plan. Asked Sebastian.

## Gate and ship

- Sebastian passed the ten ("Pass, ship all ten"). For the flak: "Make the whole thing smaller on its base and if needed shorten the barrels a bit." Then: "The guns should be contained to their squares!" (D61).
- barrel.py now scales every gun to stay 2 cm inside its plate at every turn and tilt (barrel -10 to 90, guns 0 to 90). The hand `fit` for the flak is gone, and only the rule remains. All five guns were rebuilt. Height factors: small 0.75, heavy 0.80, siege 0.81, mortar 0.85, flak 0.52 with 25 percent shorter barrels. contain.py: every reach is the half side less 2 cm. align.py and `--align`: 0.000 on all.
- Cooldown.gd caps the reload ring at the plate's half side. Before, it was the mount radius plus 6 cm, which ran past the plate on the 2x2 guns.
- 13 assets approved and synced: the ten, plus cannon, cannon22a and cannon33a. check_art: 37 models, 0 problems. run_tests.sh: every scene passes except lab, which fails the same way on master (checked in a temporary worktree at a08dd13).
- Game commit d78d92f on master, pushed. After board: [gate-after.png](../../game/art-direction/rounds/28-advanced-buildings/gate-after.png).
