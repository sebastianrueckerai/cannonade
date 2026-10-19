# Session 19: Sebastian's playtest fixes

He played the rules-v3 build and sent six reports (2026-10-19). Everything lands in one commit, each rule guarded by a test that was broken on purpose and watched fail.

## What he asked, what it was

1. Local master must always be current. Done first, as a rule change: a push refusal for uncommitted noise in the main checkout scraps the differing files and pushes instead of stopping (the CLAUDE.md workflow section, commit f4949bd).
2. "Get rid of cannon range": `max_range` 50 on cannon and rocket, the whole map (CannonBehaviour.gd, RocketBehaviour.gd).
3. "Tutorial and control menu is broken": the overlay scaled itself into a bottom-slammed panel. It now scrolls: a full-rect ScrollContainer centres the panel when the window fits it and scrolls when it does not. `_scale_to_fit` is gone.
4. "The expanding bar does not sit in its enclosure": the track stylebox was parchment-invisible and the fill near-cream. Both now carry explicit StyleBoxFlat overrides: dark track, cream fill inset by the track's content margin.
5. "I can still build in the firing phase": the hand now follows the phase. `next_phase` drops held pieces when the battle starts and draws a wall when building returns; the FlyAndVanish redraw and `try_get_next_building` respect `buildingAllowed`.
6. "Castles switch from white to a player colour, and uncaptured castles should be brown": no texture fight. The switch is the claim at work, the D73 roof-and-banner paint on surface 0. Against a near-white body it reads as colours fighting, so the neutral is now brown `#9c7a4f`. Same message: "a wall behind a castle blocks the view" led to the fade: while a piece is held, any castle between the camera and the cursor turns 35 % see-through and solid again once it stops blocking (`Castle.bounds`, `U.set_alpha`, `PlayerController._fade_blocking_castles`).

## Tests

`menu_test` guards the scroll area; `check_test` gains 2b (the hand follows the phase) and 2c (brown neutral, fade out behind a castle, solid again on a clear ray). Broken on purpose: the wall drop, the FlyAndVanish redraw gate, the fade set, the restore set, the brown constant.

## Result

One commit on master, pushed to origin. Cannon range 50 is a stopgap for tuning, not a design number; the real range question waits for lab time.
