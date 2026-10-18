# Round 30 picks – the menu's look

Three directions, built in the real menu through the Art.gd slots, shot at 1280×720 and 390
wide. Boards: [compare-v2-1280.png](shots/compare-v2-1280.png) (stacked, numbers 1–3) and
[compare-v2-390.png](shots/compare-v2-390.png) (side by side). Same numbers on both boards.

| # | Direction | Font | Buttons | Panel |
|---|-----------|------|---------|-------|
| 1 | Wooden sign | IM Fell English | painted oak plank, ink outline | oak planks, dark painted frame |
| 2 | Harbour chart | Alegreya | ochre card, one ink outline | cream chart sheet, ruled margin, faint compass |
| 3 | Flat (current, control) | Signika | flat cream box, thin ink border | flat cream box |

## Recommendation: 2, the harbour chart

Both critics (gemini, glm) independently rank 2 first to ship: "the only design that bridges
the cozy hand-painted identity and UI function". My pixel checks agree — cleanest textures of
the round (single outline on buttons, no watermark smear at render scale), and the strongest
text contrast of the two textured directions. 3 stays as the known-good fallback.

## Runner-up: 1, the wooden sign

Sebastian's own named idea, and the most alive at a glance (glm: "it breathes"). Both critics
flag the same honest weakness: cream text on mid-tone oak is the weakest contrast of the
three, and the panel frame carries one painted knot that smears mid-right. Fixable if picked:
darker text or a soft letter shadow, one panel regen.

## If 2 is picked – integration notes

- Drop [candidates/b/ui/](candidates/b/ui/) into [assets/art/ui/](../../../../assets/art/ui/) as-is; hover and pressed states derive in Art.gd.
- Full Alegreya family in place of the single weight.
- Critics' two tweaks, both one-liners: darken button ink a step (font_hover is already the accent red), and soften the button outline so cards read as stained-into the parchment, not stickers.

## Verified facts (not critic claims)

- All 7 buttons fully on screen at 390 in all three directions (pixel scan of outline rows;
  last bottom y ≈ 695 of 720). The gen-2 panel padding fix (20→12 px vertical) did it.
- "Practice (a fort that never fires back)" fits its button: measured text widths at 20 px —
  IM Fell 295, Alegreya 296, Signika 316; the widest (Signika, the control) verifiably fits.
- Title renders unclipped in all three fonts (native-res crops).
- Buttons: single clean outline, no halo, no second inner line (native-res crops).

## Spend

About $2.1 of the $6 cap by raw arithmetic (the in-tool tracker reads $1.62 and under-counts
regens): 11 paid generations and 4 critic calls across both generations.
