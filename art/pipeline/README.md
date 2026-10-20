# pipeline

The scripts that run the process. This page is the contract they follow.

## Run convention

- Python scripts run with `uv run --script pipeline/<name>.py`, dependencies declared inline in the file. No virtualenv to set up. Run from the repo root.
- Blender code runs inside the Blender that listens on port 9876. [asset.py](asset.py) sends [blender/driver.py](blender/driver.py) through `blx` with `ASSET_DIR`, `PIPELINE_DIR`, `ASSET` (the parsed asset.yaml) and `CONTRACT` (the parsed gameplay contract) prepended as Python literals. The modules in [blender/](blender) are imported inside Blender and each exposes `run(asset, asset_dir)`. Blender's Python has no YAML and no PIL, so parsing and image composition stay on the `uv` side.
- Every script reads `.env.tools` from the repo root and lets it override the shell.
- Every script that spends money adds the estimated cost to the sidecar and refuses to run past the cap. The cap is `SESSION_CAP_USD`, default 10. It counts the sidecars created since `SESSION_START`, an ISO time such as `2026-10-12T08:50`. Both live in the gitignored `.env.session` at the repo root, which a session writes once at its start; a value set in the shell wins. A worktree links `.env.tools` and `.env.session` from the main checkout. The inpainting models bill per megapixel of the input, so their estimate follows the image size. The free tools, `mask.py` and `storeset.py`, write a sidecar too, with the argv, the inputs and a cost of 0.

## Modules

| file | does | state |
|---|---|---|
| [img.py](img.py) | `gen` (text to image, or image edit with `--ref`), `critique`, `montage`, `sheet`, `cost` | works |
| [round.py](round.py) | runs a round folder: every direction times every frame times every model, then the contact sheet and the page. `refs` per direction or model attach reference images. An optional second argument names the config file, so a round with several sheets keeps one file per sheet | works |
| [teamcrop.py](teamcrop.py) | the 13 pixel test for a palette: a frame scaled so a tile is 24.7 px wide, the default view of the gameplay contract, a base in each team colour pasted in, the team colours on each ground colour of a palette, magnified 4 times | works |
| [px13.py](px13.py) | the 13 pixel test for any frames: each scaled so a tile is 24.7 px wide, a window cut, magnified 4 times, labelled in a grid. The tile width per frame is measured with a ruler crop, never taken from the wall | works |
| [titlepx.py](titlepx.py) | the title size test: each title study cropped to its letters, scaled to the Steam header capsule width 460, the small capsule 231 and 120 px, magnified twice without smoothing, one row per study | works |
| [storeset.py](storeset.py) | the store set: `loading` makes the game's loading screens from any anchors, `key` turns a lettering on a flat green screen into a transparent logo, `compose` makes every Steam, itch.io and game asset at its exact size from the wide key art, a tall and a wide repaint and the logo, plus a contact sheet | works |
| [mask.py](mask.py) | local fixes: `box` writes an inpainting mask, `paint` a rough paint-over (fill from the surrounding colour, line, rect, disc, copy of a box), `paste` puts a model's output back through a feathered mask so nothing outside it changes. `img.py gen --image --mask` sends them to an inpainting endpoint | works |
| [crop.py](crop.py) | magnified crops for a detail check, a box in frame fractions per image, one labelled cell per crop. A verdict on a cannon, a shot or a letter is made from a crop, never from the frame or the sheet | works |
| [swatches.py](swatches.py) | swatch sheet of a palette file, attached to recolour prompts and inlined in the bible | works |
| [asset.py](asset.py) | reads `asset.yaml`, runs the route and every Blender step, composes `previews/sheet.png`, writes `manifest.json`, exits 1 when a limit fails. A generative asset gets the report and the renders of the `final.glb` its cleanup wrote. `asset.py approve <asset>...` records Sebastian's pass | works |
| [blender/driver.py](blender/driver.py) | the script sent to Blender: fresh scene, then build (`build.py`, or the shared script named by `build:` in asset.yaml), normalise, materials, report, render, export. For a generative asset: import `final.glb`, report, render | works |
| [blender/geo.py](blender/geo.py) | `parts`, `bbox`, `tri_count` | works |
| [blender/normalise.py](blender/normalise.py) | drops objects not in `parts`, applies rotation and scale, merges doubles, recalculates normals, shifts the assembly to ground centre when `origin: ground_centre` (any other origin keeps the build's own), decimates over budget | works |
| [blender/materials.py](blender/materials.py) | one flat material per key of `materials` in asset.yaml: a key of palette.json's `world` or a hex, flat shaded. A `paint:` part may give `tint`, a hex that becomes the material's base colour factor over the painted texture, for a part the game recolours by one albedo write (session 26) | works |
| [blender/report.py](blender/report.py) | dims, tris, non-manifold count, parts, materials, limit check, `report.json`. Non-manifold edges fail only a procedural asset, a generated mesh keeps its UV seams | works |
| [blender/render.py](blender/render.py) | front, right, back, three-quarter at 512 px with matcap and cavity, plus the gameplay-camera view at 1280 by 720 | works |
| [blender/export.py](blender/export.py) | `final.glb` with Y up and `source.blend` | works |
| [mesh.py](mesh.py) | image-to-3D through Tripo and Meshy: one image or several views, a target face count, parts. Downloads the output at once, the sidecar records the credits charged and the time. Waits and retries when Tripo is busy | works. fal's TRELLIS.2 and Hunyuan are roadmap A3 |
| [meshsheet.py](meshsheet.py) | every generated model of an asset through Blender: the numbers, textured views, flat faces, loose parts in colour, the game's default view. One sheet with the inputs beside each run | works |
| [barrel.py](barrel.py) | splits a gun into `barrel` and `mount`: from the API's loose parts, by a cut through a fused mesh, or by joining a barrel and a mount made apart. Pivot on the trunnion axis from the trunnion caps, or `--pivot` by hand, an empty `projectile_spawn` at the muzzle, renders at the lowest and highest tilt, `--export` writes the `.glb` with the muzzle to the game's forward. `pieces` numbers every loose piece and shows each in red, `final` builds the asset from its hand-written `split.json` into `final.glb` and `source.blend`: a barrel levelled from its source `pitch`, or a `guns` part the game aims whole, and the gun scaled to stay inside its plate (D61) | works. The automatic split is only a start, `split.json` decides |
| [cleanup.py](cleanup.py) | the cleanup by hand of a generated model that does not move, from its `cleanup.json`: the turn that brings the front to the camera, the size, the origin, the texture at 512 px, and for the base the royal blue faces, and a flat roof named by `team_deck`, on a first material the game paints in the team colour. `--raw` renders the run from four sides first | works |
| [blender/inspect_glb.py](blender/inspect_glb.py), [blender/barrel.py](blender/barrel.py), [blender/cleanup.py](blender/cleanup.py) | the Blender halves of the scripts above. `barrel.py final` also builds the square plate under a gun from `split.json` | works |
| `critic_3d.py` | sends sheet, report and contract to the critic, returns the verdict JSON | roadmap A5 |
| [godot_sync.py](godot_sync.py) | copies approved `final.glb` files into the game art layer, writes its `manifest.json` with Godot axes and a minimal `.import` per model that keeps the texture inside the `.glb`. `GAME_REPO` points it at a worktree | works |

[tools/preview_glb.tscn](/home/womb/repos/grid-cannons/tools/preview_glb.tscn) in the game repo loads one `.glb` under the gameplay camera and saves a screenshot. Call it as the comment at the top of [tools/preview_glb.gd](/home/womb/repos/grid-cannons/tools/preview_glb.gd) shows.

## Sidecar JSON

Next to every generated file, same stem, `.json`:

```json
{
  "model": "fal-ai/flux-pro/kontext",
  "prompt": "...",
  "refs": ["../../art-direction/anchors/world_style.png"],
  "params": {"seed": 1234, "size": "1024x1024"},
  "est_cost_usd": 0.04,
  "created": "2026-10-11T15:02:00",
  "outputs": ["frame-1.png"]
}
```

## Asset manifest

`manifest.json` in every asset folder, written by [asset.py](asset.py):

```json
{
  "asset_id": "cannon_basic",
  "route": "procedural",
  "inputs": {"asset_yaml_sha": "...", "build_py_sha": "...", "refs": ["refs/front.png"]},
  "steps": [{"name": "normalise", "ok": true, "elapsed_s": 3.1}],
  "report": "report.json",
  "critic": {"model": "...", "verdict": "pass", "corrections": []},
  "approved_by": "Sebastian",
  "approved": "2026-10-18",
  "cost_usd": 0.0
}
```

`cost_usd` is the sum of the sidecars in the asset's folders. It is not named `est_cost_usd`, because the spending cap adds every JSON with that key.

