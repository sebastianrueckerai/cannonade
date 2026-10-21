# Session 43: the ground takes visible damage
Sebastian, 2026-10-21: "I want ground to become visibly damaged. While a building is on it the
building doaks up the damage, after this I want 3 stages of damage. Can be a combo of texture
and crater. Make different for the encolosed walls and nature.", then over the first boards:
"I want visible mesh damage from the fist hit. Then maybe make it worse in stages. Nothing
special: Just craters or gaps in the tile. Building on it heals it".
Roadmap: I73. Game code and art in one: the cratered slabs are the deliverable, the rules are
what makes them appear.
## The rules
A hit on a tile with a standing structure (wall, gun, castle, stacked wall) is soaked by the
structure, the killing blow included - the ground below stays untouched while something stands
on it. On bare ground the hit adds to the tile's groundDamage (BuildingPlace.damage_ground),
the first hit already at stage 1, stage 2 at 25, stage 3 at 50, clamped there so the ground
cannot look worse than its worst stage. Water takes none. Building on a tile heals it: build()
resets the damage and repaints, so rebuilding over a scar mends the ground (his second message
changed the rule from the first plan's "never healed").
## The look
Two families, picked by the tile's live enclosure state at every repaint, the same state the
tile colour uses, so no repaint can desync family and colour: inside walls the stamped paving
of tile_mud cracks (tile_mud_d1..d3), open nature ground churns (tile_dirt_d1..d3). Each stage
is its own slab mesh swapped in by Art.swap_mesh from _apply_ground_look, craters pressed into
the top face - deep enough to read as mesh from the first hit (d1 -4 to -5 cm, d3 up to
-10 cm), the stages deepen and spread them, the slab border stays at full height so slabs of
different stages meet without a seam. The blast texture is painted in step with the craters
([paint.py](../../pipeline/blender/paint.py), kinds mud_hit / dirt_hit): scorch dabs inside the
craters, ejecta flecks thrown out of dirt craters, more cracks on the deeper paving stages.
Built by [tile_damage.py](../game/assets/3d/tile_damage.py), deterministic seeds, sidecar
[tile_damage.json](../game/assets/3d/tile_damage.json), 524 tris a slab, near-white bases so
the game's per-tile colour keeps multiplying on top.
The meshes are procedural ($0), so no look is Sebastian-picked yet: boards below, his pick by
number decides whether the craters stay this depth.
## The checks
tests/weapons.gd: the first hit dents (stage 1, open family), a building on the scarred tile
heals it and soaks three hits and the killing blow, 15 damage reaches stage 1, 45 stage 2, 50
stage 3, past 50 no change, building heals back to the plain slab, a wall ring closing round a
scarred tile flips it to the enclosed family, a real shell that lands on bare ground scars it,
water takes none. Every new check watched red on the
old code. tools/screenshot.gd --scorch=N piles 10-damage hits onto the bare tiles nearest the
camera target, nearest first until a tile reaches 50, and prints each scar - the boards' stage
and family come from that print, not from the eye.
