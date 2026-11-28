"""Draws the baked world as an overview picture, for checking a bake.

Only the built part of the region is drawn, one pixel per tile, with the
trail routes on top.

Run: python tools/preview_map.py [out.png] [--routes]
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
    "k": (90, 110, 80), "b": (150, 100, 60), "L": (20, 60, 90), "F": (110, 100, 60),
}
ROUTE_COLORS = [(255, 40, 200), (255, 230, 0), (0, 255, 255), (255, 120, 0)]


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    routes = "--routes" in sys.argv
    out = args[0] if args else os.path.join(ROOT, "map_preview.png")
    world_dir = os.path.join(ROOT, "data", "world")
    with open(os.path.join(world_dir, "world.json"), encoding="utf-8") as f:
        m = json.load(f)
    cs = m["chunk_size"]
    x0, y0, x1, y1 = m["baked_bounds"]
    W, H = x1 - x0, y1 - y0
    img = bytearray(W * H * 4)

    def put(x, y, c):
        x -= x0
        y -= y0
        if 0 <= x < W and 0 <= y < H:
            i = (y * W + x) * 4
            img[i:i + 4] = bytes(c) + b"\xff"

    for run in m["baked_runs"]:
        cy = run[0]
        for cx in range(run[1], run[2] + 1):
            with open(os.path.join(world_dir, "chunks", "c_%d_%d.json" % (cx, cy)), encoding="utf-8") as f:
                c = json.load(f)
            for ly, row in enumerate(c["ground"]):
                for lx, ch in enumerate(row):
                    put(cx * cs + lx, cy * cs + ly, COLORS[ch])
            for lx, ly, k in c["objects"]:
                col = (20, 50, 25) if k.startswith("tree") else (60, 40, 30)
                if k in ("survey_stake", "cairn", "bridge_post", "fallen_trunk"):
                    col = (255, 255, 255)
                put(cx * cs + lx, cy * cs + ly, col)
    for s in m["structures"]:
        for y in range(s["size"][1]):
            for x in range(s["size"][0]):
                put(s["pos"][0] + x, s["pos"][1] + y, (200, 40, 40))
    if routes:
        for i, name in enumerate(["pond", "tower", "bridge", "cabin"]):
            pts = m["routes"].get(name, [])
            for a, b in zip(pts, pts[1:]):
                n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
                for k in range(n + 1):
                    put(int(a[0] + (b[0] - a[0]) * k / n), int(a[1] + (b[1] - a[1]) * k / n), ROUTE_COLORS[i])
    write_png(out, W, H, img)
    print("wrote", out, W, "x", H)


if __name__ == "__main__":
    main()
