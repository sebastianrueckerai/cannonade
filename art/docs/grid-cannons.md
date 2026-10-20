# Grid Cannons: the game repo and how art plugs in

Repo: [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons), branch `master`, remote `SparseSpeculator/grid-cannons`. Changes to the game are made from sessions here and committed there (D8). Surveyed 11 October 2026, art layer built the same day (session 02).

The game is released as Cannonade (D26). Every player-facing string says Cannonade: `config/name` in `project.godot`, the fallback titles of the splash and the menu, the store pages. Grid Cannons stays the repository, project and code name.

## Rules when touching the game repo

- Only change what the session plan names. The art layer, the export pipeline and the tools are ours. Gameplay code is not.
- Its `.env.tools` holds a GitHub token. Never copy it, read it or print it.
- `godot` is not on PATH. The scripts fall back to `~/Applications/Godot_v4.7.1-stable_linux.x86_64`, or set `GODOT`.
- Godot runs `--headless` or under `xvfb-run`, never with a window on the real display (Sebastian, session 02). [tools/godot_render.sh](/home/womb/repos/grid-cannons/tools/godot_render.sh) wraps Xvfb for every tool that saves a screenshot. Ask before anything that needs the real display.
- [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh) is the gate. It imports, then runs 17 headless scenes including the art check. The three sims take a few minutes.

## What the game is

A Godot port of a Unity game in the spirit of Rampart. A round is a wall phase, a cannon phase and a battle (session 38); before that, turns alternated between a build phase, where the player places rotatable wall pieces and buildings on a tile grid to enclose areas, and a battle phase, where cannons inside closed walls fire. Upgrade blocks in 2 by 2 or 3 by 3 patterns merge into bigger guns, flak, rocket stations, shield generators or supply depots. Modes: single player against a ship fleet, player against AI, AI against AI with 2 or 4 sides.

## Engine facts that matter for art

| fact | value |
|---|---|
| Godot | 4.7, binary 4.7.1 in `~/Applications`, Web templates installed for 4.7.1 |
| renderer | gl_compatibility on desktop and mobile, the renderer the Web export needs |
| window | 1280 by 720, stretch aspect expand |
| main scene | `res://scenes/splash.tscn`, then `menu.tscn`, then `loading.tscn`, then `game.tscn` or `sandbox.tscn` |
| boot | the Godot boot logo is off, boot colour is the menu colour |
| export presets | [export_presets.cfg](/home/womb/repos/grid-cannons/export_presets.cfg), one Web preset, thread support off |
| tools | [tools/export_web.sh](/home/womb/repos/grid-cannons/tools/export_web.sh), [tools/serve_web.sh](/home/womb/repos/grid-cannons/tools/serve_web.sh), [tools/check_web.py](/home/womb/repos/grid-cannons/tools/check_web.py), [tools/check_art.tscn](/home/womb/repos/grid-cannons/tools/check_art.tscn), and through [tools/godot_render.sh](/home/womb/repos/grid-cannons/tools/godot_render.sh): [tools/preview_glb.tscn](/home/womb/repos/grid-cannons/tools/preview_glb.tscn), [tools/shoot_ui.tscn](/home/womb/repos/grid-cannons/tools/shoot_ui.tscn), [tools/screenshot.tscn](/home/womb/repos/grid-cannons/tools/screenshot.tscn). [tools/gun_test.tscn](/home/womb/repos/grid-cannons/tools/gun_test.tscn) is the bench Sebastian opens in the editor: each gun an instance of its `.glb` with editable children, so he turns `gun` and tilts `barrel` by hand. [tools/shoot_battle.tscn](/home/womb/repos/grid-cannons/tools/shoot_battle.tscn), through the render wrapper, saves screenshots of a sandbox battle between two walled forts that hold every building of the art kit, the five guns and the depots of every size, with `--look=x,z` for a close view, `--top=H` for a view straight down, `--stack` for second storeys, `--artseed=N` for other random looks and `--align` to print each gun's mount minus plate after placement |
| light and ground | the afternoon light of [lighting_rules.yaml](../game/art-direction/lighting_rules.yaml) in `_setup_environment` of [scripts/Main.gd](/home/womb/repos/grid-cannons/scripts/Main.gd), the ground colours of [palette.json](../game/art-direction/palette.json) in [scripts/components/Map.gd](/home/womb/repos/grid-cannons/scripts/components/Map.gd), both as constants with a comment naming the source file |
| the base | a 2x2 building with a start ring of 12 walls (D40) |

Camera, tile and pixel numbers are in [gameplay_contract.yaml](../game/art-direction/gameplay_contract.yaml).

## The art layer, as built

`res://assets/art/` is the drop-in folder. [scripts/Art.gd](/home/womb/repos/grid-cannons/scripts/Art.gd) does the work, [assets/art/README.md](/home/womb/repos/grid-cannons/assets/art/README.md) in the game repeats the contract for anyone browsing there.

| file | used by |
|---|---|
| `3d/<building id>.glb` | `Catalog.spawn` for every building in `data/buildings/*.tres`: `cannon`, `cannon22a` to `cannon33c`, `flak22`, `rocket_station`, `shield22`, `supply`, `supply22`, `supply33`, `upgrade_a`, `upgrade_b`, `base`, `ship_cannon`. `supply33` came in session 12, with the Supply22 prefab and no recipe yet |
| `3d/<id>.2.glb`, `3d/<id>.3.glb` | more looks of any id, from 2 up until a number is missing. `Art.instance` picks one at random for each instance, with its own random generator, so the art never moves the game's random sequence |
| `3d/<projectile id>.glb` | `Catalog.spawn_projectile`, by the file name of the projectile in `data/projectiles/`: `shell` for the cannonball, `heavy_shell` for the heavy cannon, `cluster_bomb` and `cluster_shard` for the mortar. Origin at its centre. A part named after a node of the projectile's prefab moves under that node: `heavy_shell` rides on the `HeavyShell` body, so it pitches with the arc, nose along -Z |
| `3d/ship.glb` | `ShipFleet` for every fleet ship |
| `3d/tile.glb` | `Map` for every tile, the first mesh replaces the slab box and the game keeps repainting it |
| `3d/wall.glb`, `3d/wall_corbel.glb`, `3d/wall_pilaster.glb`, `3d/wall_course.glb`, each with an `_upper` storey | `Catalog.spawn` for the full-tile wall block (D75) in the owner's look (D78, `Catalog.wall_look`, the look `Main.build` dealt the player, D81; `Wall.wear` corrects a block spawned without an owner), `Wall.show_upper` for a stacked block's storey of the same look; a hand piece shows the owner's block at each cell, and a held piece over own walls shows a storey on each cell, darkened and square to the map, tinted red through the shader's `tint` where it cannot stack (`PlayerController.next_wall_to_wall`). The cursor picks the first wall block the view ray enters, up to `BuildingPlace.wall_top`, not the ground behind it. One mesh with region ids in UV2 under [materials/wall.gdshader](/home/womb/repos/grid-cannons/materials/wall.gdshader); `Wall.repaint` colours the walkway toward the own walls beside the block, and drops the lego top's mid-side stud on each such side (a region with alpha 0 is discarded by the shader, D80), and `BuildingPlace.repaint_walls_around` runs it when a block comes or goes. The enclosure flood (`StatesMap.waterflow`) names every closed region's ring owner through `Map.ring_owner`, the check's majority rule, and `BuildingPlace.reset_color` tints the enclosed mud 0.25 toward that player's colour (D79). The origin is the tile centre on the ground. The block stands from 0.1 m to 1.1 m, its storey from 0.85 m to 1.85 m. The `wall_<shape>_<level>` files of the parked connector walls stay with their FBX wrappers |
| `3d/<look>_rubble.glb`: `wall`, `wall_upper`, `cannon`, `cannon22a`, `cannon22b`, `flak22`, `castle_d3`, `nature_leaf_tree`, `nature_bush`, `nature_boulder` with their `.2` and `.3` looks | a model's mesh parts cut into Voronoi pieces by [fracture.py](../game/assets/3d/fracture.py), a node per part holding its pieces, each with its origin at its centre, no materials, not size checked. `Crumble.crumble(go, from)` makes a rigid body of every piece where its part stands as the thing dies, in the part's live material (a wall's shader, a gun's paint), thrown away from where the shot was fired (`TileImpactor.start`); the pieces land on the slab top and on the standing walls, each a static box of its bounds from `BuildingPlace._wall_body` since it was built or stacked, freeze after 3 s and sink away in 1 s. Called by `BuildingPlace.damage_structure` and `UpgradeCluster.damage_structure` for whatever dies, by `Castle.become_ruin` with `castle_d3` whatever the castle wore, and by `BuildingPlace.destroy_decorations` for a tile shot or built on once the game runs. `Art.instance` records the look it picked as the `art_look` meta. A wall look without pieces wears the plain block's (I62, I69) |
| `ui/splash.png`, `ui/logo.png`, `ui/menu_background.png` | splash and menu |
| `ui/win.png`, `ui/lose.png` | the end screen: the human's victory or defeat, covering the window like the menu background, the title over its sky and Retry / Menu in a themed panel in the bottom right |
| `ui/theme.tres` | splash, menu, loading and end screens. The in-game HUD takes its font, Alegreya, and the palette's ink `#3a2e28` on parchment `#fbefd9` in plaques of its own (`Main._plaque`, session 38): the countdown with the phase in its colour at the top, a plaque a player in the top corners, the phase's controls at the bottom. The camera fits the board between the timer and the help line. The sandbox panel keeps the default theme until roadmap D2 styles it, a project-wide theme moved the sandbox layout |
| `ui/button.png`, `ui/button_hover.png`, `ui/button_pressed.png` | 9-slice button images on top of the theme. Without hover and pressed files the normal image is lightened and darkened |
| `ui/panel.png` | 9-slice panel behind the menu and the loading bar |
| `ui/font.ttf` | the default font of those screens |
| `sky/world_panorama.png` | the game scene's WorldEnvironment as a PanoramaSkyMaterial |
| `manifest.json` | `{"<id>": {"size": [x, y, z], "tolerance": 0.02}}` in Godot axes, written by [pipeline/godot_sync.py](../pipeline/godot_sync.py) |

How a model is attached:

1. Origin at the ground centre, Y up, metres. `Art.attach` lifts it 0.1 m onto the slab top and undoes the prefab root's scale.
2. Every placeholder mesh without a script is hidden. Scripted meshes such as the cooldown bar stay.
3. A part whose snake_case name maps to a prefab node in PascalCase is attached to it. `barrel` goes under `Barrel` and rotates with it. An empty named `projectile_spawn` moves `ProjectileSpawn`. Other anchors the code looks for: `rocket_spawn`, `rocket_model`, `guns`, `shield`. The pivot moves to the part's origin and keeps its orientation, except for `guns`: `Flak.gd` aims the flak's `Guns` by replacing its whole basis, so that anchor takes the part's rest orientation. An anchor that is a placeholder mesh, such as `Guns`, shows again with its mesh dropped, so the art under it stays visible. A part named `plate` gets [scripts/ArtPlate.gd](/home/womb/repos/grid-cannons/scripts/ArtPlate.gd) and stays square to the grid while the building turns (D39).
4. Indicators of the prefab float 0.15 m above the model and above the reach of a moving part, `barrel` or `guns`. The reload ring of D57 lies on the plate instead, capped at its edge (D61).
5. The size is checked once per id against the manifest. A mismatch is a `push_error`, shows in red on the menu and fails [tools/check_art.tscn](/home/womb/repos/grid-cannons/tools/check_art.tscn), which [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh) runs.

Not covered yet: the nature props (`CustomModelMaker` with FBX variants, roadmap F7). Under the new light they render darker than the palette.

## Binaries in the game repo

The game repo keeps images and models as plain binaries, `*.png`, `*.fbx` and `*.glb binary` in its `.gitattributes`, with no Git LFS. The FBX files of the old walls and nature are tracked, so a fresh worktree has them. Its first import reports `res://assets/fbx` missing because one FBX names an empty image path, which is harmless. A `.glb` that Godot imports extracts its texture next to it unless its `.import` file sets `gltf/embedded_image_handling=3`, as the bench models do.

## Sync from this repo

`pipeline/godot_sync.py game/assets/3d/<asset_id>` copies `final.glb` into `3d/<asset_id>.glb`, writes the manifest entry from `report.json`, with the Blender Z-up dimensions swapped to Y up, and a minimal `.import` that keeps a texture inside the `.glb`. Only approved assets sync, `--force` overrides for a review before the approval. Our asset ids must match the game's ids above, a second look is `<id>.2`. `GAME_REPO` points it at a worktree of the game.

## Web build

- [tools/export_web.sh](/home/womb/repos/grid-cannons/tools/export_web.sh) imports and exports to [build/web/](/home/womb/repos/grid-cannons/build/web), 39.5 MB wasm plus the pck. [build/](/home/womb/repos/grid-cannons/build) is gitignored.
- [tools/serve_web.sh](/home/womb/repos/grid-cannons/tools/serve_web.sh) serves it on `http://localhost:8060/`. With threads off no COOP or COEP headers are needed, so any static host works.
- [tools/check_web.py](/home/womb/repos/grid-cannons/tools/check_web.py) serves the build, opens it in headless Chromium through Playwright, waits, saves [build/web-check.png](/home/womb/repos/grid-cannons/build/web-check.png) and exits 1 on a page error. Headless Chrome with a virtual-time budget never reaches the first frame, so the shell version was dropped.
- The HTML shell still shows the Godot logo while the engine downloads (roadmap F9).
- Hosting on a small VM is roadmap G4: nginx static, gzip or brotli for `.wasm` and `.pck`.
