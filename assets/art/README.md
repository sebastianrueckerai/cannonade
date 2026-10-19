# assets/art: the art layer

Drop a file here with the right name and the game uses it. Nothing else to wire. [scripts/Art.gd](../../scripts/Art.gd) does the work. The files come from the blender-ai pipeline ([pipeline/godot_sync.py](/home/womb/repos/blender-ai/pipeline/godot_sync.py)), which also writes [manifest.json](manifest.json).

| file | used by |
|---|---|
| `3d/<building id>.glb` | every building from `data/buildings/*.tres`: `cannon`, `cannon22a`, `flak22`, `supply`, `base`, ... |
| `3d/<id>.2.glb`, `3d/<id>.3.glb` | more looks of any id, numbered from 2 without a gap. One look is picked at random for each instance |
| `3d/<projectile id>.glb` | every shot of the projectile with that file name in `data/projectiles/`, for example `shell`. Origin at its centre |
| `3d/ship.glb` | the fleet ships |
| `3d/tile.glb` | every map tile, its first mesh replaces the slab box and gets repainted by the game |
| `3d/wall.glb`, `3d/wall_upper.glb` | the full-tile wall block and its stacked storey; hand pieces show `wall` per cell. Origin at the tile centre on the ground, the storey starts 0.75 m up. The `wall_<shape>_<level>` files belong to the parked connector walls |
| `ui/splash.png` | the splash screen |
| `ui/loading.jpg`, `ui/loading.2.jpg`, ... | the loading screen, one look at random behind the bar, numbered from 2 without a gap. Made from the twenty pictures of [round 29](../../art/game/art-direction/rounds/29-loading-art/PICKS.md) by `art/pipeline/storeset.py loading`, imported as lossy WebP at quality 0.8 |
| `ui/logo.png` | the menu title |
| `ui/menu_background.png` | behind the menu |
| [ui/theme.tres](ui/theme.tres) | the splash, menu and loading screens. The in-game HUD and the sandbox panel keep the default theme until they are styled, because their layout is sized by it |
| `ui/button.png`, `ui/button_hover.png`, `ui/button_pressed.png` | 9-slice button images on top of the theme. Without hover and pressed files the normal image is lightened and darkened |
| `ui/panel.png` | 9-slice panel image behind the menu and the loading bar |
| `ui/font.ttf` | the default font of those screens |
| `sky/world_panorama.png` | equirectangular sky for the game scene |
| [manifest.json](manifest.json) | `{"<id>": {"size": [x, y, z], "tolerance": 0.02}}`, metres in Godot axes |

Slice margins default to a quarter of the image on every side. [manifest.json](manifest.json) overrides them per image: `{"ui": {"button": {"margins": [12, 12, 12, 12], "content": [16, 8, 16, 8]}}}`.

[tools/shoot_battle.tscn](../../tools/shoot_battle.tscn) screenshots a sandbox battle of two forts that hold every building of the first batch: `tools/godot_render.sh res://tools/shoot_battle.tscn -- --at=4.5 --stack --out=/tmp/battle`.

[tools/shoot_ui.tscn](../../tools/shoot_ui.tscn) screenshots any scene at any window size, through [tools/godot_render.sh](../../tools/godot_render.sh) so no window opens: `tools/godot_render.sh res://tools/shoot_ui.tscn -- --scene=res://scenes/menu.tscn --out=/tmp/menu.png --width=390 --height=720`.

## Model rules

- Origin at the ground centre, Y up, metres, one tile is 1 m. The game lifts the model 0.1 m onto the slab top.
- Parts are named in snake_case. A part whose name maps to a prefab node in PascalCase is attached to that node: `barrel` goes under `Barrel` and rotates with it, an empty named `projectile_spawn` moves `ProjectileSpawn`. Other anchors: `rocket_spawn`, `rocket_model`, `guns`, `shield`.
- A part named `plate` stays square to the grid while the building turns, [scripts/ArtPlate.gd](../../scripts/ArtPlate.gd). Indicators of the prefab, such as the cooldown ring, float above the model.
- The base paints the first material of every mesh in the team colour, so its team part is a separate first material.
- Every mesh of the old placeholder is hidden when a model is present. Without a file, the placeholder stays.
- Sizes are checked once per id against [manifest.json](manifest.json). A mismatch shows on the menu and fails [tools/check_art.tscn](../../tools/check_art.tscn), which [run_tests.sh](../../run_tests.sh) runs.
