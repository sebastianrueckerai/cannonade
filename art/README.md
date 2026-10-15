# blender-ai

An agentic game-art process, built once on a real game so it can be copied to the next one. An agent runs art direction with image models, builds low-poly 3D assets in Blender by script or from image-to-3D APIs, makes the in-game 2D and the store art from the same design bible, and plugs everything into a Godot game. Grid Cannons, a game in the spirit of Rampart released as Cannonade, is the first game.

The process is the product. The charts in [docs/process/](docs/process/) are kept true to what we do. The assets are the proof.

## Layout

| path | holds | game-specific |
|---|---|---|
| [goal.md](goal.md) | the brief | no |
| [ROADMAP.md](../ROADMAP.md) | the backlog, pulled into sessions, at the game repository root | partly |
| [CLAUDE.md](CLAUDE.md) | the agent's read-map and rules | no |
| [docs/process/](docs/process/) | the master chart and one page per stage | no |
| [docs/decisions.md](docs/decisions.md) | decisions, newest last | partly |
| [docs/process-log.md](docs/process-log.md) | why the process changed | no |
| [docs/sessions/](docs/sessions/) | one plan per dev session | yes |
| [docs/blender.md](docs/blender.md) | Blender setup, recipes, costs, gotchas | no |
| [docs/providers.md](docs/providers.md) | keys, models, prices | no |
| [docs/grid-cannons.md](docs/grid-cannons.md) | the game repo and the art layer | yes |
| [docs/research/](docs/research/) | the discussion the process came from | no |
| [pipeline/](pipeline/) | the scripts: image, mesh, Blender, sync | no |
| [.claude/skills/](.claude/skills/) | stages packaged as skills | no |
| [game/art-direction/](game/art-direction/) | the design bible: brief, palette, rules, anchors, rounds | yes |
| [game/assets/](game/assets/) | 3D, UI and marketing assets, one folder each | yes |
| [experiments/](experiments/) | spike artefacts, one folder per spike | partly |

Game assets are separate from the process. [game/](game) is the only folder a new project replaces.

## Start a new game from this repo

1. Copy the repo. Delete [game/](game), [docs/sessions/](docs/sessions), [docs/grid-cannons.md](docs/grid-cannons.md) and the ticks in [ROADMAP.md](../ROADMAP.md).
2. Write [goal.md](goal.md) and [game/art-direction/brief.md](game/art-direction/brief.md).
3. Measure the gameplay contract in the new game and write [game/art-direction/gameplay_contract.yaml](game/art-direction/gameplay_contract.yaml).
4. Write the new game's integration page in place of [docs/grid-cannons.md](docs/grid-cannons.md).
5. Run the sessions from the roadmap. The charts tell the agent the order.

## Run a session

1. Pick items from [ROADMAP.md](../ROADMAP.md) and refine them into `docs/sessions/NN-slug.md` with a goal, a spending cap and limits.
2. Work the plan. Every artefact gets its sidecar. The critic judges before Sebastian picks.
3. Tick the items, log process changes, commit, push. Game changes are committed in the game repo.

## Requirements

Blender 5.2.2 with the MCP add-on, `blx` on PATH, `uv`, Python 3.12, keys in `.env.tools` (names in `.env.example`). Godot 4.7 CLI for the integration stage. Setup details in [docs/blender.md](docs/blender.md).
