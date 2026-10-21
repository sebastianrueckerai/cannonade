# Session 43: volume sliders in the menu

Sebastian, 2026-10-21: "Add menu options to regulate sound and music individually with one
master volume."
Roadmap: K8, the volume sliders of its list. Game code only, no new art.

## The change

Three settings, one owner: the Sound autoload. Master rides the Master bus, sound rides SFX
and UI together (the battle clips and the menu clicks are one setting), music rides Music.
`Sound.set_volume` applies `linear_to_db` to the setting's buses (the slider's 0 is the -80 dB
floor, a mute that leaves the layout alone) and saves every setting to `user://volume.cfg`;
`Sound.load_volumes` runs at startup and on every menu build, and a missing or broken file
leaves everything at full.

The menu gains a Volume button (the web build too) beside Tutorial & Controls. Its panel is
built like the tutorial's, over the same dim that a click beside closes; the two panels share
`_open_panel` and `_close_overlay` now. A row a setting: label, an HSlider 0 to 100 whose
grabber jumps to a click (`scrollable` off), and the percent. A drag is heard at once, the
menu music rides the Music bus. [theme.tres](../../assets/art/ui/theme.tres) styles the
track as bordered parchment with an ink fill, so the slider wears the menu's palette.

## The checks

tests/menu_test.gd, real mouse drags on the sliders: the button beside the tutorial's, the
three sliders at full with the buses at 0 dB, a drag to a quarter of the track sets master
near 25 and the Master bus to the slider's exact level while SFX, UI and Music stay at full,
the sound slider moves SFX and UI together, the music slider Music alone, the percent label
follows, `user://volume.cfg` holds the three values, and a fresh menu reads the file back
into its sliders and the buses. Every new check watched red on the old code. Suite green.
