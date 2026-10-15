# Round 25 — the look (C9)

Question: the game's whole visual grade in one pick — sky, sun, ambient, fog and post, judged on real gameplay scenes both from afar and zoomed in, against the mood of the anchors.

Board 1: eight candidates on three sheets ([scenes/](scenes), boards 1-8 = gg_soft, bridge, sp_fix, dw_lowsun, gg_soft_pop, bridge_v2, sp_goldilocks, lowsun_ivory). Gemini critique per sheet in [boards/](boards). Sebastian liked 1, 2, 4, 5: 1 and 5 soft and cozy, 4 the tile readability of a lower sun.

Board 2: three reworks toward that split ([scenes/p1\*](scenes), boards 9-11 = cozy_grid, honey_grid, bridge_grid).

## Pick

The midpoint of 9 and 10, shipped as soft_honey — Sebastian, 2026-10-14: "Maybe split the difference between 9 and 10 and ship that". Recorded as D52. The frames: [pick-soft_honey_003.png](scenes/pick-soft_honey_003.png) (wide), [pickb-soft_honey_040.png](scenes/pickb-soft_honey_040.png) (close), [pickc-soft_honey_003.png](scenes/pickc-soft_honey_003.png) (zoom). The shipped values live in [../lighting_rules.yaml](../lighting_rules.yaml) under `soft_honey`, the game carries them in scripts/Main.gd and tools/looks.json, and the sky is the 50/50 panorama blend [skies/panorama-soft-honey.png](skies/panorama-soft-honey.png) installed as the game's world_panorama.png.

Ship critique: [boards/ship-critique.md](boards/ship-critique.md) — "Ship as is; the lighting and grading have perfectly met the brief." One friction noted: the ivory trees can read stone or withered from afar, a repaint item for session 11, not a look change.

C11 remeasure under the pick: [scenes/c11-soft_honey.png](scenes/c11-soft_honey.png), clean lit wall face R -0.4% G +0.5% B +0.6% against the game frame. Fitted calibration in the rig [c11_rig.py](c11_rig.py) and in lighting_rules.yaml; the grade now runs in [pipeline/blender/render.py](../../../pipeline/blender/render.py) too (game_view).
