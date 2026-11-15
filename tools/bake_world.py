"""Bakes the outdoor world into chunks from the layout files and fixed seeds.

The land is never made while the game runs. This tool builds it once; the
chunks are stored in the repository. Baking twice gives the same bytes.

Ring one (the phase one test area) is baked here exactly as first built, then
tools/bake_region.py places it in the full forest with the rings around it.

Run: python tools/bake_world.py [--out DIR] [--quiet]
"""
import argparse
import json
import math
import os
import random
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUT = os.path.join(ROOT, "data", "world", "layout.json")
STRUCTURES = os.path.join(ROOT, "data", "content", "structures.json")
DEFAULT_OUT = os.path.join(ROOT, "data", "world")

GROUND_CODES = {
    "trail": "t",
    "grass": "g",
    "forest_floor": "f",
    "tall_grass": "T",
    "shallows": "s",
    "deep_water": "w",
    "rock": "r",
}
SOLID_GROUNDS = {"deep_water", "rock"}


class Noise:
    """Smooth value noise on a lattice, fixed by its seed."""

    def __init__(self, seed, scale):
        self.seed = seed
        self.scale = scale

    def _h(self, ix, iy):
        n = (ix * 374761393 + iy * 668265263 + self.seed * 2147483647) & 0xFFFFFFFF
        n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0

    def at(self, x, y):
        fx, fy = x / self.scale, y / self.scale
        ix, iy = math.floor(fx), math.floor(fy)
        tx, ty = fx - ix, fy - iy
        tx = tx * tx * (3 - 2 * tx)
        ty = ty * ty * (3 - 2 * ty)
        a = self._h(ix, iy)
        b = self._h(ix + 1, iy)
        c = self._h(ix, iy + 1)
        d = self._h(ix + 1, iy + 1)
        return (a + (b - a) * tx) * (1 - ty) + (c + (d - c) * tx) * ty


def polyline_length(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


def meander(a, b, amplitude, waves, side, samples=400):
    """Points from a to b, bent by a sine wave, straight near both ends."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    dist = math.hypot(dx, dy)
    ux, uy = dx / dist, dy / dist
    px, py = -uy, ux
    pts = []
    for i in range(samples + 1):
        t = i / samples
        env = min(1.0, t / 0.12, (1 - t) / 0.12)
        s = math.sin(math.pi * waves * t)
        if side != 0:
            s = abs(s) * side
        off = amplitude * s * env
        pts.append((ax + dx * t + px * off, ay + dy * t + py * off))
    return pts


def catmull_rom(points, per_tile=4):
    """A smooth curve through the given points."""
    pts = [tuple(p) for p in points]
    ext = [pts[0]] + pts + [pts[-1]]
    out = [pts[0]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        n = max(4, int(math.dist(p1, p2) * per_tile))
        for k in range(1, n + 1):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in (0, 1)))
    return out


def path_through(points, amplitude, side, wave_len):
    """A smooth path through the points, bent by a gentle wave along its length."""
    base = catmull_rom(points)
    if amplitude <= 0:
        return base
    total = polyline_length(base)
    out = []
    s = 0.0
    for i, p in enumerate(base):
        if i > 0:
            s += math.dist(base[i - 1], p)
        a = base[max(0, i - 1)]
        b = base[min(len(base) - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        d = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / d, dx / d
        u = s / total
        env = min(1.0, u / 0.08, (1 - u) / 0.08)
        w = math.sin(2 * math.pi * s / wave_len)
        if side != 0:
            w = abs(w) * side
        off = amplitude * w * env
        out.append((p[0] + nx * off, p[1] + ny * off))
    return out


def solve_path(points, target, side, wave_len):
    straight = polyline_length(catmull_rom(points))
    if target <= straight:
        return path_through(points, 0, 0, wave_len)
    lo, hi = 0.0, 40.0
    for _ in range(50):
        mid = (lo + hi) / 2
        if polyline_length(path_through(points, mid, side, wave_len)) < target:
            lo = mid
        else:
            hi = mid
    return path_through(points, (lo + hi) / 2, side, wave_len)


def resample(pts, step=1.0):
    """Evenly spaced points along a polyline."""
    out = [pts[0]]
    carry = 0.0
    for i in range(len(pts) - 1):
        p, q = pts[i], pts[i + 1]
        seg = math.dist(p, q)
        d = step - carry
        while d <= seg:
            t = d / seg
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
            d += step
        carry = seg - (d - step)
    if math.dist(out[-1], pts[-1]) > 1e-6:
        out.append(pts[-1])
    return out


def bake_ring_one(L, structures):
    """Ring one, the phase one test area, exactly as it was first built.

    Everything here is in ring one's own tile coordinates. The region bake
    places it into the larger world without changing a tile."""
    rng = random.Random(L["seed"])
    cs = L["chunk_size"]
    W = L["size_chunks"][0] * cs
    H = L["size_chunks"][1] * cs
    ground = [["grass"] * W for _ in range(H)]
    objects = {}  # (x, y) -> kind; origin tile of the object
    protected = [[False] * W for _ in range(H)]  # no objects placed here

    def inside(x, y):
        return 0 <= x < W and 0 <= y < H

    def disc_tiles(cx, cy, r):
        for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
            for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
                if inside(x, y) and (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    yield x, y

    # --- generated terrain ---------------------------------------------------
    edge_noise = Noise(L["seed"] + 1, 12)
    fe = L["forest_edge"]

    def forest_edge_x(y):
        return fe["x"] + (edge_noise.at(0, y) - 0.5) * 2 * fe["wobble"]

    tall_noise = Noise(L["seed"] + 2, 7)
    for y in range(H):
        ex = forest_edge_x(y)
        for x in range(W):
            if x + 0.5 < ex:
                ground[y][x] = "tall_grass" if tall_noise.at(x, y) < L["density"]["tall_grass_cover"] else "grass"
            else:
                ground[y][x] = "forest_floor"

    # --- hand-placed: stream and pool -----------------------------------------
    st = L["stream"]
    stream_pts = resample(st["points"], 0.5)
    stream_tiles = set()
    for (sx, sy) in stream_pts:
        for (x, y) in disc_tiles(sx, sy, st["shallow_radius"]):
            stream_tiles.add((x, y))
            if ground[y][x] != "deep_water":
                ground[y][x] = "shallows"
        for (x, y) in disc_tiles(sx, sy, st["deep_radius"]):
            ground[y][x] = "deep_water"
    pool = st["pool"]
    for (x, y) in disc_tiles(pool["center"][0], pool["center"][1], pool["shallow_radius"]):
        stream_tiles.add((x, y))
        if ground[y][x] != "deep_water":
            ground[y][x] = "shallows"
    for (x, y) in disc_tiles(pool["center"][0], pool["center"][1], pool["deep_radius"]):
        ground[y][x] = "deep_water"
    fx, fy = st["ford_center"]
    for (x, y) in disc_tiles(fx, fy, st["ford_radius"]):
        if (x, y) in stream_tiles:
            ground[y][x] = "shallows"

    # --- hand-placed: outlook rise ----------------------------------------------
    ol = L["outlook"]
    ocx, ocy = ol["center"]
    for (x, y) in disc_tiles(ocx, ocy, ol["rock_radius"]):
        ground[y][x] = "rock"
    for (x, y) in disc_tiles(ocx, ocy, ol["top_radius"]):
        ground[y][x] = "grass"
        protected[y][x] = True

    # --- hand-placed: clearings ----------------------------------------------
    stn = L["station"]
    sw, sh = structures[stn["id"]]["footprint"]
    scx, scy = stn["pos"][0] + sw / 2, stn["pos"][1] + sh / 2
    for (x, y) in disc_tiles(scx, scy, L["station_clearing_radius"]):
        if ground[y][x] == "tall_grass":
            ground[y][x] = "grass"
        protected[y][x] = True
    cab = L["cabin"]
    cw, ch = structures[cab["id"]]["footprint"]
    ccx, ccy = cab["pos"][0] + cw / 2, cab["pos"][1] + ch / 2
    for (x, y) in disc_tiles(ccx, ccy, L["cabin_clearing_radius"]):
        ground[y][x] = "grass"
        protected[y][x] = True

    # --- hand-placed: trail ----------------------------------------------------
    segments = {}
    seg_ends = {}
    for seg in L["trail_segments"]:
        a = seg["from"]
        if isinstance(a, str):
            a = seg_ends[a]
        b = seg["to"]
        if isinstance(b[0], str):
            b = [forest_edge_x(b[1]), b[1]]
        pts = solve_path([a] + seg.get("via", []) + [b], seg["length"], seg["side"], seg.get("wave_len", 30))
        pts = resample(pts, 0.5)
        segments[seg["id"]] = pts
        seg_ends[seg["id"]] = pts[-1]
    gate = L["gate"]
    gate_trail = resample([(gate["pos"][0] + 1.5, gate["pos"][1] + 1.0), tuple(gate["trail_to"])], 0.5)

    trail_tiles = set()
    for pts in list(segments.values()) + [gate_trail]:
        for (px, py) in pts:
            for (x, y) in disc_tiles(px, py, L["trail_radius"]):
                trail_tiles.add((x, y))
    stream_crossings = 0
    for (x, y) in sorted(trail_tiles):
        if ground[y][x] in ("deep_water", "shallows"):
            ground[y][x] = "shallows"
        else:
            ground[y][x] = "trail"
    for pts in segments.values():
        was = False
        for (px, py) in pts:
            now = ground[int(py)][int(px)] == "shallows"
            if now and not was:
                stream_crossings += 1
            was = now
    for (x, y) in trail_tiles:
        for (nx, ny) in disc_tiles(x + 0.5, y + 0.5, 2.2):
            protected[ny][nx] = True

    # --- shortcut corridor (kept clear so the shortcut can always be walked) --
    sc = L["shortcut"]
    shortcut = resample(meander(tuple(sc["from"]), tuple(sc["to"]), sc["amplitude"], sc["waves"], 0), 0.5)
    for (px, py) in shortcut:
        for (x, y) in disc_tiles(px, py, 1.0):
            protected[y][x] = True
            if ground[y][x] == "rock":
                ground[y][x] = "forest_floor"

    # --- border -------------------------------------------------------------
    rock_w = L["border"]["rock"]
    tree_w = L["border"]["trees"]
    for y in range(H):
        for x in range(W):
            d = min(x, y, W - 1 - x, H - 1 - y)
            if d < rock_w:
                ground[y][x] = "rock"
    gx, gy = gate["pos"]

    def place(x, y, kind):
        objects[(x, y)] = kind

    for y in range(H):
        for x in range(W):
            d = min(x, y, W - 1 - x, H - 1 - y)
            if rock_w <= d < rock_w + tree_w and not protected[y][x] and ground[y][x] not in ("trail", "shallows", "deep_water"):
                place(x, y, "tree_pine")
    # The gate stands in a gap in the west border.
    for yy in range(gy, gy + 2):
        for xx in range(0, rock_w):
            ground[yy][xx] = "rock"
        ground[yy][gx] = "trail"
    place(gx, gy, "gate")

    # --- scatter ------------------------------------------------------------
    dens = L["density"]
    thick = L["thick_forest"]
    tree_kinds = ["tree_pine", "tree_pine", "tree_fir", "tree_oak"]
    for y in range(rock_w, H - rock_w):
        for x in range(rock_w, W - rock_w):
            r = rng.random()
            k = rng.random()
            if protected[y][x] or (x, y) in objects:
                continue
            g = ground[y][x]
            if g in ("grass", "tall_grass"):
                if r < dens["meadow_bush"]:
                    place(x, y, "bush")
                elif r < dens["meadow_bush"] + dens["meadow_boulder"]:
                    place(x, y, "boulder")
            elif g == "forest_floor":
                p = dens["thick_tree"] if (x >= thick["min_x"] and y <= thick["max_y"]) else dens["forest_tree"]
                if r < p:
                    place(x, y, tree_kinds[int(k * len(tree_kinds))])
                elif r < p + dens["forest_boulder"]:
                    place(x, y, "boulder")

    # Fallen trunks to steer by along the shortcut.
    every = sc["trunk_every"]
    for i in range(every, len(shortcut) - every // 2, every * 2):
        px, py = shortcut[i]
        side = 1 if (i // (every * 2)) % 2 == 0 else -1
        tx, ty = int(px) - 1, int(py) + side * sc["trunk_offset"]
        for xx in range(tx, tx + 3):
            objects.pop((xx, ty), None)
        if all(inside(xx, ty) and ground[ty][xx] == "forest_floor" for xx in range(tx, tx + 3)):
            place(tx, ty, "fallen_trunk")

    # The dead tree that marks the fork, and the outlook post.
    dx_, dy_ = L["dead_tree"]["pos"]
    place(dx_, dy_, "tree_dead")
    if ground[dy_][dx_] == "trail":
        raise SystemExit("dead tree sits on the trail; move it in the layout")
    px_, py_ = ol["post"]
    place(px_, py_, "outlook_post")

    # --- solidity -------------------------------------------------------------
    otypes = L["object_types"]
    solid = [[g in SOLID_GROUNDS for g in row] for row in ground]
    for (x, y), kind in objects.items():
        w, h = otypes[kind]["size"]
        if otypes[kind]["solid"]:
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    if inside(xx, yy):
                        solid[yy][xx] = True
    placed_structures = []
    for s in (stn, cab):
        fw, fh = structures[s["id"]]["footprint"]
        door = structures[s["id"]]["door"]
        x0, y0 = s["pos"]
        for yy in range(y0, y0 + fh):
            for xx in range(x0, x0 + fw):
                solid[yy][xx] = True
                objects.pop((xx, yy), None)
        placed_structures.append({
            "id": s["id"],
            "pos": [x0, y0],
            "size": [fw, fh],
            "door": [x0 + door[0], y0 + door[1]],
        })

    # --- checks -------------------------------------------------------------
    spawns = L["spawns"]

    def reachable(start):
        sx, sy = int(start[0]), int(start[1])
        seen = {(sx, sy)}
        q = deque([(sx, sy)])
        while q:
            x, y = q.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if inside(nx, ny) and not solid[ny][nx] and (nx, ny) not in seen:
                    seen.add((nx, ny))
                    q.append((nx, ny))
        return seen

    from_station = reachable(spawns["station"])
    problems = []
    for name, p in spawns.items():
        if (int(p[0]), int(p[1])) not in from_station:
            problems.append("spawn %s cannot be reached from the station" % name)
    if stream_crossings != 1:
        problems.append("trail crosses the stream %d times, expected 1" % stream_crossings)
    for name, pts in segments.items():
        for (px, py) in pts:
            if solid[int(py)][int(px)]:
                problems.append("trail segment %s runs into a solid tile at %d,%d" % (name, int(px), int(py)))
                break

    # --- routes and metrics ---------------------------------------------------
    routes = {}
    route_lengths = {}
    for rname, seg_ids in L["routes"].items():
        pts = []
        for sid in seg_ids:
            pts.extend(segments[sid] if not pts else segments[sid][1:])
        coarse = resample(pts, 2.0)
        routes[rname] = [[round(x, 2), round(y, 2)] for (x, y) in coarse]
        route_lengths[rname] = round(polyline_length(pts), 1)

    return {
        "W": W, "H": H, "cs": cs,
        "ground": ground, "solid": solid, "objects": objects,
        "structures": placed_structures,
        "landmarks": {
            "test_cabin": [placed_structures[1]["door"][0] + 0.5, placed_structures[1]["door"][1] + 0.5],
            "scenic_outlook": [ol["center"][0], ol["center"][1]],
        },
        "outlook_center": list(ol["center"]),
        "gate": [gx, gy],
        "spawns": spawns,
        "segments": segments,
        "routes": routes,
        "route_lengths": route_lengths,
        "route_targets_minutes": L["route_targets_minutes"],
        "object_types": otypes,
        "problems": problems,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import bake_region
    problems = bake_region.bake(args.out, args.quiet)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
