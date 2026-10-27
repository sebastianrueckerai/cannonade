# Round 16: the era ladder, comments

**Rejected as a whole.** Sebastian, 12 October: the round is worthless, and phase F starts again with better inputs about what he wants and needs. The sheets look like low-poly renders instead of paintings (D30). The four guns came from the plan's tiers, not from his needs. His rules from the comments below stand, see D28 and D29.

His inputs for the restart:

- **Guns.** Sketches of cannons. No wheels, turnable, dark iron, wood on the smaller models. No multiple barrels, no mortars. Standard artillery-style cannons. Each one visibly better and more advanced than the last, not the same model upsized. Cozy, in the style of the reference images.
- **Resources.** Blocks, so they are easy to see and visibly drop into square fields. They also need to stack. Hence the box shape.

Phase F. A comment round, no pick of the metaphor (D17). The ladder in words is [tiers.md](tiers.md). Every footprint is a square of 1, 2 or 3 tiles, as `size` in [BuildingDef.gd](/home/womb/repos/cannonade/scripts/data/BuildingDef.gd) defines it, so the ladder has one gun per size.

The current sheet is [ladder-sizes.png](ladder-sizes.png): the 1x1, 2x2 and 3x3 gun at about 1 : 2 : 3, and the four resource blocks Sebastian chose.

## The sheets, in order

1. [picks-sheet.jpg](picks-sheet.jpg), 1 and 2: the first ladder from bronze to iron, with platforms and wheels.
2. [picks-sheet-2.jpg](picks-sheet-2.jpg), 3 to 5: every gun in iron, on turning mounts. Tier 1 kept wheels in all three.
3. [picks-sheet-3.jpg](picks-sheet-3.jpg), 6 to 8: edits with every wheel removed and the boxes of sheet 4. [wheels-check.png](wheels-check.png) shows the cannon rows at 1.4x: no wheels.
4. [picks-sheet-4.jpg](picks-sheet-4.jpg), 9 and 10: an edit of 6 asked the 3x3 mounts to grow to three tiles. It changed nothing.
5. [picks-sheet-5.jpg](picks-sheet-5.jpg), 11 to 13: sheet 7 with a new second gun, and the loose pot and ring removed from the last gun. [tiers-12-13.png](tiers-12-13.png) compares the mortar and the open cradle.
6. 14: wooden cradles on the first two guns of 13, pasted into 13 through [masks-cradles.png](masks-cradles.png) (`mask.py box` at 0.04,0.10,0.48,0.60, `mask.py paste --feather 6`), giving [ladder-final.png](ladder-final.png).
7. 15 and 16, [round-6.json](round-6.json): a round shield on the third gun, and a half shield with a visor slit on the second.
8. 17 and 18, [round-7.json](round-7.json): the sheet repainted over a Blender block-out, [blockout.png](blockout.png) from [blockout.py](blockout.py), with the mounts at exactly 1, 2 and 3 tiles. The model kept neither the layout nor the sizes: the 3x3 mounts came out about 2.3 and 2.5 tiles wide.
9. 19: 17 with the box row rebuilt to the four chosen blocks. The iron came out as ingots in a crate.
10. [ladder-sizes.png](ladder-sizes.png), from 19 by [resize.py](resize.py), no model call: the two small guns scaled to 0.86, the 3x3 to 1.16, and the bare iron stack of sheet 8 pasted over the crate. [ladder-sizes.json](ladder-sizes.json) records the steps.

[resources.png](resources.png) shows the candidate blocks Sebastian chose from, cut from their sheets.

## Sebastian's comments, 12 October

- **One colour.** Every cannon is dark iron grey. Gold for the low tiers and iron for the high ones confuses the eye.
- **No platform.** The cannon is the attraction, so no platform wastes space around it.
- **No wheels.** A cannon only turns, it never drives.
- **The resources.** They are boxy, fill most of a tile, and are all the same box size.
- **Footprints.** He asked to check the dimensions in code. All footprints are squares of whole tiles.
- **Wheels on the third sheet.** "Much better, some still have wheels." Those were sheets 1 to 5. 6 to 8 have none.
- **Sheet 7.** It looks good, but its second and third guns are different sizes of the same gun.
- **No twin barrels for now.** That rules out 11.
- **No mortars.** Mortars come later as sidegrades. That rules out 12, so the 2x2 gun is the long gun in an open cradle of 13.
- **Wood on the small guns.** The smaller guns may use some wood, which iron replaces on the bigger ones.
- **Shields.** A round shield is a good variation. A smaller half shield could suit the smaller gun, maybe with a visor slit.
- **Four guns, two of them the same size.** The game has three gun sizes, and the second and third guns of [ladder-final.png](ladder-final.png) looked like 2x2. A sketch needs no exact sizes, but guns of different classes must not look the same size.
- **The blocks, final.** The crate with log ends, the stacked stone blocks, the bare iron stack with no wooden box, and the open crate with one big cog. One of each: no second stone and no second wood. Decision D29.
- **The iron block's shape.** Two layers of three ingots, the upper layer turned 90 degrees across the lower, then the stepped pyramid on top: a box with a triangle on top, not a triangle. The stack on [ladder-sizes.png](ladder-sizes.png) still shows a gap between its layers. Its edit failed: fal answered `403 User is locked. Reason: TOP_UP`, so the redraw waits for a top-up.
- **Paintings, not renders.** The sheets are sketches for the later 3D, so they are painterly. Every sheet of this round looks like crappy low-poly 3D instead. Decision D30: the ladder and the blocks are repainted as a painted sketch sheet.

## What the current sheet shows

The ladder follows Sebastian's rules above, recorded as decision D28: one gun per size, 1x1 the short gun in a wooden cradle, 2x2 the long gun in a wooden open cradle with the half shield and its visor slit, 3x3 the iron gun with the round shield. The gun designs are the proposal for his comment, phase F has no pick. The four blocks are his pick, decision D29.

## Open

- **The boiler gun.** The long gun with recoil cylinders and a boiler, the last gun of [ladder-final.png](ladder-final.png), has no size of its own now. It stays a candidate for a 3x3 variant.
- **The footprint fill.** The sheet shows rough sizes only. The 3D build sets each mount from its footprint.
