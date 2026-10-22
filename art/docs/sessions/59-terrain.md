# Session 57: terrain — rocks, houses, hills and mountains on the battlefield

Sebastian, 2026-10-22: "I want terrain on the map making placement of walls harder." An imaginary line
through the battlefield, exactly as much terrain on both players' halves (crossing the line allowed while
the blocked tiles stay even). Two sorts: destructible — "I can shoot it and its gone rocks, boulders,
houses - we can reuse the supply depots here" — and indestructible — "hills, cliffs and mountains".
"There should always be a way left to encircle all castles from every exiting castle." Features big, up to
4x4 tiles, "just a few that make sense. And not just the rectacles. Interesting mountain shapes, etc."
"The AI should target terrain which blocks its own way to castles, but there should be a simple logic so
it soes not help you by openingup your way to it."
Roadmap: I90, I91, I92 (game). The mountain and hill models are their own round (C18): Sebastian, mid-session:
"MAybe test all of this with placeholder assets first, creating 3d assets for mountins and the like will be its own
thing!" - so the mechanics ship on placeholders (a big scaled boulder for the mountain, a wide flat one for the hill;
the rocks and houses use the finished nature_boulder and supply models), and C18 builds the real masses later.

## What ships

1. **Terrain features block placement like a building** (I90). A feature is one Node3D with a `Terrain`
   component, set as `t.structure` on every tile it covers (the `place_neutral` pattern), so
   `is_free`, `can_place_piece`, `_line_clear` and the AI's ring costs refuse it with no change to the
   placement rules. Shells arc over it (terrain blocks no shot, only placement); a shell that lands on it
   damages it: destructible features carry 10 health a tile and fall to rubble like a wall (Crumble,
   ground scar), indestructible ones absorb every hit. Fairness: features generate on one half (or one
   quadrant, four players) and mirror exactly by the castles' z-flip (and x-flip), so both halves hold the
   same blocked tiles.
2. **A shape library and the encirclement guarantee** (I91). A few sensible shapes to 4x4: boulder fields
   (a stone, a 2x2 block, an L, an S), depot houses (1x1, 2x2, 3x3 — the supply models), hill masses and
   mountain masses (2x2, T, L, a 4-wide bar, a fat 3x3). Terrain keeps a Chebyshev-2 distance from every
   castle centre (its 5x5 ring stays buildable), never touches water or another feature, and after each
   placement a BFS over free tiles must keep every castle's ring connected to every other's — a feature
   that would cut the last way through is dropped and another spot tried.
3. **The AI clears what blocks its own way** (I92). For each destructible feature the AI walks a BFS from
   its own castles' rings to the castles it wants (neutral and enemy), with the feature standing and with
   it gone: it targets the feature only when removing it shortens its own route by a margin (or opens an
   unreachable one), and only when the same removal does not shorten the enemy's route to the AI's
   castles the same way — it never shoots the rock that mainly opens your way. The tier sits after enemy
   castles, before enemy walls.
4. **Placeholder masses** (C18 moved out): hills and mountains stand as scaled `nature_boulder` instances
   until their own round builds them (a first `terrain_mountain` of four unioned lumps, 502 tris, passed the
   pipeline limits in a try-out this session and was rolled back out; the recipe is in C18).

## Where it does not open

Only the round games with castles and at least two players: versus, ai2, ai4 and practice. Single player
(no halves to keep even), the sandbox and the battle lab (`castles: false`) and every seeded lab seed stay
exactly as they were. The layout draws from its own RandomNumberGenerator seeded off the game seed, so no
existing seeded expectation (castle jitter, wall deals, battle randomness) moves.

## The check

[terrain_test.gd](../../tests/terrain_test.gd) (+ .tscn) on real versus games: the features own their
tiles (mini 255) and keep Chebyshev 3 off every castle centre, the halves mirror tile for tile, every
castle ring reaches every other's round the terrain (a BFS written in the test, not the generator's own
— and the test proves its detector by watching a full-width rock line read as a cut), a destructible
feature holds 10 health a tile and dies to exactly its shell count — every tile freed, mini 0, one
shell's scar each —, an indestructible one soaks shells untouched, no wall places on a terrain tile,
eight more versus seeds and one ai4 board repeat the layout checks under both flips, and on a bare ai2
board a full-width rock line draws AI fire only while it blocks the AI alone: the same line with the
wanted castle on the AI's own side, and with no wanted castle left unhidden, is left standing.
Break-checks, each watched red then restored: the mirrors dropped (10 FAILs), a feature forced beside a
castle (the clear check; halving TERRAIN_CASTLE_CLEAR alone moved nothing on these seeds, the RNG
never lands a feature near a castle), health halved (4), the shell routing into the feature removed (2),
the indestructible absorb removed (1), the tiles unclaimed (5), clearing disabled (1), the not-helps
clause dropped (1, on the no-neutral board). Suite green, 23 PASS.
