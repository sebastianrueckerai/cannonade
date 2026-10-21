# Session 43: the battle fires at any tile
Sebastian, 2026-10-21: "I should be able to shoot at any tile, even empty ones or my own
tiles. Its stupid, but it means I have to be precise. And I can have fon annihilating
trees and stuff"
Roadmap: I72. Game code only, no art.
## What was already true
The shot itself never cared: PlayerController hands the clicked tile to
Shooter.try_shoot (range and reload only), and TileImpactor.impact damages whatever
stands on the tile whichever player owns it, clears its decorations (I69) and splashes
on water and bare ground. A probe of the shipped code fired and landed on an empty
tile, a tree tile and an own wall.
## What read as a restriction
The hover: update_point_and_tile_selected kept running the placement preview in the
battle, where no piece is held, so every free tile lit red as unplaceable — exactly the
tiles he wanted to shoot. The preview now runs only outside the battle phase
(`game == null or game.phase != game.Phase.BATTLE`); the battle shows the aim arc and
the tile marker, nothing else. aimPoint, buildableTileSelected and the drop on the void
are unchanged, and the build phases preview exactly as before.
## The checks
tests/human.gd, real mouse, seed 7, battle phase: a click on a tree tile (two leaf
trees grown by the walls_test decorator) fires a shell that crumbles both; a click on
bare ground fires and the tile stays bare; a click on an own wall fires and the wall
falls to it (10 damage meets 10 health); and the battle hover lights no tile. Each
watched red on the old code: try_shoot forced to refuse tiles without an enemy
structure turned the three firing checks red, the preview gate removed turned the
hover check red. Suite green.
