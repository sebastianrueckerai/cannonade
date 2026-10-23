# 71 — The first level rises out of the ground green

Sebastian, 2026-10-23: "Great! Try this: In the first level of the hills / mountains, have the color
interpolate from the ground green to tan for hills and grey for rocks / mountains!"

## Design

1. One function paints the whole family: [Terrain.gd](../../../scripts/components/Terrain.gd)'s `_tint`
   feeds the drape's vertices, the wall feet and the shatter pieces. It changes to: the grass green of
   open ground (HILL_GREEN, D21) lerped into the family colour over the first level (LEVEL, 0.75 m);
   above it only the family's own shading goes on. HILL_GREEN is both families' base now, so it reads
   as the ground green and keeps its name only if that stays honest - rename to GROUND_GREEN.
2. Hill family colour: D21's mud_dark tan (#b2915f) with the existing light crown lift
   (0.04 + 0.10 y/peak toward white). Rock family colour: the existing ROCK_LOW to ROCK_HIGH ramp by
   y/peak. The dark foot band (ROCK_FOOT) is superseded by the green base and goes.
3. The wall faces need no own code: their vertices are the green feet at y = -0.25 and the
   family-coloured rim at the top edge, so the GPU's interpolation paints the first level's gradient.
   The shatter pieces already call `_tint` at the block's own height, so a first-level piece carries
   the green mix of the block it left.
4. Guard in [terrain_test.gd](../../../tests/terrain_test.gd) on a fresh seed 4 versus board: every
   wall foot vertex wears the ground green, the tallest hill's crown sits above the first level and
   inside the tan-with-lift segment (per-channel lerp factor consistent, 0 to 0.2), the tallest rock's
   crown keeps its grey (no green dominance). Watched red: old `_tint` (green hills, foot band) fails
   the feet and the crown.

## Steps

1. Terrain.gd: GROUND_GREEN rename, HILL_TAN constant, new `_tint`, ROCK_FOOT deleted.
2. terrain_test: `_colour_law()` after `_tree_board()`, red-watch the guard.
3. Suite green, before/after renders of the same seed with 2x same-region crops, merge by push.

## Ticks

- [x] I117, D98
