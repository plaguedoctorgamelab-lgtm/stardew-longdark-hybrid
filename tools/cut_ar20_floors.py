"""Cuts Mark's Art Request 20 floor sheet into four 16 x 16 tiles.

The sheet (art/raw/raw_ar20_floors.png) holds four large floor tiles on
black: the park's plank floor, then the shops' warm boards and its two
variants. Their grain is only a few shades darker than the wood, and the
seams between boards are thin dark lines, so a plain shrink would lose both.
This tool finds the seams on the big tile and draws each one as a single
pixel line at game size; every other pixel is the wood, or the grain where
most of its block is grain. The colours are the tile's own.

Writes art/raw/raw_ar20_floors_16.png, a 64 x 16 strip that the art
manifest cuts pixel for pixel. The raw sheet is never touched.

Run: python tools/cut_ar20_floors.py
"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "raw", "raw_ar20_floors.png")
OUT = os.path.join(ROOT, "art", "raw", "raw_ar20_floors_16.png")

T = 16
# Each tile's box on the sheet [x0, y0, x1, y1], inside its black border,
# in the strip's order: plank floor, warm boards, alt 1, alt 2.
BOXES = [(75, 70, 597, 583), (667, 70, 1189, 583), (75, 656, 597, 1169), (667, 656, 1189, 1168)]
SEAM_DARK = 14     # darker than the wood by this (sum of channels / 3) is seam
GRAIN_DARK = 5     # darker than the wood by this is grain
LINE_SHARE = 0.55  # a row or column this much seam is a seam line
GRAIN_SHARE = 0.6  # a block this much grain is drawn as grain
KNOT_SHARE = 0.25  # a block this much seam, away from the lines, is a knot


def lum(p):
    return (p[0] + p[1] + p[2]) / 3.0


def runs(flags):
    out, start = [], None
    for i, f in enumerate(flags + [False]):
        if f and start is None:
            start = i
        elif not f and start is not None:
            out.append((start, i))
            start = None
    return out


def cut(get, box):
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    px = [[get(x0 + x, y0 + y) for x in range(w)] for y in range(h)]
    wood = Counter(tuple(v >> 2 << 2 for v in p) for row in px for p in row).most_common(1)[0][0]
    wl = lum(wood)
    seam = [[lum(p) < wl - SEAM_DARK for p in row] for row in px]
    grain = [[wl - SEAM_DARK <= lum(p) < wl - GRAIN_DARK for p in row] for row in px]
    pick = lambda mask: Counter(tuple(v >> 2 << 2 for v in px[y][x]) for y in range(h) for x in range(w) if mask[y][x]).most_common(1)
    seam_c = (pick(seam) or [((wood[0] - 30, wood[1] - 28, wood[2] - 22), 0)])[0][0]
    grain_c = (pick(grain) or [(wood, 0)])[0][0]
    sx, sy = w / T, h / T
    out = [[None] * T for _ in range(T)]
    # Board rows: horizontal seam lines across the whole tile.
    hl = runs([sum(seam[y]) > LINE_SHARE * w for y in range(h)])
    rows = sorted({min(T - 1, int(((a + b) / 2) / sy)) for a, b in hl})
    # Pixels on a seam line are drawn by the line, so they are not counted
    # again as a knot or grain in the blocks around it.
    on_line = [[False] * w for _ in range(h)]
    for a, b in hl:
        for y in range(max(0, a - 2), min(h, b + 2)):
            on_line[y] = [True] * w
    # A line on the last row and one on the first would double up when the
    # tiles meet: keep the first.
    if 0 in rows and T - 1 in rows:
        rows.remove(T - 1)
    for ty in rows:
        for tx in range(T):
            out[ty][tx] = seam_c
    # Board ends: vertical seams within each band between the lines.
    edges = [0] + [b for _, b in hl] + [h]
    tops = [0] + [a for a, _ in hl] + [h]
    bands = []
    for i in range(len(hl) + 1):
        a, b = edges[i], tops[i + 1]
        if b - a > sy:
            bands.append((a, b))
    for a, b in bands:
        cols = runs([sum(seam[y][x] for y in range(a, b)) > LINE_SHARE * (b - a) for x in range(w)])
        ta, tb = int(a / sy), min(T, int((b - 1) / sy) + 1)
        for c0, c1 in cols:
            tx = min(T - 1, int(((c0 + c1) / 2) / sx))
            for ty in range(ta, tb):
                if out[ty][tx] is None:
                    out[ty][tx] = seam_c
            for y in range(a, b):
                for x in range(max(0, c0 - 2), min(w, c1 + 2)):
                    on_line[y][x] = True
    # The rest: wood, grain, or a knot.
    for ty in range(T):
        for tx in range(T):
            if out[ty][tx] is not None:
                continue
            ys = range(int(ty * sy), int((ty + 1) * sy))
            xs = range(int(tx * sx), int((tx + 1) * sx))
            n = max(1, sum(not on_line[y][x] for y in ys for x in xs))
            s = sum(seam[y][x] and not on_line[y][x] for y in ys for x in xs) / n
            g = sum(grain[y][x] and not on_line[y][x] for y in ys for x in xs) / n
            out[ty][tx] = seam_c if s >= KNOT_SHARE else grain_c if g >= GRAIN_SHARE else wood
    return out, rows, wood, grain_c, seam_c


def main():
    w, h, px = read_png(SRC)
    ch = len(px) // (w * h)

    def get(x, y):
        i = (y * w + x) * ch
        return tuple(px[i:i + 3])

    strip = bytearray(4 * T * len(BOXES) * T)
    for k, box in enumerate(BOXES):
        tile, rows, wood, grain_c, seam_c = cut(get, box)
        print("tile %d: seam rows %s, wood %s, grain %s, seam %s" % (k, rows, wood, grain_c, seam_c))
        for y in range(T):
            for x in range(T):
                i = (y * T * len(BOXES) + k * T + x) * 4
                strip[i:i + 4] = bytes(tile[y][x]) + b"\xff"
    write_png(OUT, T * len(BOXES), T, strip)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
