# Session 66: one small and one big gun a player, the mortar back at 2x2

Sebastian, 2026-10-23: "The game should have a big and a small gun, each in at least 2 varieties. Each player
in each round should only have 1 version of the 1x1 and one version of the 2x2 gun. But the versions of the
players should be different. I had at least one game were I was able to place different guns for the small one
at each click. Also, the mortar is supposed to be a 2x2 gun only not a 1x1 gun."

## The per-click variety was a bug in the wear, not the deal

`Catalog.spawn` routed the cannon through `Art.attach(go, gun_look(owner))`, but `attach` defaults to
`exact := false`, which draws one of the model family's looks at random. A player dealt the first look
`"cannon"` - and every no-owner spawn - drew a fresh one of cannon / cannon.3 / cannon.4 on every placement;
the dealt looks `"cannon.3"` and `"cannon.4"` have no numbered variants under them, so they alone were
stable. I103's belief "the explicit id, so the auto-variant pick never overrides the deal" held only for
those. The catalog test read `art_id` (the id passed in), not `art_look` (the model actually worn), so the
guard passed while the model varied. The gun attaches now pass `exact`, and the test reads `art_look` across
eight draws.

## The deals (D93)

- Small gun (C20): `GUN_LOOKS` stands at `["cannon", "cannon.3"]`; `cannon.4` (the mortar's model on the 1x1
  plate, D91) comes out - the mortar is a 2x2 gun only. Its glb leaves the game assets (manifest entry too,
  like D92 took cannon.2's); the art source and `HAND_SPAWN` entry stay in art/.
- Big gun: `BIG_GUN_LOOKS = ["cannon22a", "cannon22b"]`, dealt beside the small ones in `Main.build`
  (`PlayerController.bigGunLook`). The fused 2x2 (four cannons, still the `cannon22a` def and its heavy shell)
  wears the owner's big look: the 2x2 cannon or the mortar, D91's "1:1 exchange for the same cannon". The fuse
  spawned without its owner (`UpgradeCluster.build_multifield_upgrade` called `Catalog.spawn(def)`), so the
  owner travels with it now. The crafted cluster mortar (`cannon22b` from four upgrade blocks B) keeps its own
  def and model, as before.
- `deal_wall_looks` / `deal_gun_looks` / `deal_big_gun_looks` share one shuffle (`Catalog._shuffled`); three
  copies of the same Fisher-Yates was slop.

## Guards (tests/catalog_test, all watched red)

- eight hand-drawn cannons of a player all wear that player's look (red: exact dropped, three looks in one
  player's hand);
- four cannons fused through the real placement path wear the fusing player's big look (red: the owner dropped
  from the fuse spawn, every fused 2x2 wears cannon22a);
- no mortar model at 1x1 (red: cannon.4 back in GUN_LOOKS);
- a cannon without an owner wears exactly the first look; the two players hold different small and big looks.

## The corner fuse (found by the guard, fixed this round)

Player 0's first free 2x2 is the map corner [0, 0], and there the fuse failed: `UpgradeCluster`'s pattern
check skipped map tile (0, 0) (`if ix != 0 or iz != 0`, an artifact of the 2026-10-01 port), so a square
anchored at the corner gathered three parts and no recipe matched - four cannons stood unfused, silently.
The skip is gone; every tile of the window is checked now.

## Evidence

- Suite green, 25 of 25.
- Watched red, the three breaks made at once after the first green: exact dropped - `every drawn cannon
  wears the player's look (["cannon.3", "cannon"], want cannon)`, both small looks in one hand, his very
  bug; owner dropped from the fuse spawn - `the fused 2x2 of player 0 wears the player's big look (got
  cannon22a, want cannon22b)` on both players; cannon.4 back in the looks - `two gun looks and every
  model is in the game ["cannon", "cannon.3", "cannon.4"]` and `the mortar is a 2x2 gun only`. The corner
  guard went red on its own before the fix: `four cannons fuse into the 2x2 cannon` failed at spot [0, 0],
  green after.
- Render, versus mode, the gun phase (t = 5 s): /tmp/shot66_005.png, 1.3 MB - the board renders whole,
  the factions' gun models differ across the river. Which side wears which model is not verified from the
  pixels; the wear itself is the test's art_look reads above.
