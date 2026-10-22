# Grid Cannons rules v2: the fort, the guns and the upgrade tree

The target rule set for [the game repo](/home/womb/repos/grid-cannons), decided with Sebastian on 2026-10-14 (D59). Every number is a starting value for the lab of section 9. Nothing here is tuned.

The game is quick strategy, tower defence meets Tetris. Matches are short, every shot is a choice, nothing has a health bar. Walls die in one hit, a double wall in two, and the only things that last are the base and the ground.

## 1. The fort and the breach

The Rampart rule replaces today's rule, under which the first breach switches off the whole fort and a battle is decided in about 6 s.

- Enclosure is checked once, at the end of the build phase. A building inside a closed wall at that moment is active for the whole battle. A breach during the battle changes nothing until the next check.
- A ring closes for one side only: ground walled in by two sides' walls together stays open until one side's walls encircle it alone. Where one side's ring runs round a smaller ring of the other, the ground between stays the outer side's (2026-10-21, I75).
- The base is the flag. At the end of a build phase, a side whose base is not inside a closed wall is out. In a match of four sides the last side in wins. In single player the fleet mode ends when the seven ships are sunk or when the base is open.
- A shot kills whatever stands on the tile it hits: a wall piece, a gun, a block, a depot, a flak, a ship. The base takes no damage. On a double wall the upper storey goes first, the lower wall on the next hit.
- The cap: after round 8 the outer ring of tiles floods, one ring per round, until a base is open. A dial. Craters end most long matches before it.

## 2. Phases and draws

- Build 45 s, cannons a second per cannon the fullest hand can place, battle 30 s that ends early once no side holds a gun and no shell is in the air. The banner counts a phase in over 2 s. Today: versus runs these; single player pins 200 s walls, 50 s cannons, 250 s battle.
- The two draws stay random: a wall piece, one in four per shape, and a building, one in three each of small gun, timber block, iron block. The next piece comes 0.3 s after a placement.
- The discard goes. Two hold slots come, one beside each draw. Putting a draw into its slot swaps it with what the slot holds. A held piece waits for the right moment, the way a Tetris hold does. With a 45 s build phase draws run out before the phase does, so the slot is a choice and not a vending machine.
- Build range stays: within 2 tiles of an own structure, no crossing water.

## 3. The guns

Sebastian, 2026-10-15 (D64): no siege gun for now. The game has 1x1 and 2x2 guns only, and `cannon33a` stays parked in its file with its art. While it is parked, a 3x3 square with 5 to 9 iron makes no 3x3 building, and section 5's crater has no source.

The job column names what nothing else does. A gun without a job is cut.

| id | footprint | fired | blast | range tiles | reload s | supply | job |
|---|---|---|---|---|---|---|---|
| `cannon`, small | 1 | by hand | one tile | 8 | 4 | 0 | fires from the first turn, the safe bet |
| `cannon22a`, heavy | 2x2 | by hand | a 3x3 square at 20 a tile, the shooter's own side and bare ground included (D90) | 14 | 6 | 4 | a hole three wide, which needs three pieces in a row |
| `cannon22b`, mortar | 2x2 | by hand | five shards on five distinct tiles of the 5x5 round the target, one tile each. Every hit tile burns | 14 | 8 | 4 | holes that cannot close this rebuild |
| `flak22` | 2x2 | itself | shoots down one ball every 2 s within 4 tiles. Not shards, not the siege shell | 4 | 2 | 4 | the answer to a swarm, beaten by volume or by the siege |
| `cannon33a`, siege | 3x3 | by hand | 3x3, both storeys on every tile, a crater on the centre tile | the whole map, nothing under 8 | 10 | 9 | the finisher, a hole that needs a detour and a map that shrinks |

Every shell flies a flat arc of about 2 s. Today a shell takes 4 to 5.7 s on a steep arc for any distance. Damage stays 10 against 10 health everywhere, so a hit is a kill (the heavy shell is the exception since D90: 20 a tile over a 3x3).

Why the siege gun is worth nine blocks: nine small guns on nine tiles kill nine walls per round of shots, but only where they reach, and only as fast as one hand presses. The siege gun reaches everything from the back row, and each shell leaves a crater that stays.

## 4. Firing: gun by gun

- A side's shooting guns form one queue in build order. The highlighted gun is the next ready gun in the queue. Space fires it at the cursor tile when the tile is in its range. Tab skips to the next ready gun, and the skipped gun comes round again.
- The highlight is the plate glow of D57, held steady instead of the single ready pulse. The aim arc of D58 draws from the highlighted gun, so the range shows before the press.
- Flak fires itself. It has no shot to place.
- The AI fires the same way, see section 8.
- The hands cap the swarm. Nine small guns do not fire nine times as much as one. They cover more of the map and survive losses. Attention is the resource, which is the Tetris half of the game.

## 5. The ground

- A burning tile takes nothing until the end of the next build phase. The mortar's shards set their tiles burning. Today a tile burns 3 s.
- A crater takes nothing. The siege shell leaves one on its centre tile. A timber block placed on a crater fills it and is used up. A dial, filling on or off, default on.
- A crater under a building leaves the building standing. The tile cannot be built on again once the building is gone.
- Water stays as it is, plus the flood of section 1.

## 6. Supply

| depot | footprint | supply |
|---|---|---|
| `supply`, timber on timber | 1 | 4 |
| `supply22` | 2x2 | 10 |
| `supply33` | 3x3 | 16 |

- Only depots inside the enclosure at the check count, for the whole battle.
- A building runs when the supply is at least its need. Today the check is strict, so one depot cannot power one 2x2.
- The heavy, the mortar and the flak need 4. The siege needs 9. The small gun needs nothing.

## 7. Recipes: the more iron, the more gun

A full square of blocks of one owner merges, as today. The iron count decides, the arrangement does not.

| square | iron | building |
|---|---|---|
| 2x2 | 0 or 1 | `supply22` |
| 2x2 | 2 | `flak22` |
| 2x2 | 3 | `cannon22b`, mortar |
| 2x2 | 4 | `cannon22a`, heavy |
| 3x3 | 0 to 4 | `supply33` |
| 3x3 | 5 to 9 | `cannon33a`, siege |

- Timber on timber makes the 1x1 depot, as today.
- A 3x3 forms only when its centre is placed last, because a 2x2 merges first otherwise. This is today's merge order, kept: lay the ring, then the heart.
- A ghost over the square shows what the last block makes while it hovers. The rule, "the more iron, the more gun", shows once in the HUD.
- Gone from the catalog: `cannon22c`, `cannon22d`, `cannon33b`, `cannon33c`, `rocket_station`, `shield22`. They played the same as the plain gun of their size or had no recipe a player could find. The shield and the rockets are parked, section 11.
- The square touching map corner (0,0) merges like any other. Today it builds nothing.

Why counts and not shapes: a 2x2 has six patterns, a 3x3 has 140. Nobody learns a table of 140 under a build timer. Counts are one sentence, and the ghost makes them a choice.

## 8. The AI plays the human's game

- The same draws, the same hold slots, the same queue and skip.
- Two reaction times in seconds in [AI.gd](/home/womb/repos/grid-cannons/scripts/components/AI.gd), never 0. `secondsBetweenShots`, 0.5 by default, is the wait after every shot, the aim move and the click: a human lands about one shot per 0.5 to 0.8 s. `secondsBetweenBuilds`, 1.0 by default, is the wait after every build action, whether a placed piece or gun, a stacked block, a dropped piece or a discarded gun: a human turns and places a piece slower than it fires. D76 had one wait of 0.5 for both, which built too fast (2026-10-20, I63); the two waits planned here before, `reaction` and `switch`, stay replaced.
- It shoots, best first: the enemy's guns, then the castles the enemy holds, the nearest to ruin first, then the enemy's walls, the most walled-in first. Every loaded gun fires at the first of these in its reach, so the guns gang up on what decides the game. A neutral castle it rings and claims, never shoots (2026-10-20, I65).
- When nothing is left to ring or claim, it keeps building: the largest room it can, sited toward the castles it does not hold — territory for its guns, and staging for a claim once the walls before it fall (2026-10-21, I76).
- It knows every recipe of section 7 and can lay a 3x3. Today its integer square root returns 4 for 9.
- Personalities: swarm, heavy, mortar, flak, siege, mixed. Each defends with small guns and spends the rest of its land on its kind. Mixed may build everything.

## 9. The lab decides the numbers

[tools/lab.tscn](/home/womb/repos/grid-cannons/tools/lab.tscn) runs AI against AI with `--set` and `--sweep`. The personalities and the AI's reaction time become `--set` values.

- Round robin: every personality against every other, 100 matches per pair, both seats. The win matrix must show no personality above 60 of 100 against the field, and flak over swarm.
- Targets per 30 s battle, for a fort that was intact at its start:

| target | band |
|---|---|
| walls lost | 30 to 50 percent |
| guns lost | 1 or 2 |
| rebuild in 45 s | closes with 5 to 10 s to spare |

- Ablation: mixed against mixed with one gun removed from its roster, 100 matches, for every gun. A gun whose removal costs no wins has no job and is cut or changed.
- The matrix runs in [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh) beside the three sims, so a later change that breaks a gun fails the gate.
- Then ten matches by hand. The lab cannot judge feel.

## 10. Bugs that go with it

- The supply check is strict, section 6.
- `supply22` gives 4, the same as the 1x1 depot.
- Flak and shield are never switched off outside an enclosure.
- The corner (0,0) square builds nothing.
- `near_int_sqrt(9)` returns 4.
- `roundsPerGame` is never read. The cap of section 1 replaces it.

## 11. Parked

- `shield22`: a sphere that blocks shots for a fixed number of hits per battle. It returns as the 1-iron 2x2 if the lab shows the siege gun has no answer. It closes a counter cycle: swarm drains shield, shield stops siege, siege goes through flak, flak stops swarm.
- `rocket_station`: a crater anywhere on the map, slow. Returns as the timber-centre 3x3 if one 3x3 kind is too few.
- Capture: enclosing the enemy base in your own wall takes it. Needs walls of two owners.
- Powder magazine: a hit on a depot blows a 3x3.
- Auto-fire for the swarm, with a painted target. Sebastian wants every shot by hand.
- A third block kind, stone, for defence.
- Damaged models. Nothing has health, so nothing is damaged.

## 12. An experiment: build and shoot at once

Sebastian's idea, to try after v1 stands in the lab. One phase instead of two: draws arrive while the guns reload, and the player places pieces between shots. With reloads of 4 to 10 s the loop is place, place, fire, place, fire. It is cheap to try, both systems exist and the sandbox can run them together. Three rules change:

- The enclosure check runs on a tick, every 30 s, instead of at a phase end.
- The base rule applies at the tick: open at the tick, out.
- Burning lasts a fixed time, 20 s, instead of a phase.

The lab targets of section 9 are per battle phase and need a per-tick form for it.

## 13. What the art layer needs

- New models: `cannon22b` mortar, `flak22`, `supply22`, `supply33`, the shard projectile, a crater tile look. The mortar and the flak go through image-to-3D and the cleanup of D37. The depots and the crater are procedural.
- HUD: two hold slots, the merge ghost, the rule sentence.
- The queue highlight reuses the plate glow of D57. The base keeps its three looks, nothing damaged.

## 14. Defaults taken without a pick

Sebastian picked the Rampart rule, the base as the flag, gun by gun firing with a skip, flak on its own, every building but the base as a target, the AI with reaction and switch times, and the lab with one AI per gun. These four are defaults for his review:

1. The discard goes, two hold slots come.
2. Recipes by iron count and the roster of five guns and three depots, the shield parked.
3. The crater comes from the siege shell. The rocket station is parked.
4. Timber fills a crater, as a dial that is on.
