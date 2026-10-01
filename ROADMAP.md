# Roadmap

Living plan for Grid Cannons. Read it before starting a round of work. At the end of a
round, move finished items to **Done**, adjust **Next**, and park anything left over,
anything learned, and any new ideas in the right section. Nothing that was not finished
in one go gets lost: it goes here.

Legend: `[ ]` open · `[~]` started · `[x]` done · **(decide)** needs a decision ·
**(spike)** needs a short experiment first · **(test)** an idea to try out in play.

---

## Goal of the next rounds

1. **Buildings as data.** Define buildings, their behaviour parameters, how you get them
   (random draw, upgrade pattern, combination) and what they cost, in data files instead
   of code and scenes, so balancing is editing numbers.
2. **Sandbox (level editor + battle lab).** A menu mode to set up two bases with walls and
   guns, press Play, and watch what happens. Example question: how many flak guns defeat
   how many cannons?

Both are in place (rounds A–C). Candidates for the next round: use the lab on the
breach rule and other (test) ideas below, sandbox polish for players, the 4-AI
performance spike.

---

## Done: round A – building catalog (data-driven buildings)

Behaviour must stay identical to today; the existing tests prove it.

**Format (decided).** One Godot resource file per building
in `data/buildings/*.tres` (a `BuildingDef` resource class). It is plain text, so it diffs
well and can be edited in any text editor. In the Godot editor it is a form with typed
fields, dropdowns and pickers, so no parsing code or schema is needed. The alternative,
JSON / CSV, is nicer for spreadsheets but has no editor UI. A CSV *export* for overview
tables could come later.

**Workflow this must support (acceptance criteria)**
- New type: duplicate an existing `.tres` in the FileSystem dock, rename it, change fields
  in the Inspector, press F5 (or Play in the Sandbox): it appears in the Sandbox palette
- Behaviours are a list in the Inspector: "Add Element" → pick a behaviour type from the
  dropdown (Cannon, Flak, Shield, …) → fill in its numbers; remove with the trash icon
- Models can be reused from other buildings while prototyping
- A broken file never crashes the game; errors are listed in the Sandbox / console with
  the file name and what is wrong
- Only a genuinely new kind of behaviour needs code (one small script that then shows up
  in the dropdown)

**`BuildingDef` (sketch)**

| field | meaning |
|---|---|
| `id`, `name`, `description` | identity, shown in palettes and tooltips |
| `model` | scene with the visuals only, plus named anchor nodes (`Barrel`, `Muzzle`, `Turret`, `ShieldMesh`, `RocketSpawn`) |
| `size` | 1, 2 or 3 tiles square |
| `health` | hit points |
| `access` | walkability 3×3 grid per tile (walls); empty = fully walkable |
| `produces` / `consumes` | resource amounts, e.g. `{supply: 4}` / `{supply: 9}`; only `supply` today |
| `draw_weight` | chance to be offered as "next building" (0 = never drawn) |
| `recipe` | how it is obtained: an upgrade **pattern** (grid of block / building ids, `*` wildcard, which rotations are allowed) or a **combination** (place X on Y) |
| `behaviours` | list of behaviour resources, see below |

**Behaviours = small node scripts plus a parameter resource**, e.g.:

* `Cannon` (range min / max, gravity, arc, reload, damage) + `Projectile` (speed, splash,
  burn, stun, cluster count, tile destroyer)
* `RocketLauncher` (range, reload, initial delay)
* `Flak` (look range, shoot range, salvo interval)
* `Shield` (radius, absorb, regeneration, reset time)
* `Supply` (amount, already covered by `produces`)

At spawn, a generic `Structure` node builds the model and adds one behaviour node per
entry. The behaviour finds its anchors in the model by name. These are today's
components, with their numbers moved into data.

**Tasks**
- [x] `BuildingDef`, behaviour parameter resources, `ProjectileDef`, `Catalog` autoload
- [x] All buildings and projectiles moved into `data/` (21 buildings incl. walls, base and
      the ship's gun, 4 projectiles); model scenes stripped to visuals
- [x] Upgrade patterns, combinations and the next-building / next-wall draw read the catalog;
      the AI's target structures are catalog ids
- [x] Recipes on building ids: any single-tile building can be part of a pattern
- [x] Validation with readable messages (pattern size, unknown ids, clashing recipes,
      missing model, wrong file type, missing essentials); shown in the main menu and on F5
- [x] F5 hot reload; placed buildings take the new numbers
- [x] Tests: `catalog_test` (validation, duplicate → edit → F5 workflow, recipe from
      buildings); existing suites green = parity
- [x] README walk-through "Make a new building type"

**Left over from round A**
- [ ] F5 only updates numbers of placed buildings; behaviours added to or removed from a
      def apply to buildings placed afterwards
- [ ] Missing model parts (`Barrel`, `ProjectileSpawn`, …) silently fall back to empty
      helper nodes; a validation hint would help when building new models
- [ ] CSV / table export of all buildings for a balancing overview
- (decide) The AI's goal structures (`preferredUpgrade = cannon22c`, `supplyUpgrade =
  supply22` in `AI.gd`) could become catalog data (e.g. an `ai_priority` field)
- Note: Godot does not write values equal to a field's default into `.tres` files; the
  Inspector still shows them. Changing a default in `scripts/data/` changes every file
  that relies on it.

## Done: round B – sandbox editor v1

Main menu → **Sandbox** (`scenes/sandbox.tscn`, `scripts/sandbox/`). Test:
`tests/sandbox_test` (real mouse / key input).

**Editing**
- [x] Map size choice (default 30×30); both bases auto-placed and walled in; **Base** tool moves them
- [x] Bottom toolbar: side toggle (buttons or `1` / `2`), **Wall**, **Erase**, **Base**, one
      button per catalog building (tooltips from the def)
- [x] Wall painting with automatic shapes (`Catalog.spawn_wall_for`; `tests/ring.gd` uses it too)
- [x] Left click places, right click erases (drag works for both), `R` rotates, ghost
      preview with the model, red footprint where it does not fit
- [x] Live enclosure display; a red X over guns / supply buildings that would not work
- [x] Undo / redo (`Ctrl+Z` / `Ctrl+Y` / `Ctrl+Shift+Z`), one step per drag
- [x] Save / load: `user://scenarios/*.tres` (`ScenarioDef`); example `data/scenarios/flak_vs_cannons.tres`

**Playing**
- [x] **Play**: battle only, no build phase, no random pieces; ends when a side has no
      working gun (after a 1 s grace) or at the time limit (default 180 s)
- [x] Match setup: AI vs AI (default), Player vs AI, Player vs dormant AI
- [x] Speed: pause, 1×, 2×, 4×, 8×; **Back to editing** restores the layout
- [x] Stats per side: shots, hits, intercepted, absorbed, walls / guns / buildings lost,
      result line with winner and time
- [x] Target choice per AI side: walls / guns / supply / random (`AI.targetMode`)
- [x] Found on the way: flak errored when a shell it tracked was destroyed by another
      defence (fixed in `Flak.gd`)

**Left over from round B**
- [ ] Wall stacking (wall on wall) is not available in the editor; walls are one layer
- [ ] `R` rotation is cosmetic for multi-tile buildings; rotated-pattern variants (e.g.
      Cannon22c turned) are the same building
- [ ] **New** and **Load** discard unsaved edits without asking
- [ ] The human side is always blue in Player vs AI
- [ ] "No working gun" counts cannons and rocket stations only; a side with only flak or
      shields left loses even if it would hold out
- [ ] Ships are not available in the sandbox
- (decide) Battle time limit default 180 s: right for balance tests, or shorter?
- (test) The example scenario is one-sided (blue wins in ~11 s at seed 4242); more
  balanced examples would make better starting points

## Done: round C – experiments (battle lab)

`scripts/sandbox/BattleLab.gd`, `tools/lab.tscn`; test `tests/lab_test` (CLI as a subprocess).

- [x] Headless batch runner: `--scenario --runs --seed` prints win rates and mean stats
      per side; per-battle lines while running
- [x] Parameter sweeps (`--sweep=id.field=a:b:step` or a list) and one-off changes
      (`--set`), on any field of a building, its behaviours or its projectile
- [x] Results to CSV (`--csv`), one row per battle
- [x] Sandbox: **Run N seeds** button (background process, result in the side panel,
      `user://lab/last_run.csv`); **Mirror** copies one side's layout to the other;
      "duplicate" = Save under a new name
- [x] New match setup **AI vs dormant AI**
- [x] Fair comparisons: every seed is also played with the layouts swapped; results are
      per layout (`--swap=false` turns it off)
- [x] Reproducible: a seed gives the same battle wherever it runs in a batch (Godot's
      frame-time jitter fix is turned off in the lab)
- [x] Placing a whole layout recomputes the enclosed areas once (`StatesMap.begin_batch`):
      0.7 s → 0.03 s per layout
- [x] Example `mirror_forts` (two identical forts)

**Findings (from the lab)**
- Identical mirrored forts, walls targeted: blue won 65 %, red 25 % before the swap –
  in a tie within one frame the side processed first wins. With the swap: 45 / 45 / 10.
  With guns targeted it was already about even (50 / 45)
- Battles are decided within ~6 s: the first wall breach opens the fort and every gun
  inside goes inactive at once
- 8× speed changes results (flak at 0.25 s salvo: blue 100 % at 1×, 50 % at 8×), as the
  game steps 0.27 s per frame; the in-game speed buttons are only for watching

**Left over from round C**
- [ ] Sweeps and `--set` only from the command line; the Sandbox Run uses the data as saved
- [ ] Sweep of two values at once (grid), or of several buildings' field at once
- [ ] The Sandbox's own Play still gives blue the tie advantage **(decide)**: randomise
      or alternate the processing order per battle?
- [ ] Accurate fast-forward in the Sandbox (several game steps per frame instead of a
      bigger step) **(spike)**
- (test) Breach rule: today one wall hit can switch off a whole fort. Ideas: guns stay
  active for a few seconds after a breach, only buildings near the gap go off, or walls
  get more health – the lab can compare these quickly

---

## Later: sandbox polish (for players)
- [ ] Nicer toolbar with building icons and tooltips (name, cost, behaviour summary)
- [ ] Short in-editor help overlay / first-run hints
- [ ] More shipped example scenarios, with their `description` shown in the editor

## Ideas to try (test)
- (test) Flak with a limited number of shots per salvo, or a cooldown per shell
- (test) Shield as a dome that absorbs a fixed amount, then breaks (today it regenerates)
- (test) Supply as a network: buildings only get supply from depots in the same enclosed area
- (test) More resource types (ammo, power), via the `produces` / `consumes` maps
- (test) Upgrade recipes from built buildings (possible since round A), e.g. four
  cannons → flak battery; multi-tile ingredients (2×2 flak → battery) still unsupported
- (test) Shell arcs: today's arcs are very high (the original formula picks the steep
  solution); a flatter arc may be easier to read
- (test) Win condition for normal games: base destroyed, or more enclosed area after N rounds
  (the Unity `roundsPerGame` was never used)

## Maybes (decide / spike)
- (decide) Hot-seat (two humans) in the Sandbox: not planned; revisit if wanted
- (decide) Keep the Unity quirks the port preserved on purpose (AI plan geometry, the
  `(x, x)` check in `try_build_gun_in_plan`, upgrade-cluster tile checks at absolute
  index 0), or clean them up?
- (spike) An in-game balancing panel (edit catalog numbers live in the sandbox) vs the
  Godot inspector plus F5 reload
- (spike) Visual building editor (assemble a model from parts) – probably not worth it
- (decide) Rewrite git history to drop the ~550 MB of Unity history (currently: keep;
  use `git clone --depth 1` for small clones)

## Known issues / tech debt
- [ ] 4-AI 60×60 mode stutters (p99 frame ~100+ ms): the AI plan search and the enclosure
      flood fill are slow in GDScript. Options: incremental flood fill, cache plans between
      searches, or a C# / GDExtension hotspot **(spike)**
- [ ] Untested guard: AI plan search resuming after the game scene was left (no
      deterministic reproduction found)
- [ ] Not ported: particle effects and trails, the force-field shield shader, gamepad
      controls for player 2, custom cursor
- [ ] Next-wall / next-building previews in the screen corners look crude (white
      placeholder cubes)
- [ ] No sound
- [ ] AI (from the old `TODOS.txt`, translated): search 3×3 sub-areas that are either
      empty or have walls with the right connectors; pick the legal area with the most
      built tiles, on ties prefer the better corner / straight ratio; put currently
      unusable pieces into further adjacent areas, as far away as possible; corner
      piece with a 1/4 chance; attach every building block to a plan; each round go
      through the plans (highest priority / most points first), check they are still
      intact and recalculate if not; rotate a piece and check it against all pieces in
      the plan; discard unusable pieces; stop when no place is free.
      Much of this exists in `AI.gd` (`BuildingPlan`); still to check: plan priority
      ordering and discarding unusable pieces

## Done
- [x] Port from Unity 2018.3 to Godot 4.7 / GDScript, all game modes, textured wall models
- [x] Headless test suite (`run_tests.sh`), audited against the test-audit principles
- [x] Supply depot buildable (pattern ambiguity with Cannon22d fixed)
- [x] Unity project removed; the Godot project is the repository root
- [x] Mouse wheel zoom to the cursor, middle mouse panning
- [x] Round A: buildings and projectiles as data (`data/`, `Catalog`, F5 reload);
      combining now uses the upgrade block up; any building can be a recipe part
- [x] Round B: Sandbox editor + battle (menu entry, `scripts/sandbox/`)
- [x] Round C: battle lab – batch runs, sweeps, CSV, Run button, fair side swap
