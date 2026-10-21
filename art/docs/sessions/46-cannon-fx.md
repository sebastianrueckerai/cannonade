# Session 44: fire and impact effects
Sebastian, 2026-10-21: "I would like to add a particle effect or similar to the canon firing
(explosion and smoke at barrel) and hitting (plume of smoke at impact). Do a first version,
maky try different approahces and show me in game, including close uip so I can decide!", then
"You can also use other options, not only particle effects... its basically up to you how to do
it!"
Roadmap: I74, the first slice of K3's unported effects.
## The hooks
Two, and only two: Shooter.try_shoot spawns the muzzle effect at the barrel spawn node, aimed
along the ballistic launch direction; TileImpactor.impact spawns the landing effect for every
hit - bare ground, structure or water - scaled by the shell's damage, before the projectile
destroys itself. Every gun that fires (basic, fused, ship) and every projectile that lands
(shell, heavy shell, cluster, rocket) goes through those two funnels, so one hook each covers
the game.
## The looks
scripts/FX.gd builds all three in code, no assets, randomness only from Art._rng so no game
random moves:
- puffs - the art bible's fairground: round chunky spheres that pop in, drift and pop away;
  a bright flash ball at the muzzle, a dust ring and a rising column at the hit, white foam
  and falling drops on water.
- smoke - CPUParticles3D one-shot bursts with a radial gradient billboard, an additive flash
  burst plus grey drift at the muzzle, a ground burst plus a rising plume at the hit, a
  falling white spray on water.
- shock - materials/fx_ring.gdshader: an expanding additive ring on the ground plus a soft
  billboard flash, a few dust puffs for depth.
`FX.style` picks the shipped one; tools/screenshot.gd --fxstyle switches it for the boards and
loses the switch when the pick is made.
## The tool
tools/screenshot.gd --fire=x,z: at the first --at time the first gun that reaches the tile
fires through the real try_shoot, the tool schedules the muzzle capture (+0.12 s) and the
impact capture (flyTime + 0.3 s) itself and prints the times, --firegun re-aims the camera to
the firing gun for the close-ups.
## The checks
tests/weapons.gd, after the ground section, a fresh cannon from the bare-ground section firing
through the real path: firing pops a muzzle effect, the landing raises a plume on bare ground,
a forced-water tile (the ships check's precedent) raises a splash, and both clean themselves
up. Watched red on the old code by neutralizing each hook and the self-free timer.
## The boards
All shots came from tools/screenshot.gd --fire on the ai2 map (the firing gun is a cannon the
tool placed, --look/--eye frame the camera), in [rounds/46-cannon-fx/](../../game/art-direction/rounds/46-cannon-fx/):
- board 1 / 2: puffs, the muzzle and the landing close up
- board 3 / 4: smoke, the muzzle and the landing close up
- board 5 / 6: shock ring, the muzzle and the landing close up
- board 7 / 8: puffs at the default battle camera, firing and landing
- board 9: the water splash (the ai2 land map holds no water, --wet makes the target tile one)
Sebastian's pick by number decides the shipped look; until then the default is the art bible's
round puffs. A pick is one line in scripts/FX.gd, or the look's builder comes back from the
first commit's FX.gd - all three builders live there.
