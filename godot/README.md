# Grid Cannons – Godot port

A port of the Unity (2018.3) game in `../Assets` to **Godot 4.7** with GDScript.
The Unity project is left untouched; this folder is a self-contained Godot project.

## Running

Open `godot/project.godot` in Godot 4.7 (the first import takes a few seconds) and press
Play, or from the command line:

```sh
godot --path godot                                        # main menu
godot --path godot res://scenes/game.tscn -- --mode=versus  # straight into a game
```

Game modes (they mirror the Unity scenes):

| mode     | Unity scene         | setup                                         |
|----------|---------------------|-----------------------------------------------|
| `single` | `singlePlayer.unity`| you vs. a fleet of 7 ships, 20×20 map, water  |
| `versus` | `multiPlayer.unity` | you vs. one AI, 30×30 map                     |
| `ai2`    | –                   | watch two AIs, 30×30 map, 30 s rounds          |
| `ai4`    | `4ai.unity`         | watch four AIs, 60×60 map, 25 s rounds         |

Extra options after `--`: `--seed=N`, `--round=SECONDS`, `--size=TILES`,
`--timescale=F`, `--quit-after=SECONDS`, `--no-decorations`.

### Controls (same as the Unity input settings for player 1)

| input             | action                                                   |
|-------------------|----------------------------------------------------------|
| left mouse        | place the next wall (or stack it on one of your walls)   |
| right mouse       | place the next building / combine it with an upgrade      |
| X / mouse wheel   | rotate the wall clockwise                                |
| Y or Z / wheel    | rotate the wall counter-clockwise                        |
| Space             | fire (battle phase)                                       |
| click outside map | discard the current wall / building                       |
| Esc               | back to the menu                                          |

Rounds alternate between a **build phase** (green timer) and a **battle phase** (red timer).
Areas fully enclosed by walls turn grey; only guns inside enclosed areas can fire, and
guns that need supply only work with enough supply buildings inside your walls.
Upgrade blocks placed in 2×2 / 3×3 squares merge into bigger guns, rocket stations,
flak, shield generators or supply depots depending on their pattern.

## How the port is structured

* `tools/unity2godot.py` converts the Unity prefabs (`Assets/Prefabs/*.prefab`) into
  Godot scenes in `prefabs/`: primitive meshes, materials (`materials/`), nested prefabs
  and the serialized MonoBehaviour fields. Unity is left-handed, so the z axis is mirrored
  (`(x, y, z) → (x, y, -z)`, quaternions `(-x, -y, z, w)`). Re-run it from the repository
  root with `python3 godot/tools/unity2godot.py` (needs PyYAML).
* Every Unity `MonoBehaviour` became a GDScript in `scripts/components/`. A Unity
  GameObject is a `Node3D`; each of its components is a child node named after the
  script, so `GetComponent<Shooter>()` became `U.comp(go, "Shooter")`.
* `scripts/U.gd` (autoload) replaces the Unity API bits: `Time.time`, `Random.Range`
  semantics, `Instantiate`/`Destroy`, material colours and a projectile registry that
  replaces the physics layer used by flak and shields.
* Mouse picking intersects the camera ray with the ground plane instead of raycasting
  colliders; MEC coroutines became small time based state machines.
* Wall models are the original FBX files in `assets/` (textures re-applied by
  `scripts/WallModel.gd`); the decorations use the original nature FBX models.
* `scripts/Main.gd` builds a game from a mode (camera, light, UI, players).

### Behaviour changes compared to the Unity code

The port follows the original logic closely (including its quirks, e.g. the AI's plan
geometry). A few things were changed on purpose:

* Splash damage hits each tile in range (Unity damaged the target tile once per splash tile).
* The shield generator regenerates per second (Unity added `Time.time` every frame) and
  absorbs several hits before it resets.
* Tiles hit by a tile-destroying rocket can no longer be built on (Unity only hid them).
* Tile selection intersects the mouse ray with the ground, so the tile under a building
  can always be picked (in Unity the colliders of some buildings caught the raycast).
* The AI's plan search runs as a coroutine spread over several frames, and the
  enclosure flood fill treats fully walkable tiles as 3×3 blocks; both give the same
  results as the original algorithms (see `tests/flood_test.gd`) but keep GDScript fast.

Not ported: particle effects / trails, the Amplify force-field shader (the shield is a
transparent sphere), the second-player gamepad controls and the custom cursor.

## Tests

`./run_tests.sh` runs everything headless (set `GODOT=/path/to/godot` if needed):

* `tests/check_scripts` – every script and scene loads.
* `tests/flood_test` – the optimised enclosure flood fill equals the original algorithm.
* `tests/human` – the human player via injected input (placing, rotating, stacking,
  discarding, combining, upgrade clusters, enclosing a gun and firing).
* `tests/weapons` – cluster bombs, rockets, flak, shield generator, ships.
* `tests/menu_test` – menu → game → Esc → menu.
* `tests/sim` – full games (`--mode=single|versus|ai2|ai4`) with invariant checks and
  frame time statistics.

`tests/screenshot.tscn` renders screenshots (needs a display, e.g. `xvfb-run`):

```sh
xvfb-run godot --path godot --rendering-driver opengl3 --fixed-fps 30 \
    res://tests/screenshot.tscn -- --mode=ai2 --at=5,30 --out=/tmp/shot
```
