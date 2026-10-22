# Session 62: the picked cannons into the game, the mortar at 1x1, gun looks per faction

Sebastian, 2026-10-23: "Build 2 and 5. Show me a scene with them in the so I can rotate them in the
editor and see them up close. While we are at it, let me place the bullet spawn point." And the
follow-up: "An then in any round we give the existing cannon or one of the new ones randomly to a
faction. So each faction alwas builds the same, but per party they differ. I also want to fix up the
mortar: Scale it down to 2x2 and lets do the same for the mortat. We use it as a 1:1 exchange for the
same cannon.So one faction has the now smaller mortat and the other the existing cannon"

Closes C20 on his pick (boards 2 and 5, decision D91) and ships game item I103. What each deliverable
feeds:

- **cannon.2** (chunky-post) and **cannon.3** (chunky-iron) through split.json and
  [barrel.py](../pipeline/barrel.py): his picks become the game's new chunky gun looks, one dealt to
  each faction every game. cannon.2 needed four fixes (a dropped floating cradle, a shortened breech,
  a raised post top, a slotted fork head for the fat barrel to roll through); the residual is a 2 mm
  tangent graze at the slot walls at −10 degrees, the accepted-graze class of cannon.3.
- **cannon.4**, the mortar's raw model rebuilt on the 1x1 plate: his 1:1 model exchange, so a faction
  can build the mortar look with the cannon's behaviour and shell, and the four looks can deal evenly.
- **The look deal** (GUN_LOOKS in [Catalog.gd](../../scripts/Catalog.gd), `gunLook` on
  PlayerController, dealt in Main.build): every game hands each player one look for its whole faction,
  like the wall looks (D81); this is what makes the four models show up in his games.
- **The bench and the spawn-place scenes** ([tools/gun_test.tscn](../../tools/gun_test.tscn) with the
  three new guns, tools/spawn_place_cannon.2/.3/.4.tscn): his judgement stand for the models, and his
  drag for the spawn anchors (I78's HAND_SPAWN readback, which rebuilds the finals without touching
  geometry).

Cost: the two Meshy runs were round 1's; this round spent only critic calls (about $0.25) — well
inside the $5 window set at session start.

## Follow-up round: cannon.2 out, the hand-placed spawns in

Sebastian, same day: "cannon 2 has an untestured holder, the thing that directly holds the barrel.ITs
also not a solid piece but broken into 3 pieces. Just get rid of that one, we have enough. I places the
bullet spawns"

- **cannon.2 leaves the game** (D92): not surgery on the holder, the model goes. `GUN_LOOKS` stands at
  three (cannon, cannon.3, cannon.4), the bench and tests went with it. The asset parks in art/, its
  files and fixes kept — "we have enough" is about the looks, not about deleting work.
- **His three spawn anchors went into `HAND_SPAWN`** and the finals of cannon.3 and cannon.4 rebuilt
  with them (`"spawn_from": "hand"` in each build JSON); cannon.2's anchor is recorded too, so the
  parked asset rebuilds with his placement if it ever returns. The rebuilt glbs are synced into the
  game layer and approved in the art manifest.

Cost: none — the rebuilds are local Blender.
