# Session 65: walls that connect, and a splash you can see

Sebastian, 2026-10-23: "Change things so each wall needs to be placed exactl next to an existing wall. No more
gaps! A new wall must conncet to 1 tile of exiting wall. Add a splash sound for cannon balls falling into water
and a splash particle effect. Maybe you can sue what smoke or the cannon force wave are doing and just color it
blue? Or search the internet foir a splash effect. Make sure mountains, hills and such are nevr placed on
rivers. I want rivers to be doen first, then the rock obstacles."

## I105: a new wall must stand edge on an own wall or castle tile

The placement rule moves from "one piece cell within Chebyshev 2 of an own wall/castle tile" (reach,
PlayerController._anchor_mask) to orthogonal adjacency: one cell of the piece edge on an own wall tile, a
bridge or an own live castle tile. No more walls standing apart with a gap.

- PlayerController grows a second mask `wall_reach`, built beside `reach` in `_rebuild_reach` from the same
  anchor list (extracted to `_anchor_tiles()`): 1 on every map tile orthogonally next to an anchor. No
  line-clear condition at distance 1.
- `can_place_piece` swaps `in_reach` for the new `in_wall_reach`. That one predicate gates the human's ghost
  light and click confirm (`canPlaceWall`), the AI's `_best_cover`/`_best_approach` and the ring site scan
  already routes through it; buildings (guns) keep the old reach.
- Bridges still work: a bridge is a wall, so it anchors the next tile; a wide river crosses one tile at a
  time.
- Guards in walls_test (held wall_1 through the real predicate): adjacent own wall yes, gap tile no,
  diagonal-only no, enemy wall no, own castle tile yes, river cell edge on a wall yes, and the gap tile yes
  once a wall closes the distance. Watched red: the predicate reverted to in_reach.
- river_test's bridge section adapts: at start the river may sit past the adjacency line, so the human walks
  a wall to the bank first (legal placements only), then bridges as before.
- The old rule's guards move with it: human_test's upright three sits edge on the ring, the enemy-room block
  stays standing as the anchor, the line-clear section becomes the gap refusal plus an edge-on placement (the
  gun keeps the line-clear rule), the north walk steps one tile at a time; phase_test takes its wall spot
  through `free_tile_in_range(true)`; ai_test closes the free 2x2s the changed AI ground leaves, so the yard
  precondition of 9a holds again.
- Two test mechanics the edge-on rule forced, both real player paths, not test hooks. The pick takes the first
  wall block the view ray meets below its top (`PlayerController._wall_hit`), so the tile directly behind a
  wall cannot be cursor-picked at the default camera: the human test's extension click zooms in and aims at the
  far half of the tile, the way a player extends a line (wall top 1.09, the ray to the near half crosses at
  1.02). And the edge-on upright three stands one tile east of the old rule's spot, where it blocks the view
  ray to the building spots the later sections scan for, so it comes down right after the stacking checks, like
  the old `below` cleanup.

## I106: the water landing reads as a splash

The sound was already there and right: `hit_water_1.wav` (1.05 s, rms 6.7%, family level; TileImpactor plays
it on every wet landing, sound_test guards it). The FX water branch (I104) was a quiet 14+8 droplet puff.
Amp it in place, no new assets: more and bigger droplets, a wide white-blue foam sheet (his own recipe: what
smoke does, blue), brighter ring. Guard in weapons_test: the water impact root holds the droplet bursts and
no land-style texture (DIRT/FIRE/FIRE2/SMOKE_DARK); watched red with the water branch skipped.
Evidence: `tools/screenshot.tscn --fire --wet` same-region crops before/after.

## I107: rivers before rocks - already true, answer him with the guard

GameController builds castles, then `_place_rivers()` (line 132), then `_place_terrain()` (134). A terrain
feature lands only through `_terrain_fits`, which requires `t.is_free()`, and `is_free()` refuses water, so
no rock or hill can take a river tile. river_test's sweep already guards it: "river tiles are water and
stand bare after the build" counts any structure on a river tile, terrain included. No change; verified and
reported.

## Round 2 (I112): his play of the splash

"The river splash has lightning looking studff in it. Get rid of that. It aslso has a smoke plume. That may
work if you make it blue on the inside and white as it disperses. Currently is looks like thick black smoke."

- The lightning was the water branch's additive SPARK burst (I106): deleted, and the weapons guard flips to
  `sparks == 0`.
- The black smoke was the heavy shell's I101 3x3 puffs, which ran on water like on land. Over water the
  splash shell now skips the dirt puffs and its smoke puffs turn to mist: SMOKE_SOFT, blue (0.45, 0.62, 0.95)
  at the core running to (0.93, 0.97, 1.0) as it disperses. New `to` end-colour key on `_burst`; the colour
  moves from `p.color` into the ramp so a burst can recolour over life, identical rendering for every
  existing burst.
- Guards in weapons_test beside the cannon splash: a fused cannon placed by the water fires its shell in, the
  landing wears no dark smoke / dirt / spark texture, each of the eight tiles round it holds a mist puff, and
  its ramp starts blue, ends white. Watched red: master FX (12 sparks), mist and dirt switches off (16
  land-style bursts, 0 of 8), `to` dropped (8 of 8, ramp stays blue).
- The earlier `gun` (the fused square from the top of the test) is freed by then, so the shell fires from a
  freshly placed cannon22a beside the water tile.

## Ship order

Plan, roadmap items, code, watched reds, full suite (other sessions' Godot quiet first), before/after
crops, commit, merge to master by push, origin, report.

## Round 3 (I112 amendment): still black - the sprites themselves

"The splash is still smokle black. It needs to be water blue in the center / at the early stage of the
shapes emiting and then gfo to white. If the shapes are images that are black by default then go gout
and search something more fitting a pre made splash effect or white sprites we can tint."

- His diagnosis was right: the Kenney smoke sprites are grey. An in-engine probe read smoke_04 at 0.25
  average RGB (centre 0.23), so the blue tint multiplied down to dark grey-blue - black smoke over a
  river, whatever the recipe. The muzzle glows (muzzle_04/05) are white but star-shaped spikes with
  7.7 / 4.9 percent alpha coverage; a first pass put the water family on them and the render showed 0
  water-blue pixels - thin streaks, not puffs. That pass also proved the ground darkening in the impact
  box is the shell's own 3x3 ground scar, not particles (same scar before and after).
- No download needed: mist.png is derived in-repo from smoke_04's soft round alpha with white RGB
  (Kenney CC0 allows the edit). White tints true water blue: the droplets, the foam sheet and the 3x3
  mists all ride MIST, blue (0.45, 0.62, 0.95) at the core to white (0.95, 0.98, 1.0) through the
  round-2 `to` ramp.
- Guards: tests/weapons counts FX.MIST for the splash droplets and the eight mist tiles. Watched red:
  the water path reverted to the grey smoke sprites fails all three (0 droplets, land-style bursts,
  0 of 8 tiles).
- Render evidence, seed 42, same pixel, impact frame: the impact box (120x120) holds 4 water-blue
  pixels on master, 222 after; dark pixels 182 before, 67 after. Crops at /tmp/splash{3,4}_crop3x.png
  (before = master, the version he played).
