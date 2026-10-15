# Asset list

Every asset the game needs, read from the game data in [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons) on 12 October 2026: `data/buildings/*.tres`, `data/projectiles/*.tres`, `prefabs/`, `prefabs/walls/`, `assets/fbx/`, `assets/nature/`, the scenes and the scripts that pick models. Phase H of [art-direction.md](../../docs/process/art-direction.md). Sebastian set the first batch on 12 October (D33).

## How to read the list

- **Footprint** comes from `size` in the data, never from a picture. A footprint of 1 is one tile, 1 m by 1 m.
- **Step** is the step of the era ladder (D28): 1 is medieval and age of sail, 2 is bigger guns, 3 is iron and early industry. Everything outside the gun ladder belongs to step 1.
- **Priority:** the first batch goes first (D33). Later items follow once the first batch holds in the game. Items that wait need a game-design decision first, mostly the upgrade tree v1 (D17, roadmap B18).
- **Route:** procedural Blender, image-to-3D, or hybrid, per [assets-3d.md](../../docs/process/assets-3d.md). The guns come from image-to-3D first (D34).
- **Variants** names every version the game asks for, so the count is known. A variant is made from the approved first item, never from scratch.
- **Slots** are the model files the game loads for one id. The game picks one of a wall's slots at random for each wall it places.

## How the game makes its buildings

- **Draws.** The player always holds a wall piece and a building, both drawn at random. The wall is a line, a corner, a tee or a cross. The building is the 1x1 `cannon`, timber block `upgrade_a` or iron block `upgrade_b`, one chance in three each (D32).
- **Merges.** A full 2x2 or 3x3 square of blocks merges into one building, and the blocks vanish. The mix of timber and iron picks the building. A square that matches no pattern becomes `cannon22a` or `cannon33a`.
- **The depot.** Timber placed on timber makes the 1x1 supply depot. It never merges.
- **Supply.** Each depot inside closed walls gives 4 supply. A 2x2 building needs 4, a 3x3 building needs 9, `cannon33c` and the 1x1 gun need none. A building without enough supply stays off.
- **Guns in play.** Every plain gun fires the same cannonball: 10 damage, one shot every 2 s, a range of 40 tiles. Only the cluster gun and the rocket station fire something else.

## What the game data says about variants

- **Team colours.** Only the base shows a team colour. `PlayerController.build_start_base` paints the first material of every mesh under the base in the player's main colour. No gun, wall or other building is painted. So the base needs the team material first on every mesh, and no gun needs team variants.
- **Damage states.** The game has none. A building has 10 health points and no damaged model. A hit that destroys a wall makes it fly and vanish. Damaged models are an idea for later (roadmap C7), not a need.
- **Tile colours.** The game paints the tile mesh. `Map.gd` picks the open ground from two colour ranges, sand and grass, one per map, the enclosed ground and the ground under a wall from a stone range a shade darker than the walls, the water from the sea, and a burning tile turns red. Since session 07 the ranges come from [palette.json](palette.json).
- **Wall levels.** A wall placed on the ground shows a lower model. A wall placed on top of a wall shows an upper model. A wall stacks once. Each shape has 5 to 7 slots per level, 43 slots in all.
- **Nature.** The map draws a random subset of 9 nature kinds, each with 4 to 6 FBX variants, 45 models in all.

## 3D world

| id | class | footprint | step | priority | route | variants | status |
|---|---|---|---|---|---|---|---|
| cannon | gun | 1 | 1 | first batch | Meshy, cleanup by hand, part `barrel` on the trunnion pivot, empty `projectile_spawn`, square `plate` (D39) | the small gun of [gun_ladder.png](anchors/gun_ladder.png), the swivel gun on a wooden post (D31) | in the game (D37, D39), inside its square since D61, [final.glb](../assets/3d/cannon/final.glb) |
| cannon22a | gun | 2 | 2 | first batch | Meshy, cleanup by hand, `barrel`, `projectile_spawn`, `plate` | the medium gun of the ladder (D31) | in the game (D37, D39), inside its square since D61, [final.glb](../assets/3d/cannon22a/final.glb) |
| cannon33a | gun | 3 | 3 | first batch | Meshy, cleanup by hand, `barrel`, `projectile_spawn`, `plate` | the large gun of the ladder (D31) | in the game (D37, D39), inside its square since D61, [final.glb](../assets/3d/cannon33a/final.glb) |
| supply | building, the supply depot | 1 | 1 | first batch | Meshy, cleanup by hand with cleanup.py | timber on timber. Four looks, `supply` to `supply.4`, from [depot.png](rounds/19-first-batch/depot.png) (D38) | in the game |
| upgrade_a | resource block, timber | 1 | 1 | first batch | Meshy, cleanup by hand with cleanup.py | the crate with log ends of [resource_blocks.png](anchors/resource_blocks.png) (D29, D32), 572 triangles (D38) | in the game, [final.glb](../assets/3d/upgrade_a/final.glb) |
| upgrade_b | resource block, iron | 1 | 1 | first batch | Meshy, cleanup by hand with cleanup.py | the crossed ingots of [resource_blocks.png](anchors/resource_blocks.png), 490 triangles (D38) | in the game, [final.glb](../assets/3d/upgrade_b/final.glb) |
| wall_line | wall | 1, a straight run through the tile | 1 | first batch | procedural, the cornice look [wall_cornice.py](../assets/3d/wall_cornice.py) (D38) | lower: 6 slots, `line_base1` to `line_base6`. Upper: 5 slots, `line_upper1` to `line_upper5`. One look per level fills every slot | in the game as `wall_line_base` and `wall_line_upper`, one look in every slot |
| wall_corner | wall | 1, an L from the tile centre | 1 | first batch | procedural, the cornice look [wall_cornice.py](../assets/3d/wall_cornice.py) (D38) | lower: 5 slots, `curve_base1` to `curve_base5`. Upper: 5 slots | in the game as `wall_curve_base` and `wall_curve_upper`, one look in every slot |
| wall_tee | wall | 1, a T | 1 | first batch | procedural, the cornice look [wall_cornice.py](../assets/3d/wall_cornice.py) (D38) | lower: 5 slots, `tri_base1` to `tri_base5`. Upper: 5 slots | in the game as `wall_tri_base` and `wall_tri_upper`, one look in every slot |
| wall_cross | wall | 1, a cross | 1 | first batch | procedural, the cornice look [wall_cornice.py](../assets/3d/wall_cornice.py) (D38) | lower: 5 slots, `cross_base1` to `cross_base5`. Upper: 7 slots | in the game as `wall_cross_base` and `wall_cross_upper`, one look in every slot |
| base | building, the start base | 2 (D40) | 1 | first batch | Meshy, cleanup by hand with cleanup.py, team faces on a first material | three looks, `base` to `base.3`, designs 1, 3 and 4 of [base.png](rounds/19-first-batch/base.png) (D38). 4 team colours, painted by the game on the first material of every mesh | in the game. Every look shows its team colour on a flag and a coloured roof, the deck of `base.2` is its roof (D42) |
| tile | terrain | 1 | 1 | first batch | procedural, [build.py](../assets/3d/tile/build.py) | one mesh, painted by the game: open grass or sand, enclosed, water, burning. Height jitter of 0.1 m by the game. Colours from the palette in `Map.gd` | in the game |
| shell | projectile, the cannonball | 0.28 m | 1 | first batch | procedural, a sphere, [build.py](../assets/3d/shell/build.py) | none | in the game |
| wall looks 2 and 3 | wall | 1 | 1 | dropped (D43) | procedural | the ledge and the walkway of round 19 | dropped: the cornice is the only wall look |
| ship | ship | 1 water tile | 1 | later | image-to-3D | carries `ship_cannon`. Single player only, the fleet sails from the board edge | open |
| ship_cannon | gun on the ship | part of the ship | 1 | later | with the ship | none | open |
| nature: leaf tree, boulder, bush | nature | part of 1 | 1 | later | open | 6, 5 and 4 FBX variants today. Needs the game wiring of roadmap F7 | open |
| nature: big leaf tree, evergreen, grass, mushroom, stones, twiggy | nature | part of 1 | 1 | later | open | 5 FBX variants each today | open |
| cannon22c, cannon22d | gun | 2 | 2 | cut (D59) | they played the same as `cannon22a` | none | cut |
| cannon33b, cannon33c | gun | 3 | 3 | cut (D59) | they played the same as `cannon33a` | none | cut |
| cannon22b | gun, the mortar: five shards that set tiles on fire | 2 | 2 | session 12 | Meshy, cleanup by hand, `barrel` levelled from 45 degrees (`pitch`), `projectile_spawn`, `plate` | board 1 design 1 of [round 28](rounds/28-advanced-buildings/PICKS.md) (D60), 1,107 triangles | in the game, [final.glb](../assets/3d/cannon22b/final.glb) |
| flak22 | gun that fires itself, shoots down balls | 2 | 2 | session 12 | Meshy, cleanup by hand, part `guns` aimed whole about the ball, `plate`. Lifted on a longer neck, barrels 25 percent shorter, smaller than the other guns (D61) | the twin gun, board 2 design 1 of round 28 (D60), 1,003 triangles | in the game, [final.glb](../assets/3d/flak22/final.glb) |
| rocket_station | building, a crater anywhere on the map | 3 | 3 | parked (D59) | image-to-3D, anchors `rocket_spawn`, `rocket_model` | none | parked |
| shield22 | building, the shield generator | 2 | 2 | parked (D59), returns as the 1-iron 2x2 if the siege gun has no answer | image-to-3D, anchor `shield` | none | parked |
| supply22 | building, the 2x2 depot, 10 supply (rules v2) | 2 | 2 | session 12 | Meshy, cleanup by hand with cleanup.py | three looks, `supply22` to `supply22.3`: a log yard, a plank store with a lean-to, a pyramid-roof shed (D60) | in the game |
| supply33 | building, the 3x3 depot, 16 supply (rules v2) | 3 | 3 | session 12 | Meshy, cleanup by hand with cleanup.py | three looks, `supply33` to `supply33.3`: a long warehouse with a gantry, a granary on posts with a ramp, a barn with a gantry tower (D60). `data/buildings/supply33.tres` has no recipe until session 13 | in the game |
| cluster_bomb, cluster_shard | projectile | 0.3 m, 0.12 m | 2 | session 12, with the mortar | procedural, [build.py](../assets/3d/cluster_bomb/build.py) and [build.py](../assets/3d/cluster_shard/build.py) | a banded iron ball of 96 triangles, a chunk of iron of 16 | in the game |
| rocket | projectile | under 1 m | 3 | follows rocket_station | procedural | none | waits |
| muzzle smoke, splash, impact | effect | none | 1 | later | in the engine | round puffs of smoke, no fire that keeps burning (bible chapter 1) | open |
| tile fire | effect | 1 | 2 | the mortar is in the game | in the engine | today the tile turns red | waits |
| flak burst, shield bubble | effect | none | 2 | follow flak22 and shield22 | in the engine | none | waits |
| wall fly and vanish | effect | none | 1 | exists in the game | in the engine | none | done |
| sky panorama | sky | none | none | first game | generated image, [round 24](rounds/24-sky/sky.png) | the afternoon light of [lighting_rules.yaml](lighting_rules.yaml) | in the game untracked, waiting on Sebastian's pick |

## In-game 2D

| id | class | priority | variants | status |
|---|---|---|---|---|
| logo | identity | done | horizontal. The square icon and the SVG are open (roadmap D1) | done, D27, [logo.png](anchors/logo.png) |
| splash | screen | done | none | done, game commit `7042fb2` |
| menu background | screen | done | none | done, game commit `7042fb2` |
| theme: buttons, panels, font | UI | later | hover, pressed | started: `ui/theme.tres` styles the splash, menu and loading screens (roadmap D2) |
| HUD: timer, phase, help, supply bars | UI | later | none | open |
| building icons | UI | later | one per placeable building, selected and disabled | open |
| cooldown bar | UI | later | none | open |
| loading screen | screen | done | twenty looks, one at random | done, D66: the twenty pictures of round 29 at 1920 by 1080 from `storeset.py loading`, never the splash's key art |
| sandbox panel | UI | later | none | open |

## Store and marketing

| id | priority | sizes | status |
|---|---|---|---|
| key art | done | from the marketing contract | done, D25, [marketing_style.png](anchors/marketing_style.png) |
| Steam capsules and library assets | done | the Steam partner docs | done, session 05 |
| itch.io cover | done | 630 by 500 | done, session 05 |
| itch.io banner | later | from the itch.io page editor | open |
| screenshots | later | 1920 by 1080 from the game | waits for the game art |
| trailer still or clip | later | 16:9 | open |

## The count

The game asks for 43 wall slots, 45 nature slots and 21 buildings. The art kit fills them with fewer meshes, because one look can fill several slots.

| group | meshes |
|---|---|
| first batch: 3 guns, the depot, 2 blocks, 4 lower and 4 upper walls, the base, the tile, the cannonball | 17 |
| later: the ship and its gun, 9 nature kinds with 3 variants each | 29 |
| waits for B18: the cluster gun, flak, the shield, the rocket station, the 2x2 depot, 3 projectiles | 8 |
| total | 70 |

The total of 70 assumes 3 looks per wall shape and level, 3 variants per nature kind, and that the diagonal, pair, ring and centre guns borrow the default models.
