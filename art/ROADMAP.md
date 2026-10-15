# Roadmap

Everything we want or might want. A session pulls items by ID into its plan in [docs/sessions/](docs/sessions), refines them there, ships them, and ticks them in the same commit. Add new items at the end of their section. Never delete an item, strike it through with the reason.

Tags: **must** is needed for the first demo. **spike** is a time-boxed experiment that answers a question and ends in a process-log entry. **idea** is optional. **decide** is a choice Sebastian makes. **game-repo** means the change lands in [/home/womb/repos/grid-cannons](/home/womb/repos/grid-cannons).

## A. Process and tooling

- [x] A1 **must** Port `tools/img.py` from the portfolio repo to [pipeline/img.py](pipeline/img.py): gen, edit, critique, montage, sheet, cost, sidecar JSON, spend cap. Keys from `.env.tools`. Drop the portrait-specific prompt blocks.
- [x] A2 **must** Blender toolkit in [pipeline/blender/](pipeline/blender): `normalise.py`, `materials.py`, `report.py`, `render.py`, `export.py`, each a file `blx` runs with the asset folder as argument. Steps in [assets-3d.md](docs/process/assets-3d.md). Session 01 built all of it except `materials.py`. Session 07: [materials.py](pipeline/blender/materials.py) assigns palette materials, the walls, the tile and the cannonball use it.
- [ ] A3 **must** `pipeline/mesh.py`: image-to-3D through fal (`trellis-2`, `hunyuan-3d`), Tripo and Meshy. Downloads at once, sidecar JSON, cost. Session 06: [mesh.py](pipeline/mesh.py) runs Tripo and Meshy with one image or several views, face count and parts. The fal endpoints are open.
- [ ] A4 **must** [pipeline/asset.py](pipeline/asset.py): reads `asset.yaml`, runs the route, the normaliser, the report, the renders, the export, and writes `manifest.json`. Session 01: the procedural route works, the generative route waits for A3. Session 07: a generative asset gets its report, renders and manifest from the `final.glb` of its cleanup, and `asset.py approve` records the pass for every route.
- [ ] A5 **must** 3D critic prompt: takes the render sheet, `report.json` and `asset.yaml`, returns pass or a numbered correction list with the feedback level. Independent model from the author.
- [x] A6 **spike** Critic calibration: after each round, log whether the critic's top picks match Sebastian's. Drop a critic that disagrees twice. Session 03, three rounds: the critics' first place matched Sebastian's once, the director's never. Both stay as fault finders, not as taste predictors, see [process-log.md](docs/process-log.md).
- [ ] A7 **must** Skills: one skill per stable stage under [.claude/skills/](.claude/skills), each a short pointer at its [docs/process/](docs/process) page plus the commands. First two: `art-round` and `make-asset-3d`. Only after the stage has run once.
- [ ] A8 **idea** `new-game.sh`: copies the process files into a fresh repo and leaves an empty [game/](game).
- [x] A9 **decide** Git LFS for `.blend`, `.glb` and `.png` once the repo passes about 500 MB. Session 06: LFS for new binaries, the history stays (D35).
- [x] A10 **spike** Image model probe on game prompts: the same 3 prompts (world from the gameplay camera, cannon close, menu) through the portfolio's shortlist. Pick one model per job, write it into [providers.md](docs/providers.md).

## B. Art direction

- [x] B1 **must** Gameplay contract measured in the game repo: tile size in metres, camera angle, FOV and distance, pixel height of a wall and a cannon at 1280 by 720, current material colours from `materials/*.tres`, poly budget per asset class. Into [game/art-direction/gameplay_contract.yaml](game/art-direction/gameplay_contract.yaml).
- [x] B2 **must** Brief: fill [game/art-direction/brief.md](game/art-direction/brief.md) with Sebastian's tone words, audience and the forbidden list. Filled with session 01 assumptions, Sebastian corrects in PICKS.md.
- [x] B3 **must** Round 01: 4 to 6 contrasting directions, 3 frames each, contact sheet, critic, picks. Rules in [art-direction.md](docs/process/art-direction.md).
- [ ] B4 **must** Design bible v0 from the picks: `palette.json`, `geometry_rules.yaml`, `lighting_rules.yaml`, `art_bible.md`, `anchors/`. Folded into B15, the bible.
- [ ] B5 **must** Round 02: the picked directions as isolated references for wall, cannon, tower, rock, on neutral ground, front, side and three-quarter. Folded into B17, sketches then references per essential class.
- [x] B6 **decide** Flat palette or textured. Default flat (D5). Decide after C2 with both variants of one asset side by side. Session 09: painted texture wins on the leaf-tree board, flat bands deleted (D49).
- [ ] B7 **must** Design bible v1 after the vertical slice, tagged `art-kit-v1`.
- [x] B8 **must** `typography.yaml` and the title treatment, from D1 in section D. Session 05: lettering b, D27, [logo.png](game/art-direction/anchors/logo.png).
- [x] B9 **must** Phase A, mood and theme: 3 to 4 worlds in words, a moodboard each, pick. Round `02-mood`. D20.
- [x] B10 **must** Phase B, colour: 3 palettes applied to the picked frame, the 13 px team-colour crop, pick. `palette.json`. D21.
- [x] B11 **must** Phase C, shape language and detail level: the same fortress corner at 3 levels in 2 languages, pick. `geometry_rules.yaml`. Round `04-shape`, D22.
- [x] B12 **must** Phase D, lighting and atmosphere: time of day, fog, shadow, sea, pick. `lighting_rules.yaml`, world anchor. Round `05-light`, D23, [world_style.png](game/art-direction/anchors/world_style.png).
- [x] B13 **must** Phase E, what stays and what differs across game, menu, splash, store, plus 3 title studies, pick. `typography.yaml`. Rounds 06 to 15, D24 to D27.
- [x] B14 **must** Phase F, era ladder tiers 0 to 3 and the ingredient metaphor candidates, one sketch sheet (D16, D17). Session 05: round 16 rejected, its rules kept as D28 to D30. Round 17 painted the guns from Sebastian's brief, and he picked one gun per size (D31), [gun_ladder.png](game/art-direction/anchors/gun_ladder.png), and the four blocks, [resource_blocks.png](game/art-direction/anchors/resource_blocks.png).
- [x] B15 **must** Phase G, design bible v0 approved and tagged `bible-v0`. Session 05: Sebastian handed the bible over with the condition that the cozy, bright concept and capsule style is in it, then it was tagged.
- [x] B16 **must** Phase H, asset list confirmed by Sebastian, essentials and unsure items marked. Session 06: the list is rewritten from the game data and explains the draws, merges and supply. Sebastian set a first batch in place of the essentials (D33). The advanced gun variants, the shield and the other block buildings wait for B18.
- [x] B17 **must** Phase I, first item per essential class: sketches, pick, reference views, then 3D in the game. Session 06: the three guns picked and cleaned (D37), on the bench in the game, not yet in the art layer. Session 07: the whole first batch of D33 stands in the game, the walls confirmed chapter 3 of the bible (D38), the guns got square plates (D39) and the base became 2x2 (D40).
- [ ] B18 **decide** The ingredient metaphor and the upgrade tree v1, after the simple cannons exist (D17). Session 06: the blocks are picked, timber and iron (D32). Open: every plain gun fires the same shot whatever its size, so the bigger guns need a reason in play. Brainstorm after session 11b: the tree is designed in [rules.md](game/design/rules.md), recipes by iron count, the roster cut to five guns (D59). Session 12 built the models (D60, D61). Planned as [session 13](docs/sessions/13-rules-v2.md). Ticked when the game plays it.
- [x] B19 **decide** The triangle budget of the guns. The bible allows 600 per building. Round 18 shows the medium and large guns lose their detail below about 1,500 and 3,000 when zoomed in, while the default view shows no difference. Session 06: about 1,100, 1,500 and 3,000, picked on the bench (D37).

## C. 3D assets

- [x] C1 **must** Plumbing proof: unstyled `wall_straight` with the exact modular dimensions, procedural, through normalise, report, export to `.glb`, instanced in the game's [tools/screenshot.tscn](/home/womb/repos/grid-cannons/tools/screenshot.tscn), one screenshot. No art direction needed. Proves Blender to Godot end to end.
- [ ] C2 **must** Vertical slice set from design bible v0: wall straight, corner, cross, one damaged state, cannon with separate barrel and carriage and a trunnion pivot, tower, rock, tree, bush, terrain slab. Session 07: the walls, the guns with their trunnion pivots and the tile are in the game. The game has no damaged states (C7). Tower, rock, tree and bush are open.
- [x] C3 **spike** The same cannon through image-to-3D (`trellis-2` and Tripo) from the B5 references, through the same normaliser. Compare style match, topology, pivots, editability, cost and time with the procedural one. Process-log entry. Session 06: reshaped by D34 into Tripo against Meshy on all three guns, with four inputs, three barrel methods and a face-count ladder, [round 18](game/art-direction/rounds/18-gun-3d/RESULTS.md). The procedural build is the last resort, so it was not compared.
- [x] C4 **spike** Rock formation: procedural noise against image-to-3D. Session 08: Tripo won on boulders, then D45 narrowed the verdict to hard-surface irregulars after the foliage card-cluster gate failure; bushes, trees and boulders all ship as procedural solids ([nature_build.py](game/assets/3d/nature_build.py)).
- [ ] C5 **must** Nature set: the 43 FBX props replaced or restyled. Session 07: replaced, not restyled. Sebastian wants every kind new, bigger and more stylized, like the cover art (D41). Session 08: the nine bush, tree and boulder looks are procedural solids, rejected at the gate on look, "still untextured" (D46). Session 09: textures are painted (D49); leaf tree, boulder and bush pass their gate as nine painted looks and ship (D50). Session 10: the first game needs only the approved three kinds (D51); the other six kinds are parked until the first game asks for them.
- [x] C6 **must** Building set: the v2 roster of D59, five guns and three depots. Session 07: the supply depot in four looks, the base in three, both blocks. Session 12, round 28: the mortar `cannon22b`, `flak22`, `supply22` and `supply33` in three looks each, the cluster bomb and the shard (D60). Every gun now stays inside its square, and the flak is smaller (D61). The shield and the rocket station are parked, `cannon22c`, `cannon22d`, `cannon33b`, `cannon33c` are cut.
- [ ] C7 **idea** Damage and team-colour states as parameter variants in `build.py`, not new assets.
- [ ] C8 **idea** Generated textures for hero assets only, if B6 picks textured.
- [x] C9 **must** World background: one equirectangular sky image from the design bible, tested in a WorldEnvironment with a PanoramaSkyMaterial. Session 10: painted in [round 24](game/art-direction/rounds/24-sky/sky.png) on the style anchors, centre-cropped 16:9 to 2:1, in the game as `assets/art/sky/world_panorama.png` waiting on Sebastian's pick. Found on the way: the game camera pitches 60 to 71 degrees down, so only the panorama's haze band is ever visible behind the board; the cloud half shows in no game view. Session 10: picked with the look round, D52 — the soft/warm blend ships as world_panorama.png (see round 25).
- [ ] C10 **idea** Turntable video per approved asset for the preview folder.
- [x] C11 **must** **game-repo** [lighting_rules.yaml](game/art-direction/lighting_rules.yaml) into the game: the WorldEnvironment, the DirectionalLight and the sky from the picked variant, and the gameplay-camera view of [render.py](pipeline/blender/render.py) lit the same way, so a render sheet and a game screenshot compare. Nothing reads the file yet (D23). Session 07: the game side is done, the light and the fog in [scripts/Main.gd](/home/womb/repos/grid-cannons/scripts/Main.gd) with a measured sun energy of 0.5. Session 08: the render view matches, wall bands within 2% of a game screenshot ([check](docs/sessions/08-c11-render-view-check.png)). Session 10: remeasured under the D52 look (38-degree sun, the grade), wall face R -0.4% G +0.5% B +0.6%; render.py carries the grade through game_view.
- [x] C12 **must** The repaint round: the nine wall pieces, the tile, the shell and the square gun plates are flat palette materials from [materials.py](pipeline/blender/materials.py), paint them on the D49 path ("I would like everything to be textured, but dont redo stuff that already is fine", session 10). Includes the ivory tree readability fix from the D52 ship critique. Session 11: the set paints on the D49 path (D53), the ivory looks read leaf again (D54), the gate passed with the plate lag fixed in the game (D55). Plan: [11-repaint.md](docs/sessions/11-repaint.md).

## D. In-game 2D and identity

- [ ] D1 **must** Logo and title: identity brief, 3 contrasting type directions, pick, SVG. Session 05: three styles, b picked (D27), a 1280 px transparent PNG. The SVG is open.
- [ ] D2 **must** `theme.tres` for Godot: buttons, panels, labels, from the palette. Icons for every building type, readable at 32 pixels. Session 02: `ui/theme.tres` exists and styles the splash, menu and loading screens. The HUD and the sandbox panel still use the default theme, because the project-wide theme moved the sandbox layout.
- [x] D3 **must** Menu background and splash image. Session 05: from the store set, in the game at commit `7042fb2`.
- [ ] D4 **must** Readability check: the real menu at 1280 by 720 and at 390 wide, critic, Sebastian approves.

## E. Marketing

- [x] E1 **must** Key art from approved hero renders, gameplay screenshots and the marketing anchor. Session 05: a painted key art instead (D24, D25), [marketing_style.png](game/art-direction/anchors/marketing_style.png).
- [x] E2 **must** Store set composited by script: splash 1920 by 1080, cover 1280 by 720, icon 512, banner 1920 by 480. Platform-specific sizes once the platform is decided. Session 05: [storeset.py](pipeline/storeset.py) makes the Steam and itch.io sizes.
- [ ] E3 **decide** Platform for the demo: hosted web page only, itch.io, or Steam page later.
- [ ] E4 **idea** A 20 second gameplay GIF or clip for the page.
- [ ] E5 **must** Steam page set: capsules, library assets and screenshots at the sizes in the Steam partner docs. Sebastian, 2026-10-11: yes, but after the art exists. Session 05: capsules and library assets done, screenshots wait for the game art.
- [ ] E6 **must** itch.io page set: cover, banner, screenshots. Same note as E5. Session 05: the cover is done.

## F. Game integration, all game-repo

- [x] F1 **must** Art layer `res://assets/art/{3d,ui,sky}/` and `prefabs/art/<asset_id>.tscn` wrappers. `BuildingDef.model` points at wrappers. Pattern and paths in [grid-cannons.md](docs/grid-cannons.md).
- [x] F2 **must** [pipeline/godot_sync.py](pipeline/godot_sync.py): copies approved files into the art layer, writes `manifest.json`, touches nothing else.
- [ ] F3 **must** `Map.gd` loads slab and nature from a table, `WallModel.gd` PNG mapping becomes fallback or goes. Session 02: walls fall back to the FBX when no `.glb` exists. The nature table is F7. Session 07: the tile and all eight wall shapes and levels come from the art layer, so the FBX walls only show when a file is missing.
- [x] F4 **must** `Menu.gd` and `SandboxUI.gd` use `theme.tres`. `Splash.tscn` before the menu. Menu background TextureRect.
- [x] F5 **must** `tools/preview.tscn`: gameplay camera, grid, one or many assets by id, screenshot. Built on [tools/screenshot.tscn](/home/womb/repos/grid-cannons/tools/screenshot.tscn).
- [ ] F6 **decide** Restyle the 46 FBX walls by material first, or remodel them procedurally. Decide after C1 shows the budget.
- [x] F7 **must** Nature props through the art layer: `CustomModelMaker` variants from `3d/nature_<kind>_<n>.glb` in place of the FBX files. Session 09: `CustomModelMaker` asks `Art.instance("nature_" + kind)`, the nine approved looks are committed in the game repo with their manifest entries, check_art clean.
- [x] F8 **must** Verify the part mapping with a real cannon model: `barrel` under `Barrel`, a `projectile_spawn` empty. The attach path ran without errors in the catalog test, no model has used a pivot yet. Session 07: the three guns fire from the art layer in a sandbox battle, the barrels tilt about their trunnions and every shot starts at `projectile_spawn`, [07-battle-guns.png](docs/sessions/07-battle-guns.png).
- [ ] F9 **idea** Custom HTML shell for the web export, so the browser shows our colours instead of the Godot logo while the engine downloads.
- [x] F10 **must** `PLAYER_COLORS` in [scripts/Main.gd](/home/womb/repos/grid-cannons/scripts/Main.gd) from the team set in [palette.json](game/art-direction/palette.json): blue #2d55c4, purple #7b2fa3, teal #197059, olive #8c7a1f (D21). The sandbox test clicks by position, not by colour, so the change is safe for it. Session 04, game commit 3398d86, proof [04-team-colours-ai4.png](docs/sessions/04-team-colours-ai4.png).

- [x] F11 **must** [pipeline/godot_sync.py](pipeline/godot_sync.py) fills every random slot of a wall shape and level from one look, so new walls never mix with the old FBX walls. Each shape has 5 to 7 slots per level, 43 in all. Session 07: solved in the game instead of by copies, [WallModel.gd](/home/womb/repos/grid-cannons/scripts/WallModel.gd) asks for `wall_<shape>_<level>` for every slot, and a second look would become a `.2` variant. Sebastian keeps the cornice as the only look (D43).
- [x] F12 **must** Projectiles through the art layer: `3d/shell.glb` replaces the cannonball of `prefabs/Bullet.tscn`. Session 07: `Catalog.spawn_projectile` attaches `3d/<projectile id>.glb`, the cannonball is a 0.28 m sphere in dark iron, 288 triangles.
- [x] F13 **must** **game-repo** Battle readability: how a gun shows its reload and its aim. Session 11b, round 27: candidates built as game variants and shot in sandbox battles, picked the team-tinted ring round the gun's foot with a ready pulse (D57) and the thin tapered arc on the human's guns only (D58). On the way the gun mount was centred on its plate in the model and the plate freezes after placement in the game.
## G. Web demo and hosting, all game-repo

- [x] G1 **must** Godot 4.7 CLI and the Web export templates installed on this machine. Session 01: Godot 4.7.1 is in `~/Applications`, the 4.7 Web templates are not.
- [x] G2 **must** [export_presets.cfg](/home/womb/repos/grid-cannons/export_presets.cfg) with a Web preset, thread support off. [tools/export_web.sh](/home/womb/repos/grid-cannons/tools/export_web.sh) and [tools/serve_web.sh](/home/womb/repos/grid-cannons/tools/serve_web.sh).
- [x] G3 **must** Smoke test in headless Chromium: loads, menu shows, one round plays.
- [ ] G4 **must** Host on a small VM: nginx static, compression for `.wasm` and `.pck`.
- [ ] G5 **idea** Export and publish on push.

## H. Spikes on the agentic process itself

- [ ] H1 **spike** Does the 2D reference stage pay for itself on low-poly procedural assets? One cannon from brief to mesh twice: once through direction, reference, procedural, once from brief straight to procedural with the design bible text only. Compare style match and cost.
- [ ] H2 **spike** Variations in place of prototypes: 5 parametric variants of one approved asset, critic ranks, Sebastian picks. Is that cheaper than one careful prototype?
- [ ] H3 **spike** Open-weight image-to-3D on the 11 GB GPU: TripoSR or SPAR3D. Only if API cost per asset turns out to matter.
- [ ] H4 **idea** Mesh-aware texture API for hero assets.
- [ ] H5 **idea** Rigging and a sail animation for the ship.
- [ ] H6 **spike** Agent as the only critic against agent plus independent critic, on one round. Does the second model change the picks?
