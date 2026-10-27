# Session 75: the kit shows the game, each castle with its stages

Roadmap item: C24.

Sebastian, 2026-10-27: "This contains a lot of castles and bases. I dont know why these are seperate. Its the
same thing. Make sure its up to date. Only a few castles made the cut and those I need with the stages of
destruction. A castle should have its destroyed stages in one folder and naming should be so they are easy
to find. Export should still work. Fix it!"

## Why these deliverables

- **The kit is his tuning surface (D95), so it must show the game.** It held 106 flat collections: eight
  castle looks times five stages, three bases, parked guns and walls, every source's render sun. The game
  plays three castle looks (I109) and no base at all: the `base` building has been parked since the
  castles took its place (its def carries `parked = true`, catalog_test pins `get_def("base") == null`),
  yet its three models still shipped as glbs and sat in the kit next to the castles.
- **A castle is one thing with five stages.** In the game a look's stages are `castle.3`, `castle_d1.3`
  and on, the stage before the look's dot; sorted flat in an outliner the stages of one look lie eight
  rows apart.
- **Parked stays, out of sight.** A parked asset's mesh lives only in the kit now (the per-asset
  source.blend left the repo in session 68), so parked collections move under one excluded root instead
  of being deleted.

## Layout

```
kit                       what the game plays
  castle                  group of look 1: castle.d0 (castle.glb) ... castle.d4 (castle_d4.glb)
  castle.3                castle.3.d0 (castle.3.glb) ... castle.3.d4 (castle_d4.3.glb)
  castle.6
  cannon, cannon.3, cannon22a, ... wall, wall_upper, ... flag
parked                    excluded from the view layer; what a manifest parks
  base, base.2, base.3, cannon.2, cannon.4, wall_arch, wall_caps, wall_straight
  castle.2, castle.4, castle.5, castle.7, castle.8 (each with its five stages inside)
```

Objects: `<collection>.<part>`, the castle's body part `castle` in every stage (was `castle_d1.3`), the
dock `flag_dock`. The render suns (`game_sun`, a light in every folded source) are gone.

## Plan

1. [kit.py](../../pipeline/kit.py): the id-to-collection rule (`place`), nested groups for a staged family,
   the `parked` root, fold skips lights, export derives the id from the collection name and prunes a parked
   asset's files and manifest entry from the game, params to Blender as JSON (no `%` trap).
2. A one-off migration script regroups the existing kit.blend in place: the sharp marks and every hand
   edit survive, nothing is re-folded.
3. The three base manifests park. Export with `GAME_REPO` at this worktree: base glbs and entries leave,
   every other entry's size and tris unchanged against the saved manifest.
4. `kit.py add` proven on a stage re-folded from a scratch source.blend: it lands in its group with its
   dock.
5. castle_test pins that no base model ships. Suite green.
6. Boards: tools/damage_view before and after. Docs: D101, process log, integration page, READMEs,
   ROADMAP C24, this file. Stale `grid-cannons` repository paths in art, the contract yaml and
   fracture.py follow the repository move.

## Limits

- No provider runs, no spending. Local Blender and Godot only.
- Game changes: the base glbs and manifest entries leave, castle_test gains one check, nothing else.

## Result

[kit.blend](../../game/assets/3d/kit.blend) opens on two roots. `kit` holds the 61 collections the game
plays: three castle groups with their five stages each (`castle.d0` to `castle.d4`, `castle.3.d0` to
`castle.3.d4`, `castle.6.d0` to `castle.6.d4`), the guns, walls, nature, terrain, shells, ship, supply,
upgrades and the flag. `parked`, excluded from the view layer, holds the three bases, `cannon.2`,
`cannon.4`, the three parked wall blocks and the five rejected castle looks with their stages. The
one-off migration moved 48 collections, renamed 62 objects (`castle_d1.3.castle_d1.3` is
`castle.3.d1.castle` now), dropped the 41 render suns and drew flag docks on the 20 parked castle stages
d0 to d3; no mesh was re-folded, so every sharp mark survived.

[kit.py](../../pipeline/kit.py) carries the rule both ways: `place(id)` puts a game id into its
collection, group and root by the asset manifests and `id_of(name)` reads the id back at export. Export
shipped 73 models with every size and tri count equal to the saved manifest (only the `parts` names
changed, the body of every castle stage and every numbered nature and terrain look is its family name),
re-cut the 18 rubbles and pruned the three bases: `base.glb`, `base.2.glb`, `base.3.glb`, their
`.import` files and manifest entries. The Blender scripts take their parameters as a JSON file after
`--`. A partial ship (`export <id>`) re-cuts only the rubble it shipped.

`add` proven on `castle_d2.6` re-folded from a scratch source.blend cut off the kit: it landed in
`castle.6` as `castle.6.d2` with its body `castle`, a `flag_dock` at the same point (-0.0994, 0.3073,
1.6671) and the same 1593 sharp edges; its export gives the same size and tris as before.

[75-kit-castles.png](75-kit-castles.png) is tools/damage_view's board of the three keepers' five
stages after the export; the board rendered before the export is byte-identical (same md5).

castle_test pins the base absent, watched red with `base.glb` back in the folder and green without.
