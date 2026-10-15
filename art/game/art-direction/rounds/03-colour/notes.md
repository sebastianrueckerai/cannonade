# Round 03 notes

Phase B, colour. Three palette candidates in `palette-<slug>.json`, swatch sheets in `swatches-<slug>.png`, each applied to the round 01 anchor frame through `google/nano-banana-2.1/edit` with the frame and the swatch sheet attached, see [round.json](round.json). The 13 pixel test per palette, `<slug>-13px.png`, comes from [teamcrop.py](../../../../pipeline/teamcrop.py): the recoloured frame scaled so a one metre wall is 13 px tall, a base block in each team colour pasted in, next to the four team colours and a wall on each ground colour, magnified four times. 3 images, 0.45 USD, plus two critiques. Everything on one sheet: [picks-sheet.jpg](picks-sheet.jpg).

## Director's read, provisional

The three frames differ less than the swatches do: the edit kept the composition and shifted the colours, the sea went bluer in market-warmth and paler in fogged-teal, the roofs went orange and red. All three keep the toy mood. The difference that matters is in the ground: market-warmth's grass is green where painted-toy's is yellow-green, and green ground is the better bed for olive and for the sand next to it.

1. **market-warmth**: the warmest and the clearest hierarchy. Orange roofs and bronze cannons sit on cream walls on green grass next to a blue sea, four colours that stay apart at 13 px. The warm stone separates from the sand better than the other two.
2. **painted-toy**: the anchor as it is. The yellow-green grass and the yellow sand are close in hue, and the cream stone sits between them, so on a pure land map the ground is three yellows.
3. **fogged-teal**: the bone white stone disappears into the pale sand at 13 px, and the softer grass takes saturation out of the one world Sebastian picked for its colours.

The team colours fail the test in every palette the same way: deep blue #1f1f5e and purple #4a1671 are two dark blocks side by side at 13 px, on every ground. Teal and olive read. The fix is in the game's colours, not in the palette: a lighter, redder purple. Proposal in [PICKS.md](PICKS.md).

## Faults in the images

- The edit does not hit the hex values. It moves each surface toward the swatch, which is enough for a comparison and not a measurement. The palette files hold the intended values.
- The sails lost their stripes in none of the three, the flags changed colour in all three.
