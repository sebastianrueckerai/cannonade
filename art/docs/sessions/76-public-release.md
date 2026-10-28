# Session 76: the repository goes public

Roadmap item: G10.

Sebastian, 2026-10-28: "I want to make this repo public. But I want to do it right: Have a MIT license, scan
for vulnerabilities, make sure no secrets are in the git history... anything you can think of. Make a plan
for a safe way to make this public"

This file holds the audit of 2026-10-28, the plan built on it, Sebastian's decisions and the outcome. The
session ran the plan the same day.

## Blocker: GitHub still served the old Unity history

The local history is clean. Its three 2019 commits hold `.gitignore`, `.gitattributes` and `TODOS.txt`,
nothing else: the Unity project was filtered out before the move. GitHub never forgot it. The five commits
before the filter still existed on GitHub as unreachable objects, readable by hash through the API and the
web: `e45e623` "Track Unity binary asset types in LFS", `5f48a77`, `9ca6a53`, `d642c0f`, `85d2071`.
README line 7 published the first hash.

The tree of `e45e623` has 7141 files. 2561 of them are `Assets/AmplifyShaderEditor`, 3413 are
`Assets/Mirza Beig/Ultimate VFX`, ten are `Assets/Plugins/Trinary Software` and one is
`Assets/2D-Flat-Shape-Shader-master.zip`. Amplify Shader Editor and Ultimate VFX are paid Unity Asset
Store products. The Asset Store EULA forbids redistributing them. The blobs are real files, not LFS
pointers: a 22 KB fbx, 19 MB sprite sheets. No secret-like file name is in those trees.

Switching that repository to public would have published those packages at
`github.com/sebastianrueckerai/cannonade/tree/e45e623...` for anyone who read the README. GitHub
Support can purge unreachable objects on request, but that takes days and cannot be checked from
outside. A new repository has no unreachable objects. So `master` went to a new repository and the old
one stays private as `cannonade_old`.

## Secrets: none in the history

| check | scope | result |
|---|---|---|
| gitleaks 8.30.1 `git --log-opts=--all` | every local ref, 227 non-empty commits | 0 leaks |
| grep for key formats (GitHub, AWS, OpenAI, Anthropic, Slack, Google, private keys) | text diff of every ref, 16 MB | 0 hits |
| grep for `token=`, `password=`, `secret=`, `api_key=` on added lines | same | 0 hits (one `image_token` variable name) |
| file names ever committed | 4331 paths | [art/.env.example](../../.env.example) only, names without values |
| gitleaks `dir` | working tree, untracked included | 5 values, all in the two gitignored env files |

The two env files stay local. `.env.tools` at the root holds a fine-grained GitHub token for a second
account. Nothing in this repository reads it. [art/.env.tools](../../.env.tools) holds the fal,
Replicate, Tripo, Meshy and Z.AI keys for the art pipeline. The root [.gitignore](../../../.gitignore)
named `.env.tools` alone before this session and names `.env*` now, with `.env.example` re-included.
[art/.gitignore](../../.gitignore) covers `.env` and `.env.*`.

## Licence: none before, and the third-party pieces keep their own

GitHub reported no licence. No `LICENSE` file existed. The parts that are not Sebastian's own work:

| piece | where | licence | state |
|---|---|---|---|
| Alegreya font | [assets/art/ui/font.ttf](../../../assets/art/ui/font.ttf) | SIL OFL 1.1 | [font-OFL.txt](../../../assets/art/ui/font-OFL.txt) beside it, as the OFL asks |
| Alegreya, IM Fell English, Metamorphous, Signika | [rounds/30-menu-look/fonts/](../../game/art-direction/rounds/30-menu-look/fonts) | SIL OFL 1.1 | `OFL.txt` in each folder |
| Kenney Particle Pack 1.1 | [assets/art/fx/](../../../assets/art/fx) | CC0 | [LICENSE.txt](../../../assets/art/fx/LICENSE.txt) beside it |
| 3D models | `art/game/assets/3d/*/raw/`, the kit, the glbs | Meshy (290 raw files), Tripo (114) | provider terms: commercial use of outputs on paid plans, Meshy free-plan outputs are CC BY 4.0 |
| UI, sky, loading and store images | [assets/art/ui](../../../assets/art/ui), [assets/art/sky](../../../assets/art/sky), marketing | google/nano-banana-2.1 through fal | provider terms: the user owns the output |
| music | [assets/audio/music/](../../../assets/audio/music) | fal-ai/ace-step | ACE-Step is Apache 2.0, outputs free |
| sound effects | [assets/audio/sfx/](../../../assets/audio/sfx), [ui/](../../../assets/audio/ui) | ElevenLabs sound-effects v2 (18), Stable Audio 2.5 (1), mirelo-ai sfx2.0 (1) | provider terms, ElevenLabs royalty-free on paid plans, Stability Community Licence under 1 million USD |
| Unity-era models | [assets/fbx/](../../../assets/fbx) (44 fbx, 5 textures), [assets/nature/](../../../assets/nature) (45 fbx) | Sebastian's | Blender 2.79 exports, the old tree held their `.blend1` sources under `Assets/Models`. Sebastian, 2026-10-28: "The models are done by AI with editing from me" |

MIT covers what Sebastian owns. It cannot relicense a provider's terms or a font, and copyright on AI
output is unsettled in the EU and the US. So [LICENSE](../../../LICENSE) is the plain MIT text (nothing
appended, so GitHub's detection reads it) and the README's credits section names the exceptions.

## Vulnerabilities: nothing to patch

- The game has no network code: no `HTTPRequest`, `HTTPClient`, `WebSocket`, `JavaScriptBridge`. No
  addons. No dependency manifest, so Dependabot has nothing to watch. The web build runs inside itch's
  iframe.
- The sandbox loads scenario `.tres` files from `user://scenarios/` with `ResourceLoader`
  ([Sandbox.gd:322](../../../scripts/sandbox/Sandbox.gd#L322), [BattleLab.gd:217](../../../scripts/sandbox/BattleLab.gd#L217)).
  A `.tres` can embed a script that runs on load. The files are written by the same user who runs the
  game, the same trust as the executable. Accepted. The README's sandbox section now says a scenario file
  from someone else is a mod.
- The battle lab spawns the Godot binary with arguments from internal values
  ([Sandbox.gd:416](../../../scripts/sandbox/Sandbox.gd#L416)). The saved name passes `validate_filename`. Fine.
- The Python art pipeline runs the repository's own scripts with `exec` inside Blender
  ([driver.py:30](../../pipeline/blender/driver.py#L30)). No `shell=True`, no `yaml.load`, no `verify=False`. Developer tooling, fine.
- A Claude Security scan (`/claude-security` in an interactive session) would give a second read of the
  GDScript and the pipeline. Not run in this session.

## Personal data

- Commit authors: 219 commits carry the GitHub noreply address, 25 carry a private one
  (`mail@sebastianruecker.com` 12, `sebastian@womb.art` 10, `Ruecker.Sebastian@googlemail.com` 3), 11
  are Claude's. A rewrite with `git filter-repo --mailmap` changes every hash, breaks 18 commit references
  in the docs and the two live worktrees, and needs a force push. Kept, on Sebastian's decision.
- `/home/womb` appears in 80 doc lines and five scripts ([fracture.py](../../game/assets/3d/fracture.py)
  and [tile_damage.py](../../game/assets/3d/tile_damage.py) read `GAME_REPO` first). It reveals a user
  name and nothing else. Portability, not safety.
- [chatgpt-design-and-game-art-conversation.md](../research/chatgpt-design-and-game-art-conversation.md)
  is Sebastian's own ChatGPT transcript about a portfolio site. It holds no contact data.
- Session plans, decisions and ROADMAP quote Sebastian verbatim. His words, his call.

## Hygiene before the session

- `origin` carried the stray branch `claude/busy-brahmagupta-uu18ap`, merged into master on 2026-10-01.
- README line 1 read "Grid Cannons – Godot port", line 7 cited the dead commit. No link to the itch page,
  no screenshot, no licence section. The GitHub description, homepage and topics were empty.
- Untracked in the checkout: `reference-ux-design-process.md` (another project's file, it names that
  project's key file), `boards/` (21 MB of PNGs), `tools/castle_looks.tscn`, `assets/art/3d/wall_straight.glb`,
  `art/game/assets/audio/sfx/castle_lost.*`, eleven marketing JPGs. `kit.blend` was modified by a Blender
  save at 01:55 on 2026-10-28, three hours after the last commit.
- Size: 194 MB tracked, 526 MB packed, largest blob 5.2 MB. Under GitHub's limits. No LFS.
- The local `.git` holds 135 unreachable commits. A push sends reachable objects only.

## Decisions

Sebastian, 2026-10-28: "New repo. rename the old one so it becomes '_old' or something. Locally, I want my
project to point to the new one. Otherwise I go with your proposals. The models are done by ai with
editing from me. .env.tools should be gitignored and it should still be in the new repo once the folder
switches to that obviously no leaks to repo or git history pls"

1. **New repository**, the old one renamed to `cannonade_old` and kept private.
2. **Copyright line** `Copyright (c) 2019-2026 Sebastian Rücker`.
3. **MIT scope** the whole repository, code, art kit, models, audio and docs, with the third-party table
   above as the exceptions.
4. **Author emails** kept.
5. **The Unity-era models** are his, AI-made and hand-edited.
6. **The old repository** stays private under the new name. Deleting it later is his call.

## Plan and what each step did

Phase 1, local

1. `reference-ux-design-process.md` differs from its copy in the portfolio repo, so it stays untracked
   and is listed in `.git/info/exclude` instead of deleted. `boards/` is in [.gitignore](../../../.gitignore).
2. The root [.gitignore](../../../.gitignore) ignores `.env*` and re-includes `.env.example`. Checked
   with `git check-ignore`: `.env.tools` and `art/.env.tools` ignored, `art/.env.example` not.
3. The other untracked session files stay as they were. Not this session's work.
4. The stray branch is deleted from the old repository.
5. gitleaks 8.30.1 sits in `~/.local/bin`, verified against the release checksum, and
   `.git/hooks/pre-commit` runs `gitleaks git --pre-commit --staged` on every commit. Worktrees share
   the hook. It ran on this session's commits.

Phase 2, licence and credits

6. [LICENSE](../../../LICENSE) holds the plain MIT text with the copyright line of decision 2.
7. The README ends with "Licence and credits": MIT, the fonts under the OFL, Kenney under CC0, the AI
   providers behind the models, images, music and sounds, Godot not included.
8. Nothing reserved, per decision 3.

Phase 3, README and hygiene

9. The README opens as Cannonade with the pitch, the itch link, the cannon-fight screenshot of the itch
   page and Godot 4.7.2. The dead commit reference is gone. The port section stays below.
10. The sandbox section says a scenario `.tres` from elsewhere is a mod.
11. `./run_tests.sh` in the worktree: 25 of 25 PASS, no ERROR output.
12. Committed as f79b884, merged by push into the main checkout's master, pushed to the old repository
    too. The main checkout refused the push over the modified `kit.blend`. Its content was saved to
    `/home/womb/repos/kit.blend.uncommitted-2026-10-28` (5 000 086 bytes, saved 01:55) and the file was
    restored to the committed content (4 987 565 bytes). If that save was Sebastian's tuning, the
    backup is the copy to bring back.

Phase 4, the new repository

13. `gh repo rename cannonade_old -R sebastianrueckerai/cannonade`.
14. `gh repo create sebastianrueckerai/cannonade --private` with the description "Cannonade: a
    Rampart-style castle game in the browser, Godot 4" and the itch homepage. Private first, public after
    the checks of phase 5.
15. The remote URL did not change, so `origin` in the main checkout and the worktrees points at the new
    repository without a `set-url`. `master` and the tag `v3` (at 7cd6ee5, the last commit before the
    export of 2026-10-24 01:45 that butler pushed) went up.
16. Issues on, projects off, wiki off. Topics godot, godot4, gdscript, game, rampart, strategy. Ruleset
    "protect master" (id 26033063, active) blocks deletion and force pushes. Secret scanning and push
    protection enabled, Dependabot alerts enabled. The social preview is a web-UI upload, still open:
    [art/game/assets/marketing/itch/](../../game/assets/marketing/itch) holds the boards.
17. [art/docs/grid-cannons.md](../grid-cannons.md) and [CLAUDE.md](../../../CLAUDE.md) keep their paths.

Phase 5, verified from outside

18. `gh api repos/sebastianrueckerai/cannonade/commits/e45e623` returns "No commit found". The same
    hash still answers on `cannonade_old`, which anonymous HTTP sees as 404.
19. A fresh clone holds 257 commits, `master` and `v3`, no env file. Its test suite: see the outcome table.
20. gitleaks `git --log-opts=--all` on that clone: 0 leaks.
21. Anonymous `ls-remote` lists `refs/heads/master` and `refs/tags/v3` only. The repository page answers
    200, the raw LICENSE 200, the raw README opens with "# Cannonade". GitHub reads the licence as MIT.
22. G10 ticked in ROADMAP in the closing commit.

## Outcome

| check | result |
|---|---|
| secrets in the pushed history (gitleaks, fresh clone, every ref) | 0 |
| old Unity commit on the public repository | 404 |
| old repository anonymously | 404, private as `cannonade_old` |
| refs on the public repository | `master`, `v3` |
| licence detected by GitHub | MIT |
| env files in the main checkout after the switch | `.env.tools` 205 bytes, `art/.env.tools` 368 bytes, both ignored, neither in any commit |
| test suite in the worktree | 25 of 25 PASS |
| test suite in the fresh clone, nothing gitignored present | 25 of 25 PASS, no ERROR output |
