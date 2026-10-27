# Session 01: Plumbing and the first art round

Roadmap items: B1, A1, A10, B2, B3, C1. Stretch: G1.

## Why these

Two chains have never run here: image model to critic to picks, and Blender to .glb to Godot. Every later session needs both. The art round needs the gameplay contract as input, so measuring comes first. The plumbing proof needs no art direction, so it runs in parallel and does not wait for picks. Web export, the vertical slice and the generative 3D comparison wait for session 02, because they depend on the picks or on Godot being installed.

## Goal

When the session ends, Sebastian has:

1. [game/art-direction/gameplay_contract.yaml](../../game/art-direction/gameplay_contract.yaml) with measured numbers, not nulls (B1).
2. [pipeline/img.py](../../pipeline/img.py) working here, one cheap generation and one critique as proof (A1).
3. The model probe result in [providers.md](../providers.md): one image model per job (A10).
4. [game/art-direction/brief.md](../../game/art-direction/brief.md) filled in with Sebastian (B2). This is the one step that needs him live, at the start.
5. Round 01: 4 to 6 contrasting directions, 3 frames each, `contact-sheet.jpg`, `critique/*.json`, `index.html`, and an empty `PICKS.md` waiting for him (B3).
6. [game/assets/3d/wall_straight/](../../game/assets/3d/wall_straight) with `build.py`, `source.blend`, `final.glb`, `report.json`, a sheet render, and one screenshot of it inside the game's [tools/screenshot.tscn](/home/womb/repos/cannonade/tools/screenshot.tscn) (C1). Unstyled grey. This proves dimensions, origin, scale and axis conventions survive the trip.
7. A process-log entry: what the first run changed in the charts.

## Inputs

- Spending cap: 10 USD. `img.py` adds up estimates from its price table. Sebastian checks the fal dashboard after.
- Blender running with a window, so renders and screenshots both work.
- The game repo on `master`. Our only change there in this session is a scene that loads `final.glb` for the screenshot, committed as its own commit. Sebastian's uncommitted re-saves of `project.godot` and [scenes/menu.tscn](/home/womb/repos/cannonade/scenes/menu.tscn) stay out of it.
- Order within the session: B1 and B2 first, A1 next, A10 and C1 in parallel, B3 last so it uses the probe result.

## Limits

- Round 01 is 18 images at most. No round 02 in this session.
- The critic is one of the two portfolio critics. A6 calibration starts with this round's picks.
- `wall_straight` gets no materials beyond one grey. Style is session 02.
- No change to gameplay code. No export preset yet.

## Done when

Items ticked in [ROADMAP.md](../../../ROADMAP.md), both repos committed and pushed, the sheet page linked in the closing message, PICKS.md open for Sebastian.

## Log

- Worktree `s01`. Blender 5.2.2 started headless with the MCP socket. Godot 4.7.1 found in `~/Applications`, display `:0` works, Web export templates exist only for 4.6 (G1 still open for 4.7).
- B1 done: `gameplay_contract.yaml` measured from the game code. Tile 1 m, versus camera pitch 60, fov 30, 54.4 m. Predicted 24.7 by 12.3 px for a 1 m wall, measured 26 by 13 in Godot.
- A1 done: [pipeline/img.py](../../pipeline/img.py) ported, smoke run in [experiments/00-smoke/](../../experiments/00-smoke), 0.04 USD. Empty-answer bug fixed.
- A2 and A4 done for the procedural route: [pipeline/asset.py](../../pipeline/asset.py) plus [pipeline/blender/](../../pipeline/blender). First wall failed on 1 non-manifold edge, rebuilt as a profile, passes: 52 tris, 1.0 by 0.3 by 1.0 m.
- C1 done: [game/assets/3d/wall_straight/](../../game/assets/3d/wall_straight) with `final.glb`, `source.blend`, `report.json`, `manifest.json`, `previews/sheet.png`, `previews/godot_default.png`, `previews/godot_zoom7.png`. Game repo got [tools/preview_glb.tscn](/home/womb/repos/cannonade/tools/preview_glb.tscn) and `.gd`, not yet committed there.
- B2 done as assumptions in [game/art-direction/brief.md](../../game/art-direction/brief.md).
- A10 done: probe in [game/art-direction/rounds/00-model-probe/](../../game/art-direction/rounds/00-model-probe), 15 images, 1.05 USD. Nano-banana for world and asset frames, ideogram for menus, recraft for cheap breadth. Written into [docs/providers.md](../providers.md).
- B3 done: [game/art-direction/rounds/01-directions/](../../game/art-direction/rounds/01-directions), 5 directions by 3 frames, 1.95 USD. Gemini critique in `critique/`. GLM failed, the Z.AI account has no balance. `PICKS.md` open for Sebastian. Gemini's ranking matched the director's, first A6 data point.
- GPT-5 is gone from fal any-llm (404) and Z.AI has no balance (429). Gemini was the only working critic until Sebastian topped up Z.AI the same evening, then GLM ranked round 01 too.
- Spend: 3.09 USD of the 10 USD cap.
- Open: G1 (4.7 Web templates), A2 `materials.py`, the game repo commit of `tools/preview_glb.*`.
