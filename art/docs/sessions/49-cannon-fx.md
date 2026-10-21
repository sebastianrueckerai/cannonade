# Session 49: fire and impact effects
Sebastian, 2026-10-21: "I would like to add a particle effect or similar to the canon firing
(explosion and smoke at barrel) and hitting (plume of smoke at impact). Do a first version,
maky try different approahces and show me in game, including close uip so I can decide!", then
"You can also use other options, not only particle effects... its basically up to you how to do
it!"
Roadmap: I78, the first slice of K3's unported effects.
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
tool placed, --look/--eye frame the camera), in [rounds/49-cannon-fx/](../../game/art-direction/rounds/49-cannon-fx/):
- board 1 / 2: puffs, the muzzle and the landing close up
- board 3 / 4: smoke, the muzzle and the landing close up
- board 5 / 6: shock ring, the muzzle and the landing close up
- board 7 / 8: puffs at the default battle camera, firing and landing
- board 9: the water splash (the ai2 land map holds no water, --wet makes the target tile one)
Sebastian's pick by number decides the shipped look; until then the default is the art bible's
round puffs. A pick is one line in scripts/FX.gd, or the look's builder comes back from the
first commit's FX.gd - all three builders live there.

## Round 2: the reference looks
Sebastian rejected the round-1 boards ("absolute horse shit... 4 white balls seem to be flying
away which is crap"); only the board-6 dust ring stayed. Two references then: Kenney's CC0
particle pack (smoke, fire, muzzle, spark and dirt sprites, [assets/art/fx/](../../../assets/art/fx/)
with the license) and Godot's official 3D particles demo (the material recipe: unshaded alpha
billboards, spin, damping, scale curves, colour ramps). scripts/FX.gd rebuilds every effect as
one-shot CPUParticles3D bursts on those sprites in three looks - smoke (the demo look), fire
(fireball, dirt, dark column), soft (three slow puffs) - and keeps the ring on every landing.
FX.ENABLED stays false (3ab3d04) until the pick; tools/screenshot.gd --fxstyle turns one look
on for a render and --muzzlecam frames the firing gun's muzzle in profile. The smoke look's
landing carries no sparks (streak sprites read as electric arcs there, so it lands as flash,
dust, smoke and ring) and the water splash is falling droplets, a fast column and a low crown,
not floating puffs. Sebastian read the fire board's flash as coming out of the cannon's back:
the Kenney muzzle sprites carry their glow low in the frame (muzzle_05's content centroid sat
20% below the quad centre), so the flash core rendered below the muzzle anchor and, being
centred on it, wrapped the barrel. Every sprite is now content-centred in its quad (which also
stops the spin wobble), and all three muzzle flashes sit forward along the aim and smaller
(smoke +0.16 m and 0.34 to 0.5 m, fire +0.2 m and 0.42 to 0.58 m, soft +0.16 m and 0.22 to
0.32 m); boards 10, 12, 14, 16 and 17 re-shot. The flash cores measure at or above the muzzle
anchor in all of them (board 12's was 60 px below it before), checked by anchor diffs, a
flash-only diagnostic render and a vision pass. [fx_check.tscn](../../../tools/fx_check.tscn)
is Sebastian's own check for the same question: opening it shows the baked copy of the catalog's build
([fx_check_cannon.tscn](../../../tools/fx_check_cannon.tscn), regenerated by --bake after a model or anchor
change), the real art-model cannon aimed at the target with the ProjectileSpawn anchor marked by a green sphere
and the flash centre by a yellow one, so the origin reads in the editor without playing. Playing rebuilds the
cannon through the game's own path (the editor cannot: the autoloads are placeholders there) and fires the muzzle
effect in a loop, one look per shot, printing style, barrel angle, anchor and flash centre in world and screen
coordinates; any drag orbits the camera around the anchor and the wheel zooms. Every board was
checked before it went to Sebastian: each frame diffs against an effects-off render of the
same seed, so the effect sits on the muzzle and impact points the tool prints, and a vision
pass read each frame for texture and placement first. Boards 10 to 18 in
[rounds/49-cannon-fx/](../../game/art-direction/rounds/49-cannon-fx/): 10/11 smoke, the muzzle
and the landing close up; 12/13 fire; 14/15 soft; 16/17 smoke at the battle camera, firing and
landing; 18 the water splash (--wet makes the target tile water). The pick by number names the
look; FX.ENABLED = true and FX.style land it in one commit.
