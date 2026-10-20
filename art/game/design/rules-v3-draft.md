# Grid Cannons rules v3 draft: the castles set the guns

The proposed rule set from the design session of 2026-10-18. It supersedes the parts of [rules.md](rules.md) listed in section 10. Every number is a starting value for the lab. Nothing here is built yet.

The game is quick strategy, tower defence meets Tetris. You lose when your last castle falls. The castles you hold set how many guns you may field, so a player who keeps two castles outguns a player who keeps one, and the match tips instead of looping. Everything on the board can be shot, including your own buildings.

## 1. The round

- A round is a wall phase, a cannon phase, then a battle phase: 45 s, 15 s, 30 s (session 38, D86). The wall and cannon phases together are the build.
- In the wall phase you close your walls and stack them; in the cannon phase you place guns and replace what died. You hold one piece at a time, a wall piece or a gun, and see it only on the board where you point.
- Walls come as Rampart pieces (session 24, D75): one block, two, three or four in a row, S, T and cross, drawn at weights 30/25/15/10/10/6/4. A piece stamps a full-tile block on each cell. Blocks sharing a side are one wall; a corner contact does not join.
- You build only near your own: every piece, gun and building needs one tile within 2 tiles of your walls or of a castle you hold that is not a ruin. Guns anchor nothing. The 2 is a first lab value.
- Nobody builds on ground another player's closed ring holds, reach or not (D82). The AI keeps the same rules.
- At the end of the cannon phase the check runs, section 6. Then the battle.
- Shells fly arcs over walls, so walls block no shot. Every building is a legal target at all times, walled in or not.
- A breach during the battle changes nothing. Walls matter only at the check. This is the Rampart rule of [rules.md](rules.md) section 1, unchanged.

## 2. Castles and winning

- Every player starts with one castle. Neutral castles stand between the forts.
- The board is 52 tiles wide and 34 deep, the window's shape. Each side's four neutrals spread across its half from anchors at 0.15, 0.35, 0.65 and 0.85 of the width, jittered at random up to 3 tiles sideways and 2 deep, and stay 5 rows or more from the middle line, so the two halves keep free ground between them (session 38, D86).
- A castle inside your closed wall ring at the check is yours. Wall a neutral castle in and it is yours at the next check.
- A castle of yours that stands open at the check is destroyed.
- A castle takes shells like anything else. Its hit count is a starting value for the lab, 12 as the first guess.
- A destroyed castle is gone for the rest of the match. Castles are never repaired and never rebuilt.
- You lose when your last castle falls: at once when a shell ruins it in battle, at the check when it burns or is claimed away (2026-10-20, I65). In a match of four sides, the last side in wins.

## 3. The parts cap

- Guns cost parts. Walls cost nothing and have no limit.
- The castles you hold at the last check set your cap: one castle 6 parts, two castles 10. The curve past two is for the lab, 13 and 15 as first guesses.
- The cap is a standing limit, not a grant you spend each round. A gun placed in round 2 and alive in round 5 still counts against the cap.
- No income, no banking, no wallet. There is no second number to track.
- A gun that dies frees its parts. You may place a new gun whenever your placed guns sit under the cap.
- If a castle dies and the cap drops below what stands placed, the placed guns stay. You cannot place new ones until you are under the cap again.

## 4. Guns, damage and fusing

- Two basic guns, one part each, and both shoot. Basic gun A is today's small cannon. What basic gun B is, is open, section 9.
- Four basic guns in a 2x2 square fuse during the cannon phase into one bigger building. The pattern names the result: four A the heavy cannon, two A and two B the flak. Further patterns are for the lab.
- A fused building counts its four parts against the cap. Fusing is one way.
- A basic gun takes 4 shells, a fused 2x2 building 8. Starting values.
- The heavy cannon fires a pointed heavy shell worth four shells, 40 against 10, at the basic gun's reload. One heavy shell kills a basic gun, three ruin a castle. A wall dies to any shell, so against walls the heavy opens a quarter of what its four cannons would (session 25, D77).
- A damaged gun smokes and fires slower. Every hit it survives makes its reload longer. The numbers are for the lab.
- Nothing repairs, ever. A damaged gun stays damaged until it dies.
- The upgrade blocks are parked, the way D64 parks a building. The two basic guns are the merge material now.

## 5. Walls

- A wall tile dies to one shell. A double wall takes two, the upper storey first.
- A piece stacks wherever your walls fill every tile under it, whichever pieces placed them, and none of those tiles has a storey yet (D82). Each cell adds a storey.
- Walls have no damage states. A hit wall is a gone wall.
- Walls do nothing during the battle. They block no shell and switch off no gun. Their whole job is the check.
- The check never destroys a wall. Only shells destroy walls.

## 6. The check

At the end of every cannon phase, in this order:

1. Burn. Every building of yours outside your closed wall ring is destroyed: guns, fused buildings and castles alike.
2. Claim. Each castle inside your ring is now yours.
3. Cap. Your cap is recomputed from the castles you now hold.
4. Lose. A player holding no castle is out.

A castle that burns in step 1 cannot be claimed in step 2, so the order matters. Nothing changes ownership in between checks.

## 7. Removal: you shoot it

- There is no scrap, no undo, no take-back of any placement. What you place stands until a shell removes it.
- Your cannons may target anything on the board, including your own buildings. This is the only way to remove your own gun.
- The use is the smoking wreck: shooting your dead gun frees its part for a fresh one.

## 8. The battle

- Every building on the board is a legal target at all times, because arcs clear the walls.
- Firing keeps the revolver cadence of [rules.md](rules.md) section 4: the queue, space to fire the highlighted gun, tab to skip.
- No rule disables anything mid-battle. Walls, wounds and losses all settle at the check.
- Supply depots have no job under these rules, because no gun falls silent. Likely removed, section 9.

## 9. Open questions

- What basic gun B is. It must be worth placing for itself and serve as merge material.
- The fused patterns past 4A and 2A2B, and what 4B makes.
- Supply depots: remove them outright, or keep them as buildings that only take hits?
- The ships and single player. Ships that shell walls still press the check, but their role and the fleet ending are undecided.
- A backstop against two players who never engage: a round cap, or the flood of [rules.md](rules.md) section 1.
- How the draw system meets the parts cap: walls stay random draws, and a placed gun draw costs a part. Whether you draw your gun sort or pick it is open. Answered for walls in session 24: walls are drawn pieces, weighted towards the small ones (D75).
- A visible damage state for castles. They are big enough for one, unlike walls.

## 10. Defaults taken without a pick

- Neutral castles never burn. Only shells remove them.
- The start castle follows the same rule as any castle: close a ring around it in the first wall phase, or it falls at the first check.
- The first wall phase opens the first round. You start with your castle and your 6 parts, nothing else placed.
- Walls never burn at the check. Only shells destroy walls, section 5.

## 11. What this replaces in [rules.md](rules.md)

- Section 1's flag rule. The base as an instant-loss flag becomes the castle: an open castle is destroyed, you lose at zero castles.
- Section 1's line that the base takes no damage. Castles now take shells and fall to shooting.
- The live enclosure check in today's code, which silences guns the moment a wall opens. The check runs once, at the end of the cannon phase, and guns fire regardless of walls.
- Section 3's supply column and section 6's depots. No gun needs supply under these rules.
- The upgrade blocks, parked in favour of the two basic guns.
- The menu text "Destroy the enemy base before yours falls", which names the old ending.
