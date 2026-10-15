# Round 06 notes

Phase E, what stays and what differs. The table was written first, [surfaces.md](surfaces.md), then three title studies through `ideogram/v4` with prompt expansion off, then three surface frames through `google/nano-banana-2.1/edit` with [world_style.png](../../anchors/world_style.png) attached, see [prompts/](prompts). The menu and the splash frames were run twice: the first attempt of each lost the palette's blue sky to a cream wash, the second names the sky. 8 images, 1.02 USD, plus four critiques, 0.12 USD, two of them empty. [title-small.png](title-small.png) is the title size test: each study cropped to its letters at 460, 231 and 120 px wide, the Steam header capsule, the small capsule and half of that, magnified twice, made with the new [titlepx.py](../../../../pipeline/titlepx.py).

## Director's read, provisional

- **1 carved wood**: chunky slab-serif capitals in relief, cream faces, orange sides and a dark shadow line. The oak of the prompt came out in the roof orange, so the letters read as painted toy blocks, the world's own material. The widest strokes of the three, the one that holds at the small capsule.
- **2 painted sign**: bouncy brush capitals, cream with a red-orange drop shadow and a dark outline, a slant. Cheerful and the least formal. The brush edges fuzz at 231 px and the S of CANNONS goes first at 120 px; the slant makes the lockup wider than it needs to be.
- **3 naval brass**: tall engraved serif capitals in gold with a highlight band and a dark inset. Elegant and formal, the age of sail. The thin serifs break first at 120 px, and brass is a colour the palette lacks. Reads as a more serious game than the toy world.
- **4a menu**: the hero angle works, the tower and the walls over the pier and the ship, the upper third open. The sky went pale green-grey, a drift from the palette, and the flag went brown.
- **4b menu v2**: the same angle with the palette's blue sky and a thin fog band at the horizon. The title zone is clear blue. Pine trees joined the round ones, the flag is brown again, a second ship is cut by the right edge. A centred panel 390 px wide covers the gate, which sits right of centre, so the menu layout of D3 either moves the panel or accepts it.
- **5a splash**: the island small and centred, the sea around it, but the whole upper half turned cream, so there is no sky and the lockup would sit on fog.
- **5b splash v2**: the blue sky over a thick fog band, the island the one focal point, the two ships at anchor, the sea to the edges. The lockup sits on the blue, the splash of the table.
- **6 store**: the evening sky, round smoke puffs at the cannon mouths, two cannonballs in the air, a splash by the pier, two ships close in. The sea stayed the palette's blue, so the evening did not turn the water into a painting as it did in round 05. The camera stayed at the gameplay angle instead of low on a diagonal, the one thing the prompt asked for and did not get; the drama is in the light and the smoke, not the angle. The cannonballs are too small to read in a capsule.

Director's ranking for the title: 1, 2, 3. Carved wood, because the chunky relief letters are the world's blocks and keep the widest strokes for the small capsule. For the frames the director takes 4b, 5b and 6 as the references, because the lockup is tested on the palette's sky and must sit on it in the menu and the splash.

## Critics

Gemini ranks the titles 1, 2, 3, GLM ranks 1, 3, 2, see [critique/](critique). Both put carved wood first as the only study that still reads at 120 px and the only one made of the world's material; both call the brass a realistic naval game and say the brush letters fuzz. Gemini sees the D of 2 close toward an O, GLM sees its S collapse. On the frames the two split against the director: Gemini keeps 4a for its sea and sky and 5b for its sand and grass, GLM keeps 4a and 5a and reads the fog band of 5b as clouds and the two ships as competition. Both say a centred 390 px panel covers the gate in 4a and 4b. Both say 6 does not read as the same game at a glance and would remove the smoke puffs; GLM would also drop the evening sky. Their three rules agree: the hex of the base materials never changes; the store may change the time of day and the camera; the UI is built from the world's chamfer and face colours, never a flat neutral rectangle.

The director keeps the smoke and the evening on the store: the brief's battle phase is a shooting gallery with round smoke puffs, and the evening light is the one change the table allows the store, so the fault in 6 is the camera, not the light. The critics' point that 6 drifts too far is taken as a limit: the store still keeps the world's camera height or lower, the palette's sea, and no more than the smoke, the cannonballs and the splash on top of the world.

GLM returned an empty answer twice at `--max-tokens 4000`, because its reasoning tokens come out of the same budget, and answered at 12000. The default of 8000 is the floor from now on. The two empty runs are counted in [critique/glm-empty-1.json](critique/glm-empty-1.json) and [critique/glm-empty-2.json](critique/glm-empty-2.json).

## Faults in the images

- 4a and 5a lost the palette sky to cream: a prompt that says "fog band at the horizon" without naming the sky colour lets the fog fill the sky. The rerun names the sky as the sea's blue.
- The flag is brown in 4a, 4b and 6, red in the anchor. The edit drops a red flag to brown when the tower is seen from the side.
- 6 kept the gameplay camera. A composition change on top of a light change does not hold in one edit of this frame; a store still from a low angle is a two-step edit, angle first, light second.
- 3 uses brass, a colour the palette lacks. A pick of 3 adds `brass` to the palette as a phase B correction.

## Reproduce the composites

```
uv run --script pipeline/img.py montage --images game/art-direction/rounds/06-surfaces/1-carved-wood--ideogram.png game/art-direction/rounds/06-surfaces/2-painted-sign--ideogram.png game/art-direction/rounds/06-surfaces/3-naval-brass--ideogram.png --labels "1 carved wood" "2 painted sign" "3 naval brass" --cols 3 --cell 1024 --out game/art-direction/rounds/06-surfaces/picks-sheet.jpg
uv run --script pipeline/titlepx.py --widths 460,231,120 --mag 2 --out game/art-direction/rounds/06-surfaces/title-small.png "1 carved wood=game/art-direction/rounds/06-surfaces/1-carved-wood--ideogram.png" "2 painted sign=game/art-direction/rounds/06-surfaces/2-painted-sign--ideogram.png" "3 naval brass=game/art-direction/rounds/06-surfaces/3-naval-brass--ideogram.png"
```
