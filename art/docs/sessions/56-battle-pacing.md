# Session 56: battle pacing — the disarmed end, the 2 s banner, a second a cannon

Sebastian, 2026-10-22: "When both sides have no more cannons and no projectiles are in the air, the shooting
round shoult stop. The counter for a new round starting should be 1 second shorter. The time for placing
cannons should be 1 second per cannon the player can place!" Then, on the ending: "I mean, you can just wait
a second or two for the last bullet to land. A 1 or 2 second grace might be good anyways for the ending not
to be too aprupt."
Roadmap: I85, I86, I87, game code.

## What ships

Three pacing changes, all in [GameController.gd](../../../scripts/components/GameController.gd):

1. **A battle with nothing left ends** (I85). `_disarmed()`: no side holds an active cannon and no shell with
   a player is in the air. A ship's shell never holds the round — ships shell walls all battle in versus, so
   a literal "no projectiles" would almost never open. Once quiet, the battle waits `DISARM_GRACE` (2 s) for
   the last exchange to settle, then flips to the walls; anything going back up restarts the wait
   (`_quietSince`), and the flip itself shoots down anything still flying (I79).
2. **The banner counts a phase in over 2 s** (I86): `readyDuration` 3 → 2. `--ready=` and the sandbox keep
   pinning their own.
3. **A second a cannon** (I87): `gunDuration = 0` derives the gun phase at the flip — the widest parts cap on
   the table, 6 s at one castle, 10 at two, then 13, 15, 17, so the phase grows as the castles do. versus,
   ai2 and ai4 drop their pinned `guns` in [Main.gd](../../../scripts/Main.gd); single player keeps 50 s,
   practice and the sandbox stay untimed, `--guns=SECONDS` still pins (the sim-versus run pins 8).

## Where it does not open

The grace and the disarm check live in the battle of a round game alone: they sit behind the `castles` flag
that already gates the check and the game end, so the sandbox's endless battles (a Main built with
`castles: false`, and the lab through the same scene) never flip early — a lab seed replays exactly as
before. check_test 2b's 95-frame wait sits inside the banner plus the grace, noted in a comment there.

## The check

[phase_test.gd](../../../tests/phase_test.gd), real input on the versus map: every phase opens on the
banner's "2" and counts to "1"; the gun clock opens at exactly 6.0 s (one castle, 6 parts); with every cannon
un-built, the battle holds while the fired shell flies, past its landing through the grace, then flips to
the walls. [sim.gd](../../../tests/sim.gd) records every phase flip's clock and armed state and asserts each
flip is past its clock or a disarmed battle. Break-checks: the grace off, the shell clause off and the
cannon clause off each turned a new check red, the derived gun duration reverted turned the 6.0 s check red.
Suite green, 22 PASS.
