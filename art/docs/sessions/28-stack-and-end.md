# Session 28: stacking where the player points, the end screen, testing keys

Sebastian, 2026-10-20: "Stacking walls is broken, make it work again with proper preview. Also,
win screen looks broken - fix. Check loose screen as well. For testing purposes make pressing k
win and pressing l loose the game so I can check."

Roadmap: I53, I54, I55.

## Stacking (I53)

**Root cause.** [PlayerController._pick](/home/womb/repos/grid-cannons/scripts/components/PlayerController.gd)
took the tile under the ground point of the view ray. A wall block stands 1.1 m tall, so a cursor
on its top met the ground up to half a tile behind it, more when zoomed in. Zoomed in on the
start ring with a single block in hand, the cursor on a wall's top:

| ring side | what the old pick did |
|-----------|-----------------------|
| east, west | stacked on the northern neighbour |
| north | placed the block outside the ring |
| south | picked the castle, so the click did nothing |

The stack logic itself was sound: `tests/human` stacked through the ground point and passed.

**Change.**
- `_pick` walks the view ray down from 2.5 m and stops at the first wall block it enters, up to
  `BuildingPlace.wall_top`, the storey's top on a stacked tile. Guns and castles stay
  transparent to the cursor, castles fade as before. Shells aim at the wall under the cursor too.
- The preview: over a wall it can stack on, the held block wears the look's storey where the
  placed storey will stand, darkened like every ghost, its walkway following the neighbours.
  Before, it showed a lower block lifted 0.75 m. `Wall.put_on` is now the one way a block or a
  piece cell changes art (wear, storey, spawn, piece cells), and `Wall.open_sides` the one way
  to read a block's corridors.

## End screen (I54)

**Root cause.** The win and lose art is 2752 x 1536. A TextureRect keeps its texture's size as
its minimum, so the art filled a corner of the window and pushed the title and the buttons
below it.

**Change.** The art covers the window like the menu and loading screens, VICTORY or DEFEAT
stands in its sky, Retry and Menu sit in a themed panel in the bottom right like the loading
bar, off the art's subject. Without art (watch mode, a draw) the board is dimmed as before.

## Testing keys (I55)

K wins the running game for the human, L hands it to the other player. Both end the game
through `GameController.end`, the path the rules check uses. They do nothing in watch mode or
after the end.

## Tests

[tests/human.gd](/home/womb/repos/grid-cannons/tests/human.gd), through real wheel, mouse and key events:
- Zoomed in, the cursor on the far half of an east wall's walkway picks that wall, shows the
  darkened storey, stacks there and not on the wall behind, and the storey stands where its
  ghost stood.
- The next wall shows the storey too, the block goes back to the hand as a block without
  shadows, and on free ground it is a block again.
- L shows DEFEAT, K after the end changes nothing, K in a fresh game shows VICTORY. Both times
  the art covers the window and both buttons lie inside it.

Broken on purpose, each check went red: the ground pick back (the cursor picked (19, 9), the
stack went behind), the old lifted-block preview, the piece not swapped back to a block, the
art without `EXPAND_IGNORE_SIZE` (2752 x 1536), the key handler removed, and the shadows
switched off before the art swap.

## Verification

- Suite green, 19 entries.
- [28-stack.jpg](28-stack.jpg): the same zoomed view, same seeds, cursor on the middle east
  wall. Left the old code: the ghost and the storey land on the wall behind. Right: the storey
  ghost on the wall under the cursor, and the placed storey matching it.
- [28-end.jpg](28-end.jpg): the win and lose screens at 1280 x 720, old left, new right, both
  reached through K and L.
- Not verified: a real display at other window sizes. The art covers any aspect, the panel
  is anchored to the bottom right.
