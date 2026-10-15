# Session 12: the mortar, the flak and the big depots

Start prompt for the session: "Run session 12 from docs/sessions/12-advanced-buildings.md. Go."

Roadmap item: C6, the building set. It also builds the models of B18, which is ticked only when the game plays the recipes of [rules.md](../../game/design/rules.md) section 7, in session 13.

## Why these deliverables

- **Rules v2 cut the roster and named the gaps.** D59 and [rules.md](../../game/design/rules.md) leave five guns and three depots. Four have no model and show as grey boxes: the mortar `cannon22b`, the flak `flak22`, the depots `supply22` and `supply33`. The mortar also fires two projectiles without art, the cluster bomb and its shard.
- **Sebastian wants the models before the rules.** "We will need those anyways, and we can worry about testing the game after, at least the tests will look nice with these models." Session 13 puts rules v2 into the game and shoots every lab battle and gate board with these buildings.
- **Not in this session:** the shield and the rocket station, parked in rules.md section 11. The crater tile, which follows the siege shell's crater in session 13.

## The brief per building

From rules.md sections 3 and 6, the gun rules of D28 and D39, the era ladder of D16.

| id | footprint | plays | the look to sketch | parts | triangles |
|---|---|---|---|---|---|
| `cannon22b`, mortar | 2x2 | lobs a bomb that bursts into five shards, the hit tiles burn | a squat wide-mouthed iron mortar in a heavy iron bed on the round turning mount, tier 2 industrial. A sidegrade of `cannon22a` that reads as a different gun at the default view: a short fat tube at 45 degrees against the long gun | `barrel` on a trunnion pivot, `projectile_spawn`, `plate` | 1,500 with the plate (D37) |
| `flak22` | 2x2 | fires itself at balls passing within 4 tiles | a twin or quad mount of thin barrels pointed at the sky, tier 2 to 3, dark iron, on the round mount. It must not read as a wall gun | `guns`, the part the game turns toward its target, `plate` | 1,500 with the plate |
| `supply22` | 2x2 | 10 supply from four timber blocks | a timber yard: stacked logs under a roof, the warm brown of the timber block (D32). A bigger cousin of the four 1x1 depots of D38 | none | 600 |
| `supply33` | 3x3 | 16 supply from a 3x3 of mostly timber | a warehouse or granary with a loading gantry, timber, the biggest building on the map after the base | none | 600 |
| cluster bomb, shard | 0.3 m, 0.12 m | the bomb flies, bursts at 70 percent of its flight, five shards fall | the bomb a rounder, banded iron ball that reads apart from the 0.28 m shell, the shard a chunk of iron | none | under 100 each |

One look per building. The depots of D38 got four looks because a map holds many 1x1 depots. A 2x2 or 3x3 stands once or twice.

## Plan

1. **Sketches.** Round 28, one painted board per building on the D30 painting rules, the anchors beside it ([gun_ladder.png](../../game/art-direction/anchors/gun_ladder.png), [resource_blocks.png](../../game/art-direction/anchors/resource_blocks.png), the depot board of round 19), the parts marked. A pick per building, images open in his editor, boards named by number.
2. **Build.** The two guns through the generative route of [assets-3d.md](../process/assets-3d.md): reference view, Meshy ladder, pieces, `split.json` by hand, `final`, the check sheet, the bench. The flak's moving part is `guns`, not `barrel`, so step 5 of the route gets its first part that is not a barrel. The depots on the route the "Which route" section picks, painted on the D49 path. The projectiles procedural in a `build.py` like the shell.
3. **Gate.** The acceptance ladder of assets-3d.md: report, wire, sheet, critic, then Sebastian once per new class. The guns measured from above after placement, mount against plate under 0.02 m. One gate board in the sandbox battle with all four buildings placed and the mortar firing, every asset big (D48).
4. **Ship.** Approve, `godot_sync.py`, reimport, `check_art`, `run_tests.sh`, the game commit. [asset_list.md](../../game/art-direction/asset_list.md) rows updated, C6 ticked. Then the session 13 plan: rules v2 in the game.

## Game changes named

- `data/buildings/supply33.tres`: 3x3, 16 supply, no recipe yet. The sandbox needs it to place the model. The recipes stay as today until session 13.
- [tools/shoot_battle.tscn](/home/womb/repos/grid-cannons/tools/shoot_battle.tscn): both forts hold the four new buildings.
- [scripts/Art.gd](/home/womb/repos/grid-cannons/scripts/Art.gd): the `guns` anchor checked with the flak the way F8 checked `barrel`.
- Nothing else in the game. Gameplay code waits for session 13.

## Limits

- At most 25 new images shown per round (D19). Sketches are paintings (D30).
- 600 triangles per building, 1,500 per 2x2 gun with its plate (D37). Everything seeded and sidecarred.
- Spending cap 14 USD in `.env.session`, rewritten at session start.
- Game changes land on `master`, limited to the list above.

## Done when

The mortar, the flak and the two depots stand painted in the game and in the sandbox battle, the bomb and its shards fly from the mortar, asset_list.md says so, C6 is ticked, and the session 13 plan is written.
