# Session 36: the AI builds half as fast

Sebastian, 2026-10-20: "Maek the ai build half as fast (increase the pause)".

Roadmap: I63.

## Change

- [AI.gd](/home/womb/repos/cannonade/scripts/components/AI.gd) splits I49's one reaction time
  in two: `secondsBetweenBuilds`, 1.0 s after every build action (a placed piece or gun, a
  stacked block, a dropped piece, a discarded gun), and `secondsBetweenShots`, 0.5 s after every
  shot. The battle keeps its pace; only the build is slower.
- The idle retry stays 0.15 s: a wait with nothing to do is no action.
- [rules.md](/home/womb/repos/cannonade/art/game/design/rules.md) section 8 names both.

## Tests

`tests/ai_test`: the default build wait is at least twice the default shot wait, and the live
25 s claim check runs at a build wait of its own, 0.5 s, since it counts actions, not seconds.
The pace check times the build at a test-set 1.1 s and the shots at 0.8 s, apart, so a build
paced by the shot wait or a shot paced by the build wait turns the test red. Build gaps seen:
1.1, 1.133, 1.133, 1.133 s; battle gaps 0.833 s.

**Watched red** (each broken on purpose, the test red, then restored):

- the build paced by `secondsBetweenShots`: build gaps 0.8, 0.833, 0.833... under the 1.1 s set
- the default build wait back at 0.5 s: "builds at most half as fast as it shoots by default" red

The full suite ran green on this `AI.gd` apart from the claim check, which was then given its own
pace; `ai_test` is green alone after that.
