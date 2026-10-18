# Session 15: Tutorial & Controls, with input remapping

Roadmap item: G7.

Sebastian, 2026-10-18: "I want the how to play to be 'Tutorial & Controls' and It should be possible to remap the inputs!"

## Why these deliverables

- **The name now says what the panel holds.** The primer teaches the game, the table holds the controls; together they are "Tutorial & Controls".
- **Remapping keeps players.** The five gameplay actions (build wall, build building, rotate both ways, fire) are the whole hand. A player who wants them elsewhere should move them in the same panel that teaches them, and the game must obey everywhere at once, across restarts.

## Plan

1. [Menu.gd](../../../scripts/Menu.gd): the button and panel title become "Tutorial & Controls". The remappable rows turn into buttons named after their action, showing the live binding; clicking one waits for the next key or mouse button. The primer and the fixed rows (wheel, middle drag, Enter where Practice runs, Esc) stay as they are.
2. Remapping writes the `InputMap` at runtime (the game reads these five only through actions), normalizes the captured event to the project's own event shape (device -1, physical keycode), rejects a key already on another of the five with a note, and saves all five to `user://input_remap.cfg`. The menu loads that file on start and applies it, so the bindings survive a restart. Esc cancels a capture; it still closes the panel when no capture runs.
3. [tests/menu_test](../../../tests/menu_test.gd) drives the real flow first: the rename, the default bindings shown, capture and apply through `Input.parse_input_event`, the input map itself, persistence across a menu reload, the conflict rejection, the hermetic cleanup of the saved file.
4. The browser build: [tools/export_web.sh](../../../tools/export_web.sh), then the panel in headless Chromium, renamed and remapping through a real key press.

## Limits

- No art pipeline runs, no spending, so no `art/.env.session` for this session.
- Game changes limited to [Menu.gd](../../../scripts/Menu.gd) and [tests/menu_test](../../../tests/menu_test.gd), plus this roadmap and plan. The camera controls, Enter and Esc stay hardcoded and are listed as fixed rows, not remapped.

## Result

Done and verified: the suite is green, the panel renames and remaps on desktop and in the exported browser build, and bindings survive a reload.
