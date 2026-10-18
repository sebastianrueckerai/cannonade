#!/usr/bin/env python3
# Gen-2 compare boards: numbered vertical stack at 1280, side-by-side row at 390.
from glob import glob
from PIL import Image, ImageDraw, ImageFont

R = "art/game/art-direction/rounds/30-menu-look"
S = f"{R}/shots"
font = ImageFont.truetype(glob(f"{R}/fonts/signika/*.ttf")[0], 30)


def label(im, n):
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 96, 44], fill=(24, 20, 18))
    d.text((12, 6), str(n), fill=(251, 239, 217), font=font)
    return im


W = 840
rows = [label(Image.open(f"{S}/{d}-1280.png").convert("RGB").resize(
    (W, round(720 * W / 1280)), Image.LANCZOS), i + 1) for i, d in enumerate("abc")]
b = Image.new("RGB", (W, sum(r.height for r in rows) + 16), (24, 20, 18))
y = 0
for r in rows:
    b.paste(r, (0, y)); y += r.height + 8
b.save(f"{S}/compare-v2-1280.png")
print("1280 board", b.size)

w390 = [label(Image.open(f"{S}/{d}-390.png").convert("RGB"), i + 1) for i, d in enumerate("abc")]
b = Image.new("RGB", (390 * 3 + 32, 760), (24, 20, 18))
for i, im in enumerate(w390):
    b.paste(im, (i * (390 + 16), 4))
b.save(f"{S}/compare-v2-390.png")
print("390 board", b.size)
