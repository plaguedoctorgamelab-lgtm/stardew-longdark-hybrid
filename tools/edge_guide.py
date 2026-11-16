"""Draws the layout guide for a ground edge sheet (Art Request 05).

An edge sheet is 64 x 64: a 4 by 4 grid of 16 x 16 cells. Cell number m
(left to right, top to bottom, starting at 0) shows the ground creeping in
from the sides in m: 1 = top, 2 = right, 4 = bottom, 8 = left, added
together. Cell 0 is empty. Everything else in a cell is see-through.

The guide shows each cell 8 times bigger: green where the ground creeps in,
tan where the lower ground shows through, with the cell number in dots.

Run: python tools/edge_guide.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "art", "art_request_05_edge_guide.png")
K = 8
T = 16
GAP = 8
GREEN = (97, 187, 97)
TAN = (225, 189, 142)
INK = (26, 22, 32)
BG = (246, 224, 180)


def main():
    cell = T * K
    W = GAP + 4 * (cell + GAP)
    img = bytearray(bytes(BG) + b"\xff") * (W * W)

    def put(x, y, c):
        i = (y * W + x) * 4
        img[i:i + 4] = bytes(c) + b"\xff"

    for m in range(16):
        ox = GAP + (m % 4) * (cell + GAP)
        oy = GAP + (m // 4) * (cell + GAP)
        for y in range(cell):
            for x in range(cell):
                px, py = x // K, y // K
                depth = 99
                if m & 1:
                    depth = min(depth, py)
                if m & 2:
                    depth = min(depth, T - 1 - px)
                if m & 4:
                    depth = min(depth, T - 1 - py)
                if m & 8:
                    depth = min(depth, px)
                c = GREEN if depth < 4 else TAN
                if x % K == 0 or y % K == 0:
                    c = tuple(max(0, v - 18) for v in c)
                put(ox + x, oy + y, c)
        # The cell number as a row of dots: big dots are 4s, small dots 1s.
        for i in range(m // 4):
            for y in range(10):
                for x in range(10):
                    put(ox + cell // 2 - 30 + i * 16 + x, oy + cell // 2 - 5 + y, INK)
        for i in range(m % 4):
            for y in range(5):
                for x in range(5):
                    put(ox + cell // 2 - 30 + (m // 4) * 16 + i * 10 + x, oy + cell // 2 - 2 + y, INK)
    write_png(OUT, W, W, bytes(img))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
