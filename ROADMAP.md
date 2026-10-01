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

## Next: round B – sandbox editor v1

A main menu entry **Sandbox**. Two sides, blue and red. Aims: obvious to use, no manual
needed. Audience: mainly a dev tool to iterate on gun concepts and balance; players may
use it too, so polish follows later (see Later: sandbox polish).

**Editing**
- [ ] Map size choice (default 30×30); both bases auto-placed as today, but movable
- [ ] Bottom toolbar: side toggle (blue / red, or keys `1` / `2`), tools **Wall**,
      one button per catalog building, **Erase**, **Base**
- [ ] **Wall painting with automatic shapes:** click and drag to draw a wall line, and the
      right corner / T / cross / straight piece is chosen from its neighbours (the helper
      exists in `tests/ring.gd`; move it to production)
- [ ] Left click places, right click erases, `R` rotates a building, ghost preview under
      the cursor, red tint when the spot is invalid
- [ ] Live display of enclosed areas and active / inactive guns (supply, enclosure), same as in game
- [ ] Undo / redo (`Ctrl+Z` / `Ctrl+Y`)
- [ ] Save / load scenarios: `user://scenarios/*.tres`; shipped examples in `data/scenarios/`

**Playing**
- [ ] **Play** runs a *battle only* simulation: no build phase and no random pieces; it
      ends when one side has no active gun, or at a time limit
- [ ] Match setup before Play: **AI vs AI** (default), **Player vs AI**, **Player vs
      dormant AI** (the AI side never fires, to see how a build performs against a
      stationary enemy). The player side aims and fires as in the normal game
- [ ] Speed: pause, 1×, 2×, 4×, 8×; **Reset** returns to the edited layout
- [ ] Stats panel per side: shots, hits, intercepted by flak, absorbed by shields, walls /
      guns lost, time to defeat, winner
- [ ] Target choice per AI side: walls (today's behaviour) / guns / supply / random
      (decided: part of round B)

## Later: round C – experiments (battle lab)
- [ ] Headless batch runner: `--scenario=x --runs=50 --seeds=1..50` prints win rates and
      mean stats per side, e.g. "4 flak vs 6 cannons: blue wins 72%". Uses the deterministic
      fixed step, as the tests already do
- [ ] Parameter sweeps: run a scenario while varying one catalog value (e.g. flak salvo
      1.0–3.0 s) and print a table
- [ ] Scenario variants in the editor: duplicate, mirror a base to the other side
- [ ] Results to CSV for spreadsheets

---

## Later: sandbox polish (for players)
- [ ] Nicer toolbar with building icons and tooltips (name, cost, behaviour summary)
- [ ] Short in-editor help overlay / first-run hints
- [ ] Shipped example scenarios with descriptions

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
