# Session 39: the grey square where four tiles meet

Sebastian, 2026-10-21: "During a game against Ai sooner or later this weird grey square appears
were 4 tiles meet. This is a bug. investigate and fix!" (screenshot: a dark square, one tile wide,
on a tile corner near the board's centre, build phase, versus).

Roadmap: I68.

## Cause

The square is a gun's iron plate, standing at the board's centre. `ArtPlate` kept the plate square
to the grid by making it top level one frame after every tree entry. On the next entry it turned top
level off first. Turning top level off inside the tree keeps the node's world transform, not its
rest pose, so the plate kept the spot it froze at.

A held gun waits in its slot, a SubViewport of its own with the gun at the origin. Its plate froze
there at (0, 0.1, 0). Placed on the board, the gun moved to its tile and the plate stayed at
(0, 0.1, 0) of the board's world: the board's centre, a corner of four tiles on the even map.
Reproduced headless (versus, seed 7): gun at (-12.5, 0, 13.5), its plate at (0, 0.1, 0). Every gun
placed from a slot, the human's or the AI's, left its plate there, all stacked as one square, and
stood on no plate. A discarded gun flew off out of its slot without its plate.

Session 38 (I67) merged during this session: the slots are gone, and a gun waits in the hand, an
invisible node of the player's, and previews on each hovered tile. The old `ArtPlate` failed there
the same way: the plate stayed on the first spot it froze at, 4.5 m and 13.5 m off the previewed gun
in the test below.

## Change

- [ArtPlate.gd](/home/womb/repos/cannonade/scripts/ArtPlate.gd): the plate stays the gun's
  child, so the scene tree carries it wherever the gun goes: from the hand onto a hovered tile, onto
  a 2x2 square's centre. It keeps its global basis from its first entry and takes back the
  gun's turn on `NOTIFICATION_TRANSFORM_CHANGED`. The engine sends that after every node's process
  and before drawing, so no drawn frame shows the plate swung (the session 11 lag came from a plate
  turned back in its own process).
- A top-level plate that follows the gun in a late `_process` was tried first: a node put back
  into the tree in the middle of a frame misses that frame's process, so the plate showed one frame
  at the old spot.
- `Cooldown._place` reads the plate's world box at the first shot, after that shot's turn and
  before the plate takes the turn back. The box only grows with the turn, and its clamp never binds
  with today's guns (mount ring 0.31 m against plate half 0.45 m on the cannon, 0.65 and 0.91 m
  against 0.95 m on the heavy guns, 0.30 m against 0.95 m on the flak), so it stays as it is.

## Tests

`tests/preview_test`, `_check_plates`, in the cannon phase: a gun that rested in the hand, previewed
on a hovered tile, then on the next, then placed with a real right click, keeps its plate at the
hand's offset under it. Aimed with `Shooter.try_aim`, the gun turns, and the plate keeps its basis
and stays under it.

**Watched red** on master after session 38:

- the old `ArtPlate`: "previewed on a tile" (plate 4.5 m and 13.5 m off the gun), "previewed on the
  next tile", "placed" and "turned to aim" red
- the turn not taken back: "the plate stays square to the grid while the gun turns" red

Before the merge the test drove the slots: there the old `ArtPlate` left the placed gun's plate
3.5 m and 5.5 m off and a discard's 2.1 m under the flying gun.

Taking out `set_notify_transform(true)` stays green: the plate is a MeshInstance3D, which sends
the notification anyway. The call stays, since the script extends Node3D.
