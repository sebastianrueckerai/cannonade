# Round 25: the look round (lighting, sky, colour, post)

Sebastian's brief, 14 Oct: "Make a few skies, and then do a design round: Construct a few realistic scenes, have a critic run over them and adjust colors: Lighting, skybox, textures, colors... There are a lot of variables. You can also dip into post processing but make it mobile friendly. Go broad first. Judge the board from afar as well as zoomed in. Find a few different candidates that visually match our vision and concept art in terms of mood. Make it cozy. In the end I want about 3 to 10 variants to choose from, the best from what you were able to do!"

## Machinery

- Game tools: `tools/looks.gd` + `tools/looks.json` (game repo, uncommitted until the pick). `--style=NAME` on `screenshot.tscn` and `shoot_battle.tscn`, `--artseed=N` pins asset variants. Fog `range` scales the span from begin to end; post = tonemap + exposure/white + brightness/contrast/saturation + glow, all GLES3-safe (no SSAO/SSR/DOF/SDFGI).
- Scenes: SC1 wide = `screenshot.tscn --mode=single --seed=1 --artseed=7` (grass map, one fort, painted nature, sky behind). SC2 close = same + `--look=8,8`. SC3 battle = `shoot_battle.tscn --artseed=7` (all first-batch buildings, no nature by sandbox design).
- Skies: `skies/sky-*.png` raw 16:9 with sidecars, centre-cropped to 2:1 as `panorama_*.png`, dropped into the game's `assets/art/sky/`. Round 24's haze = `world_panorama.png` (the current default).
- Determinism: seed 1, artseed 7 everywhere, so boards differ only by the style knobs.

## Pass 1 (breadth): 12 lighting/post styles on the round-24 haze + flat blue

base_current, flat_blue, warm_gold, bright_air, pastel_haze, golden_glow, crisp_day, cozy_overcast, deep_warm, airy_blue, honey_fog, storybook_pop. Montage `boards/pass1.png`, critique `boards/pass1-critique.md`.

Result: top three deep_warm, golden_glow, storybook_pop. Flat blue killed ("cheap digital skybox, cut-out effect"); washed-out hazes killed (pastel_haze, honey_fog); cozy_overcast reads dreary; bright_air neon. Warm cream haze beats flat blue across the sheet. Advice folded into pass 2: cooler shadow fill for deep_warm, less glow for golden_glow, less saturation for storybook_pop, deeper softer shadows from a lower sun (sun_angle knob added to looks.gd).

## Pass 2: skies crossed with the shortlisted styles

12 variants (`boards/pass2.png`, critique `boards/pass2-critique.md`). Result: top four gg_soft, bridge, sp_fix, dw_lowsun; sp_warm reads jaundiced, dw_cool drab. Backdrop verdict: warm honey = most mood but tints the board; blue-leaning = most readable but cold morning; soft ivory = the compromise that serves both.

## Pass 3 (final): four refinements + close and battle scenes

gg_soft_pop (more contrast), bridge_v2 (greens tamed), sp_goldilocks (a hair warmer), lowsun_ivory (36-degree sun on the ivory sky), each against the four pass-2 keepers, every candidate rendered wide, close (`--look=8,8`) and in the battle scene. Final board of eight candidates for Sebastian.

Final critic verdict (`boards/final-critique.md`, candidates numbered as on the board): ship #5 gg_soft_pop, #7 sp_goldilocks close second, then #4 dw_lowsun, #1 gg_soft, #2 bridge, #3 sp_fix, #6 bridge_v2, #8 lowsun_ivory. Its one fault on #5 was blown highlights on sun-facing cream; fixed with exposure 0.94, white 6.5, glow 0.25, re-rendered wide/close/battle and re-checked (highlights now hold form). Sheets: `boards/final-wide.png`, `boards/final-close.png`, `boards/final-battle.png`.

## Rework pass: cozy of 1/5 with the tile pop of 4

Sebastian shortlisted 1, 2, 4, 5: "1 and 5 look nice and soft and cozy, but 4 makes the individual tiles pop more which may be necessary for the player making out the grid." Three new candidates, each a different route to that blend:

- cozy_grid: candidate 5 unchanged in mood, sun to 40 degrees, shadow to 0.56, ambient dimmed one step (0.46, a touch cooler), contrast up.
- honey_grid: candidate 4 softened toward cozy (brighter less-orange sun, warmer ambient, fog, less glow); keeps the 36-degree sun and honey sky that pop the tiles.
- bridge_grid: candidate 2 with the same pop knobs (40 degrees, shadow 0.54, contrast 1.05).

Each rendered wide, close and battle as r2-*, r2c-*, r2b-*.

Rework critic verdict (`boards/rework-critique.md`, against his cozy reference p3-gg_soft_pop and readability reference p2-dw_lowsun): ship 11 bridge_grid, "the only option that successfully resolves the brief's central conflict between soft mood and grid readability". 9 cozy_grid fails the brief (grid almost invisible when squinting, washed-out, stark backdrop); 10 honey_grid has the clearest grid but its dark saturated shadows read "slightly grim". Candidate 11's one named fault, the plain off-white backdrop, was fixed before the sheets (fog colour #f4e6cd, sky_affect 0.25) and re-rendered; the sky band now measures in family with gg_soft_pop's.

## Pick: soft_honey, the split of 9 and 10 (D52)

"Maybe split the difference between 9 and 10 and ship that." The midpoint is built knob by knob: sun between the two (#ffd29d at 0.65, 38 degrees), ambient between (#bec3c4 at 0.46), shadow 0.56, the fog of both (#f4e6cd, sky_affect 0.2), filmic post (exposure 0.97, white 6.25, saturation 1.07, contrast 1.05, glow 0.26), and the sky as a 50/50 pixel blend of the soft and warm panoramas ([skies/panorama-soft-honey.png](skies/panorama-soft-honey.png)), installed as the game's `world_panorama.png`. Frames: [pick-soft_honey_003.png](scenes/pick-soft_honey_003.png) wide, [pickb-soft_honey_040.png](scenes/pickb-soft_honey_040.png) close, [pickc-soft_honey_003.png](scenes/pickc-soft_honey_003.png) zoom.

Ship critique ([boards/ship-critique.md](boards/ship-critique.md)): "Ship as is; the lighting and grading have perfectly met the brief." One friction: the ivory trees can read stone or withered from afar — a repaint item on the assets for session 11, not a look change.

C11 remeasure under the pick ([scenes/c11-soft_honey.png](scenes/c11-soft_honey.png)): the same wall row as `shoot_battle.tscn --look=10,2` rebuilt in EEVEE by [c11_rig.py](c11_rig.py), fitted until the clean lit face band matches the game frame at R -0.4% G +0.5% B +0.6%. Calibration: sun_energy 13.6, ambient_strength 0.16, ambient_blue_scale 0.92, grade_sat 0.5. Two findings along the way: the game frame's flat upper face carries no crenellation shadow (Godot's shadow range skips it) so the fit band is Blender's lower clean strip; and [render.py](../../../../pipeline/blender/render.py) gained `game_view`, which now runs the grade (view transform, exposure in stops, saturation and contrast as compositor nodes) in every EEVEE preview, with grade_sat absorbing Godot's display-space vs Blender's scene-linear saturation difference. Known gap: no white point or glow equivalent, the shoulder shape differs.

## Spend

5 skies at ~0.25 actual = ~1.25 USD, 6 critique calls at ~0.03 = ~0.18 USD (one truncated answer re-run, one ship critique wasted on a wrong prompt and re-run). Session total: ~3.46 USD of 14.

## Post-pick sync (done)

- [lighting_rules.yaml](../../lighting_rules.yaml): `picked: soft_honey`, the variant carries the shipped values and the fitted `blender_eevee` calibration; the no-grading rule is amended to the D52 reality.
- Game repo: `looks.json` soft_honey entry, `Main.gd` environment block, `assets/art/sky/world_panorama.png`.
- C11 remeasured for the 38-degree sun, `render.py` follows the pick through `game_view`.

