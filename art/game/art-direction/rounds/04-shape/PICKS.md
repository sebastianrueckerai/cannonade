# Picks, round 04: shape language and detail level

The same fortress corner of the colour anchor redrawn six times, so the comparison is shape and detail only. One sheet: [picks-sheet.jpg](picks-sheet.jpg), rows are the detail levels, columns the shape languages. [corner-13px.png](corner-13px.png) shows the anchor and the six at the game's default view, a tile 24.7 px wide, magnified four times. With them, as information for the pick, not as options: the shipwright's structures in the toy language, [structures-sheet--nanobanana.png](structures-sheet--nanobanana.png), and the river and the land map next to the island, [maps-sheet.jpg](maps-sheet.jpg) and [maps-13px.png](maps-13px.png). The draft rules are in [geometry_rules.yaml](../../geometry_rules.yaml), the pick fills the numbers.

| | rounded and chunky | faceted and sharp |
|---|---|---|
| Kingdoms and Castles, the least detail | 1 | 2 |
| River Towns, the middle | 3 | 4 |
| Foundation, the most | 5 | 6 |

The chunky column overshoots: the prompt asked for a bevel of a tenth of a block and the edit made a quarter, so 1, 3 and 5 look like clay. The anchor itself is the sharp column with a small chamfer. If neither column is right, name the bevel in centimetres on a one metre block.

Critics, at the true 13 px scale: Gemini ranks 2, 4, 1, 6, 3, 5, GLM ranks 1, 2, 3, 4, 6, 5. Both put 5 last and say the Foundation props add nothing at the default view. They disagree on the language: Gemini says sharp keeps the battlements and the gate, GLM says the chunky bevel keeps the wall a solid mass. The director ranks 4, 2, 6, 3, 1, 5, see [notes.md](notes.md): the River Towns level with the anchor's chamfer. Both critics on the half-scale sheet, before the test was fixed, ranked 2, 4, 6, 1, 3, 5. Your pick is the decision and goes into [docs/decisions.md](../../../../docs/decisions.md) and into [geometry_rules.yaml](../../geometry_rules.yaml).

## Pick one level and one language, by number

- [ ] 1 Kingdoms and Castles, rounded and chunky
- [ ] 2 Kingdoms and Castles, faceted and sharp
- [ ] 3 River Towns, rounded and chunky
- [x] 4 River Towns, faceted and sharp
- [ ] 5 Foundation, rounded and chunky
- [ ] 6 Foundation, faceted and sharp
- [ ] bevel correction: ______ cm on a one metre block

## Also on the sheets

- The structures: all eight read at full size. Both critics would drop the scaffold or the slipway at the default view, the director keeps them as zoomed-view landmarks with thick posts. The tower on the sheet carries stone courses the walls do not, it will follow the wall rule.
- The maps: both hold without the sea. The cream wall against the yellow sand path is the weakest edge on every map, so phase D owes every wall a base shadow.

## Pick

Sebastian, 11 October: 4, River Towns, faceted and sharp, no bevel correction, so the anchor's own chamfer stays. Decision D22. Gemini had 4 second, GLM fourth, the director first.

## Comments
