# Session 06: The asset list and the first item per essential class

Start prompt for the session: "Run session 06 from docs/sessions/06-asset-list-and-first-items.md. Go."

Roadmap items: B16 (phase H, the asset list confirmed by Sebastian), B17 (phase I, the first item per essential class), and the first items of C2 (the vertical slice set). Phases H and I of [art-direction.md](../process/art-direction.md). The bible v0 is tagged `bible-v0` at the end of session 05.

## Why these deliverables

- **The asset list, from the game data.** [asset_list.md](../../game/art-direction/asset_list.md) with one row per item: every building in `data/buildings`, every wall shape and level, the tile, every nature kind, the ships, the projectiles, the effects, every UI screen, every store item. Columns: id, class, footprint, step of the era ladder, priority, route, variants, status. Without it, nobody knows how many assets the game needs or which ones settle the style. Session 05 showed why the data comes first: the plan's four cannon tiers did not match the game's three gun sizes (D28). It feeds phase I, C2 to C6, and the cost estimate of the asset production.
- **Sebastian's marks on the list.** He confirms the essentials and marks what he is unsure about, such as the shield generator and the advanced cannon variants (D17). Unsure items wait, so no money goes into an asset that may leave the game.
- **The first item per essential class.** The essentials are the items that settle the style: the tile, the four wall shapes, the base, the 1x1 cannon, the ship, three nature kinds. The splash, the menu and the logo are done (D25 to D27). For each class: three or four concept sketches in the bible's style, Sebastian picks one, reference views by image editing, then 3D through [assets-3d.md](../process/assets-3d.md) and a screenshot in the game. The first item that holds the bible's look in the game screenshot lets its class go to batch production. One that does not hold sends the fault back to phase C or D, before many assets repeat it.

## Inputs

- The bible v0: [art_bible.md](../../game/art-direction/art_bible.md), [palette.json](../../game/art-direction/palette.json), [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml), [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml), [anchors/](../../game/art-direction/anchors/), above all `world_style.png` and `shape_corner.png` for the 3D builds, and `marketing_style.png` for the painted sketches.
- The game data in [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons): `data/buildings/*.tres` for ids and `size`, the wall shapes and levels, the nature props, the ships, the projectiles, the UI screens. [gameplay_contract.yaml](../../game/art-direction/gameplay_contract.yaml) for the tile size, the camera and the poly budgets. [grid-cannons.md](../grid-cannons.md) before touching the game repo.
- [blender.md](../blender.md) before any bpy. [providers.md](../providers.md) before any paid call.
- Spending cap 10 USD.

## Plan


1. **Phase H.** Read the game data and write `asset_list.md`. Every row names its footprint from the data, never from a picture. Count the variants: team colours, damage states, ladder steps, nature variants. Mark the essentials. Ask Sebastian to confirm the essentials and mark the unsure items, with the list open in his editor. Free.
2. **Phase I, the tile and the walls.** The tile first, because every other asset sits on it, then the four wall shapes, since they share the wall's material and the chamfer rule. Sketches, Sebastian's pick, reference views, a procedural Blender build (C1 proved the route), the geometry report, a small render sheet, then a game screenshot under `xvfb-run`. About 3 USD.
3. **Phase I, the 1x1 cannon and the base.** The cannon is the small gun of [gun_ladder.png](../../game/art-direction/anchors/gun_ladder.png), the swivel gun on a wooden post (D31). The painted sketch shows its look, and the 3D build sets its exact size from the footprint. Its barrel is a separate part with a trunnion pivot, so the game can aim it. Same steps as 2. About 3 USD.
4. **Phase I, the ship and three nature kinds,** if the cap allows. About 3 USD.
5. **Close.** A decision entry per pick, the process-log lines, the roadmap ticks, the plan for session 07: batch production of the classes that held.

## Limits

- At most 25 new images shown per round (D19).
- Sketches are paintings, never in the low-poly render look (D30).
- Sketches are sketches. Sizes need to read, guns of different sizes never look alike, but no exact sizing in 2D. Exact sizes come from the footprint in the 3D build.
- An image with a fault Sebastian already named is not shown. Every fault is checked in a magnified crop first.
- Godot runs `--headless` or under `xvfb-run`, Blender runs `--background`.
- Game changes land in the game repo on `master`, limited to the assets this plan names. Sebastian's uncommitted edits there stay untouched.
- Every image and mesh keeps its sidecar. Every pick is Sebastian's, asked with the images open.

## Done when

`asset_list.md` exists and Sebastian has confirmed the essentials. The tile, the four wall shapes, the 1x1 cannon and the base each have a picked sketch, reference views, a 3D asset in the game repo and a game screenshot that Sebastian approved, or a recorded fault sent back to phase C or D. The session 07 plan is written.

## Change of plan, 12 October

Sebastian changed the order of phase I after the asset list.

- **Phase H.** [asset_list.md](../../game/art-direction/asset_list.md) is rewritten from the game data. It now explains how the game makes its buildings: draws, merges of block squares, the depot, supply. Sebastian set the first batch in place of the essentials (D33): one standard gun per size, the depot, the timber and iron blocks (D32), the four wall shapes at both heights, the base, the tile with its colours, the cannonball, and the engine light (C11). The other block buildings, the ship and nature wait.
- **Phase I starts with the guns, and the route is a test.** The guns already have picked sketches (D31), so they skip the sketch round. The image-to-3D route comes first and the procedural build is the last resort (D34). Each experiment runs on Tripo and on Meshy: four inputs, three ways to make the barrel a separate part, a ladder of face counts. The results are on [round 18](../../game/art-direction/rounds/18-gun-3d/RESULTS.md).
- **Tooling.** [mesh.py](../../pipeline/mesh.py) runs Tripo and Meshy, [meshsheet.py](../../pipeline/meshsheet.py) compares the results in one sheet, [barrel.py](../../pipeline/barrel.py) splits a gun into barrel and mount with the pivot on the trunnion axis. The spending cap now counts only the session's own sidecars, from `SESSION_START`.
- **Spend.** Sebastian raised the cap to 20 USD for the route test. Tripo's API credits are bought apart from Tripo Studio, and he paid 14 USD for 1,500 of them.
- **Next, after his verdict on the route.** The guns in the game with the pivot, then sketches for the depot and the base, then the walls, the tile and the light.
- **Later the same day.** One side view on Meshy's low-poly model is the best input (round 18, experiment 5). Git LFS for new binaries (D35), Meshy for the 3D work (D36). Twelve guns stand on [tools/gun_test.tscn](/home/womb/repos/grid-cannons/tools/gun_test.tscn) in the game for Sebastian's verdict on pivots and face counts. The cap rose to 25 USD, spend 22.75 USD.

## Status, end of session

Phase H is done. Phase I made the three guns and stopped before the rest of the first batch, which moves to session 07.

- **Phase H, done.** [asset_list.md](../../game/art-direction/asset_list.md) comes from the game data and explains the draws, the merges and supply. Sebastian set the first batch (D33) and the two blocks, timber and iron (D32). B16 is ticked.
- **Phase I, the guns.** Round [18](../../game/art-direction/rounds/18-gun-3d/RESULTS.md) tested the 3D route: Tripo against Meshy, four inputs, three ways to free the barrel, a ladder of face counts, then the number of views. Meshy won (D36). One side view on its low-poly model is the best input. Sebastian picked the second-lowest count of each gun on the bench in the game (D37). Their barrels were cleaned by hand in Blender, so only the barrel moves, about its trunnion. The three `final.glb` stand on [tools/gun_test.tscn](/home/womb/repos/grid-cannons/tools/gun_test.tscn) in the game repo, not yet in the art layer.
- **Process.** The 3D chart, [assets-3d.md](../process/assets-3d.md), has the generative route step by step, with the cleanup by hand as a required step. Git LFS takes new binaries (D35). The budget reads from `.env.session`.
- **Not done from this plan.** The tile, the four wall shapes, the base, and the game screenshot of each. Also the rest of the first batch: the depot, the blocks, the cannonball, the engine light. All of it moves to [session 07](07-first-batch-in-the-game.md). The ship and nature moved to later with D33.
- **Spend.** 22.75 USD against a cap Sebastian raised to 25 USD: Tripo 10.00 including one charged run without a model, Meshy 10.50 at the plan price, fal 2.25. Tripo has 500 API credits left, Meshy 575 of its 1,100 monthly credits, which reset on 11 November.
- **Open in the game repo.** Sebastian's editor resaved `tools/gun_test.tscn`, which stays uncommitted in his checkout.
