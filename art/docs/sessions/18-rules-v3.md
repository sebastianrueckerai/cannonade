# Session 18: rules v3, castles are the game

Sebastian, 2026-10-19: build the loop of [rules-v3-draft.md](../game/design/rules-v3-draft.md). Castles become the win object: ten on the versus map (jittered but evenly spaced, Rampart-style), each player starts with one walled in, guns cost parts capped by castles held, castles take 12 shells through the four damage states, hit guns fire slower, and the game ends on a screen with painted art (a ruin against an intact castle) offering Retry and Menu. Locked with him up front: single player and ai4 park from the menu, the win and lose art comes from a painted round, fusion (four cannons make `cannon22a`) ships now.

## The five commits

1. Core and map: [Castle.gd](/home/womb/repos/cannonade/scripts/components/Castle.gd) (damage states, claim, ruin), `castle.tres`, the catalog changes, fusion through the existing cluster, `hits_taken` and the 1.5x reload, the healthy castle synced; `_place_castles` (jittered mirrored anchors at Chebyshev 5, the 255 neutral sentinel, 16-wall start rings), the old start-base path deleted.
2. The check: burn, claim, cap, lose at the build-to-battle switch; the parts gate; the HUD (parts over cap, castles held); the game-over overlay with Retry (same seed) and Menu; practice re-scoped to the standard map with a dormant enemy; `tests/check_test`, every case broken on purpose and watched fail.
3. Parkings: `base`, `upgrade_a`, `upgrade_b` park D64-style; the menu shrinks to Player vs. AI, Watch, Practice with the tutorial on the castle goal; the scenarios migrate to castle starts; a battle side lives while it holds a non-ruin castle.
4. AI: the castle target pool and auto priority (guns, castles, walls), the 40-point castle term in the plan score, the upgrade machinery deleted, `castles_lost` in the lab.
5. Art and bookkeeping: this session's deliverables below, the README, the roadmap.

## Deliverables

1. The castle paint (C14, D73): all five states painted on the D49 path, deterministic through `cleanup.json` seeds, the flat `team` slot kept first. Feeds the game's runtime team paint and every castle on the map.
2. Round 34 ([rounds/34-win-lose/](../../game/art-direction/rounds/34-win-lose/)): six win and lose candidates in the loading style, two boards, two critics, the picks on [PICKS.md](../../game/art-direction/rounds/34-win-lose/PICKS.md). Feeds the game-over overlay behind its Art gate.
3. The bookkeeping: this doc, D73 and D74, the roadmap items, the README.

## Limits

- Spend: 0.96 USD of the session's 10 USD window (six picture edits at 0.15, two critiques at 0.03; the paint itself is local Blender work).
- At most 25 images shown (D19); three boards went to Sebastian's editor, the picks asked by number.
- The Blender socket on 9876 ran the paint and the render pairs; cleanup re-runs went through it too, clobbering its scene each time.

## Result

All five commits are on master and pushed to origin. The first push attempt refused on the main checkout's uncommitted `tools/gun_test.tscn`, a Godot editor re-serialization; Sebastian changed the rule (2026-10-19): he never hand-edits the checkout, so the merge scraps such noise and pushes instead of stopping. The workflow section of [CLAUDE.md](/home/womb/repos/cannonade/CLAUDE.md) now says so. The tuning numbers are first guesses: 12 shells a castle, 4 a gun, 1.5x reload per hit, 6/10/13/15/17 parts, 40 plan points a castle in the ring, 45 s build / 30 s battle. The lab and the sim both run the loop end to end; a 210 s versus sim at seed 5 ends by conquest (the loser's last castle ruined mid-battle, the check eliminating them at the next flip) with both sides under their parts cap the whole way. Known weak spot, left open: when the AI's gun and castle pools run dry, its wall fallback sorts by wall connectivity and can aim at walls out of range, so its guns fall silent until something closer appears; tuning it wants lab time.

Open from earlier sessions: `castle.2`'s height still follows D68's clause until Sebastian answers. Session 17's round folder `33-ground` never made it into a commit (its boards were shot, the pick is D70); the folder is gone from disk, only the docs name it.
