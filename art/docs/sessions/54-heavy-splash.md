# Session 54: the heavy shell splashes a 3x3

Sebastian, 2026-10-22: "Hm, how about the big cannon does twice the damage per
field but damages all field in a 3x3 radius (including friendly ones and neutral
one) with a impact effect over all 3 fields?"

## Plan
- I84 (roadmap): cannon22a's heavy shell hits every tile of the 3x3 round its
  target at 20 a tile, twice the small cannon's 10, the shooter's own side and
  bare ground included. Data only: damage 20 in
  /home/womb/repos/grid-cannons/data/buildings/cannon22a.tres, splash_range 1 in
  /home/womb/repos/grid-cannons/data/projectiles/heavy_shell.tres; TileImpactor
  already splashes get_surrounding_tiles(splashRange) owner-blind.
- The landing effect covers the 3x3: FX.impact takes the splash span in metres,
  widens the plume and raises a dirt puff on each hit tile
  (/home/womb/repos/grid-cannons/scripts/FX.gd,
  /home/womb/repos/grid-cannons/scripts/components/TileImpactor.gd).
- tests/weapons.gd: the fused gun's shell takes 20 off every building of the 3x3
  whatever the owner, kills a 10-health wall, scars bare tiles by 20, leaves the
  tile outside clean.
- rules.md: the cannon22a row moves from the plus of five to the 3x3 at 20 (D90).
- Lab: heavy_vs_cannons before and after, 20 seeds, --targets=auto,auto: blue
  73/0/28 and 75.5 s average before, 100/0/0 and 28.7 s after. The splash
  heavy beats the four smalls every time now; more tuning is Sebastian's call.
- tools/screenshot.gd grows --firewith=DEF so the render scaffolding can place
  any gun def, not just the basic cannon (used to shoot the splash plume).
