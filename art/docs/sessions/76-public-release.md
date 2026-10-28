# Session 76: the repository goes public

Roadmap item: G10.

Sebastian, 2026-10-28: "I want to make this repo public. But I want to do it right: Have a MIT license, scan
for vulnerabilities, make sure no secrets are in the git history... anything you can think of. Make a plan
for a safe way to make this public"

This file holds the audit of 2026-10-28 and the plan built on it. Nothing in the plan was executed yet.

## Blocker: GitHub still serves the old Unity history

The local history is clean. Its three 2019 commits hold `.gitignore`, `.gitattributes` and `TODOS.txt`,
nothing else: the Unity project was filtered out before the move. GitHub never forgot it. The five commits
before the filter still exist on GitHub as unreachable objects, readable by hash through the API and the
web: `e45e623` "Track Unity binary asset types in LFS", `5f48a77`, `9ca6a53`, `d642c0f`, `85d2071`.
README line 7 publishes the first hash.

The tree of `e45e623` has 7141 files. 2561 of them are `Assets/AmplifyShaderEditor`, 3413 are
`Assets/Mirza Beig/Ultimate VFX`, ten are `Assets/Plugins/Trinary Software` and one is
`Assets/2D-Flat-Shape-Shader-master.zip`. Amplify Shader Editor and Ultimate VFX are paid Unity Asset
Store products. The Asset Store EULA forbids redistributing them. The blobs are real files, not LFS
pointers: a 22 KB fbx, 19 MB sprite sheets. No secret-like file name is in those trees.

Switching this repository to public would publish those packages at
`github.com/sebastianrueckerai/cannonade/tree/e45e623...` for anyone who reads the README. GitHub
Support can purge unreachable objects on request, but that takes days and cannot be checked from
outside. A new repository has no unreachable objects. The plan pushes `master` to a new repository and
keeps this one private.

## Secrets: none in the history

| check | scope | result |
|---|---|---|
| gitleaks 8.30.1 `git --log-opts=--all` | every local ref, 227 non-empty commits | 0 leaks |
| grep for key formats (GitHub, AWS, OpenAI, Anthropic, Slack, Google, private keys) | text diff of every ref, 16 MB | 0 hits |
| grep for `token=`, `password=`, `secret=`, `api_key=` on added lines | same | 0 hits (one `image_token` variable name) |
| file names ever committed | 4331 paths | `art/.env.example` only, names without values |
| gitleaks `dir` | working tree, untracked included | 5 values, all in the two gitignored env files |

The two env files stay local. `.env.tools` at the root holds a fine-grained GitHub token for a second
account. Nothing in this repository reads it. `art/.env.tools` holds the fal, Replicate, Tripo, Meshy and
Z.AI keys for the art pipeline. The root `.gitignore` names `.env.tools` alone. `art/.gitignore` covers
`.env` and `.env.*`.

## Licence: none, and the third-party pieces keep their own

GitHub reports no licence. No `LICENSE` file exists. The parts that are not Sebastian's own work:

| piece | where | licence | state |
|---|---|---|---|
| Alegreya font | `assets/art/ui/font.ttf` | SIL OFL 1.1 | `font-OFL.txt` beside it, as the OFL asks |
| Alegreya, IM Fell English, Metamorphous, Signika | `art/game/art-direction/rounds/30-menu-look/fonts/` | SIL OFL 1.1 | `OFL.txt` in each folder |
| Kenney Particle Pack 1.1 | `assets/art/fx/` | CC0 | `LICENSE.txt` beside it |
| 3D models | `art/game/assets/3d/*/raw/`, the kit, the glbs | Meshy (290 raw files), Tripo (114) | provider terms: commercial use of outputs on paid plans, Meshy free-plan outputs are CC BY 4.0 |
| UI, sky, loading and store images | `assets/art/ui`, `assets/art/sky`, marketing | google/nano-banana-2.1 through fal | provider terms: the user owns the output |
| music | `assets/audio/music/` | fal-ai/ace-step | ACE-Step is Apache 2.0, outputs free |
| sound effects | `assets/audio/sfx/`, `ui/` | ElevenLabs sound-effects v2 (18), Stable Audio 2.5 (1), mirelo-ai sfx2.0 (1) | provider terms, ElevenLabs royalty-free on paid plans, Stability Community Licence under 1 million USD |
| Unity-era models | `assets/fbx/` (44 fbx, 5 textures), `assets/nature/` (45 fbx) | unknown | Blender 2.79 exports, the old tree held their `.blend1` sources under `Assets/Models`, so they read as Sebastian's own work. Needs his word |

MIT covers what Sebastian owns. It cannot relicense a provider's terms or a font, and copyright on AI
output is unsettled in the EU and the US. The licence file therefore grants MIT on the repository and the
README names the exceptions.

## Vulnerabilities: nothing to patch

- The game has no network code: no `HTTPRequest`, `HTTPClient`, `WebSocket`, `JavaScriptBridge`. No
  addons. No dependency manifest, so Dependabot has nothing to watch. The web build runs inside itch's
  iframe.
- The sandbox loads scenario `.tres` files from `user://scenarios/` with `ResourceLoader`
  ([Sandbox.gd:322](../../../scripts/sandbox/Sandbox.gd#L322), [BattleLab.gd:217](../../../scripts/sandbox/BattleLab.gd#L217)).
  A `.tres` can embed a script that runs on load. The files are written by the same user who runs the
  game, the same trust as the executable. Accepted. A scenario file from a stranger is a mod, and the
  README says so after this session.
- The battle lab spawns the Godot binary with arguments from internal values
  ([Sandbox.gd:416](../../../scripts/sandbox/Sandbox.gd#L416)). The saved name passes `validate_filename`. Fine.
- The Python art pipeline runs the repository's own scripts with `exec` inside Blender
  ([driver.py:30](../../pipeline/blender/driver.py#L30)). No `shell=True`, no `yaml.load`, no `verify=False`. Developer tooling, fine.
- A Claude Security scan (`/claude-security` in an interactive session) gives a second read of the
  GDScript and the pipeline. Optional, after the move.

## Personal data

- Commit authors: 219 commits carry the GitHub noreply address, 25 carry a private one
  (`mail@sebastianruecker.com` 12, `sebastian@womb.art` 10, `Ruecker.Sebastian@googlemail.com` 3), 11
  are Claude's. A rewrite with `git filter-repo --mailmap` changes every hash, breaks 18 commit references
  in the docs and the two live worktrees, and needs a force push. Recommendation: keep them. The
  addresses are his public contact.
- `/home/womb` appears in 80 doc lines and five scripts (`fracture.py` and `tile_damage.py` read
  `GAME_REPO` first). It reveals a user name and nothing else. Portability, not safety.
- `art/docs/research/chatgpt-design-and-game-art-conversation.md` is Sebastian's own ChatGPT transcript
  about a portfolio site. It holds no contact data.
- Session plans, decisions and ROADMAP quote Sebastian verbatim. His words, his call.

## Hygiene

- `origin` carries the stray branch `claude/busy-brahmagupta-uu18ap`, merged into master on 2026-10-01.
- README line 1 reads "Grid Cannons – Godot port", line 7 cites the dead commit. No link to the itch page,
  no screenshot, no licence section. The GitHub description, homepage and topics are empty.
- Untracked in the checkout: `reference-ux-design-process.md` (another project's file, it names that
  project's key file), `boards/` (21 MB of PNGs), `tools/castle_looks.tscn`, `assets/art/3d/wall_straight.glb`,
  `art/game/assets/audio/sfx/castle_lost.*`, eleven marketing JPGs. `kit.blend` is modified by a Blender
  re-save.
- Size: 194 MB tracked, 526 MB packed, largest blob 5.2 MB. Under GitHub's limits. No LFS.
- The local `.git` holds 135 unreachable commits. A push sends reachable objects only.

## Decisions Sebastian makes before the work starts

1. **New repository or Support purge.** Recommended: a new repository named `cannonade`, this one
   renamed to `cannonade-archive` and kept private. The purge route keeps the repository but cannot be
   checked and takes days.
2. **Copyright line.** Proposed: `Copyright (c) 2019-2026 Sebastian Rücker`.
3. **MIT scope.** Proposed: the whole repository, code, art kit, models, audio and docs, with the
   third-party table above as the exceptions. The alternative keeps the art under all rights reserved
   so nobody can republish the game with his art. Both are one sentence in the licence file.
4. **Author emails.** Proposed: keep.
5. **The Unity-era models.** His own work in Blender 2.79, or from a pack? A pack decides whether
   `assets/fbx` and `assets/nature` can be published.
6. **The old repository.** Rename and keep private, or delete. Proposed: rename now, delete after a
   month.

## Plan

Phase 1, local, before anything is pushed anywhere

1. Delete `reference-ux-design-process.md` from the checkout. Add `boards/` to `.gitignore`.
2. Widen the root `.gitignore` from `.env.tools` to `.env*`.
3. Decide the other untracked session files with Sebastian: commit or drop.
4. `git push origin --delete claude/busy-brahmagupta-uu18ap`.
5. Install gitleaks into `~/.local/bin` and a `pre-commit` hook running `gitleaks protect --staged`.
   Worktrees share the hook.

Phase 2, licence and credits

6. Write `LICENSE`: the MIT text with the copyright line of decision 2 and, after it, one paragraph
   naming the exceptions of the table above and pointing at the README credits.
7. Add a "Licence and credits" section to the README: MIT, the fonts under the OFL, Kenney under CC0,
   the AI providers that made the models, images, music and sounds, the Godot engine under MIT.
8. If decision 3 keeps the art reserved, the licence paragraph says which folders.

Phase 3, README and hygiene

9. README: title "Cannonade", first paragraph says what the game is, links the itch page
   (moonlightart.itch.io/cannonade), shows one marketing board, says Godot 4.7.2 builds it. Drop the
   dead commit reference in line 7. Keep the port section below.
10. README sandbox section: one sentence that a scenario `.tres` from elsewhere runs as a mod.
11. Run `./run_tests.sh` after the README edit (menu_test reads nothing from it, but the suite stays the
    gate for every commit).
12. Commit, merge by push to master, push to origin. The old repository gets the final state too, so a
    later comparison is one `git diff`.

Phase 4, the new repository

13. `gh repo rename cannonade-archive -R sebastianrueckerai/cannonade`.
14. `gh repo create sebastianrueckerai/cannonade --public --description "Cannonade: a Rampart-style
    castle game, Godot 4" --homepage https://moonlightart.itch.io/cannonade`.
15. `git remote set-url origin https://github.com/sebastianrueckerai/cannonade.git`, then
    `git push -u origin master` and `git tag v3 && git push origin v3` for the shipped version.
16. Settings through `gh`: wiki off, projects off, issues on. Topics `godot`, `godot4`, `gdscript`,
    `game`, `rampart`, `strategy`. A ruleset on `master` that blocks deletion and force pushes. Secret
    scanning and push protection enabled (`security_and_analysis` on the repository API). Social
    preview uploaded in the web UI from `art/game/assets/marketing/itch/`.
17. `art/docs/grid-cannons.md` and `CLAUDE.md` keep their paths. The remote URL did not change, only
    the repository behind it.

Phase 5, verify from outside

18. `gh api repos/sebastianrueckerai/cannonade/commits/e45e623` returns 404.
19. Anonymous `git clone` into an empty folder, `./run_tests.sh` green there. Proves the public tree
    needs nothing that is gitignored.
20. gitleaks `git` on that clone: 0 leaks.
21. Open the repository page logged out: licence badge shows MIT, README renders, the board shows.
22. Tick G10 in ROADMAP in the commit that closes the session. The archive repository is deleted a
    month later if decision 6 says so.
