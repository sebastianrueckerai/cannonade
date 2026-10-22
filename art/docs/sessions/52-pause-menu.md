# Session 52: the pause menu on Esc
Sebastian, 2026-10-22: "Durin a running game a smaller meu should pop up on ESC with the volume settings and
the option to go bnack to mnain menu or restart the current round. Play should stop in menu"
Roadmap: I82, game code.
## What ships
Esc in a running game pauses the tree (`get_tree().paused`) and opens a small parchment panel over a dim in
[Main.gd](../../../scripts/Main.gd) (`_open_pause`): the title "Paused", the three volume sliders, and Resume,
Restart, Menu stacked under them. Restart replays the seed through the end screen's existing `_retry`; Menu is
`_to_menu`; both unpause first. Esc closes the menu again through the Resume button's shortcut (Esc as its
`Shortcut`), a click on the dim through its `gui_input`, and the overlay is the one branch that still takes
input while paused (`PROCESS_MODE_WHEN_PAUSED`), so play stands still: the phase clock, the AI, the ships,
physics and `U.time` all freeze, and the music keeps playing. An effect in flight now pauses with its cleanup
timer (`create_timer(life, false)` in [FX.gd](../../../scripts/FX.gd)) instead of being freed early under the
pause.
## What it reuses
The volume rows moved from Menu.gd's Volume panel into `Sound.volume_rows()` in
[Sound.gd](../../../scripts/Sound.gd), which already owned the settings and their file: the menu's panel and
the pause menu wear the same three sliders, live on the buses and saved on every change. The panel is the
menu's own overlay shape (dim, centred PanelContainer, full-width buttons, Alegreya theme).
## Where it does not open
After the game ends (`game.started` false) Esc keeps going straight to the menu, and the sandbox worlds — a
`Main` built from a `config` — never open it; their Esc stays the old leave-to-menu. The Tutorial & Controls
fixed row, the HUD help lines and the README now say pause, not "back to the menu".
## The check
[human.gd](../../../tests/human.gd), real keys and mouse, versus seed 7: Esc pauses with the round clock and
`U.time` frozen exactly over five frames, the panel holds the three sliders, the master slider sets the volume
live and saves `user://volume.cfg` (restored afterwards), the buttons are wired to `_close_pause` / `_retry` /
`_to_menu`, Esc resumes with `U.time` running again, and a click on the dim closes a reopened menu.
[menu_test](../../../tests/menu_test.gd) ends through the new flow: Esc in the started game opens the pause
menu, its Menu button returns to the menu unpaused. Every new check watched red with the pause menu's opening
branch removed and with the paused flag left off.
