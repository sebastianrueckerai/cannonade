#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow", "numpy"]
# ///
"""Sheet 19 with the three guns at about 1 : 2 : 3 and the bare iron stack of sheet 8 in place of the crate.
Each object is cut from its sheet by colour (everything that is not grass or background), scaled about a point and
pasted. Ground it uncovers is copied from whole tiles further along the same row of the painted grid.
Run from the repo root: uv run --script game/art-direction/rounds/16-era-ladder/resize.py"""

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

D = Path(__file__).parent
BASE = D / "19-four-blocks--nanobanana.png"
OUT = D / "ladder-sizes.png"


def pitch(y):
    return 258 + (y - 184) * 0.1264  # tile width along an image row of sheet 19, from its grid lines at rows 184 and 888


def objects(a):
    r, g, b = (a[..., i].astype(int) for i in range(3))
    grass = (g > 1.25 * b) & (g >= 0.92 * r)
    background = (r > 180) & (b > 130) & (r >= g)
    return ~grass & ~background


def fill_holes(m):
    im = Image.fromarray(np.pad(m, 1).astype(np.uint8) * 255).copy()
    ImageDraw.floodfill(im, (0, 0), 128)
    return (np.asarray(im) != 128)[1:-1, 1:-1]


def cut(a, box):
    x0, y0, x1, y1 = box
    m = np.zeros(a.shape[:2], bool)
    m[y0:y1, x0:x1] = objects(a[y0:y1, x0:x1])
    im = Image.fromarray(m.astype(np.uint8) * 255)
    for f in (ImageFilter.MinFilter(11), ImageFilter.MaxFilter(11), ImageFilter.MaxFilter(5), ImageFilter.MinFilter(5)):
        im = im.filter(f)
    m = np.asarray(im) > 127
    m[:y0], m[y1:], m[:, :x0], m[:, x1:] = False, False, False, False
    return fill_holes(m)


def warp(im, sx, sy, c, t, size, resample):
    return im.transform(size, Image.AFFINE, (1 / sx, 0, c[0] - t[0] / sx, 0, 1 / sy, c[1] - t[1] / sy), resample=resample)


def main():
    src = {"19": Image.open(BASE).convert("RGB"), "8": Image.open(D / "8-from-5-fix--nanobanana.png").convert("RGB")}
    orig = np.asarray(src["19"])
    H, W = orig.shape[:2]
    occupied = np.asarray(Image.fromarray(objects(orig).astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(21))) > 127
    lum = orig.astype(float).mean(axis=2)
    dark = Image.fromarray(((lum < 0.72 * np.median(lum[~occupied])) & ~occupied).astype(np.uint8) * 255)
    shadow = np.asarray(dark.filter(ImageFilter.MinFilter(15)).filter(ImageFilter.MaxFilter(31))) > 127
    clean = ~occupied & ~shadow

    out = orig.copy()
    gun1, gun2, gun3 = cut(orig, (150, 380, 720, 800)), cut(orig, (720, 200, 1640, 880)), cut(orig, (1650, 40, 2752, 905))
    crate, stack = cut(orig, (1600, 930, 1960, 1300)), cut(np.asarray(src["8"]), (1255, 985, 1512, 1345))

    def bbox(m):
        ys, xs = np.nonzero(m)
        return xs.min(), ys.min(), xs.max(), ys.max()

    def leftmost(m):
        x0 = bbox(m)[0]
        return x0, float(np.nonzero(m[:, x0])[0].mean())

    s_small, s_big = 0.86, 1.16
    ops = [("19", gun1, s_small, s_small, leftmost(gun1), leftmost(gun1)),
           ("19", gun2, s_small, s_small, leftmost(gun2), leftmost(gun2)),
           ("19", gun3, s_big, s_big, (bbox(gun3)[2], bbox(gun3)[1]), (bbox(gun3)[2], bbox(gun3)[1]))]
    cx0, _, cx1, cy1 = bbox(crate)
    sx0, _, sx1, sy1 = bbox(stack)
    sx = (cx1 - cx0) / (sx1 - sx0)
    ops.append(("8", stack, sx, 0.92, ((sx0 + sx1) / 2, sy1), ((cx0 + cx1) / 2, cy1)))
    olds = [gun1, gun2, gun3, crate]

    news = []
    for (key, m, sx_, sy_, c, t) in ops:
        mm = np.asarray(warp(Image.fromarray(m.astype(np.uint8) * 255), sx_, sy_, c, t, (W, H), Image.BILINEAR)) > 127
        news.append((np.asarray(warp(src[key], sx_, sy_, c, t, (W, H), Image.BICUBIC)), mm))
    covered = np.zeros((H, W), bool)
    for _, mm in news:
        covered |= mm
    uncover = np.zeros((H, W), bool)
    for m in olds:
        uncover |= np.asarray(Image.fromarray(m.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(7))) > 127
    uncover &= ~covered

    ys, xs = np.nonzero(uncover)
    todo = np.ones(ys.size, bool)
    for k in (1, -1, 2, -2, 3, -3, 4, -4, 5, -5):
        q = np.rint(xs + k * pitch(ys)).astype(int)
        ok = todo & (q >= 0) & (q < W)
        ok[ok] = clean[ys[ok], q[ok]]
        out[ys[ok], xs[ok]] = orig[ys[ok], q[ok]]
        todo &= ~ok
    misses = int(todo.sum())
    out[ys[todo], xs[todo]] = np.median(orig[clean], axis=0).astype(np.uint8)

    img = Image.fromarray(out)
    for rgb, mm in news:
        alpha = Image.fromarray(mm.astype(np.uint8) * 255).filter(ImageFilter.GaussianBlur(1.2))
        img.paste(Image.fromarray(rgb), (0, 0), alpha)
    img.save(OUT)
    sizes = {name: int(bbox(m)[2] - bbox(m)[0]) for name, m in zip(("gun1", "gun2", "gun3"), (gun1, gun2, gun3))}
    rec = {
        "made_by": "game/art-direction/rounds/16-era-ladder/resize.py",
        "inputs": [BASE.name, "8-from-5-fix--nanobanana.png"],
        "ops": [{"src": k, "scale": [round(a, 3), round(b, 3)], "from": [round(float(v), 1) for v in c], "to": [round(float(v), 1) for v in t]}
                for (k, _, a, b, c, t) in ops],
        "width_px_before": sizes,
        "uncovered_px": int(uncover.sum()),
        "uncovered_without_clean_source_px": misses,
        "est_cost_usd": 0.0,
    }
    OUT.with_suffix(".json").write_text(json.dumps(rec, indent=1))
    print(json.dumps(rec))


if __name__ == "__main__":
    main()
