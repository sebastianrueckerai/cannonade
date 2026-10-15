# Session 03: Mood, theme and colour

Start prompt for the session: "Run session 03 from docs/sessions/03-art-direction.md. Go."

Roadmap items: B9 (mood and theme), B10 (colour), A6 (critic calibration with the picks). This is phases A and B of [art-direction.md](../process/art-direction.md). Phases C to I follow in sessions 04 to 06. The first plan for this session was rejected (D18): it jumped to reference views of five assets with no reason given. This plan names why each deliverable exists.

## Why these deliverables

- Theme candidates in words: every image after them is steered by them, and words cost nothing to change.
- Moodboards: the words made visible, so Sebastian picks a feeling, not a sentence.
- Palettes applied to one frame: colour is the one thing that reads at 13 pixels, so it is decided before shape.
- Both critics on every sheet: the second calibration point for A6, and a second opinion before Sebastian's.

## Inputs

- [brief.md](../../game/art-direction/brief.md), including the game-design notes: simple cannons first, the era ladder, the ingredient metaphor.
- [inspirations/notes.md](../../game/art-direction/inspirations/notes.md) and the images in that folder. River Towns, Foundation, A Monster's Expedition and the toy-harbour world frame are the references the image model gets.
- [toy-harbour-world--nanobanana.png](../../game/art-direction/rounds/01-directions/toy-harbour-world--nanobanana.png), decision D15, the starting point for phase A.
- Spending cap 10 USD. Models per [providers.md](../providers.md): nano-banana for world frames and edits, ideogram for anything with text, Gemini and GLM as critics.

## Plan

1. Phase A. Write three or four candidate worlds as paragraphs in `rounds/02-mood/themes.md`. Generate the six moodboard images per candidate with the references attached. Build the contact sheet, run both critics, write `PICKS.md`. If Sebastian is present, ask for the pick with one question. If not, stop here and leave the picks open.
2. Phase B, after the pick. Extract three palettes as named swatch sets. Apply each to the picked world frame by image editing. Add the 13 pixel crop with the four team colours. Contact sheet, critics, `PICKS.md`. Same rule: ask if present, else stop.
3. After the colour pick: write [palette.json](../../game/art-direction/palette.json), the theme and colour chapters of [art_bible.md](../../game/art-direction/art_bible.md) with the anchor images inline, a decision entry per pick, the calibration lines in [process-log.md](../process-log.md), the roadmap ticks.

## Limits

- At most 24 images in phase A and 12 in phase B.
- No asset frames, no 3D, no menu or store art. Those are later phases.
- Every image keeps its sidecar. Every pick is Sebastian's.

## Done when

Phase A and B are picked, `palette.json` exists, the first two chapters of the bible carry text and images, and the next session's plan for phases C and D is written with reasons.

## Status, end of session

Done. Phase A: four worlds, 24 frames, both critics, pick D20. Phase B: three palettes, the 13 pixel test, both critics, pick D21 with the corrected team colours. [palette.json](../../game/art-direction/palette.json) written, chapters 1 and 2 of [art_bible.md](../../game/art-direction/art_bible.md) carry text and images, [04-shape-and-light.md](04-shape-and-light.md) is the next plan. Spend 4.17 USD. New rules: D19, the show-images rule in CLAUDE.md, the map types in the brief. New tools: [teamcrop.py](../../pipeline/teamcrop.py), [swatches.py](../../pipeline/swatches.py), `refs` in [round.py](../../pipeline/round.py).
