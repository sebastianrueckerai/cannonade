# Session 23: the loading bar sits in the panel's drawn frame

Fifth playtest report (2026-10-19), one screenshot: on the loading screen the
gold bar lies below the parchment's drawn slot, spilling over the panel's dark
border, and neither reads as belonging to the other.

## Root cause

The parchment panel skin is a 9-slice of [ui/panel.png](/home/womb/repos/cannonade/assets/art/ui/panel.png),
917x512, whose design element is the thin double-line inner frame. Measured on
the texture, that frame sits 31-36 px from the top edge, 35-41 px from the
bottom, 33-38 px from the left and 878-883 px from the right — and with slice
margins of 46 those bands render unscaled in every panel, so the frame always
occupies those insets regardless of panel size.

The skin's declared content margins in
[ui/manifest.json](/home/womb/repos/cannonade/assets/art/ui/manifest.json) were
(26, 12, 26, 12): the content area starts inside the frame and crosses it. The
menu panels had the same disease, milder — the frame lines ran behind the
buttons. On the loading screen it glared: at 412x88 the panel's 9-slice
compresses the texture's 420 px middle into ~8 px, the frame collapses into a
thin empty-looking slot mid-panel, and the bar (label above it) straddled and
overhung it.

## Fix

The content margins clear the drawn frame everywhere:
(42, 42, 42, 46), leaving 3-6 px breath to the line pixels on each side. One
manifest change; every parchment panel (menu, Tutorial & Controls, loading)
now lays its content inside the frame. The loading panel grows to its natural
444x152, where the frame reads as a frame again and the bar sits in it.

## Test

New `tests/loading_test` drives the real `scenes/loading.tscn` against a tiny
staged-build stand-in (`tests/loading_target`) for Main's `staged` / `progress`
/ `built` contract, and checks the laid-out label and bar rects sit inside the
frame insets hand-measured from the texture. It ran red on exactly those two
assertions with the old margins, green after the manifest change. The real
game path through the loading screen stays covered by `tests/menu_test`.

## Result

The guard ran red on exactly the label and bar assertions with the old
margins, green after the manifest change. Full suite green after it:
eighteen entries, no ERROR output. One commit on master, pushed to origin.
