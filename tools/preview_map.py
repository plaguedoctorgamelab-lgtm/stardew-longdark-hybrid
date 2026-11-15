"""Draws the baked world as a small overview picture, for checking a bake.

Run: python tools/preview_map.py [out.png]
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLORS = {
    "t": (210, 170, 110), "g": (100, 160, 70), "f": (70, 90, 50), "T": (150, 190, 80),
    "s": (110, 180, 220), "w": (30, 70, 130), "r": (120, 120, 120),
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "map_preview.png")
    world_dir = os.path.join(ROOT, "data", "world")
    with open(os.path.join(world_dir, "world.json"), encoding="utf-8") as f:
        m = json.load(f)
    W, H = m["size"]
    cs = m["chunk_size"]
    S = 2
    img = bytearray(W * H * S * S * 4)

    def put(x, y, c):
        for dy in range(S):
            for dx in range(S):
                i = ((y * S + dy) * W * S + x * S + dx) * 4
                img[i:i + 4] = bytes(c) + b"\xff"

    for cy in range(m["chunks"][1]):
        for cx in range(m["chunks"][0]):
            with open(os.path.join(world_dir, "chunks", "c_%d_%d.json" % (cx, cy)), encoding="utf-8") as f:
                c = json.load(f)
            for ly, row in enumerate(c["ground"]):
                for lx, ch in enumerate(row):
                    put(cx * cs + lx, cy * cs + ly, COLORS[ch])
            for lx, ly, k in c["objects"]:
                put(cx * cs + lx, cy * cs + ly, (20, 50, 25) if k.startswith("tree") else (60, 40, 30))
    for s in m["structures"]:
        for y in range(s["size"][1]):
            for x in range(s["size"][0]):
                put(s["pos"][0] + x, s["pos"][1] + y, (200, 40, 40))
    write_png(out, W * S, H * S, img)
    print("wrote", out)


if __name__ == "__main__":
    main()
