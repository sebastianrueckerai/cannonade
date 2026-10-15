# Round 10 notes

Sebastian on round 09: fix the issues he raises, point by point, and never show an image with an unfixed issue. F still had the misaligned grid and the only text. No cannon fired in any image. C had one intact and one broken cannon. A and B still had cannons on the walls and towers of the smaller castle. Later: the castles and their keeps were near copies of each other, the same tower with the same building on the same side.

Why the faults got through: the far castles were checked at a size where a wall walk and a courtyard floor look alike, the firing step of round 08 was dropped when round 09 split the scene from the shot, and F was put on the sheet as a comparison although it had known faults. The fix is the [checklist](checklist.md), every line checked in a crop, the far castle at 4x, and only passing images on the sheet.

## What was done

1. A and B of round 09, one edit each through nano-banana, [round.json](round.json): the far castle's wall and tower cannons moved to the courtyard floor, the near castle's front cannon fired. Both shots passed in the crop. Both far castles still kept the near castle's design.
2. The far castle replaced by a clearly different one through nano-banana, [round-far.json](round-far.json): a tall round crenellated keep, round corner towers, a long hall, the gate at the right. Checked at 4x, [far-AB.png](far-AB.png): B passed, its two cannons on the floor behind the front battlements. A failed, one cannon on the round corner tower.
3. A's tower cannon removed with `fal-ai/flux-lora/inpainting` at strength 0.8 on a paint-over through a mask, [far-A-final.png](far-A-final.png): a clean removal.
4. The grid against the walls, [grid-AB.png](grid-AB.png): B's walls run with the grid lines. A's near castle front wall runs at about 27 degrees and the grid beside it at about 13. A fails line 10 and is not shown.

## Not shown, and why

| image | failing lines |
|---|---|
| A, round 10 | 10: the grid not parallel to the near castle; 8: the far castle has one cannon after the removal |
| round 09 C | 5 and 6: a cannon on the wall, a barrel on two carriages; 3: no shot |
| round 09 D | 3, 9: one near cannon, no shot |
| round 09 E | 3, 9: one near cannon, no shot |
| round 09 F | 10: the grid; 13: text; 3: no shot |

## Lessons

- The far castle decides the checks: it is a quarter of the size of the near one and hides every wall-mounted cannon at 2x. 4x is the floor.
- A rule from an earlier round has to be in every later prompt; the shot was lost between rounds 08 and 09 because the split into two steps was not carried.
- Replacing a whole building through a mask works where moving one small object does not: the redesigned far castle came out right in one of two, the removal of one cannon was clean.
