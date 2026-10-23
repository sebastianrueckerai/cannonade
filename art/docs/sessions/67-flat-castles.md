# Session 67: the castles go flat solid materials, the ruin catches its shatter

Sebastian, 2026-10-23: "OK, lets go with flat. Some faces are still assigned wring an the model has bad
geometry... I might fix this later in blender. Make sure the materials make sense: I need to see tham and
know what they are and which ofg them is the one were I assign stuff that changes color based on player.
Yopu can already put the models in game. We go with flat colors. Make sure to use the castles I OKd.
MAke ruined versions of them like last time. Also, make sure on the last ruined stage, at the moment the
castle is destroyed the last ruin shatters to pieces just like walls."

He picks the flat look over the painted texture (D94), keeps the three C21 keepers
(`castle`, `castle.3`, `castle.6`), wants materials he can read at a glance with the player-colour one
named, and the fall to ruins to shatter like the walls' crumble.

## Deliverables

1. **Flat as solid materials** (D94): [paint.py](../../pipeline/blender/paint.py) `flat_materials`
   returns a part id per face and a colour per part instead of a flattened texture; `painted_material`
   makes one solid material a part, named `team` (first, the game paints it in the player's colour),
   `stone`, `dark` and `stone<n>`. The flat painter owns the team split, so `cleanup.py` skips
   `split_team` for it. The castle glbs carry no image at all.
2. **The 15 keeper models rebuilt flat** (castle, castle.3, castle.6 and their four damage states each),
   `cleanup.json` `paint.kind: flat` with `keep_uv: true` over `k: 6, blur: 2`, seeds kept, synced into
   the game. The wrong faces and rough geometry stay his to fix in Blender; the materials are the handoff
   (team = the player colour slot). The three rubbles re-cut from the flat d3s (`fracture.py`): the flat
   d3 is one mesh, so the old multi-part rubble holders matched nothing and the pieces went material-less.
3. **The ruin catches the shatter** (I66): `Castle._ruin_body` gives the d4 ruin a thin static slab over
   its bounds (0.3 m, top at 0.8 of its height), so the d3 pieces of the fall to ruins lie on the rubble
   and none is shoved under the ground. `Crumble`'s lending instance now takes the exact look
   (`Art.instance(look, true)`): without it a base castle's fall drew a random d3 variant and its pieces
   went material-less. Guarded in `tests/walls_test._check_crumble`, watched red.
4. **The board**: `tools/damage_view` over the three keepers × five states in the flat materials, for
   his pass; the material names on the board are the answer to his question.

## Budget

No provider runs: the flat painter reads the baked source textures the assets already carry. Local
pipeline and renders only.
