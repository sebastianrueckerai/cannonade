# Session 07: The first batch in the game

Start prompt for the session: "Run session 07 from docs/sessions/07-first-batch-in-the-game.md. Go."

Roadmap items: B17 (phase I, continued), C2 (the first items of the vertical slice set), C11 (the engine light), F8 (the barrel of a real gun in the game), F11 (one wall look in every slot), F12 (projectiles through the art layer). Phase I of [art-direction.md](../process/art-direction.md) for the rest of the first batch (D33).

## Why these deliverables

- **The three guns in the art layer.** They are picked and cleaned (D37), but they stand only on the bench. In `res://assets/art/3d/` they appear in real matches. It is also the first test of a real barrel in the game: the part `barrel` under the prefab's `Barrel`, the tilt the game's `Shooter` gives it, and `projectile_spawn` as the start of every shot (roadmap F8). It feeds every later gun.
- **The engine light and the tile colours.** Without the afternoon light of [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml) and the palette on the tiles, no screenshot can show the bible's look, however good the models are (D33). Today the game paints its tiles from code defaults in `Map.gd`.
- **The tile and the four wall shapes at both heights.** They cover most of the board, so they decide whether the style holds at the default view. Chapter 3 of the bible says the first real wall in the game checks its rules. They are built procedurally in Blender, because their sizes must be exact (D4). One look per shape and level fills all of the game's random slots (roadmap F11).
- **The timber and iron blocks.** They are two of the three building draws, so the player places them all the time. Their designs are picked (D29, D32), so they skip the sketch round and go straight to Meshy.
- **The supply depot and the base.** They have no design yet, so they need a round of painted sketches and Sebastian's pick before any 3D. The base has a technical limit: the game paints the first material of every mesh under it in the team colour, so the team-coloured part, such as a flag or a roof, must be its own material, first on each mesh.
- **The cannonball.** It flies in every shot. It is a sphere built in Blender, plus a small hook so projectiles can come from the art layer (roadmap F12).

## Inputs

- The route: [assets-3d.md](../process/assets-3d.md), above all "The generative route, step by step", and round [18](../../game/art-direction/rounds/18-gun-3d/RESULTS.md). The procedural route and [asset.py](../../pipeline/asset.py) for the walls and the tile, starting from [wall_straight](../../game/assets/3d/wall_straight) of C1.
- The guns: `final.glb`, `source.blend` and `split.json` in [cannon](../../game/assets/3d/cannon), [cannon22a](../../game/assets/3d/cannon22a), [cannon33a](../../game/assets/3d/cannon33a).
- The bible: [art_bible.md](../../game/art-direction/art_bible.md), [palette.json](../../game/art-direction/palette.json), [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml) for the wall, chamfer, merlon and budget numbers, [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml), the anchors `world_style.png` and `shape_corner.png` for the 3D look, `marketing_style.png` for painted sketches, `resource_blocks.png` for the blocks.
- The game: [asset_list.md](../../game/art-direction/asset_list.md) for ids, footprints and wall slots, [gameplay_contract.yaml](../../game/art-direction/gameplay_contract.yaml), [grid-cannons.md](../grid-cannons.md) before touching [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons).
- [blender.md](../blender.md) before any bpy, [providers.md](../providers.md) before any paid call.
- Spending cap 10 USD. The budget was reset at the end of session 06: `.env.session` holds `SESSION_START=2026-10-12T11:17` and `SESSION_CAP_USD=10`. Meshy has 575 credits until 11 November, Tripo 500 for simple shapes only (D36).

## Plan

1. **The guns in the game.** Ask Sebastian whether the cleaned guns pass the bench. Read how `Shooter` tilts `Barrel` and which way the prefab's barrel faces, and match our export to it. Sync the three `final.glb` as `cannon`, `cannon22a` and `cannon33a`. Place them in a match in the sandbox, and take a screenshot under `xvfb-run` with a barrel raised and a shot in the air. Run [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh). Free.
2. **The light and the tile colours.** The game scene's WorldEnvironment and sun from the afternoon light (C11). The colour ranges of `Map.gd` from the palette: grass and sand for open ground, a stone tone for enclosed ground, the sea for water. A screenshot at the default view. Free.
3. **The tile and the walls.** First one painted sheet of the four wall shapes at both heights, with Sebastian's pick, then the procedural build from [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml): the tile, a chamfered slab painted by the game, and eight wall meshes. Palette materials (roadmap A2), the geometry report, the render sheet, then sync with one look in every slot (F11). A screenshot at the default view and zoomed in. Sebastian approves, or the fault goes back to phase C. About 0.30 USD.
4. **The blocks.** One side view of each block by image edit from [resource_blocks.png](../../game/art-direction/anchors/resource_blocks.png), Meshy at a ladder of counts, the pick, the cleanup by hand, size 0.8 by 0.8 by 0.6 m (D29). In the game as `upgrade_a` (timber) and `upgrade_b` (iron). About 1 USD.
5. **The depot and the base.** Three or four painted sketches of each (D30), Sebastian's pick, then the generative route with its cleanup. The base gets its team-coloured part as a separate first material, and its screenshot shows all four team colours. About 3 to 4 USD.
6. **The cannonball.** A sphere in dark iron within the prop budget, and the hook of F12. Free.
7. **Close.** A decision entry per pick, the process-log lines, the roadmap ticks, and the plan for session 08: the wall looks 2 and 3, nature, perhaps on Tripo's remaining credits (D36), and the ship.

## Limits

- At most 25 new images shown per round (D19).
- Sketches are paintings, never in the low-poly render look (D30). A picked design skips the sketch round.
- Every generated model goes through the cleanup by hand in Blender and its `split.json` (D37). Every model stays inside its triangle budget in [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml). Every export is a `.glb`.
- An image with a fault Sebastian already named is not shown. Every fault is checked in a magnified crop first.
- Godot runs `--headless` or under `xvfb-run`, Blender runs `--background`.
- Game changes land in the game repo on `master`, limited to what this plan names. Sebastian's uncommitted edits there stay untouched, including his resave of `tools/gun_test.tscn`.
- Every image and mesh keeps its sidecar. Every pick is Sebastian's, asked with the images open.

## Done when

The three guns fire from the art layer in a match, with the barrel tilting about its trunnion. The light and the tile colours are in the game. The tile and the four wall shapes at both heights are in the game, and Sebastian approved their screenshot or a fault went back to phase C. The blocks, the depot and the base each have a pick and a model in the game, or a recorded reason why not. The cannonball flies. The session 08 plan is written.

## Outcome

The first batch stands in the game. Screenshots: [07-battle-default.png](07-battle-default.png) at the default view, [07-battle-guns.png](07-battle-guns.png) and [07-battle-wall.png](07-battle-wall.png) zoomed in, [07-match-default.png](07-match-default.png) and [07-match-base.png](07-match-base.png) from a real match, [07-bases-ai4.png](07-bases-ai4.png) with the four team colours.

1. **The guns.** In the art layer and firing in a sandbox battle, barrels tilting about their trunnions, every shot from `projectile_spawn` (F8). After the first review each gun got a square plate in its own grey that stays on the grid (D39), and the cooldown ring moved above the guns.
2. **The light and the tile colours.** The afternoon light of the rules in the game with a measured sun energy of 0.5, the ground from the palette. The rules file had the sun's azimuth defined from the wrong side, the comment is fixed. The [render.py](../../pipeline/blender/render.py) view under the same light is open (C11).
3. **The tile and the walls.** Board 2 of round 19, the cornice, built procedurally as eight pieces of 108 to 200 triangles plus a 20-triangle tile. Sebastian approved them in the game. The game now asks for one art file per wall shape and level, so one look fills every slot (F11).
4. **The blocks.** The 600-triangle Meshy runs, 572 and 490 triangles (D38).
5. **The depot and the base.** Sebastian took all four depot designs and three of the four bases, which made the art layer pick a random look per building (D38). Two depot roofs were redone with flat roof planes in the reference. The base became a 2x2 building with a 12-wall start ring (D40). That change exposed an AI bug kept from the Unity original, now fixed.
6. **The cannonball.** A 288-triangle sphere in dark iron, attached to every shot through the art layer (F12).

After Sebastian's review of the final screenshots: the guns pass, the deck of base design 2 is now its team-coloured roof (D42), and nature gets redone from scratch, bigger and more stylized, like the cover art (D41).

Open, carried into session 08: nature, and the [render.py](../../pipeline/blender/render.py) view, which is not lit like the game.

Spend: 7.20 USD of the 10 USD cap, 18 images and 15 Meshy runs, 225 Meshy credits.
