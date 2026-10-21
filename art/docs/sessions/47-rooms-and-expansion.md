# Session 47: a shared ring keeps the room open, and the AI expands
Sebastian, 2026-10-21: "Currently if there is a room that is closed by partially mine and
partially the enemies walls, it becomes a closed room (not sure who it belongs to) this is
wroing, it should be open until walls from one faction encirlce it." and "Also the ui seems
to stop building once it cant capture new castely anymore. Also wrong - It should try to
gain territpory by building the larghest rooms it can and also getting as close as possible
to my castles with walls as it can. The idea is that after demolishing my rooms, it might
be able to capture castles there later. And more rooms is an advantag in and off itself!"
Roadmap: I75, I76. Game code only, no art.
## The shared ring (I75)
Root cause: the enclosure flood (StatesMap.waterflow) is purely geometric; any region that
does not reach the map rim closes, and Map.ring_owner hands it to whoever borders most, tie
to the lower player number (D79's majority rule). A ring half one player's and half the
other's therefore closed as somebody's room.
ring_owner returns the one faction whose walls border the region, null when none or several
do; a region closes only when sealed. For a mixed border StatesMap asks per faction whether
a flood that may cross any wall but that faction's still reaches the map rim (_seals): the
faction whose walls encircle the region alone owns it (an outer ring of mine round a smaller
ring of the enemy keeps the ground between), and when none does the room stays open — open
colour, no owner, decorations kept, buildable under the standing rules, and the check treats
it as no ground at all: guns outside a closed ring burn, castles in no ring fall.
## The AI's expansion (I76)
Root cause: the AI's tiers were own castles, yards, claims, and yards were gated on gun room
under the parts cap. With every castle rung and no claim rankable, no plan had gaps: the AI
dropped piece after piece and looked idle. Changes:
- A fourth tier, rooms. When nothing else is open, the AI picks the largest room site that
  fits (5x5 inside, else 3x3) among free open ground in its reach, sited nearest a castle it
  does not hold — staging for a claim once the intervening walls fall, and territory in its
  own right, guns standing only inside own closed ground. Rooms are RingPlans like yards:
  held pieces cover their gaps, out-of-reach gaps are approached, guns land inside, and when
  one closes the next is picked.
- RingPlan loops may no longer run along another faction's walls (cost 2 became impossible):
  under the shared-ring rule such a ring never closes as the AI's, and plans sited through
  the human's walls had unfillable gaps. Claims blocked by enemy walls now wait for the guns
  to open them, which is the staging the quote asks for.
- _pick_room walks the ranking until the first buildable site instead of costing only the
  four best by proxy: the sites nearest the enemy are the ones the human's walls block, so
  the old cut returned "nothing" while viable sites stood further back. The first buildable
  site down the ranking is by definition the closest one to the enemy's castles.
- A ring that stands but does not seal (the fine-grid flood slips a diagonal pinch where the
  loop grazes existing walls) is a dud: RingPlan.done marks the game-sealed state and the AI
  replaces a gap-less room that never sealed.
## The checks
tests/walls_test _check_ground rewritten to the shared-ring rule (one enemy block in the ring
opens the room, ground and colour return when the block is the owner's again) plus nested
rings: an outer ring of one faction round an inner ring of another holds the ground between,
and one swapped block opens exactly the annulus, the inner heart staying the other's. Each
watched red on the majority code. flood_test still equals the old flood fill (0 mismatches).
tests/ai_test section 8: with every castle, yard and claim closed, wall tiles grow (20
blocks in 12 s), closed ground grows by a room, almost no piece flies, the room is a 5x5
sited 4 tiles from a castle the AI does not hold (17 from its own), and it closes in the
window. Watched red on the old code (static walls, pieces dropped, no room tier).
