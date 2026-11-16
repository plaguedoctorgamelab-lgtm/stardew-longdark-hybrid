"""Bakes the forest region: ring one placed whole, then the rings around it.

Called by tools/bake_world.py. Only chunks that hold something are written;
the rest of the region stays unbaked until its ring is built.
"""
import json
import os

import bake_world as bw

ROOT = bw.ROOT
REGION = os.path.join(ROOT, "data", "world", "region.json")


class Region:
    """The whole region's tiles, in region coordinates."""

    def __init__(self, w, h, cs):
        self.W, self.H, self.cs = w, h, cs
        self.ground = [["rock"] * w for _ in range(h)]
        self.solid = [[True] * w for _ in range(h)]
        self.objects = {}        # (x, y) -> kind
        self.baked = set()       # chunks that hold something
        self.structures = []
        self.landmarks = {}
        self.spawns = {}
        self.routes = {}
        self.route_lengths = {}
        self.route_targets = {}
        self.edits = []          # ring one tiles changed on purpose
        self.problems = []
        self.extra = {}

    def inside(self, x, y):
        return 0 <= x < self.W and 0 <= y < self.H

    def mark_baked_rect(self, x0, y0, x1, y1):
        """Marks every chunk touching the tile rectangle [x0, x1) x [y0, y1)."""
        cs = self.cs
        for cy in range(max(0, y0 // cs), min(self.H // cs, (y1 - 1) // cs + 1)):
            for cx in range(max(0, x0 // cs), min(self.W // cs, (x1 - 1) // cs + 1)):
                self.baked.add((cx, cy))


def _shift(p, ox, oy):
    return [round(p[0] + ox, 2), round(p[1] + oy, 2)]


def place_ring_one(R, r1, ox, oy):
    for y in range(r1["H"]):
        gr = r1["ground"][y]
        sr = r1["solid"][y]
        for x in range(r1["W"]):
            R.ground[y + oy][x + ox] = gr[x]
            R.solid[y + oy][x + ox] = sr[x]
    for (x, y), kind in r1["objects"].items():
        R.objects[(x + ox, y + oy)] = kind
    R.mark_baked_rect(ox, oy, ox + r1["W"], oy + r1["H"])
    for s in r1["structures"]:
        R.structures.append({
            "id": s["id"],
            "pos": [s["pos"][0] + ox, s["pos"][1] + oy],
            "size": list(s["size"]),
            "door": [s["door"][0] + ox, s["door"][1] + oy],
        })
    for k, v in r1["landmarks"].items():
        R.landmarks[k] = _shift(v, ox, oy)
    for k, v in r1["spawns"].items():
        R.spawns[k] = _shift(v, ox, oy)
    for k, pts in r1["routes"].items():
        R.routes[k] = [_shift(p, ox, oy) for p in pts]
    R.route_lengths.update(r1["route_lengths"])
    R.route_targets.update(r1["route_targets_minutes"])
    R.problems += r1["problems"]


def bake(out_dir, quiet=False):
    with open(bw.LAYOUT, encoding="utf-8") as f:
        L = json.load(f)
    with open(bw.STRUCTURES, encoding="utf-8") as f:
        structures = {r["id"]: r for r in json.load(f)["rows"]}
    with open(REGION, encoding="utf-8") as f:
        G = json.load(f)
    cs = L["chunk_size"]
    W = G["size_chunks"][0] * cs
    H = G["size_chunks"][1] * cs
    ox = G["ring_one_chunk_offset"][0] * cs
    oy = G["ring_one_chunk_offset"][1] * cs
    r1 = bw.bake_ring_one(L, structures)
    R = Region(W, H, cs)
    place_ring_one(R, r1, ox, oy)
    otypes = dict(r1["object_types"])
    if "ring_two" in G:
        import ring_two
        otypes.update(ring_two.bake(R, G, L, r1, structures, ox, oy))
    write(R, out_dir, L, otypes, ox, oy, r1)
    import bake_forage
    fo = bake_forage.bake(R, out_dir, L["seed"], R.spawns["station"])
    if not quiet:
        print("forage: %d ground spots, %d magic places" % (sum(len(v) for v in fo["spots"].values()), sum(len(v) for v in fo["magic"].values())))
        print("baked %dx%d tiles, %d of %d chunks hold something, %d objects" % (W, H, len(R.baked), (W // cs) * (H // cs), len(R.objects)))
        for k, v in R.route_lengths.items():
            print("  route %-12s %6.1f tiles" % (k, v))
        if R.edits:
            print("  ring one tiles changed on purpose: %d" % len(R.edits))
        for p in R.problems:
            print("  PROBLEM:", p)
    return R.problems


def write(R, out_dir, L, otypes, ox, oy, r1):
    cs = R.cs
    chunk_dir = os.path.join(out_dir, "chunks")
    os.makedirs(chunk_dir, exist_ok=True)
    by_chunk = {}
    for (x, y), kind in R.objects.items():
        by_chunk.setdefault((x // cs, y // cs), []).append([x % cs, y % cs, kind])
    written = set()
    for (cx, cy) in sorted(R.baked):
        g = []
        s = []
        for y in range(cy * cs, (cy + 1) * cs):
            g.append("".join(bw.GROUND_CODES[R.ground[y][x]] for x in range(cx * cs, (cx + 1) * cs)))
            s.append("".join("1" if R.solid[y][x] else "0" for x in range(cx * cs, (cx + 1) * cs)))
        objs = sorted(by_chunk.get((cx, cy), []))
        data = {"cx": cx, "cy": cy, "ground": g, "solid": s, "objects": objs}
        name = "c_%d_%d.json" % (cx, cy)
        written.add(name)
        with open(os.path.join(chunk_dir, name), "w", encoding="utf-8", newline="\n") as f:
            json.dump(data, f, separators=(",", ":"), sort_keys=True)
            f.write("\n")
    # Chunks from an older bake that no longer exist are removed.
    for name in os.listdir(chunk_dir):
        if name.endswith(".json") and name not in written:
            os.remove(os.path.join(chunk_dir, name))
    # Baked chunks as runs along each row: [cy, first cx, last cx].
    runs = []
    for cy in range(R.H // cs):
        row = sorted(cx for (cx, y) in R.baked if y == cy)
        start = None
        prev = None
        for cx in row:
            if start is None:
                start = prev = cx
            elif cx == prev + 1:
                prev = cx
            else:
                runs.append([cy, start, prev])
                start = prev = cx
        if start is not None:
            runs.append([cy, start, prev])
    xs = [c[0] for c in R.baked]
    ys = [c[1] for c in R.baked]
    meta = {
        "note": "Baked by tools/bake_world.py from layout.json and region.json. Do not edit by hand.",
        "seed": L["seed"],
        "size": [R.W, R.H],
        "chunk_size": cs,
        "chunks": [R.W // cs, R.H // cs],
        "baked_runs": runs,
        "baked_bounds": [min(xs) * cs, min(ys) * cs, (max(xs) + 1) * cs, (max(ys) + 1) * cs],
        "ring_one_offset": [ox, oy],
        "ring_one_size": [r1["W"], r1["H"]],
        "ring_one_edits": [list(t) for t in sorted(R.edits)],
        "ground_codes": {v: k for k, v in bw.GROUND_CODES.items()},
        "object_types": otypes,
        "structures": R.structures,
        "landmarks": R.landmarks,
        "outlook_center": [r1["outlook_center"][0] + ox, r1["outlook_center"][1] + oy],
        "gate": [r1["gate"][0] + ox, r1["gate"][1] + oy],
        "spawns": R.spawns,
        "routes": R.routes,
        "route_lengths": R.route_lengths,
        "route_targets_minutes": R.route_targets,
    }
    meta.update(R.extra)
    with open(os.path.join(out_dir, "world.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(meta, f, indent=1, sort_keys=True)
        f.write("\n")
