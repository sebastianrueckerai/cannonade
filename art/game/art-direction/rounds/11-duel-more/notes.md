# Round 11 notes

Sebastian on round 10: B looks good and is usable, he wants more. The title goes on later as an overlay. The budget may go over for this round.

Eight new paintings through `google/nano-banana-2.1/edit` with B as the style reference only, [round.json](round.json). Every rule of the checklist is in the prompt, and every image names two different castle designs. The 2x and 4x crops gave this result:

| image | first result | fix |
|---|---|---|
| 1 | the far castle fired, the ball about 45 degrees off the barrel | the far shot removed and the near castle's front cannon fired, through [round-fix.json](round-fix.json); then the trail curled back on itself, so a straight trail from a second edit was pasted through a mask |
| 2 | pass | |
| 3 | two balls on one trail | the nearer ball removed with `fal-ai/flux-lora/inpainting` at 0.85 through a mask; a lump and a smudge stayed, so the removal was redone over a larger mask at 0.9 |
| 4 | pass | |
| 5 | the far castle fired with the flash behind the muzzle | the shot moved as in 1; the far castle then had one cannon, so a second one was added through an edit and pasted through a mask over the courtyard only |
| 6 | pass | |
| 7 | pass | |
| 8 | pass | |

The prompt asked for a star fort in 2 and an L-shaped and a ring castle in 6. The model drew 6 as asked and drew 2 as a square fort with a tall flagpole. Five of the eight reuse B's two castles, because B was the reference.

## Lessons

- **The shot is the weakest part of a generated image.** Three of eight shots failed: a ball off the barrel's line, a flash behind the muzzle, and a second ball. Moving a shot to the near castle by an edit, which made B, fixed both cases where it was tried.
- **A masked paste keeps the rest of an image intact.** Five fixes went through masks. Outside each mask, the pixels stayed those of the checked image.
- **A removal needs a margin.** A mask cut tight to a ball leaves its shadow and the trail's lump behind.
- **The critics miss and invent faults.** They called two shots where there is one, a missing ball that is there, and a too-similar pair they passed in four other images. The crops are the gate, and the critics are a second look that every claim must survive.
