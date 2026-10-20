# Session 29: the AI rings castles with any piece

Sebastian, 2026-10-20: "The algorithm placing walls is still optimized for not capturing castles
and for placing 1x1 pieces. Revamp it for the new ways we designed walls with multi tile pieces
that fit anywhere."

## What was wrong

The planner was the Unity port's `BuildingPlan`: rectangles of free tiles, their border the ring.

- A rectangle was only "possible" when every tile inside it was free or the AI's own, so a
  rectangle round a neutral castle (255 on the mini map) never existed, and the castle bonus of
  40 never scored. The AI claimed a castle only by accident, when the rings of several rectangles
  happened to close round one.
- The ring was the exact one-tile border. A piece placed only when every cell outside the ring
  stayed outside, so an S, T or plus with a cell pointing inward covered nothing and flew away,
  and a piece could never bend a ring or reuse a bulge.
- The search enumerated every rectangle up to 6 x 5 round every tile in plan range, scored and
  combined them in a coroutine sliced over frames.

## The design

**A plan is a region to enclose, not a rectangle.** [RingPlan.gd](../../../scripts/RingPlan.gd)
holds a target: a castle's 3 x 3 plus the free tiles one tile round it (so a claimed castle brings
16 tiles of gun room), or a 3 x 3 yard of free ground. The plan's ring is the cheapest 4-connected
closed loop round the target on the board as it stands: own walls cost 0, free ground 1, an enemy
wall 2, free ground already inside own territory 3; water, castles, guns and ruins cannot carry a
wall and the loop goes round them. A loop that is 4-connected is what the fine-cell flood cannot
pass (diagonal blocks never join), so the cheapest loop is the fewest blocks to a closed ring.

**The loop search.** A loop round the target crosses a ray east of it exactly once. For every ray
tile the plan runs one Dijkstra from the tile north of it to the tile south of it through the
window round the target (the target's box grown by 4), with the ray and the target forbidden, and
keeps the cheapest loop over the ray tiles. Costs are 0 to 3, so the queue is a bucket list. The
loop's non-wall tiles are the gaps; the 8-flood from the target bounded by the loop is the inside.
A closed plan has cost 0.

**Plans.** One per live castle, kept across phases; yards made on demand.

- Tier 0, own castles: their loop reuses the standing ring and patches a breach at its width.
- Tier 1, yards: when the free tiles inside own closed ground are fewer than the parts still to
  place and no yard is open, the AI picks the 3 x 3 of free open ground whose ring shares the
  most own walls, the nearest castle on ties, and keeps the four best by that proxy for a real
  loop cost. The start ring has no free tile inside, so the first yard comes before the first gun.
- Tier 2, claims: castles not held by the AI and not sitting in another player's closed ring, the
  nearest to own walls with a finite loop, three open at a time.

Plans refresh when the reach mask goes stale (every own placement, loss and castle hand-over), at
every phase start, and at least every two seconds for what the enemy did.

**The held piece.** In tier order, the piece goes where it covers the most gap tiles of one plan:
all four turns, every gap as every cell, every cell free and one in reach, no cell inside the plan
it serves. Cells beyond the ring are allowed: the next refresh reroutes the loop through them
when that is cheaper. When no gap of any plan is in reach, the piece walks: it
lands in reach as near as it can to the plan's nearest gap, provided that is nearer than the
nearest own anchor already is. A single block with nothing to cover stacks on a ring wall of an
own castle, then of a yard, then anywhere own. A piece with no use flies away, as before.

**Guns** go on free tiles in reach inside own closed ground, the inside of an own castle plan
first, then a yard, then any. A gun never waits on a plan that might not close. A gun over the
parts cap stays in hand until a gun dies: the session 20 discard drew a new over-cap gun every
0.3 s and discarded it every 0.5 s action, so once the cap filled, ten seconds into the first
phase, no wall was ever placed again.

**What dies.** `BuildingPlan.gd`, the rectangle search, its coroutine slicing, the compatibility
scoring, the exponential wall cost, the double-stack plan, the plan range mask. Tests and tools
asked `has_method("search_best_building_plans")` to spot an AI; `is_ai()` replaces it.

## Tests

`tests/ai_test`, each watched red with its rule broken:

- the start castle's plan is closed with the 16 ring blocks as its ring; one block gone, the gap
  is that block, cost 1; a free neutral castle costs 24
- a yard plan exists at the start (no gun room), a claim plan or two with a finite cost
- an S piece placed by the AI covers yard gaps, no cell on own ground
- the gun in hand waits while no own closed ground has a free tile
- live: the yard closes, guns land inside own closed ground, a neutral castle is ringed and claimed
  at the check, and a breached start ring is patched
- the reaction-time pacing of session 20

## As built

- **Three claims at a time, not two.** A ring's last gap is often a one-tile hole only a single
  block fills, and a dropped piece flies three seconds before the redraw, so a third open claim
  gives a piece a use more often.
- **Only the served plan's inside is off limits.** With every plan's inside forbidden, two claim
  castles five tiles apart deadlocked: each ring ran through the other's margin. Now the first
  ring goes through, the margin tile it takes leaves the other target, and the second ring reuses
  that wall.
- **A target inside own closed ground is closed.** The loop lives in a window of four tiles round
  the target and cannot see a bigger enclosure; its last gap sat inside own ground and the AI
  refused to wall there.
- **An own castle's margin holds only own ground and own guns.** A ring block shot off the tight
  start ring was no wall any more, joined the target, and forced a five-tile detour instead of
  the one-block patch. A claim keeps the full margin, that is its gun room.
- **A held target skips the loop search.** Its inside is the 8-flood to the nearest walls and its
  ring the own walls among them, so a refresh with every plan closed costs little.

## Result

Each AI in ai2 claims its four neutral castles in the first build phase (seed 1: both hold five
at the first check; seeds 2 to 4: every plan closed by 30 to 38 s, 146 to 198 walls), places its
guns inside, patches breaches, and idles only once nothing is left to ring. A refresh costs up to
13 ms at the game start (every plan plus the yard pick) and little afterwards.

| run | p99 frame | worst frame |
|---|---|---|
| session 24, pieces | 21.0 ms | 44.8 ms |
| session 29, seed 1, 130 s | 27.8 ms | 37.6 ms |

`tests/ai_test`: 36 checks. Suite green, 19 entries.

**Watched red** (each rule broken on purpose, the test red, then restored):

- cells off the ring refused, the old one-tile bias: no neutral castle ringed in 25 s
- no claim plans: no finite claim ring, no castle ringed
- no plans for own castles: the start castle's plan empty, tier 0 empty
- the session 20 discard back: the over-cap gun discarded and the piece not placed, no castle ringed
- the full margin on an own castle: the shot ring block joined the target, a five-tile detour
  instead of the one-block gap
