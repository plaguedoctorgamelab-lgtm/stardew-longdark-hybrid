"""Bakes where forage can appear, and the possible places of the magical
ingredients. Called by tools/bake_region.py after the land is baked, so the
spots are fixed with the land: a save only chooses which of them are active.

Reads the forage table (data/content/forage.json) for ordinary forage, and the
spoiler table (data/content/spoiler_magic.json) for the magical ingredients'
places. Writes forage.json beside world.json:

  {"spots": {forage id: [[x, y], ...]},   # ground forage, fixed tiles
   "magic": {forage id: [[x, y], ...]}}   # possible places, about ten each

A spot is an open, reachable tile with nothing on it, on one of its row's
grounds, and beside what its row asks for. Only a share of the tiles that fit
are kept (bake_share), so the file stays small.
"""
import json
import os
import random
import zlib
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FORAGE = os.path.join(ROOT, "data", "content", "forage.json")
MAGIC = os.path.join(ROOT, "data", "content", "spoiler_magic.json")
TUNING = os.path.join(ROOT, "data", "tuning", "tuning.json")

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
NEAR_TRAIL = 3


def _rng(seed, name):
    return random.Random(zlib.crc32(("%d:%s" % (seed, name)).encode("utf-8")))


def reachable(R, start):
    """Every open tile a walker can reach from start."""
    seen = set()
    sx, sy = int(start[0]), int(start[1])
    if not R.inside(sx, sy) or R.solid[sy][sx]:
        return seen
    seen.add((sx, sy))
    q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        for dx, dy in N4:
            nx, ny = x + dx, y + dy
            if (nx, ny) in seen or not R.inside(nx, ny) or R.solid[ny][nx]:
                continue
            seen.add((nx, ny))
            q.append((nx, ny))
    return seen


def _fits(R, x, y, rule):
    if R.ground[y][x] not in rule["grounds"]:
        return False
    within = int(rule.get("within", 1))
    want_g = rule.get("beside_ground", [])
    want_o = rule.get("beside_object", [])
    if not want_g and not want_o:
        return True
    for dy in range(-within, within + 1):
        for dx in range(-within, within + 1):
            nx, ny = x + dx, y + dy
            if (dx or dy) and R.inside(nx, ny):
                if R.ground[ny][nx] in want_g or R.objects.get((nx, ny)) in want_o:
                    return True
    return False


def _open_tiles(R, reach):
    """Open, reachable tiles with nothing on them, in a fixed order."""
    covered = set()
    for (x, y) in R.objects:
        covered.add((x, y))
    return sorted(t for t in reach if t not in covered)


def bake(R, out_dir, seed, start):
    with open(FORAGE, encoding="utf-8") as f:
        forage = json.load(f)["rows"]
    with open(MAGIC, encoding="utf-8") as f:
        magic = json.load(f)["rows"]
    with open(TUNING, encoding="utf-8") as f:
        places = int(json.load(f)["magic"]["places_per_ingredient"])
    reach = reachable(R, start)
    tiles = _open_tiles(R, reach)
    # Structures' doors and their fronts stay clear.
    keep_clear = set()
    for s in R.structures:
        dx, dy = s["door"]
        for oy in range(0, 3):
            for ox in range(-1, 2):
                keep_clear.add((dx + ox, dy + oy))
    # Tiles within NEAR_TRAIL of a trail: casual walks pass these.
    near = set()
    for y in range(R.H):
        row = R.ground[y]
        for x in range(R.W):
            if row[x] == "trail":
                for dy in range(-NEAR_TRAIL, NEAR_TRAIL + 1):
                    for dx in range(-NEAR_TRAIL, NEAR_TRAIL + 1):
                        near.add((x + dx, y + dy))
    out = {"note": "Baked by tools/bake_forage.py (from tools/bake_world.py). Do not edit by hand. spots: where each ground forage can appear; a save activates a share of them each season. magic: the possible places of each magical ingredient (SPOILERS); a save uses some of them.",
           "spots": {}, "magic": {}}
    for row in forage:
        if row.get("source", "ground") != "ground" or row.get("magic"):
            continue
        rng = _rng(seed, "forage:" + row["id"])
        share = float(row["bake_share"])
        trail_share = float(row.get("near_trail_share", share))
        got = []
        for (x, y) in tiles:
            if (x, y) in keep_clear:
                continue
            roll = rng.random()
            if roll < (trail_share if (x, y) in near else share) and any(_fits(R, x, y, rule) for rule in row["where"]):
                got.append([x, y])
        out["spots"][row["id"]] = got
    for row in magic:
        rng = _rng(seed, "magic:" + row["id"])
        fits = [t for t in tiles if t not in keep_clear and _fits(R, t[0], t[1], row["rule"])]
        rng.shuffle(fits)
        gap = float(row["min_spacing"])
        chosen = []
        for (x, y) in fits:
            if all((x - a) ** 2 + (y - b) ** 2 >= gap * gap for a, b in chosen):
                chosen.append((x, y))
                if len(chosen) >= places:
                    break
        if len(chosen) < places:
            R.problems.append("magic %s: only %d places fit (want %d)" % (row["id"], len(chosen), places))
        out["magic"][row["id"]] = [list(t) for t in sorted(chosen)]
    with open(os.path.join(out_dir, "forage.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, separators=(",", ":"), sort_keys=True)
        f.write("\n")
    return out
