# Round 04 notes

Phase C, shape language and detail level. The fortress corner of the colour anchor, [refs/corner.png](refs/corner.png), redrawn six times through `google/nano-banana-2.1/edit` with one detail reference attached per level, see [round.json](round.json): the Kingdoms and Castles screenshot, the River Towns screenshot, the Foundation screenshot, each with its interface cropped off, in [refs/](refs). Two languages per level, rounded and chunky against faceted and sharp. Then one sheet of the shipwright's structures in the toy language from [structures.png](../../anchors/structures.png), one river map and one land map from the colour frame. 9 images, 1.35 USD, plus four critiques, two of them on a wrong test, see below.

The 13 pixel test is [corner-13px.png](corner-13px.png): every edit scaled so a tile is 24.7 px wide, the default view of the gameplay contract, magnified four times without smoothing. [maps-13px.png](maps-13px.png) does the same for the three maps.

## The test was at half scale, now fixed

The round 03 test and the first sheet of this round scaled the frame so the fortress wall was 13 px tall, taking the wall for one metre. A ruler on the anchor says a tile is about 52 px wide there and the fortress wall about two tiles tall, so the frames were shown at under half the game's size. [teamcrop.py](../../../../pipeline/teamcrop.py) and the new [px13.py](../../../../pipeline/px13.py) now scale by the tile width, the anchor's [team_13px.png](../../anchors/team_13px.png) is re-rendered, and the two critiques on the half-scale sheet sit in [critique/half-scale/](critique/half-scale), ranking 2, 4, 6, 1, 3, 5 both. The team-colour verdict of round 03 stands, the base blocks were drawn at the real tile size and only the frame around them was small.

## Director's read, provisional

The edit kept the camera, the palette and every object in place in all six. The difference between the languages is bigger than the difference between the levels.

- **Rounded and chunky, 1, 3, 5** overshoot. The prompt asked for a bevel of a tenth of a block and the model made a quarter: the merlons are pillows, the grid softens, the keep turns to clay. Painted wood became plasticine. At the default view the walls still read, the notched top edge is softer than the anchor's.
- **Faceted and sharp, 2, 4, 6** are the anchor's own language. 2 is nearly the anchor itself: the anchor already has hard edges with a small chamfer. The chamfer is what makes the toy, so a hard zero bevel would lose it; the right number sits between the two columns, about 0.05 m.
- **Kingdoms and Castles, 1 and 2**: houses lose their door, the walls stay the same. Nothing is missing at the default view, the zoomed view is bare.
- **River Towns, 3 and 4**: a door, two windows, a chimney, crates by the gate. The walls stay plain slabs. At the default view the features are dots that read as life, not as noise.
- **Foundation, 5 and 6**: timber framing, tile ridges, a well, a cart, ball stacks, a balcony on the tower. The keep became a half-timbered house, a drift. At the default view the props are two-pixel lumps in the yard; zoomed in it is the ceiling of what the budget allows.

Director's ranking for the game: 4, 2, 6, 3, 1, 5. Level River Towns, language faceted and sharp with the anchor's chamfer.

## The structures

All eight read as what they are at full size: crane, slipway ribs, scaffold, tower, forge, timber, stone, iron. Two faults. The tower carries drawn stone courses, more than the fortress walls next to it, so the tower must follow the wall rule. The scaffold is thin poles, finer than any feature the default view can show, so it lives in the zoomed view or gets thick posts. The slipway ribs become one orange shape at the default view, which is fine for a yard landmark.

## The maps

Both hold. The river map reads as the same world with the river as a tile kind, banks of sand, one bridge. The land map reads too: grass, sand patches and grey rock tiles carry the grid without the sea. The weakest edge is the cream wall against the yellow sand path, on both maps and on the anchor. The lighting phase owes every wall a base shadow on its ground tile, which is the rule that separates stone from sand at 13 px.

## Faults in the images

- The six lost the small trees and tufts by the gate, and the chunky three lost the tile lines under the softened grass.
- Foundation replaced the keep's stone front with timber framing in both 5 and 6, a drift the prompt did not ask for.
- The structures sheet drew the wood lighter than the palette's wood swatch. The sheet is a shape reference, not a colour one.

## Reproduce the composites

From the repo root. The tile widths were measured with a ruler crop on each frame.

```
python3 -c "from PIL import Image; im=Image.open('game/art-direction/anchors/colour_frame.png').crop((220,200,1020,650)).resize((1600,900), Image.LANCZOS); im.save('game/art-direction/rounds/04-shape/refs/corner.png')"
uv run --script pipeline/px13.py --tile-px 95 --centre 0.5,0.55 --window 240x135 --cols 4 --out game/art-direction/rounds/04-shape/corner-13px.png "anchor=game/art-direction/rounds/04-shape/refs/corner.png@104" "1 kingdoms chunky=game/art-direction/rounds/04-shape/1-kingdoms-chunky--nanobanana.png" "2 kingdoms sharp=game/art-direction/rounds/04-shape/1-kingdoms-sharp--nanobanana.png" "3 rivertowns chunky=game/art-direction/rounds/04-shape/2-rivertowns-chunky--nanobanana.png" "4 rivertowns sharp=game/art-direction/rounds/04-shape/2-rivertowns-sharp--nanobanana.png" "5 foundation chunky=game/art-direction/rounds/04-shape/3-foundation-chunky--nanobanana.png" "6 foundation sharp=game/art-direction/rounds/04-shape/3-foundation-sharp--nanobanana.png"
uv run --script pipeline/px13.py --tile-px 78 --centre 0.5,0.5 --window 300x169 --cols 3 --out game/art-direction/rounds/04-shape/maps-13px.png "anchor island=game/art-direction/anchors/colour_frame.png@52" "river map=game/art-direction/rounds/04-shape/map-river--nanobanana.png" "land map=game/art-direction/rounds/04-shape/map-land--nanobanana.png"
uv run --script pipeline/teamcrop.py --frame game/art-direction/anchors/colour_frame.png --tile-px 52 --palette game/art-direction/palette.json --centre 0.45,0.5 --out game/art-direction/anchors/team_13px.png
```

The half-scale sheet the first two critiques judged, in [critique/half-scale/](critique/half-scale), was the same seven frames at 13 px per fortress wall, which is a tile of 196 px, with a window of 174 by 97.
