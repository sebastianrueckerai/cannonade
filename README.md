# Grid Cannons – Godot port

The game is released as **Cannonade**. Grid Cannons stays the project name, the repository name and the name in code.

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

Game modes:

| mode     | menu entry      | setup                                          |
|----------|-----------------|------------------------------------------------|
| `versus` | Player vs. AI   | you vs. one AI, 52×34 map, ten castles         |
| `ai2`    | Watch           | watch two AIs, same map                        |
| `practice` | Practice      | the versus map with a dormant enemy, no timer  |

`single` and `ai4` are parked (D64-style): their mode code and files stay, the menu does
not offer them. In `practice`, Enter steps to the next phase, so you can try the rules
check on your own walls.

Extra options after `--`: `--seed=N`, `--walls=SECONDS`, `--guns=SECONDS`,
`--battle=SECONDS`, `--ready=SECONDS` (the banner before each phase, 0 for none), `--size=TILES` (the depth), `--width=TILES`, `--timescale=F`,
`--quit-after=SECONDS`, `--no-decorations`.

### Controls (same as the Unity input settings for player 1)

| input             | action                                                   |
|-------------------|----------------------------------------------------------|
| left mouse        | place the wall piece, or stack it on your walls (wall phase); place the cannon at a parts cost, or fuse it onto three cannons (cannon phase); fire (battle) |
| X                 | rotate the wall piece clockwise                          |
| Y or Z            | rotate the wall piece counter-clockwise                  |
| mouse wheel       | zoom in / out (towards the cursor; fully out shows the whole map) |
| middle mouse drag | pan the view while zoomed in                              |
| Enter             | step to the next phase (`practice` only)                 |
| K / L             | testing keys: win / lose the running game at once         |
| click outside map | discard the current piece / building                      |
| Esc               | back to the menu                                          |

Walls come as **pieces**, Rampart style: one block, two, three or four in a row, an S, a T
or a cross, drawn at random (small pieces more often) and turned with X / Y. A piece stamps
a full-tile wall block on each of its cells. Blocks that share a side are one wall; blocks
that touch only at a corner do not join, so a ring must close side to side. Everything you
place needs one tile within two tiles of your own walls or of a castle you hold, with a
straight line of empty ground between it and that wall or castle, so nobody builds behind enemy
lines or inside an enemy's half-built room, and nobody builds on ground another player's closed
ring holds. The AI keeps the same rules. A piece stacks wherever your walls fill every tile under it, whichever
pieces placed them, as long as none of those tiles has a storey yet. A stacked tile takes two
shells. Held over your walls, the piece shows the storeys it adds, red where it cannot stack,
and the cursor on a block picks that block, not the ground hidden behind it.
A wall shot down breaks into pieces that fly from the shot, land on the walls around and sink
into the ground. So do a gun, the castle as it falls to ruins, and the trees, bushes and
boulders of a tile that is shot or built on.
Every game deals each player a different wall look of four. The walkway along the top of a wall carries the
owner's colour, running toward the neighbouring blocks of the same wall, and the ground inside
a closed ring takes a wash of the colour of the player whose walls encircle it alone — a ring
two factions share encircles nothing and the ground stays open — so a glance tells whose wall
and whose ground is whose.

A round is three phases: **build walls** (45 s), **place cannons** (15 s) and the
**battle** (30 s). A small banner in the middle counts each phase in for 3 seconds; nobody
acts while it shows, and the phase starts with its own call: a bell for the walls, a whistle
for the cannons, a horn for the battle. The plaque at the top counts each phase down and names it, its last
five seconds in red; the line at the bottom names the controls of the phase. You hold one
thing at a time and see it only where you point: the wall piece in the wall phase, a drawn
cannon in the cannon phase, each on the tile under the cursor, red where it cannot go.
**Castles are the game**: ten sit on the map, each side's four neutrals spread across
its half with free rows between the two halves, you start with one walled in, and a player
whose last castle falls is out: at once when a shell ruins it, at the check when it burns.

At the end of every cannon phase the **check** runs:

- every owned building standing outside your closed wall ring burns,
- a castle inside another player's ring changes owner (a ruin never does),
- your parts cap recomputes from the castles you hold: 1 castle 6 parts, 2 → 10,
  3 → 13, 4 → 15, 5 → 17; a cap below your placed guns blocks new placement only,
- a player holding no castle is out; both out in the same check is a draw.

Guns always fire, walled in or not, and every building is a legal target. A shell lands
on any tile you click — bare ground, a tree, an enemy's or your own wall — and whatever
stands there takes the hit, so a stray shot wastes itself on empty ground and a careless
one fells your own wall. A gun takes
4 shells and fires 1.5× slower for each shell it survives; a castle takes 12 shells
through four damage states and ends as a ruin nobody claims or builds on. Nothing
repairs. A gun costs parts (1×1 one part, 2×2 four); four basic cannons placed in a
2×2 fuse into the heavy `cannon22a`, which takes 8 shells and fires a pointed heavy shell
worth four (40 damage against the cannon's 10) at the cannon's 2 s reload. The upgrade
blocks are parked with the 3×3 guns.

A shell on a tile whose building is already gone hits the ground instead: the tile cracks
in three stages (the first hit already shows a crater, stage 2 at 25 damage, stage 3 at 50,
water never scars), its look follows the ground — stamped paving cracks inside walls, open
ground churns — and building on the tile heals it back to plain ground.

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

**Park a building:** tick `parked`. The file and its model stay, and the data is still
checked, but no recipe, draw or Sandbox palette offers the building. The 3×3 guns
(`cannon33a`, `cannon33b`, `cannon33c`, `rocket_station`), the old `base` and the two
upgrade blocks are parked.

The model (`model`) can be any scene; reuse another building's model while prototyping.
Behaviours look for parts by node name: `Barrel` and `ProjectileSpawn` (cannons),
`RocketSpawn` (rockets), `Guns` (flak), `Shield` (shield), `Progress Bar` (reload ring).
A genuinely new kind of behaviour needs a small script in `scripts/components/` plus a
parameter resource in `scripts/data/`.

## Sandbox (build & test battles)

Main menu → **Sandbox**. Set up two castles, press **Play**, and watch what happens – e.g.
how many flak guns beat how many cannons.

**Editing**

| input | action |
|---|---|
| `1` / `2` or the Blue / Red buttons | side you are building for |
| tool buttons (bottom) | **Wall**, **Erase**, **Castle**, one button per catalog building (tooltip: details) |
| left click / drag | place with the current tool; dragging the Wall tool draws wall blocks tile by tile |
| right click / drag | erase (a whole multi-tile building at once) |
| `R` | turn the next building (looks only; patterns are not affected) |
| `Ctrl+Z` / `Ctrl+Y` (or `Ctrl+Shift+Z`) | undo / redo |
| wheel / middle drag | zoom / pan, as in the game |
| F5 | reload the building data |
| Esc | back to the menu |

Enclosed areas turn grey as in the game. The ghost under the cursor turns red where the
building does not fit. **Castle** places the side's 3×3 castle with its wall ring.
**New** starts an empty layout with a walled-in castle a side (map size next to it).

Layouts are saved under a name (**Save**) to `user://scenarios/` and loaded from the
**Scenarios** list; shipped examples (`data/scenarios/`, e.g. *flak_vs_cannons*) are
in the same list. Scenarios are `ScenarioDef` resources, so they can also be edited as
text.

**Playing:** pick the match – **AI vs AI** (default), **Player vs AI**, **Player vs
dormant AI** (red never fires; the player is blue and aims with the mouse, fires with
Space) or **AI vs dormant AI** – what each AI aims at (walls as in the game, guns,
castles, supply or random) and a time
limit, then **Play**. There is no build phase and no random pieces; the parts cap does
not apply. Speed: pause, 1×, 2×,
4×, 8×. The panel on the right shows shots, hits, shells intercepted by flak, hits
absorbed by shields and walls / guns / castles / buildings lost per side. The battle
ends when a side holds no castle that is not a ruin, or at the time limit. **Back to
editing** restores the
layout as it was before Play. The speed buttons are for watching: at 4× and 8× the game
takes coarser steps (flak misses more), so judge balance with **Run** (below).

**Mirror** copies the current side's layout to the other side, mirrored top to bottom
(it replaces the other side; Ctrl+Z undoes it) – a fair starting point for "what if
one side had X instead of Y". The example *mirror_forts* is such a pair.

## Battle lab: win rates and sweeps

**In the Sandbox:** set the match, targets and time limit, choose the number of seeds
next to **Run** and press it. The layout is played in a background process at normal
speed (a short battle takes about a second) and the panel on the right shows how often each
layout wins and the mean stats. Each seed is played twice, the second time with the two
layouts swapped (blue's layout on red's side, in red): battles are usually decided by
who breaches a wall first, and in a tie the side the game processes first (blue) wins,
so the swap keeps the comparison fair. Results are therefore per *layout*. Each battle
is also written to `user://lab/last_run.csv`.

**From the command line** (headless, for longer runs and sweeps):

```sh
# 20 seeds of an example or a saved scenario (name or .tres path)
godot --headless --fixed-fps 30 res://tools/lab.tscn -- --scenario=flak_vs_cannons --runs=20

# sweep one catalog value, write every battle to a CSV
godot --headless --fixed-fps 30 res://tools/lab.tscn -- --scenario=mirror_forts --runs=10 \
    --sweep=flak22.salvo_interval=0.5:3:0.5 --csv=flak.csv

# four cannons against the heavy they fuse into, the heavy shell's damage swept
godot --headless --fixed-fps 30 res://tools/lab.tscn -- --scenario=heavy_vs_cannons --runs=10 \
    --targets=auto,auto --sweep=cannon22a.damage=10,20,30,40,60,80

# change values first (several with ";"), red aims at guns, red's layout never fires
godot --headless --fixed-fps 30 res://tools/lab.tscn -- --scenario=my_test \
    --set="cannon.reload=1.5;flak22.shoot_range=5" --targets=walls,guns --match=dormant
```

Values are `<building id>.<field>`, where the field belongs to the building or one of
its behaviours (`flak22.salvo_interval`, `cannon.reload`, `supply.produces.supply`,
`cannon.projectile.splash_range`); the names are the ones in the Inspector, in
snake_case. `--sweep` takes `from:to:step` or a list `a,b,c`. Other options: `--seed=N`
(first seed), `--limit=SECONDS`, `--swap=false`, `--speed=F`, `--out=PATH`; see
`scripts/sandbox/BattleLab.gd`. A seed always gives the same battle (headless), so runs
can be repeated and compared.

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
* A wall is one full-tile block, `assets/art/3d/wall.glb`, with `wall_upper.glb` as its
  stacked storey; the original FBX connector walls stay with their parked defs. `<look>_rubble.glb`
  is a model cut into pieces, a node per part, which `scripts/Crumble.gd` throws as rigid
  bodies when the thing dies: the walls, the guns, `castle_d3` as the castle falls to ruins
  and the nature looks. The decorations use the boulders, bushes and leaf trees of the
  art layer (`assets/art/3d/nature_*.glb`). Each one stays inside its tile and is shrunk
  until it fits, so it never reaches into a neighbouring building.
* `scripts/Main.gd` builds a game from a mode (camera, light, UI, players).
* `scripts/Sound.gd` (autoload) plays the clips of `assets/audio/`: `sfx/` and `ui/` by cue, a cue's
  variants from a `_1`, `_2` suffix, one at random and never the same twice, three voices a cue; the music
  of `music/` loops per phase and screen. The buses are Master, Music, SFX and UI
  (`default_bus_layout.tres`). The menu's Volume panel sets master, sound (SFX and UI together) and
  music, saved in `user://volume.cfg` and applied at startup. A cue with no clip plays nothing, so a new
  sound is a file dropped into the
  folder under its cue's name. The cue list is `art/game/design/sound.md`.

### Behaviour changes compared to the Unity code

The port follows the original logic closely (including its quirks). A few things were
changed on purpose:

* Upgrade patterns match their structure as laid out first, then turned by 180°, then
  by 90°. Unity accepted any rotation, so an adjacent pair of b blocks always became a
  Cannon22d and the supply depot (the same pair along the other axis) could never be
  built; the AI also only plans layouts that merge into the structure it wants.
* Combining an upgrade block into a building uses the block up (Unity kept it, so it
  could be combined again and again).
* Any single-tile building can be part of an upgrade pattern, not only upgrade blocks.
* There are no 3×3 guns for now. A 3×3 square merges only when a building in the game has
  its pattern. Otherwise one of its 2×2 squares merges. Unity made a 3×3 cannon of any 3×3
  square.
* Walls are Rampart pieces stamping full-tile blocks, not the connector tiles of the Unity
  game; the start castle is walled in with 16 blocks.
* Splash damage hits each tile in range (Unity damaged the target tile once per splash tile).
* The shield generator regenerates per second (Unity added `Time.time` every frame) and
  absorbs several hits before it resets.
* Flak ignores a shell that another defence already destroyed (Unity would keep aiming at it).
* Tiles hit by a tile-destroying rocket can no longer be built on (Unity only hid them).
* Tile selection intersects the mouse ray with the ground, so the tile under a building
  can always be picked (in Unity the colliders of some buildings caught the raycast).
* The AI plans rings, not the Unity rectangles: for every castle and for 3×3 gun yards it
  finds the cheapest closed loop of wall tiles round the target on the board as it stands,
  places whatever piece it holds where it covers the most of that loop's gaps, bulging
  outward freely, and walks towards a loop out of reach. That is how it claims neutral
  castles and patches its breaches. Guns go only into its closed ground, and a gun over
  the parts cap waits in its hand until a gun dies. Once nothing is left to ring or claim
  it keeps building: the largest room it can, sited toward the castles it does not hold —
  territory for its guns and staging for later captures.
* The enclosure flood fill treats fully walkable tiles as 3×3 blocks; it gives the same
  results as the original algorithm (see `tests/flood_test.gd`) but keeps GDScript fast.

Not ported: particle effects / trails, the Amplify force-field shader (the shield is a
transparent sphere), the second-player gamepad controls and the custom cursor.

## Tests

`./run_tests.sh` runs everything headless (set `GODOT=/path/to/godot` if needed):

* `tests/check_scripts` – every script and generated scene loads.
* `tests/sound_test` – the buses, the clips by cue with their variants and voice cap, and a voice at every
  hook: a piece built, a gun refused, the horns and the music per phase once its banner runs out, a shot, a hit, a wall and a gun
  destroyed, a castle claimed, lost and ruined, the win music, the end buttons.
* `tests/flood_test` – enclosure detection: walls enclose areas, gaps open them, and the
  optimised flood fill matches the original algorithm (kept in the test) on random edits.
* `tests/human` – the human player through real mouse / key events: placing, rotating,
  discarding and stacking walls (a turned three on three walls, zoomed in, the cursor on a
  wall's top, the storey ghosts), no building inside the enemy's closed ring,
  guns by left click at their parts cost, fusion, firing with the left click. K and L end the
  game and the end screen fits the window.
* `tests/phase_test` – the banner counts each phase in at the window's centre, small and off
  the other plaques, and a middle drag on it pans the board; under it a left click places and
  fires nothing, the AI builds nothing and the clock stands; then the phase's horn blows and
  the left click places the piece, places the cannon and fires.
* `tests/weapons` – upgrade patterns (incl. rotated ones) merge into the right structures;
  cluster bombs, rockets, shield, flak and ships behave as in the game.
* `tests/menu_test` – menu → chosen game mode → Esc → menu. The loading screen shows concept
  art, not the splash, and stays up with a moving bar until the game is built. It keeps
  input away from the game meanwhile.
* `tests/practice_test` – practice mode: Enter switches the phase, the dormant enemy
  never fires, the standard versus map with its castles.
* `tests/camera_test` – wheel zoom towards the cursor within its limits, middle mouse panning.
* `tests/preview_test` – the hand is invisible; the wall piece previews on a free tile in the
  wall phase and the cannon in the cannon phase; the HUD plaques stay on screen, apart, and
  off the board, which spans the window's width.
* `tests/catalog_test` – shipped data is valid; data problems are reported, not crashed on;
  duplicate a building, change it, press F5: it works in the running game (incl. recipes), and
  the F5 toast sits in the window's centre.
* `tests/sandbox_test` – the sandbox through real mouse / key input: drawing walls, placing,
  erasing, undo / redo, mirror, save / load, battles in the match setups, AI target choice,
  stats and result, back to editing, a background Run; every shipped example loads and fights.
* `tests/lab_test` – the battle lab command line as a subprocess: sweeps and `--set` change
  what the battles use, swapped battles report per layout, seeds replay exactly, CSV
  output, readable errors.
* `tests/check_test` – the rules check on a fixed seed through the real timer: the castle
  map layout, burn, claim, the parts cap gate, the ruin, the game-over rule.
* `tests/finish_test` – the AI's target list (the enemy's guns, its castles nearest to ruin
  first, then walls, never a neutral castle), each gun at the first target in its reach, and
  the game ending the moment a shell ruins the last castle.
* `tests/sim` – full games (`--mode=versus` with an autobuild stand-in, `--mode=ai2`):
  rounds alternate, AIs build, arm
  themselves and fight, ships sail and shoot; map invariants hold; frame times are printed.

The runner fails on any engine or script error output and times out hung tests.

`tools/screenshot.tscn` renders screenshots (needs a display; `tools/godot_render.sh` runs Godot under Xvfb):

```sh
tools/godot_render.sh res://tools/screenshot.tscn -- --mode=ai2 --at=5,30 --out=/tmp/shot
```
