# Round 08 notes

Phase E, the castle duel, after Sebastian's rejection of round 07 sheet 4 with 2x crops: cannons hovering over houses, a wheel in a wall, a grid rotated against the castles, a cannon off its ball's line. Two changes of method. Every verdict on a cannon, a shot or a letter is now made from a magnified crop, with the new [crop.py](../../../../pipeline/crop.py), never from the frame or the sheet, and the critics get the crops. And the picture is made in two edits: first the scene with the cannons placed and no shot, [round.json](round.json), the cannons checked in crops; then the shot as an edit of the checked scene that names the one cannon that fires, [round-fire.json](round-fire.json), checked again. Every cannon stands on the flat top of a corner tower or on a wall walk, so it looks over the battlements; the two castles are not mirror images; the grid runs parallel to the walls. 10 images, 1.50 USD, plus critiques. Session spend with rounds 06 and 07: 6.84 USD before the critiques of this round.

## The scenes, from the crops

[crops-1.png](crops-1.png) to [crops-5.png](crops-5.png), the castles of each scene at 2.5x.

- **1 side by side**: the cannons came out in the courtyards on the floor, complete, well drawn, pointing at the other castle through their own wall; the right castle has one on its wall-walk corner. The castles differ, a round tower on the right. The grid is diagonal and the front walls are horizontal, so the grid is not parallel to the walls, the fault of round 07's 25.
- **2 land, diagonal**: the near castle's cannons on its two corner tower tops and one on the front wall walk, the far castle's on its tower tops, all on stone, looking over the battlements. The castles differ. The walls and the grid share their diagonals.
- **3 two islands**: one cannon on a tower top and one on a wall walk per castle, on stone, pointing across the strait. The castles differ. The grid shows on the courtyards and the island edges.
- **4 side by side, closer**: the prompt asked for closer and got scene 1 again, the cannons in the courtyards, the grid not parallel to the front walls.
- **5 land, from higher**: the prompt asked for a steeper view and got scene 2's view with more cannons, three on the near castle's tower tops, one on its wall, two on the far castle's towers and one in its courtyard; all on stone, pointing in several directions.

## The shots, from the crops

[shots.png](shots.png), the five shots at 2x.

- **1**: the upper courtyard cannon fires to the right over the wall, the flash and the cloud at the muzzle, the ball over the river on the barrel's axis. Right. The cannon fires from the courtyard over the wall, which is how the game's cannons fire.
- **2**: the right tower cannon fires up and right, the flash and the cloud at the muzzle, the ball above the line: the barrel points to about half past one, the ball sits at about twelve. Wrong by that much.
- **3**: the tower cannon fires right across the strait, the flash and the cloud at the muzzle, the ball on the axis with a straight trail. Right, the cleanest.
- **4**: the right castle's wall-walk cannon fires left over the river, the flash and the cloud at the muzzle, the ball on the axis. Right.
- **5**: the back tower cannon fires up and right at the far castle, the flash and the cloud at the muzzle, the ball on the axis. Right, with seven cannons in the picture, which is more than Sebastian wants.

Director's ranking: 3, 1, 4, 5, 2. Every title stayed as it was, [capsule-small.png](capsule-small.png).

## Critics

GLM reads the crops as the director does: 1, 3, 4 and 5 right, 2 wrong with the ball at twelve against a barrel at half past one; it ranks 5, 1, 3, 4, 2, see [critique/glm.json](critique/glm.json). GLM also reads the grid of 1 and 4 as parallel to the walls, which the crops contradict. Gemini returned an empty answer at 12000 tokens, [critique/gemini-empty.json](critique/gemini-empty.json), and on a rerun with smaller images and 16000 tokens ranks 3, 2, 5, 1, 4, see [critique/gemini.json](critique/gemini.json): it reads 1 and 4 as off by an hour on the clock face and 2 as right, the opposite of GLM, and it sees a cannon on a roof in 5 that the crop does not show. The one verdict all three share: 3 is right, the ball on the axis with a straight trail. On the clock face the director reads 1 at two against two, 2 at half past one against twelve, 4 at half past nine against half past nine.

## Lessons

- A frame at screen size hides a cannon's fault. Round 07 sheet 4 was judged "right" on the frames and was wrong in every case Sebastian cropped. The crop is the check, and the first thing a critic prompt attaches.
- Two edits beat one. Placing the cannons with no shot and firing one of them in a second edit gave four right shots in five; one edit that asked for both gave none in eight.
- "Closer" and "steeper" do not move the camera of an edit that attaches a frame; 4 and 5 kept the view of 1 and 2. A new camera needs a new composition prompt without the frame, or a crop of the frame as the reference.
- The model puts cannons where the words put them: "on the flat top of a corner tower" produced tower cannons in 2, 3 and 5, and the courtyard cannons of 1 and 4 came with the side-by-side layout, where the facing walls have no corner tower in view.

## Reproduce the composites

```
uv run --script pipeline/round.py game/art-direction/rounds/08-castle-duel
uv run --script pipeline/round.py game/art-direction/rounds/08-castle-duel round-fire.json
uv run --script pipeline/crop.py --mag 2 --cols 2 --out game/art-direction/rounds/08-castle-duel/shots.png "1 the left castle's upper courtyard cannon=game/art-direction/rounds/08-castle-duel/1-side-by-side-fire--nanobanana.png@0.24,0.38,0.58,0.68" "2 the near castle's right tower=game/art-direction/rounds/08-castle-duel/2-land-diagonal-fire--nanobanana.png@0.36,0.46,0.70,0.78" "3 the left castle's right tower=game/art-direction/rounds/08-castle-duel/3-two-islands-fire--nanobanana.png@0.30,0.36,0.66,0.64" "4 the right castle's wall-walk cannon=game/art-direction/rounds/08-castle-duel/4-side-closer-fire--nanobanana.png@0.44,0.38,0.78,0.68" "5 the near castle's back tower=game/art-direction/rounds/08-castle-duel/5-land-top-down-fire--nanobanana.png@0.26,0.40,0.62,0.76"
uv run --script pipeline/img.py montage --images game/art-direction/rounds/08-castle-duel/1-side-by-side-fire--nanobanana.png game/art-direction/rounds/08-castle-duel/2-land-diagonal-fire--nanobanana.png game/art-direction/rounds/08-castle-duel/3-two-islands-fire--nanobanana.png game/art-direction/rounds/08-castle-duel/4-side-closer-fire--nanobanana.png game/art-direction/rounds/08-castle-duel/5-land-top-down-fire--nanobanana.png --labels "1 side by side" "2 land, diagonal" "3 two islands" "4 side by side, the right castle fires" "5 land, from higher" --cols 2 --cell 1024 --out game/art-direction/rounds/08-castle-duel/picks-sheet.jpg
uv run --script pipeline/titlepx.py --widths 460,231 --mag 2 --out game/art-direction/rounds/08-castle-duel/capsule-small.png "1 side by side=game/art-direction/rounds/08-castle-duel/1-side-by-side-fire--nanobanana.png" "2 land, diagonal=game/art-direction/rounds/08-castle-duel/2-land-diagonal-fire--nanobanana.png" "3 two islands=game/art-direction/rounds/08-castle-duel/3-two-islands-fire--nanobanana.png" "4 side by side, right fires=game/art-direction/rounds/08-castle-duel/4-side-closer-fire--nanobanana.png" "5 land, from higher=game/art-direction/rounds/08-castle-duel/5-land-top-down-fire--nanobanana.png"
```
