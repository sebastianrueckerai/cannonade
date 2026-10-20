# Cannonade sound design: the cue list

Session 31, 2026-10-20, for roadmap K5. The game has no audio yet: no AudioStreamPlayer, no clip, no
call. Every row below is a hook to add. Script lines are from [scripts/](/home/womb/repos/grid-cannons/scripts)
at commit 90b875b. The models that make the clips and what they cost are in
[ai-audio-providers.md](../../docs/research/ai-audio-providers.md). The probes of this session are
rounds [36-music-probe](../art-direction/rounds/36-music-probe) and [37-sfx-probe](../art-direction/rounds/37-sfx-probe).

The sound follows the bible: a painted wooden toy fortress, cheerful, chunky, sunlit. The build phase
sounds like stacking painted blocks on a board game table. The battle sounds like a fairground shooting
gallery: guns pop, water splashes, a hit ship tips over like a toy. Nothing is gritty, nothing screams,
nothing burns for long. Wood, stone and dark iron are the materials, so impacts are wooden knocks and
stone cracks, not metal screeches.

## Music

Five cues. Two themes carry the game, the other three are versions of them, so the whole game sounds like
one piece. A loop runs on the game's own loop points, since no model makes a seamless loop: the
clip is cut to a bar line and the join is checked by ear.

| cue | where it plays | length | character | source |
|---|---|---|---|---|
| build | the wall and cannon phases, 45 s and 15 s, from `next_phase` | a 60 to 90 s loop | calm, bouncy, playful, 100 to 110 BPM, constant energy, no intro, no ending | the build theme, generated |
| battle | the battle phase, 30 s | a 60 to 90 s loop | driving march, 140 to 150 BPM, snare pattern, fanfare lead, playful not grim | the battle theme, generated |
| menu | the main menu and the tutorial overlay, from `Menu._ready` | a 60 to 90 s loop | the build theme slower and lighter, fewer parts, the melody on one instrument | a version of the build theme |
| win | the win screen, from `Main._on_game_over` | 8 to 15 s, once | the battle theme's fanfare as a triumphant sting, then silence | a version of the battle theme |
| lose | the lose screen | 8 to 15 s, once | the build theme slow and in minor, a wooden thunk at the end | a version of the build theme |

A draw shares the lose sting. The loading screen plays the menu cue on, since the map builds over a
few seconds, and the build cue starts when `built` fires.

Versions of a theme: a text-to-music model cannot repeat a theme across runs, so a version is made
from the clip. The routes: [fal-ai/ace-step/audio-to-audio](https://fal.ai/models/fal-ai/ace-step/audio-to-audio)
remixes a clip under new tags (slower, minor, fewer instruments) and keeps its material, with no dial
for how much, at 0.0002 USD a second, round 38 made three this way;
[fal-ai/stable-audio-25/audio-to-audio](https://fal.ai/models/fal-ai/stable-audio-25/audio-to-audio)
regenerates a clip from a prompt with a `strength` dial, 0 returns the input and 1 ignores it, at 0.20
a run, untested; MiniMax's `music-cover` takes a reference clip on the direct API, which takes no new
users; a tracker or a DAW makes the versions by hand from the chosen theme, the chiptune route makes
this easy. A cut of the clip is a version too: the win and lose stings are the first 16 s with a fade.

The directions on probe, each on the four music endpoints of fal:

| direction | what it is | why it may fit |
|---|---|---|
| chip | chiptune: two pulse leads, triangle bass, noise drums | Sebastian's lean. Arcade spirit, Rampart's era |
| toybox | toy-box folk orchestra: whistle, fiddle, accordion, marimba, glockenspiel, pizzicato, woodblock | the painted wooden toy world, acoustic and warm |
| organ | fairground band organ with snare, bass drum, bells | the shooting-gallery tone of the battle, mechanical and merry |
| chipfolk | chiptune lead over accordion, fiddle, banjo, hand drums | the chip lean with the sea and the wood in it |

## Sound effects

Priority A is what a first release needs. B is polish, or a sandbox-only feature. One row per clip
set; a set with "x3" wants three variations so the same hit does not repeat. The trigger names the
script and function that fires it. "Hook" means the code is silent today and needs a call put in.

### Build phase

| id | clip | trigger | how often | priority |
|---|---|---|---|---|
| place_piece x3 | a painted wooden piece set down on a board: one wooden clack per cell, the cells 30 ms apart | `PlayerController.build_next_wall` (556) | several a phase | A |
| stack_block | a block set on top of a wall, a higher clack | `PlayerController.stack_wall` (546) | occasional | A |
| place_invalid | a soft dull double knock, polite | hook at `PlayerController` 459 to 462, where `canPlaceWall` false falls through | a few a phase | A |
| place_gun | a heavier set-down with an iron ring | `PlayerController.build_next_building` (507) | a few a round | A |
| gun_refused | the invalid knock, lower | hook at `PlayerController` 509, over the parts cap | rare | B |
| fuse_heavy | four cannons become the heavy 2x2: a wooden clatter, then a deep iron clunk | `PlayerController.combine_building` (496), `build_upgrade` (538) | rare, a big moment | A |
| rotate | a short wooden tick | `BuildingBlock` 31 and 37, X and Y | several a piece | A |
| draw_piece | a piece slides out of a box into a tray | `PlayerController.get_next_wall` (607) | every few seconds | A |
| draw_gun | the same with iron, a bit heavier | `PlayerController.try_get_next_building` (288) | a few a round | B |
| hover_tick | a very soft tick when the hovered tile changes | `PlayerController.update_point_and_tile_selected` (165) | constant | B, off by default |
| ring_closed | a short rising wooden chime: the enclosed ground takes the owner's colour | `BuildingPlace.reset_color` (230) when a ring closes | a few a game | A |
| piece_flies | a soft whoosh as the held pieces rise and vanish at battle start | `FlyAndVanish.drop` (13, 30) | once a phase | B |

### Phase and check

| id | clip | trigger | how often | priority |
|---|---|---|---|---|
| horn_battle | a bugle call, two rising notes | `GameController._begin`, the battle's banner run out | once a round | A |
| horn_build | a softer bell or whistle, the shutters open | `_begin`, the wall phase's banner run out | once a round | A |
| horn_guns | the cannon phase opens, between the two | `_begin`, the cannon phase's banner run out | once a round | A |
| countdown x1 | a wooden tick on each of the last 5 s | `GameController` 158, the timer label | 5 a phase | A |
| burn_outside | a building outside a ring is lost at the check: a short crackle and a puff | `BuildingPlace.un_build` (124) from `run_check` (227) | a few a round | A |
| castle_claimed | a chime sting with a flag going up | `Castle.claim` (53) | rare | A |
| castle_lost | the same reversed, falling | `Castle.claim` for the loser | rare | A |
| castle_ruin | a big collapse of stone and wood, the keep goes | `Castle.become_ruin` (45) | rare | A |

### Battle

| id | clip | trigger | how often | priority |
|---|---|---|---|---|
| shot_cannon x3 | the 1x1 gun: a tight toy boom with a wooden thump | `Shooter.try_shoot` (138) with `projectile.kind` shell | constant | A |
| shot_heavy x2 | the 2x2 heavy: deep boom, metallic ring | kind heavy_shell | often | A |
| shot_ship | a ship's gun, the small boom further away | `Ship._try_shoot` (77) | every 2 to 4 s per ship | A |
| whistle | the shell in flight, a short falling whistle | `Projectile.fly` (39) | per shell | B, ducked when many fly |
| hit_ground x2 | a dull thud, a puff of dust | `TileImpactor.impact` (45), nothing on the tile | constant | A |
| hit_wall x3 | a stone crack and a wooden knock, a block tumbles | `damage_structure` (97) | constant | A |
| hit_stack | the top block goes: the wall hit, higher | `damage_stacked_wall` (111) | occasional | B |
| hit_gun | an iron clang, the gun rocks | `damage_structure` on a gun | often | A |
| hit_castle | a heavy stone crack, cracks appear | `Castle.take_damage` (32) | often | A |
| hit_water x2 | a round plop and a splash | `impact` on a sea tile | constant | A |
| hit_ship | a wooden crack and a creak | `Ship.damage` (180) | often | A |
| crumble x3 | a wall block is destroyed: stone blocks tumble and clatter | `BuildingPlace.un_build` (124) from a hit on a wall | very frequent, every wall hit kills a block | A |
| gun_destroyed x3 | a gun is destroyed: iron parts clang and clatter, the carriage cracks | `un_build` on a gun | several a game | A |
| ship_sink | the ship tips over: creak, splash, bubbles | `Ship._sink` (187) | 7 a game at most | A |
| target_blip | a short warning blip on the tile an enemy shell will hit | `BuildingPlace.target_on` (257) | per incoming shell | B |
| reload_ready | a soft click when the gun can fire again | `Cooldown`, ring at ready | per shot | B |
| stun | a rattle, the gun goes dark | `Shooter.stun` (121) | rare | B |
| shake | a low rumble under a stunned tile | `BuildingPlace.shake` (271) | rare | B |
| aim_servo | a quiet wooden creak while the barrel swings | `Shooter.try_aim` (87) | constant | B, off by default |
| sail_loop | a slow creak and wave loop near a ship | `Ship._travel` (134) | constant | B |

### Sandbox and parked weapons

Only reachable through the sandbox and scenarios, so B until the upgrade blocks come back.

| id | clip | trigger |
|---|---|---|
| cluster_pop | the cluster bomb splits: a pop and five whistles | `ClusterBomb.release_cluster` (16) |
| shard_hit | a small crack and a short fire crackle for 3 s | `TileImpactor` for cluster_shard, `BuildingPlace.set_on_fire` (224) |
| rocket_launch, rocket_dive | a hiss that climbs, then a dive and a hard crunch, the tile is gone | `S2SRocket` (52), `TileImpactor.disable_tile` (69) |
| flak_shot | a quick pop, a shell knocked down | `Flak._fire_at` (74) |
| shield_absorb, shield_down, shield_up | a soft hum ping, a fizzle, a hum rising | `ShieldGenerator` 94, 70, 50 |

### Menu, loading and end

| id | clip | trigger | priority |
|---|---|---|---|
| ui_hover | a very light wooden tick | `Menu` 74 to 93, the mode buttons, Tutorial, Sandbox, Quit | A |
| ui_click | a crisp wooden tick | the same, and Retry and Menu at `Main` 506 to 510 | A |
| panel_open, panel_close | a wooden slide | `Menu` 140 and `_close_help` (218) | B |
| key_captured | a tick, and a lower double tick for a duplicate | `Menu` 228 and 242 | B |
| splash | a short wooden sting under the title card | `Splash` 8 | B |
| loading_ready | a bright wooden chime when the map is built | `Loading` 72, on `built` | A |
| win, lose | the music stings above, plus a cheer or a sad trombone under them if the music alone is thin | `GameController.end` (271), `Main._on_game_over` (454) | A |
| camera | none. Zoom and pan stay silent | `CameraRig` | |

Counts: 33 clip sets in A, 21 in B, about 70 files with the variations.

## Mixing rules

- Three buses: music, effects, UI. Each with its own slider in the menu later.
- The battle fires many shells at once. Each effect gets a maximum of three voices, and a new one
  steals the oldest. The whistle ducks under the shots.
- Enemy and AI actions play the same clips, 6 dB quieter and panned to the side of the map they come
  from. The camera decides the pan.
- Every clip is levelled for its bus before it goes into the game, by `audio.py final`: a one-shot is
  too short for an integrated loudness, so effects and UI are set by their loudest 400 ms, -16 LUFS
  for effects and -22 for UI, under a limiter at -1 dBTP; music by its integrated loudness, -16 LUFS.
  Silence is cut at both ends. The sheet of a round shows the numbers.
- Formats: effects as 44.1 kHz 16-bit WAV, music as OGG Vorbis with loop points. The kit's copies are
  in [game/assets/audio/](../assets/audio) with a sidecar naming the source clip, the game's in
  [assets/audio/](/home/womb/repos/grid-cannons/assets/audio).

## Picked so far

The assets are named after their cue id, numbered when a cue has several: `shot_cannon_1`. The picks
live in the round's `picks.json`, the page of round 37 shows them ticked, and `audio.py finals` makes
the assets from it. D83, from round 37: shot_cannon x3, shot_heavy x3, castle_claimed, draw_piece,
ship_sink, place_piece, place_invalid, horn_battle, hit_water, ui_click, crumble x3, castle_ruin x3 and
gun_destroyed x3 (the metallic set, used untested on his word). Open from the A list: the rest, with
candidates on the page. Session 41 took two of those candidates in unheard, for his ear and not a pick, since
every phase now starts with a call: horn_build, the harbour bell `fill-horn-build-a--eleven`, and horn_guns,
the boatswain's whistle `fill-horn-build-b--eleven`, made with `audio.py final`, not in `picks.json`.

D84, from round 36: the build and the battle theme are the age-of-sail chiptune from ACE-Step,
`build.ogg` and `battle.ogg`, full clips not yet cut to loops. D85, from round 38: `menu.ogg` is the
build theme as a slow waltz, `win.ogg` the battle theme happy, `lose.ogg` the build theme mournful, all
full length. The five music cues are picked.

## In the game

[Sound.gd](/home/womb/repos/grid-cannons/scripts/Sound.gd) is the autoload. It loads every clip of
[assets/audio/](/home/womb/repos/grid-cannons/assets/audio) at start, `sfx/` and `ui/` by cue, a cue's
variants from the `_n` suffix, and plays a cue with `Sound.play(cue, db)`: a random variant, never the
same twice in a row, at most three voices per cue with the oldest stolen, on the clip's bus. A cue with no
clip plays nothing, so every hook of the cue list is in the code and a new clip only needs its file. A
cue in `Sound.ALIAS` borrows another's clip until it has one: ui_hover, countdown, shot_ship, stack_block,
hit_gun and hit_castle. `Sound.music(cue)` loops `music/<cue>.ogg` on the Music bus. The buses are
Master, Music, SFX and UI in [default_bus_layout.tres](/home/womb/repos/grid-cannons/default_bus_layout.tres).
Another player's action plays 6 dB down. The clips draw their randomness from the autoload's own
generator, so seeded battles and the lab stay as they were.

The hooks: the menu, the loading screen, GameController (music, horns, countdown), Castle (claimed, lost,
ruin), PlayerController (piece, stack, gun, refused, fusion, rotate, draw, ring closed), Shooter (the
shot by projectile and ship), TileImpactor (water, ground), BuildingPlace (hits, crumble, gun destroyed),
UpgradeCluster (one sound for one structure), Ship (hit, sink), Main (win, lose, the end buttons).
[tests/sound_test.gd](/home/womb/repos/grid-cannons/tests/sound_test.gd) drives them.

Not in yet: panning by map side, volume sliders, the loop cut of the music, the B list.

