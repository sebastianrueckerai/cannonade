# Brief: Grid Cannons, released as Cannonade

The open fields hold the session 01 assumptions. Round 01 explores tone through contrasting directions instead of fixing it in words first. Sebastian corrects the assumptions in PICKS.md or here.

## The game

A turn-based build and battle game in the spirit of Rampart. Build phase: place rotatable wall pieces and buildings on a tile grid to enclose areas. Battle phase: cannons inside closed walls fire. Upgrade blocks in 2 by 2 or 3 by 3 patterns merge into bigger guns, flak, rocket stations, shield generators or supply depots. Modes: one player against a ship fleet, player against AI, AI against AI with 2 or 4 sides.

## Constraints that shape the art

- Low poly. Flat palette by default (D5), textured is open (B6).
- Runs in the browser. Godot 4.7, gl_compatibility renderer, 1280 by 720.
- Readable from the gameplay camera. At the default view a tile is 25 px wide and a 1 m wall is 12 px tall. Zoomed in, 96 px. Numbers in [gameplay_contract.yaml](gameplay_contract.yaml). Walls, cannons, upgrade patterns and team ownership must read at the default view. Detail only has to read zoomed in.
- Four team colours exist in the code and must stay distinguishable: deep blue, purple, teal green, olive.
- Maps are island, river or pure land, generated from one tileset. The look must work on all three: the sea is one tile kind, not the frame of the world (D20).
- One identity across world, UI and store art.
- No Atari material. Rampart is the inspiration, not the source.

## Assumptions, session 01

- Tone: saturated but cosy colours and lighting, a readable grid, the River Towns level of detail. Direction: the toy-harbour world frame of round 01 (D15). Sebastian, after round 01.
- Audience: people who liked Rampart and short tactical rounds, and visitors of the browser demo who come to see the process. A real release on itch.io and Steam is the aim (D10), so the art must make a store screenshot worth a second look.
- Era and place: a coastal fortress world in the age of cannon and sail, dipping into the middle ages where it helps. No constraint to modern forts. No real nation, no real flag. Confirmed and widened by Sebastian (D11, D14).
- The game must never look like: photoreal, gritty war, horror, a pixel-art copy of the original, or generic asset-store low poly with no identity of its own.
- Inspirations: supplied, see [inspirations/notes.md](inspirations/notes.md). River Towns is the strongest match.

## Game-design notes that shape the art (Sebastian, 11 October)

- The existing building set is not complete. Some cannon variants are advanced but not tested enough. The shield is in doubt. Do the simple cannons first, then decide the first version of the upgrade tree (D17).
- Advanced cannons are built by stacking the resources the game gives. Those resources need a visual metaphor that stacks: wood, stone, iron, blocks of tools, gear sets are the candidates (D17).
- Age of sail with medieval elements is the base, but the game wants big guns in the end, which the age of sail never had. The advanced tiers stretch into industrial, steampunk, World War One sized artillery. Not right away, only for the advanced cannons (D16).
- The full asset set is named in [asset_list.md](asset_list.md). Production starts with the essentials and grows the variants from them.
