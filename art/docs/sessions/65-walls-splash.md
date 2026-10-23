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

## Ship order

Plan, roadmap items, code, watched reds, full suite (other sessions' Godot quiet first), before/after
crops, commit, merge to master by push, origin, report.
