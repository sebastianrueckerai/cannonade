# Session 60: the menu's mute icon

Sebastian, 2026-10-22: "When the main menu shows, can you give it a subtle icon in the lower right over
the BG image, to turn sound on and off completely?" The menu carries the Volume panel with its three
sliders, but nothing silences the game in one click, and nothing of it shows while the painting fills the
screen.
Roadmap: I94 (game). No paid generation: the icons are hand-drawn SVGs, so the session cap is 0 and no
provider runs.

## What ships

1. **A mute the Master bus carries** (I94). `Sound` gains `muted()` and `set_muted()`: the Master bus
   muted, which every slider's buses flow into, so one flag is the whole game silent — menu, battle, the
   pause menu's sliders keep writing their own buses and the mute stays. The flag lives in
   `user://volume.cfg` beside the volumes (`volume/muted`); one `_save_volumes()` writes every setting,
   so a slider move cannot drop the mute. `load_volumes()` reads and applies it, so a fresh menu opens as
   it was left. Why a flag and not a zeroed Master slider: the sliders keep their values, the icon
   restores in one click.
2. **The icon over the painting's bottom-right corner** (same item). A TextureButton named `Mute`,
   anchored bottom-right with a 24 px margin, drawn by hand as `assets/art/ui/sound_on.svg` and
   `sound_off.svg` (96 px glyphs shown at 44) in the theme's cream ink — the corner's olive of the board
   2 painting measures luminance 91, so cream reads where the panels' dark ink would sink. Subtle at
   rest: 55 % opacity, full cream on hover, the glyph swapping on the click. Without the art layer a text
   Button (`Sound` / `Muted`) stands in, the logo-fallback pattern. What it feeds: Sebastian's one-click
   silence from the menu, and the itch page's no-sound-in-public players.

## Checks

[menu_test.gd](../../tests/menu_test.gd) grows the icon block between the volume rounds: the icon found by
name, 24 px off the bottom-right edge, 44 px wide, idling below 75 % opacity; one real click (a real
InputEventMouseButton at its centre) mutes the Master bus and swaps in the muted glyph; volume.cfg holds
`volume/muted`; a master-slider drag in the Volume panel keeps the mute beside its own 0.25 — the guard on
the shared write; a fresh menu opens muted; a second click restores the sound. Break-checks, each watched
red then restored: the bus mute, the corner anchors (moved 200 px) and the idle opacity broken together
(15 FAILs, six of them the icon's own, the rest the shared save's collateral), then only the mute key
dropped from `_save_volumes` (4 FAILs, all persistence guards, while the one-click bus mute stayed ok).
Suite green, 23 PASS.

Visual: tools/shoot_ui before/after 1280x720 renders, 3x magnified corner crops at /tmp/corner-before.png
and /tmp/corner-after.png. Measured on the render: the glyph paints (162, 164, 125) — the predicted 55 %
cream over the corner's olive — in a 33x26 box centred in the 44 px footprint, and every sampled pixel
outside the corner window is identical to the before shot. Whether the glyph reads as a speaker at a
glance is Sebastian's eye, not measured.
