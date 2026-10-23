# game/assets

One folder per asset. `3d/<asset_id>/` follows the contract in [assets-3d.md](../../docs/process/assets-3d.md). [ui/](ui) and [marketing/](marketing) hold the approved 2D files with their sidecars. Nothing here is loaded by the game directly. The 3D models live in [3d/kit.blend](3d/kit.blend) and [pipeline/kit.py](../../pipeline/kit.py) exports its collections into the game's art layer.
