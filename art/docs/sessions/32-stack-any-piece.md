# Session 32: every piece stacks, and nobody builds inside another player's ring

Sebastian, 2026-10-20, after session 28: "Hm, seems like stacking is still borken! Also, thje ai
can seemingly build anywhere... It shopuld be limited by the same ruels as the human player!"

Roadmap: I58, I59. Decision: D82.

## What the measurements showed

- **Stacking:** a single block stacked in the real game. Through the loading screen at the
  default camera, all 16 start-ring walls took a storey. Longer pieces never stacked, by D75.
  Asked with both options, Sebastian picked "Every piece stacks".
- **The AI and reach:** in 120 s of ai2, all 193 AI placements lay within two tiles of its walls or
  held castles. It looks unlimited because it acts every 0.5 s and lays stepping-stone pieces
  toward far castles, so it rings every neutral castle in the first build phase.
- **Inside the human's walls:** Sebastian answered "It once places walls inside my walls". The
  reach rule allowed that to both sides. The probe counted AI placements on ground another
  player's ring had closed in the frame before.

| game | placements inside the other's ring |
|------|-----------------------------------|
| ai2, seeds 1 to 4, 200 s each | 0 |
| versus with the stand-in builder, seed 1, 200 s | 1 |
| versus with the stand-in builder, seed 2, 200 s | 6 |

With the new rule both versus games showed 0.

## Change

- [PlayerController.gd](/home/womb/repos/grid-cannons/scripts/components/PlayerController.gd):
  `can_stack_on` takes the whole held piece, every cell on an own wall with no storey.
  `stack_wall` stacks a block on each cell's wall. `next_wall_to_wall` shows a darkened storey on
  each cell, square to the map, its walkway following that tile's neighbours.
- `enemy_ground` is ground whose ring owner is another player. `can_place_piece` refuses a cell
  there, and a gun is refused there too.
- [Wall.gd](/home/womb/repos/grid-cannons/scripts/components/Wall.gd): `paint_piece` turns each cell
  back with its piece, after a storey ghost stood square to the map.
- [RingPlan.gd](/home/womb/repos/grid-cannons/scripts/RingPlan.gd): enemy ground cannot carry an AI
  ring, so the AI never plans a ring it may not build.
- The AI still stacks single blocks only, and its pace and stepping stones stay as I56 made them.
- The menu's control label, the in-game help line, the README and the rules v3 draft say that a
  piece stacks.

## Tests

- [tests/human.gd](/home/womb/repos/grid-cannons/tests/human.gd): a level three across one wall does
  not stack. A turned three over three own walls shows a darkened storey on each cell, turns back
  to blocks off the walls, and stacks three storeys where their ghosts stood. A 1 x 1 enemy ring in
  the player's reach refuses a block and a gun inside it, and the block places once the ring is gone.
- [tests/ai_test.gd](/home/womb/repos/grid-cannons/tests/ai_test.gd): with the tile on a free
  castle's ring walled in by the human, the AI's ring for that castle goes round it.
- [tests/sim.gd](/home/womb/repos/grid-cannons/tests/sim.gd): frame by frame, every AI piece and
  gun has a tile within reach of the AI's anchors and none on ground another player's ring
  closed, both derived in the test from the board of the frame before.

Broken on purpose, each check went red: the single-block rule back, a stack on the anchor
only, the ghost turned with the piece, the cells not turned back, the enemy rule out of
`can_place_piece`, out of the gun check, out of `RingPlan`, and out of both `can_place_piece`
and `RingPlan` for the sim (the AI then built at (7, 11) inside the human's ring).

## Verification

- Suite green, 19 entries.
- [32-stack.jpg](32-stack.jpg): a turned three over the east side of the start ring, the three
  storey ghosts, then the three placed storeys.
