# Session 48: the shell trails its flight, the aim light rides the cursor
Sebastian, 2026-10-21: "The new godot has an easy way of attaching a trail ot something... I
would like a white trail following projectiles. showing their flight pass. Also, elave in the
code, but disable the current curve showing the flight path ahead of time! Also, highlight the
tile that is currently aimed at only, not every tile that a bullet is going to. I basically
want the highlight to be my aim indicator andss thats it. Its my job to correctly distribute
bullets!"
Roadmap: I77 (the trails of K3, in part).
## The trail
Every projectile leaves a white ribbon along its flight: Catalog.spawn_projectile attaches a
TrailLine ([scripts/TrailLine.gd](../../scripts/TrailLine.gd)) to each spawn, a LineRenderer
ribbon over a window of past positions rebuilt each frame, fading toward the tail. Godot 4.7's
particle trails (a trail-enabled GPUParticles3D with a RibbonTrailMesh draw pass) were built
first, but the compatibility renderer does not support particle trails, so the ribbon is drawn
the way the old aim arc was. One attach covers every kind: shells, the cluster's submunitions,
the rocket.
## The arc kept, off
The curve that predicted the flight ahead of the shot (RenderArc through Shooter.try_aim) stays
in the code, gated behind Shooter.ARC_ENABLED = false: nothing instantiates or draws it, and
switching the flag on brings it back. The shell's trail shows the path after the fact instead.
## The aim light
The light cube no longer rides in-flight shells (TileImpactor.aim_tile marks nothing now); the
human's aim is the only highlight: PlayerController puts BuildingPlace.target_on on the tile
under the cursor while the battle runs, off when the cursor leaves the map or the battle ends.
It is his aim indicator, and distributing the bullets stays his job.
## The checks
tests/weapons.gd: a fired shell carries the Trail ribbon, white, its window spanning the flight
behind the shell; both checks watched red on the broken code. tests/human.gd,
real mouse, battle: the hover lights the aimed tile and no flight path is drawn ahead of the
shot; the light leaves the last aimed tile with the cursor and sits on the new one; while a
shell flies, exactly one tile is lit, the one under the cursor. Every new check watched red on
the old code. tests/sim's marker invariant flipped with the design: no tile is ever marked now
that nobody in the sim aims. The boards: a probe run inside the project renders a mover with
and without its TrailLine under the game's compatibility renderer — the same region with the
white ribbon and without.
