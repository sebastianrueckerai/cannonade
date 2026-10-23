# 73 — The second-level gradient, boulders on the mountains

Sebastian, 2026-10-23: "Cool. Maybe make the whole 1st level green and then have a gradient on the second level.
Also, much like trees live on the hills, have rocks on the mountains!"

## Design

1. The colour law moves up one level: [Terrain.gd](../../../scripts/components/Terrain.gd)'s `_tint`
   stays pure green through the first 0.75 m, interpolates green into the family colour across the
   second level, and wears the family colour from the second level's top up. One clamp start moves
   (`y` to `y - LEVEL`); the feet skirt, the shatter pieces (they call `_tint` at their block's own
   height) and the crown lift follow for free.
2. Boulders on mountains: the terrain decoration pass sprouts on standing rock columns the way it
   sprouts greenery on hills. `place_decorations`' maker filter becomes by sort - hills draw the
   greenery (everything but boulders, as now), rocks draw boulders alone - and `_terrain_trees`
   renames to `_terrain_decorations`, hills and rocks both through it. A boulder stands on the
   drape's own surface and flies with the block it stands on when that block is shot, the tree's
   path unchanged.
3. Guards in [terrain_test.gd](../../../tests/terrain_test.gd): every drape vertex at or below the
   first level's top wears the ground green exactly (the old law mixed the family colour in from the
   ground up, so this goes red against it); the tallest hill's crown and the tallest rock's crown
   keep their family colour as now; `_tree_board` flips - rocks carry boulders (every one a
   nature_boulder), a shot block takes its boulder with it.

## Steps

1. Terrain.gd: the gradient start moves to the second level.
2. GameController + BuildingPlace: the by-sort maker filter, the rename, rocks in the pass.
3. terrain_test guards, both watched red.
4. Suite green, a mountain close-up before | after, merge by push.

## Ticks

- [x] I119, D100
