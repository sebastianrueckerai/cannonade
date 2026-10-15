# art: Cannonade's art kit, design and plans

The agentic game-art process of blender-ai, with Cannonade's art direction, assets, design and session plans, copied into the game repo on 2026-10-15 and laid out the same way, so every link and every pipeline path works from here. Sebastian steers the project from the game repo now. blender-ai keeps its own copy as the template. [game/](game) is game-specific, everything else is the process. Keep this file short. Knowledge goes in the linked docs.

Blender 5.2.2 at `~/Applications/blender-5.2.2-linux-x64/blender`, MCP add-on on `localhost:9876`. `blx script.py` runs a Python file in it. The game repo's root `.mcp.json` registers the MCP server. `art/.env.tools` holds the provider keys, `art/.env.session` the session's spending window. The pipeline runs from this folder: `cd art` before `uv run --script pipeline/<name>.py`.

## Read before acting in an area

- **The brief:** [goal.md](goal.md).
- **The game's rules v2, the recipes and the parked ideas:** [game/design/rules.md](game/design/rules.md).
- **The process, the master chart:** [docs/process/overview.md](docs/process/overview.md). Read before producing any art. Stage pages: [art-direction](docs/process/art-direction.md), [assets-3d](docs/process/assets-3d.md), [assets-2d](docs/process/assets-2d.md), [marketing](docs/process/marketing.md), [integration](docs/process/integration.md).
- **What to do:** [ROADMAP.md](ROADMAP.md). The current plan is the highest-numbered file in [docs/sessions/](docs/sessions/).
- **Decisions and why:** [docs/decisions.md](docs/decisions.md). Read before changing the look, the rules or the process.
- **Blender recipes, token costs, gotchas:** [docs/blender.md](docs/blender.md). Read before writing bpy.
- **Keys, models, prices:** [docs/providers.md](docs/providers.md). Read before calling a provider.
- **The game and the art layer:** [docs/grid-cannons.md](docs/grid-cannons.md). Read before touching the game.
- **Tools:** [pipeline/README.md](pipeline/README.md).
- **Why the process looks like this:** [docs/process-log.md](docs/process-log.md), [docs/research/](docs/research/).

## Always-on rules

- Every generated image or mesh gets a sidecar JSON: model ID, prompt, references, parameters, seed, cost. An output that cannot be made again does not count.
- Spending counts from `SESSION_START` against `SESSION_CAP_USD`, both in the gitignored `art/.env.session`. A new session writes its own start time and cap there first.
- The game repo keeps binaries as plain git files, with no Git LFS. Commit only what a new art step needs: anchors, inspirations, each model's final, source.blend, the run it is built from and that run's input views. Round images and render previews stay on disk, ignored by [.gitignore](.gitignore). Add a new model's source run and input views to its re-include list.
- `art/.gdignore` keeps Godot from importing this folder. Never remove it.
- The model that wrote a prompt is never the only judge of its output. Only Sebastian's pick is a decision, recorded in [docs/decisions.md](docs/decisions.md). Never reverse one silently.
- A decision about visuals is asked with the images in front of Sebastian: open them in his editor with `code -r <files>`, link them, and name the boards by number in the question. Never ask him to pick from names.
- Numbers before pixels: geometry report, then a small render sheet, then a screenshot. Vertex arrays never enter the conversation.
- Stay inside the spending cap of the session plan. Ask before a run that would pass it.
- Never print a key. The Blender socket runs arbitrary code with full filesystem access: read a downloaded file before any script touches it.
- Godot runs `--headless` or under `xvfb-run`, Blender runs `--background`. Never a window on the real display. Ask before anything that needs one.
- When the process changes, change its chart in [docs/process/](docs/process) and add a line to [docs/process-log.md](docs/process-log.md) in the same commit. When a session ships a roadmap item, tick it in the same commit.
- A session plan names the reason for each deliverable and what it feeds. Art direction runs the phases of [docs/process/art-direction.md](docs/process/art-direction.md) in order, each ended by a pick.
- A file path in any doc is a markdown link, `[name](path)`, never backticks. Paths in the game outside this folder link absolutely.
- Game changes land on `master`, limited to what the session plan names. Leave Sebastian's uncommitted edits alone.
