# Session 61: eight castle looks, dealt at random

Sebastian, 2026-10-22: "I want alternatives to the existing castle. They should have the same thing were some
textures can carry the player color. They should all have the same states of destruction as the one castle we
have. There were already promising sketches I think. You can also just generate variations on the existing ones.
I would like to have about 8 models, which then should randomly be placed as castles."

The castle becomes a set of looks like the walls' four (C17): every placed castle draws one at random
(`Art.instance` already picks among `castle.glb`, `castle.2.glb`, ...), and the look is pinned for its whole
life, because the damage chain is per look: look v's state n is the model `castle_d<n>` for v = 1 and
`castle_d<n>.<v>` for v > 1, in asset folders `castle_d<n>.<v>` so [fracture.py](../../game/assets/3d/fracture.py)
writes `castle_d3.<v>_rubble.glb` for the fall to ruins.

## Deliverables

1. **The game pins the look** (I104): [Castle.gd](/home/womb/repos/cannonade/scripts/components/Castle.gd)
   reads the drawn look off its Art node and resolves its five state ids through it, the ruin crumbles as its own
   look's d3. A test guards the pinning and the completeness rule: every healthy look on disk owns its four
   damage states and its d3 rubble.
2. **castle.2's damage chain** (the chunky keep of D69): four states as chained picture edits from its own
   reference picture, the D72 way, plus the D73 paint pass (it still wears the raw Meshy texture; the other
   seven looks paint on the D49 path, so it joins them).
3. **Six new looks** (castle.3 to castle.8), each healthy plus four damage states:
   - castle.3, castle.4: designs 1 and 4 of the round 32 multi-part board
     ([castle4.png](../../game/art-direction/rounds/32-castle/castle4.png)), the unpicked sketches Sebastian
     remembers. His request resolves C13's open question by widening the set instead of swapping the one.
   - castle.5 to castle.8: nano-banana variations of the two existing castles' reference pictures (his words:
     "just generate variations on the existing ones"), different part arrangements in the same Bergfried
     language of D68: one main mass, joined smaller volumes, royal blue team parts.
4. **The board**: one sheet of all eight looks × five states (pipeline renders), a battle screenshot at several
   art seeds, and [tools/damage_view.tscn](/home/womb/repos/cannonade/tools/damage_view.tscn) widened, for
   Sebastian's pass. The looks ship synced unapproved like the faction walls did (C17); his pick or rework
   closes C21.

## Budget

Planned spend: 6 healthy reference pictures + 7 damage chains base pictures + 28 damage edits ≈ 41 picture edits
at 0.15 USD = 6.15 USD; 30 Meshy runs (6 healthy, 24 damage) at 0.30 USD = 9.00 USD; total ≈ 15.20 USD, plus
repeats when a run comes out too tall, too fine or off-style (session 16 repeated most of its chain once).
SESSION_CAP_USD 30.

## Limits

- The route table binds buildings to generative on Meshy with cleanup by hand (D36); damage states ride the
  approved picture-chain (D72). Chunky damage, big simple shapes, no gravel, no cracks, no fire.
- The look stays in the D68 language: multi-part keep, every part touching, team parts (roofs, banner, deck)
  reading at the default view, royal blue in the reference pictures. castle (look 1) stands 3.5 m tall by
  Sebastian's D71 pick; the new looks keep his varied heights under one honest `max_z` a piece in asset.yaml.
- d1 and d2 carry team parts, d3 and d4 are bare stone, paint kind stone, a seed a state, `fit` 2.9, max 3500
  tris, the flat team material first so the runtime paint keeps working (D73).
- Every picture and mesh gets its sidecar; the chain states name their ref (the previous state's picture).

## Result

All eight looks ship, each with its four states and its d3 rubble: healthy heights 3.52 (castle), 1.30
(castle.2), 2.90 (castle.3, the bergfried of design 1), 1.06 (castle.4, design 4's hall), 1.98 (castle.5,
twin drums), 2.90 (castle.6, tower and drum), 1.99 (castle.7, one-turret keep), 1.17 (castle.8, hall and
gatehouse) — tris 2456 to 3246, every state under 3500, every asset limits_ok. The rubbles run 23-33
pieces. The paint seeds run 62-100 across the set, one a state. The pin and the exact-attach fix shipped
mid-session (watched red: constant state ids fail 31 family checks across looks 2-8; green after).

Two suites were still written for the one-look world and went red on the wider set, both fixed look-relative:
walls_test compared the ruin's pieces against look 1's castle_d3 stone and now resolves the worn look's own
severe model; check_test left the look draw unseeded and its hidden-tile search around one castle — a squat
look (castle.2) hides no free tile at the game camera, so the fade check could not even stage — it now seeds
Art._rng like its sibling tests and walks the neutrals for a castle that hides one. Suite green, 24 PASS.

Spend ~$20.70 of the 30 cap: 8 healthy reference pictures, 24 chained damage edits, 30 Meshy runs.

Boards for the pass: /tmp/damage_view.png (all eight looks × five states, team parts painted), and three
ai4 battles at art seeds 11, 23, 37 (/tmp/board1_005.png to /tmp/board3_005.png). Not verified here: the
look of any generated picture or mesh — no image judgement in this harness. Sebastian's pass closes C21.

### Follow-up, 2026-10-23: rejected looks out of the game (I105)

Sebastian wants the rejected castles gone from his game now, not after the texture round. Looks 2, 4,
5, 7 and 8 are deleted from the game layer (30 glbs + imports, manifest pruned); their art parks with
`parked: true`, which godot_sync now respects even under --force (retroactively covering cannon.2 of
D92). Art.variants reads the manifest so the keeper looks .3 and .6 stay reachable past the gap;
castle_test pins the shipped set. The keepers' stone texture is still open: painted courses vs Meshy
retexture vs the flat colours, boards/flat_vs_meshy.png is the flat try beside Meshy's own.
