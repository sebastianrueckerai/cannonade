# Session 21: the free-tile preview shows the wall only

Third playtest report (2026-10-19), one fix, its rule guarded by tests that
were watched red with the old behaviour in place.

## "I now start with having a gun and a wall piece at the same time placeable as the preview. Show wall only."

Root cause, traced: session 20 taught the held building to preview on the
hovered free tile like the wall (`next_building_to_map`), so with the usual
hand — one wall, one gun — a free tile under the cursor carried both ghosts
stacked, and neither piece read. The gun has its gui slot all along; the wall
is the piece that previews.

Fix: `PlayerController.update_point_and_tile_selected` sends the held building
to its gui slot on a free tile (`next_building_to_gui`); `next_building_to_map`
is gone. Placement is untouched: the wall still lands on left mouse, the gun
still lands on right mouse, stacks and combinations behave as before. The
castle fade keeps its session-20 rule unchanged — it fires while a piece
previews on the hovered tile, and the piece it reveals is now the wall. Trade,
noted: a gun parked behind a castle is placed from its gui slot while the
castle fades around the wall ghost.

Test: `check_test` 2c now pins the wall on the hidden tile and the gun in its
slot while the castle fades; `preview_test` pins the building staying in its
slot while the wall lands and the tile's trees hide under the wall alone.

## Result

One commit on master, pushed to origin. Both guards ran red before the fix,
each on exactly its new slot assertion, and green after. Full suite green:
sixteen entries, no ERROR output.
