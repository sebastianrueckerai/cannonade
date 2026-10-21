# Session 46: the killing blow scars the freed ground
Sebastian, 2026-10-21: "I want ground damage to be immediate: So from the first shot, and maybe
from the second shot on a neighboring tile. So see how that works currently and improve. A ground
does not take damage until its structure is destroyed. But upon destroying the structure there
should be immediate damage on the ground as well. Otherwise, shooting at the ground only, it
should do increasing visible damage!"
Roadmap: I74. Game code only: the cratered slabs of I73 already carry all three stages, the rule
that feeds them changes.
## The rules
Unchanged: a hit on a tile with a standing structure is soaked by it, water takes none, bare
ground takes the hits in three stages at 1 / 25 / 50, building on a tile heals it. Changed: the
killing blow no longer vanishes into the structure - it also lands on the ground the dying
structure frees, full damage, so a shell that flattens a wall leaves a stage-1 dent at once, the
heavy's shell a stage-2 one, and the next shells escalate from there exactly like bare ground.
The spill lives at the death sites: BuildingPlace.damage_structure after un_build(), and
UpgradeCluster.damage_structure after un_build_upgrade() for every tile the fused heavy frees
(one structure stands on four tiles, so the blow scars all four). The castle is unchanged on
purpose: the ruin that replaces it is a standing structure, and a stacked wall's death leaves
the main wall standing, so neither scars. Splash is untouched: cluster shards already scar the
eight tiles around their burst with splash_range 1; plain shells stay single-tile, his
"maybe ... on a neighboring tile" stays out until he asks for it.
## The checks
tests/weapons.gd, every new check red on the old code: the killing blow on a cannon leaves
stage 1 and the cratered slab at once, then 15 / 25 damage reach stages 2 / 3 from the kill's
10 (the old soak chain rewritten: 10 + 15 = 25, 25 + 25 = 50), and the file's fused gun, whose
four cannons build_building fuses on its own, dies to its eighth shell and leaves all four
freed tiles at stage 1 - the real cluster death path, no new setup. Boards:
tools/godot_render.sh --kill=wall in versus, the worktree's frame shows the fallen wall's
tile scorched and dented 4 s after the kill; master's frames hide the kill tile under the
persistent centre plaque, so the before contrast comes from the red run, not the eye.
