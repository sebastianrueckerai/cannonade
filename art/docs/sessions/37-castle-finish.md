# Session 37: the AI finishes the castle, the last castle ends the game, only the human's aim shows

Sebastian, 2026-10-20: "I dont want to see the AI highlighting the fields it is shooting at when
playing human vs ai. Only show this for AI vs AI." and "I did not build anything: The ai fired at
my castle until it was in ruined state, but for some reason it did not finish it off. The castle
should crumble and disappear and if it was my only one that should loose the game. Either
destroying the castle did not work or the ai targeting is fucked were it stops targeting the
castle shortly before it could win!"

Roadmap: I65. The ruined castle still stands as the d4 ruin; its crumble and whether its ground
frees up are I66, an open question for Sebastian, since rules v3 keeps the ruin standing and
blocking (I37). The `crumble2` worktree, which had cut a `castle_d3_rubble.glb`, was gone
unmerged with its branch by the end of this session.

## What the game did

Reproduced headless with `tests/sim` (versus, seed 2, the human idle): the AI's three guns put
twelve shells into the human's castle within the first battle. The game then ran the rest of
that battle and a whole 45 s build phase with the human holding nothing before the check at the
next phase switch ended it. Two things made it look as if the AI gave up:

- `GameController.run_check` was the only place a game ended, and it runs at the build-to-battle
  switch alone. A castle ruined in battle cost nothing until up to 75 s later.
- The AI's castle pool held every castle it did not own, the eight neutral ones included, and
  each shot picked at random from it: the human's castle got one shot in seven, and the AI shelled
  castles it was ringing to claim. A castle at d3 looks ruined already, so the shots that went
  elsewhere read as the AI stopping short.

## Change

- [AI.gd](/home/womb/repos/grid-cannons/scripts/components/AI.gd): `aquire_targets` is one list,
  best first. In "auto": the enemy's guns (shuffled), the castles the enemy holds, the nearest to
  ruin first, then the enemy's walls, the most walled-in first. Neutral castles are never in it.
  An explicit sandbox mode leads with its own pool and the walls follow. `search_and_fire_at_targets`
  walks the guns in random order and each gun takes the first target in its reach; the first
  loaded one fires, one shot per action as before. A gun still reloading stays aimed at its target.
- [GameController.gd](/home/womb/repos/grid-cannons/scripts/components/GameController.gd):
  `decide()` holds the end rule (fewer than two holders: the last one wins, none a draw). The check
  calls it as before, and [Castle.gd](/home/womb/repos/grid-cannons/scripts/components/Castle.gd)
  calls it the moment a shell leaves the castle a ruin. The burn at the check does not call it
  early: the claims of the same check come first.
- [Indicators.gd](/home/womb/repos/grid-cannons/scripts/Indicators.gd): `shows(player)` is the one
  rule for whose aim shows, the arc and the light cube alike.
  [Shooter.gd](/home/womb/repos/grid-cannons/scripts/components/Shooter.gd) uses it for the arc,
  [TileImpactor.gd](/home/womb/repos/grid-cannons/scripts/components/TileImpactor.gd) for the light;
  a shell remembers whether it lit its tile and puts out only its own light, so an AI shell
  landing on a tile the human aims at leaves the human's light.
- [rules.md](/home/womb/repos/grid-cannons/art/game/design/rules.md) section 8 names the target
  order; [rules-v3-draft.md](/home/womb/repos/grid-cannons/art/game/design/rules-v3-draft.md) and
  the README name the end at once.

## Tests

- `tests/finish_test` (new, 20 checks): the list order, no neutral castle, a gun first and the
  castles again once it is gone, each gun at the first target in its reach (a second AI cannon cut
  to a range that reaches the start castle alone, since every gun of the data reaches the whole
  map), one shot per action, the twelfth shell a ruin with the game going on while a castle is
  held, the ruin no target, the shell that ruins the last castle ending the game at once with no
  phase between, the DEFEAT overlay.
- `tests/target_test`: real shots from an AI gun and a human gun at one tile: the AI's lights
  nothing while a human plays, the human's lights it, the AI's shell lands first and leaves the
  light, the light goes with the human's shell; with `Indicators.own_player` null the AI's next
  shot lights the tile in its colour.
- `tests/check_test` step 6 is the check path now: the enemy's ring opened, its castle burns at
  the check and its holder is out (the shell path lives in finish_test).
- `tests/sim`: in a game with a human who never fires no tile may ever light; with no human one
  must.

**Watched red** (each broken on purpose, the test red, then restored; `/tmp/claude-1000/cf/red.py`):

- `TileImpactor` lighting for every shooter: target_test "the AI's shot lights nothing while a
  human plays" red.
- `AI` without the sort and with neutral castles in the pool: finish_test "the castle nearest to
  ruin comes first" and "no neutral castle is a target" red (and everything after them).
- `AI` with a gun at its own index target instead of the first in reach: "each gun fires at the
  first target in its reach" red.
- `Castle.take_damage` without `decide()`: "the shell that ruins the last castle ends the game at
  once" red.
- `run_check` without `decide()`: check_test "the castle outside a closed ring burns at the check,
  and its holder is out" red.
