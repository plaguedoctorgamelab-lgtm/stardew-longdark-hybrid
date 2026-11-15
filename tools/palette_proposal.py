"""Makes the brighter palette proposal and a before-and-after sheet.

The current forest palette (art/palette.json) is lifted: mid-tones get
lighter, greens and warm colours a little richer, and the darkest colours
stay dark for outlines. A few bright accents are added. Nothing in the game
changes until the designer approves; the proposal is written to
docs/art/palette_bright.json and docs/art/palette_bright_preview.png.

Run: python tools/palette_proposal.py
"""
import colorsys
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OLD = os.path.join(ROOT, "art", "palette.json")
OUT_JSON = os.path.join(ROOT, "docs", "art", "palette_bright.json")
OUT_PNG = os.path.join(ROOT, "docs", "art", "palette_bright_preview.png")

ACCENTS = [
    (150, 214, 96),    # sunny grass green
    (196, 236, 126),   # new leaf
    (112, 186, 236),   # clear sky blue
    (255, 224, 102),   # buttercup yellow
    (240, 128, 150),   # wildflower pink
    (232, 182, 116),   # fresh-cut wood
    (206, 212, 218),   # pale stone
]


def brighten(c):
    r, g, b = (v / 255 for v in c)
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    if l < 0.16:          # outline darks stay dark
        return tuple(c)
    lift = 0.16 * (1 - abs(l - 0.5) * 1.3)
    l = min(0.96, l + max(0.05, lift))
    green = 0.17 <= h <= 0.45
    warm = h < 0.12 or h > 0.95
    s = min(1.0, s * (1.32 if green else 1.2 if warm else 1.1))
    r, g, b = colorsys.hls_to_rgb(h, l, s)
    return tuple(int(round(v * 255)) for v in (r, g, b))


def nearest(c, pal):
    return min(range(len(pal)), key=lambda i: sum((a - b) ** 2 for a, b in zip(c, pal[i])))


def main():
    old = [tuple(c) for c in json.load(open(OLD, encoding="utf-8"))["colors"]]
    new = [brighten(c) for c in old]
    full = new + ACCENTS
    with open(OUT_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump({"note": "Proposal: the forest palette brightened, with seven new accents. Not in use until the designer approves.",
                   "colors": [list(c) for c in full]}, f, indent=1)
        f.write("\n")

    # Preview: swatches before and after, then a few game pictures recoloured.
    S = 24
    samples = ["obj_tree_pine", "obj_tree_oak", "building_cabin_repaired", "building_tower_repaired", "obj_canoe", "item_axe", "obj_bush", "obj_cairn"]
    grounds = ["ground_grass", "ground_tall_grass", "ground_forest_floor", "ground_trail", "ground_shallows", "ground_bog"]
    pics = []
    for n in samples + grounds:
        p = os.path.join(ROOT, "art", "final", n + ".png")
        if os.path.exists(p):
            w, h, px = read_png(p)
            pics.append((n, w, h, px))
    scale = 3
    W = max(len(full) * S + 16, 16 + sum(w * scale + 8 for (_, w, _, _) in pics[:len(samples)]))
    pic_h = max(h for (_, _, h, _) in pics) * scale
    H = 16 + S + 8 + S + 24 + (pic_h + 16) * 2 + (16 * 4 + 12) * 2
    img = bytearray([30, 28, 34, 255] * (W * H))

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            i = (y * W + x) * 4
            img[i:i + 4] = bytes(c[:3]) + b"\xff"

    def rect(x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                put(xx, yy, c)

    y = 8
    for i, c in enumerate(old):
        rect(8 + i * S, y, S - 2, S - 2, c)
    y += S + 8
    for i, c in enumerate(full):
        rect(8 + i * S, y, S - 2, S - 2, c)
        if i >= len(new):
            rect(8 + i * S, y + S - 4, S - 2, 2, (255, 255, 255))
    y += S + 24

    def draw_row(row, y0, recolour):
        x = 8
        for (n, w, h, px) in row:
            for yy in range(h):
                for xx in range(w):
                    i = (yy * w + xx) * 4
                    r, g, b, a = px[i:i + 4]
                    if a < 128:
                        continue
                    c = (r, g, b)
                    if recolour:
                        c = new[nearest(c, old)]
                    rect(x + xx * scale, y0 + (pic_h - h * scale) + yy * scale, scale, scale, c)
            x += w * scale + 8

    objs = [p for p in pics if p[0] in samples]
    draw_row(objs, y, False)
    y += pic_h + 16
    draw_row(objs, y, True)
    y += pic_h + 16
    gr = [p for p in pics if p[0] in grounds]
    for k, recolour in enumerate((False, True)):
        x = 8
        for (n, w, h, px) in gr:
            for ty in range(2):
                for tx in range(2):
                    for yy in range(h):
                        for xx in range(w):
                            i = (yy * w + xx) * 4
                            c = tuple(px[i:i + 3])
                            if recolour:
                                c = new[nearest(c, old)]
                            rect(x + (tx * w + xx) * 2, y + (ty * h + yy) * 2, 2, 2, c)
            x += w * 4 + 8
        y += 16 * 4 + 12
    write_png(OUT_PNG, W, H, bytes(img))
    print("wrote", OUT_JSON, "and", OUT_PNG, "(%d colours)" % len(full))


if __name__ == "__main__":
    main()
