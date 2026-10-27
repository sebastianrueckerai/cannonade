# Round 35: two wall looks and the team colour on walls and ground

Session 26, plan [26-faction-walls.md](../../../../docs/sessions/26-faction-walls.md). Two questions for
Sebastian, each with its board: which two wall looks the factions get (C17), and which parts of a wall and
the ground wear the owner's colour, how strongly (I51). The sketches came first (D30), then every look was
built as a real block and shot in the game, and every colour scheme is a tool flag on a sandbox battle, as
in round 27. Six sketches, one critic read, no other provider calls.

## Boards

- [contact-sheet.jpg](contact-sheet.jpg): the six painted sketches, one look each, numbered 1 to 6 in
  reading order. 1 arcade, 2 corbelled parapet, 3 buttress, 4 coursed stone, 5 capped merlons, 6 two
  factions with the walkway and merlons stained blue and purple.
- [3d-sheet.png](3d-sheet.png): the six procedural variants of the block from the pipeline's render sheet,
  three-quarter, front and the textured view, with their triangle counts. 1 plain (today's block as three
  parts), 2 arch, 3 corbel, 4 pilaster, 5 course, 6 caps.
- [models.jpg](models.jpg): every variant on both forts in the game: the near fort's corner from a low
  angle (a model check, the game never looks this low), the same corner at the game's angle, and the far
  fort's walls magnified 3x.
- [pairs.jpg](pairs.jpg): four candidate pairs, one look per fort, neutral stone.
- [colours.jpg](colours.jpg): nine tint schemes on the plain block, blue near, red far.

## What the sketches showed

Checked in the sheet before Sebastian saw it: sheet 1 draws the single block's arch as an open doorway and
the stacked storey as a tower; the others draw the storey as a tower too. Sheet 3's pilasters protrude past
the tile, which a block cannot do. The looks themselves read as asked.

The Gemini critic ([critique-gemini.json](critique-gemini.json)) ranked the looks for telling two players
apart from the game camera 1, 3, 2, 4, 5: the arcade and the buttress are the two bold shapes, the corbels,
courses and caps blur at five pixels. It called sheet 6's colour on the walkway and merlons the better
answer, because the camera sees the tops, not the sides.

## What the game showed

**The side treatments do not survive the camera.** The game looks down at 60 degrees and zooming keeps
that pitch ([CameraRig.gd](/home/womb/repos/cannonade/scripts/CameraRig.gd) moves the camera along one
line), so a wall face is a 5 px band at the default view and a foreshortened strip even at the near corner.
In [models.jpg](models.jpg) the arch, pilaster and course blocks are the plain block from both game angles;
only the low-angle cell shows their faces. What does survive is on top: the corbel's overhang draws a
shadow line and a joint groove at every seam, the caps' pyramid merlons catch the light as small facets.
[pairs.jpg](pairs.jpg) makes the same point with one look per fort: at the default view no pair tells the
two forts apart. A second look is flavour for the zoomed view, not the thing that tells the factions apart.

**The colour does.** In [colours.jpg](colours.jpg), blue near and red far on the plain block:

| scheme | reads at the default view | note |
|---|---|---|
| 1 today | no | both forts the same |
| 2 walkway 0.35 | faintly | reads on the near fort at 2x |
| 3 walkway 0.6 | yes, both forts | the merlons stay cream dots on a coloured band |
| 4 walkway 1.0 | loud | unmistakable, the cozy stone goes |
| 5 walkway + merlons 0.6 | yes | one flat coloured band, less stone than 3 |
| 6 merlons only 0.6 | yes, delicate | a dotted ring, the walkway stays cream |
| 7 whole block 0.2 | no | the body's faces are what the camera cannot see |
| 8 walkway 0.6 + ground 0.25 | yes, and the territory | the mud keeps its hue under the wash |
| 9 ground only 0.4 | the territory, strongly | the walls stay cream |

The session's own read, not a decision: 8, walkway 0.6 with the ground at 0.25, answers "walls and
territory at a glance" with the stone and the mud still themselves; 6 is the prettiest if walls alone
suffice. The sandbox sides are blue and red; in play the AI wears the palette's purple (D21), which the
boards do not show.

**Costs.** Triangles per block: plain 168, caps 192, pilaster 232, corbel 328, arch 344, course 360
against the contract's 200 for a wall. The plain and caps blocks fit; the others need the budget raised
for the full-tile block. Spend: six sketches at 0.25 USD and one critique at 0.03 USD, 1.53 USD.

## Picks (D78)

- **Looks: 1, 3, 4 and 5, all four.** Sebastian, 2026-10-20: "1, 3,4,5 all look good, lets do them all." One per
  player number: plain, corbel, pilaster, course. The budget rises with it: 308 to 524 triangles a block.
- **Colour: the walkway, not the merlons, and the walkway follows the neighbours.** "I would color the walkway
  on the wall, not the lego like blocks on the walls ... a walkway presumes a direction, and the direction is
  guided by the neighbouring walls. A single standing cell of 1x1 walls should then only have the inner square
  colored." Shipped at 0.6, the session's call.
- **Accents: scheme 8 of [accents.jpg](accents.jpg), the ground (D79).** "9 looks great", then "Actually,
  I like 8 better! Switch to 8, rest stays." The walkway as shipped and the enclosed ground at 0.25 toward its
  ring owner's colour. The rim line and the band are unpicked. [ai4.png](ai4.png) shows all four looks and
  colours in one four-player frame.
- **The walkways at every junction:** "show me some variations with each existing individual piece placed
  without neighbors and some walls connecting on 2, 3 and 4 sides. I want to see if the walkways all still
  work!" [pieces.jpg](pieces.jpg): the seven pieces alone, a corner, a 2 x 2, a filled 3 x 3 and a 4 x 4 ring,
  straight down and at the game's angle, under the shipped colours.
- **Passed.** Sebastian on [pieces.jpg](pieces.jpg): "looks great! lets go!" The eight wall models (four looks,
  each with its storey) are approved in their manifests; C15 is ticked.
- **The looks side by side in the game:** "Can you show me the walls in comparison? in Game?"
  [looks-in-game.jpg](looks-in-game.jpg): a four-player game at its start, each player's castle ring close
  up, one column per look with its colour, at the game's angle and from a low angle.
- **Open: the tops.** "Unfortunately the walls all look the same cause of the angle. Can you also have them
  have some variations for the granulations?" Each look now has its own merlons: square, octagonal drums,
  pyramid-capped, sixteen small studs. [looks-in-game.jpg](looks-in-game.jpg) shot again with them, for his pass.
- **Three studs a side on the 3rd look.** "Can you change 2 3rd or 2nd one for one were it has 3 granulations /
  lego connectors on each side instead of 2?" The pilaster look's pyramid caps gave way to eight round studs,
  a 3 x 3 without its centre. [looks-in-game.jpg](looks-in-game.jpg) shot again, for his pass.
- **The studs follow the docking walls (D80).** "3 granulations are only in place, were the wall is overlooking
  open space!" A mid-side stud goes where that side's walkway opens. [looks-in-game.jpg](looks-in-game.jpg)
  shot again, for his pass.
- **Passed and deployed (D81).** "Looks good. Deploy! Every faction gets a random wall type, no wall twice!"
  All eight models approved; each game deals the looks at random, one per player.
