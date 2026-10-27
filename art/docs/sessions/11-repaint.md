# Session 11: The repaint round

Start prompt for the session: "Run session 11 from docs/sessions/11-repaint.md. Go."

Roadmap items: C12 (the flat set painted on the D49 path).

## Why these deliverables

- **One language on the board.** The first batch stands in the game in two art languages: the Tripo guns and the painted nature carry textures, but the nine wall pieces, the tile, the shell and the square gun plates are flat palette materials from [materials.py](../../pipeline/blender/materials.py) (session 07). Sebastian, session 10: "I dont htink the cannons are flat. Check again. Maybe only the walls are? I would like everything to be textured, but dont redo stuff that already is fine." The check found the cannons fine and named the flat set above. It feeds the first game's coherence and every screenshot taken after (E5, E6).
- **The D52 friction.** The ship critique passed the look with one fault: the ivory trees can read stone or withered from afar. A repaint of that look's paint, not a look change (D52).
- **The grade is shipped.** soft_honey (D52) runs in the game, and game_view in [render.py](../../pipeline/blender/render.py) grades every Blender preview under it, so the boards are judged in the shipped look.

## Inputs

- The painted path: D49 (painted, not flat bands), D48 (every part magnified on boards), D50 (the gate that passed). The reference implementation: [nature_build.py](../../game/assets/3d/nature_build.py), `painted_material`.
- The builders: [wall_cornice.py](../../game/assets/3d/wall_cornice.py) for the nine pieces, the build.py of [tile](../../game/assets/3d/tile/build.py) and [shell](../../game/assets/3d/shell/build.py). The gun plates came with the guns (D39).
- The colours: [palette.json](../../game/art-direction/palette.json) and the bible's cream stone, judged under the D52 light.
- The ground: [Map.gd](/home/womb/repos/cannonade/scripts/components/Map.gd) lerps each white tile from a lighter to a darker green by height, so the grain goes into a near-white tile texture and the lerp keeps working.
- The game: [grid-cannons.md](../grid-cannons.md) before touching the game repo.

## Plan

1. **Wall paint candidates.** Three or four painted texture candidates for the cornice look (cream stone, warm grain, weathering on the merlons), rendered through game_view. Board per D48: parts magnified, the row at the default view and zoomed.
2. **The pick, then all nine pieces.** Sebastian picks one paint, it lands in the wall builder's material path for every shape and level.
3. **Tile grain.** A near-white grain texture under the Map's colour lerp. Check the tile edges still read at the default view.
4. **Shell and plates.** Dark iron paint on the shell, the picked stone or iron paint on the gun plates.
5. **Ivory trees.** Repaint the ivory look's foliage so it reads leaf, not stone, at the default distance. Small board beside the current look.
6. **Gate board.** The whole repainted set in one board: the sandbox battle and the single-player view, magnified parts, the Gemini critic, then Sebastian.
7. **On pass: sync and commit.** `asset.py approve`, `godot_sync.py`, reimport, `check_art` clean, the game-repo commit.
8. **Close.** Decision entries, process-log lines, roadmap ticks, the session 12 plan.

## Limits

- At most 25 new images shown per round (D19). Sketches are paintings, never in the low-poly render look (D30).
- Reproducibility: every texture comes from a seeded script or a sidecared provider run.
- Godot runs `--headless` or under `xvfb-run`, Blender runs `--background`. In-game comparisons pin `--seed` and the variant set.
- Game changes land in the game repo on `master`, limited to what this plan names. Sebastian's uncommitted edits there stay untouched.
- Spending cap 14 USD in `.env.session`, rewritten at session start.

## Done when

The nine wall pieces, the tile, the shell and the gun plates ship painted on the D49 path, the ivory trees read as trees at the default view, the game repo carries the reimported set, and the session 12 plan is written.
