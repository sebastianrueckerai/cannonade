# Grid Cannons – notes for Claude

The game is released as **Cannonade**: every player-facing string, the window title (`config/name`), the splash and the menu say Cannonade. Grid Cannons stays the project, repository and code name.

Godot 4.7 game in GDScript (ported from Unity 2018.3). Player-facing docs: `README.md`.

## Roadmap
[ROADMAP.md](ROADMAP.md) is the one backlog for the game, the art and the process: sections A to H
art and process, I to K game code. Read it at the start of a round of work. A session pulls items
by ID into its plan in [art/docs/sessions/](art/docs/sessions) and ticks them in the same commit
that ships them. New work, leftovers, open questions and ideas go in as new items at the end of
their section, with a tag. Never delete an item: strike it through with the reason. Keep no other
TODO lists.

## Git workflow
Sebastian plays the game from the main checkout, so its master must always be the newest. He does not
edit the checkout by hand and does not run merges: the session that finished the work merges it itself.
Do new work in a worktree off the latest master; when it is done, merge it into the local master and
push. The harness blocks a worktree session's git against the main checkout, and master is checked out
there, so merge by push: `receive.denyCurrentBranch = updateInstead` stays set in the main checkout's
`.git/config` (if missing, `git config --file /home/womb/repos/grid-cannons/.git/config
receive.denyCurrentBranch updateInstead`), then `git push /home/womb/repos/grid-cannons <branch>:master`.
Sebastian never hand-edits the checkout, so a refusal for uncommitted changes there is machine noise
(Godot re-serializations, regenerated files), never his work: restore each differing tracked file to
its committed content (a `git archive master` extract makes the reference copy), delete untracked
files the push would overwrite, and push again. Never leave master behind over such files; say what
was discarded in the report. Then push master to origin. A session cannot remove the
worktree it lives in: the next session prunes dangling worktrees (`git worktree remove`,
`git worktree prune`); leave the locked worktrees of live sessions alone.

## Art, design and plans
[art/](art) holds Cannonade's art kit, copied from blender-ai on 2026-10-15 and laid out the same way: the
art direction, the sources of every model, the pipeline that makes art, rules v2 with the recipes
([art/game/design/rules.md](art/game/design/rules.md)), the decisions and the session plans. Read
[art/CLAUDE.md](art/CLAUDE.md) before any art, design or planning work. The current plan is the
highest-numbered file in [art/docs/sessions/](art/docs/sessions), and it can name game work too.
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
  the behaviour components from the data. A def with `parked = true` stays in the files but
  out of the game (D64: the 3×3 guns). Park a building, never delete its files or assets.
- `scripts/sandbox/` – Sandbox editor + battle lab (`scenes/sandbox.tscn`). It wraps a
  `Main` built from a `config` dictionary; layouts are `ScenarioDef` item lists
  (`data/scenarios/` examples, `user://scenarios/` saves). `BattleLab.gd` (`tools/lab.tscn`)
  plays a scenario many times headless; the Sandbox's Run button starts it as a subprocess.
  Use it to check balance claims instead of guessing.
- `scripts/Main.gd` – builds a game from a mode (`single`, `versus`, `ai2`, `ai4`, `practice`)
  or a config; `scripts/CameraRig.gd` – zoom / pan. `scripts/Loading.gd` – the loading screen:
  it sets `Main.staged`, and the map is then built over many frames while the bar shows
  `Main.progress`.
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
- Visual check: `tools/godot_render.sh res://tools/screenshot.tscn -- --mode=versus --at=5 --out=/tmp/shot`
- Every Godot run without a window plays no sound. `--headless` mutes it on its own; any other run
  (`xvfb-run`, a tool, a subprocess) passes `--audio-driver Dummy`, as `tools/godot_render.sh` does.

## Gotchas
- GDScript `:=` cannot infer types from untyped (Variant) expressions; declare the type.
- A parse error in a test scene makes Godot hang instead of failing; the runner has a timeout.
- Headless windows are 64×64; set `get_tree().root.size` when a test depends on the view.
- Images and models are plain git files, not Git LFS (LFS pushes are blocked here).
- `Main.build`, `GameController.start_game` and `Map.make_map` contain `await`. They run straight
  through unless `Main.staged` is set, so the sandbox, tests and tools get a built game at once.
  Never add an `await` there that always waits a frame.
- Battles share the game's random numbers with the map build: anything the build draws changes
  every lab battle and seeded test. Draw look-only randomness from `Art._rng`, or only when
  decorating.
- The battle lab replays a seed exactly only with `--fixed-fps 30`.
