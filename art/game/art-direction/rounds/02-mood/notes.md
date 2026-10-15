# Round 02 notes

Phase A, mood and theme. Four candidate worlds in [themes.md](themes.md), six frames each through `google/nano-banana-2.1/edit` with the round 01 anchor and two or three references attached, see [round.json](round.json). 24 images, 3.60 USD, plus two critiques at 0.03 USD each. One board per candidate: [board-toy-harbour.jpg](board-toy-harbour.jpg), [board-lighthouse-islands.jpg](board-lighthouse-islands.jpg), [board-river-town.jpg](board-river-town.jpg), [board-shipwright-yard.jpg](board-shipwright-yard.jpg). The reference collage per candidate is `refs-<slug>.jpg`.

## Director's read, provisional

1. **lighthouse-islands**: the most coherent board. The fog, the cream horizon and the checker grid came through in every frame, the fortress frame stays as readable as the anchor, the harbour at dawn and the battle are the two frames of the round a stranger would stop on. The sky frame is the one that could become the panorama. The palette is softer than the anchor, which is the one thing to watch against the brief's "saturated".
2. **river-town**: the closest to River Towns and Foundation, the warmest colours, the best material sheet. The fortress frame packs houses inside the walls, which is what the game does, but the cannons are hard to find among the roofs. The harbour frame went yellow. The busiest board, so the readability risk is the highest of the four.
3. **toy-harbour**: the fortress frame is the anchor repeated, which proves the reference conditioning works and adds nothing. The coast, harbour and battle frames put the island on a literal wooden table in a room, because the prompt said "on a sunlit table". That is a prompt fault, not a world. Taken as a diorama identity it is a real option, but it was not what D15 picked.
4. **shipwright-yard**: the clearest era story and the best fit for the ingredient metaphor, timber, stone and iron stacked in the yard. Also the brownest, the most cluttered and the least cosy board. The fortress frame would not read at 13 pixels.

A merge worth naming: the lighthouse islands' sea, fog and sky with the market town's roofs and material warmth. The world stays small and airy, the buildings get River Towns' saturation.

## Faults in the images

- toy-harbour: the table and the room in three frames, from "on a sunlit table" in the prompt. The fortress frame is near identical to the anchor.
- lighthouse-islands: the roof in the material sheet is a red and white checker, which belongs to the lighthouse, not to a house. The coast frame joins three islands with bridges.
- river-town: the harbour frame is yellow all over. The fortress courtyard is full, so the three cannons hide.
- shipwright-yard: the harbour frame is dark for a cosy game. The material sheet added a crane and a forge on its own, both fit.
- All four: the edit endpoint kept the anchor's low-poly look and the visible grid, so the boards differ in world and not in render style, as intended.

## Critics

Gemini ranked toy-harbour, lighthouse-islands, river-town, shipwright-yard. GLM ranked toy-harbour, river-town, shipwright-yard, lighthouse-islands. Both put toy-harbour first, both on the readability argument: the simplest ground, the strongest contrast, team colours sit on it without a fight. Both call lighthouse-islands' fog and soft palette a readability risk, Gemini as fixable, GLM as the riskiest board. Both call river-town too dense inside the walls. Both propose the same merge, toy-harbour's forms and materials with river-town's warm colours and half-timber architecture. The director ranked lighthouse-islands first, so this round the two critics agree with each other and not with the director. Second calibration point for roadmap A6, resolved by Sebastian's pick.

Note on the critics' reading: Gemini saw a wooden table edge in the toy-harbour battle frame and read it as a deliberate diorama. GLM named felt and cork as its materials. Both took a prompt fault as a design choice, which is one reason the director does not count the toy-harbour board as evidence for the toy world.
