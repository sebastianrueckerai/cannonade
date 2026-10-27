# Round 18: the three guns through Tripo and Meshy

The route test of D34. Every experiment ran on both APIs, with the three guns of [gun_ladder.png](../../anchors/gun_ladder.png) as test cases: 45 runs, 24 on Tripo and 21 on Meshy. The runs come from [route-test.sh](../../../assets/3d/route-test.sh), the sheets from [meshsheet.py](../../../../pipeline/meshsheet.py) and [barrel.py](../../../../pipeline/barrel.py). Every run keeps its sidecar next to its model in `game/assets/3d/<gun>/raw/`. Every sheet shows the input images beside each run.

## Verdict for Sebastian

Meshy beat Tripo on every measure this test can count, and on the look of the small and the medium gun. Four questions are his to decide. Each has my suggestion:

1. **API: Meshy.** It is five times faster, charges 15 credits against Tripo's 40, hits the face count asked within 11 percent, and returns the barrel as its own part.
2. **Input: one side view.** On Meshy's low-poly model, one side view gave every gun its right proportions and its barrel as a separate part, for 15 credits. The three-quarter view works for the small and medium guns but shortens the large barrel. Several views fixed the length too, but only through `meshy-7.1`, which fuses the parts and costs 30 credits. See experiment 5.
3. **Barrel: Meshy's own parts,** split off in Blender. Where a barrel comes in many pieces, as on the large gun, the barrel and the mount made apart and joined in Blender is the fallback. A cut through a fused mesh tears it.
4. **Face count: about 1,000 for the small gun, 1,500 for the medium, 3,000 for the large.** At the default view 300 looks the same as 3,000. The counts matter only when the player zooms in, where 300 makes the small barrel eight-sided.

## The inputs

Each gun has the same set in `game/assets/3d/<gun>/refs/`.

| input | what it is | how it was made |
|---|---|---|
| a | the painted sketch, cut out of the ladder | a crop, no change |
| b | a clean three-quarter view on plain grey | an image edit of a, nano-banana 2.1 |
| c4 | front, left, back and right, for Meshy also b as the fourth | one turnaround sheet edited from b, cut into separate files at one scale |
| c2 | front and back only, Tripo | two of the c4 files |
| barrel, mount | the barrel alone and the mount without the barrel | two image edits of b |

The large gun's turnaround repeated its left side in the right-side cell, so its c4 has three views. The first barrel picture of the small gun still showed the post, so it was painted again.

## How the APIs perform

| | Tripo | Meshy |
|---|---|---|
| runs | 24 | 21 |
| credits | 960 in the sidecars, 1,000 charged | 360 |
| credits per run | 40 for every mode | 15 for one image, 30 for several views |
| USD per run | 0.40 | about 0.30 at the plan price, 0.60 for several views |
| seconds per run, median | 268 | 54 |
| seconds per run, range | 92 to 463 | 35 to 411 |
| triangles returned for each one asked | 1.27 to 2.30 | 0.89 to 1.09 |
| barrel as its own part | only with its parts option, which drops the texture and the low-poly mode | in every low-poly run |
| failures | 8 runs refused with error 429 when 16 ran at once. One run returned an empty response but was charged 40 credits. The script now waits and retries | none |

Tripo's face limit probably counts four-sided faces, so a model comes back with 1.3 to 2.3 times the triangles asked. Meshy's multi-view mode uses its `meshy-7.1` model, not the low-poly `meshy-t2`, so those runs return one fused piece.

Every run, one row each. Ratio is the triangles returned for each one asked. Loose parts are counted after welding the texture seams.

| gun | run | API | input | asked | triangles | ratio | loose parts | credits | seconds |
|---|---|---|---|---|---|---|---|---|---|
| small | meshy-a-1000 | Meshy | a | 1000 | 1064 | 1.06 | 10 | 15 | 45 |
| small | meshy-b-300 | Meshy | b | 300 | 321 | 1.07 | 5 | 15 | 50 |
| small | meshy-b-1000 | Meshy | b | 1000 | 1086 | 1.09 | 9 | 15 | 50 |
| small | meshy-b-3000 | Meshy | b | 3000 | 3137 | 1.05 | 13 | 15 | 50 |
| small | meshy-c4-1000 | Meshy | c4 | 1000 | 1037 | 1.04 | 1 | 30 | 93 |
| small | meshy-barrel | Meshy | barrel | 1000 | 1070 | 1.07 | 1 | 15 | 65 |
| small | meshy-mount | Meshy | mount | 1000 | 901 | 0.9 | 13 | 15 | 54 |
| small | tripo-a-1000 | Tripo | a | 1000 | 1722 | 1.72 | 2 | 40 | 208 |
| small | tripo-b-1000 | Tripo | b | 1000 | 1812 | 1.81 | 1 | 40 | 219 |
| small | tripo-b-parts | Tripo | b, parts option | 1000 | 894 | 0.89 | 9 | 40 | 93 |
| small | tripo-b-3000 | Tripo | b | 3000 | 3812 | 1.27 | 1 | 40 | 250 |
| small | tripo-c4-1000 | Tripo | c4 | 1000 | 1888 | 1.89 | 2 | 40 | 263 |
| small | tripo-c2-1000 | Tripo | c2 | 1000 | 1844 | 1.84 | 1 | 40 | 242 |
| small | tripo-barrel | Tripo | barrel | 1000 | 1416 | 1.42 | 1 | 40 | 229 |
| small | tripo-mount | Tripo | mount | 1000 | 1972 | 1.97 | 1 | 40 | 255 |
| medium | meshy-a-1500 | Meshy | a | 1500 | 1562 | 1.04 | 21 | 15 | 35 |
| medium | meshy-b-500 | Meshy | b | 500 | 521 | 1.04 | 17 | 15 | 35 |
| medium | meshy-b-1500 | Meshy | b | 1500 | 1585 | 1.06 | 29 | 15 | 41 |
| medium | meshy-b-4000 | Meshy | b | 4000 | 4175 | 1.04 | 35 | 15 | 41 |
| medium | meshy-c4-1500 | Meshy | c4 | 1500 | 1529 | 1.02 | 2 | 30 | 105 |
| medium | meshy-barrel | Meshy | barrel | 1000 | 1046 | 1.05 | 5 | 15 | 35 |
| medium | meshy-mount | Meshy | mount | 1500 | 1503 | 1.0 | 51 | 15 | 47 |
| medium | tripo-a-1500 | Tripo | a | 1500 | 2381 | 1.59 | 33 | 40 | 273 |
| medium | tripo-b-1500 | Tripo | b | 1500 | 2659 | 1.77 | 15 | 40 | 294 |
| medium | tripo-b-parts | Tripo | b, parts option | 1500 | 1410 | 0.94 | 17 | 40 | 92 |
| medium | tripo-b-4000 | Tripo | b | 4000 | 5918 | 1.48 | 1 | 40 | 356 |
| medium | tripo-c4-1500 | Tripo | c4 | 1500 | 2658 | 1.77 | 25 | 40 | 353 |
| medium | tripo-c2-1500 | Tripo | c2 | 1500 | 2239 | 1.49 | 7 | 40 | 307 |
| medium | tripo-barrel | Tripo | barrel | 1000 | 1430 | 1.43 | 4 | 40 | 260 |
| medium | tripo-mount | Tripo | mount | 1500 | 3002 | 2.0 | 25 | 40 | 327 |
| large | meshy-a-3000 | Meshy | a | 3000 | 3001 | 1.0 | 63 | 15 | 131 |
| large | meshy-b-1000 | Meshy | b | 1000 | 1016 | 1.02 | 30 | 15 | 59 |
| large | meshy-b-3000 | Meshy | b | 3000 | 2942 | 0.98 | 51 | 15 | 114 |
| large | meshy-b-8000 | Meshy | b | 8000 | 7095 | 0.89 | 198 | 15 | 59 |
| large | meshy-c4-3000 | Meshy | c4 | 3000 | 3089 | 1.03 | 1 | 30 | 411 |
| large | meshy-barrel | Meshy | barrel | 1500 | 1353 | 0.9 | 35 | 15 | 103 |
| large | meshy-mount | Meshy | mount | 3000 | 2981 | 0.99 | 84 | 15 | 65 |
| large | tripo-a-3000 | Tripo | a | 3000 | 6110 | 2.04 | 97 | 40 | 379 |
| large | tripo-b-3000 | Tripo | b | 3000 | 6910 | 2.3 | 93 | 40 | 323 |
| large | tripo-b-parts | Tripo | b, parts option | 3000 | 2873 | 0.96 | 35 | 40 | 108 |
| large | tripo-b-8000 | Tripo | b | 8000 | 12155 | 1.52 | 103 | 40 | 454 |
| large | tripo-c4-3000 | Tripo | c4 | 3000 | 6278 | 2.09 | 74 | 40 | 463 |
| large | tripo-c2-3000 | Tripo | c2 | 3000 | 6238 | 2.08 | 49 | 40 | 407 |
| large | tripo-barrel | Tripo | barrel | 1000 | 1814 | 1.81 | 22 | 40 | 229 |
| large | tripo-mount | Tripo | mount | 3000 | 6665 | 2.22 | 73 | 40 | 336 |

All runs per gun on one sheet: [small](../../../assets/3d/cannon/previews/all.png), [medium](../../../assets/3d/cannon22a/previews/all.png), [large](../../../assets/3d/cannon33a/previews/all.png).

## Experiment 1: which API

The same clean view (b) and the same face count through both APIs: [small](../../../assets/3d/cannon/previews/1-api.png), [medium](../../../assets/3d/cannon22a/previews/1-api.png), [large](../../../assets/3d/cannon33a/previews/1-api.png).

- **Small and medium guns: Meshy keeps the sketch.** The barrel is round with its rings, the bore is open, the yoke and the cradle keep their shape, the wood shows its grain. Tripo makes them blockier, with an eight-sided barrel on the small gun.
- **Large gun: both are close.** Both keep the geared housing and the turntable. Tripo spends twice the triangles on it.

## Experiment 2: which input

The painted sketch (a), the clean view (b), four views (c4) and front and back only (c2): [small](../../../assets/3d/cannon/previews/2-inputs.png), [medium](../../../assets/3d/cannon22a/previews/2-inputs.png), [large](../../../assets/3d/cannon33a/previews/2-inputs.png).

- **Meshy takes the painted sketch directly.** Its guns from a and from b differ little on all three sizes.
- **Several views gave the large gun the right proportions on both APIs.** From one image both made its barrel stubby. From four views the barrel is as long as in the sketch's side view.
- **Several views broke Tripo's small and medium guns.** From c4 and c2 the small barrel became a short open tube, and the medium gun lost its barrel: only the cradle and the side plate remain. Both faults are confirmed in magnified crops. This matches the warning that generated side views can disagree with the front.
- **Tripo from the sketch** left dark triangles in the small post's texture, a flat cap without a bore on the small muzzle, and a broken medium cradle with loose fragments beside it. All three faults are confirmed in magnified crops.

## Experiment 3: the barrel as its own part

Two sheets per gun. The first shows the models: the whole gun, the parts the API returns, and the barrel and the mount made apart: [small](../../../assets/3d/cannon/previews/3-barrel.png), [medium](../../../assets/3d/cannon22a/previews/3-barrel.png), [large](../../../assets/3d/cannon33a/previews/3-barrel.png). The second shows the split in Blender, with the barrel at its lowest and highest tilt, 10 degrees down and 45 up: [small](../../../assets/3d/cannon/previews/3-barrel-split.png), [medium](../../../assets/3d/cannon22a/previews/3-barrel-split.png), [large](../../../assets/3d/cannon33a/previews/3-barrel-split.png).

- **Meshy's parts, split off in Blender, work on the small and medium guns.** Both parts are closed meshes. The barrel's rings on the medium gun are separate pieces around it and go with the barrel.
- **On the large gun Meshy's barrel comes in several pieces.** The automatic selection took the main tube but left a breech band behind on one run and the rear half on another. Choosing the pieces by hand is a few clicks.
- **Barrel and mount made apart, then joined, work on both APIs.** The join sizes and places them like the parts of the same API's whole gun.
- **A cut through a fused mesh tears it** on the small and medium guns: slivers of the barrel stay on the mount and the barrel opens where it met the yoke. On the large gun, whose barrel stands free of the housing, the cut came out clean on both APIs.
- **Tripo's parts option** returns real parts, but untextured and lumpy, because it cannot run in the low-poly mode.
- **The pivot.** The split puts the trunnion axis above the centre of the footprint when it finds no trunnion pins. On the medium gun the breech then swings into the cradle at 45 degrees. The real trunnion sits at the cap on the side plate, so the pivot needs setting by hand per gun.

## Experiment 4: the face count

Meshy at three counts and Tripo at two, from the clean view: [small](../../../assets/3d/cannon/previews/4-faces.png), [medium](../../../assets/3d/cannon22a/previews/4-faces.png), [large](../../../assets/3d/cannon33a/previews/4-faces.png). The last column shows each gun from the game camera at the default view, 24.7 px a tile, magnified.

- **At the default view the counts look the same.** 300 and 3,000 triangles give the same small gun on screen.
- **Zoomed in, the low counts show.** At 300 the small gun's barrel has eight sides and the post shows its facets. At 500 the medium gun's barrel turns angular. From 1,000 on the barrels read round.
- **The bible's budget of 600 triangles per building** fits the small gun at the default view. The medium and large guns need more to keep their detail when zoomed in, which is a change to the budget for Sebastian to decide.

## Experiment 5: how many views

Sebastian asked whether fewer views would do. On the large gun, Meshy ran one side view, the clean view through `meshy-7.1`, front and side, clean view and side, and front, side and back: [large gun](../../../assets/3d/cannon33a/previews/5-views.png). The small and medium guns ran the side view against the clean view and four views: [small](../../../assets/3d/cannon/previews/5-views.png), [medium](../../../assets/3d/cannon22a/previews/5-views.png).

| run | model | views | barrel length | parts | credits | seconds |
|---|---|---|---|---|---|---|
| meshy-b-3000 | t2, low poly | three-quarter | stubby | yes | 15 | 114 |
| meshy-v1-left-3000 | t2, low poly | side | as in the sketch | yes | 15 | 69 |
| meshy-v1-b71-3000 | 7.1 | three-quarter | as in the sketch | no, one piece | 30 | 70 |
| meshy-v2-fl-3000 | 7.1 | front, side | as in the sketch | no | 30 | 203 |
| meshy-v2-bl-3000 | 7.1 | three-quarter, side | as in the sketch | no | 30 | 198 |
| meshy-v3-3000 | 7.1 | front, side, back | as in the sketch | no | 30 | 204 |
| meshy-c4-3000 | 7.1 | front, side, back, three-quarter | as in the sketch | no | 30 | 411 |

- **The number of views does not matter.** The short barrel came from the low-poly model reading the three-quarter view. The 7.1 model keeps the length from that same view alone.
- **One side view on the low-poly model is the best input.** It keeps the length, returns the parts, costs 15 credits and took 36 to 69 s. On the medium gun it is the most faithful model of the round: the barrel, the large side disc and the cradle all match the sketch.

## The bench in Godot

[tools/gun_test.tscn](/home/womb/repos/cannonade/tools/gun_test.tscn) in the game repo is an editable scene with twelve Meshy models: per gun the lowest, the middle and the highest face count from the clean view, and the side-view model. Columns run by vertex count, lowest on the left. The small guns stand in front, the large ones at the back, each on its footprint in grass tiles under the afternoon sun.

- **Open it** in the Godot editor from the project in [/home/womb/repos/cannonade](/home/womb/repos/cannonade).
- **Turn a gun.** Select its node `gun` and rotate about Y.
- **Tilt the barrel.** Expand `gun`, select `barrel` and rotate about X. A positive angle raises the muzzle. The barrel's origin sits on the trunnion axis, found by [barrel.py](../../../../pipeline/barrel.py) from the trunnion caps, or at the footprint centre on the small guns, whose yoke sits centred.
- **The red dot** is `projectile_spawn` at the muzzle.
- **The labels** give vertices and triangles. The vertex count is what the GPU gets, split at texture seams and sharp edges.

## Sebastian's picks and the cleanup

On the bench he picked the second-lowest face count of each gun (D37): the small gun from the clean view at 1,086 triangles, the medium from the side view at 1,450, the large from the clean view at 2,941. He found two faults, and both went back to Blender:

- **Pieces of the body moved with the barrel.** The automatic split had put the small gun's trunnion pin and a cap at the foot of its yoke, the medium gun's bolt heads on the side plates, and the large gun's trunnion stubs, bearing plates and housing plates on the barrel.
- **The small gun's yoke floated** 2.5 cm above its wooden post.

The cleanup is now a step of the route, done by hand for each gun in its `split.json`: [small](../../../assets/3d/cannon/split.json), [medium](../../../assets/3d/cannon22a/split.json), [large](../../../assets/3d/cannon33a/split.json). The piece sheets show every piece numbered: [small](../../../assets/3d/cannon/previews/pieces-meshy-b-1000.png), [medium](../../../assets/3d/cannon22a/previews/pieces-meshy-v1-left-1500.png), [large](../../../assets/3d/cannon33a/previews/pieces-meshy-b-3000.png). The final sheets show the barrel tilted with nothing left behind: [small](../../../assets/3d/cannon/previews/final.png), [medium](../../../assets/3d/cannon22a/previews/final.png), [large](../../../assets/3d/cannon33a/previews/final.png). The pivot is the centre of the pin or of the trunnion stubs. The post now reaches the yoke, checked in magnified crops before and after. The three `final.glb` files replace the second column of the bench.

## Spend

The route test cost 19.45 USD: Tripo 9.60 USD by the sidecars plus 0.40 USD for the charged run without a model, Meshy 7.20 USD at the plan price, fal 2.25 USD for the input images. The views test added 3.30 USD of Meshy credits, 22.75 USD in all against the raised cap of 25 USD.

## Still open

1. Sebastian's verdict from the bench: the face count per gun, and whether the side-view models win.
2. The picked guns in the game's art layer, with the pivot checked per gun.
3. Palette colours: the models carry Meshy's painted texture. Whether they keep it or move to flat palette colours is roadmap B6.
