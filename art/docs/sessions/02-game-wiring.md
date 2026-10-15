# Session 02: Game wiring and the browser build

Roadmap items: F1, F2, F3 (walls), F4, F5, G1, G2, G3. Sebastian's rule for the session: no image or mesh production, simple shapes as placeholders, wiring only (D12).

## Goal

The game takes art by file name, runs in the browser from one script, and tells us when a model has the wrong size. All of it before any art exists, so the art sessions only drop files.

## What was built, in the game repo

- [assets/art/](/home/womb/repos/grid-cannons/assets/art) with [README.md](../../README.md), `manifest.json`, `ui/theme.tres`. [scripts/Art.gd](/home/womb/repos/grid-cannons/scripts/Art.gd) attaches `3d/<id>.glb` to buildings (`Catalog.spawn`), ships (`ShipFleet`), tiles (`Map`, mesh swap) and walls (`WallModel`), hides placeholder meshes, maps snake_case parts to PascalCase pivots, checks sizes once against the manifest.
- [scenes/splash.tscn](/home/womb/repos/grid-cannons/scenes/splash.tscn) is the main scene, [scenes/loading.tscn](/home/womb/repos/grid-cannons/scenes/loading.tscn) sits between the menu and the game, the menu shows `ui/logo.png` and `ui/menu_background.png` when present, the game uses `sky/world_panorama.png` when present. The Godot boot logo is off.
- [export_presets.cfg](/home/womb/repos/grid-cannons/export_presets.cfg) with a Web preset without threads, [tools/export_web.sh](/home/womb/repos/grid-cannons/tools/export_web.sh), [tools/serve_web.sh](/home/womb/repos/grid-cannons/tools/serve_web.sh), [tools/check_web.py](/home/womb/repos/grid-cannons/tools/check_web.py) (Playwright), [tools/check_art.tscn](/home/womb/repos/grid-cannons/tools/check_art.tscn) in [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh).
- [tests/menu_test.gd](/home/womb/repos/grid-cannons/tests/menu_test.gd) waits for the loading screen.

## Evidence

- [run_tests.sh](/home/womb/repos/grid-cannons/run_tests.sh): 16 of 17 pass with the project-wide theme, the sandbox test failed on moved click targets. With the theme scoped to the menu screens, scripts, sandbox and menu pass again. The full suite ran once before the scoping, the three affected tests after it.
- Size check: a wall copied in as `cannon.glb` with a wrong manifest size fails `check_art` with exit 1 and the message names both sizes. With the right size it passes, and the catalog test passes with the model attached. The temporary file was removed.
- Browser: [tools/export_web.sh](/home/womb/repos/grid-cannons/tools/export_web.sh) builds 39.5 MB wasm plus 2.0 MB pck. [tools/check_web.py](/home/womb/repos/grid-cannons/tools/check_web.py) shows the themed menu after the splash in headless Chromium, no page errors.
- Game commit b8f3e48 on master, pushed, includes Sebastian's two editor re-saves as agreed.

## What was built here

- [pipeline/godot_sync.py](../../pipeline/godot_sync.py) copies approved `final.glb` files into the art layer and writes the manifest with Godot axes.
- Docs: [grid-cannons.md](../grid-cannons.md), [integration.md](../process/integration.md), decisions D10 to D13, roadmap ticks and the new E5, E6, F7, F8, F9.

## Open

- F8: no model has used a pivot yet, the mapping is untested with a real barrel.
- The HTML shell still shows the Godot logo while the engine downloads (F9).
- G4 hosting. Round 02 waits for the picks in [PICKS.md](../../game/art-direction/rounds/01-directions/PICKS.md).
- The Z.AI account has no balance, the second critic is out until it is topped up.

## Addendum: image slots and the headless rule

- `ui/button.png`, `ui/button_hover.png`, `ui/button_pressed.png`, `ui/panel.png` as 9-slice styles and `ui/font.ttf` as the default font, loaded on top of `theme.tres` when present. Slice margins default to a quarter of the image, `manifest.json` `"ui"` overrides. The menu and loading screens sit in a PanelContainer.
- Proof with generated placeholder images, removed after the shot: [02-menu-with-image-slots.png](02-menu-with-image-slots.png) against [02-menu-flat-theme.png](02-menu-flat-theme.png), and [02-splash.png](02-splash.png). Menu test passes, browser build re-exported and smoke-tested. Game commit 63bb208.
- [tools/shoot_ui.tscn](/home/womb/repos/grid-cannons/tools/shoot_ui.tscn) screenshots any scene at any window size, for the UI readability check in roadmap D4.
- Rule from Sebastian: Godot headless or under Xvfb, never a window on the real display. [tools/godot_render.sh](/home/womb/repos/grid-cannons/tools/godot_render.sh) in the game wraps Xvfb for the screenshot tools. The session 01 and 02 screenshots before this rule did open windows.
