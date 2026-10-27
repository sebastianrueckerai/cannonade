# Session 04: Shape, detail and light

Start prompt for the session: "Run session 04 from docs/sessions/04-shape-and-light.md. Go."

Roadmap items: B11 (shape language and detail level), B12 (lighting and atmosphere), F10 (team colours into the game). Phases C and D of [art-direction.md](../process/art-direction.md). Phases E to G follow in session 05.

## Why these deliverables

- The same fortress corner at three detail levels and in two shape languages: the pick sets the bevel width, the facet size and the parts per building that every procedural `build.py` and every image-to-3D normalisation reads from `geometry_rules.yaml`. Without it the first asset guesses, and the second asset guesses differently.
- The shipwright's structures in the toy language, one sheet: D20 steals cranes, slipways, scaffolds and towers into the toy world, and nothing has shown them chunky and painted yet. The sheet decides whether they survive the simplification.
- A river map and a pure land map in the picked style: D20 says the look holds on three map types, and every frame so far is an island. Two images settle whether grass, sand and stone carry the look without the sea.
- What a wall shows at 13 pixels: the stone against the sand and the grass is the first thing the shape phase measures, because the 13 pixel test of round 03 used flat blocks and the real wall has an edge and a shadow. The rule goes into `geometry_rules.yaml`.
- Lighting variants of the picked frame: the pick sets the sun angle, sky, fog depth, shadow strength and water style for the game's WorldEnvironment and for every preview render, so a render sheet and a game screenshot can be compared.
- The world anchor image: the one frame every downstream prompt attaches from phase D on.
- F10: the corrected team colours exist only in `palette.json` until `Main.gd` reads them. A small named game change, so the next game screenshot shows the right four.

## Inputs

- [art_bible.md](../../game/art-direction/art_bible.md) chapters 1 and 2, [palette.json](../../game/art-direction/palette.json), the anchors in [anchors/](../../game/art-direction/anchors/).
- [gameplay_contract.yaml](../../game/art-direction/gameplay_contract.yaml) for the pixel sizes and the tri budgets.
- The recoloured frame [colour_frame.png](../../game/art-direction/anchors/colour_frame.png) is the base for every edit in both phases.
- Spending cap 10 USD. Models per [providers.md](../providers.md): nano-banana edit for every variant, Gemini and GLM as critics, their job is faults and readability, not taste (A6).

## Plan

1. Phase C. Six edits of the fortress corner from the recoloured frame: detail levels Kingdoms and Castles, River Towns, Foundation, in the languages rounded-and-chunky and faceted-and-sharp. One sheet of the shipwright's structures in the toy language. One river map and one land map frame. Draft `geometry_rules.yaml` in words and numbers: bevel width, facet size, silhouette rules, parts per building, detail per tier, what a wall shows at 13 pixels. Contact sheet, both critics, `PICKS.md`, the images open in Sebastian's editor, one question. About 1.50 USD.
2. Phase D, after the pick. Four to six lighting edits of the picked frame: time of day, fog depth, shadow strength, sea treatment. `lighting_rules.yaml`. The world anchor into `anchors/world_style.png`. Same round shape, one question. Under 1 USD.
3. After the pick: chapters 3 and 4 of the bible with the sheets inline, a decision entry per pick, the process-log lines, the roadmap ticks, the plan for session 05 with reasons.
4. F10 in the game repo: `PLAYER_COLORS` in [scripts/Main.gd](/home/womb/repos/cannonade/scripts/Main.gd) from the team set, the sandbox test run headless, one screenshot through [tools/godot_render.sh](/home/womb/repos/cannonade/tools/godot_render.sh) as proof, committed on `master` there.

## Limits

- At most 25 new images shown per round (D19), iteration inside a round allowed inside the cap.
- No asset frames, no 3D, no menu or store art. Those are phases E to I.
- Every image keeps its sidecar. Every pick is Sebastian's, asked with the images open.

## Done when

Phases C and D are picked, `geometry_rules.yaml` and `lighting_rules.yaml` exist, chapters 3 and 4 carry text and images, `anchors/world_style.png` exists, the game shows the corrected team colours, and the session 05 plan for phases E to G is written with reasons.

## Status, end of session

Done. Phase C: six corners, the structures sheet, the river and the land map, the 13 px test, both critics, pick D22. Phase D: the frame at the picked shapes, five relights, both critics, pick D23. [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml) and [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml) exist, chapters 3 and 4 of [art_bible.md](../../game/art-direction/art_bible.md) carry text and images, [world_style.png](../../game/art-direction/anchors/world_style.png) is the world anchor, the game shows the corrected team colours ([04-team-colours-ai4.png](04-team-colours-ai4.png)), [05-surfaces-and-tiers.md](05-surfaces-and-tiers.md) is the next plan. Spend 2.43 USD. Found and fixed: the 13 px test ran at half scale since round 03, see [process-log.md](../process-log.md). New tool: [px13.py](../../pipeline/px13.py), `teamcrop.py` scales by the tile.
