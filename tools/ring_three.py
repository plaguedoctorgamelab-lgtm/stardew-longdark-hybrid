"""Bakes ring three of the forest: the far bank of the Dusk River and Skull
Lake (Phase 6 Spec, sections 1 and 2).

Ring three is everything east of the river and the mire, which ring two
left as unreachable woods, out to the region's new east edge. The river's
east-running stretch carries on into Skull Lake, whose skull shape is two
ellipses (the cranium and the jaw) with three islands for the eyes and
the nose. A creek drains the jaw south to the park edge.

The only way across is the broken bridge, once mended. Ring three also
bakes what the seasons change (the fords that flood in the melt, the
summer ford, the winter ice crossing, the high trails that snow in) and
the old road's cart trail, for the game to switch by date.

Positions in region.json are plan coordinates: tiles east and north of the
park gate.
"""
import math
import random

import bake_world as bw
import ring_two as r2mod

OBJECT_TYPES = {
    "tree_birch": {"size": [1, 1], "sprite": "obj_tree_birch", "solid": True},
    "tree_hemlock": {"size": [1, 1], "sprite": "obj_tree_hemlock", "solid": True},
}
SOLID = {"deep_water", "rock", "lake"}


def disc(cx, cy, r):
    return r2mod.disc(cx, cy, r)


def bake(R, G, r1, ox, oy):
    C = G["ring_three"]
    rng = random.Random(C["seed"])
    gx = r1["gate"][0] + ox
    gy = r1["gate"][1] + oy

    def P(e, n):
        return (gx + e, gy - n)

    def E(x, y):
        return (x + 0.5 - gx, gy - (y + 0.5))

    cs = R.cs
    bx0, by0 = int(P(C["box"]["e"][0], 0)[0]), int(P(0, C["box"]["n"][1])[1])
    bx1, by1 = int(P(C["box"]["e"][1], 0)[0]), int(P(0, C["box"]["n"][0])[1])
    bx0, by0 = (bx0 // cs) * cs, (max(0, by0) // cs) * cs
    bx1, by1 = min(R.W, -(-bx1 // cs) * cs), min(R.H, -(-by1 // cs) * cs)
    r2x0, r2y0, r2x1, r2y1 = R.r2_box

    def in_r2(x, y):
        return r2x0 <= x < r2x1 and r2y0 <= y < r2y1

    def r3(x, y):
        """Ring three: ring two's far side, and the new land beyond ring two."""
        if not (bx0 <= x < bx1 and by0 <= y < by1):
            return False
        return (x, y) in R.r2_far or not in_r2(x, y)

    tiles = [(x, y) for y in range(by0, by1) for x in range(bx0, bx1) if r3(x, y)]
    ground = R.ground
    objects = R.objects
    protected = set()
    zone = {}
    for t in tiles:
        ground[t[1]][t[0]] = "forest_floor"
        objects.pop(t, None)

    # --- the river runs on east into the lake ------------------------------------------------
    rv = G["ring_two"]["river"]
    out_pts = bw.resample(bw.catmull_rom([P(e, n) for e, n in C["river_out"]]), 0.5)
    for (px, py) in out_pts:
        for t in disc(px, py, rv["shallow_radius"]):
            if r3(*t) and ground[t[1]][t[0]] != "deep_water":
                ground[t[1]][t[0]] = "shallows"
                zone[t] = "river"
    for (px, py) in out_pts:
        for t in disc(px, py, rv["deep_radius"]):
            if r3(*t):
                ground[t[1]][t[0]] = "deep_water"
                zone[t] = "river"

    # --- Skull Lake ----------------------------------------------------------------------------
    lk = C["lake"]
    lnoise = bw.Noise(C["seed"] + 1, 9)

    def in_ellipse(x, y, el, grow=0.0):
        cx, cy = P(*el["c"])
        u = ((x + 0.5 - cx) / (el["rx"] + grow)) ** 2 + ((y + 0.5 - cy) / (el["ry"] + grow)) ** 2
        return u <= 1.0 + (lnoise.at(x, y) - 0.5) * 0.06

    lake_tiles = set()
    shallow_tiles = set()
    parts = [lk["cranium"], lk["jaw"]]
    for t in tiles:
        x, y = t
        if any(in_ellipse(x, y, el) for el in parts):
            lake_tiles.add(t)
        elif any(in_ellipse(x, y, el, lk["shallow"]) for el in parts):
            shallow_tiles.add(t)
    islands = {}
    for name, el in lk["islands"].items():
        isl = {t for t in lake_tiles if in_ellipse(t[0], t[1], el)}
        rim = {t for t in lake_tiles if in_ellipse(t[0], t[1], el, 2) and t not in isl}
        islands[name] = isl
        lake_tiles -= isl
        lake_tiles -= rim
        shallow_tiles |= rim
    for t in lake_tiles:
        ground[t[1]][t[0]] = "lake"
        zone[t] = "lake"
    for t in shallow_tiles:
        if zone.get(t) != "river":
            ground[t[1]][t[0]] = "shallows"
            zone[t] = "shore"
    for name, isl in islands.items():
        for t in isl:
            ground[t[1]][t[0]] = "grass"
            zone[t] = "island"

    # --- the jaw creek: the lake's outflow, shallow all the way --------------------------------
    jc = C["jaw_creek"]
    creek_pts = bw.resample(bw.catmull_rom([P(e, n) for e, n in jc["points"]]), 0.5)
    creek_tiles = set()
    for (px, py) in creek_pts:
        for t in disc(px, py, jc["radius"]):
            if r3(*t) and zone.get(t) not in ("lake", "shore", "island"):
                ground[t[1]][t[0]] = "shallows"
                zone[t] = "creek"
                creek_tiles.add(t)

    # --- the far bank's trail: from the bridge to the landing and up into the north woods ----
    tr = C["trail"]
    trail_pts = bw.resample(bw.catmull_rom([P(e, n) for e, n in tr["points"]]), 0.5)
    trail_tiles = []
    for (px, py) in trail_pts:
        for t in disc(px, py, tr["radius"]):
            if r3(*t) and ground[t[1]][t[0]] not in ("deep_water", "lake", "shallows") and t not in trail_tiles:
                ground[t[1]][t[0]] = "trail"
                trail_tiles.append(t)
        for t in disc(px, py, tr["radius"] + 2):
            protected.add(t)
    # The high part, over the north woods' bald hill, snows in.
    high_from = int(tr["snows_in_from"] * len(trail_pts))
    high = set()
    for (px, py) in trail_pts[high_from:]:
        for t in disc(px, py, tr["radius"]):
            if ground[t[1]][t[0]] == "trail":
                high.add(t)
    hill = C["hill"]
    hx, hy = P(*hill["c"])
    for t in disc(hx, hy, hill["r"]):
        if r3(*t) and ground[t[1]][t[0]] == "forest_floor":
            ground[t[1]][t[0]] = "grass"
            protected.add(t)

    # --- Dusk River Landing ---------------------------------------------------------------------
    la = C["landing"]
    lx, ly = P(*la["boathouse"])
    for yy in range(int(ly) - 4, int(ly) + 3):
        for xx in range(int(lx) - 4, int(lx) + 5):
            if r3(xx, yy) and ground[yy][xx] == "forest_floor":
                ground[yy][xx] = "grass"
            protected.add((xx, yy))

    # --- trees -------------------------------------------------------------------------------------
    fo = C["forest"]
    wood_kinds = ["tree_fir", "tree_pine", "tree_fir", "tree_oak"]
    cx, cy = P(*lk["cranium"]["c"])
    for t in tiles:
        x, y = t
        if t in protected or t in objects:
            continue
        g = ground[y][x]
        if g not in ("forest_floor", "grass"):
            continue
        e, n = E(x, y)
        r = rng.random()
        k = rng.random()
        if zone.get(t) == "island":
            if r < fo["island_tree"]:
                objects[t] = "tree_pine" if k < 0.6 else "tree_birch"
            continue
        near_lake = math.hypot((x - cx) / (lk["cranium"]["rx"] + 50), (y - cy) / (lk["cranium"]["ry"] + 60)) < 1.0
        if n >= fo["hemlock_from_n"]:
            if r < fo["tree"]:
                objects[t] = "tree_hemlock" if k < 0.55 else wood_kinds[int(k * 4)]
        elif near_lake:
            if r < fo["shore_tree"]:
                objects[t] = "tree_birch" if k < 0.6 else wood_kinds[int(k * 4)]
        elif r < fo["tree"]:
            objects[t] = wood_kinds[int(k * 4)]
        elif r < fo["tree"] + fo["boulder"]:
            objects[t] = "boulder"

    # --- the mended bridge's far end, and the region's east and north edges ----------------------
    # The bridge's far half of the deck was baked by ring two; trees never
    # stand on it.
    br = G["ring_two"]["bridge"]
    bry = int(P(0, br["n"])[1])
    for e in range(br["deck"][0], br["deck"][1] + 6):
        x = int(P(e, 0)[0])
        for y in range(bry - 2, bry + 3):
            objects.pop((x, y), None)
            protected.add((x, y))
    edge = C["edge"]
    for t in tiles:
        x, y = t
        d = min(bx1 - 1 - x, y - by0, by1 - 1 - y)
        if d < edge["rock"]:
            ground[y][x] = "rock"
            objects.pop(t, None)
        elif d < edge["rock"] + edge["trees"] and ground[y][x] == "forest_floor":
            objects[t] = "tree_pine"

    # --- solidity ------------------------------------------------------------------------------
    otypes = dict(OBJECT_TYPES)
    for t in tiles:
        R.solid[t[1]][t[0]] = ground[t[1]][t[0]] in SOLID
    for t, kind in objects.items():
        if r3(*t) and kind in ("tree_birch", "tree_hemlock", "tree_fir", "tree_pine", "tree_oak", "boulder"):
            R.solid[t[1]][t[0]] = True
    R.mark_baked_rect(bx0, by0, bx1, by1)

    # --- places, spawns, seasons ---------------------------------------------------------------
    R.landmarks["dusk_river_landing"] = [round(lx, 2), round(ly, 2)]
    sp = P(*la["spawn"])
    R.spawns["landing"] = [round(sp[0], 2), round(sp[1], 2)]
    lc = C["logging_camp"]
    lcx, lcy = P(*lc["sawmill"])
    R.landmarks["logging_camp"] = [round(lcx, 2), round(lcy, 2)]
    sp = P(*lc["spawn"])
    R.spawns["logging_camp"] = [round(sp[0], 2), round(sp[1], 2)]
    # The camp's yard is cleared in ring two's woods.
    for yy in range(int(lcy) - 4, int(lcy) + 8):
        for xx in range(int(lcx) - 7, int(lcx) + 8):
            if R.objects.get((xx, yy)) in ("tree_pine", "tree_fir", "tree_oak", "boulder", "bush"):
                R.objects.pop((xx, yy))
            if ground[yy][xx] == "forest_floor":
                ground[yy][xx] = "grass"
            if ground[yy][xx] not in bw.SOLID_GROUNDS:
                R.solid[yy][xx] = False
    # A short spur of trail from the camp down to the old road, the nearest
    # road tile being where the broken cart stands (on cart trail).
    road = sorted((t for t in getattr(R, "road_tiles", set()) if not R.solid[t[1]][t[0]] and t not in R.objects
                   and all(not R.solid[t[1] + dy][t[0] + dx] for dx in (-1, 0, 1) for dy in (-1, 0, 1))), key=lambda t: (t[0] + 0.5 - sp[0]) ** 2 + (t[1] + 0.5 - sp[1]) ** 2)
    cart_tile = list(road[0]) if road else [int(sp[0]), int(sp[1])]
    x, y = int(sp[0]), int(sp[1])
    while road and (x, y) != tuple(road[0]):
        if ground[y][x] not in bw.SOLID_GROUNDS:
            ground[y][x] = "trail"
            R.solid[y][x] = False
            R.objects.pop((x, y), None)
        if x != road[0][0]:
            x += 1 if road[0][0] > x else -1
        else:
            y += 1 if road[0][1] > y else -1
    # Where the canoe waits: the water nearest the landing's spawn.
    lsp = R.spawns["landing"]
    water = [(xx, yy) for yy in range(int(lsp[1]) - 2, int(lsp[1]) + 14) for xx in range(int(lsp[0]) - 6, int(lsp[0]) + 7)
             if ground[yy][xx] in ("shallows", "deep_water")]
    put_in = min(water, key=lambda t: (t[0] + 0.5 - lsp[0]) ** 2 + (t[1] + 0.5 - lsp[1]) ** 2) if water else (int(lsp[0]), int(lsp[1]))
    gap_list = sorted((int(P(e, 0)[0]), y) for e in range(br["gap"][0], br["gap"][1] + 1) for y in range(bry - 1, bry + 2))
    far_end = (int(P(br["deck"][1], 0)[0]) + 2, bry - 1)
    pts = R.extra.setdefault("trail_job_points", {})
    pts["bridge_gap"] = list(gap_list[len(gap_list) // 2])
    pts["toll_box"] = list(far_end)
    pts["landing_boathouse"] = [put_in[0] - 4, put_in[1]]
    pts["canoe_build"] = [put_in[0] + 2, put_in[1] - 2]
    pts["canoe_put_in"] = list(put_in)
    pts["sawmill"] = [int(lcx), int(lcy)]
    pts["plank_pile"] = [int(lcx) - 6, int(lcy) + 2]
    pts["cart"] = cart_tile
    lake_c = P(*lk["cranium"]["c"])
    R.landmarks["skull_lake"] = [round(lake_c[0], 2), round(lake_c[1], 2)]
    for name, el in lk["islands"].items():
        p = P(*el["c"])
        R.landmarks[name] = [round(p[0], 2), round(p[1], 2)]
    R.landmarks["ring_hill"] = [round(hx, 2), round(hy, 2)]

    rvx = [t for t in _cross(P, C["summer_ford"], rv) if ground[t[1]][t[0]] == "deep_water"]
    ice = [t for t in _cross(P, C["ice_crossing"], rv) if ground[t[1]][t[0]] == "deep_water"]
    snow = sorted(high | set(getattr(R, "steps_tiles", set())))
    # A closed sign at each end of each snowed-in stretch.
    signs = []
    if high:
        a = trail_pts[max(0, high_from - 4)]
        signs.append([int(a[0]), int(a[1]) + 1])
    foot = getattr(R, "steps_foot", None)
    if foot:
        signs.append([int(foot[0]) + 2, int(foot[1]) + 1])
    flow = bw.resample(list(R.river_pts) + list(out_pts), 4.0)
    R.extra["seasonal"] = {
        "note": "Phase 6, seasons change the land: fords flood in the melt, the summer ford dries to sandbar, the ice crossing freezes in deep winter, the high trails snow in. Tiles are [x, y].",
        "fords": [list(t) for t in sorted(set(getattr(R, "ford_tiles", [])) | creek_tiles)],
        "lake_shore": [list(t) for t in sorted(t for t in shallow_tiles if zone.get(t) == "shore")],
        "summer_ford": [list(t) for t in sorted(rvx)],
        "ice_crossing": [list(t) for t in sorted(ice)],
        "snow_closed": [list(t) for t in snow],
        "closed_signs": signs,
    }
    R.extra["cart_trail"] = [list(t) for t in sorted(getattr(R, "road_tiles", set()))]
    R.extra["river_flow"] = [[round(p[0], 1), round(p[1], 1)] for p in flow]
    R.extra["far_bank_box"] = [bx0, by0, bx1, by1]

    # --- checks --------------------------------------------------------------------------------
    gap = set()
    for e in range(br["gap"][0], br["gap"][1] + 1):
        x = int(P(e, 0)[0])
        for y in range(bry - 1, bry + 2):
            gap.add((x, y))
    R.extra["bridge_gap"] = [list(t) for t in sorted(gap)]
    reach = r2mod._reachable(R, R.spawns["station"], set())
    for t in tiles:
        if t in reach and not R.solid[t[1]][t[0]]:
            R.problems.append("ring three: the far bank can be reached without the bridge at %d,%d" % t)
            break
    reach2 = r2mod._reachable(R, R.spawns["station"], gap)
    lspawn = R.spawns["landing"]
    if (int(lspawn[0]), int(lspawn[1])) not in reach2:
        R.problems.append("ring three: the landing cannot be reached over the mended bridge")
    for name in lk["islands"]:
        p = R.landmarks[name]
        if (int(p[0]), int(p[1])) in reach2:
            R.problems.append("ring three: %s can be reached without the ice" % name)
    # The old road's fallen trunks and brush count as cleared, as in ring two.
    cleared = set()
    for (x, y, kind) in R.extra.get("obstacles_on_routes", []):
        for xx in range(x, x + (3 if kind == "fallen_trunk" else 1)):
            cleared.add((xx, y))
    reach3 = r2mod._reachable(R, R.spawns["station"], cleared)
    lcs = R.spawns["logging_camp"]
    if (int(lcs[0]), int(lcs[1])) not in reach3:
        R.problems.append("ring three: the logging camp cannot be reached from the station")
    return otypes


def _cross(P, c, rv):
    """Tiles of a crossing straight over the river's north-south stretch."""
    x0, y = P(c["e"][0], c["n"])
    x1, _ = P(c["e"][1], c["n"])
    out = []
    for yy in range(int(y) - c["half_width"], int(y) + c["half_width"] + 1):
        for xx in range(int(x0), int(x1) + 1):
            out.append((xx, yy))
    return out
