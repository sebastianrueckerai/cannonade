# Session 61: four chunkier 1x1 cannons to judge

Sebastian, 2026-10-22: "the 1x1 cannons are a bit thin and small. I also want one version without any
wood. Can you make variants that are a bit chunkier? Maybe a bit into the direction of the mortar? The
simensions should still be the same and they should still have the two parts... can you make 4 for me to
judge?" And the reason: "The current cannon looks great up close, but from a distance its more important
to use its 1x1 square effieciently so it clearly read as a cannon! With some heft!"

One exploration round ended by his pick, roadmap C20. What the pick feeds: the winning run becomes the
new cannon model through split.json and [barrel.py](../pipeline/barrel.py) (the plate, the trunnion
pivot, the scaling into the square stay as they are), the unpicked runs park in
[cannon](../game/assets/3d/cannon) with the castle round's other unpicked looks.

## What the distance sees

The versus board is 52 tiles wide in 94 % of a 1280 px window, so a tile is about 23 px at the default
zoom and the whole gun about 20 px tall. At that size only the silhouette mass reads: a fat barrel, a
heavy base, a muzzle ring. The current gun is a slender swivel barrel on a post — elegant close up, a
stick on a disc from far away, most of its 0.9 m square empty.

## The four candidates

Four nano-banana edits of the picked reference [b-clean](../game/assets/3d/cannon/refs/b-clean.png),
same style and palette, one Meshy run each at 1000 triangles:

1. **chunky-post** — the current design with much more girth: fatter barrel, bigger breech ball, thick
   banded post, wide iron foot with a tall rim.
2. **chunky-mortar** — toward the 2x2 mortar: fat pot barrel with a flared muzzle on heavy riveted iron
   cheeks, on a chunky wooden block.
3. **chunky-carriage** — the classic silhouette: fat barrel on trunnions between wooden cheeks, two big
   wooden wheels with iron rims.
4. **chunky-iron** — no wood anywhere: fat iron barrel, riveted iron yoke and pedestal, octagonal iron
   base, greys varied so the shapes read.

## What every candidate keeps

- The height of the current gun (about 0.85 m) and the 0.9 m plate footprint; the gain goes into girth,
  the silhouette nearly as wide as tall.
- Two parts: the barrel separate on its trunnion pins, the mount below it — the game's split and tilt.
- The painterly style and the iron-and-wood palette of the picked direction, except the no-wood one.
- Big simple shapes with sharp edges (D72), no fine gravel detail.

## Phases

1. Four reference edits, checked in magnified crops before any 3D run.
2. Four Meshy runs, numbers first (dims, triangles) against the 1150 budget.
3. The board: every candidate big beside the current gun (D48), scaled to the same 1 m footprint, plus
   the game's default view at gameplay size for the distance read. Opened in his editor, picked by
   board number.
