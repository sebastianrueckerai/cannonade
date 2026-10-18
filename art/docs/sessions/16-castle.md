# Session 16: the castle, 3x3, in modules

The rules v3 draft ([rules-v3-draft.md](../../game/design/rules-v3-draft.md)) makes castles the win object: several on the map, claimed by enclosing, shot down over a match. The model must say "castle" at a glance from the gameplay camera and carry five damage states in which whole sections of storeys crumble, readable from bird's eye. It is one solid keep tower, a Bergfried (D68): one big building that fills its 3x3 footprint, no curtain walls, no gatehouse, no courtyard, nothing detached. A castle that wore its own walls around an inner tower would contradict the claim rule of section 2: the castle is the prize the players' own walls enclose. The keep sits low, wider than tall and at most half as tall as its footprint is wide, covering its 3x3 grid edge to edge with no grass margin, because the gameplay camera looks 60 to 71 degrees down and a tall tower hides the walls behind it (D68). It is a multi-part building, not a monolithic drum: one big main mass with smaller joined volumes, wings, annexes, small towers, every part touching with no gap, their size differences carrying the scale, plus a few scale details such as dormers, chimneys and an arched door, not many flags or window grids (D68). It stands in distinct storeys, so the damage states crumble whole sections.

## Deliverables

1. The painted sketch board of four keep designs, Sebastian's pick. Round 31 drew walled compounds and was stopped before the pick (D68); round 32 draws the Bergfried board.
2. The picked design as a 3x3 model on the generative route (reference view, Meshy ladder, meshsheet pick, cleanup), `game/assets/3d/castle/`.
3. If the model passes: five damage states as variants of the same castle, whole sections crumbled, top view readable. Their route follows from what the picked mesh gives us: per-piece edits in `source.blend`, or a hybrid rebuild. Only after Sebastian likes the healthy model.

Roadmap: C13. Budget: the standing 4 USD of this session cover the sketch round, the reference views and the Meshy ladder with room for one repeat.

## Limits

- The route table binds this class to generative on Meshy with the cleanup by hand (session 07, the base).
- The team colour is royal blue in the sketches, a separate first material in the model, on parts that read at the default view: roofs, flags, banners.
- Sketches are paintings in the marketing style, never the low-poly render look (D30). At most 25 images shown (D19).
- Every image and mesh keeps its sidecar. Every pick is Sebastian's, asked with the images open.
