# Session 42: placing needs a line of empty ground
Sebastian, 2026-10-21: "We currently allow to build a few tiles away from a existing wall tile
or castle. this is OK, but it should only be possible if there is a straight line of empty
terrain between the two walls. If there is an enemy wall between my wall and the field I wasnt
to build, building should be blocked.This way, if my enemy built a almost completed room, I can
not just place a wall inside that room. Also, I cant ever build in enclosed enemy rooms -. but I
think thats already the case."
Roadmap: I71. Game code only, no art. The enclosed rooms he remembers right: enemy ground
(Map.ring_owner) has refused a closed ring's inside to other players since the ring check
exists, and that stays; what was missing is the room still open, whose gap let the square reach
in.
## The change
One rule, one place: PlayerController._anchor_mask, whose mask every placement path reads
(wall pieces through can_place_piece, guns through canPlaceBuilding, the AI through the same
two). A tile is in reach only when _line_clear joins it to an own wall tile or a held castle's
tile: the Bresenham line between the two tiles crosses no standing structure, whichever
player's. Decorations and water carry no structure and never block; an own wall between does
not lose the reach either, the nearer wall becomes the anchor. Range and the Chebyshev square
are unchanged.
The mask is a snapshot of the board, and only the builder's reach went stale on a placement.
An enemy's wall could not move a player's reach under the old range rule, so nobody noticed;
under the line rule an enemy wall falling has to reopen the line. BuildingPlace.build and
un_build now call _board_changed, which stales every player's reach; reach_changed only sets
a flag and the AI's override only marks its plans stale, so the call is cheap.
## The checks
tests/human.gd, real mouse and keys, seed 7: the enemy's block between the player's wall and a
tile two east blocks piece and gun (in_reach, the ghost's canPlaceWall / canPlaceBuilding, the
click refusing) and the same line clear places; a diagonal runs through one tile, the enemy's
block beside it does not block, and the reopened line reads reached the moment the block on it falls; the old 1 x 1 enemy ring grows to a 2 x 1 room so the ring rule
keeps its own guard - no line reaches inside, the player's own block inside anchors its
neighbour and enemy ground still refuses on top of it. Every new check watched red on the old
code. Suite green.
