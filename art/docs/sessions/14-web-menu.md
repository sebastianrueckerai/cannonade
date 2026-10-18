# Session 14: the web menu and a How to play panel

Roadmap item: G6.

Sebastian, 2026-10-18: "On the shipped web version I want only 'Player VS AI' and 'Watch AI vs AI' as options in the main menu, plus a button that brings up a text box with the controls. Or better: Add a small menu to map controls, make it so it also sort of explains the game."

## Why these deliverables

- **The browser build is the demo.** Two modes show the game: one to play, one to watch. Single player, the four-AI watch, practice, the Sandbox and Quit are desktop doors, not demo doors.
- **Nobody reads a README in a browser.** The controls and the three rules that decide the game (wall your guns in, supply feeds them, 2x2 blocks merge) belong one click from the menu — on every platform, so the panel went into the desktop menu too.

## Plan

1. [Menu.gd](../../../scripts/Menu.gd) gates its mode list on `OS.has_feature("web")`: "Player vs. AI" and "Watch: AI vs. AI" only, plus the How to play button everywhere.
2. The How to play panel: a dim overlay in the menu's own style, a three-paragraph primer, a two-column controls table (the Enter row only where Practice is reachable), closed by its button, Esc or a click on the dim.
3. [tests/menu_test.gd](../../../tests/menu_test.gd) drives the real flow, written first: button count, the modes desktop keeps, the panel opening, the controls listed, both close paths; then a break-on-purpose check.
4. The browser build itself: [tools/export_web.sh](../../../tools/export_web.sh), then [tools/check_web.py](../../../tools/check_web.py) and a click through the panel in headless Chromium.

## Limits

- No art pipeline runs, no spending, so no `art/.env.session` for this session.
- Game changes limited to [Menu.gd](../../../scripts/Menu.gd) and [menu_test.gd](../../../tests/menu_test.gd), plus this roadmap and plan.

## Result

The web menu shows the logo, "Player vs. AI", "Watch: AI vs. AI" and "How to play"; nothing else. The panel carries the primer and the controls, Esc closes it everywhere. `tests/menu_test` covers the menu (count, desktop modes, open, both close paths) and stays green with the full suite. The exported build, checked in headless Chromium, shows the two modes and opens the panel.
