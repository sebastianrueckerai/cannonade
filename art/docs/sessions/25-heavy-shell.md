# Session 25: the heavy shell

Sebastian, 2026-10-20: "The big cannon formed from 4 smaller ones needs a bigger cannon ball (maybe not a round one but a bullet shaped one - easily doable in blender, no generatiuo needed) and it needs to do more damage. Do the numbers and make a guess about what a fair number might be". Roadmap: I50, C16, J13. Decision: D77.

## The number: 40

The heavy cannon `cannon22a` deals 40 per shot, four times the cannon's 10, at the same 2 s reload. Four cannons fuse into it and it costs their four parts, so 40 gives it the damage of the four cannons it replaces. Before, it fired the cannon's ball for 10, a quarter of what the same four parts dealt as cannons.

## Shots to kill

A target dies when its health reaches 0, and damage does not carry over to the next target. This table shows how many shots each target takes.

| target | health | cannon shells at 10 | heavy shells at 40 | heavy shells at 60 |
|---|---|---|---|---|
| wall block | 10 | 1 | 1 | 1 |
| cannon | 40 | 4 | 1 | 1 |
| heavy cannon | 80 | 8 | 2 | 2 |
| castle | 120 | 12 | 3 | 2 |

Four cannons fire 4 shells per 2 s, the heavy fires one. At 40 the heavy equals the four cannons against guns and castles. Against walls it opens one tile per shot, where the four cannons open four. It also has 80 health in one gun, where the four cannons have 160 across four guns.

Values between the health steps change nothing. 41 to 59 play as 40, and 61 to 79 play as 60. The real choices are 40, 60, 80 and 120.

## Lab

The scenario [heavy_vs_cannons](/home/womb/repos/grid-cannons/data/scenarios/heavy_vs_cannons.tres) rings both castles as [mirror_forts](/home/womb/repos/grid-cannons/data/scenarios/mirror_forts.tres) does. Blue holds four cannons, spread out so they do not fuse. Red holds one heavy cannon. Every seed plays twice, the second time with the layouts swapped. The AI acts every 0.5 s (D76).

In the gun duel, the AI shoots guns first, then castles (`--targets=auto,auto`, 10 seeds). This table shows who wins the duel at each damage.

| heavy damage | four cannons win % | heavy wins % | draw % | cannons lost |
|---|---|---|---|---|
| 10 | 100 | 0 | 0 | 0.1 |
| 20 | 100 | 0 | 0 | 1.4 |
| 30 | 100 | 0 | 0 | 1.4 |
| 40 | 60 | 0 | 40 | 3.4 |
| 60 | 60 | 0 | 40 | 3.4 |
| 80 | 60 | 0 | 40 | 3.4 |

From 40 up, damage changes nothing in the duel. Each heavy shell already kills a cannon, and the four cannons put 8 shells into the heavy before it fires a sixth shot. A draw means both sides lost every gun.

In the castle race, both sides shoot only the enemy castle (`--targets=castles,castles`, 5 seeds). This table shows who ruins the other castle first.

| heavy damage | four cannons win % | heavy wins % | battle s | cannon hits on the castle at the end |
|---|---|---|---|---|
| 10 | 100 | 0 | 12.2 | 12 |
| 30 | 100 | 0 | 12.2 | 12 |
| 40 | 0 | 100 | 10.4 | 8 |
| 60 | 0 | 100 | 8.4 | 5 |
| 80 | 0 | 100 | 8.4 | 5 |

## Why 40 and not 60

At 40 the heavy loses the gun duel and wins the castle race. Neither layout wins both, so four cannons against one heavy is a real choice. At 60 a castle falls to two heavy shells in 4 s, while the cannons land 5 of their 12 shells. The duel stays as it is at 40, so 60 only adds to what the heavy already wins. At 120 one shell ruins a castle.

The heavy stays weak against walls. The cannons open four wall tiles in the time the heavy opens one, and damage cannot change that, because any shell kills a wall. J13 holds the blast idea for that.

## What shipped

- [heavy_shell](../../game/assets/3d/heavy_shell/): a pointed iron shell with a driving band, 0.32 m wide and 0.64 m long against the 0.28 m ball, 384 triangles, built by [build.py](../../game/assets/3d/heavy_shell/build.py) with the shell's iron paint. It is synced unapproved and waits on Sebastian's pass (C16).
- [heavy_shell.tres](/home/womb/repos/grid-cannons/data/projectiles/heavy_shell.tres) and [HeavyShell.tscn](/home/womb/repos/grid-cannons/prefabs/HeavyShell.tscn). The art layer hangs a projectile's model beside the body that the flight pitches, so the ball never turned. The prefab names its body `HeavyShell`, so `Art.attach` moves the model's `heavy_shell` part under the body. The shell now pitches with its arc and rolls about its nose.
- [cannon22a.tres](/home/womb/repos/grid-cannons/data/buildings/cannon22a.tres): the projectile `heavy_shell`, damage 40.
- [shoot_battle.gd](/home/womb/repos/grid-cannons/tools/shoot_battle.gd): its forts asked for the parked `base` and upgrade blocks, and without castles the sandbox ended the battle at once. The forts now hold a castle.
- The tutorial, the README and section 4 of [rules-v3-draft.md](../../game/design/rules-v3-draft.md) give the heavy shell's damage.

## Tests

[tests/weapons.gd](/home/womb/repos/grid-cannons/tests/weapons.gd) fires the fused gun once at a cannon. It checks that the shell's model rides on the flying body, that the nose climbs while the shell rises and dips while it falls, that the nose points along the flight, and that the one shell destroys the cannon. Two breaks ran red. With damage 10, the kill check failed. With the shell on the old `Bullet.tscn` prefab, which leaves the model beside the body, the model check failed and the nose pointed backwards (-1.00). The suite is green, 18 entries.

## Picture

[25-heavy-shell-flight.png](25-heavy-shell-flight.png): on the left the heavy shell climbs out of the heavy cannon at 0.3 s, on the right the ball flies at 0.2 s. Both come from 1280x720 frames of `tools/shoot_battle.tscn` and are magnified 3x. The heavy shell flies higher and nearer the camera than the ball, so the size between the two crops is not to scale.
