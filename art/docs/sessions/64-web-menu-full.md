# Session 64: the browser menu shows the whole game

Sebastian, 2026-10-23: "Fix the menu of the web built version. It has flags to not show all menu
entries. It should show all but 'Sandbox'." — and on Quit: "Ah, yes- no quit on the browser! That
is still the case!" Roadmap: G8 (supersedes G6's two-mode rule and I88's pair).

## What ships

[Menu.gd](../../../scripts/Menu.gd) grew `_build_buttons(box, web)`: the modes, Tutorial & Controls
and Volume everywhere, Sandbox and Quit desktop-only. `_ready` passes the one read of
`OS.has_feature("web")`; `modes_for` and the web gate on the panel's "next phase (Practice)" row are
gone — practice is reachable everywhere now, so the row lists everywhere. tests/menu_test drives the
builder with `web = true` and checks the five web buttons against Sandbox and Quit leaking in
(watched red both ways: practice dropped, Sandbox shown); the desktop build stays the 7-button
check. The suite ran green — all 22 suites, practice_test and the ai2 sim among them — after the
C20 gun-look, terrain and flat-arc rounds. An extra 45 s practice sim ran error-free; its only
failures are the sim's versus-shaped invariants (walls past the start ring, an active gun) hitting
the dormant fort that is practice by design (I7). The ai2 smoke ran green. The web export was
rebuilt and smoke-tested in headless Chromium (25 s, no page errors).
