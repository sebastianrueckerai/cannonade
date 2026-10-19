# Session 22: castles stop flashing white under aimed fire

Fourth playtest report (2026-10-19), one fix, its rule guarded by a test that
was watched red with the old behaviour in place.

## "During the shooting phase the castles randomly change colors between player colors and the neutral crown as well as stark white."

Root cause, traced: the targeting marker of I35 — emission
`WHITE.lerp(shooter colour, 0.3)` at energy 1.2 on "the tile slab and
everything standing on it" — predates castles as shot targets. With range 50
every gun reaches every castle and the AI targets castles after guns, so each
salvo in flight turned the aimed-at castle's team surface (roof and banner,
surface 0) into a flat unshaded white; when the salvo landed the glow cleared
and the crown brown or the team colour returned. Reproduced headless (ai2,
default seed): the same neutral castle is brown at t=50 and stark white at
t=62, wall pixels unchanged — only the team surface blows out, unshaded, which
is emission, not albedo.

Fix: `BuildingPlace.target_on` / `target_off` glow `model()` — the tile slab —
instead of the tile's whole tree. Buildings keep their colours; the marker
still reads on open tiles. Trade, noted: on a fully covered tile the slab
hides under the building, so an aimed-at castle shows no marker — the shells
and the damage states show the hit.

Test: new `tests/target_test` drives the real aim path (`target_on` /
`target_off`, as `aim_tile`, `impact` and `_exit_tree` call them) on a neutral
castle's centre tile: the slab glows and clears, the castle never carries
emission. It ran red on the castle assertion before the fix, green after.

## Result

The guard ran red on exactly the castle assertion with the old code, green
after the fix. Full suite green after it: seventeen entries, no ERROR output.
One commit on master, pushed to origin.
