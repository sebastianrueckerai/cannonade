# Picks, round 03: colour

Three palettes on the same frame, the round 01 anchor, so the comparison is colour only. One sheet: [picks-sheet.jpg](picks-sheet.jpg), one row per palette: the recoloured frame, the swatches with the hex per surface, the 13 pixel test with a base block in each team colour. The intended values are in [palette-painted-toy.json](palette-painted-toy.json), [palette-market-warmth.json](palette-market-warmth.json), [palette-fogged-teal.json](palette-fogged-teal.json). The image edit moves each surface toward the swatch and does not hit the hex, so the swatches are the palette and the frame is the impression.

Critics: Gemini and GLM both ranked market-warmth, painted-toy, fogged-teal, for hierarchy at 13 pixels and for the wall against the sand. The director agrees, see [notes.md](notes.md). Sebastian said before the sheet that the toy harbour's own colours and lighting are the nicest, which is painted-toy. Your pick is the decision and goes into [docs/decisions.md](../../../../docs/decisions.md) and into [palette.json](../../palette.json).

## Pick one palette, with corrections by swatch name

- [ ] 1 painted-toy, the anchor's own colours
- [x] 2 market-warmth, orange roofs, green grass, blue sea, warm stone
- [ ] 3 fogged-teal, bone stone, pale sand, soft grass, red roofs
- [ ] corrections: ______ to ______

## Team colours

The four team colours fail the 13 pixel test the same way in every palette: deep blue #1f1f5e and purple #4a1671 are two dark blocks side by side. The three judges each blamed a different colour. Gemini: blue, to #2d55c4. GLM: olive, to #8a9a2e. Director: purple, lighter and redder. [team-fix-sheet.jpg](team-fix-sheet.jpg) shows the current four (A) and one proposed set (B) on the market-warmth grounds: blue #2d55c4, purple #7b2fa3, teal #197059 unchanged, olive #8c7a1f. GLM's olive is too close to the grass, so the proposal lifts olive less. The team colours live in the game's `scripts/Main.gd`, so a change there is a game change for a later session plan. The pick here puts the values into [palette.json](../../palette.json).

- [ ] A keep the game's four
- [x] B the proposed set
- [ ] other values: ______

## Pick

Sebastian, 11 October: first palette 3, fogged-teal, then minutes later and before the commit: "I changed my mind: go with 2 market-warmth." Palette 2, no corrections named. Team colours: set B. Decision D21. Both critics and the director had ranked market-warmth first, third calibration point for A6.

## Comments

