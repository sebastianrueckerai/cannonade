# Session 50: the round's end clears the sky
Sebastian, 2026-10-21: "Make sure all bullets are deleted at the end of the round. Currently they can hit
in the next build round."
Roadmap: I79, a bug in I67's three-phase round.
## The bug
The battle's clock runs a second past its end before the flip (`_update_round_time` in
[GameController.gd](../../../scripts/components/GameController.gd)), and a projectile is its own node:
`fly_and_check_progress` lands it whenever its own `flyTime` is up, never asking the phase. A shell fired in
the battle's last seconds therefore survived the flip to walls and fell on the next build round's ground,
walls included.
## The fix
One funnel: every round end runs through `GameController.next_phase`. On leaving the battle it now shoots
down every entry of `U.projectiles` — the registry each TileImpactor enters at `_enter_tree`, so shells, the
cluster's submunitions and the rocket are all covered — through the same `shoot_down()` the Flak
interception uses. Player guns fire in the battle alone — the AI acts there only, the human has nothing to
fire with — but the neutral ships shell in any phase, so the sky may refill with theirs after the flip: what
the flip owes is that nothing airborne at it survives.
## The check
[phase_test.gd](../../../tests/phase_test.gd), at the battle's start where the test already fires at the
enemy castle: the shells in flight are snapshotted, `game.next_phase()` — the clock's flip — leaves none of
them alive and the next round opens on its banner. Watched red on the old code, green after.
