# Picks, round 15: Cannonade, the title and the full store set

The game is released as Cannonade (D26). This round redoes round 14's title as the single word CANNONADE and recomposes the full store set with it. The paintings are round 14's, already checked in crops.

The sheets:

- [letterings.jpg](letterings.jpg): three styles of the title on the same painting, each on the main capsule and the small capsule at 462, 184 and 120 px wide.
- [set-b-outline/sheet.jpg](set-b-outline/sheet.jpg): the full set with style b, every asset at its exact size. The files are in [set-b-outline/](set-b-outline). The same set with a is in [set-a-white/](set-a-white) and with c in [set-c-cream/](set-c-cream).

## The three styles

Each was drawn by `google/nano-banana-2.1/edit` on a flat green screen with round 07's candidate 4 attached, [round.json](round.json). All three spell CANNONADE correctly. [storeset.py](../../../../pipeline/storeset.py) keyed each one to a transparent logo.

| | style | at 120x45 |
|---|---|---|
| a | white letters, a soft shadow | blurs against the pale sky |
| b | white letters, a dark brown outline | reads |
| c | cream letters, a dark brown outline, an orange-red drop shadow | reads, the shadow thickens the letters |

Gemini and GLM both rank b, c, a, see [critique/](critique). Both find c the warmest fit for a cosy game.

## Fixes made before this sheet

- **The logo touched the frame.** The one-word logo is taller than the two-word one, and its first C poked over the top edge of the main capsule. Every logo now keeps a margin of 4% of the frame height.
- **The logo covered a flag.** On the itch.io cover the logo covered the far castle's flag. It is now smaller and sits left of the castle.
- **Too much empty sky.** Gemini found it on the vertical capsule. The crop moved down to show more land.

Gemini also claimed that the library hero carries the title and that the library logo has a grey background. Both claims are wrong. The hero has no text, and the logo is a transparent PNG. The grey is only the sheet's backdrop.

| asset | size px | title |
|---|---|---|
| Steam header capsule | 920 x 430 | yes |
| Steam small capsule | 462 x 174 | yes, nearly fills it |
| Steam main capsule | 1232 x 706 | yes |
| Steam vertical capsule | 748 x 896 | yes |
| Steam page background | 1438 x 810 | no |
| Steam library capsule | 600 x 900 | yes |
| Steam library header | 920 x 430 | yes |
| Steam library hero | 3840 x 1240 | no, Steam forbids text |
| Steam library logo | 1280 x 486 | the title alone, transparent |
| Steam community icon | 184 x 184 | no |
| icon | 512 x 512, and a .ico | no |
| itch.io cover | 630 x 500 | yes |
| game splash | 1920 x 1080 | yes |

One limit: Steam never crops only the centre 860 x 380 px of the library hero. Both castles sit outside that centre, so a very narrow library window cuts one of them.

## Pick

- [ ] a  - [ ] b  - [ ] c
- [ ] correction: ______

## Comments
