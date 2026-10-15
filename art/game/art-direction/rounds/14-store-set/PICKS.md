# Picks, round 14: the title and the full store set

Superseded by round [15-cannonade](../15-cannonade/PICKS.md): the game is released as Cannonade (D26), and the title and the set were redone with the new name. The paintings of this round stay the sources of the set.

The key art of D25 with the title laid over it, and every store asset made from it by script. The sheets:

- [letterings.jpg](letterings.jpg): three letterings of the title on the same painting, each on the main capsule and the small capsule at 462, 184 and 120 px wide.
- [set/sheet.jpg](set/sheet.jpg): the full set with lettering b, every asset at its exact size. The files are in [set/](set). The same set with a and with c is in [set-a-white/](set-a-white) and [set-c-cream/](set-c-cream).

## The three letterings

All three are the white hand-lettered script of round 07's candidate 4, the lettering Sebastian called the best text. Each was drawn by `google/nano-banana-2.1/edit` with candidate 4 attached, on a flat green screen, [round.json](round.json). [storeset.py](../../../../pipeline/storeset.py) keyed each one to a transparent logo.

| | lettering | at 120x45 |
|---|---|---|
| a | white letters, a soft shadow | blurs, loses contrast on the pale sky |
| b | white letters, a dark brown outline | reads, the outline holds on sky and land |
| c | cream letters, a dark brown outline, an orange-red drop shadow | reads, the shadow thickens the letters |

Gemini ranks b, c, a, GLM ranks b, a, c, see [critique/](critique). Both put b first for the outline, which keeps the title readable at every size. GLM finds b's outline a little hard for a cosy game, and a's soft shadow the cosiest.

## The set

Made by `storeset.py compose` from three paintings, every one checked in crops, [source-checks.png](source-checks.png):

- **The wide key art.** [marketing_style.png](../../anchors/marketing_style.png), upscaled 4x by `fal-ai/aura-sr`, for the 16:9 capsules, the page background, the icons and the splash.
- **A tall repaint.** A 2:3 version for the vertical capsules, with an open sky above the castles.
- **A wide repaint.** A 21:9 version for the library hero and the header capsules, with both castles in the middle band and land to both sides.

| asset | size px | title |
|---|---|---|
| Steam header capsule | 920 x 430 | yes |
| Steam small capsule | 462 x 174 | yes, nearly fills it |
| Steam main capsule | 1232 x 706 | yes |
| Steam vertical capsule | 748 x 896 | yes |
| Steam page background | 1438 x 810 | no, blurred and darkened |
| Steam library capsule | 600 x 900 | yes |
| Steam library header | 920 x 430 | yes |
| Steam library hero | 3840 x 1240 | no, Steam forbids text |
| Steam library logo | 1280 x 377 | the title alone, transparent |
| Steam community icon | 184 x 184 | no, the near castle firing |
| icon | 512 x 512, and a .ico | no |
| itch.io cover | 630 x 500 | yes |
| game splash | 1920 x 1080 | yes |

Both critics find no fault in any asset of the set. One limit: Steam never crops only the centre 860 x 380 px of the library hero. Both castles sit outside that centre, so a very narrow library window cuts one of them. The shot stays inside the centre.

## Pick

- [ ] a  - [ ] b  - [ ] c
- [ ] correction: ______

## Comments
