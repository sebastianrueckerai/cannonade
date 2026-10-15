# Grid Cannons – notes for Claude

The game is released as **Cannonade**: every player-facing string, the window title (`config/name`), the splash and the menu say Cannonade. Grid Cannons stays the project, repository and code name.

Godot 4.7 game in GDScript (ported from Unity 2018.3). Player-facing docs: `README.md`.

## Roadmap
`ROADMAP.md` is the plan. Read it at the start of a round of work. At the end of the
round, update it: tick off what is done, park unfinished work, open questions, ideas and
"maybes" in the matching section. Do not keep separate TODO lists.

## Art, design and plans
[art/](art) holds Cannonade's art kit, copied from blender-ai on 2026-10-15 and laid out the same way: the
art direction, the sources of every model, the pipeline that makes art, rules v2 with the recipes
([art/game/design/rules.md](art/game/design/rules.md)), the decisions and the session plans. Read
[art/CLAUDE.md](art/CLAUDE.md) before any art, design or planning work. The current plan is the
highest-numbered file in [art/docs/sessions/](art/docs/sessions), and it can name game work too.
[art/ROADMAP.md](art/ROADMAP.md) holds the art and design items, this ROADMAP.md the game code's rounds.
[.mcp.json](.mcp.json) registers the Blender MCP server. Godot skips the folder through `art/.gdignore`.

## Layout
- `scripts/components/` – one script per original Unity MonoBehaviour. A "GameObject"
  is a `Node3D`; its components are child nodes named after the script. Look them up with
  `U.comp(go, "Shooter")`, never by script type.
- `scripts/U.gd` – autoload replacing the Unity API: game time (`U.time`), Unity-style
  random (`U.rint` excludes max), instantiate / destroy, colours, projectile registry.
- `data/buildings/*.tres`, `data/projectiles/*.tres` – buildings and projectiles as data
  (`scripts/data/` classes). `scripts/Catalog.gd` (autoload) loads and validates them and
  spawns configured buildings: always create buildings with `Catalog.spawn(id)`, never by
  instantiating a prefab. Model scenes in `prefabs/` are visuals only; the catalog adds
  the behaviour components from the data.
- `scripts/sandbox/` – Sandbox editor + battle lab (`scenes/sandbox.tscn`). It wraps a
  `Main` built from a `config` dictionary; layouts are `ScenarioDef` item lists
  (`data/scenarios/` examples, `user://scenarios/` saves). `BattleLab.gd` (`tools/lab.tscn`)
  plays a scenario many times headless; the Sandbox's Run button starts it as a subprocess.
  Use it to check balance claims instead of guessing.
- `scripts/Main.gd` – builds a game from a mode (`single`, `versus`, `ai2`, `ai4`) or a config;
  `scripts/CameraRig.gd` – zoom / pan.
- `prefabs/`, `materials/` – generated from the Unity prefabs (the converter is in git
  history only); edit them by hand now. Building prefabs are models only.
- Coordinates: tile `(x, z)` sits at `Map.tile_position(x, z)`; Unity's z axis is
  mirrored (`z → -z`). "Up" on the map is Godot −z.

## Testing
- `./run_tests.sh` runs everything headless (`GODOT=/path/to/godot` if not on PATH).
  It must stay green. It also fails on any `ERROR:` / `SCRIPT ERROR` output.
- Tests drive real boundaries: real input events, real build / merge paths. No test-only
  hooks in production code. Every new test must fail when the behaviour it guards is
  broken (check this by breaking the code on purpose before you commit). Follow
  https://github.com/openclaw/openclaw/blob/main/.agents/skills/test-audit/SKILL.md
- Visual check: `xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 30
  res://tools/screenshot.tscn -- --mode=versus --at=5 --out=/tmp/shot`

## Gotchas
- GDScript `:=` cannot infer types from untyped (Variant) expressions; declare the type.
- A parse error in a test scene makes Godot hang instead of failing; the runner has a timeout.
- Headless windows are 64×64; set `get_tree().root.size` when a test depends on the view.
- Images and models are plain git files, not Git LFS (LFS pushes are blocked here).
