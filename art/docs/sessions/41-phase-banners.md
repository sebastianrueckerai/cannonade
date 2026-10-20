# Session 41: a banner counts each phase in, and the left mouse does everything

Sebastian, 2026-10-21, with a screenshot of the cannon phase: "Look at the image when placing cannons, sometimes it
places just the grey tiles. Also, I changed to two building rounds: First walls, then cannons. They need a small pop
up anouncing them with a 3 sec countdown and a sound when they start. Same for the shhot round. NMow that we split
it, make placing of everything and shooting happen with LMB."

Roadmap: I70. Decision: D87.

## The grey tiles

The dark squares are gun plates left behind, I68, the work of the session in the plate-fix worktree (plan 39), which
was merging master when this session started. Reproduced here on master 1340cdc (versus, seed 7, the cursor over
three tiles, then a click): the gun at (-3.5, 0, 12.5), its plate at (0, 0.1, 0), top level. A plate freezes one
frame after the gun enters the tree; `U.set_parent` moves the gun by remove and add, and the plate keeps its frozen
world spot, so it stays where the gun was when it was dealt: the hand at the origin, or the tile under the cursor at
that moment. With plate-fix's [ArtPlate.gd](/home/womb/repos/grid-cannons/scripts/ArtPlate.gd) copied in, the plate
lay at (-3.5, 0.11, 12.5) under the gun. That session landed it on master (5a3476d) while this one ran; merged here,
its plate check in `tests/preview_test` places the gun with the left click now.

## Calls made here

- **The banner.** `GameController.readyDuration`, 3 s (`ready` in the mode config and on the command line), counts
  every phase in, the game's first wall phase too: a parchment plaque in the window's centre names the phase in its
  colour over the seconds left in accent red. Nobody acts while it shows, the AI neither, and the phase clock
  stands; the held piece still previews. When it runs out the phase's call blows and its music starts
  (`GameController._begin`).
- **The calls.** horn_build is the harbour bell (`fill-horn-build-a--eleven`), horn_guns the boatswain's whistle
  (`fill-horn-build-b--eleven`), both from the round 37 page, made with `audio.py final`, unheard and kept out of
  `picks.json`: for Sebastian's ear, not picks. horn_battle stays. horn_guns no longer borrows the battle horn.
- **One button.** `act`, the left mouse, replaces build_wall, build_building and fire: it places or stacks the wall
  piece in the wall phase, places or fuses the cannon in the cannon phase, fires in the battle, and off the board
  drops what the hand holds. The remap panel has one row for it. Space and the right mouse do nothing now. A saved
  remap of the old actions is ignored, since the panel loads only its own rows.
- **The plaques let the mouse through.** The banner sits over the board's middle, and as a PanelContainer it took
  the wheel and the middle drag there (camera_test went red). Every HUD plaque now ignores the mouse.
- **The F5 toast sat in the top left corner.** `set_anchors_preset` kept its position at (0, 0); the toast and the
  banner use `set_anchors_and_offsets_preset` and sit in the centre.
- **Tests and the sandbox run without the banner** (`ready` 0) where they test something else; the sims, the
  practice, sound and phase tests run with it.

## Tests

- `tests/phase_test` (new): the banner opens the game on BUILD WALLS 3, sits in the window's centre, small, off
  the other plaques, lets a middle drag through to the camera, counts 2; under it a left click places nothing, the AI places nothing
  and the clock stands; then horn_build, the clock runs, a left click places the piece, the AI builds. The cannon
  phase and the battle the same with PLACE CANNONS and BATTLE: no cannon placed and no shot under the banner, then
  horn_guns and a cannon placed by a left click, horn_battle with the battle music and a shot by a left click.
- `tests/sound_test`: each horn waits for its banner, the battle music too.
- `tests/catalog_test`: the F5 toast sits in the window's centre.
- `tests/human`, `tests/menu_test`, `tests/practice_test`: the one button (the remap rows act, rotate_cw,
  rotate_ccw; the practice battle fires by a left click).

**Watched red** (each broken on purpose on a copy of the tree, the test red, then restored):

- the players act under the banner: `phase_test`, "a left click under the banner places nothing", "the AI places
  nothing under the banner", no cannon, no shot
- the phase clock runs under the banner: `phase_test`, the clock stands, three phases
- the horn at the phase change, as before: `phase_test` and `sound_test`, "the cannon phase holds its horn while the
  banner counts", the battle's horn and music
- no banner at the game start: `phase_test`, "the game opens on the banner: BUILD WALLS, 3"
- the banner never shown: `phase_test`, all three phases
- the seconds standing at 3: `phase_test`, "the banner counts down: 2"
- the banner and the toast anchored with `set_anchors_preset`: `phase_test` (the banner at (-93, -48)) and
  `catalog_test` (the toast at (-98.5, -15.5))
- the plaques taking the mouse: `phase_test`, "a middle drag that starts on the banner pans the board under it", and
  `camera_test`; a wheel check passed there, since Godot passes the wheel through a plaque that stops the mouse, so
  the test drags instead
- the wall piece, the cannon or the shot on another button: `phase_test`, `human`, `preview_test` (the cannon),
  `sandbox_test` and `practice_test` (the shot)
