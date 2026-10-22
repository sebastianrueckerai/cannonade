# Session 61: the heavy shell's 3x3 smoke

Sebastian, 2026-10-22: "can you give the 2x2 cannon shell a 3x3 puff of smoke when landing. The current
donut shaped force wave is not enough." The fused 2x2 cannon's heavy shell splashes a 3x3 (I84), but its
landing showed only the centre plume, small dirt kicks on the eight hit tiles and the expanding ground
ring of board 6 — the area read as a wave, not a cloud.
Roadmap: I101 (game). No paid generation: Kenney's CC0 smoke sprites already ship in
[assets/art/fx](../../../assets/art/fx), so the session cap is 0 and no provider runs.

## What ships

1. **A smoke puff on every splash tile of the heavy shell's landing** (I101). `smoke_puff` is a new field
   on [ProjectileDef.gd](../../../scripts/data/ProjectileDef.gd); [heavy_shell.tres](../../../data/projectiles/heavy_shell.tres)
   sets it, Catalog wires it onto TileImpactor beside `splashRange`, and FX.impact puffs three slow rising
   SMOKE_DARK quads on each of the eight tiles round the hit, beside I84's dirt. Under the centre's own
   plume the 3x3 reads as one cloud, heaviest at the hit; the ring still runs under it. The cluster's
   shards carry splash too but keep the flag off: five shard plumes each smoking a 3x3 would fog the
   board, and Sebastian asked for the 2x2 cannon's shell.
2. **Why a def flag and not splash alone** (same item). Splash is shared by the cluster's shards; smoke
   is the heavy shell's own look. One bool in the data binds the effect to the shell that earned it, and
   the tests pin both directions.

## Checks

[weapons.gd](../../../tests/weapons.gd): in the I84 splash round, the fused gun's landing plume
holds a SMOKE_DARK puff within 0.4 m of each of the eight neighbour positions (found through the FX
root's own ground ring, not a hardcoded world point); in the cluster round, every shard plume that
appears while the fires catch is checked the same way and must hold none. Watched red, both
directions: `smoke_puff = true` dropped from heavy_shell.tres (0 of 8 neighbours), and the FX puff
keyed on `splash > 0` alone instead of the flag (the shard plumes smoke). Suite green, 23 PASS.

Visual: [tools/screenshot.tscn](../../../tools/screenshot.tscn) `--mode=versus --seed=7 --artseed=5
--firewith=cannon22a` at the smoke peak 0.76 s after impact. The renders are pixel-deterministic at fixed
seeds - two runs of the unflagged build diff 0 px - so the whole before/after delta is the change: 66 325
px, 56 850 of them inside the box round the 3x3 (the smoke quad band, risen and spread). 3x magnified
same-region crops at /tmp/crop-3x3-smoke-before.png and /tmp/crop-3x3-smoke-after.png. Whether the
weight reads right at a glance is Sebastian's eye, not measured.
