# Session 74: release version numbers

Roadmap item: G9.

Sebastian, 2026-10-23: "Lets have a version number. All future releases should have them in the uploaded file."

## Why these deliverables

- **A player must be able to say which build they play.** Butler has counted the HTML5 channel silently (build #2185705 version 1, #2195852 version 2), but nobody outside the channel table ever saw a number.
- **One number, one source.** The version lives once, in `project.godot` under `application/config/version` (Godot's own slot); the menu and the butler push both read it, so the build and the channel listing cannot drift apart.

## Plan

1. [project.godot](../../../project.godot): `application/config/version="3"`, continuing butler's count.
2. [Menu.gd](../../../scripts/Menu.gd): a quiet `v3` label in the menu's bottom-left corner (the mute icon owns the bottom-right).
3. [tools/deploy_itch.sh](../../../tools/deploy_itch.sh): read the version, push with `--userversion`, refuse to deploy when the setting is missing.
4. [tests/menu_test.gd](../../../tests/menu_test.gd), written first: the menu shows the project version; watch it red before implementing.
5. Deploy v3 and confirm the channel table lists version 3 with the tick on the new build.

## Limits

- No art pipeline runs, no spending, so no `art/.env.session` for this session.
- Game changes limited to [project.godot](../../../project.godot), [Menu.gd](../../../scripts/Menu.gd), [deploy_itch.sh](../../../tools/deploy_itch.sh) and [menu_test.gd](../../../tests/menu_test.gd), plus this roadmap and plan.

## Result

`project.godot` carries `config/version="3"`, the menu shows a quiet `v3` in its bottom-left corner, and deploy_itch.sh refuses to ship without the setting and pushes it with `--userversion`, so build #2195852's silent count continues in the open. tests/menu_test watches the label red (empty setting, no label) then green; the full suite passes.

On the way the repository directory flipped names under the session (grid-cannons → cannonade → back within minutes), which briefly broke every worktree's absolute gitdir pointers and read as a deleted worktree; the flip back restored all of them untouched, and the version work was committed before anything else ran. If the rename happens for real, every .git/worktrees/*/gitdir and each worktree's .git file needs its absolute path rewritten.
