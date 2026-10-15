# game/assets

One folder per asset. `3d/<asset_id>/` follows the contract in [assets-3d.md](../../docs/process/assets-3d.md). [ui/](ui) and [marketing/](marketing) hold the approved 2D files with their sidecars. Nothing here is loaded by the game directly. [pipeline/godot_sync.py](../../pipeline/godot_sync.py) copies approved files into the game's art layer.
