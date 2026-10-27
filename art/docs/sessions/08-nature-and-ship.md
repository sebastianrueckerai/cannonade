# Session 08: Nature and the ship

Start prompt for the session: "Run session 08 from docs/sessions/08-nature-and-ship.md. Go."

Roadmap items: C2 (the rest of the vertical slice: rock, tree, bush), C4 (rock: procedural against image-to-3D), C5 and F7 (nature through the art layer), C11 (the render view lit like the game), the ship from the asset list. Phase I of [art-direction.md](../process/art-direction.md) for nature and the ship.

## Why these deliverables

- **Nature, redone.** After the walls and the tile, nature covers the most board. Sebastian found the old props much too small and wants every kind new, bigger and more stylized, like the cover art (D41): round-crowned trees about a tile wide in groves, a few conifers, piles of rounded boulders about a tile across. Bigger props change how the game places them, so the game side is read first. Tripo's leftover credits suit these simple shapes (D36). The game needs F7: `CustomModelMaker` must take its variants from the art layer.
- **The ship.** The single-player mode sails a fleet from the board edge. It is the last placeholder a single-player screenshot shows.
- **The render view lit like the game.** A render sheet and a game screenshot can only be compared under the same light. The game side of C11 is done.

## Inputs

- The route: [assets-3d.md](../process/assets-3d.md), the procedural route with [wall_cornice.py](../../game/assets/3d/wall_cornice.py) as an example of a shared build script, the generative route with [cleanup.py](../../pipeline/cleanup.py) for models that do not move.
- The bible: D41 and the cover art [marketing_style.png](../../game/art-direction/anchors/marketing_style.png) for the nature look, [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml) for the nature budget of 300 triangles, which the round may ask to change, [palette.json](../../game/art-direction/palette.json) for leaf, grass and stone.
- The game: [asset_list.md](../../game/art-direction/asset_list.md) for the 9 nature kinds and their slots, [grid-cannons.md](../grid-cannons.md), [CustomModelMaker.gd](/home/womb/repos/cannonade/scripts/components/CustomModelMaker.gd), [ShipFleet.gd](/home/womb/repos/cannonade/scripts/components/ShipFleet.gd).
- The check in the game: [tools/shoot_battle.tscn](/home/womb/repos/cannonade/tools/shoot_battle.tscn) for buildings, [tools/screenshot.tscn](/home/womb/repos/cannonade/tools/screenshot.tscn) in single mode for the ship and the nature.
- [blender.md](../blender.md) before any bpy, [providers.md](../providers.md) before any paid call.
- Spending cap 10 USD, written in `.env.session` at the end of session 07. Meshy has 350 credits until 11 November, Tripo 500 for simple shapes only (D36).

## Plan

1. **Nature in the game (F7).** Read how `CustomModelMaker` and `BuildingPlace.place_decorations` place the props: how many per tile, at what scale, and whether a crown a tile wide or a grove across tiles fits. `CustomModelMaker` then loads `3d/nature_<kind>.glb` and its looks from the art layer, the FBX stays the fallback. Free.
2. **Nature, the first three kinds, new (D41).** Leaf tree, boulder and bush. Painted sheets in the style of the cover art, with the sizes on a tile grid, Sebastian's pick, then the boulder twice for C4, procedural in Blender and on Tripo, and the tree and the bush by the route that wins. Three looks each. A screenshot of a match in single mode next to the cover art. About 1.5 USD.
3. **The ship.** Three painted designs, Sebastian's pick, a side view, Meshy, the cleanup by hand with its `ship_cannon` anchor, a screenshot of the fleet. About 2 USD.
4. **The render view (C11).** The gameplay-camera view of [render.py](../../pipeline/blender/render.py) under the sun, ambient and sky of [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml), checked side by side with a game screenshot of the same asset. Free.
5. **Close.** A decision entry per pick, the process-log lines, the roadmap ticks, and the plan for session 09.

## Limits

- At most 25 new images shown per round (D19). Sketches are paintings, never in the low-poly render look (D30).
- Every generated model goes through the cleanup by hand and stays inside its triangle budget. Every export is a `.glb`.
- An image with a fault Sebastian already named is not shown. Every fault is checked in a magnified crop first.
- Godot runs `--headless` or under `xvfb-run`, Blender runs `--background`.
- Game changes land in the game repo on `master`, limited to what this plan names. Sebastian's uncommitted edits there stay untouched, including his resave of `tools/gun_test.tscn`.

## Done when

Three nature kinds, new and at the size of the cover art, stand in the game through the art layer, and C4 has its verdict. The ship sails in single mode, or a recorded reason says why not. The render view and a game screenshot of one asset are lit alike. The session 09 plan is written.
