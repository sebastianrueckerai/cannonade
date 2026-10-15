# Round 09 notes

Phase E, the castle duel, main images only, no capsule work until Sebastian's OK. His rules after round 08: cannons stand inside the walls on the courtyard floor, never on a wall or a tower; big enough to shoot over the wall with the barrel at about 45 degrees; two or more cannons all the same size; the grid parallel to the castles; the castles not mirror images. He asked for two routes in parallel: fixes of existing images by painting over the faulty area and inpainting only that area through a mask, and newly generated variants.

## Route 1: scenes, then local fixes

[round.json](round.json) repainted the five scenes of round 08 with the cannons inside. The model kept the cannons in the courtyards but at the old shallow angle, kept the grid of the side-by-side scenes diagonal against the horizontal walls, and in scene 3 kept cannons on the towers and the walls.

The local fix, tested on scene 5's upper-left cannon and then on more, see [inpaint-tests.png](inpaint-tests.png):

1. `fal-ai/flux-pro/v1/fill`, the mask over the cannon, no paint-over: the cannon came back flat. Flux Fill regenerates the masked area from the context, and the context says cannon.
2. `fal-ai/flux-lora/inpainting` at strength 0.8 on a paint-over, a rough barrel at 45 degrees drawn with the new [mask.py](../../../../pipeline/mask.py): the cannon was erased and the wall repainted cleanly. Strength 0.8 ignores the paint-over. A clean removal tool.
3. The same at strength 0.6: a complete cannon on the floor, the barrel at about 35 degrees on screen, the same size as its neighbour. The one success.
4. `google/nano-banana-2.1/edit` on the paint-over, pasted back through the mask: a cannon twice the size. The mask bounds the area, not the size.
5. Flux LoRA 0.6 on three more cannons in one call: raised, but in a ribbed style that does not match, and a stray barrel stub on the lower left.
6. Flux LoRA 0.6 adding a second cannon to scene 2: a shed.
7. The existing cannon copied into the spot, then Flux LoRA 0.45 to blend: melted cannons.

One success in seven attempts. The paint-over steers the inpaint only in a narrow band of strength, and small objects read as buildings. Candidate F on the sheet is the one success in its scene, the other three cannons of that scene are unfixed.

## Route 2: new paintings

[round-new.json](round-new.json), four directions through nano-banana and one through `blackforestlabs/flux-3/edit-image`, all with round 09's scene 2 as the reference, no title, every cannon rule in the prompt. Checked in [cannons.png](cannons.png), each castle at 2x:

- **A closer, diagonal**: the near castle large, its two cannons big, the same size, complete, on the courtyard floor, raised about 40 degrees, aimed over the wall at the far castle; the far castle's two in its courtyard, raised, aimed back. The grid runs with the walls. Right in every rule.
- **B land, diagonal**: two cannons in each courtyard, complete, the same size, raised about 30 degrees, aimed at the other castle. Right, a little flatter than A.
- **C islands, diagonal**: the near castle's right cannon stands on the wall by the tower, and the left barrel has two carriages under it. Wrong.
- **D side by side**: the model kept the reference's diagonal layout and drew one near cannon. The layout was not drawn.
- **E land, diagonal, Flux 3**: one cannon in the near castle. Wrong count. The second model kept the layout and the style of the reference closely.
- **F**: round 09 scene 5 with the one inpainted cannon, for comparison.

Director's ranking: A, B, F, E, C, D.

## Critics

Gemini ranks A, C, B, E, F, D, GLM A, C, F, B, E, D, see [critique/](critique). Both put A first with no fault found. Both put C second and both missed what the crop shows, the cannon on the wall and the double carriage. Gemini calls B's two near cannons different sizes and its elevation too low, GLM calls B's elevation about 20 degrees; the crop shows about 30.

## Lessons

- A new painting with every rule in the prompt beat a local fix: two right images in five against one right cannon in seven fixes.
- The angle that holds is about 35 to 40 degrees on screen. "45 degrees" in the prompt gives that; the model does not draw steeper.
- "Side by side with the castles at the grid's angle" did not move the layout of a reference that is diagonal. A side-by-side duel with an aligned grid needs a side-by-side reference with its grid fixed first, or no reference.
- Inpainting tools now exist: [mask.py](../../../../pipeline/mask.py) for masks, paint-overs, copies and masked pastes, and `img.py gen --image --mask` for the inpainting endpoints. Flux LoRA at 0.8 is the removal tool, at 0.6 the redraw tool, both for one object at a time.
