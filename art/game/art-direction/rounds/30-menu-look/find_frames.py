#!/usr/bin/env python3
# 9-slice margins from the deliberate dark ink line/band near each edge: per side, the
# darkest run in the outer 18% is the frame; margin = run end + safety, scaled to the
# height the candidate build resizes to (buttons 96, panels 512).
from PIL import Image

R = "game/art-direction/rounds/30-menu-look"
TARGET = {"a-panel": 512, "b-panel": 512, "a-button": 96, "b-button": 96}


def band(vals, span):
    edge = vals[: int(span * 0.18)]
    lo = min(edge)
    i = edge.index(lo)
    hi = max(edge)
    if hi - lo < 18:  # no pronounced line; say so
        return (None, None), lo, hi
    thr = lo + 0.35 * (hi - lo)
    a = i
    while a > 0 and edge[a - 1] < thr:
        a -= 1
    b = i
    while b < len(edge) - 1 and edge[b + 1] < thr:
        b += 1
    return (a, b), lo, hi


for n, tgt in TARGET.items():
    im = Image.open(f"{R}/gen2/{n}.png").convert("L")
    w, h = im.size
    px = im.load()
    mids = range(h // 4, 3 * h // 4), range(w // 4, 3 * w // 4)
    cols = [sum(px[x, y] for y in mids[0]) / len(mids[0]) for x in range(w)]
    rows = [sum(px[x, y] for x in mids[1]) / len(mids[1]) for y in range(h)]
    s = tgt / h
    out = []
    for side, vals, span in (("l", cols, w), ("r", cols[::-1], w), ("t", rows, h), ("b", rows[::-1], h)):
        (a, b), lo, hi = band(vals, span)
        out.append(f"{side}=" + ("flat" if a is None else f"{a}-{b}") + f"[{lo:.0f}|{hi:.0f}]"
                   + (f"->{round((b + 4) * s)}" if a is not None else ""))
    print(f"{n} {w}x{h} scale {s:.2f}: " + "  ".join(out))
