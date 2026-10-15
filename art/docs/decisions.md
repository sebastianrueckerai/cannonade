# Decisions

One entry per decision, newest last. Never reverse one silently. Propose a change as a new entry that names the one it amends.

## D1. Work from a roadmap in sessions (2026-10-11, Sebastian)

[ROADMAP.md](../../ROADMAP.md) holds everything we want or might want, including ideas and spikes. A session pulls items by ID into a plan in `docs/sessions/NN-slug.md`, refines them, ships them, ticks them.

## D2. Process and game content are separated (2026-10-11, Sebastian)

[game/](../game) holds everything specific to Grid Cannons: the art kit and the assets. Everything else is the process and stays game-agnostic, so a new project copies the repo and replaces [game/](../game).

## D3. One shared art kit feeds every production line (2026-10-11, from the ChatGPT discussion)

Text rules, numeric values and approved anchor images in [game/art-direction/](../game/art-direction). The 3D world, the UI, the identity and the store art all read their subset of it. A failure that spans domains is fixed in the kit, not in the consumers.

## D4. Procedural Blender is the default 3D route (2026-10-11, from the ChatGPT discussion)

The game is modular, geometric and mechanically constrained. The coding agent builds assets from primitives with exact dimensions, named parts and pivots. Image-to-3D is the tested alternative for complex silhouettes. Both routes pass the same normaliser and the same acceptance test.

## D5. Low poly, flat palette as the working default (2026-10-11, Sebastian)

Low poly is decided. Flat shared materials from `palette.json` are the default until roadmap B6 decides flat against textured after the vertical slice.

## D6. Blender through the direct socket for modelling, MCP tools for inspection (2026-10-11, from docs/blender.md)

`blx script.py` for every build, normalise, render and export step. The MCP server's tools only to pick apart a file somebody else built. Measurements in [blender.md](blender.md).

## D7. Every artefact is reproducible and judged by an independent critic (2026-10-11, carried over from the portfolio repo)

Every generated image or mesh gets a sidecar JSON with model ID, prompt, references, parameters, seed and cost. The model that wrote a prompt is never the only judge of its output. Only Sebastian's pick is a decision.

## D8. Game changes are made from here, committed there (2026-10-11, Sebastian)

Changes to [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons) happen in sessions planned in this repo and land on its `master`. We touch the art layer, the export pipeline and the preview scene. Gameplay code only when a session plan names it.

## D9. Numbers before pixels (2026-10-11, from docs/blender.md)

A mesh is checked by its geometry report first, by a small render sheet second, by a viewport screenshot last. Vertex arrays never enter the conversation.

## D10. A real release on itch.io and Steam is the aim (2026-10-11, Sebastian)

The browser demo on a small VM is the first milestone, the store pages come after the art exists. The marketing stage carries the real Steam and itch.io sizes (roadmap E5, E6).

## D11. The world is a coastal fortress in the age of cannon and sail (2026-10-11, Sebastian)

Stone walls, bronze cannons, wooden ships, harbours. No real nation, no real flag. Confirms the session 01 assumption.

## D12. Wiring before art (2026-10-11, Sebastian)

No image or mesh production until the game can take the files and run in the browser. Session 02 built that. Round 02 waits for the picks.

## D13. Art enters the game through one folder (2026-10-11, Sebastian asked for drop-in swapping)

`res://assets/art/` in the game repo. A `3d/<id>.glb` replaces the placeholder of the building, ship, tile or wall with that id. Parts named in snake_case attach to prefab pivots named in PascalCase. Sizes are checked against `manifest.json` once on load, and a mismatch shows on the menu and fails the test suite. Without a file the placeholder stays. The theme applies to the splash, menu and loading screens only until the HUD is styled (roadmap D2), because a project-wide theme resized the sandbox panel.

## D14. The middle ages are allowed where they help (2026-10-11, Sebastian)

Amends D11. Age of sail stays the base for castles and ships, and the look may dip into the middle ages where required. No constraint to modern forts. References in [inspirations/notes.md](../game/art-direction/inspirations/notes.md), River Towns is the strongest match.

## D15. Direction: the toy-harbour world frame (2026-10-11, Sebastian)

[toy-harbour-world--nanobanana.png](../game/art-direction/rounds/01-directions/toy-harbour-world--nanobanana.png) is by far the best of round 01 and the anchor of the art direction. Bright, cosy, easy to make out, the grid tastefully done. The toy-harbour menu frame is rejected. Notes for the depth round, not a hybrid: the elevation of the ink-chart world, the River Towns level of detail, the saturated but cosy palette and lighting of the references, the small fogged islands of A Monster's Expedition. The references in [inspirations/](../game/art-direction/inspirations/) stay unlabelled where the agent could not name the game.

## D16. The era ladder: the big guns outgrow the age of sail (2026-10-11, Sebastian)

Age of sail with medieval elements is the base. The advanced cannons go industrial, steampunk, World War One sized artillery, because the game wants big guns the age of sail never had. Not right away: the ladder is tier 0 medieval and age of sail, tier 1 bigger bronze guns, tier 2 iron and early industry, tier 3 steampunk and heavy artillery. Phase F of [art-direction.md](process/art-direction.md) draws it.

## D17. Simple cannons first, the upgrade tree after, the ingredients need a visible form (2026-10-11, Sebastian)

The existing building set is not complete. Some cannon variants are advanced but untested, and the shield is in doubt. The simple cannons come first. The first version of the upgrade tree is decided after they exist. The advanced cannons are built by stacking the resources the game gives, so those resources need a visual metaphor: candidates are wood, stone, iron, blocks of tools, gear sets. The metaphor is picked with the upgrade tree v1.

## D18. Art direction starts broad and every plan says why (2026-10-11, Sebastian)

The first session 03 plan was rejected: it jumped to reference views of five assets, named without a reason, with no bible behind them. The stage now runs mood, colour, shape, lighting, the cross-domain rules, the era ladder, the bible, the asset list, then the first item per essential class, each with Sebastian's pick, as [art-direction.md](process/art-direction.md) says. A complete vision first, iterative after. Every session plan names why each deliverable exists and what it feeds. D15 stays as the starting anchor of the mood phase, not as its result.

## D19. A round shows at most 25 new images, iteration inside it may make more (2026-10-11, Sebastian)

The image limit of a round is on what Sebastian is shown, not on what is generated: at most 25 new images per round in the contact sheet and the picks file. Inside a round the agent may iterate past that count to get the sheet right, inside the session's spending cap, which stays the hard limit. Every generated image keeps its sidecar whether it reaches the sheet or not.

## D20. The world: the toy harbour with the shipwright's structures (2026-10-11, Sebastian)

The painted toy fortress world of round 01 and of round 02 board 1 is the world of Grid Cannons. From the shipwright's island, board 4, come the towers and the yard structures: cranes, slipways, scaffolds, the forge, stacked timber, stone and iron. The market town, board 3, is noted as also nice and is not merged. The lighthouse islands are out. The tileset must build island, river and pure land maps, so the world is a table of tiles, the sea is one tile kind among others, and nothing in the identity depends on being an island. The literal table and room in three toy-harbour frames were a prompt fault, not part of the world. Round 02 calibration: both critics ranked toy-harbour first, the director ranked it third.

## D21. Palette: market-warmth, team colours corrected (2026-10-11, Sebastian)

Of the three palettes of round 03, Sebastian picked market-warmth: orange tile roofs, green grass, a bluer sea, warm cream stone, the market town's warmth on the toy world. His first answer was fogged-teal, changed minutes later before the commit, so this entry records only the second. Values in [palette.json](../game/art-direction/palette.json). Both critics and the director ranked market-warmth first, for the clearest hierarchy at 13 pixels. The four team colours become blue #2d55c4, purple #7b2fa3, teal #197059, olive #8c7a1f, because the game's deep blue and purple were two dark blocks side by side at 13 pixels. The game's `scripts/Main.gd` follows in a later session (roadmap F10).

## D22. Shape and detail: the River Towns level, faceted and sharp (2026-10-11, Sebastian)

Of the six fortress corners of round 04, Sebastian picked 4: the River Towns level of detail, a door, two windows, a chimney and a crate or a barrel per building, in the faceted and sharp language with the anchor's own chamfer. No bevel correction, so the chamfer is 0.05 m on a one metre block. Numbers in [geometry_rules.yaml](../game/art-direction/geometry_rules.yaml). The rounded and chunky column was rejected: the edits turned a tenth-of-a-block bevel into a quarter and the fortress into clay. Foundation was rejected as noise at the default view. Gemini ranked 2, 4, 1, 6, 3, 5, GLM 1, 2, 3, 4, 6, 5, the director 4, 2, 6, 3, 1, 5. Sebastian's pick was the director's first and Gemini's second. The round also showed that the look holds on a river map and on a pure land map, and that the shipwright's structures survive the toy simplification, with the scaffold and the slipway as zoomed-view landmarks.

## D23. Lighting: afternoon sun from the front right, a fog band at the horizon, a flat sea (2026-10-11, Sebastian)

Of the six lightings of round 05, Sebastian picked 3, afternoon: the sun from the front right at 45 degrees, medium shadows, warm light on the lit faces, a cream fog band at the horizon that never reaches the board, a flat blue sea with a foam line as a zoomed-view detail. Numbers in [lighting_rules.yaml](../game/art-direction/lighting_rules.yaml), the frame is [world_style.png](../game/art-direction/anchors/world_style.png), the one image every downstream prompt attaches. Gemini ranked 1, 3, 2, 4, 6, 5, GLM 1, 3, 2, 6, 4, 5, the director 3, 1, 2, 4, 5, 6: noon was the critics' first for readability, afternoon keeps noon's edges and adds the brief's warmth. Rejected: overcast, because without a cast shadow the wall base merges with the sand path at 13 px; the depth fog, because it covers the far tiles the player builds on; the evening, because its sea becomes a painting and its shadows hide the cannons. Two rules came with the pick: every wall casts a base shadow on its ground tile, and the game lights the world in the engine from the rules, never by recolouring a frame, because two of the five relights moved the palette.

## D24. The 2D art is a separate painted style that shares the game's theme, and a title is judged on a capsule (2026-10-11, Sebastian)

Sebastian rejected round 06. It made the menu, the splash screen and a store image by editing the world anchor, so every frame kept the game's low-poly render look. It also showed the three title studies on their own, on a flat sky.

His reasons:

- **2D art is its own style.** The splash screens and above all the store art are painted 2D illustrations. They use the game's theme, its elements and perhaps its colours, but not its render look.
- **Other games do the same.** My Time at Portia is a 3D game and Doloc Town a pixel-art game. Each sells itself with a painted 2D capsule that has the logo inside the painting.
- **A title cannot be judged on its own.** It is judged on a capsule that advertises the game, as part of the painting.

None of the three title studies was good. The painted sign was the best of them. Study 2 looked grimy, like a horror game. Study 3 looked stiff, like Age of Empires. Study 1 looked like old WordArt and not like wood.

What changed in the bible: the game world and the UI keep the rules of chapters 2 to 4. The menu, the splash screen, the store art and the trailer title cards are painted illustrations that share the theme and its motifs, and never pretend to be screenshots. Round [07-key-art](../game/art-direction/rounds/07-key-art/PICKS.md) started phase E again with painted key-art candidates.

## D25. The key art: two castles in a cannon duel, seen from above, with the title as a separate layer (2026-10-12, Sebastian)

From rounds 07 to 13, Sebastian picked [a3-pasted.png](../game/art-direction/rounds/13-tower-swap/a3-pasted.png) as the main image of the store art. It is now [marketing_style.png](../game/art-direction/anchors/marketing_style.png). It combines three images of round 11: image 1 as the base, the tower house of image 2 as the far keep, and the broken front wall of image 8.

The picture is a painted land map seen from above, with a river and the tile grid. Two different castles stand on it:

- **The near castle** has a square keep, a timber lookout and a red flag. Its front cannon fires one shot at the far castle.
- **The far castle** has a tower house with a stepped gable and a blue flag. Its front wall shows the damage of an earlier hit.

The title is not painted into the picture. It goes on later as a separate layer, because the lettering must stay editable and clear at capsule size.

Sebastian's rules from the seven rounds are kept in the [checklist](../game/art-direction/rounds/10-duel-checked/checklist.md). Every key-art image is checked against it in crops magnified 2x and 4x before he sees it:

- Castles shoot at castles, not at ships.
- Exactly one cannon fires, and its ball flies along the line of its barrel.
- Cannons stand inside the walls on the courtyard floor, pointing up at about 45 degrees. They never stand on a wall or a tower.
- All cannons are the same size.
- The two castles are clearly different.
- The walls are straight and follow the grid.
- The land is not bare.
- The image carries no text.

Rejected on the way: the game's render look for 2D art (round 06, D24), ships as the subject, a view too close to show the game, round walls, and a bare field.

## D26. The game is released as Cannonade (2026-10-12, Sebastian)

The game's public name is Cannonade. The store pages, the title logo, the window title, the splash screen and the menu say Cannonade.

Grid Cannons stays the project name. It is the name of the repositories and folders, the name in code, and the name in these documents.

The title logo is the word CANNONADE in the lettering of D25, see [typography.yaml](../game/art-direction/typography.yaml) and round [15-cannonade](../game/art-direction/rounds/15-cannonade/PICKS.md). In the game repository, commit `4aac46a` on `master` changed `config/name` in `project.godot` and the fallback title text of the splash screen and the menu.

## D27. The title lettering: white letters with a dark brown outline (2026-10-12, Sebastian)

Round [15-cannonade](../game/art-direction/rounds/15-cannonade/PICKS.md) lettered CANNONADE in three styles:

- **a:** white letters.
- **b:** white letters with a dark brown outline.
- **c:** cream letters with an outline and a red shadow.

Sebastian picked b. It still reads at 120 px wide on the small store capsule, where plain white letters blur into the sky. Both critics also ranked it first.

The logo is [logo.png](../game/art-direction/anchors/logo.png), and the store set is [set-b-outline/](../game/art-direction/rounds/15-cannonade/set-b-outline). The game uses the set's logo, splash screen and menu background, game repository commit `7042fb2`.

## D28. The guns: one gun per footprint size, standard artillery in dark iron, each size better than the last (2026-10-12, Sebastian)

Every footprint in the game is a square of whole tiles, and the game data has guns on 1, 2 and 3 tiles. So the era ladder has three steps, one gun per size. This narrows the four tiers of D16 to three:

- **1 by 1:** medieval and age of sail.
- **2 by 2:** bigger guns.
- **3 by 3:** iron and early industry.

Sebastian's rules for every gun, from his comments on round [16-era-ladder](../game/art-direction/rounds/16-era-ladder/PICKS.md):

- **Standard artillery.** A classic cannon with one barrel. No multiple barrels, and no mortars. Mortars come later as sidegrades.
- **Each size is better than the last.** Every gun looks visibly better and more advanced than the gun below it. A bigger gun is never the same model scaled up.
- **Dark iron.** Every gun's main colour is dark iron grey. Bronze for the small guns and iron for the big ones would confuse the eye.
- **Wood on the small guns.** The small guns may use wooden parts. Iron replaces the wood on the bigger guns.
- **No wheels.** A gun only turns. It never drives. It sits on a round turning mount.
- **No platform.** The gun is the attraction, so it fills its footprint and stands on nothing else.
- **Sizes read.** Guns of different sizes never look the same size.
- **Cozy.** Friendly and toy-like, painted in the style of the references.
- **Shields as variation.** A round shield suits a big gun. A small half shield, perhaps with a visor slit, suits a smaller one.

Sebastian rejected round 16 as a whole. Its sheets looked like low-poly renders (D30), and its four guns came from the plan's tiers, not from his needs. The rules above stand. The gun designs are open, and phase F starts again in session 06 from these rules.

## D29. The resource blocks: four boxes of the same size, one per material (2026-10-12, Sebastian)

Resource blocks are box-shaped, for three reasons. A box is easy to see on the board. A box visibly drops into a square field. Boxes stack.

Every block has the same size, about 0.8 by 0.8 by 0.6 m, filling most of its tile. There is one block per material, with no second variant for now. Sebastian picked four:

- **Timber:** a wooden crate with log ends at its corners.
- **Stone:** stacked cream stone blocks.
- **Iron:** dark iron ingots with no wooden box. Two layers of three ingots, the upper layer turned 90 degrees, form a box, and a stepped pyramid of ingots sits on top. The block reads as a box with a triangle on top, not as a triangle.
- **Gears:** an open wooden crate with one big iron cog inside.

He dropped the log stack, the brick block and the tool chest. The game has three resources today, so one block is a reserve. Which block stands for which resource is decided with the first upgrade tree (D17).

## D30. Concept sketches are paintings, not low-poly renders (2026-10-12, Sebastian)

A concept sketch for a later 3D asset is a painting. It has loose brushwork, painted light, and the colours and shapes of the bible. It looks like a concept artist's sheet, cozy and bright, in the style of the concept paintings and the store capsules Sebastian gave as references. A sketch shows things. It is not an exact 2D template for a 3D model.

A sketch never imitates the low-poly game render. A sketch decides form and proportion. A fake render looks like bad 3D before any 3D exists.

Round 16 broke this rule. The rule covers phase F and the sketches of phase I.

## D31. The three guns and the iron block (2026-10-12, Sebastian)

From the painted boards of round [17-painted-sketches](../game/art-direction/rounds/17-painted-sketches/PICKS.md), Sebastian picked:

- **The small gun, 1 by 1:** an iron swivel gun on a thick wooden post with an iron foot. He picked it because it is very different from the next size.
- **The medium gun, 2 by 2:** a long iron gun in an iron-fitted wooden cradle on an open iron ring, with a riveted side plate. It is not too long.

- **The large gun, 3 by 3:** board 4's geared iron gun on a heavy riveted turntable, with its round shield removed. He chose it over board 3's long gun with a telescope.

The three guns stand together on [gun_ladder.png](../game/art-direction/anchors/gun_ladder.png), small to large.

The iron block is rebuilt with fewer, bigger bars, and each layer turns 90 degrees against the one below, the single top bar included. The other three blocks stay as painted on board 6.

## D32. Two blocks in the game: timber is block A, iron is block B (2026-10-12, Sebastian)

Amends D29. The game has two block types, `upgrade_a` and `upgrade_b`. Supply is not a block. It is a number that the supply depots produce. D29 counted supply as a third resource and kept one block as a reserve. The correct count is two blocks, so two of the four designs are reserves.

- **Block A, `upgrade_a`, is timber:** the crate with log ends. Timber placed on timber makes the supply depot.
- **Block B, `upgrade_b`, is iron:** the crossed ingots.
- **Stone and gears** are reserves for a later upgrade tree.

D17 left this mapping to the upgrade tree v1. Sebastian picked it now, because the blocks are two of the three building draws and need models in the first batch. Timber is warm brown and iron is dark grey, so the two read apart at the default view.

## D33. The first batch of 3D models (2026-10-12, Sebastian)

The first batch is the set a versus match shows most:

- **One standard gun per size:** `cannon`, `cannon22a`, `cannon33a`, from [gun_ladder.png](../game/art-direction/anchors/gun_ladder.png) (D31).
- **The supply depot,** `supply`.
- **The two blocks,** timber and iron (D32).
- **The four wall shapes at both heights.** A wall stacks once, so each shape has a lower and an upper model.
- **The base,** the player's fortress.
- **The tile,** with its colour variations from the palette.
- **The cannonball,** a sphere built in Blender.

Not in the first batch: the cluster gun, the flak, the shield, the rocket station, the 2x2 depot, the other gun variants, the ship and nature. They keep their placeholders. Making the bigger guns better in play is game design for the upgrade tree v1 (B18). Today every plain gun fires the same shot. The engine light of [lighting_rules.yaml](../game/art-direction/lighting_rules.yaml), roadmap C11, comes with the batch, because no screenshot can show the bible's look without it.

## D34. The guns come from image-to-3D first, the procedural build is the last resort (2026-10-12, Sebastian)

Amends D4 for the guns. An artillery piece can look complex, so an agent writing Blender Python part by part is the last resort. Rework in Blender is allowed: cutting, reducing, recolouring, setting pivots and scaling. Building the gun outright in Blender is not, for now.

The first guns are a test. Every experiment runs twice, once on Tripo and once on Meshy, and the results are compared side by side. The test cases are the three guns of [gun_ladder.png](../game/art-direction/anchors/gun_ladder.png). The test answers four questions:

1. **Which API is better,** Tripo or Meshy.
2. **Which input works:** the painted three-quarter sketch as it is, a clean three-quarter view repainted from it, or front, side and back views.
3. **How the barrel becomes its own part,** because the game turns the whole gun to aim sideways and tilts only the part named `barrel`. Three ways: the whole gun cut in Blender, the parts returned by the API, or the barrel and the mount generated separately and joined in Blender.
4. **Which face count balances the look and the budget.** Both APIs take a target count as a parameter. The models are low poly: a few hundred vertices for the small gun, up to a few thousand for the large one. Each API makes a ladder of counts.

## D35. Git LFS for new binaries, the history stays (2026-10-12, Sebastian)

Decides roadmap A9. The repository passed 900 MB with the route test. Images, models and Blender files added from now on go to Git LFS: `.png`, `.jpg`, `.jpeg`, `.webp`, `.glb`, `.blend`, `.fbx`. The files committed before stay plain git files and are named one by one in [.gitattributes](../.gitattributes), because moving them would rewrite every commit and need a force push. A clone needs `git lfs install` once.

## D36. Meshy does the 3D work, Tripo gets simple shapes (2026-10-12, Sebastian)

From round 18. Meshy makes the game's 3D models: it was faster, cheaper, more exact on the face count, returned the barrel as its own part, and kept the sketches better. Tripo's remaining API credits go to simple shapes where its weaknesses matter less, such as trees and rocks, until the balance is used up.

## D37. The first three guns, their face counts, and the cleanup by hand (2026-10-12, Sebastian)

From the bench in the game, Sebastian picked the second-lowest face count of each gun:

| gun | model | triangles |
|---|---|---|
| small, `cannon` | Meshy low-poly from the clean three-quarter view | 1,086 |
| medium, `cannon22a` | Meshy low-poly from the side view | 1,450 |
| large, `cannon33a` | Meshy low-poly from the clean three-quarter view | 2,941 |

This decides roadmap B19. The guns get their own budget in [geometry_rules.yaml](../game/art-direction/geometry_rules.yaml): about 1,100, 1,500 and 3,000 triangles from small to large, above the 600 of a building.

He also found that every barrel carried pieces of the body, and that the small gun's yoke floated 2.5 cm above its post. So the cleanup in Blender is a required step of the generative route, not an option. Each gun's `split.json` names by hand the pieces that move with the barrel, the pieces that give the pivot, and the fixes, step 4 of [assets-3d.md](process/assets-3d.md).

## D38. The first wall look, the depot and base designs, the block face count (2026-10-12, Sebastian)

From round [19-first-batch](../game/art-direction/rounds/19-first-batch), with the boards open:

- **Wall look 1 is board 2, the cornice:** square merlons standing on a band that projects from both faces of the wall, no ledge at the foot, plain cream stone. The ledge of board 1 and the walkway of board 3 are the candidates for looks 2 and 3. In the game Sebastian found that the walls look good, at the default view and zoomed in, [07-battle-wall.png](sessions/07-battle-wall.png). So the first real wall confirms chapter 3 of the bible.
- **Every merlon stands on one tile.** The game sets each tile to its own height, up to 0.1 m up or down, so a merlon split across two tiles showed a step. The tile seam falls in a gap between merlons, and every junction gets a solid corner post.
- **The depot: all four designs,** for variety. **The base: designs 1, 3 and 4 of the board,** not the round tower. Each design is a look of the same game id, `supply`, `supply.2` and so on, and the game picks one look at random for each building.
- **The blocks: the 600-triangle runs,** 572 for the timber crate and 490 for the iron ingots. At 300 the crate lost its side panels and the iron came out melted.
- **The ground colours** from the palette pass.

## D39. Every gun stands on a square plate (2026-10-12, Sebastian)

Amends D28, which said that a gun stands on nothing else. Sebastian: a round gun is hard to make out on the grid, so every gun sits on a rectangular plate in the gun's colour, and the plate shows which grid squares it stands on.

- The plate covers the footprint less 5 cm on each side, 0.1 m tall, with a 3 cm chamfer on its top edges. Its colour is the area-weighted grey of the iron faces of the gun's own texture.
- The gun turns to aim, the plate stays square to the grid.
- Each gun budget includes the plate's 20 triangles, so the small gun's budget is 1,150.
- The white ring over the guns is the game's cooldown indicator. It cut through the taller art gun, so it now floats above the highest point a raised barrel reaches. Sebastian keeps it there for now.

## D40. The base is a 2x2 building (2026-10-12, Sebastian)

A 1x1 base looked small. Sebastian asked for a 2x2 or 3x3 building that is a clear landmark. From three scales of design 1 at 3x3, [07-base-3x3-options.png](sessions/07-base-3x3-options.png), he took option B, the keep 2 m wide and its proportions kept, standing exactly on 2x2 tiles.

- In the game the base is 2x2, and its start ring is 12 walls in a 4x4 square instead of 8 in a 3x3 square. [base.tres](/home/womb/repos/grid-cannons/data/buildings/base.tres), `build_start_base` in [PlayerController.gd](/home/womb/repos/grid-cannons/scripts/components/PlayerController.gd), the new layout of [Sandbox.gd](/home/womb/repos/grid-cannons/scripts/sandbox/Sandbox.gd) and the two example scenarios in [data/scenarios/](/home/womb/repos/grid-cannons/data/scenarios) changed with it.
- The keep is 1.9 m square, the footprint less 5 cm on each side like the gun plates, and 4.3 to 5.4 m tall depending on the design.

## D41. Nature is redone: bigger and more stylized, like the cover art (2026-10-12, Sebastian)

The old nature props are much too small, and restyling them is not enough. Every nature kind is made new, in the look of the cover art, [marketing_style.png](../game/art-direction/anchors/marketing_style.png):

- **Bigger.** Round-crowned trees whose crown is about a tile wide, standing in groves, a few conifers among them, and piles of rounded boulders about a tile across.
- **More stylized.** Chunky, simple forms that read as trees and rocks at the default view.

This replaces the rule of chapter 3 that trees are cones or icospheres and rocks are angular with 6 to 10 faces. The nature round of session 08 sets the new numbers. Roadmap C5 becomes a replacement, not a restyle.

## D42. Every base shows its team colour on a flag and a coloured roof (2026-10-12, Sebastian)

A flag and a team-coloured roof are the rule for every base. Base design 2, the keep with battlements, had only a flag and a banner, which barely showed at the default view. Its flat deck inside the battlements is its roof, so the deck is now team-coloured too, through `team_deck` in its [cleanup.json](../game/assets/3d/base.2/cleanup.json). [07-bases-ai4.png](sessions/07-bases-ai4.png) shows all three designs in the four team colours.

## D43. The cornice is the only wall look (2026-10-12, Sebastian)

Amends D38, which kept the ledge and the walkway of round 19 as candidates for wall looks 2 and 3. With the three boards and the cornice in the game open, Sebastian chose one look only, over mixing the looks piece by piece and over one look per fortress. Every wall slot keeps the cornice, and session 08 spends that time on nature.

## D44. The nature looks of round 20 (2026-10-13, Sebastian)

From the painted boards of [round 20](../game/art-direction/rounds/20-nature/PICKS.md): every variant of every board becomes a look, three per kind, and the C4 route comparison ran on board 2's left boulder. The picked boards set the palettes and proportions the assets carry.

## D45. Bushes and trees are procedural solids; the image-to-3D verdict narrows to boulders (2026-10-13, Sebastian)

Session 08 built its bushes and trees through Tripo after C4 picked Tripo over the procedural build on a boulder. The result was clusters of intersecting flat planes with an opaque green texture: the providers represent foliage as leaf cards, the fal Tripo v2.5 endpoint takes no prompt text, so the reference image was the only control, and the JPEG texture export strips any alpha. Two gates failed on it.

Bushes and trees go back to the procedural route the route table always named: closed round meshes built in Blender, painted by a generated gradient texture, palettes from the D44 picks. C4's verdict stands where it was earned, on boulders and other hard-surface irregulars. Amends the session 08 plan; the acceptance ladder gains the wireframe view and the solidity number that would have caught the card clusters (recorded with the process changes of the same commit).

## D46. The nature gate, round 3, fails on look (2026-10-13, Sebastian)

The procedural rebuild stood up structurally: closed solids on the wire view, solidity 0.63 to 1.0, byte-identical rebuilds, clean in game. Sebastian rejected the look: "It all looks like shit. Its also still untextured." The vertical gradient material, painted for the D41 storybook look, reads as an untextured flat colour at game size. Nothing is approved; the game repo holds the uncommitted force-sync of the nine assets. Nature gets a texture and look round in a later session; session 08 moves on to the ship on Sebastian's word. D45 stands.

## D47. The ship is the caravel (2026-10-13, Sebastian)

From the painted board of [round 21](../game/art-direction/rounds/21-ship/PICKS.md): design 1, the single-masted caravel with one big cream square sail and a red pennant. The simplest silhouette and the closest to the cover art's fleet. The longship and the brig stay unpicked.

## D48. The ship passes its gate (2026-10-13, Sebastian)

Round 2 of the ship gate failed on the cannon ("cut off, lacks a lower part and the back of the barrel, not merged with the ship"). The rework answers it: a full breech ring and cascabel knob clear of the mast, a tapered pedestal and sunken base plate bedding the gun into the foredeck, the barrel overhanging the stem. Gate 3 passes on the rebuilt board: four Blender close-ups, the hull sheet, and 3x in-game crops. 208 gun tris, 1408 total. The two standing bars behind the rework, "show assets big on boards" and "the game must look decent zoomed in", go into [assets-3d.md](process/assets-3d.md) with this session's close-out.

## D49. Nature textures are painted, not flat palette bands (2026-10-13, Sebastian)

From [round 22](../game/art-direction/rounds/22-leaf-tree-texture/PICKS.md): the same leaf-tree mesh twice, only the material differing, judged at full size, crown and base magnified, the trunk/canopy seam at 2x, and the same in-game tree at 3x. The painted texture wins: D44 storybook stops, scalloped contact shadow, crease, brush noise, dabs, bark dashes. The flat palette bands that had been the default since D5 lose and are deleted. C5 ports the painted path into nature_build.py as the only material path for all nine looks.

## D50. The nature set passes its look gate (2026-10-13, Sebastian)

The C5 gate board ([round 22](../game/art-direction/rounds/22-leaf-tree-texture/PICKS.md)): nine looks on the D49 painted path, bush, leaf tree and boulder x three D44 palettes, every part magnified per D48, trees with a 2x trunk-seam strip, the in-game grove crop at the bottom. The Gemini critic passed it before Sebastian saw it (painted read on all nine, no artifacts, looks distinct, no clone-read at gameplay distance); Sebastian passed the board. The nine nature assets are approved and ship to the game repo. Shape variety stays on the per-look proportions and seed noise of D45: no second construction this round.

## D51. The first game needs no new nature: the approved three kinds close the set (2026-10-13, Sebastian)

Mid-session 10, with the six-kind boards already generated: "Wait, are oyu remaking all nature assets? Thats not neccessary. we only need rocks and bushes and trees for now." and "I want just the things done we need for a first game - the 3 basic cannons of different sizes, walls and buildings, ground... and the upgrades and supply depos!" Every item of that list already stands in the game from sessions 06 to 08 (D33 first batch, D37 to D43). C5's remaining six kinds (big leaf tree, evergreen, grass, mushroom, stones, twiggy) are parked until the first game wants them; the game's nature draw is trimmed to the approved bush, boulder and leaf tree (D50) so no old FBX prop appears. The round 23 boards and edits are kept as artifacts, unpicked. The open look question — session 07's palette-material guns, walls and buildings beside session 09's painted nature — is Sebastian's next pick, not a default.

## D52. The shipped look is soft_honey, the split of cozy_grid and honey_grid (2026-10-14, Sebastian)

From [round 25](../game/art-direction/rounds/25-look/PICKS.md): after eight candidates and three reworks built on his feedback ("1 and 5 look nice and soft and cozy, but 4 makes the individual tiles pop more which may be neccessary for the player making out the grid"), Sebastian picked with "Maybe split the difference between 9 and 10 and ship that". soft_honey is that midpoint: the soft and warm round 24 skies blended 50/50 into one panorama, a #ffd29d sun at 0.65 energy and 38 degrees over a #bec3c4 ambient of 0.46, shadow 0.56, #f4e6cd fog touching the sky at 0.2, and the game's first grade — filmic tonemap, exposure 0.97, white 6.25, saturation 1.07, contrast 1.05, glow 0.26, all GLES3 safe. This amends the round 05 rule "no colour grading in the game" to "the grade stays mobile friendly, the palette still carries the mood". The Gemini ship critique returns "Ship as is" with one friction: the ivory trees can read stone or withered from afar, which is a session 11 repaint item on the assets, not a look change. C11 is remeasured under the pick (wall face R -0.4% G +0.5% B +0.6%), and render.py now carries the grade through game_view so every Blender preview renders under the shipped look.

## D53. The walls paint in the subtle stone grain (2026-10-14, Sebastian)

From [round 26](../game/art-direction/rounds/26-repaint/PICKS.md): of the four painted stone candidates rendered under the shipped look, Sebastian picked 1 subtle, and it lands on all nine wall pieces through the `paint:` block in each asset.yaml (pipeline/blender/paint.py, kind stone, seed 41). This amends the chapter 7 rule "no texture drawn on a wall face": the face now carries the painted grain and merlon weathering, with nothing drawn on top of it — no stone courses, no slits. At the default view the wall still reads as clean cream stone, so the chapter 3 rule about what 13 pixels show is unchanged.

## D54. The ivory trees repaint deep, all three looks (2026-10-14, Sebastian)

The D52 ship critique's friction: all three leaf-tree looks washed pale at the lit crown tops under soft_honey and could read stone or withered. Of the candidates on the round 26 board Sebastian picked the deep repaint for all three looks — deeper, more saturated crown stops, same paint structure, same seeds. The bushes and boulders stay as approved (D50).

## D55. The gun plate detaches from the turning gun (2026-10-14, Sebastian)

At the C12 gate Sebastian passed the set but named the fault: the plates swung with the gun on every re-aim. Root cause: ArtPlate corrected the plate in _process, one frame behind the aim turn, and guns re-aim every battle tick. The plate now detaches from the turning subtree (top_level in ArtPlate.gd): its world transform is set once, no turn can move it, no lag frame exists. Probe and re-shot battle verify it; the round 26 re-critique passes.

## D56. soft_honey's sky value is the haze-band hex (2026-10-14, agent)

Data correction to the D52 record: the variant's `sky:` held a prose description, which crashed the first asset.py run against the picked variant (render.py parses the value as a colour). It is now "#f7e3c0", the haze band the C11 rig always used, with the panorama named in the comment. No look change.

## D57. A gun shows its reload as a team-tinted ring round its foot, then a red pulse (2026-10-14, Sebastian)

From [round 27](../game/art-direction/rounds/27-indicators/PICKS.md). The floating white ring above the gun read as a sticker over the toy, so Sebastian asked for a ring round the gun's base instead, and then a plate pulse at the ready moment: "Try a ground ring, where the ring is really around the gun in question ... Maybe have the whole ground plate then pulse red once when it reloads?" The colour went through three answers: not bright red, then the gun's iron tone, then "the cannon color tone shifted toward the player's color", with the aim "clearly visible but not to badly destroy the cozy atmosphere". Of three strengths shot on both forts he picked A, the subtle one: the plate iron #544d52 shifted 0.35 toward the owner's team colour. The ring lies flat on the plate, centred on the gun's mount and sized to it, and its band thins outward to nothing over the reload; at ready the plate pulses the kit's ui_accent red once over 0.7 s. Rejected on the way: a hot barrel cooling to iron, the plate filling with a warm tint, the barrel slumping and rising, and the shipped ring laid flat. Every candidate was built in the game and shot in a real sandbox battle.

## D58. The aim arc is thin, fades toward the landing, and only the human's guns draw it (2026-10-14, Sebastian)

From the same round. The shipped arcs were full-width team-colour wires that every gun of every side kept through its reload. Sebastian picked the tapered arc: 0.045 m wide, 0.9 opacity at the muzzle fading to 0.15 at the landing, cleared the moment the shell flies and drawn again at the next aim. Only the human player's guns draw it; with no human (AI against AI) every side does. Rejected: no arc, a flat band on the ground, a ring on the target tile only, round puffs along the path.


## D59. The game's rules v2: the Rampart enclosure, the base as the flag, every shot by hand (2026-10-14, Sebastian)

From a brainstorm on the game's problems before any more assets. The picks: enclosure is checked once, at the end of the build phase, and the guns fire the whole battle, because today the first breach switches off the whole fort and a battle is over in about 6 s. A side whose base is open at the check is out. The base takes no damage, every other building is a target, as in Rampart. Every shot is placed by hand, gun by gun through one queue with a skip, and only the flak fires itself. The AI plays with the same draws and queue, with a reaction time and a switch time to tune. The numbers come from the lab, one AI per gun, with an ablation test that cuts any gun whose removal costs no wins. A Tetris hold slot replaces the free discard. Rejected on the way: a point score ("lame"), a base with three hits ("then why kill walls?"), walls with more health ("this is not tower defence with lots of health"), auto-fire for the swarm. Sebastian also wants one experiment after v1: build and shoot in one phase. The whole rule set is [rules.md](../game/design/rules.md). Its section 14 names four defaults that wait for his review. For the assets: the roster shrinks to five guns and three depots, the mortar and the flak are the next image-to-3D rounds, the shield and the rocket station are parked, and nothing gets a damaged model.

## D60. The mortar, the flak and six depot looks of round 28 (2026-10-14, Sebastian)

From the painted boards of [round 28](../game/art-direction/rounds/28-advanced-buildings/PICKS.md), with the boards open. The mortar `cannon22b` is board 1's design 1, a fat pot mortar between riveted cheek plates on an open ring. The flak `flak22` is board 2's design 1, a twin gun in a boxy cradle on a ball on a short pedestal. Every design of the two depot boards becomes a look, as with the 1x1 depots of D38: "All of them lets have some variety just like with the smaller supply depots" and "same here, all or them!" That gives `supply22` to `supply22.3` (a log yard, a plank store with a lean-to, a pyramid-roof shed) and `supply33` to `supply33.3` (a long warehouse with a gantry, a granary on posts with a ramp, a barn with a gantry tower). The cluster bomb is a banded iron ball and the shard a chunk of iron, both procedural. At the gate Sebastian passed all ten: "Pass, ship all ten".

## D61. Every gun stays inside its square, and the flak is smaller (2026-10-14, Sebastian)

At the gate the flak's guns, aiming low, swung 0.5 m over the next tile and through the mortar. Sebastian: "Make the whole thing smaller on its base and if needed shorten the barrels a bit. The flag can be less massive than other guns." Then: "Also maybe make the mortar slightly smaller... it seems to somewhat overlap the 2x2 square it should be on. The guns should be contained to their squares!"

This amends D39 and session 11b, which let a barrel overhang its plate. The gun build now scales every gun until its mount and its moving part stay inside the plate at every turn and every tilt the game gives them, 2 cm short of the plate's edge. A barrel tilts from -10 to 90 degrees, and the flak's guns aim from level to straight up. All five guns were rebuilt that way, measured by their height above the plate: the small gun at 0.75 of its old size, the heavy gun at 0.80, the siege gun at 0.81 and the mortar at 0.85. The flak, with 25 percent shorter barrels, stands at 0.52, 1.66 m tall against 3.08 m. The factors are larger than the old overhang suggests, because a turning gun sweeps a circle: the muzzle ring's corners set the reach, and the barrel reaches farther at -10 degrees than at level. The reload ring of D57 is capped at the plate's half side, so it stays on the plate too.

## D62. Cannonade is steered from the game repo, blender-ai keeps a copy (2026-10-15, Sebastian)

Amends D2. Sebastian: "I want to steer the project from the project folder for grid-cannons now", "The repo here should only have the template for the art generation in 2d and 3d", "Move everything the project needs there, including a copy of your env.tool keys. Also the skills or docs documenting how to make art and ressocurces. But keep a copy here as well", and "Make it so it also has all the plans there, like our musing about gun combos". The whole of blender-ai, laid out the same way, is copied to this folder, [art/](/home/womb/repos/grid-cannons/art) in the game repo: the process and its docs, the pipeline, the art direction, every model's sources, rules v2, the decisions, the roadmap and the session plans. The game repo takes no Git LFS, so it commits the anchors, the inspirations, each model's final, source.blend, source run and input views, about 200 MB. The round images and render previews are on disk here, ignored, and stay versioned in [blender-ai](/home/womb/repos/blender-ai) with Git LFS. The keys are copied to the ignored `art/.env.tools`. From this date this copy is the live one. blender-ai keeps its copy as the template and its worked example.

## D63. One roadmap for the game, the art and the process (2026-10-15, Sebastian)

Amends D1. Sebastian: "It now has two roadmaps. Merge them, the newer one takes precedence." The art kit's roadmap and the game's roadmap are one file, [ROADMAP.md](../../ROADMAP.md) at the repository root. The art kit's items keep their IDs A1 to H6 and its rules: a session pulls items by ID into its plan, ticks them in the same commit, and strikes an item through with the reason instead of deleting it. The game's rounds A to D, their leftovers, ideas, maybes and known issues became sections I, J and K. Where the two disagreed, the newer side won: the art roadmap's rules, and rules v2 ([rules.md](../game/design/rules.md)) over the older game ideas, which are struck through with the section that decides them. The tag game-repo became game, as there is one repository.

## D64. No 3x3 guns for now (2026-10-15, Sebastian)

Amends D59. Sebastian: "No siege gun for now, dont delete assets but the game should be limited to 1x1 and 2x2 guns." The game has 1x1 and 2x2 guns only. `cannon33a`, `cannon33b`, `cannon33c` and `rocket_station` stay in [data/buildings/](../../data/buildings) with their models and art, marked with the new field `parked`, so no recipe, draw or Sandbox palette offers them. A full 3x3 square of blocks merges one of its 2x2 squares. Bringing the siege gun back is unticking `parked` in its file.

## D65. The loading screen shows concept art (2026-10-15, Sebastian)

Sebastian: "When I play a game it takes a while to load. There should be concept art being shown there and not the same image as on the initial screen!" The loading screen shows one piece of concept art at random behind its bar, never the key art of the splash and the menu ([marketing_style.png](../game/art-direction/anchors/marketing_style.png)). The first set is five anchors, picked by the agent as a default: [world_style.png](../game/art-direction/anchors/world_style.png), [structures.png](../game/art-direction/anchors/structures.png), [shape_corner.png](../game/art-direction/anchors/shape_corner.png), [resource_blocks.png](../game/art-direction/anchors/resource_blocks.png), [structures_toy.png](../game/art-direction/anchors/structures_toy.png). The gun ladder is left out, as it shows the parked siege gun (D64). Sebastian picks the final set.
