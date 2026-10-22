# Session 64: rivers that cut castles off, and walls that bridge them

Sebastian, 2026-10-22: "Before placing the mountains and hills that were recently added, but after placing the
castles, I want rivers on the map. The river should divide the map in such a way, that it cuts off up to half the
castles for each player. The river should be "fair" in the sense that it cuts off the same amount of castles from
each player, counting from their starting castle. There can also be 2 rivers, cutting off a curved section in the
corner for each player. Lots of possibilities, as long as both players have access to the same amount of castles
cut off. The river should be a few pieces wide. The idea is, that placing walls in the river turns them into
aqueduct / bridge pieces. So I can bridge the river but I cant claim territory on the river. So I have to cross it
and build a room on the other side. The same wall can continue that build the bridge. The river should have at
least a tile space to any castle!"

Roadmap I104.

## The rules

- A river tile is water a wall may stand on. A wall there is a bridge: it carries the player's wall line and
  reach across, but the enclosure flood runs under it, so a bridge never seals a ring and river ground is never
  anyone's. A room on the far bank is a ring on land.
- Nothing else stands on a river: no guns, no castles, no terrain, no stacked storey on a bridge.
- The river is 3 tiles wide (a 3x3 stamp along its course); the reach of 2 cannot jump it, so crossing takes a
  bridge.
- Every river tile keeps Chebyshev distance 3 from every castle centre: one free tile between the castle's 3x3 and
  the water, the castle's build ring stays land.

## The layout

Two-player boards only (versus, ai2, practice): the fairness is between two players. A board draws one of two kinds:

- through: one river from the north edge to the south edge;
- corners: two rivers, one a side, each from that side's back edge to its west or east edge, the corner of each
  side drawn on its own, so the board is not mirrored.

Each river's course is the cheapest 8-connected path between its two edge points over a smooth noise field (rivers
follow valleys), never nearer a castle centre than 4 (so the stamp keeps 3). A drawn layout stands only when it is
fair:

- per player, the castles of their own half that the river cuts off from their start castle over land: the same
  count for both, at least 1 and at most 2 (half of a side's four neutral castles);
- per player, the castles reachable over land from the start castle: the same count for both;
- every land region holds a castle (no dead slivers).

The river draws from its own generator seeded from the map seed, so the game's random numbers stay put. The
terrain then seats around it, as before.

## Touch points

- [GameController.gd](/home/womb/repos/grid-cannons/scripts/components/GameController.gd): `_place_rivers`
  between the castles and the terrain; the terrain's ring guarantee and border reach cross the river.
- [Map.gd](/home/womb/repos/grid-cannons/scripts/components/Map.gd): a river tile (water, `river`, no
  decorations).
- [BuildingPlace.gd](/home/womb/repos/grid-cannons/scripts/components/BuildingPlace.gd): `river`, `wall_free`.
- [StatesMap.gd](/home/womb/repos/grid-cannons/scripts/StatesMap.gd): a bridge leaves its tile open.
- [PlayerController.gd](/home/womb/repos/grid-cannons/scripts/components/PlayerController.gd): pieces go on
  river tiles; no storey on a bridge.
- [Wall.gd](/home/womb/repos/grid-cannons/scripts/components/Wall.gd): a block on a river wears `wall_bridge`.
- [AI.gd](/home/womb/repos/grid-cannons/scripts/components/AI.gd): its terrain route crosses the river; its
  approach already walks straight over (Chebyshev), its rings already stay on land.
- Art: `wall_bridge`, the plain block with a through arch on both axes, from
  [wall_block.py](../../game/assets/3d/wall_block.py) style `bridge`. Synced unapproved like the terrain boxes,
  Sebastian's look pass open.
- tests/river_test: fairness per seed, clearance, width, bridges placeable and open, a room across.

## Findings

- The river draws between the castles and the terrain (`_place_rivers` in `_initialize_players`),
  from its own generator seeded `hash("river%d" % mapSeed)`, so the game's random streams (lab
  battles, seeded tests) stay put. One river through or one a side in a corner each: in the
  river test's 12-seed sweep the split is 11 through, 1 corners, so the through shape dominates.
- Fairness is generate-and-test: a Dijkstra course over a value-noise cost field (rivers follow
  valleys), stamped 3 wide, redrawn until both players lose the same 1-2 of their own half's
  castles over land and keep the same count, and every land region holds a castle. All 12 sweep
  seeds fair at the first or a later attempt inside 60.
- Every river tile keeps Chebyshev 3 from every castle centre: one free tile past the castle's
  3x3, so the castle's build ring stays land. No land reaches across within the build reach of 2,
  so crossing takes a bridge.
- The bridge is the wall: `wall_free()` admits river ground, `Wall.wear()` swaps the block to
  `wall_bridge`, and the enclosure flood ignores blocks on river tiles, so a bridge carries the
  line and the reach but never seals a ring and river ground stays nobody's - a room across is a
  ring on the far bank. No gun, no storey, no terrain on river; a shell frees the river again.
- The look: `wall_bridge` from `wall_block.py` style `bridge` (two crossing through-arches on
  four piers, 518 tris), synced unapproved like the terrain boxes - Sebastian's look pass open.
  Renders of two versus boards hold a water-coloured band along the course (pixel-checked
  against the palette's water colour); the bridge block was judged from its preview sheet.
- The older suites seated with the river: weapons' `open_patch` searches a wider window and its
  shots stay short (shooter near target, the flat arc clips no rock), walls' crumble spots and
  ownerless-block spot pick the first dry tile east in their row, terrain's ring detector
  crosses river tiles (a wall bridges) and its rock line runs through the water where the river
  crosses its row, and the AI's room window widened by 24 s: a river board spends its walls on a
  claim first (claims outrank rooms), the room itself closes about 15 s later.
- Watched red (river_test): rivers skipped (4 organic failures), the fairness gate forced open
  (unfair on 6 of 12 seeds), `wall_free()` refusing the river, the flood counting a bridge as a
  wall (the ring over the river closed).
- Renumbered I102 to I104 and this plan 63 to 64: the flat-arc session, running in parallel,
  took I102 and plan 63 on master first. Its commit cd96bf2 shipped before this branch merged.
- weapons' three failing checks were the flak, not the river: the river moved the free ground
  so the adapted `open_patch` picked a shooter two tiles from the p2 flak at (20,15), inside
  its 4-tile reach, and every shell from that gun was intercepted a frame out of the barrel.
  The interceptors are destroyed once their own checks are done, so the picks below need no
  distance rule (master's flat-arc round hit the same wall and moved its patch instead).
- Rivers resurrected a dead block in sound_test: its sea landing had never run, because a
  versus board held no water before rivers (`_set_water_areas` is single-player only), and it
  reached for a `TileImpactor` component `spawn_projectile` never makes (it adds `Projectile`,
  which extends it). Now it runs on a river tile and was fixed to what spawn_projectile
  actually returns - the component itself, a TileImpactor; watched red against the wet check
  in `TileImpactor.impact()`.
- Merge round: master had run ahead with I100 (hills/rocks drapes), I102 (flat arc) and
  I103 (gun looks), so the branch merged master in before shipping. One content conflict
  (the terrain section header in GameController.gd); weapons and terrain_test auto-merged
  with both sides standing. The first merge commit kept a `<<<<<<< HEAD` line and the suite
  caught it at the scripts check - amended at once. The bridge and the drape do not meet:
  terrain never seats on river ground (`_terrain_fits` through `is_free`), and a river tile
  counts as no terrain for `_backed`, so no shoulder hangs over the water. The river itself
  is unchanged by the merge: castles and map shape feed its carve, terrain seats around it.
