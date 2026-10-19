# Rampart wall pieces: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The hand deals seven rotatable wall pieces that stamp full-tile wall blocks; side-touching blocks form one wall, diagonals never join; placement needs one tile within 2 of an own wall or castle.

**Architecture:** One placed unit, the full-tile `wall` block, so damage, the ring check, targeting and stacking keep their per-tile paths. A hand piece is a def with cell offsets; its node shows one block look per cell, so the ghost is the placement. Reach is a mask rebuilt from own walls and castles on every change, replacing the incremental waterflow marking.

**Tech Stack:** Godot 4.7 GDScript, headless tests via [run_tests.sh](../../../run_tests.sh); Blender 5.2 through `blx` and [asset.py](../../pipeline/asset.py) for the models.

**Spec:** [24-wall-pieces.md](24-wall-pieces.md). Executed; where the build differs from these tasks, its As built section says so.

## Global Constraints

- Tile coordinates: x right, z up; tile z maps to Godot −z. A clockwise quarter turn maps a cell (x, z) to (z, −x), matching `rotate_clockwise`'s −90° about +Y.
- Pieces, anchor cell (0, 0), draw weights: `wall_1` [(0,0)] 30; `wall_2` [(0,0),(1,0)] 25; `wall_3` [(-1,0),(0,0),(1,0)] 15; `wall_4` [(-1,0),(0,0),(1,0),(2,0)] 10; `wall_s` [(-1,1),(0,1),(0,0),(1,0)] 10; `wall_t` [(-1,0),(0,0),(1,0),(0,1)] 6; `wall_x` [(0,1),(-1,0),(0,0),(1,0),(0,-1)] 4.
- Reach radius n = `map.buildingRange` = 2, Chebyshev, anchors: own wall tiles and the tiles of own castles that are not ruins.
- Park, never delete: `wall_line`, `wall_corner`, `wall_tee`, `wall_cross` get `parked = true`; their prefabs, FBX files, [WallModel.gd](../../../scripts/WallModel.gd), `WallBehaviour`'s model arrays and the nine old glbs stay so the parked files still load.
- Every new test runs red with its rule broken on purpose before the commit. The suite stays green after each task.
- Player-facing copy says Cannonade; no new strings name Grid Cannons.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Changes against the design doc, settled while planning

- No piece models. A piece node holds one instance of the block's model and art per cell, so the seven piece glbs of C15 are not needed. C15 is the block `wall` and its storey `wall_upper`.
- No `wall_1` fast path. Every placement and every stack consumes the held piece and spawns fresh `wall` blocks.
- No legacy id mapping. Scenarios and saves have always stored walls as id `wall`, which is now the block's own id.
- Start rings go through `build_wall`, so their tiles enter `wallTiles`. Today they bypass it: the AI never targets start rings, and the reach anchors would miss them.
- [BuildingPlan.gd](../../../scripts/BuildingPlan.gd)'s upgrade-tile search (`try_initialize_xz_upgrade_tiles` and its helpers) has had no caller since session 18 and reads the dying `ibr`. It is deleted.

## Review Focus

1. **Seeded layout drift.** Each placed wall drew a random FBX look from the game RNG, and `_build_from_random_prefabs` shuffled with it. Both draws go, so every seed builds a different neutral-castle layout. Fixtures with fixed tiles (human far tile (10, 15), the practice pocket at (15, 7)) must keep landing on free ground. Re-derive them from the built map where they break. Task 2 runs the whole suite.
2. **A piece hanging off the map edge.** `piece_tiles` returns empty, nothing places, nothing indexes out of range. Task 3 adds the edge case to `tests/human`.
3. **The largest piece in the hand slot.** `wall_4` and `wall_x` fit the 120 px slot at every rotation. Task 3 adds the bounds check to `tests/preview_test`.
4. **Reach once every wall is shot away.** The castle alone still anchors reach. Task 4 adds this case to `tests/human`.
5. **A claimed or ruined castle.** Reach follows ownership at once through `Castle.hold_tiles`. Task 4 checks the ruin case through `become_ruin`.

---

### Task 1: The wall block models

**Files:**
- Create: [art/game/assets/3d/wall_block.py](../../game/assets/3d/wall_block.py), `art/game/assets/3d/wall/asset.yaml`, `art/game/assets/3d/wall_upper/asset.yaml`
- Sync into: `assets/art/3d/wall.glb`, `assets/art/3d/wall_upper.glb`, `assets/art/manifest.json`

**Interfaces:**
- Produces: art ids `wall` and `wall_upper`, origin at the tile centre on the ground, Y up. `wall` spans 1.0 × 1.0 × 1.0 m; `wall_upper` spans 1.0 m in x and z, its geometry from 0.75 to 1.75 m.

- [ ] **Step 1: Before shot.** Before any code change, run `xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/screenshot.tscn -- --mode=versus --seed=7 --at=5 --out=/tmp/walls-before`.
- [ ] **Step 2: Write `wall_block.py`.** `build(asset)`: level `base` makes one box covering the full tile from 0 to 0.75 m, plus merlons 0.25 m tall on a 0.5 m period, 2 × 2 per tile, each 0.25 wide at [0.125, 0.375] on both axes, so a seam falls mid-gap. Level `upper` makes a body from 0.75 to 1.5 m covering the full tile, which swallows the lower merlons, plus the same merlons on top. Chamfer the merlon tops and the merlon verticals at 0.05 m. Never chamfer an edge in a tile boundary plane. Copy `box()` and `on_boundary()` from [wall_cornice.py](../../game/assets/3d/wall_cornice.py).
- [ ] **Step 3: Write both `asset.yaml` files.** Copy `wall_line_base`'s and `wall_line_upper`'s files, set `asset_id`, `build: ../wall_block.py`, `level`, dims max 1.0 / 1.0 / 1.0, `max_tris: 200`. Keep their paint specs and seeds.
- [ ] **Step 4: Build.** Run `cd art && uv run --script pipeline/asset.py game/assets/3d/wall` and the same for `wall_upper`. Expected: `limits_ok` true, report dims 1.0 × 1.0 × 1.0.
- [ ] **Step 5: Sync for review.** Run `GAME_REPO=<worktree> uv run --script pipeline/godot_sync.py game/assets/3d/wall game/assets/3d/wall_upper --force`. Approval waits for Sebastian's pass.
- [ ] **Step 6: Run `./run_tests.sh`.** Expected: all PASS, and the art check validates the two new ids.
- [ ] **Step 7: Commit** the build script, both asset folders (yaml, final.glb, source.blend, report, manifest) and the synced files.

### Task 2: The full-tile block is the placed wall

**Files:**
- Create: `data/buildings/wall.tres`, `prefabs/WallBlock.tscn`
- Modify: [Wall.gd](../../../scripts/components/Wall.gd), [Catalog.gd](../../../scripts/Catalog.gd) (`spawn`, `configure`, `_apply_params`, `_check_catalog`), [BuildingPlace.gd](../../../scripts/components/BuildingPlace.gd) (`build`), [PlayerController.gd](../../../scripts/components/PlayerController.gd) (`_wall_in`, `build_wall`, `next_wall_to_wall`), [Sandbox.gd](../../../scripts/sandbox/Sandbox.gd), [SandboxUI.gd](../../../scripts/sandbox/SandboxUI.gd), [ScenarioDef.gd](../../../scripts/data/ScenarioDef.gd), [tools/shoot_battle.gd](../../../tools/shoot_battle.gd)
- Test: [tests/flood_test.gd](../../../tests/flood_test.gd), [tests/ring.gd](../../../tests/ring.gd), [tests/catalog_test.gd](../../../tests/catalog_test.gd), [tests/human.gd](../../../tests/human.gd) `_pocket`, [tests/practice_test.gd](../../../tests/practice_test.gd), [tests/check_test.gd](../../../tests/check_test.gd)

**Interfaces:**
- Produces: def `wall`, category WALL, `access` all nine `false`, `draw_weight` 0, `model` WallBlock.tscn (a 1 × 0.75 × 1 placeholder box), behaviours one `WallBehaviour` with empty arrays.
- Produces: `Catalog.spawn` attaches art for walls like every other def. `Wall.show_lower` returns at once when the def has no lower models, which is the block's case. The connector pieces keep drawing and placing as today until Task 3.
- Produces: `_wall_in(x0, z0, x1, z1)` places a `wall` block through `build_wall` on every border tile. `build_wall(tile, wall)` appends to `wallTiles`, then calls `_build`.
- Removes: `Catalog.spawn_wall_for`, `_wall_shapes`; `_build_from_random_prefabs`; Sandbox `_is_wall_of`, `_connectors`, `_reshape_wall`, `_reshape_around`, the wall dictionaries in `apply_items`/`restore`, the `"wall_line"` lookup at line 586.

- [ ] **Step 1: Write the failing flood tests** in flood_test after the ring case:

```gdscript
# full blocks: side contact closes, a corner contact alone never joins
Ring.build_rect(player, map, 16, 4, 20, 8, _compare)            # blocks on every border tile
_check(map.is_tile_enclosed(18, 6), "a ring of full blocks encloses its inside")
var corner = map.tiles[16][4]
corner.un_build()
_compare(corner)
_check(not map.is_tile_enclosed(18, 6), "a ring missing one corner block stays open: diagonal blocks do not join")
```

`Ring.build_rect` places `Catalog.spawn("wall")` per border tile. Add a catalog_test check: `wall` is a WALL def that never draws, and its access blocks all nine cells.

- [ ] **Step 2: Run** `godot --headless res://tests/flood_test.tscn`. Expected: FAIL, unknown building `wall`.
- [ ] **Step 3: Implement the interfaces above.** `Catalog._check_catalog` reports `"no wall block: data/buildings/wall.tres"` when `wall` is missing. Test fixtures built with `_build_from_random_prefabs` place `wall` blocks through `build_wall`. Sandbox `_place_wall(s, xz)` returns `player(s).place(Catalog.get_def("wall"), xz.x, xz.y) != null`. The SandboxUI tooltip becomes "Click and drag to draw walls".
- [ ] **Step 4: Run** `./run_tests.sh`. Expected: all PASS. Where a seeded fixture now lands on a castle (Review Focus 1), re-derive it from the built map, never by loosening an assertion.
- [ ] **Step 5: Break on purpose.** Give `wall.tres` a thin-line access, run flood_test, and watch the diagonal case go red. Restore it.
- [ ] **Step 6: Commit.**

### Task 3: The hand deals pieces

**Files:**
- Create: `data/buildings/wall_1.tres` to `wall_4.tres`, `wall_s.tres`, `wall_t.tres`, `wall_x.tres`, `prefabs/WallPiece.tscn` (one empty Node3D)
- Modify: [BuildingDef.gd](../../../scripts/data/BuildingDef.gd), [BuildingBlock.gd](../../../scripts/components/BuildingBlock.gd), [Catalog.gd](../../../scripts/Catalog.gd), [BuildingPlace.gd](../../../scripts/components/BuildingPlace.gd), [PlayerController.gd](../../../scripts/components/PlayerController.gd), [AI.gd](../../../scripts/components/AI.gd), [BuildingPlan.gd](../../../scripts/BuildingPlan.gd), [Main.gd](../../../scripts/Main.gd) (hand camera, help line), [tools/previews.gd](../../../tools/previews.gd)
- Test: [tests/human.gd](../../../tests/human.gd), [tests/camera_test.gd](../../../tests/camera_test.gd), [tests/preview_test.gd](../../../tests/preview_test.gd), [tests/ai_test.gd](../../../tests/ai_test.gd), [tests/sim.gd](../../../tests/sim.gd), [tests/catalog_test.gd](../../../tests/catalog_test.gd)

**Interfaces:**
- Produces: the four connector defs park. `Wall.show_upper() -> void` frees the block's `Art` child and attaches `wall_upper`. `Wall.show_lower`, `lowerPrefabs`, `upperPrefabs`, `placeholderModel` and `Catalog._placeholder_path` go. `next_wall_to_wall` lifts the ghost 0.75 m, where the upper body starts.
- Produces: `BuildingDef.piece: Array[Vector2i]`, the cells of a hand piece. It is empty for every other def. `_check_catalog` reports a drawn WALL def without cells.
- Produces: `BuildingBlock.cells: Array[Vector2i]`, the piece's current cells. `rotate_clockwise` and `rotate_counter_clockwise` turn the node and the cells. The access-grid rotation and every connector function go: `connects`, `connects_up_down_left_right`, `connectorsUpDownLeftRight`, `fits_plan*`, `rotate_plan_clockwise`, `BuildingPlace.connects_up_down_left_right`.
- Produces: `Catalog.spawn` of a piece adds one `wall` model instance with `Art.attach(cell, "wall")` per cell. A cell sits at local (c.x, 0, −c.y), in `def.piece` order, so child i belongs to `cells[i]`.
- Produces: `BuildingPlace.is_free() -> bool`, true when the tile holds no structure and `buildable()` is true.
- Produces: `PlayerController.piece_tiles(tile) -> Array`, the tiles of the held piece anchored on `tile`, empty when a cell falls off the map. `can_place_piece(tile) -> bool` is true when every tile is free and one tile is in reach. Until Task 4, "in reach" reads today's `ibr`. `can_stack_on(tile) -> bool` holds when the held piece has one cell and the tile is an own wall with no upper that is not burning.
- Produces: `build_next_wall(tile)` stamps a `wall` block on every tile of `piece_tiles(tile)`, destroys the held piece and draws the next. `stack_wall(tile)` consumes the held piece and stacks a fresh `wall` block.
- Produces: flags `canPlaceWall` and `canPlaceBuilding` replace `canBuildOnTile`. `decorHiddenTiles` and `litTiles` arrays replace `decorHiddenTile`, so the decorations and the highlight cover every footprint tile.
- Produces: `BuildingPlan.ring: Dictionary` (Vector2i → true), the border tiles of the plan rectangle. Each ring tile is free ground (no water, not disabled) or an own wall. `unfinished_ring() -> Dictionary`, `stackable_walls() -> Array`. The connector code goes: `xz2upDownLeftRight*`, `_score_connection*`, `_update_direction_dict`, `_c`, `OX`/`OZ`, `ensure_compatibility*`, `_synchronize_key`, `_combine_keys`, `update_plan_tile`, the dead upgrade-tile search. AI `connectionMemo` becomes `slicing: bool`, which keeps the count cache valid inside one slice only.
- Produces: `AI.try_build_next_wall` checks every rotation and every placement of the held piece that covers an unfinished ring tile. It skips placements that put a cell inside the plan's walled-in tiles or fail `can_place_piece`. It places the piece that covers the most unfinished ring tiles, else the piece flies away. `try_stack_next_wall` stacks a one-cell piece on the first stackable wall of the double-stack plan.

- [ ] **Step 1: Write the failing tests.** In tests/human, the rotation case holds `wall_t` and asserts that X turns `cells` from [(-1,0),(0,0),(1,0),(0,1)] to [(0,1),(0,0),(0,-1),(1,0)] and that Y turns them back. The placement case holds `wall_3`, turned once clockwise, so its cells read [(0,1),(0,0),(0,-1)]. It hovers an anchor whose three tiles are free and within 2 of the start ring, derived from the ring's known tiles. It asserts that the ghost's cell children map through `tile_index_at` to those three tiles. After the click, the same three tiles hold `wall` blocks, `wallTiles` grew by three, the held node is gone and a new piece is offered. The edge case hovers the anchor (0, z) with `wall_3` lying flat: nothing places and no error prints. The stacking case: `wall_1` over an own wall stacks, `wall_3` over an own wall does not. In tests/camera_test, the wheel leaves the held `wall_t`'s `cells` unchanged. tests/preview_test keeps the gui and hover checks for whichever piece is held, and replaces the K4 shape checks with two. For every drawn piece at four rotations, the ghost cells map to anchor + `cells`. In the gui slot, the piece's bounds sit centred and inside the slot camera's view.
- [ ] **Step 2: Run** the human, camera and preview tests. Expected: FAIL on the missing defs.
- [ ] **Step 3: Implement the interfaces above.** `next_wall_to_gui` sets the piece's position to minus the centre of its cell box, so it sits centred. The hand camera's `cam.size` becomes 4.4, which holds a four-long piece. `next_wall_to_map` sets each cell child's global y to its tile's y. The help line reads `LMB: place wall piece / stack a block   RMB: place gun (costs parts) / combine   X / Y: rotate piece   Space: fire   Wheel: zoom   MMB drag: pan   Esc: menu`. `sim._autobuild` keeps only tiles where `can_place_piece` holds. Catalog_test checks that each piece draws at its weight.
- [ ] **Step 4: Run** `./run_tests.sh`. Expected: all PASS, and sim-ai2 shows each AI placing at least 5 walls.
- [ ] **Step 5: Break on purpose and watch each test fail.** Turn the cells counter-clockwise in `rotate_clockwise`. Let a three-cell piece stack. Make `try_build_next_wall` return false; sim-ai2 must fail its wall count. Restore each.
- [ ] **Step 6: Commit.**

### Task 4: Reach

**Files:**
- Modify: [PlayerController.gd](../../../scripts/components/PlayerController.gd), [AI.gd](../../../scripts/components/AI.gd), [BuildingPlan.gd](../../../scripts/BuildingPlan.gd) (`reachable`), [Castle.gd](../../../scripts/components/Castle.gd) (`claim`, `hold_tiles`), [GameController.gd](../../../scripts/components/GameController.gd) (`_initialize_players`), [tools/previews.gd](../../../tools/previews.gd)
- Test: [tests/human.gd](../../../tests/human.gd), and the `ibr` calls in [tests/ai_test.gd](../../../tests/ai_test.gd), [tests/preview_test.gd](../../../tests/preview_test.gd), [tests/sim.gd](../../../tests/sim.gd)

**Interfaces:**
- Produces: `PlayerController.reach: PackedByteArray`, indexed `x * map.sizeZ + z`. `refresh_reach() -> void` rebuilds it as `_anchor_mask(map.buildingRange)`. `_anchor_mask(r: int) -> PackedByteArray` marks 1 within Chebyshev r of `wallTiles` and of the tiles of own castles that are not ruins. `in_reach(x, z) -> bool` replaces `ibr`.
- Produces: `refresh_reach()` runs in `setup()`, after `_build`'s `tile.build`, at the end of `remove_building_from_player`, and in `Castle.hold_tiles` for the old and the new holder. `AI.refresh_reach()` calls super, then sets `inPlanRange = _anchor_mask(maxPlanRange)`.
- Removes: `inBuildRange`, `ibr`, `mark_buildable_area_waterflow` (with the AI override), `mark_buildable_area_line_of_sight`, `remove_buildable_area`, `mark_square_on_array`, the `inBuildRange` setup in GameController, the marking loop in `Castle.claim`.

- [ ] **Step 1: Write the failing reach case** in tests/human. The start ring spans x 13..17 and z 5..9 around the castle at (15, 7). The case walks the castle's row, z = 7, east from x = 17, or west from x = 13 when the east side has fewer than seven free tiles. Below, d is the distance from the ring along that row, and every expectation is derived from d:
  - `wall_1` at d = 3 is refused.
  - `wall_3` lying flat with its anchor at d = 3 covers d = 2, 3 and 4. Only one tile is in reach, and it places.
  - `wall_1` at d = 6 places, because its nearest wall now sits at d = 4. The chain extends reach.
  - A cannon at d = 3 on the opposite side's row is refused.
  - With every own wall un-built, a tile 2 from the castle's edge is in reach and a tile 3 away is not.
  - A ruined castle anchors nothing. After `become_ruin()`, with no walls, the tile next to its edge is out of reach.
- [ ] **Step 2: Run** human.tscn. Expected: FAIL. The chain and the distance-3 cases differ under the waterflow marking, which seeds from guns and spreads by flood.
- [ ] **Step 3: Implement the interfaces above.**
- [ ] **Step 4: Run** `./run_tests.sh`. Expected: all PASS.
- [ ] **Step 5: Break on purpose.** Require all footprint tiles in reach, then only the anchor tile; the one-tile-in-reach case fails each time. Drop the `hold_tiles` refresh; the ruin case fails. Restore each.
- [ ] **Step 6: Commit.**

### Task 5: Docs, the look check, review, merge

**Files:**
- Modify: [README.md](../../../README.md), [Menu.gd](../../../scripts/Menu.gd) (control labels, tutorial), [Art.gd](../../../scripts/Art.gd) (header), [assets/art/README.md](../../../assets/art/README.md), [grid-cannons.md](../grid-cannons.md), [rules-v3-draft.md](../../game/design/rules-v3-draft.md), [decisions.md](../decisions.md) (D75), [ROADMAP.md](../../../ROADMAP.md), [24-wall-pieces.md](24-wall-pieces.md)

- [ ] **Step 1: Copy.** The Menu control labels read: "place the wall piece / stack a single block on one of your walls", "rotate the wall piece clockwise", "rotate the wall piece counter-clockwise", "discard the piece / building in hand". The tutorial gains: "Walls come as pieces you turn and drop. Pieces that share a side form one wall; touching corners do not join. Everything you place needs one tile within two tiles of your walls or of a castle you hold." The README's controls, sandbox and port notes follow.
- [ ] **Step 2: Rules and decisions.** Rules v3 section 1 gains the reach rule. Section 5 gains "Only a single block stacks on a wall tile." Section 9's draw question is answered: walls are drawn pieces, weighted. D75 records Sebastian's four answers and his reach rule, in his words. n = 2 is labelled the plan's first lab value.
- [ ] **Step 3: Roadmap.** Tick I46 and I47. C15 stays open until Sebastian passes the look: built and in the game. Strike K6, whose connector search is gone. Add a note to J9 that the dead upgrade-tile search is deleted. Then write the session plan's result paragraph.
- [ ] **Step 4: After shot.** Repeat Task 1 step 1 with `--out=/tmp/walls-after`, crop the same region of both shots and magnify it, then open the sheet and both crops with `code -r` for Sebastian's pass.
- [ ] **Step 5: Final review.** A fresh reviewer reads the diff from master against the design doc.
- [ ] **Step 6: Merge.** Run `./run_tests.sh` green, commit, push to the main checkout's master, then push to origin.
