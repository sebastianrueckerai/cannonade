# Session 27: a bigger map with three free rows round every castle

Sebastian, 2026-10-20: "Make the map a bit bigger and leave 3 rows between any castle and the
border so every castle can be walled in."

## Root cause

On the 30-tile map the outer neutral anchors sat at (4, 4) and (25, 4), and the jitter of up to
two tiles took a centre as far as 1: the castle's edge on the border, where no ring fits, and a
centre of 2 put the ring itself on the border. The start castles were fine (rows 7 and 23).

## Change

- Versus, ai2 and practice play 34 x 34 (`Main.MODES`); `single` keeps 20 and `ai4` 60.
- `GameController.CASTLE_MARGIN` = 3: free rows between any castle's edge and the map edge.
  `_neutral_castle_spot` rejects a centre nearer than 4 to an edge, and the anchors move in by two
  to (8, 13), (25, 13), (6, 6), (27, 6), the spacing of before plus the border room, so the jitter
  reaches the margin and never crosses it.
- The second start castle and the four-player starts sit on the exact mirror
  (`sizeZ - 1 - sizeZ / 4`) like the neutrals and the sandbox's new layout; before, player 2's
  castle stood one row nearer its edge than player 1's.
- The too-small check asks for 16 tiles, the size at which a start castle at a quarter keeps the
  margin.

## Tests

- `tests/check_test`: the seed-4 layout's castles all keep three free rows, and twelve more seeds
  (10 to 21) each build a versus game, read its ten castles and free it before a frame passes, so
  no AI coroutine starts.
- The tests that named tiles of the 30 map derive them from the map size now (`check_test`,
  `practice_test`, `ai_test`, `human`), and `weapons` places its specials on tiles no jitter can
  reach: the east margin, the middle columns clear of the start rings, the free rows between the
  castle bands.

## Verification

- Suite green, 19 entries.
- Broken on purpose, the old anchors (4, 4) and (25, 4) and the old edge bound of 1 back in: the
  seed-4 layout check went red (castles at (3, 4), (27, 2) and their mirrors) and 11 of the 12
  sweep seeds reported castles 1 or 2 rows off the edge; seeds 14 and 17 happened to stay inside.

## Shot

[27-map.jpg](27-map.jpg): versus, seed 4, five seconds in, from the default view: the 34-tile map
with its ten castles, every one three rows or more off the edge.
