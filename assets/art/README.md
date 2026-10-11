# assets/art: the art layer

Drop a file here with the right name and the game uses it. Nothing else to wire. `scripts/Art.gd` does the work. The files come from the blender-ai pipeline (`pipeline/godot_sync.py`), which also writes `manifest.json`.

| file | used by |
|---|---|
| `3d/<building id>.glb` | every building from `data/buildings/*.tres`: `cannon`, `cannon22a`, `flak22`, `supply`, `base`, ... |
| `3d/ship.glb` | the fleet ships |
| `3d/tile.glb` | every map tile, its first mesh replaces the slab box and gets repainted by the game |
| `3d/wall_<fbx stem>.glb` | one of the 46 wall shapes, for example `wall_line_upper1`, `wall_curve_base3` |
| `ui/splash.png` | the splash screen |
| `ui/logo.png` | the menu title |
| `ui/menu_background.png` | behind the menu |
| `ui/theme.tres` | the splash, menu and loading screens. The in-game HUD and the sandbox panel keep the default theme until they are styled, because their layout is sized by it |
| `ui/button.png`, `ui/button_hover.png`, `ui/button_pressed.png` | 9-slice button images on top of the theme. Without hover and pressed files the normal image is lightened and darkened |
| `ui/panel.png` | 9-slice panel image behind the menu and the loading bar |
| `ui/font.ttf` | the default font of those screens |

Slice margins default to a quarter of the image on every side. `manifest.json` overrides them per image: `{"ui": {"button": {"margins": [12, 12, 12, 12], "content": [16, 8, 16, 8]}}}`.

`tools/shoot_ui.tscn` screenshots any scene at any window size: `godot --rendering-driver opengl3 res://tools/shoot_ui.tscn -- --scene=res://scenes/menu.tscn --out=/tmp/menu.png --width=390 --height=720`.
| `sky/world_panorama.png` | equirectangular sky for the game scene |
| `manifest.json` | `{"<id>": {"size": [x, y, z], "tolerance": 0.02}}`, metres in Godot axes |

## Model rules

- Origin at the ground centre, Y up, metres, one tile is 1 m. The game lifts the model 0.1 m onto the slab top.
- Parts are named in snake_case. A part whose name maps to a prefab node in PascalCase is attached to that node: `barrel` goes under `Barrel` and rotates with it, an empty named `projectile_spawn` moves `ProjectileSpawn`. Other anchors: `rocket_spawn`, `rocket_model`, `guns`, `shield`.
- Every mesh of the old placeholder is hidden when a model is present. Without a file, the placeholder stays.
- Sizes are checked once per id against `manifest.json`. A mismatch shows on the menu and fails `tools/check_art.tscn`, which `run_tests.sh` runs.
