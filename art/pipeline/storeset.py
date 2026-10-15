#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow", "numpy"]
# ///
"""The store set: a title lettering keyed to a transparent logo, then every store asset composited by script from
the key art and the logo, so the lettering stays crisp and every size is made again from one command. Run from the
repo root.

storeset.py key --out LOGO.png LETTERING.png [--box x0,y0,x1,y1]
    the flat background colour, sampled at the corners, keyed out to alpha and unmixed from the edges
storeset.py compose --wide ART.png --tall TALL.png --hero HERO.png --logo LOGO.png --out DIR
    every asset of ASSETS at its exact pixel size, plus sheet.jpg with all of them
storeset.py loading --out DIR IMAGE...
    the game's loading screens, loading.jpg, loading.2.jpg and on, one per image at LOADING as JPEG at quality 90:
    a 16:9 image is cropped to fill, a wider one fits the width on the colour of its corners"""

import argparse
import datetime as dt
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

# name: (width, height, source, crop focus x, crop focus y, logo centre x, logo centre y, logo width as a fraction).
# source is wide (the 16:9 key art), tall (the 2:3 repaint) or hero (the 21:9 repaint). Logo None means no text.
ASSETS = {
    "steam_header_capsule": (920, 430, "hero", 0.5, 0.5, 0.30, 0.15, 0.46),
    "steam_small_capsule": (462, 174, "wide", 0.5, 0.30, 0.50, 0.50, 0.90),
    "steam_main_capsule": (1232, 706, "wide", 0.5, 0.5, 0.34, 0.13, 0.50),
    "steam_vertical_capsule": (748, 896, "tall", 0.5, 0.50, 0.50, 0.15, 0.86),
    "steam_page_background": (1438, 810, "wide", 0.5, 0.5, None, None, None),
    "steam_library_capsule": (600, 900, "tall", 0.5, 0.5, 0.50, 0.14, 0.88),
    "steam_library_header": (920, 430, "hero", 0.5, 0.5, 0.30, 0.15, 0.46),
    "steam_library_hero": (3840, 1240, "hero", 0.5, 0.49, None, None, None),
    "steam_community_icon": (184, 184, "icon", 0, 0, None, None, None),
    "icon_512": (512, 512, "icon", 0, 0, None, None, None),
    "itch_cover": (630, 500, "tall", 0.5, 0.47, 0.37, 0.15, 0.66),
    "splash_1920x1080": (1920, 1080, "wide", 0.5, 0.5, 0.34, 0.13, 0.50),
}
LOADING = (1920, 1080)
ICON_BOX = (0.105, 0.30, 0.495, 1.0)  # the near castle with its firing cannon and its smoke, in fractions of the wide art


def write_sidecar(dest, tool, inputs, params, outputs):
    meta = {"tool": f"storeset.py {tool}", "argv": sys.argv, "inputs": inputs, "params": params, "est_cost_usd": 0.0,
            "created": dt.datetime.now().isoformat(timespec="seconds"), "outputs": outputs}
    Path(dest).write_text(json.dumps(meta, indent=2))


def frac_box(im, box):
    x0, y0, x1, y1 = box
    return round(im.width * x0), round(im.height * y0), round(im.width * x1), round(im.height * y1)


def cmd_key(a):
    im = Image.open(a.lettering).convert("RGB")
    if a.box:
        im = im.crop(frac_box(im, [float(v) for v in a.box.split(",")]))
    px = np.asarray(im).astype(np.float32)
    k = max(4, min(im.size) // 40)
    corners = np.concatenate([px[:k, :k], px[:k, -k:], px[-k:, :k], px[-k:, -k:]]).reshape(-1, 3)
    bg = np.median(corners, axis=0)
    ch = int(np.argmax(bg))                                   # the key channel, green for a green screen
    others = [c for c in range(3) if c != ch]
    if bg[ch] - bg[others].max() < 30:
        sys.exit(f"{a.lettering}: the corners {bg.round().tolist()} are not a chroma background")
    spill = px[..., ch] - px[..., others].max(axis=-1)
    alpha = 1 - np.clip(spill / (bg[ch] - bg[others].max()), 0, 1)
    alpha[alpha < 0.08] = 0                                   # residual noise of the flat background
    fg = (px - (1 - alpha[..., None]) * bg) / np.maximum(alpha[..., None], 1e-3)
    fg[..., ch] = np.minimum(fg[..., ch], fg[..., others].max(axis=-1))   # despill
    fg[alpha == 0] = 0
    rgba = np.dstack([np.clip(fg, 0, 255), alpha * 255]).astype(np.uint8)
    out = Image.fromarray(rgba, "RGBA")
    bbox = out.getchannel("A").point(lambda v: 255 if v > 64 else 0).filter(ImageFilter.MedianFilter(7)).getbbox()
    if bbox is None:
        sys.exit(f"{a.lettering}: nothing is left after keying out the background")
    pad = round(0.02 * out.width)
    out = out.crop((max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(out.width, bbox[2] + pad), min(out.height, bbox[3] + pad)))
    out.save(a.out)
    write_sidecar(Path(a.out).with_suffix(".json"), "key", [a.lettering], {"box": a.box}, [Path(a.out).name])
    print(a.out, out.size)


def cover(im, w, h, fx, fy):
    s = max(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x = min(max(0, round(r.width * fx - w / 2)), r.width - w)
    y = min(max(0, round(r.height * fy - h / 2)), r.height - h)
    return r.crop((x, y, x + w, y + h))


def corner_colour(im):
    px = np.asarray(im.convert("RGB"))
    k = max(4, min(im.size) // 40)
    corners = np.concatenate([px[:k, :k], px[:k, -k:], px[-k:, :k], px[-k:, -k:]]).reshape(-1, 3)
    return tuple(int(v) for v in np.median(corners, axis=0))


def fit(im, w, h):
    s = min(w / im.width, h / im.height)
    r = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    canvas = Image.new("RGB", (w, h), corner_colour(im))
    canvas.paste(r, ((w - r.width) // 2, (h - r.height) // 2))
    return canvas


def place_logo(canvas, logo, cx, cy, wf):
    m = round(0.04 * canvas.height)                           # the logo never touches the frame edge
    lw = min(round(canvas.width * wf), canvas.width - 2 * m)
    lh = round(logo.height * lw / logo.width)
    if lh > canvas.height * 0.9:
        lh = round(canvas.height * 0.9)
        lw = round(logo.width * lh / logo.height)
    lg = logo.resize((lw, lh), Image.LANCZOS)
    x = min(max(round(canvas.width * cx - lw / 2), m), canvas.width - lw - m)
    y = min(max(round(canvas.height * cy - lh / 2), m), canvas.height - lh - m)
    canvas.alpha_composite(lg, (x, y))


def cmd_compose(a):
    src = {k: Image.open(getattr(a, k)).convert("RGBA") for k in ("wide", "tall", "hero")}
    logo = Image.open(a.logo).convert("RGBA")
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    made = []
    for name, (w, h, s, fx, fy, lx, ly, lw) in ASSETS.items():
        if s == "icon":
            base = src["wide"].crop(frac_box(src["wide"], ICON_BOX))
            side = min(base.size)
            base = base.crop(((base.width - side) // 2, base.height - side, (base.width + side) // 2, base.height))
            img = base.resize((w, h), Image.LANCZOS)
        else:
            img = cover(src[s], w, h, fx, fy)
        if name == "steam_page_background":
            img = ImageEnhance.Brightness(img.filter(ImageFilter.GaussianBlur(3))).enhance(0.8)
        if lx is not None:
            place_logo(img, logo, lx, ly, lw)
        p = out / f"{name}.png"
        img.convert("RGB").save(p)
        made.append(p)
    f = min(1280 / logo.width, 720 / logo.height)
    lib = logo.resize((round(logo.width * f), round(logo.height * f)), Image.LANCZOS)
    lib.save(out / "steam_library_logo.png")
    made.append(out / "steam_library_logo.png")
    icon = Image.open(out / "icon_512.png")
    icon.save(out / "icon.ico", sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
    sheet(made, out / "sheet.jpg")
    write_sidecar(out / "storeset.json", "compose", [a.wide, a.tall, a.hero, a.logo],
                  {"assets": {n: list(v) for n, v in ASSETS.items()}, "icon_box": ICON_BOX},
                  [p.name for p in made] + ["icon.ico", "sheet.jpg"])
    for p in made:
        print(p, Image.open(p).size)


def cmd_loading(a):
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    w, h = LOADING
    made = []
    for i, src in enumerate(a.images):
        im = Image.open(src).convert("RGB")
        img = fit(im, w, h) if im.width / im.height > w / h * 1.1 else cover(im, w, h, 0.5, 0.5)
        p = out / ("loading.jpg" if i == 0 else f"loading.{i + 1}.jpg")
        img.save(p, quality=90)
        made.append(p)
    sheet(made, out / "sheet.jpg")
    write_sidecar(out / "loading.json", "loading", a.images, {"size": list(LOADING)},
                  [p.name for p in made] + ["sheet.jpg"])
    for p in made:
        print(p, Image.open(p).size)


def sheet(paths, dest, cell=460):
    font = ImageFont.load_default(18)
    for f in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if Path(f).exists():
            font = ImageFont.truetype(f, 18)
    tiles = []
    for p in paths:
        im = Image.open(p).convert("RGBA")
        checker = Image.new("RGBA", im.size, (200, 200, 200, 255))
        checker.alpha_composite(im)
        im = checker.convert("RGB")
        im.thumbnail((cell, cell), Image.LANCZOS)
        tiles.append((f"{p.stem} {Image.open(p).size[0]}x{Image.open(p).size[1]}", im))
    cols, pad, lab = 4, 12, 26
    rows = -(-len(tiles) // cols)
    out = Image.new("RGB", (cols * (cell + pad) + pad, rows * (cell + lab + pad) + pad), (255, 255, 255))
    d = ImageDraw.Draw(out)
    for i, (label, im) in enumerate(tiles):
        x, y = pad + (i % cols) * (cell + pad), pad + (i // cols) * (cell + lab + pad)
        d.text((x, y), label, fill=(200, 0, 0), font=font)
        out.paste(im, (x, y + lab))
    out.save(dest, quality=90)


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    k = sp.add_parser("key")
    k.add_argument("--out", required=True)
    k.add_argument("--box")
    k.add_argument("lettering")
    k.set_defaults(f=cmd_key)
    c = sp.add_parser("compose")
    for n in ("wide", "tall", "hero", "logo", "out"):
        c.add_argument(f"--{n}", required=True)
    c.set_defaults(f=cmd_compose)
    lo = sp.add_parser("loading")
    lo.add_argument("--out", required=True)
    lo.add_argument("images", nargs="+")
    lo.set_defaults(f=cmd_loading)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
