# Session 14: the menu's look — font, panels, buttons

Roadmap: D7 (new), feeds D2 and D4.

Sebastian, 2026-10-18: "While this is going on I want you to find a cooler version of the designed menu. I mean font, shape and possible texture use. Like maybe a menu that looks like a wooden sign... So I want you to search for references, then make a few prototypes, first go die, then iterate using a critic and then show me the best alternatives."

The web-menu thread owns [Menu.gd](/home/womb/repos/grid-cannons/scripts/Menu.gd), [menu.tscn](/home/womb/repos/grid-cannons/scenes/menu.tscn) and [menu_test.gd](/home/womb/repos/grid-cannons/tests/menu_test.gd) this session. This round touches none of them: candidates go through the [Art.gd](/home/womb/repos/grid-cannons/scripts/Art.gd) drop-in slots in this worktree only.

## Why these deliverables

- Reference notes from comparable games: the wooden-sign idea is common enough that a taxonomy beats taste. Feeds the direction set.
- Four directions built in the real menu through the Art.gd slots (font.ttf, button.png, panel.png, manifest margins, theme colours) and shot at 1280 by 720 and 390 wide. The review unit is the real screen, because font and texture are details a concept image cannot draw ([assets-2d.md](../process/assets-2d.md)). Feeds D4.
- Gen 1 dies: a calibration pass that exists to tune prompts and slice margins. Its generated files are deleted, its learnings go into the brief. Sebastian's instruction.
- Two critics (Gemini through fal, GLM on Z.ai), at most two loops, every legibility claim checked against a crop before it changes a candidate ([providers.md](../docs/providers.md)).
- Boards plus [PICKS.md](../game/art-direction/rounds/30-menu-look/PICKS.md) with the director's recommendation and runner-up. Sebastian's pick ships to the [ui/ slots](/home/womb/repos/grid-cannons/assets/art/ui/) in a follow-up commit.

## Plan

1. References: web pass over cozy and period strategy menus, plus the kit's own logo language and [art_bible.md](../game/art-direction/art_bible.md) chapter 5. Notes into the [round brief](../game/art-direction/rounds/30-menu-look/brief.md).
2. Fonts: four OFL candidates into the round folder (Signika, Alegreya, Metamorphous, IM Fell English), one weight per direction for the round; the pick gets the full family at integration.
3. Textures: panel and button 9-slice PNGs per direction from the style anchors through [img.py](../pipeline/img.py) gen, prompts carry no text. Hover and pressed states derive in Art.gd until the pick.
4. Build: each direction's files into [assets/art/ui/](/home/womb/repos/grid-cannons/assets/art/ui/) in this worktree, shoot menu.tscn at both widths with [shoot_ui.tscn](/home/womb/repos/grid-cannons/tools/shoot_ui.tscn) through [godot_render.sh](/home/womb/repos/grid-cannons/tools/godot_render.sh), montage the boards. Gen 1's generated files deleted after its critique.
5. Critics on the boards, claims checked in crops, one fix loop and one compare loop.
6. Boards presented to Sebastian by number, PICKS.md filled with recommendation and runner-up.

## Limits

4 directions, all built in the real menu. Gen 1 keeps learnings only. At most 2 directions carried into the fix loop. Cap USD 6 in [.env.session](../.env.session) (window 2026-10-18T14:25), stop time 19:00. No touch to Menu.gd, menu.tscn, tests or the theme.tres on master; nothing lands in the live ui/ slots before the pick. About 12 paid generations and 6 critic calls expected, every board inside the 25-image pick budget (D19).

## Result

Done, awaiting the pick. Four directions built and shot in the real menu at both widths;
gen 1 thrown away after its two-critic round; a and b carried into gen 2, d dead, c the flat
control. Gen 2 needed four regens (edge-to-edge buttons, single outline) plus a deterministic
a-panel crop and a panel-padding fix that put all seven buttons back above the fold at 390
(pixel-verified). Both critics ship b, the harbour chart; a, the wooden sign, is the
runner-up with a known contrast cost. Boards by number in [PICKS.md]
(../game/art-direction/rounds/30-menu-look/PICKS.md). D7 stays open until Sebastian picks.
About $2.1 of the $6 cap spent (tracker reads $1.62, under-counts regens).

Two things surfaced that belong to Menu.gd, not this round: a painted title on the sign and
a wax-seal accent would need text drawn by the menu, and at 390 the help panel sits mostly
below the fold in every direction (layout, not look).

