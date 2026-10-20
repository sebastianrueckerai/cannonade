# Session 26: two wall looks, one per faction, and team colour on walls and ground

Sebastian, 2026-10-20: "I would like two different wall models: The new walls are chunky cause they
always cover a whole tile. This is fine. But maybe have some granulations or something like that on
the sides. Maybe like arches... like medieval doorways but just the arch parts. Or the walls get
thinner in the middle and fatter on top? Anyways, make a few models, first 2d then show me some 3d
variants. In addition to that: I like the current colors of the walls and the floors that are
encircled by walls. But: Both look identical for me and the enemy which is bad. So different
factions should use different wall models and different colors. Once you have the models experiment
with a few alternatives. Make the 'walkways' on top of the walls get tinted towards a player's
color? Something like that... I want to see at a glance which walls and territory belongs to which
player!"

Two asks, both exploration rounds that end in his picks:

1. **Wall looks.** Painted sketches first (D30), then procedural 3D variants of the full-tile block
   (D75, C15) in the game. He picks two, one per faction.
2. **Team colour on walls and ground.** The cream stone and the stamped mud stay (D53, D70); a team
   tint goes on part of the wall and perhaps the enclosed ground. He picks the scheme and strength.

## What the camera sees

The default view looks down at 60 degrees. A vertical wall face 0.75 m tall shows about 5 px, the
block's top about 19 px deep (gameplay contract). So from the default view the player sees mostly
the tops: the walkway and the 2 x 2 merlons. The side treatments (arches, courses, pilasters) read
only on the near fort and zoomed in. A tint on the walkway is the one change that reads everywhere.
Both boards show the default view and a zoomed corner, so the pick weighs both.

## Constraints a block must keep

A block knows nothing about its neighbours (D75: no per-tile model inference), so:

- Nothing protrudes past the tile edge. Two neighbours' protrusions would overlap and z-fight.
- Anything inset from the tile edge leaves a slot at every seam between two blocks. A small inset
  (under 0.1 m) reads as a joint groove; a large one shows daylight through the wall.
- Recesses in a face stay at most 0.12 m deep, so the storey above still swallows the lower block's
  merlons (which reach 0.375 m from the centre).
- The storey (`wall_upper`) is the same build shifted 0.75 m up; its body hides the lower merlons.

## The 2D round

[rounds/35-faction-walls/](../../game/art-direction/rounds/35-faction-walls/): six painted sketch
sheets in the round 19 style (nano-banana edit, 2K, the three style refs of round 19), one look per
sheet, each showing a run of full-tile blocks that turns a corner, one and two storeys, from the
game's three-quarter view:

1. **Arcade.** One blind round-headed arch sunk into every face, piers between.
2. **Corbelled parapet.** Plinth at the foot, body set back, walkway and merlons overhanging on
   corbels: his "thinner in the middle and fatter on top".
3. **Buttressed.** Pilaster strips at every block corner, a string course under the merlons,
   recessed panels between.
4. **Coursed stone.** Three courses of big dressed blocks with deep recessed joints, offset like
   brickwork: his "granulations on the sides".
5. **Capped merlons.** A plain body with a cornice band and pyramid-capped merlons: a top that reads
   from above, where the camera looks.
6. **Two factions.** Two runs side by side, look 2 in royal blue and look 3 in purple on the walkway
   and merlon tops, the enclosed mud lightly tinted: the colour idea as a painting.

Cost: six images at about 0.25 USD, within the 5 USD window of `.env.session`.

## The 3D round

The shared build [wall_block.py](../../game/assets/3d/wall_block.py) gains a `style` key and three
parts: `wall` (the body), `deck` (the walkway slab on top of the body, 0.02 m) and `merlons`. Deck
and merlons paint in the stone grain on a white base, so the game's colour multiplies cleanly on
them (the mud tile's rule, D70); the body keeps the cream stone paint. Six assets, base level only
for the pick (storeys follow the picked two): `wall_plain` (today's block in parts), `wall_arch`,
`wall_corbel`, `wall_pilaster`, `wall_course`, `wall_caps`. Each gets the pipeline's render sheet.
They sync unapproved under their own ids into the worktree's art layer for the boards; the shipped
`wall` and `wall_upper` are untouched until the pick.

## The in-game boards

[tools/shoot_battle.gd](/home/womb/repos/grid-cannons/tools/shoot_battle.gd) gains three tool-side
flags: `--wall=idA,idB` swaps each side's wall art, `--team=deck=K,merlons=K,body=K,floor=K` tints
the named parts toward the owner's team colour by K (the enclosed ground by the ring owner the
check computes), `--eye=Y,Z` sets the close camera's offset so a low angle can show a wall's faces.
Boards composed by the round's `board.py` from the frames `shoot.sh` takes:

- **models.jpg**: every variant on both forts: a low-angle model check, the near corner at the
  game's angle, the far fort magnified 3x.
- **pairs.jpg**: four candidate faction pairs in neutral stone, default view and both forts magnified.
- **colours.jpg**: nine tint schemes on the plain block: none, walkway at three strengths, walkway
  plus merlons, merlons only, body, walkway plus ground, ground only. Default view, the near fort
  at 2x and the far fort at 3x.

## Deliverables

1. Round 35 sketches, checked in crops, one critic read.
2. The six variants built, their sheets, and the three boards.
3. This doc, `PICKS.md` with the open questions, roadmap items for the looks (C) and the colour
   (I), tests green, merged to master. No decision entry until Sebastian picks.

## Limits

- Provider spend: the six sketches and one critique, about 1.6 USD.
- The wall triangle budget of 200 (gameplay contract) holds for `wall_plain` and `wall_caps`; the
  face treatments need more, measured per variant below. Raising the budget for the block is part
  of the pick.
- Four-player games: two models cover two factions. The proposal is model A for players 1 and 3,
  model B for players 2 and 4, with the colour telling them apart, as the castle roofs do today.

## Results

Everything above is built and on the boards of [round 35](../../game/art-direction/rounds/35-faction-walls/PICKS.md);
the picks are open. Findings, in the order the round made them:

- **The sketches read as asked.** Faults found in crops: sheet 1's single block has an open doorway,
  every sheet draws the stacked storey as a tower, sheet 3's pilasters protrude past the tile. The critic
  ranked the arcade and the buttress boldest and called the colour on the walkway and merlons the better
  answer than any shape.
- **Six blocks built clean**, three parts each, all inside the tile, no non-manifold edge. Two builds
  needed a second pass: the arch cutter as a box plus a cylinder shared an edge with the body's jamb and
  broke the exact boolean on two of four faces, so the arch is now one extruded outline; the corbel's
  outer face lay in the slab's face plane and left one open edge, so it sits 5 mm inside the tile. The
  course block builds from stones round a set-back core instead of grooves cut into a box, for the same
  reason.
- **The side treatments vanish from the game camera.** The pitch is 60 degrees and the zoom keeps it, so
  the five faces read only in the low-angle cell. The corbel's overhang line and the caps' pyramid tops
  are the top-visible differences. No pair of looks tells the forts apart at the default view.
- **The walkway tint does.** At 0.6 it reads on both forts at the default view with the merlons still
  cream; with the ground at 0.25 the territory reads too. The body tint is invisible. The table in
  PICKS.md grades all nine.
- **The tint mechanism works end to end**: white-base paint, a multiply node, `baseColorFactor` in the
  glTF, `albedo_color` in Godot, one `U.set_color` on the part.
- **Suite green**, 18 entries, with the six variants synced under their own ids and the shipped `wall`
  untouched. The texture-leak lines the battle tool prints at exit are pre-existing: the untouched
  master prints the same four.
- Provider spend 1.53 USD of the 5 USD window.

Open for Sebastian: the two looks and the budget (C17), the colour scheme (I51). Flagged: the sandbox
sides are blue and red, in play the AI is purple; a storey (`wall_upper`) exists only for the shipped
block until a look is picked; after the pick the preview restore in
[PlayerController.gd](/home/womb/repos/grid-cannons/scripts/components/PlayerController.gd) must keep
each part's own colour, because `U.get_color` reads one mesh.
