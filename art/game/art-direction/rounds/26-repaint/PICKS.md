# Round 26 — the repaint round (C12)

Question: the flat set (nine wall pieces, tile, shell, gun plates) onto the D49 painted path, and the ivory-tree readability fix from the D52 ship critique.

- Wall paint candidates: [candidates.py](candidates.py) → [candidates-board.png](candidates-board.png). Four stone paints rendered through the C11 game view under the shipped soft_honey light: 1 subtle, 2 weathered, 3 patchy, 4 pale. Procedural board, no provider call.
- **Pick: 1 subtle** — Sebastian, 2026-10-14. Recorded as D53. Seed 41; the paint lands on all nine wall pieces through the `paint:` block in each asset.yaml.
- Ivory trees: [ivory.py](ivory.py) → [ivory-board.png](ivory-board.png). The three leaf-tree looks beside repaint candidates (same seeds and paint structure, deeper crown stops). All three shipped looks wash pale at the lit crown tops under soft_honey.
- **Pick: deep repaint, all three looks** — Sebastian, 2026-10-14. Recorded as D54.
- Tile and shell: [pieces.py](pieces.py) → [pieces-board.png](pieces-board.png). The tile grain is shown pre-multiplied by the Map's green and sand lerp colours (the game multiplies its colour on top of the near-white texture); edges read at the default view. The shell paints in the iron kind. No pick — both judged at the gate.
- Gate: [gate.py](gate.py) → [gate-board.png](gate-board.png), the force-synced set in the running game (seed 1): sandbox battle and single-player view, the zoom pair, magnified crops, Blender texture views. Gemini: GATE: PASS ([critique/](critique/)).
- **Pick: ship, but the plate must stay on the grid while only the gun rotates** — Sebastian, 2026-10-14.
- The fault confirmed in magnified crops: plates rotated with the aim yaw. Root cause: ArtPlate's per-frame correction lagged one frame behind every re-aim (probe: the aim frame rendered the plate at −108°, corrected the frame after; guns re-aim every battle tick, so the lag showed constantly). Fix: the plate goes `top_level` in ArtPlate.gd — its world transform is set once and no turn can move it. Probe after the fix: yaw +0.0 in the aim frame itself; battle re-shot, all five plates square ([/tmp/gate11/plates-check2.png](../../../../../tmp/gate11/plates-check2.png)).
- Re-critique on the fixed board: GLM GATE: PASS ([critique/gate-board.json](critique/gate-board.json)), after three Gemini runs returned empty answers.
- Procedural round: the board scripts are committed; only the critic calls spent, about 0.15 USD.
