# Session 53: the wall placing pause
Sebastian, 2026-10-22: "We should add a tiny pause between placing walls so a palyer cant just wildly machinegun click walls into a direction plastering them automatically. We want them to placve quickly, but this would be an exploit." Then: "The ai already had the cooldown, but ahuman can place walls as quickly as they like. This is fione for cannonsa but for walls a little pause would keep them from wildly click a lot."
Roadmap: I83, game code.

## What ships
A wall just placed holds the next one for `secondsBetweenWalls` (0.25 s) in
[PlayerController.gd](../../../scripts/components/PlayerController.gd). The clock `secondsLastWall` is
stamped where the wall lands — the tails of `build_next_wall` and `stack_wall`, the shared success point
the AI walks through too — and the human's act click inside the wait plays `place_invalid` and is dropped:
the piece stays in hand, nothing is queued, past the wait the same click places it. The number: deliberate
placing tops out at 3-4 walls a second and machinegun spam 6-10 clicks a second, so 0.25 s caps at the top
of deliberate speed; Sebastian took the recommendation.

## What it reuses
The `secondsLastBuilding` / `secondsBetweenBuildings` idiom already on the controller, the `place_invalid`
sound already used for refused placements, and in the test a free-column scan cut after `free_quad_in_range`.

## Where it does not open
Guns stay instant (I80 dealt them the next frame on purpose), the AI keeps its own `secondsBetweenBuilds`
pacing, discards keep their waits (0.3 s for a thrown-away gun, the fly-away seconds for a wall), and the
sandbox's `place()` and the tests' direct `build_wall(...)` calls never go through the gate — only the human
input click does.

## The check
[human.gd](../../../tests/human.gd), real clicks, a held upright three: the click right after a placed wall
places nothing and the piece is still in hand, past the wait the same click places it. Three older checks
whose clicks now fell inside the wait — the empty-line block, the distance refusal, the reach extension —
each got an explicit past-the-hold wait so they keep testing what they claim. The new hold check watched
red with the gate off; suite green, 22 PASS.
