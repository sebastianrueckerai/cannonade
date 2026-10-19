# Session 20: the AI's flying cannons and the castle fade

Two playtest reports (2026-10-19), fixed in one commit, each rule guarded by a
test broken on purpose and watched fail.

## 1. "The AI's placeable cannon flies away all the time, even when it is not placing cannons"

Root cause, traced: `GameController._process` draws a building for every player
(`try_get_next_building`), so the AI holds a piece like the human does. The AI
places guns until `parts_used` sits at the cap (6 parts at one castle, reached
in the first seconds of a build phase — `try_build_walled_in_gun` dumps the
drawn gun on any free tile in reach). From then on every drawn shooter is over
the cap, and `execute_building_plan` calls `drop(nextBuilding, false)`, which
flies it away; the redraw comes 0.3 s later, is over the cap too, and flies
away as well — for the rest of every build phase. The discard itself is right
(it clears the hand so the wall logic keeps running, and rotation lets a
smaller gun fit under the cap); the flight animation on a repeat discard is
the bug.

Fix: `AI._discard_next_building` swallows the held piece without the
fly-away (`U.destroy` + null + the usual redraw cooldown). Identical draws,
identical placements; only the animation goes. The old Upgrade-block drop
branch went with it: the only Upgrade-carrying defs are parked (D64), and a
kept non-shooter would never wedge anything (the gun builders skip it, the
walls still build).

Test: new `tests/ai_test` — a real versus game, the enemy AI filled to its
parts cap, then (a) an over-cap shooter discarded with no `FlyAndVanish`
flight on a building, (b) seconds of live build phase with the AI acting, no
building ever flying. Red before the fix (flights counted), green after.

## 2. "The castle goes transparent when I place something near it; when I place behind it I still don't see the piece"

Root cause, traced: `_fade_blocking_castles` keyed on the cursor ground point
(`aimPoint`) alone. Hovering the castle itself or its wall ring pierces the
castle's AABB with the camera ray, so the castle faded while the held piece
sat in the gui slot — a ghost fade that reveals nothing. And a held building
never previewed at the cursor at all (only walls moved to the tile), so
"placing a gun behind a castle" faded the castle and showed empty ground.

Fix, two halves in `PlayerController`:
- The fade runs only while a piece actually previews at the cursor
  (`freeTileSelected or canStackWall`, and a piece is held): no preview, no
  fade, castle stays solid.
- Held buildings preview on the hovered free tile like walls
  (`next_building_to_map` / `next_building_to_gui`), so the fade reveals the
  gun behind the castle. Shadows follow the wall pattern (on over the map,
  off in the slot); the tile's decoration hiding is the wall's existing
  machinery, shared by both previews.

Test: `check_test` 2c rewritten — a free tile truly behind the castle fades it
and both previews stand on that tile; hovering the castle's own tile keeps it
solid (the ghost-fade rule); the clear far tile keeps it solid. New building
preview check in `preview_test` (moves onto the hovered tile, back to the slot
off-board).

## Result

One commit on master, pushed to origin. All three guards watched red before
the fix and each was broken on purpose after it: restoring `drop` failed
`ai_test` on both its checks, restoring the old early-out failed `check_test`
2c on the solid-under-the-cursor rule, and removing the preview call failed
2c's held-gun check and `preview_test`'s building hover. Full suite green
after the restore: sixteen entries, no ERROR output.
