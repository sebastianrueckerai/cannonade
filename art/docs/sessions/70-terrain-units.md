# 70 — Hills and mountains as grown units

Sebastian, 2026-10-23: "Currently they are made by placing shapes. Can you propose an algorithm were we just
pick a few spots on the map [...] and then fill the avilable area so we leave any castle rechable from any
other castle and leave every castle so it still can be walled it. with this, make more organix andd rounded
mountain and hill shapes and wlays make them as big as possible. [...] so a hill can be like this, were 0 is
flat gounrds, 1 is one elevation level and 2 is two elevatrion levels: 00000/01110/01210/01110/00000 [...]
hills should be genty sloping anyways. Mountains could have sheer faces, but only towards the player. [...]
each connected mountain line is created as one unit an dnot different blocks accitenally being dropped next
to each other. Also: On the hills, trees should stoill grow. If the place were it grows is shot, the tree
scatters just like the piece of the hill." Parity: "at least roughly it should be equal", within 10 percent,
"not to mayorly give a benefit just to one side".

## Design (agreed in chat, then "go")

1. No shape table: TERRAIN_PATTERNS and the seat/partner/rotation machinery go. Each unit picks spots
   (best of 24 scored draws from the terrain rng), then grows by multi-source Dijkstra over open tiles
   (cost 1 + 0.4 board-keyed noise) until the family cap, the span cap, a castle clear, a reserved way,
   the board edge or the gap to another unit stops it. Rocks seed a short line of spots: one ridge, one
   unit. Cleanup fills pinholes, drops slivers, keeps the largest connected part.
2. Ways between castle rings are reserved (a BFS tree of shortest paths) before anything grows, so the
   rings stay connected by construction; after each unit a flood checks no free ground lost its border
   reach, and a candidate that fails is thrown away whole.
3. Heights: a hill domes (BFS depth from its rim, one level a tile, cap 3) — his ASCII hill generalized,
   gentle in every direction. A rock climbs sheer toward the player only; its far side eases one level a
   tile from the far rim. `_terrain_sight` runs both directions now: the player-side 60-degree law (I97)
   and its mirror bound the far side. After the trims `_terrain_ease` lowers any rock cell that still
   stands more than one level above its row neighbours east or west, so the sheer face is the player's
   alone on every side; hills need no ease (the dome holds all four neighbours).
4. Units keep a two-tile Chebyshev gap (no accidental neighbouring blocks), caps 30 tiles / 9 span a
   hill, 44 / 11 a rock, together at most 30 percent of the free tiles. `--terrain=N` is units a side
   (default 3: one rock, two hills); ai4 one set per quadrant.
5. Parity within a 10 percent band, not exact: a balance pass sheds the richer side's largest unit's rim
   tiles until the band holds.
6. Trees: after the sight pass, every standing hill column sprouts green decorations (no boulders) on the
   drape's own surface; when the block under a tree shatters, the tree crumbles away with the block.
   Rocks stay bare.
7. Supersedes I95's clustering (the gap replaces flush clustering) and I97's no-circles shape rule
   (organic blobs are the point); keeps I90/I91/I93/I96's guarantees, I100/I105/I111's drapes and I113's
   shatter.

## Steps

1. GameController: new `_place_terrain` + `_grow_unit`, `_unit_heights`, `_terrain_ways`,
   `_terrain_balance`, `_terrain_open`, `_seed_score`, two-way `_terrain_sight`, `_terrain_ease`,
   `_terrain_trees`; delete the shape/partner/anchor/flush/rotate/heights/fits machinery and the old
   reach floods. `_terrain_go(sort, cells, heights)` takes the heights instead of drawing them.
2. BuildingPlace.place_decorations takes an optional Terrain: decorations stand on the drape surface,
   boulders off the draw. Terrain.take_damage and die() crumble a tile's trees with the block's fall.
3. tests/terrain_test rewritten to the new invariants (band parity, both-direction sight, gap between
   units, dome hills, far-gentle rocks, trees grow and fly), every new guard watched red.
4. Suite green, dump_board and a rendered versus board, merge by push.

## Ticks

- [x] I116, D97
