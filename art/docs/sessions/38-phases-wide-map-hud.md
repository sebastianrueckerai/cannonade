# Session 38: three phases, the hand on the board, a wide map, a parchment HUD

Sebastian, 2026-10-20: "Get rid of the menus showing the next piece and the next gun. Make two phases: One
longer to place walls then a short one to place cannons. make the playing field wider so it has the same
dimensions as the game window. This should also give more space to arrange the castles horizontally with
maybe a bit of space between the two players domains. But there should still be random placement. Also
overhaul the ugly font color and general appearance of the text overlay elements in game, the countdown and
such!"

Roadmap: I67. Decision: D86.

## Calls made here

- **The round is walls, cannons, battle.** `GameController.Phase` {WALLS, GUNS, BATTLE}, 45 s, 15 s, 30 s
  (`walls`, `guns`, `battle` in the mode config and on the command line). Walls and stacking in WALLS only,
  guns and fusing in GUNS only, fire in BATTLE. The check runs where the build ends, at GUNS to BATTLE, as
  before. The wall piece flies away when the cannons come, the gun when the battle starts, a fresh piece is
  drawn when the walls return. The AI needs no change of its own: it holds no gun in the wall phase and no
  piece in the cannon phase. Practice: Enter steps to the next phase.
- **The hand is hidden.** One invisible `hand` node a player replaces the two corner viewports and their
  panels; `tools/previews` went with them. The held piece shows only on the board: the wall piece on a free
  tile or over own walls as before, and now the held gun on a free tile too, the tile lit red where it cannot
  go (over the parts cap included).
- **The map is 52 by 34.** `width` beside `size` in the mode config. The camera keeps its pitch and moves
  back until the board, ground to a block's top, fills the width or the height between the HUD bands, centred
  between them (`GameController.position_camera`, `hudBand` measured from the plaques by `Main._hud_band`).
  At 1280 by 720 the front row spans 94 % of the window and no tile of the board's edge lies under a plaque.
  The sandbox passes its top bar and toolbar as its band. `CameraRig` pans over both half extents.
- **Castles spread out.** The neutral anchors are shares of the map: x at 0.15, 0.35, 0.65, 0.85 of the
  width, the inner pair at 0.3 of the depth, the outer at 0.18; jitter 3 sideways and 2 deep; a castle centre
  stays 5 rows or more from the middle line, so rows 14 to 19 stay free between the two sides.
- **Range 65.** The 52 by 34 diagonal is 62; every gun still reaches every tile.
- **The HUD wears the menu's parchment.** Alegreya from `Art.theme()`, ink `#3a2e28` on parchment
  `#fbefd9` plaques with a 2 px ink border, round corners and a soft shadow (`Main._plaque`). The countdown
  and the phase word in one row at the top: BUILD WALLS in leaf green, PLACE CANNONS in wood brown, BATTLE
  in the accent red; the number turns accent red in its last five seconds. A plaque a player: the name in the
  player's colour, parts and castles in ink, parts in accent red over the cap. The phase's controls in a
  plaque at the bottom. The F5 toast is a plaque too.
- **The cannon phase's horn** borrows the battle horn 6 dB down until it has a clip (K8). The build horn has
  no clip yet either.

## Tests

- `tests/preview_test` rewritten: the hand is invisible and no viewport or icon panel exists; the wall
  previews on a free tile (darker, decorations hidden) and goes back to the hand off the board; in the gun
  phase the gun previews on the tile and the piece is gone; every drawn piece's ghost covers anchor + cells at
  every turn; the HUD plaques lie on screen without overlap and cover no tile of the board's edge, in versus
  and ai4; the front row spans 93 % of the window or more.
- `tests/check_test` 2b walks the hand through all three phases; its end case opens the enemy's ring on the
  north side, since the player's ring round a neighbouring neutral now sits flush against the west side.
- `tests/ai_test` 4 runs the wall phase (no gun placed, a neutral ringed), then the cannon phase (guns inside
  own ground), then the check; 5 breaches the side of the start ring with open ground beyond, since the AI
  may wall a neighbouring castle in with its own.
- `tests/human` sets the phase with its fixtures, `practice_test` steps Enter through the phases,
  `sound_test` checks the cannon horn by its level, `weapons` places its specials in the free middle rows,
  `sim` counts three phases, and its versus run plays 20 / 8 / 25 s so a battle happens within 60 s.

**Watched red** (each broken on purpose, the test red, then restored):

- the held gun kept in the hand over a free tile: `preview_test`, "the gun previews on the hovered tile"
- the HUD band zero: `preview_test`, "Timer covers no tile of the board's edge"
- the camera 15 % further back: `preview_test`, "the front row spans 1028 of 1280 px"
- the hand visible: `preview_test`, "player 1 keeps its hand in an invisible node of its own"
- the wall piece kept into the cannon phase: `check_test`, "the held piece flies away when the cannon phase starts"
- a gun dealt in the wall phase: `check_test`, `preview_test` and `ai_test` ("no gun is placed in the wall
  phase"); the first try passed, since `check_test` read the hand before the draw's 0.3 s cooldown, and now
  waits past it
- the cannon horn's alias removed: `sound_test`; it read the level from the alias table and crashed, and
  now expects -6 dB written out
- Enter jumping from the walls to the battle: `practice_test`, "Enter steps to the cannons"
