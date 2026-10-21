# Session 51: rapid cannon placing, rotate on Space / RMB
Sebastian, 2026-10-22: "it seems like quickly placing cannons sometimes does not work right if I click a lot.
check if there is a bug. Rapid building should be possible. Also, rotating walls in build mode should be
space OR RMB."
Roadmap: I80 and I81, game code.
## The bug (I80)
Reproduced headless with real input events, versus seed 7, gun in hand: four clicks a tenth of a second
apart, each on its own free in-reach tile. Only the first placed — the other three printed
`gun_in_hand=false`. The cause: `build_next_building` and `combine_building` in
[PlayerController.gd](../../../scripts/components/PlayerController.gd) stamped
`secondsLastBuilding = U.time`, and `try_get_next_building` deals the next gun only when
`secondsLastBuilding + secondsBetweenBuildings < U.time` — 0.3 s of empty hand after every placement,
and a click into that window does nothing. Walls never had this: `get_next_wall` re-deals at once.
## The fix
A placement no longer stamps the clock: both `secondsLastBuilding += U.time` lines are gone, so the next
gun is dealt the very next frame, like walls. The variable now marks only a discard — FlyAndVanish sets it
when a gun is thrown away — so that wait keeps its shape: a discarded gun still leaves the hand empty for
`secondsBetweenBuildings` (0.3 s), a discarded wall for the fly-away seconds.
## The binding (I81)
Space and the right mouse button join X as defaults of `rotate_cw` in
[project.godot](../../../project.godot); Y and Z keep turning back. Rotation only acts with a wall piece in
hand, so both work in the wall phase alone, as asked. The Tutorial & Controls panel reads the InputMap
live, so its button shows "X / Space / Right mouse" untouched, and a remap still replaces the whole set.
The camera never used the right button (wheel and middle drag only), the sandbox keeps its own handling.
## The check
[human.gd](../../../tests/human.gd), real mouse and keys, seed 7: two frames after a placement the next
gun is in hand and the click right after a placement places again; Space turns the T clockwise and the
right mouse button turns it again. All four watched red on the old code, green after, suite green.
