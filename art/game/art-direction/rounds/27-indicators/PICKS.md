# Round 27: battle readability, the reload and the aim

Question: how a gun shows when it can fire again, and where it aims, with as few overlays as possible and the cozy look intact. Every candidate was a real game variant, shot in a sandbox battle under the shipped soft_honey look. No provider calls, no sidecars: the boards are game screenshots composed by the scripts in this folder.

## Boards

- [reload.png](reload.png): six reload candidates on the own fort's guns, just fired, mid reload, ready. The shipped white ring above the gun, none, a hot barrel cooling to iron, the plate warming, the ring laid flat, the barrel slumping.
- [arcs.png](arcs.png): six arc candidates at the default view. The shipped wire, none, a thin tapered arc, a flat band on the ground, a ring on the target tile, round puffs.
- [base.png](base.png): Sebastian's own candidate, a ring round the gun's foot that thins over the reload and a red pulse on the plate at ready, shot straight from above and from the game camera.
- [shift.png](shift.png): that ring in the gun's iron shifted toward the owner's team colour, three strengths, both forts.
- [shipped.png](shipped.png): the picked pair as the game now plays it, no tool flags.
- [aligned-rest.png](aligned-rest.png), [aligned-aim.png](aligned-aim.png): the three guns centred on their plates, straight from above.

## Picks

- **Arcs: 3, taper.** Sebastian, 2026-10-14. Recorded as D58.
- **Reload: the base ring, A subtle, shift 0.35.** Sebastian, 2026-10-14, after "Try a ground ring, where the ring is really around the gun in question", "not bright red", "the cannon color tone shifted toward the players color", and "clearly visible but not to badly destroy the cozy atmosphere". Recorded as D57.

## Faults found on the way, all fixed

- The first reload board showed nothing: `Indicators.reload` collided with GDScript's `reload()` method, so every style match fell through. Renamed.
- The base ring was first a smear (scaled to the plate), then buried under the mount (it shrank inward), then an ellipse (scaled after the lay-flat rotation). Gate: [measure.py](measure.py), straight from above, width over height 1.00 per ring. The shipped rings measure 1.00 on all three guns.
- The guns stood off their plates, twice over. In the model the split centred the whole gun, so the barrel overhang moved the mount 5 to 24 cm off the plate. In the game the plate froze at the spawn spot before the gun was placed in its tile, 0.5 m off on the 2x2 gun. Gate: [align.py](align.py) on the model, and mount minus plate in the placed battle layout, 0.000 on all three guns.
- A deferred call in the cooldown script failed the sandbox test whenever the sandbox stripped a node's script. The call did nothing and was deleted.
