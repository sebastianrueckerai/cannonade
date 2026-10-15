# Round 05 notes

Phase D, lighting and atmosphere. First the colour anchor redrawn at the picked level and language of D22, River Towns in faceted and sharp, as [1-noon--nanobanana.png](1-noon--nanobanana.png): the base of the round and the noon variant in one. Then five relights of it through `google/nano-banana-2.1/edit` with the base attached, see [round.json](round.json): morning, afternoon, fogged, overcast, evening. 6 images, 0.90 USD, plus two critiques. The 13 pixel test is [light-13px.png](light-13px.png), a tile 24.7 px wide, magnified four times.

The base kept the anchor's camera, island and palette and added what the level asks: chimneys, doors, barrels, crates, and three houses outside the walls that the prompt did not ask for. They stay, a world frame may have houses outside the walls.

## Director's read, provisional

The relights kept every object and the camera in all five. What moved is the light, the sky, the sea and, in two frames, the palette.

- **1 noon**: the anchor's light. Short hard shadows, a plain sky, a flat sea. Everything reads. The base shadow under a wall is one tile short, so the cream wall against the sand path is at its weakest here.
- **2 morning**: a low sun from the left, long soft shadows to the right, cool pale light, a glare in the top-left corner and a sparkle on the sea. The long shadows separate every wall from its ground, and they also fall across tiles the player must read. The saturation drops a step.
- **3 afternoon**: a sun from the front right, medium shadows, warm light on the lit faces, a cream fog band at the horizon, the sea flat blue. The walls separate from the sand by warm against cool, the grid stays, nothing of the board is lost. The brief's saturated and cosy light.
- **4 fogged**: depth fog from mid-board, the far pier and the ships half gone, the island floating in cream. The mood of A Monster's Expedition, and on a 30 tile board the far rows the player builds on would be in the fog at the default view.
- **5 overcast**: no sun, no shadows. The sea turned grey-blue, a drift from the palette. The walls still read by their lit top against their faces, and the sand edge is the worst of the six: nothing separates the wall base from the path. The control case: the shadows carry the readability.
- **6 evening**: an orange sky and a sea full of streaks. The water became a painting that competes with the island, the grass went olive and the stone pink, the cannons inside the yard are the hardest to count. A store still, not the game.

Director's ranking for the game's default view: 3, 1, 2, 4, 5, 6. The afternoon light with the horizon fog band.

## Faults in the images

- 5 and 6 moved the palette: the sea in 5, the grass and the stone in 6. A relight must not recolour the surfaces, which argues for the game doing the lighting in the engine from the rules, never from a frame.
- 2 put a sun glare into the frame corner, an object the prompt did not ask for.
- 4's fog starts too near. The rule puts the fog start past the far edge of the buildable board.

## Reproduce the composites

```
uv run --script pipeline/px13.py --tile-px 52 --centre 0.42,0.55 --window 300x169 --cols 3 --out game/art-direction/rounds/05-light/light-13px.png "1 noon=game/art-direction/rounds/05-light/1-noon--nanobanana.png" "2 morning=game/art-direction/rounds/05-light/2-morning-world--nanobanana.png" "3 afternoon=game/art-direction/rounds/05-light/3-afternoon-world--nanobanana.png" "4 fogged=game/art-direction/rounds/05-light/4-fogged-world--nanobanana.png" "5 overcast=game/art-direction/rounds/05-light/5-overcast-world--nanobanana.png" "6 evening=game/art-direction/rounds/05-light/6-evening-world--nanobanana.png"
```
