# Session 58: the AI distributes its guns

Sebastian, 2026-10-22: "The AI should try to distribute its canons: onmly place 4 next to each other if you want to
build a big ccannon. But keep big cannons apart so the 3x3 shot from other big cannons does less damage"
Roadmap: I89 (first drafted I88 / session 57; renumbered when the itch-deploy session landed I88 and its own 57 on master while this ran), game code.

## What ships

All in [AI.gd](../../../scripts/components/AI.gd):

1. **Guns spread** (I89). `try_build_gun` placed at the first free tile it found, so guns blobbed, fused by
   accident and one enemy heavy 3x3 (I84) caught them all. `_spread_spot()` replaces it: the free spot of own
   closed ground with the most ground to the nearest own gun (`_own_gun_tiles` scans the board, a fused big
   counts all four tiles), ties to the deeper plans — an own castle's ground, then a yard's, a claim's, a room's.
2. **Packing only on purpose.** `_big_sites()` derives every 2x2 of own closed ground whose cells are free or
   hold an own small cannon and whose whole square stands `SPLASH_SEPARATION` (Chebyshev 3, exactly the span of
   one heavy splash) from every other own gun. The first site the parts budget can finish (`4 - smalls ≤
   budget`) gets the placements; the sites come off the live board, so a dying gun or a lost site self-heals.
3. **A yard per big.** Castle rings are one tile thick — no 2x2 ever fits inside one — so when the cap can pay
   for a big (need ≥ 4) and no site stands, `update_plans` grows a yard off every own gun (`_pick_room`'s new
   `off_guns` filter keeps every tile of the site 3 from own guns), with the unfiltered pick as the fallback:
   gun room outranks perfect spacing. Each yard hosts one big of its own 3x3.

## The check

[ai_test.gd](../../../tests/ai_test.gd): in the live gun phase one big fuses and every other gun keeps its own
3x3; with the smalls cleared and the cap set to 10, exactly one yard is planned and every one of its tiles
stands 3 from every own gun; its gaps closed by hand, four direct placements fuse a second big still a 3x3
from the first. [sim.gd](../../../tests/sim.gd) checks per frame that no AI ever holds two bigs in one 3x3.
Break-checks, all watched then restored: the old first-free-tile body back failed three checks ("every other gun
stands its own 3x3", "four smalls fuse the second big", "the two bigs share no 3x3"); `SPLASH_SEPARATION := 1` and
the yard trigger off each failed "a second yard is planned for the next big". Two honestly unproven: the `off_guns`
filter off stayed green on this seed (the unfiltered pick landed clear anyway) — its guarantee is covered by the sep
and trigger breaks instead; and the sim tripwire never fired red either, because even the old AI at 260 s on seeds
1 and 2 never puts two bigs in one 3x3, so no violating state arises for it to catch — its predicate is the same
Chebyshev-3 pair check ai_test watches red.
