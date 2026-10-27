# Session 13: rules v2 in the game

Start prompt for the session, in the game repo: "Run session 13 from art/docs/sessions/13-rules-v2.md. Go."

Roadmap item: B18, the upgrade tree v1. It is ticked when the game plays the recipes of [rules.md](../../game/design/rules.md) section 7. The crater tile look rides along.

Sebastian, 2026-10-15 (D64): no siege gun for now. Leave `cannon33a` parked (`parked = true` in its file): the game has 1x1 and 2x2 guns only, and the crater, which comes from the siege shell, waits with it. The `lab` test passes again since game round D (roadmap I11).

## Why these deliverables

- **The battle is over in about 6 s.** Today the first breach switches off the whole fort (D59). Rules v2 checks the enclosure once, at the end of the build phase, keeps the guns firing through the battle, and makes the base the flag. That is the change the whole game waits for.
- **The models exist now.** Session 12 put the mortar, the flak, both big depots and the cluster bomb into the art layer (D60). Today only the sandbox reaches them: `supply22` gives 4 supply like the 1x1 depot, `supply33` has no recipe, and no recipe a player can find makes the mortar or the flak. Recipes by iron count make all five guns and three depots reachable.
- **Every shot by hand is the Tetris half of the game.** Firing gun by gun through one queue, with a skip, makes attention the resource. The AI plays the same queue with a reaction and a switch time, so the lab can tune it.
- **The lab decides the numbers.** No number in rules.md is tuned. The round robin and the ablation of section 9 say which guns have a job. The `lab` test that fails today ("blue's four cannons beat red's slow flak", failing on master before session 11) is replaced by the section 9 matrix.

## Plan

1. **Rules, sections 1 and 5.** The enclosure check at the build phase's end, the base as the flag, a hit kills what stands on its tile, the upper storey first, the flood cap. Burning tiles until the next build phase, the siege crater, timber fills a crater.
2. **Draws and the hold slots, section 2.** Build 45 s, battle 30 s, the discard replaced by two hold slots.
3. **Guns, section 3.** The table's ranges, reloads, supply needs and blasts. The mortar's five shards land on five distinct tiles of the 5x5 and burn them. The flak shoots down one ball every 2 s within 4 tiles. Every shell flies a flat arc of about 2 s.
4. **Firing, section 4.** One queue in build order, Space fires the highlighted gun at the cursor, Tab skips. The highlight is the D57 plate glow held steady, and the D58 arc draws from the highlighted gun.
5. **Supply and recipes, sections 6 and 7.** `supply22` gives 10, `supply33` gives 16 and gets its recipe. A building runs when the supply is at least its need. Recipes count iron, a 3x3 forms when its centre comes last, and a ghost shows what the last block makes.
6. **The AI, section 8.** Same draws, hold slots and queue, `reaction` and `switch` as `--set` values, the 3x3 recipes, the six personalities.
7. **The bugs of section 10**, each fixed where all callers route through.
8. **The lab, section 9.** The round robin and the ablation in [tools/lab.tscn](/home/womb/repos/cannonade/tools/lab.tscn), the win matrix in [run_tests.sh](/home/womb/repos/cannonade/run_tests.sh). The numbers move until the bands of section 9 hold. Then ten matches by hand with Sebastian, because the lab cannot judge feel.
9. **The crater tile.** A procedural crater look on the tile route, painted on the D49 path, with a small board and Sebastian's pick.
10. **Gate boards.** One sandbox battle board under rules v2 with all five guns firing, the shards burning their tiles and a crater, every asset big (D48).

## Found in session 12, to settle here

- `Shooter.sleep()` rests every gun at -10 degrees. The mortar then lies with its mouth forward, like a short cannon. Check when guns sleep under rules v2, and give a gun its own rest angle if the mortar shows it: 45 degrees for the mortar.
- `Flak.gd` aims its guns at a ball at any height, down to level. Since D61 the guns stay on their own plate, so a low aim no longer passes through a neighbour. A minimum aim is only worth adding if the lab battles show the flak looking at the ground.
- The flak's recoil scales its `Guns` node to 85 percent for a moment on every shot. Keep it or replace it with a kick back along the barrels, by eye in a battle frame.

## Game changes named

- Gameplay code in [scripts/](/home/womb/repos/cannonade/scripts) for sections 1 to 8 and 10 of rules.md, and the data in [data/buildings/](/home/womb/repos/cannonade/data/buildings) and [data/projectiles/](/home/womb/repos/cannonade/data/projectiles).
- The HUD for the hold slots, the merge ghost and the rule sentence (rules.md section 13).
- [tools/lab.tscn](/home/womb/repos/cannonade/tools/lab.tscn), [run_tests.sh](/home/womb/repos/cannonade/run_tests.sh) and the tests that rules v2 changes.
- The crater tile model in the art layer.

## Limits

- Sebastian's four defaults of rules.md section 14 wait for his review at the start of the session. Ask before building on them.
- The numbers come from the lab, never from taste. Record each tuning step and its matrix.
- Spending cap 5 USD in `.env.session`, rewritten at session start: only the crater board and the critic calls cost.
- Game changes land on `master`, limited to the list above. Sebastian's uncommitted edits there stay untouched.

## Done when

A match in the game plays rules v2: the enclosure check at the phase end, the base as the flag, every shot by hand through the queue, all five guns and three depots reachable by the iron count. The lab matrix runs in `run_tests.sh` and holds the bands of section 9, ten matches by hand are played with Sebastian, B18 is ticked, and the session 14 plan is written.
