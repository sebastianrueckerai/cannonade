# Round 28: the mortar, the flak and the big depots

Session 12, phase I for the four buildings rules v2 names without a model (D59), plus the mortar's two projectiles. Painted on the D30 rules with the three style references of round 19. The guns' sheets also get [gun_ladder.png](../../anchors/gun_ladder.png), and the depots' sheets get the round 19 depot board, with [resource_blocks.png](../../anchors/resource_blocks.png) for supply22. Prompts in [prompts/](prompts), boards by [board.py](board.py).

| board | file | three designs |
|---|---|---|
| 1 | [1-mortar-board.png](1-mortar-board.png) | a fat pot between riveted cheek plates on an open ring; a banded stubby mortar in an iron-strapped oak bed; an industrial mortar with a toothed quadrant on a geared mount |
| 2 | [2-flak-board.png](2-flak-board.png) | a twin gun in a boxy cradle; a quad bundle in a drum cradle; a six-barrel rotary volley gun. All on a ball on a short pedestal |
| 3 | [3-supply22-board.png](3-supply22-board.png) | an open log yard under a long roof; a plank store with a lean-to over logs; a square shed under a pyramid roof |
| 4 | [4-supply33-board.png](4-supply33-board.png) | a long two-storey warehouse with a gantry; a granary on posts with a ramp; a barn with a freestanding gantry tower |

Faults found in crops before the pick: both depot boards paint raised roof tiles despite the prompt. supply33 design 3 has a plank roof, not orange tiles.

## Picks (Sebastian, 2026-10-14)

- **Mortar:** board 1, design 1.
- **Flak:** board 2, design 1, the twin gun.
- **supply22:** "All of them lets have some variety just like with the smaller supply depots". Three looks, `supply22` to `supply22.3`.
- **supply33:** "same here, all or them!" Three looks, `supply33` to `supply33.3`.

## Build

[crops.py](crops.py) cuts each pick into its asset's `refs/a-sketch.png`. Each reference view is a three-quarter view. The views of supply22 and supply22.2 flattened their roofs in a second edit, and supply33.3 got orange tiles. Meshy meshy-t2 made the models: the guns at 1,000 triangles (the mortar's 1,450 run came out at 1,520, over budget with the plate), the depots at 550. Then the hand cleanups: `split.json` for the guns, `cleanup.json` for the depots. The cluster bomb and the shard are procedural `build.py` scripts.

Checks: [guns_check.py](guns_check.py), the flak's joint at five pitches. [contain.py](contain.py), every gun's reach against its plate. The round 27 align.py and `tools/shoot_battle.gd --align`, mount minus plate in the placed battle. [gate_renders.py](gate_renders.py), the guns at their tilts.

## Gate

Boards by [gate.py](gate.py): [gate-guns.png](gate-guns.png) and [gate-depots.png](gate-depots.png), from the frames in [frames/](frames) and the renders in [renders/](renders).

The Gemini critic failed both boards, [critique/](critique). Each fault was checked in crops and numbers. One was real: when the flak aimed low, its guns swung over the next tile and through the mortar. The other nine were false: overlaps in projection, a prop hidden behind the mortar in that frame, and nearest-neighbour aliasing at 3x.

Sebastian passed the set: "Pass, ship all ten". For the flak: "Make the whole thing smaller on its base and if needed shorten the barrels a bit. The flag can be less massive than other guns." Then: "Also maybe make the mortar slightly smaller... it seems to somewhat overlap the 2x2 square it should be on. The guns should be contained to their squares!" (D61). The build now scales every gun until it stays inside its plate at every turn and tilt the game uses. All five guns were rebuilt that way, the flak with 25 percent shorter barrels. The reload ring is capped at the plate's edge.
