# 68 — Flat everywhere, one kit file, castle flags, random yaw

Sebastian, 2026-10-23: "switch the project to flat textures everywhere... I want one Blender file holding
all assets with a script exporting them... You do an initial round of assigning flat colors on all models...
Each castle should have a flag as a seperate object... it only goes down when the castle crumbles...
Random castles randomly in 90 degree steps when placing them."

## Plan
1. Flat pass, every family (D94's recipe, session 67, extended): parked castles, supply family, base, ship,
   upgrade, guns (barrel.py final gains a flat step), walls (yaml paint -> materials), tiles + tile_damage,
   shells, terrain, nature (band materials from its own gradient stops). Part names become nearest
   palette.json `world` role, `team` stays the player slot, first.
2. art/game/assets/kit.blend: one collection per asset id, appended from every source.blend after the flat
   pass, materials shared by name; the per-asset source.blend and final.glb go away, the folders keep
   their configs and raw provenance. art/pipeline/kit.py builds it, exports every collection to the game
   (glb + manifest) and re-cuts rubbles; it replaces godot_sync.py as the one maintenance path.
3. Flag: a `flag` collection (pole + cloth), a `flag_dock` empty on every keeper castle state d0-d3, docked
   where the keep survives that state; Castle.gd flies it outside the art, re-docks on every state swap,
   paints it with the owner colour (neutral #9c7a4f), and it topples and goes at become_ruin. Cloth wears
   materials/flag.gdshader, a TIME wave; U.set_color/set_alpha write shader materials' colour.
4. Random 90-degree yaw for placed castles, drawn from Art._rng in GameController._place_castles.
5. Tests (watched red), suite green, render boards, docs (D95/D96, assets-3d chart, process log,
   ROADMAP ticks, this file finished), merge by push.

## Deliverables

1. **Every family flat** (D95): the flat pass of session 67 run over the whole kit - parked castles,
   supply, base, ship, upgrade, guns (`barrel.py` gained the flat step), walls (yaml paint to solid
   materials), tiles and tile_damage, shells, terrain, nature (band materials from its own gradient
   stops). Part names come from the nearest `palette.json` world role, `team` stays the player slot and
   stays first, so his "which material is the player colour" answer holds everywhere: `team`.
2. **One Blender file** (D96): [kit.blend](../game/assets/3d/kit.blend), one collection per asset id,
   built by [kit.py](../../pipeline/kit.py) (`build`, `add <id>...` after a rerun or a hand edit,
   `export` with a fresh budget gate and the rubble recut). The per-asset `source.blend` and `final.glb`
   are gone (105 each); the folders keep their configs and raw provenance. [godot_sync.py](../../pipeline)
   is retired - kit.py is the one maintenance path. His tuning surface is kit.blend: fix a face, reassign
   a material, `python3 kit.py export <id>`. The `team` material reads white in Blender; the game paints
   it in the player's colour at runtime.
3. **The flag** (I115's sibling, C22 open for his pass): a `flag` collection (pole + cloth), a
   `flag_dock` empty on every keeper state d0-d3, docked where the keep survives that state. The cloth
   wears [flag.gdshader](../../../materials/flag.gdshader) (a TIME wave); `Castle._fly_flag` parents the
   flag outside the art, `_dock_flag` re-docks it on every state swap, it topples only at `become_ruin`.
   Two Godot traps on the way: `go.add_child(flag)` from inside `Castle._ready()` is silently dropped -
   `_ready` fires inside `BuildingPlace`'s `add_child` propagation, and a reentrant `add_child` on the
   parent no-ops without an error - so the fly is `call_deferred`; and `U._shader_param` never looked at
   `material_override`, so the cloth's shader albedo never got the owner colour - it does now, which is
   also why the cloth can go alpha in the fall. `castle_test` guards the state-0 dock and the quarter
   turn, watched red both ways (the direct `_fly_flag()` call left 51 checks failing).
4. **Random quarter turns**: `Map.place_neutral` yaws a placed castle by `PI / 2 * Art._rng.randi_range(0, 3)`
   - the placement path itself, not the plan's `GameController._place_castles`, and `Art._rng` so the
   map build does not perturb the battles' shared stream.
5. **Walls went flat with the rest**: the band paints `STONE.lerp(team, band_tint)` straight (the old
   code divided by STONE as a texture factor, a convention the WHITE slot carried);
   `walls_test` expects the flat values now.
6. **Suite 26 of 26** (castle_test grew the flag guards; the shader's `NORMAL` went lowercase once and
   the catalog group caught it - a reminder that direct test runs must grep ERROR lines, not just
   PASS/FAIL). The board [68-flat-kit-versus.png](68-flat-kit-versus.png): versus at 5 s, both castles
   flying their player's colour above the keep (pixel-checked: each faction's colour sits in a small
   patch above the castle mass, gap for the pole, no stray team blobs - no guns are placed at 5 s).
   C22 stays open: his flat-tuning pass in kit.blend closes it.

## Budget

No provider runs: the flat pass re-reads the baked sources like session 67's. Local pipeline, tests and
renders only.
