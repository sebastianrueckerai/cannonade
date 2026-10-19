# Session 24: Rampart wall pieces

Sebastian, 2026-10-19: "I now dislike my system of placing 1x1 blocks with
connectors. I want to radically change it closer to the system in rampart."
Walls connect wherever a field next to them holds a wall; two diagonal walls
never connect; any side contact makes the walls one. His sketch sets seven
pieces, `+` an empty cell, all rotatable:

```
#    ##   ###   ####   ##+   +#+   +#+
                           +##   ###   ###
                                 +#+
```

Mid-turn he added the reach rule: building stays possible as long as one tile
of the new piece is within n tiles of an existing wall of a friendly castle,
n picked here, so nobody builds behind enemy lines at the start.

Locked with him this session: the seven shapes are the pieces the hand deals
(placement stamps walls, no per-tile model inference anywhere); stacking stays,
but only the single block stacks; the Sandbox editor keeps per-tile painting;
the draw is weighted, small pieces common. Today's live game already deals
shape pieces and the player rotates them — what dies is the connector
machinery around that draw, not the dealing itself.

## The design

**Pieces and the placed unit.** Seven piece defs in [data/buildings/](../../../data/buildings):
`wall_1`, `wall_2`, `wall_3`, `wall_4` (1 to 4 tiles in a row), `wall_s` (S/Z),
`wall_t` (T), `wall_x` (plus). One placed def `wall`, the full-tile wall block:
its `access` blocks all nine fine cells of its tile, `draw_weight` 0 — never
drawn, only stamped. Piece defs carry their footprint in new fields:
`pattern_w`, `pattern_h` and `pattern` (true = wall tile, column-major from
the lower left) plus `anchor_x`, `anchor_z`, the one wall tile that sits under
the cursor. A 4x1 piece cannot live in the 3x3 `access` grid, so pieces never
touch `access`; [BuildingBlock.gd](../../../scripts/components/BuildingBlock.gd)
keeps its 9-bool grid for the placed `wall` only, and a small new helper
rotates pattern and anchor together. `get_next_wall` keeps its random quarter
turn through that helper. Piece `draw_weight`s, first lab guesses: 30, 25, 15,
10, 10, 6, 4 percent. The four old connector defs (`wall_line`, `wall_corner`,
`wall_tee`, `wall_cross`) park D64-style with `parked = true`.

**Placement.** The held piece node is the ghost: `next_wall_to_map` parents it
to the hovered tile, which carries the pattern's anchor cell, so the ghost
sits exactly where the piece lands and rotation pivots under the cursor.
Every pattern names a wall tile as its anchor: the centre tile of `wall_1`,
`wall_3` and `wall_x`; one middle tile of `wall_2`, `wall_4` and `wall_s`; the
centre of `wall_t`'s crossbar. (Settled plan-author call after the builder
check: the alternative — bounding-box centre on the cursor — needs half-tile
offsets against the tile grid and was rejected; Sebastian can veto.) The
piece prefabs are authored with the anchor segment at the origin. Placing
consumes the held node and stamps one fresh `wall` spawn on every footprint
tile through `build_wall`, so `wallTiles`, `miniMap`, `StatesMap`, targeting
and damage all keep seeing today's per-tile wall. `wall_1` takes the old fast
path: the held node itself is placed, as today. Every footprint tile must pass
today's free check (no structure, dry, not disabled, no ship, on the map).
Rotation keys work as today, before placement.

**Reach (I47).** A piece, gun or building goes down only when at least one of
its footprint tiles sits within Chebyshev distance 2 (`map.buildingRange`) of
an own wall tile or a tile covered by an own castle that is not a ruin. Guns
keep the same gate with their centre tile. The `inBuildRange` array and its
marking machinery (`mark_buildable_area_waterflow`, `mark_buildable_area_line_of_sight`,
`remove_buildable_area`, the AI override) die; the gate is a predicate at
hover time over `wallTiles` plus live castles. Anchors are walls and castles
only, Sebastian's "wall of friendly castle"; guns and depots no longer seed
building ground. The gate is pure distance: water bars nothing by itself,
only the free-tile check does (the practice map holds the only river; settled
plan-author call, flagged). The Sandbox editor bypasses the gate, as it
bypasses placement rules today.

**Stacking.** Only `wall_1` stacks, on an own wall tile with no upper, not
burning. `_stackable_wall_fits` loses its connector-subset check; the held
def must be `wall_1`. That tile takes two shells, upper first — the damage
path (`damage_building_place`, `damage_stacked_wall`) stands unchanged.

**Check and battle.** Unchanged. The ring check floods fine cells; a full-tile
block closes rings like a thin wall did, diagonals never join; walls matter
only at the check; shells kill per tile.

**AI.** The connector planner dies: `BuildingPlan`'s
`xz2upDownLeftRight`, `_score_connection`, `_score_connection_impl`,
`_update_direction_dict`, the detour paths, `connectionMemo`, and
`fits_plan_with_clockwise_rotations_of_input`. Plans stay rectangles of ring
tiles with the castle term. With the marking override gone, `inPlanRange`
seeds at planning time from the same anchor set — own walls and live castles —
at today's plan radius 3, so the search keeps its geography and budget
(settled plan-author call). `try_build_next_wall` fits footprints: for each of
the four rotations it walks the unfinished ring tiles as anchor candidates and
places the first piece whose every footprint tile is an unfinished ring tile;
otherwise the piece flies away, as today. `try_stack_next_wall` stacks the
monomino on any own uncovered wall near a plan. The search gets faster by
losing the connector scorer.

**Sandbox.** Painting places `wall` monominoes per tile. `_connectors`,
`_place_wall`'s shape pick, `_reshape_around`, `_reshape_wall` and the bulk
reshape in `apply_items`/`restore` die. `Catalog.spawn_wall_for` and its
`_wall_shapes` cache die; loading maps any parked wall id (`wall_line` and
friends) to `wall`, so shipped scenarios and old saves keep their tiles and
only lose the cosmetic thin-wall shapes.

**Start rings.** `_wall_in` and `_build_from_random_prefabs` stamp `wall`
monominoes on the same ring tiles; `Main._place_castles` keeps its geometry.

**Models (C15).** On the D49 painted path: `wall_block`, one full-tile wall
segment; `wall_block_upper`, its storey; the seven piece models, each built
from linked copies of the segment so butted pieces read as one continuous
wall. The untracked `wall_straight.glb` from 2026-10-18 is the candidate
segment — inspect, adopt or rebuild, then commit it with its sidecar. The
wrapper scenes point the defs at the models; walls join the normal model path
(`Catalog.spawn` stops skipping `Art.attach` for walls). [WallModel.gd](../../../scripts/WallModel.gd)
and its FBX texture fallback die; [Wall.gd](../../../scripts/components/Wall.gd)
keeps the upper swap (`WallBehaviour` with one upper model). The nine old wall
glbs, the 34 FBX wrappers and the `Block*` placeholders park. The hand gui
slot's top-down camera fits the held piece (it was fixed at 1.6).

**Rules doc.** [rules-v3-draft.md](../game/design/rules-v3-draft.md) section 5
gains: only a single block stacks on a wall tile. Section 9's draw question
is answered: pieces, weighted. The README's wall text follows.

## The commits

Each rule ships with a test that ran red with the rule broken on purpose.

1. **Art and data.** The segment, its upper and the seven piece models through
   the pipeline and `godot_sync`; wrapper scenes; the eight defs; parking;
   legacy-id mapping in the loader. Tests: `tests/catalog_test` (each piece
   drawable at its weight, `wall` not, a parked id loads as `wall`),
   `tests/flood_test` (a full-block ring closes, diagonal blocks never join).
2. **Hand, placement, reach.** Draw, ghost on the anchor tile, pattern
   rotation, consume-and-stamp, the reach gate, the marking machinery
   deleted. Tests: `tests/human` (every piece's ghost tiles equal its placed
   tiles under rotation — the Unity z mirror is the trap here — and an I3
   leaves three walls in `wallTiles`), a reach case (all tiles past n from own
   walls and castles refused, a chain extends the reach), `tests/preview_test`
   rewritten around the piece glbs' footprints.
3. **Stacking.** Monomino-only, no connector check, upper first. Test:
   `tests/human` stacking case (watched red under the old subset rule).
4. **AI.** Footprint fitting, connector planner deleted, plan-range seeding.
   Tests: `tests/ai_test` (the AI closes a ring from pieces), `tests/sim`
   (walls placed per battle at least as before).
5. **Sandbox, rings, tools, bookkeeping.** Per-tile painting, reshapers
   deleted, start rings, shipped scenarios load, the dying calls in
   `tools/shoot_battle.gd` (`spawn_wall_for`, `Sandbox._connectors`) and
   `tools/previews.gd` (`ibr`) rewritten, `rules-v3-draft.md`, README,
   roadmap ticks (I46, I47, C15), K6 struck (the connector search it
   describes is gone). Tests: `tests/sandbox_test` (paint, erase, an old
   scenario loads), the full suite green.

## Deliverables

1. C15: the eight models on the painted path, a render sheet before the sync.
2. I46 and I47 in the game, suite green, played once in the Sandbox and once
   in Player vs. AI.
3. The bookkeeping: this doc, the roadmap, the rules and README edits.

## Limits

- No image-model spend planned; the models are local Blender work. Ask before
  any run that would pass the session window in `art/.env.session`.
- Numbers are first guesses for the lab: draw weights, n = 2.
- The reach gate changes gun seeding: after a battle that killed every wall,
  rebuilding starts from the castle, not from surviving guns. Flagged to
  Sebastian, his rule as stated.

## As built

The design above is the approved one. [24-wall-pieces-impl.md](24-wall-pieces-impl.md) holds the task plan. These parts were built differently:

- **No piece models, no pattern fields.** A piece def lists its cells as offsets from the anchor (`BuildingDef.piece`), and its node shows the block's model at each cell. The ghost is exactly what the piece places. C15 is two models, `wall` and `wall_upper`.
- **No `wall_1` fast path.** Every placement and every stack consumes the held piece and spawns fresh blocks.
- **No legacy id mapping.** Scenarios have always stored walls as id `wall`, which is now the block's own id.
- **Start rings go through `build_wall`.** Their tiles enter `wallTiles`, so the AI can target start rings and reach can anchor on them. Once rings counted as walls, the sim's check that each AI builds walls passed by itself. It now counts walls built beyond the start ring.
- **Reach is a lazy mask.** It is marked stale on every own placement and loss and on every castle hand-over, and rebuilt at the next read. Before that change, every block rebuilt both masks.
- **A piece's blocks share one flood.** `StatesMap.update_tiles` replaces one flood per block.
- **The dead upgrade search is deleted.** BuildingPlan's upgrade-tile search had no caller since session 18.
- **The AI's loose-gun path is gone.** Session 18 let the AI drop a gun on any free tile in reach when no plan had room. Then the guns seeded reach and spread outward, and the old planner wrapped them. Under the new rule guns anchor nothing, so all six loose guns stacked two tiles from the start ring. Walling them in needs walls three tiles out, beyond reach, and the check burned them. Five or six of six burned, where the old AI lost at most one on the same seed. Now a gun goes only into a plan's enclosure and waits in hand until a plan has room: none of six burned in six runs.
- **The slot colour comes from the visible mesh.** `U.get_color` read the hidden placeholder box's brown and tinted the held piece with it. It now skips hidden meshes.
- **`wall_straight.glb` was not adopted.** The untracked file in the main checkout is session 01's thin plumbing slab, not a full tile.

## Result

The pieces, the reach rule and the block ship on master. The suite runs green, 18 entries.

**The AI builds well.** In 130 s of ai2, each AI built over 200 walls and held three castles.

**Every new rule was watched red.** I broke each one on purpose before its commit:

- the AI keeping a gun that no plan can wall
- the slot colour
- the diagonal rule, under a 4-connected flood
- the clockwise cell turn
- single-block stacking
- an AI that never builds
- reach requiring every tile
- reach seeded from every own tile
- the castle hand-over

**Frame times rose, then partly fell back.**

| run | p99 frame | worst frame |
|---|---|---|
| baseline, old walls | 16.5 ms | 28.2 ms |
| pieces, before fix | 24.0 ms | 62.7 ms |
| pieces, after fix | 21.0 ms | 44.8 ms |

The fix gave a piece's blocks one shared flood and made the reach rebuild lazily. The rest is spawn cost: each building's art attach takes about 3 ms, and an action now places 3 to 5 tiles instead of one. K7 holds the idea for cutting it.

**Open:** Sebastian's pass on the block's look (C15). The same view and seed before and after, magnified 3x: [the start ring](24-walls-ring-before-after.png) and [the hand slot](24-walls-slot-before-after.png).
