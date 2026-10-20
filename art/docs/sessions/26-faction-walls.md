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

## Second pass: the picks in the game

Sebastian, with the boards open: "1, 3,4,5 all look good, lets do them all. I would color the walkway on the
wall, not the lego like blocks on the walls (trough which the walkways lead. But a problem with this is, that
a walkway presumes a direction, and the direction is guided by the neighbouring walls. A single standing cell
of 1x1 walls should then only have the inner square colored. See if you can make that happen. If there are
other accents like lines around the wall that lend themselves to be colored, experiment with that as well!"
Recorded as D78.

**The block is one mesh with regions.** A block with a dozen separately coloured parts would be a dozen draw
calls, and a long game holds hundreds of blocks (K7). So [wall_block.py](../../game/assets/3d/wall_block.py)
builds the deck as one plate, cuts it along the region planes and writes a region id into a second UV layer
per face: the centre square, four corridors, their four caps at the tile edge, the four corner squares, a rim
frame and the band round the body's top. [materials/wall.gdshader](/home/womb/repos/grid-cannons/materials/wall.gdshader)
multiplies the painted texture by one colour per region, with a `shade` for the placement preview. The deck's
rows of the texture are painted white (`white_band`), so the colour is the region's own. One material per
block, one draw call, as before.

**The game.** `Catalog.WALL_LOOKS` names the four looks by player number, `Catalog.spawn` takes the owner so a
block or piece wears its look from the start, and `Wall.wear` corrects a block built without one (the sandbox
and the tools). `Wall.repaint` colours the walkway from the centre toward every side where an own wall stands,
`BuildingPlace.repaint_walls_around` runs it on this tile and its four neighbours when a block is built or
destroyed, a storey repaints itself when it is stacked, and a hand piece's cells show the walkways between the
cells in the piece's own frame, which turns with it. The preview darkens the piece through the shader's shade.
The ground tint and the accents are tool knobs on `Wall` (`walk_tint`, `rim_tint`, `band_tint`) and
`--team=walk=K,rim=K,band=K,floor=K` in the battle tool, for the accents board.

**Found on the way.** An exact union of boxes that only touch leaves their shared faces inside the result and
55 non-manifold edges; parts overlap by 0.01 m now. The glTF exporter writes the second UV layer as
`TEXCOORD_1` without a setting, and Godot reads it as `UV2`.

**Watched red.** `tests/walls_test` went red under each of five breaks: the owner ignored beside a block, one
look for every player, no repaint when a block is destroyed, a storey wearing the base model, a piece without
its corridors. `tests/human` and `tests/preview_test` read the shader's shade now instead of an albedo.

**Result.** Triangles: plain 308, pilaster 390, corbel 468, course 524. The walkway reads at the default view
on both forts as a line through the ring that turns at the corners. Suite green, 19 entries.

## Third pass: the ground, and the walkways at every junction

Sebastian: "9 looks greeat... but show me some variations with each existing individual piece places without
neighbors and some walls connecting on 2, 3 and 4 sides. I want to see if the walkways all still work!", then
mid-work "Actually, I like 8 better! Switch to 8, rest stays". Recorded as D79.

**Shipped.** The ground: the enclosure flood already finds
every closed region and recolours its tiles, so it now asks `Map.ring_owner` for the region's owner, the
check's majority rule moved out of `GameController._ring_regions` into the one shared helper, and the tile
keeps that owner in `ringOwner` for every later recolour (a burnt tile cooling, a tool repaint). The tint is
`BuildingPlace.ground_tint`, 0.25. The rim line and the band stay knobs at 0.

**Watched red.** Two breaks on the walls test's new ground checks: the tint ignored in `reset_color`, and the
flood never naming an owner. One wrong expectation in the test itself: a ring's corner blocks border no
inside tile, so the majority counts the six side blocks, not ten.

**The board.** [pieces.jpg](../../game/art-direction/rounds/35-faction-walls/pieces.jpg): the battle tool's
`--pieces` layout, every hand piece alone (1, 2, 3, 4 in a row, S, T, X), a corner, a 2 x 2, a filled 3 x 3
and a 4 x 4 ring, straight down and at the game's angle.

## Fourth pass: the looks in the game, and the castle's roof

Sebastian: "Can you show me the walls in comparison? in Game?" and "the castle texture has a piece of the roof
missing... its like a thin pizza slice of the round roof not colored in the players colors -> fix!"

**The roof.** The cleanup's team vote samples the raw Meshy texture by hue and saturation, and the texture
shades a slice of the cone and the edges of the annex roofs too pale, so those faces stayed on the stone
material and showed cream in play. `fill_team` in [cleanup.py](../../pipeline/blender/cleanup.py) now fills a
face from its team neighbours after the vote; the castle, d1 and d2 were cleaned, rendered, synced and checked
in a game close-up. d3 and d4 carry no team part (D72).

**The looks in the game.** [looks-in-game.jpg](../../game/art-direction/rounds/35-faction-walls/looks-in-game.jpg):
a four-player game at its start, each player's castle ring close up at the game's angle and from a low angle,
so the four looks stand side by side with their colours, shot by [tools/screenshot.gd](/home/womb/repos/grid-cannons/tools/screenshot.gd)
with its new `--castle=N` and `--eye=Y,Z`.
