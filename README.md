# Grid Cannons – Godot port

A Godot 4.7 game (GDScript), ported from the original Unity 2018.3 version. The Unity
project was removed from the repository; it is still in the git history before the
port (commit `e45e623`).

## Running

Open this folder (`project.godot`) in Godot 4.7 (the first import takes a few seconds) and press
Play, or from the command line:

```sh
godot --path .                                        # main menu
godot --path . res://scenes/game.tscn -- --mode=versus  # straight into a game
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
| X                 | rotate the wall clockwise                                |
| Y or Z            | rotate the wall counter-clockwise                        |
| mouse wheel       | zoom in / out (towards the cursor; fully out shows the whole map) |
| middle mouse drag | pan the view while zoomed in                              |
| Space             | fire (battle phase)                                       |
| click outside map | discard the current wall / building                       |
| Esc               | back to the menu                                          |

Rounds alternate between a **build phase** (green timer) and a **battle phase** (red timer).
Areas fully enclosed by walls turn grey; only guns inside enclosed areas can fire, and
guns that need supply only work with enough supply buildings inside your walls.
Upgrade blocks placed in 2×2 / 3×3 squares merge into bigger guns, rocket stations,
flak, shield generators or supply depots depending on their pattern.

## Buildings are data

Every building is a file in `data/buildings/` (the file name is its id); projectiles are
in `data/projectiles/`. Numbers in these files win over anything in the model scenes.

**Change a building:** open its `.tres` in Godot (double-click in the FileSystem dock), edit
the fields in the Inspector, save, and press **F5** in the running game. Placed buildings
use the new numbers right away (a reload already running finishes first).

**Make a new building type:**
1. Right-click a similar file in `data/buildings/` → *Duplicate…* → give it a new name
   (that name is the id).
2. In the Inspector set the name, size, health, `consumes` / `produces` (e.g. `supply`),
   and `draw_weight` (> 0 to have it offered as the next building).
3. Under *Behaviour*, add or remove entries ("Add Element" → *New CannonBehaviour*,
   *FlakBehaviour*, *ShieldBehaviour*, *RocketBehaviour*, *WallBehaviour*) and fill in
   their numbers. A cannon needs a projectile: pick one from `data/projectiles/` or
   duplicate one there too.
4. Under *Recipe*, say how it is obtained: a `recipe_pattern` (ids of single-tile
   buildings in a size × size square, column by column from the lower left, `*` = any;
   turned versions match too) or a `recipe_combine` (`[placed building, building it is
   placed on]`).
5. Save and press F5 (or restart). Problems in the data are listed in the main menu and
   in the F5 message, never a crash.

The model (`model`) can be any scene; reuse another building's model while prototyping.
Behaviours look for parts by node name: `Barrel` and `ProjectileSpawn` (cannons),
`RocketSpawn` (rockets), `Guns` (flak), `Shield` (shield), `Progress Bar` (reload ring).
A genuinely new kind of behaviour needs a small script in `scripts/components/` plus a
parameter resource in `scripts/data/`.

## How the port is structured

* The scenes in `prefabs/` and `materials/` were generated from the Unity prefabs by a
  converter (`tools/unity2godot.py`, removed together with the Unity project; see the git
  history). Unity is left-handed, so the z axis is mirrored (`(x, y, z) → (x, y, -z)`,
  quaternions `(-x, -y, z, w)`).
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

* Upgrade patterns match their structure as laid out first, then turned by 180°, then
  by 90°. Unity accepted any rotation, so an adjacent pair of b blocks always became a
  Cannon22d and the supply depot (the same pair along the other axis) could never be
  built; the AI also only plans layouts that merge into the structure it wants.
* Combining an upgrade block into a building uses the block up (Unity kept it, so it
  could be combined again and again).
* Any single-tile building can be part of an upgrade pattern, not only upgrade blocks.
* The start base is walled in with all four wall shapes (Unity only used three).
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

* `tests/check_scripts` – every script and generated scene loads.
* `tests/flood_test` – enclosure detection: walls enclose areas, gaps open them, and the
  optimised flood fill matches the original algorithm (kept in the test) on random edits.
* `tests/human` – the human player through real mouse / key events: placing, rotating,
  discarding and stacking walls, buildings, combining, and firing from an enclosed gun.
* `tests/weapons` – upgrade patterns (incl. rotated ones) merge into the right structures;
  cluster bombs, rockets, shield, flak and ships behave as in the game.
* `tests/menu_test` – menu → chosen game mode → Esc → menu.
* `tests/camera_test` – wheel zoom towards the cursor within its limits, middle mouse panning.
* `tests/catalog_test` – shipped data is valid; data problems are reported, not crashed on;
  duplicate a building, change it, press F5: it works in the running game (incl. recipes).
* `tests/sim` – full games (`--mode=single|ai2|ai4`): rounds alternate, AIs build, arm
  themselves and fight, ships sail and shoot; map invariants hold; frame times are printed.

The runner fails on any engine or script error output and times out hung tests.

`tools/screenshot.tscn` renders screenshots (needs a display, e.g. `xvfb-run`):

```sh
xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30 \
    res://tools/screenshot.tscn -- --mode=ai2 --at=5,30 --out=/tmp/shot
```
