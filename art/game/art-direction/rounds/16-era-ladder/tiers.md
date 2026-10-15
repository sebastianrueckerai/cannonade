# The era ladder, in words first

Phase F. The game merges upgrade blocks in 2 by 2 and 3 by 3 patterns into bigger guns (D16, D17). Every footprint is a square: `size` in [BuildingDef.gd](/home/womb/repos/grid-cannons/scripts/data/BuildingDef.gd) is the side length in whole tiles, 1, 2 or 3. The data has three gun sizes: `cannon` on one tile, `cannon22a` to `cannon22d` on 2 by 2, `cannon33a` to `cannon33c` on 3 by 3. `flak22`, `shield22` and `supply22` share the 2 by 2 size, `rocket_station` the 3 by 3. So the ladder has three steps, one per size, and each step gets an era. Every step stays inside the River Towns level, the chamfer rule of chapter 3, and the 600-tri budget per building.

The sheet is [ladder-sizes.png](ladder-sizes.png). It shows rough sizes only. The 3D build sets each mount from its footprint.

## Sebastian's rules, 12 October (D28)

- **One main colour.** Every cannon is dark iron grey, iron #33302e. A ladder that starts in bronze and ends in iron confuses the eye.
- **The cannon is the attraction.** No platform around it. The gun fills its footprint.
- **No wheels.** A cannon only turns and never drives. It sits on a round turning mount.
- **Sizes read.** Guns of different sizes never look the same size.
- **Wood on the small guns.** The 1x1 and 2x2 guns may use wooden cradles. From 3x3, iron replaces the wood.
- **No twin barrels for now. No mortars in the ladder.** Mortars come later as sidegrades.
- **Shields as variation.** A round shield suits the big gun. A small half shield with a visor slit suits the smaller one.

At the default view a tile is 24.7 px wide. A step reads from its footprint, from the size and length of its barrel, and from its mount.

## Step 1: 1x1, medieval and age of sail

- **Buildings.** `cannon`. The gun fills the tile.
- **Form.** A short thick iron barrel in a wooden cradle on a round riveted iron turning mount.
- **Accents.** The wooden cradle, wood #7a4a2e.
- **Detail cap.** The River Towns level: mount, cradle, barrel, two bands on the barrel.

## Step 2: 2x2, bigger guns

- **Buildings.** `cannon22a` to `cannon22d`, and the look for `flak22`.
- **Form.** One long iron gun, much longer than step 1's, in an open wooden cradle with two tall side cheeks, on a wide riveted iron ring. A low curved half shield of riveted iron with one visor slit stands in front of the cradle.
- **Accents.** Wood and rivets.
- **Detail cap.** The picked level plus two parts, the cheeks and the half shield.

## Step 3: 3x3, iron and early industry

- **Buildings.** `cannon33a` to `cannon33c`, and the look for `rocket_station`.
- **Form.** A large cast iron gun on a riveted iron turntable, with one round riveted iron shield, the barrel through its centre, turning with the gun.
- **Accents.** Rivets, no wood.
- **Detail cap.** The picked level plus three parts: the shield, the turntable and the cheeks.
- **Variant candidate.** The long gun with two recoil cylinders, brass bands and a small boiler with a chimney, last on [ladder-final.png](ladder-final.png). It has no size of its own and stays a candidate for a 3x3 variant.

## The resource blocks (D29)

`upgrade_a` and `upgrade_b` are the resources the game gives. Each is one tile, and they stack into the 2 by 2 and 3 by 3 patterns. Every block is a box of the same size, filling most of its tile, about 0.8 by 0.8 by 0.6 m with the chamfer of chapter 3. Sebastian chose one block per material:

| block | the box | reads at 13 px by |
|---|---|---|
| timber | a crate with log ends at its corners | brown, light dots at the corners |
| stone | stacked cream stone blocks | cream |
| iron | dark iron ingots, no box: two layers of three, the upper layer turned 90 degrees, a solid box, with a stepped pyramid on top | dark grey |
| gears | an open wooden crate with one big iron cog inside | brown, one round light mark |

Sebastian: the game has three resources today, so one block is a reserve. Which block maps to which resource is picked with the upgrade tree v1, roadmap B18 (D17).

## Open points

- **Brass.** The palette has no brass. Only the boiler gun variant uses it.
- **The pattern.** Whether the blocks of a pattern stay visible inside the merged gun, or vanish when the gun is built.
