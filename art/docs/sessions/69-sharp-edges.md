# 69 — Sharp edges at 35 degrees, everything else smooth

Sebastian, 2026-10-23: "We now have all game assets in ablender file, it should have an export script. In
blender, go trough all of them except the organic trees and bushes, and select sharp edges. Use >35 deg.
Then make these lines sharp. Sicne everything else is smooth shaded, this should look nice!"

## Plan
1. The sharp pass as a kit.py step: every collection in kit.blend except the organic trees and bushes goes
   smooth shaded, then every edge whose two faces meet over 35 deg is marked sharp. `sharpen` is its own
   subcommand and runs at the end of `build` and `add` (add only on the ids it folded, so hand-cleared
   marks elsewhere survive); `export` never re-marks.
2. Export re-ships every glb from the marked kit, rubble recut.
3. castle_test reads the pass off the shipped glbs (positions whose vertex normals split 30 deg or more):
   the castle creased, the trees and bushes fully smooth. Watched red before the pass, and the organic
   exemption watched red through a scratch kit sharpened with the guard removed.
4. Boards before/after, docs, merge by push.

## Deliverables

1. **The sharp pass** (C23): [kit.py](../../pipeline/kit.py) `sharpen` - every mesh face set smooth, then
   edges over 35 deg marked (`e.smooth = False`, bmesh's inverted naming); the organic leaf trees and
   bushes are skipped whole, `ORGANIC` in kit.py is the list. `build` and `add` run it on what they fold,
   `add` only its ids, so his hand-cleared marks in the tuned kit survive another asset's rerun; `export`
   never re-marks, so the marks in kit.blend are what a ship carries. One run over the kit: 100 of 106
   collections (the six organic ones untouched), 89408 edges marked, 14072 flat faces smoothed (the wall
   blocks' old flat shading and the flag pole's), no custom normals anywhere, and nothing over 35 deg
   left smooth outside the organics (the 143 edges that are, are all theirs).
2. **The shipped glbs**: 76 re-exported, the rubble of the 18 crumbling models re-cut. Measured on the
   glbs as positions whose vertex normals split 30 deg or more (UV seams copy one normal, so a fully
   smooth model measures 0): castle 0 -> 1288 (max 180 deg), castle_d1.3 0 -> 1334, ship 0 -> 555,
   wall 120 -> 120 (the block edges were already split by flat shading, now they are marks), cannon
   539 -> 496 - the guns' soft regions got *smoother*, the flat era had split everything - flag 16 -> 16,
   and nature_leaf_tree / nature_bush at 0.0 deg max, untouched.
3. **The guard** in `castle_test` (`_splits`, read through the game's importer): the castle must carry
   at least 800 split positions - it ships 1317 - and the organic trees and bushes exactly 0. Watched
   red both ways: before the pass the castle read 0, and a scratch copy of the kit sharpened with the
   exemption removed ships the tree with 20 hard positions at up to 91.3 deg. `Art.instance` returns an
   unparented node - the guard frees its instances, or the runner's ERROR-at-exit gate fails the group.
4. **Terrain bug caught on the baseline suite run** (master's, not the pass's): a shell's leftover
   damage that overkilled a terrain column's last block made `take_damage`'s while-condition re-read
   `columns[tile]` after `_free_tile` erased it - an intermittent `Invalid access` SCRIPT ERROR in
   sim-ai2, intermittent because it needs the overkill case. The loop breaks after the free now, and
   terrain_test's last blow is 25.0 overkill (watched red) instead of the exact kill it was.
5. **Suite green, all 25 groups** (sim-ai2 included - the Terrain fix above took its intermittent
   SCRIPT ERROR with it). The board [69-sharp-edges.png](69-sharp-edges.png): versus at 5 s and player 1's
   castle close-up, before | after, each with a 2x same-region crop of the close-up. The pair is proven
   same-scene before it is read as shading: the wide shots' skyline profile (topmost content row per
   column) deviates 0 px between before and after, so every pixel difference is shading - the models
   changed, the scene did not. What the board cannot show is whether the creases *look nice* - that is
   his call, and C22's tuning pass in kit.blend (clear a mark, `kit.py export`) adjusts it in place.

## Budget

No provider runs: the pass reads the existing kit.blend. Local pipeline, tests and renders only.
