"""Places the facility pads: the set places where a large facility can be built.

Each request names a target spot. The pad goes on the nearest open, level
ground that fits its footprint: no solid tile, no object, open ground (water
for a dock's far end), never on trail, and within the tuned distance of
trail or of the route the trail will most likely follow. The result is
written to data/content/pads.json, and the pads that belong to places the
designer has not been told of to data/content/spoiler_pads.json.

The requests are kept in tools/pad_requests.json (ring one) and in
docs/spoilers/pad_requests.json when present (the rest). The spoiler file is
git-ignored; its output table is kept, as with the other spoiler tables.
Run: python tools/place_pads.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
CONTENT = os.path.join(ROOT, "data", "content")
OPEN = {"grass", "tall_grass", "forest_floor"}


def load_world():
    meta = json.load(open(os.path.join(WORLD, "world.json"), encoding="utf-8"))
    cs = meta["chunk_size"]
    codes = meta["ground_codes"]
    ground, solid, objects = {}, set(), {}
    for f in os.listdir(os.path.join(WORLD, "chunks")):
        _, cx, cy = f[:-5].split("_")
        cx, cy = int(cx), int(cy)
        c = json.load(open(os.path.join(WORLD, "chunks", f), encoding="utf-8"))
        for ly, row in enumerate(c["ground"]):
            for lx, ch in enumerate(row):
                ground[(cx * cs + lx, cy * cs + ly)] = codes[ch]
        for ly, row in enumerate(c["solid"]):
            for lx, ch in enumerate(row):
                if ch == "1":
                    solid.add((cx * cs + lx, cy * cs + ly))
        types = meta["object_types"]
        for o in c["objects"]:
            w, h = types.get(o[2], {}).get("size", [1, 1])
            for dy in range(h):
                for dx in range(w):
                    objects[(cx * cs + o[0] + dx, cy * cs + o[1] + dy)] = o[2]
    # Forage grows on open ground: a pad never covers a forage spot.
    forage = json.load(open(os.path.join(WORLD, "forage.json"), encoding="utf-8"))
    for spots in forage["spots"].values():
        for x, y in spots:
            objects[(x, y)] = "forage"
    return meta, ground, solid, objects


def line_tiles(meta, route_names):
    out = set()
    for name in route_names:
        pts = meta["routes"][name]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for i in range(n + 1):
                out.add((int(x0 + (x1 - x0) * i / n), int(y0 + (y1 - y0) * i / n)))
    return out


def place(req, meta, ground, solid, objects, taken, trail_near, max_off):
    tx, ty = req["near"]
    w, h = req["size"]
    water = req.get("water", False)
    best = None
    for r in range(0, req.get("search", 14) + 1):
        for y in range(ty - r, ty + r + 1):
            for x in range(tx - r, tx + r + 1):
                if max(abs(x - tx), abs(y - ty)) != r:
                    continue
                tiles = [(x + dx, y + dy) for dy in range(h) for dx in range(w)]
                ok = True
                wet = 0
                for t in tiles:
                    g = ground.get(t, "rock")
                    if t in taken or t in objects or g == "trail" or g == "boards":
                        ok = False
                        break
                    if water:
                        if g in ("shallows", "deep_water"):
                            wet += 1
                        elif g not in OPEN or t in solid:
                            ok = False
                            break
                    elif t in solid or g not in OPEN:
                        ok = False
                        break
                if not ok:
                    continue
                if water:
                    # A dock: open ground at the land end, water for the rest.
                    land = [(x + dx, y + h - 1) for dx in range(w)]
                    if wet < w * (h - 1) or any(ground.get(t) not in OPEN for t in land):
                        continue
                    if req.get("reach_deep") and not any(ground.get((x + dx, y - 1)) == "deep_water" for dx in range(w)):
                        continue
                # Near the trail, or the line the trail will most likely take.
                near = any((t[0] + dx, t[1] + dy) in trail_near for t in tiles for dx in range(-max_off, max_off + 1) for dy in range(-max_off, max_off + 1))
                if not near:
                    continue
                best = (x, y)
                break
            if best:
                break
        if best:
            break
    if not best:
        raise SystemExit("no room for pad %s near %s" % (req["id"], req["near"]))
    for dy in range(-1, h + 1):
        for dx in range(-1, w + 1):
            taken.add((best[0] + dx, best[1] + dy))
    row = {"id": req["id"], "site": req["site"], "facility": req["facility"], "pos": list(best), "size": [w, h]}
    for k in ("built", "lookout"):
        if k in req:
            row[k] = req[k]
    return row


def main():
    meta, ground, solid, objects = load_world()
    tuning = json.load(open(os.path.join(ROOT, "data", "tuning", "tuning.json"), encoding="utf-8"))
    max_off = int(tuning["placement"]["trail_distance_tiles"])
    trail = {t for t, g in ground.items() if g == "trail"}
    taken = set()
    out = {}
    for path, table in ((os.path.join(ROOT, "tools", "pad_requests.json"), "pads"), (os.path.join(ROOT, "docs", "spoilers", "pad_requests.json"), "spoiler_pads")):
        if not os.path.exists(path):
            print("no %s: %s left as it is" % (os.path.relpath(path, ROOT), table))
            continue
        reqs = json.load(open(path, encoding="utf-8"))["requests"]
        rows = []
        for req in reqs:
            if req.get("fixed"):
                w, h = req["size"]
                for dy in range(h):
                    for dx in range(w):
                        t = (req["near"][0] + dx, req["near"][1] + dy)
                        if t in objects and not req.get("lookout"):
                            raise SystemExit("fixed pad %s covers %s at %s" % (req["id"], objects[t], t))
                row = {"id": req["id"], "site": req["site"], "facility": req["facility"], "pos": req["near"], "size": req["size"]}
                for k in ("built", "lookout"):
                    if k in req:
                        row[k] = req[k]
                rows.append(row)
                continue
            # Near trail, the route the trail will likely take, or the site's
            # other pads, which the ranger's trail will join.
            near = trail | line_tiles(meta, req.get("routes", []))
            for r in rows:
                if r["site"] == req["site"]:
                    near |= {(r["pos"][0] + dx, r["pos"][1] + dy) for dx in range(r["size"][0]) for dy in range(r["size"][1])}
            rows.append(place(req, meta, ground, solid, objects, taken, near, max_off))
            print("  placed", rows[-1]["id"], rows[-1]["pos"])
        out[table] = rows
        with open(os.path.join(CONTENT, table + ".json"), "w", encoding="utf-8") as f:
            json.dump({"rows": rows}, f, indent=1)
            f.write("\n")
        print("%s: %d pads" % (table, len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
