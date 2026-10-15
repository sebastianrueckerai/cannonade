# Session 05: What stays and what differs, the era ladder, the bible v0

Start prompt for the session: "Run session 05 from docs/sessions/05-surfaces-and-tiers.md. Go."

Roadmap items: B13 (phase E, what stays and what differs, three title studies, `typography.yaml`), B14 (phase F, the era ladder and the ingredient metaphor candidates), B15 (phase G, the design bible v0 approved and tagged), and the typography half of B8. Phases E to G of [art-direction.md](../process/art-direction.md). Phases H and I follow in session 06.

## Why these deliverables

- The cross-domain table, one row per surface: in-game world, in-game UI, menu, splash, store page, trailer still, with the columns palette, shapes, detail, lighting, composition, text. Without it the menu, the splash and the store art each re-decide the look. It feeds D2 (the theme), D3 (menu and splash), E1 and E2 (store art).
- Three title studies through ideogram, the model that renders text: the typography direction, picked by Sebastian. It feeds D1 (logo and title) and `typography.yaml`.
- One frame per surface that differs from the world: the menu from a hero angle with a title placeholder, the splash as a mood painting, a store still with drama. Each edited from [world_style.png](../../game/art-direction/anchors/world_style.png), so what stays is visible and what differs is the only change. They feed D3 and E1 as the references those items are made from.
- The era ladder sheet: the same cannon at tiers 0 to 3 and the ingredient blocks beside it, one sketch sheet, with a paragraph per tier for materials, silhouette, colour shift and detail cap, inside the picked River Towns level (D22) and the chamfer rule. Sebastian comments, the metaphor pick waits for the simple cannons (D17, B18). It feeds C6 (the building set) and chapter 6 of the bible.
- The bible v0: chapters 5, 6 and 7 filled, the four rule files next to it, every chapter with its anchor inline. Sebastian approves, the commit is tagged `bible-v0`. It feeds phase H, the asset list, and phase I, the first item per essential class, in session 06.

## Inputs

- [art_bible.md](../../game/art-direction/art_bible.md) chapters 1 to 4, [palette.json](../../game/art-direction/palette.json), [geometry_rules.yaml](../../game/art-direction/geometry_rules.yaml), [lighting_rules.yaml](../../game/art-direction/lighting_rules.yaml), the anchors in [anchors/](../../game/art-direction/anchors/), above all `world_style.png` and `shape_corner.png`.
- [brief.md](../../game/art-direction/brief.md) for the era notes (D16) and the ingredient candidates (D17).
- [gameplay_contract.yaml](../../game/art-direction/gameplay_contract.yaml) for the window size and the current UI, [grid-cannons.md](../grid-cannons.md) for the menu image slots.
- Spending cap 10 USD. Models per [providers.md](../providers.md): ideogram for the title studies and any frame with text, nano-banana edit for the surface frames and the tier sheet, Gemini and GLM as critics for faults and readability.

## Plan

1. Phase E. Write the cross-domain table in words first, in `surfaces.md` of the round folder `06-surfaces`. Three title studies through ideogram, each a different type direction: carved wood, painted sign, naval brass. One frame each for the menu, the splash and the store still, edited from `world_style.png`. Contact sheet, both critics, `PICKS.md`, the images open in Sebastian's editor, one question: the title style. Draft `typography.yaml`. About 1.50 USD.
2. Phase F, after the pick. One sketch sheet of the cannon at tiers 0 to 3 with the ingredient blocks beside it, from `shape_corner.png` and the tier paragraphs. The paragraphs into chapter 6. One sheet, both critics, Sebastian comments, no pick. Under 1 USD.
3. Phase G. Chapters 5, 6 and 7 with the sheets inline, `typography.yaml` final, a decision entry per pick, the process-log lines, the roadmap ticks. Sebastian approves v0, tag `bible-v0`, push. Then the plan for session 06, phases H and I, with reasons.

## Limits

- At most 25 new images shown per round (D19).
- No 3D, no final logo SVG, no store set at platform sizes. Those are D1, E2 and session 06 onward.
- Every image keeps its sidecar. Every pick is Sebastian's, asked with the images open.

## Done when

The title style is picked, the cross-domain table and `typography.yaml` exist, the tier sheet and the tier chapter exist with Sebastian's comments recorded, the bible v0 is approved and tagged `bible-v0`, and the session 06 plan for phases H and I is written with reasons.

## Status, end of session

Phase E is done. Phase F was rejected and starts again in session 06. Phase G, the bible, waits for Sebastian's approval and the tag.

- **Phase E changed course.** Round 06 edited the surfaces from the game's render, and Sebastian rejected it: the 2D surfaces are a separate painted style that shares the theme (D24). Rounds 07 to 13 painted the key art, two castles in a cannon duel seen from above, picked as a3 of round 13 (D25). Sebastian renamed the game Cannonade (D26). Round 15 lettered the title in three styles, and he picked the outlined white letters (D27). [storeset.py](../../pipeline/storeset.py) composited the full Steam and itch.io set, and the game shows the new logo, splash and menu background, game repo commits `4aac46a` and `7042fb2`.
- **Phase F, rejected.** Round 16 ran 19 sheets, and Sebastian rejected the round as a whole. The sheets looked like low-poly renders instead of paintings, and the guns came from the plan's four tiers instead of from his needs. His rules from the comments stand: one gun per footprint size, standard artillery in dark iron, each size better than the last (D28), four box-shaped resource blocks (D29), sketches as paintings (D30).
- **Phase G.** [art_bible.md](../../game/art-direction/art_bible.md) is rewritten in full to the writing guide, because Sebastian found the text too condensed to follow. Chapter 6 says that the gun designs are open. [typography.yaml](../../game/art-direction/typography.yaml) is final. The plan for session 06 is [06-asset-list-and-first-items.md](06-asset-list-and-first-items.md).
- **Spend.** About 20.20 USD of the session's 10 USD cap, about 29.90 USD in total. Sebastian allowed the overspend for the key-art rounds. The inpainting endpoints bill per megapixel, which the estimates first missed.
- **Phase F, restarted.** After the top-up, round [17-painted-sketches](../../game/art-direction/rounds/17-painted-sketches/PICKS.md) painted the guns and the blocks from Sebastian's brief: five gun boards and one block board, all checked against the brief in crops. Sebastian picked one gun per size and the four blocks (D31). The sketches are the anchors [gun_ladder.png](../../game/art-direction/anchors/gun_ladder.png) and [resource_blocks.png](../../game/art-direction/anchors/resource_blocks.png).
- **Not done.** The SVG logo, D1. The Steam and itch.io screenshots, which wait for the game art.
