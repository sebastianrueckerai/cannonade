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

## Round 2: boxes, holes, a tunable count (I93)

Sebastian, 2026-10-22, after seeing the placeholder render: "that looks terrible. The visible blocks are
stretched and much bigger than the 4x4 i requested as maximum! I want shapes like these: [4x4 full block,
a hook with holes, a 2x2-plus-tail clump, a 3x3 zigzag] and so on. Like bigger tetris shapes that have
clumps not just lines. Model a bunch of these from blender primitives. Just assemble boxes the same size
as our tiles in the patterns above and in other patterns. And use those as obstacles." And on fairness:
the line between the parties is horizontal (each side owns the half its castle stands in — the castles
already z-mirror this way, so the split was right in the data; the stretched 2.1-scale placeholder blobs
made it unreadable), each side keeps the same blocked tiles (the exact mirrors do), the count becomes a
tunable number tuned to "a good few but not too many", and the encirclement guarantee stays the upper
bound.

1. **A clumped shape library.** Ten shapes of 4 to 16 cells, all inside 4x4, clumps with holes and
   notches instead of lines: the 4x4 solid, a 4x4 with a 2x2 corner bitten out, a horseshoe with a
   one-tile hole, a 3x3 ring, the 3x3 solid, his hook, his 2x2-plus-tail, his zigzag, a fat S, the 2x2.
   Hole tiles stay free ground — a wall can stand in a horseshoe's mouth.
2. **One sort per feature, not per kind.** Each feature is stone (indestructible, absorbs every hit) or
   crates (destructible, 10 health a tile), drawn 50/50; the sort is mirrored with the shape so the
   halves stay identical.
3. **Tile-size boxes from Blender.** One model family per sort, `terrain_stone` and `terrain_crate`, a
   look each a different height block (three looks per family, picked per tile, so a mass reads as piled
   blocks not one extrusion). C18's mountain/hill placeholder plan is superseded by this.
4. **A tunable count.** `--terrain=N` (and the config key) sets the features a side draws; the default
   was picked from board dumps and renders at several counts.

## Round 2 check

The new guards in tests/terrain_test, each watched red then restored: a shape widened past 4x4
(the bbox check), the horseshoe's mouth claimed shut by its own cells (the hole check went red
with the gap-filling break, n>=1 suffices), and the "terrain" key dropped from Main (both knob
checks red). Suite green, 23 PASS — after one find the terrain layout flushed out: flood_test's
reference still closed any enclosed region the pre-D88 way, and the round-2 board at seed 11
grew the first two-faction border its random edits ever produced (test walls plus a start ring
jointly enclosing 7 tiles: the game rightly open under D88, the reference closed). The D88
verdict moved into StatesMap._finish_flood, called by both the optimised fill and the original
cell-by-cell reference, so the reference guards the fill and walls_test guards the sealing rule;
the block enqueue broken on purpose turned it red again before the restore.

## Round 3

Two asks: bigger obstacles (up to 7x7, no plain rectangle, clustered rather than evenly spread)
and a red preview of the blocked part of a held piece.

**Shapes.** Eight big patterns join TERRAIN_PATTERNS: 7x7 donut, spiral, 7x7 U, thick L,
double clump, 5x7 zigzag, comb, 5x5 donut. The first spiral draft was two disconnected islands
(row 0 hanging off column 6, rows 2-6 a second mass) — caught it reviewing the diff, replaced
with a connected curl. Every big mass has a hole by construction, so "no boring rectangle"
holds without a runtime rule.

**Clustering.** The first try — anchor a random cell of a placed feature plus a random one of
eight directions — measured 12-13 touching pairs against 8-2 unbiased and looked thin because
the shape grows back over the neighbour, fails `_terrain_fits`, and the retry scatters
uniformly. Raising the gate 0.4 to 0.6 changed nothing (12 vs 13). The shipped rule seats the
new feature's bounding box flush against a placed one's, one of four sides, the slide along it
random: 23 pairs at 0.5 and 27 at 0.7 against 2 unbiased (8 seeds, versus, --terrain=6), so
TERRAIN_CLUSTER stays 0.5. Blocked area holds near 10% of a half; TERRAIN_DEFAULT drops 8 to 6.

**Red ghost.** `Wall.paint_piece` takes per-cell tints; `_blocked_tints` in PlayerController
walks the piece's cells and marks a cell red when the tile cannot take a block (terrain, a
wall, enemy ground, off the map — the same rule `can_place_piece` applies per tile). A blocked
cell's block also rides on top of the structure that blocks it: at ground level the red block
would sit inside the terrain box, out of sight. `_settle_cells` resets the heights every
frame, so the lift is per hover, not sticky. The anchor cell (the hovered free tile) stays
white; a piece over own walls keeps the storey stack preview as before.

**Break-checks** (each watched red then restored): an 8x3 solid pattern (oversize and
solid-big both red), the eight big patterns removed (big >= 4 red), TERRAIN_CLUSTER := 0.0
(pairs red), `_blocked_tints` returning empty (the red and the lift red). The `:=`-from-
Variant trap bit twice in new code (`_blocked_tints`'s `ok`, `preview_test`'s `nodes`) —
both the same shape as round 2's: an untyped `map`/`human` in the chain.

**The suite flake.** The full suite failed previews once with the spot search empty while
the same test had passed standalone: the dealt piece is time-seeded (`U.randomize()` runs at
startup, `Catalog.draw` picks through the global RNG), so the drawn shape varies per run and
some shapes find no free anchor beside terrain on the seed-7 board. `_check_blocked_cells`
now picks its own piece, the first wall def from `Catalog.drawable(WALL)` that anchors beside
terrain at one of its rotations (`_check_pieces`' destroy-and-spawn pattern), and leaves it
in the hand — the first draft saved the dealt piece to restore it and crashed on a freed
instance: the def loop's first destroy frees exactly that piece. The `:=` trap bit a third
time in the same fix (`var held := human.nextWall`): a parse error makes the scene hang, so
the runner times out at 600 s with exit 124 instead of failing fast.

**Renders:** /tmp/r3_versus_s4_005.png, /tmp/r3_versus_s11_005.png, /tmp/r3_ai4_s5_005.png.


## Round 5

One ask in two parts: the halves must stop looking symmetrical ("same amount but not the
same configuration") and features may cross the midline while the sides stay level.

**Independent seats.** `_terrain_mirrors` is gone. Each drawn shape lands twice (four
players: once per quadrant) at its own anchor and rotation; with two players the second seat
comes from `_terrain_partner`, a search over rotations and anchors whose tiles above the
midline number what the first seat placed below it, so every standing pair contributes its
tile count to each side. A pair that cannot seat (fit, ring guarantee) releases both members
and redraws; TERRAIN_ATTEMPTS bounds the rounds. Measured: seed 4 holds 101/101 blocked
tiles a side with 320 tiles off the flip, 22 features cross the midline across the 8 swept
seeds, ai4 seed 5 holds 119 a quarter, clusters hold (37 touching pairs).

**Bugs this round.** The first draft missed the `_terrain_fits` gate on the anchor seat: two
features could share tiles, the shared tile counted once and the sides drifted (seed 4 stood
124 to 118) while the tile-integrity check failed; the same stuck structure kept the rings
cut and sank `_ai_board`'s last check with it. The seventh `:=` bite: `var mid :=
map.sizeZ / 2` through untyped map - a parse error again, and the tool run poured 64 MB of
cascading errors instead of failing clean. The rng sort could draw a one-sort board (seed 4:
twelve stone), which starved the crate damage checks; sorts alternate by shape now.

**Break-checks** (each watched red then restored): the partner z-flipped back to the first
seat (0 tiles off the flip, the difference guards red on every seed), the partner copying
the first seat's split instead of complementing it (56 against 112, the level guards red),
and the first seat boxed into one half (0 crossings, the midline guard red).
