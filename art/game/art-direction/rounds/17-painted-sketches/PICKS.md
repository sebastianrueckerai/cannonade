# Round 17: painted sketches of the guns and the resource blocks

Phase F again, from Sebastian's words in [brief.md](brief.md). The style references are the painted key art, the key art of A Monster's Expedition and the My Time at Portia capsule. The world anchor was not attached. Every board passed the brief's checklist in crops before Sebastian saw it.

[picks-sheet.jpg](picks-sheet.jpg) shows the six boards.

| board | file | the idea |
|---|---|---|
| 1 | [1-shipwright-guns--nanobanana.png](1-shipwright-guns--nanobanana.png) | the shipwright's guns: a stubby gun in a wooden cradle, a long gun in an iron-banded oak cradle on an iron ring, a long iron gun on a turntable |
| 2 | [9-fortress-long--nanobanana.png](9-fortress-long--nanobanana.png) | fortress guns: a swivel gun on a wooden post, a long gun on a wooden slide carriage, a heavy coastal gun in a round iron housing |
| 3 | [3b-classic-guns--nanobanana.png](3b-classic-guns--nanobanana.png) | chunky toy proportions with classic long barrels, the big gun with a sighting telescope |
| 4 | [8-shields-nowheels--nanobanana.png](8-shields-nowheels--nanobanana.png) | the shields: a plain gun in a wooden cradle, a gun with a half shield and a visor slit, a big gun behind a round shield |
| 5 | [5-industry-cropped.png](5-industry-cropped.png) | from the age of sail to early industry, ending in a long breech-loading gun |
| 6 | [6-blocks-row-cropped.png](6-blocks-row-cropped.png) | the four resource blocks |

The round was painted from [round.json](round.json) and [round-2.json](round-2.json).

## Fixes before the sheet

- **Board 2.** The big gun of [2-fortress-guns--nanobanana.png](2-fortress-guns--nanobanana.png) had a short, wide barrel that read like a mortar. An edit gave it a long classic barrel.
- **Board 3.** The first painting, [3-chunky-guns--nanobanana.png](3-chunky-guns--nanobanana.png), had short, wide barrels that read like mortars. It was painted again with long barrels.
- **Board 4.** The small gun of [4-shields-guns--nanobanana.png](4-shields-guns--nanobanana.png) had two wooden wheels on its cradle. An edit removed them.
- **Boards 5 and 6.** Both paintings had faint ghost shapes at the top. [croptop.py](croptop.py) cut that band off.

## Left out

[7-blocks-stacked-blocks--nanobanana-b.png](7-blocks-stacked-blocks--nanobanana-b.png) showed the blocks stacked on grass tiles. It added a plain crate with no log ends and no cog, and two loose stone blocks, so it fails the brief.

## Sebastian's picks, 12 October

- **Small: board 2's small gun,** the swivel gun on a wooden post. It is very different from the next size.
- **Medium: board 4's medium gun.** A good second gun, not too long. Board 5's medium gun is a bit long.
- **Large: board 3's or board 4's,** with the round shield of board 4 removed. Most guns look good.
- **Blocks.** The iron bars were not stacked right. Each layer should turn against the one below, with bigger bars and fewer layers. The other three blocks look good.

## After the picks

- [10-large-noshield--nanobanana.png](10-large-noshield--nanobanana.png): board 4 with the round shield removed from the large gun. Its geared iron housing now shows.
- [11-iron-crossed--nanobanana.png](11-iron-crossed--nanobanana.png): the blocks with the iron rebuilt in three layers of bigger bars, each layer crossing the one below. The other three blocks are unchanged.
- [ladder-a.png](ladder-a.png) and [ladder-b.png](ladder-b.png): the picked small and medium guns with each large candidate, cut from their boards by [ladder.py](ladder.py) and set side by side, small to large.

## The large gun and the last iron fix

- [ ] large gun a, from board 3
- [x] large gun b, from board 4 without the shield

Sebastian, 12 October: "Ladder b looks good!" [ladder-b.png](ladder-b.png) is now the anchor [gun_ladder.png](../../anchors/gun_ladder.png). Decision D31.

He also found that the single top iron bar faced the wrong way. [12-iron-top--nanobanana.png](12-iron-top--nanobanana.png) turns the top layer across the layer below. The stack is now three layers of three bars, each layer crossing the one under it, and reads as a box. The other three blocks are unchanged. It is now the anchor [resource_blocks.png](../../anchors/resource_blocks.png).
