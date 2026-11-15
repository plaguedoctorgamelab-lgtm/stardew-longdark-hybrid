"""Bakes ring two of the forest around ring one.

Hand-placed features (from region.json) always win over generated terrain.
Positions in region.json are plan coordinates: tiles east and north of the
park gate. Ring one is not changed except for the few tiles listed in
world.json as ring_one_edits, where ring two joins it.
"""
import heapq
import json
import math
import os
import random

import bake_world as bw

TUNING = os.path.join(bw.ROOT, "data", "tuning", "tuning.json")

OBJECT_TYPES = {
    "fence": {"size": [1, 1], "sprite": "obj_fence", "solid": True},
    "brush": {"size": [1, 1], "sprite": "obj_brush", "solid": True},
    "thicket": {"size": [1, 1], "sprite": "obj_thicket", "solid": True},
    "survey_stake": {"size": [1, 1], "sprite": "obj_survey_stake", "solid": False, "interact": "find:survey_stakes"},
    "cairn": {"size": [1, 1], "sprite": "obj_cairn", "solid": True, "interact": "landmark:kettle_pond"},
    "bridge_post": {"size": [1, 1], "sprite": "obj_bridge_post", "solid": True, "interact": "landmark:broken_bridge"},
}

SOLID_GROUNDS = {"deep_water", "rock"}


def disc(cx, cy, r):
    for y in range(int(math.floor(cy - r)), int(math.ceil(cy + r)) + 1):
        for x in range(int(math.floor(cx - r)), int(math.ceil(cx + r)) + 1):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                yield x, y


def bake(R, G, L, r1, structures, ox, oy):
    C = G["ring_two"]
    rng = random.Random(C["seed"])
    gx = r1["gate"][0] + ox
    gy = r1["gate"][1] + oy

    def P(e, n):
        return (gx + e, gy - n)

    def Pi(e, n):
        x, y = P(e, n)
        return int(math.floor(x)), int(math.floor(y))

    def E(x, y):
        """Plan coordinates of a game tile's middle."""
        return (x + 0.5 - gx, gy - (y + 0.5))

    r1x0, r1y0, r1x1, r1y1 = ox, oy, ox + r1["W"], oy + r1["H"]

    def in_r1(x, y):
        return r1x0 <= x < r1x1 and r1y0 <= y < r1y1

    bx0, by0 = Pi(C["box"]["e"][0], C["box"]["n"][1])
    bx1, by1 = Pi(C["box"]["e"][1], C["box"]["n"][0])
    bx0, by0 = max(0, bx0), max(0, by0)
    bx1, by1 = min(R.W, bx1), min(R.H, by1)
    # Whole chunks, so the edge of the built area is never seen.
    cs = R.cs
    bx0, by0 = (bx0 // cs) * cs, (by0 // cs) * cs
    bx1, by1 = min(R.W, -(-bx1 // cs) * cs), min(R.H, -(-by1 // cs) * cs)

    def r2(x, y):
        return bx0 <= x < bx1 and by0 <= y < by1 and not in_r1(x, y)

    tiles = [(x, y) for y in range(by0, by1) for x in range(bx0, bx1) if not in_r1(x, y)]
    ground = R.ground
    objects = R.objects
    protected = set()
    zone = {}   # tile -> "burn", "bottoms", "far", "river_woods"

    for (x, y) in tiles:
        ground[y][x] = "forest_floor"

    # --- far bank: across the river, never reachable ----------------------------
    rv = C["river"]
    river_pts = bw.resample(bw.catmull_rom([P(e, n) for e, n in rv["points"]]), 0.5)
    # The river runs south, then bends east. Its north-south stretch gives x for
    # each row; its east-west stretch gives y for each column.
    bend_i = min(range(len(river_pts)), key=lambda i: abs(river_pts[i][1] - P(0, 600)[1]) + abs(river_pts[i][0] - P(900, 0)[0]))
    ns_x = {}
    for (px, py) in river_pts[:bend_i + 1]:
        ns_x.setdefault(int(py), px)
    ew_y = {}
    for (px, py) in river_pts[bend_i:]:
        ew_y.setdefault(int(px), py)
    bend_x, bend_y = river_pts[bend_i]

    def far_side(x, y):
        if y <= bend_y and y in ns_x and x > ns_x[y]:
            return True
        if x >= bend_x and x in ew_y and y < ew_y[x]:
            return True
        return False

    for (x, y) in tiles:
        if far_side(x, y):
            zone[(x, y)] = "far"

    # --- the Shoulder: cliffs along the north edge --------------------------------
    sh = C["shoulder"]
    sh_noise = bw.Noise(C["seed"] + 1, 16)
    for (x, y) in tiles:
        e, n = E(x, y)
        if zone.get((x, y)) == "far":
            continue
        if n > sh["n"] + (sh_noise.at(x, 0) - 0.5) * 2 * sh["wobble"]:
            ground[y][x] = "rock"
    # --- the Burn ---------------------------------------------------------------------
    bu = C["burn"]
    bcx, bcy = P(*bu["center"])
    bnoise = bw.Noise(C["seed"] + 2, 14)
    tall = bw.Noise(C["seed"] + 3, 6)
    for (x, y) in tiles:
        if ground[y][x] != "forest_floor" or (x, y) in zone:
            continue
        d = math.hypot(x + 0.5 - bcx, y + 0.5 - bcy)
        if d < bu["radius"] + (bnoise.at(x, y) - 0.5) * 2 * bu["wobble"]:
            zone[(x, y)] = "burn"
            ground[y][x] = "tall_grass" if tall.at(x, y) < bu["tall_grass"] else "grass"

    # --- the Bottoms --------------------------------------------------------------
    bo = C["bottoms"]
    onoise = bw.Noise(C["seed"] + 4, 40)
    gnoise = bw.Noise(C["seed"] + 5, 5)
    for (x, y) in tiles:
        if ground[y][x] != "forest_floor" or (x, y) in zone:
            continue
        e, n = E(x, y)
        w = (onoise.at(x, y) - 0.5) * 2 * bo["wobble"]
        if bo["e"][0] + w < e < bo["e"][1] + w and n < bo["n"][1] + w:
            zone[(x, y)] = "bottoms"
            ground[y][x] = "grass" if gnoise.at(x, y) < bo["grass"] else "bog"

    # --- river woods ------------------------------------------------------------------
    fo = C["forest"]
    for (x, y) in tiles:
        if (x, y) not in zone:
            e, n = E(x, y)
            if fo["river_woods"][0] <= e <= fo["river_woods"][1]:
                zone[(x, y)] = "river_woods"

    # --- the ridge outside ring one's north and east sides ------------------------------
    rd = C["ridge"]["depth"]
    rnoise = bw.Noise(C["seed"] + 6, 5)
    for (x, y) in tiles:
        dn = r1y0 - 1 - y if (r1x0 <= x < r1x1 and y < r1y0) else 99
        de = x - r1x1 if (r1y0 <= y < r1y1 and x >= r1x1) else 99
        d = min(dn, de)
        if d < rd and d < rnoise.at(x, y) * (rd + 1):
            ground[y][x] = "rock"

    # --- the park boundary: rock, dense trees and an old fence ---------------------------
    bnd = C["boundary"]
    for (x, y) in tiles:
        west = x - bx0 if x < r1x1 and y < r1y0 else 99
        south = R.H - 1 - y if x >= r1x1 else 99
        d = min(west, south)
        if d < bnd["rock"]:
            ground[y][x] = "rock"
            zone[(x, y)] = "edge"
        elif d < bnd["rock"] + bnd["trees"]:
            ground[y][x] = "forest_floor"
            zone[(x, y)] = "edge"
        elif d == bnd["rock"] + bnd["trees"]:
            zone[(x, y)] = "fence"

    # --- Kettle Pond ------------------------------------------------------------------
    po = C["pond"]
    pcx, pcy = P(*po["center"])
    pnoise = bw.Noise(C["seed"] + 7, 6)
    pond_tiles = set()
    for y in range(int(pcy - po["ry"] - po["reeds"] - 2), int(pcy + po["ry"] + 3)):
        for x in range(int(pcx - po["rx"] - 2), int(pcx + po["rx"] + 3)):
            u = ((x + 0.5 - pcx) / po["rx"]) ** 2 + ((y + 0.5 - pcy) / po["ry"]) ** 2
            wob = (pnoise.at(x, y) - 0.5) * 0.25
            if u <= 1.0 + wob:
                pond_tiles.add((x, y))
                inner = ((x + 0.5 - pcx) / (po["rx"] - po["deep_in"])) ** 2 + ((y + 0.5 - pcy) / (po["ry"] - po["deep_in"])) ** 2
                ground[y][x] = "deep_water" if inner <= 1.0 + wob else "shallows"
                zone[(x, y)] = "pond"
            elif u <= 1.6 + wob and y < pcy - po["ry"] * 0.3:
                # Reeds along the north shore.
                ground[y][x] = "tall_grass"
                zone[(x, y)] = "pond"
    (b0e, b0n), (b1e, b1n) = po["beach"]
    for y in range(Pi(0, b1n)[1], Pi(0, b0n)[1] + 1):
        for x in range(Pi(b0e, 0)[0], Pi(b1e, 0)[0] + 1):
            if (x, y) not in pond_tiles:
                ground[y][x] = "grass"
                protected.add((x, y))
                zone[(x, y)] = "pond"

    # --- Ford Creek, from the pond down into ring one's stream --------------------------
    cr = C["creek"]
    creek_pts = bw.resample(bw.catmull_rom([P(e, n) for e, n in cr["points"]]), 0.5)
    creek_tiles = set()
    for (px, py) in creek_pts:
        for (x, y) in disc(px, py, cr["shallow_radius"]):
            creek_tiles.add((x, y))
    deep_tiles = set()
    for (px, py) in creek_pts:
        for (x, y) in disc(px, py, cr["deep_radius"]):
            deep_tiles.add((x, y))

    # --- the trail from the cabin toward the pond -------------------------------------------
    tr = C["trail"]
    cab = r1["structures"][1]
    cab_center = (cab["pos"][0] + ox + cab["size"][0] / 2, cab["pos"][1] + oy + cab["size"][1] / 2)
    gap_x, inner_path = _find_gap(R, r1, ox, oy, cab_center, L)
    trail_from = (gap_x + 0.5, P(0, tr["from_gap_n"])[1])
    trail_pts = bw.solve_path([trail_from] + [P(e, n) for e, n in tr["via"]] + [P(*tr["to"])], tr["length"], 0, 30)
    trail_pts = bw.resample(trail_pts, 0.5)
    vanished = set()
    for (a, b) in tr["vanished"]:
        for i in range(int(a * len(trail_pts)), int(b * len(trail_pts))):
            vanished.add(i)
    trail_tiles = set()
    corridor = set()
    for i, (px, py) in enumerate(trail_pts):
        for t in disc(px, py, 2.2):
            corridor.add(t)
        if i in vanished:
            continue
        for t in disc(px, py, tr["radius"]):
            trail_tiles.add(t)
    # Where the trail crosses the creek, the creek is shallow: a ford.
    ford = None
    for (px, py) in trail_pts:
        if (int(px), int(py)) in deep_tiles:
            ford = (px, py)
            break
    if ford is None:
        R.problems.append("the trail from the cabin never crosses the creek")
    else:
        for t in disc(ford[0], ford[1], cr["ford_radius"]):
            deep_tiles.discard(t)
    for (x, y) in creek_tiles:
        if in_r1(x, y):
            continue
        if r2(x, y) and zone.get((x, y)) != "pond":
            ground[y][x] = "deep_water" if (x, y) in deep_tiles else "shallows"
            zone[(x, y)] = "creek"

    # Ring one: open its ridge where the creek runs in and where the trail runs out.
    rock_rows = L["border"]["rock"]
    edge_rows = rock_rows + L["border"]["trees"]
    for (x, y) in sorted(creek_tiles):
        if in_r1(x, y) and y - r1y0 < rock_rows:
            g = "deep_water" if (x, y) in deep_tiles else "shallows"
            if ground[y][x] != g:
                ground[y][x] = g
                R.solid[y][x] = g in SOLID_GROUNDS
                R.edits.append((x, y))
    for y in range(r1y0, r1y0 + edge_rows):
        for x in range(gap_x - 1, gap_x + 2):
            if ground[y][x] != "forest_floor" or R.solid[y][x] or (x, y) in objects:
                ground[y][x] = "forest_floor"
                R.solid[y][x] = False
                objects.pop((x, y), None)
                R.edits.append((x, y))

    for (x, y) in trail_tiles:
        if r2(x, y) and ground[y][x] not in ("deep_water", "shallows"):
            ground[y][x] = "trail"
    for t in corridor:
        protected.add(t)
        if r2(*t) and ground[t[1]][t[0]] == "rock":
            ground[t[1]][t[0]] = "forest_floor"

    # --- Tower Hill ---------------------------------------------------------------------------
    tw = C["tower"]
    tcx, tcy = P(*tw["center"])
    tnoise = bw.Noise(C["seed"] + 8, 7)
    for (x, y) in disc(tcx, tcy, tw["rock_radius"] + tw["wobble"]):
        d = math.hypot(x + 0.5 - tcx, y + 0.5 - tcy)
        if d <= tw["rock_radius"] + (tnoise.at(x, y) - 0.5) * 2 * tw["wobble"]:
            ground[y][x] = "rock"
            zone[(x, y)] = "hill"
    for (x, y) in disc(tcx, tcy, tw["plateau"]):
        ground[y][x] = "grass"
        protected.add((x, y))
    sdx, sdy = tw["steps_dir"][0], -tw["steps_dir"][1]
    sl = math.hypot(sdx, sdy)
    sdx, sdy = sdx / sl, sdy / sl
    foot = (tcx + sdx * (tw["rock_radius"] + tw["wobble"] + 2), tcy + sdy * (tw["rock_radius"] + tw["wobble"] + 2))
    steps_pts = bw.resample([(tcx + sdx * (tw["plateau"] - 1), tcy + sdy * (tw["plateau"] - 1)), foot], 0.5)
    for (px, py) in steps_pts:
        for t in disc(px, py, tw["steps_radius"]):
            ground[t[1]][t[0]] = "trail"
        for t in disc(px, py, 2.5):
            protected.add(t)

    # --- the stakes across the Burn -------------------------------------------------------------
    st = C["stakes"]
    s0 = P(*st["from"])
    stake_line = bw.resample([s0, foot], 0.5)
    stakes = []
    step = st["every"] * 2
    for i in range(0, len(stake_line), step):
        stakes.append(stake_line[i])
    for (px, py) in stake_line:
        for t in disc(px, py, st["corridor"]):
            protected.add(t)
            if ground[t[1]][t[0]] in ("rock", "deep_water"):
                ground[t[1]][t[0]] = "grass"

    # --- the old road down to the river -------------------------------------------------------
    ro = C["road"]
    road_pts = bw.solve_path([foot] + [P(e, n) for e, n in ro["via"]] + [P(*ro["to"])], ro["length"], 0, 70)
    road_pts = bw.resample(road_pts, 0.5)
    for (px, py) in road_pts:
        for t in disc(px, py, ro["radius"]):
            if ground[t[1]][t[0]] not in ("deep_water",):
                ground[t[1]][t[0]] = "trail"
        for t in disc(px, py, ro["radius"] + 1.5):
            protected.add(t)

    # --- the Dusk River ----------------------------------------------------------------------
    for (px, py) in river_pts:
        for (x, y) in disc(px, py, rv["shallow_radius"]):
            if r2(x, y) and ground[y][x] != "deep_water":
                # Below the cliffs the river runs deep right to the rock.
                ground[y][x] = "deep_water" if ground[y][x] == "rock" else "shallows"
                zone[(x, y)] = "river"
    for (px, py) in river_pts:
        for (x, y) in disc(px, py, rv["deep_radius"]):
            if r2(x, y):
                ground[y][x] = "deep_water"
                zone[(x, y)] = "river"
    # The river may never be waded: its shallow rim on the near side stays, but
    # every tile between the two rims is deep.

    # --- the broken bridge ---------------------------------------------------------------------
    br = C["bridge"]
    _, bry = Pi(0, br["n"])
    for e in range(br["deck"][0], br["deck"][1] + 1):
        if br["gap"][0] <= e <= br["gap"][1]:
            continue
        x, _ = Pi(e, 0)
        for y in range(bry - 1, bry + 2):
            ground[y][x] = "boards"
            protected.add((x, y))
            zone[(x, y)] = "bridge"
    # The far half of the deck stands on the far bank: never reachable.

    # --- the mire along the east edge, south of the river --------------------------------------
    mi = C["mire"]
    mnoise = bw.Noise(C["seed"] + 9, 9)
    for (x, y) in tiles:
        e, n = E(x, y)
        if zone.get((x, y)) == "far" or (zone.get((x, y)) == "river" and ground[y][x] == "deep_water"):
            continue
        c = mi["e"] + (mnoise.at(0, y) - 0.5) * 2 * mi["wobble"]
        if abs(e - c) <= mi["half_width"]:
            ground[y][x] = "deep_water"
            zone[(x, y)] = "mire"
        elif e > c:
            zone[(x, y)] = "far"

    # --- objects -------------------------------------------------------------------------------
    tree_kinds = ["tree_pine", "tree_pine", "tree_fir", "tree_oak"]
    wood_kinds = ["tree_fir", "tree_pine", "tree_fir", "tree_oak"]
    pool_noise = bw.Noise(C["seed"] + 10, 4)
    thick_noise = bw.Noise(C["seed"] + 11, 4)
    for (x, y) in tiles:
        r = rng.random()
        k = rng.random()
        if (x, y) in protected or (x, y) in objects:
            continue
        g = ground[y][x]
        z = zone.get((x, y), "")
        if z == "fence":
            if g not in SOLID_GROUNDS:
                objects[(x, y)] = "fence"
            continue
        if z == "edge":
            if g == "forest_floor":
                objects[(x, y)] = "tree_pine"
            continue
        if g not in ("forest_floor", "grass", "tall_grass", "bog"):
            continue
        if z == "burn":
            if r < bu["snag"]:
                objects[(x, y)] = "tree_dead"
            elif r < bu["snag"] + bu["young"]:
                objects[(x, y)] = "bush"
            elif r < bu["snag"] + bu["young"] + bu["boulder"]:
                objects[(x, y)] = "boulder"
        elif z == "bottoms":
            if thick_noise.at(x, y) < bo["thicket"] and r < 0.55:
                objects[(x, y)] = "thicket"
            elif r < bo["alder"]:
                objects[(x, y)] = "tree_oak"
        elif z == "far":
            if r < fo["far_bank_tree"]:
                objects[(x, y)] = wood_kinds[int(k * 4)]
        elif z == "river_woods":
            if g == "forest_floor" and r < fo["river_woods_tree"]:
                objects[(x, y)] = wood_kinds[int(k * 4)]
            elif r < fo["river_woods_tree"] + fo["boulder"]:
                objects[(x, y)] = "boulder"
        elif z in ("", "hill"):
            if g == "forest_floor" and r < fo["tree"]:
                objects[(x, y)] = tree_kinds[int(k * 4)]
            elif g == "forest_floor" and r < fo["tree"] + fo["boulder"]:
                objects[(x, y)] = "boulder"
    # Standing pools in the Bottoms.
    every = bo["pool_every"]
    bottoms = sorted(t for t in tiles if zone.get(t) == "bottoms")
    for _ in range(len(bottoms) // (every * every)):
        jx, jy = bottoms[rng.randrange(len(bottoms))]
        if True:
            rad = bo["pool_radius"][0] + rng.random() * (bo["pool_radius"][1] - bo["pool_radius"][0])
            for t in disc(jx + 0.5, jy + 0.5, rad):
                if zone.get(t) == "bottoms" and t not in protected:
                    ground[t[1]][t[0]] = "deep_water"
                    objects.pop(t, None)

    # Fallen trunks across the trail and the road.
    def trunk_at(pts, frac):
        i = int(frac * len(pts))
        px, py = pts[i]
        tx, ty = int(px) - 1, int(py)
        for xx in range(tx, tx + 3):
            objects.pop((xx, ty), None)
        objects[(tx, ty)] = "fallen_trunk"
        return (tx, ty)

    trunks = [trunk_at(trail_pts, f) for f in tr["trunks"]] + [trunk_at(road_pts, ro["trunk"])]

    # Brush grown across the old trail and road.
    brush = []

    # A trunk blocks the whole width of the trail: brush fills its row beside it.
    for (tx, ty) in trunks:
        for step in (-1, 1):
            x = tx - 1 if step < 0 else tx + 3
            while ground[ty][x] == "trail" and (x, ty) not in objects:
                objects[(x, ty)] = "brush"
                brush.append((x, ty))
                x += step

    def brush_at(pts, frac, radius):
        px, py = pts[int(frac * len(pts))]
        for t in disc(px, py, radius + 0.4):
            if ground[t[1]][t[0]] == "trail" and t not in objects:
                objects[t] = "brush"
                brush.append(t)

    for f in tr["brush"]:
        brush_at(trail_pts, f, tr["radius"])
    for f in ro["brush"]:
        brush_at(road_pts, f, ro["radius"])
    for (px, py) in stakes:
        objects[(int(px), int(py))] = "survey_stake"
    cx_, cy_ = Pi(*po["cairn"])
    objects[(cx_, cy_)] = "cairn"
    px_, py_ = Pi(*br["post"])
    objects[(px_, py_)] = "bridge_post"

    # --- the fire tower --------------------------------------------------------------------------
    trow = structures[tw["id"]]
    fw, fh = trow["footprint"]
    tx0, ty0 = int(round(tcx - fw / 2)), int(round(tcy - fh / 2))
    door = trow["door"]
    tower = {"id": tw["id"], "pos": [tx0, ty0], "size": [fw, fh], "door": [tx0 + door[0], ty0 + door[1]]}
    for yy in range(ty0, ty0 + fh):
        for xx in range(tx0, tx0 + fw):
            objects.pop((xx, yy), None)
    R.structures.append(tower)

    # --- solidity for ring two -------------------------------------------------------------------
    otypes = dict(r1["object_types"])
    otypes.update(OBJECT_TYPES)
    for (x, y) in tiles:
        R.solid[y][x] = ground[y][x] in SOLID_GROUNDS
    for (x, y), kind in objects.items():
        if not r2(x, y) and not in_r1(x, y):
            continue
        if in_r1(x, y):
            continue
        ot = otypes[kind]
        if ot["solid"]:
            w, h = ot["size"]
            for yy in range(y, y + h):
                for xx in range(x, x + w):
                    if R.inside(xx, yy):
                        R.solid[yy][xx] = True
    for yy in range(ty0, ty0 + fh):
        for xx in range(tx0, tx0 + fw):
            R.solid[yy][xx] = True
    R.mark_baked_rect(bx0, by0, bx1, by1)

    # --- landmarks and spawns ---------------------------------------------------------------------
    R.landmarks[po["id"]] = list(P(*po["center"]))
    R.landmarks[tw["id"]] = [tower["door"][0] + 0.5, tower["door"][1] + 0.5]
    R.landmarks[br["id"]] = [round(P(br["gap"][0], 0)[0], 2), bry + 0.5]
    R.spawns["pond"] = [round(c, 2) for c in P(*po["spawn"])]
    R.spawns["tower"] = [tower["door"][0] + 0.5, tower["door"][1] + 1.5]
    R.spawns["bridge"] = [round(c, 2) for c in P(*br["spawn"])]

    # --- checks -----------------------------------------------------------------------------------
    trunk_tiles = set(brush)
    for (tx, ty) in trunks:
        for xx in range(tx, tx + 3):
            trunk_tiles.add((xx, ty))
    reach = _reachable(R, R.spawns["station"], trunk_tiles)
    for name in ("pond", "tower", "bridge"):
        p = R.spawns[name]
        if (int(p[0]), int(p[1])) not in reach:
            R.problems.append("ring two: the %s cannot be reached from the station" % name)
    for (x, y) in reach:
        if zone.get((x, y)) == "far":
            R.problems.append("ring two: the far side can be reached at %d,%d" % (x, y))
            break
        if x <= bx0 or y <= by0 or x >= bx1 - 1 or y >= by1 - 1:
            R.problems.append("ring two: the edge of the built area can be reached at %d,%d" % (x, y))
            break

    # --- routes and travel times ------------------------------------------------------------------
    speeds = _speeds()
    station_route = [tuple(p) for p in R.routes["cabin"]]
    base = route_minutes(R, station_route, speeds)
    cab_spawn = tuple(R.spawns["cabin"])
    # Routes follow the trails as laid, as a ranger keeping to them would:
    # the cabin trail, the line of stakes, the steps and the old road. Short
    # links between them are the quickest walk.
    def link(a, b):
        return _astar(R, a, b, speeds, trunk_tiles)

    def along(pts):
        return bw.resample(pts, 2.0)

    pond_spawn = tuple(R.spawns["pond"])
    to_pond = [link(cab_spawn, trail_pts[0]), along(trail_pts), link(trail_pts[-1], pond_spawn)]
    to_stakes = [link(pond_spawn, stake_line[0]), along(stake_line)]
    up_steps = along(list(reversed(steps_pts)))
    legs = {
        "pond": to_pond,
        "tower": to_pond + to_stakes + [up_steps, link(up_steps[-1], tuple(R.spawns["tower"]))],
        "bridge": to_pond + to_stakes + [along(road_pts), link(road_pts[-1], tuple(R.spawns["bridge"]))],
    }
    times = {}
    for name, parts in legs.items():
        if any(p is None for p in parts):
            R.problems.append("ring two: no way to walk to the %s" % name)
            continue
        pts = list(station_route)
        for part in parts:
            pts += part[1:]
        R.routes[name] = [[round(x, 2), round(y, 2)] for (x, y) in pts]
        R.route_lengths[name] = round(bw.polyline_length(pts), 1)
        times[name] = round(route_minutes(R, pts, speeds), 1)
    R.route_targets.update(C["route_targets_minutes"])
    R.extra["ring_two_estimate_minutes"] = times
    R.extra["ring_two_lengths"] = {"trail": round(bw.polyline_length(trail_pts), 1), "road": round(bw.polyline_length(road_pts), 1), "stakes": round(bw.polyline_length(stake_line), 1)}
    R.extra["ring_two_estimate_base"] = round(base, 1)
    R.extra["obstacles_on_routes"] = [[t[0], t[1], "fallen_trunk"] for t in sorted(trunks)] + [[t[0], t[1], "brush"] for t in sorted(brush)]
    return OBJECT_TYPES


def _speeds():
    with open(TUNING, encoding="utf-8") as f:
        T = json.load(f)
    return T["movement"]["ground_speed"]


def route_minutes(R, pts, speeds):
    """Game minutes to walk a polyline at the ground speeds under it, clear weather."""
    total = 0.0
    per_min = 4.5 * 7 / 10   # tiles per game minute on trail
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        mx, my = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2
        g = R.ground[int(my)][int(mx)]
        total += math.dist(a, b) / (per_min * speeds.get(g, 1.0))
    return total


def _reachable(R, start, passable_extra):
    from collections import deque
    sx, sy = int(start[0]), int(start[1])
    seen = {(sx, sy)}
    q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if R.inside(nx, ny) and (nx, ny) not in seen and (not R.solid[ny][nx] or (nx, ny) in passable_extra):
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


def _astar(R, a, b, speeds, passable_extra, margin=60):
    """The quickest walk between two points as tile middles; obstacles in
    passable_extra are treated as cleared."""
    sx, sy = int(a[0]), int(a[1])
    tx, ty = int(b[0]), int(b[1])
    x0, x1 = min(sx, tx) - margin, max(sx, tx) + margin
    y0, y1 = min(sy, ty) - margin, max(sy, ty) + margin

    def ok(x, y):
        return x0 <= x <= x1 and y0 <= y <= y1 and R.inside(x, y) and (not R.solid[y][x] or (x, y) in passable_extra)

    def cost(x, y):
        return 1.0 / speeds.get(R.ground[y][x], 1.0)

    openq = [(0.0, 0.0, sx, sy)]
    came = {(sx, sy): None}
    gbest = {(sx, sy): 0.0}
    dirs = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)]
    while openq:
        f, g, x, y = heapq.heappop(openq)
        if (x, y) == (tx, ty):
            break
        if g > gbest[(x, y)] + 1e-9:
            continue
        for dx, dy in dirs:
            nx, ny = x + dx, y + dy
            if not ok(nx, ny):
                continue
            if dx and dy and (not ok(x + dx, y) or not ok(x, y + dy)):
                continue
            step = (1.4142 if dx and dy else 1.0) * (cost(x, y) + cost(nx, ny)) / 2
            ng = g + step
            if ng < gbest.get((nx, ny), 1e18):
                gbest[(nx, ny)] = ng
                came[(nx, ny)] = (x, y)
                h = math.hypot(tx - nx, ty - ny)
                heapq.heappush(openq, (ng + h, ng, nx, ny))
    if (tx, ty) not in came:
        return None
    path = []
    node = (tx, ty)
    while node is not None:
        path.append((node[0] + 0.5, node[1] + 0.5))
        node = came[node]
    path.reverse()
    path[0] = (float(a[0]), float(a[1]))
    path[-1] = (float(b[0]), float(b[1]))
    return _thin(path)


def _thin(path):
    """Keeps the corners of a tile path and drops points along straight runs."""
    if len(path) < 3:
        return path
    out = [path[0]]
    for i in range(1, len(path) - 1):
        ax, ay = path[i][0] - path[i - 1][0], path[i][1] - path[i - 1][1]
        bx, by = path[i + 1][0] - path[i][0], path[i + 1][1] - path[i][1]
        if abs(ax - bx) > 1e-6 or abs(ay - by) > 1e-6:
            out.append(path[i])
    out.append(path[-1])
    return out


def _find_gap(R, r1, ox, oy, cab_center, L):
    """Where the trail leaves ring one through its north ridge: the column whose
    walk from the cabin clearing through ring one's own forest is shortest."""
    from collections import deque
    edge_rows = L["border"]["rock"] + L["border"]["trees"]
    start = (int(cab_center[0]), int(cab_center[1]) - L["cabin_clearing_radius"] + 1)
    seen = {start: 0}
    q = deque([start])
    x0, x1 = ox + 330, ox + r1["W"] - 10
    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if x0 <= nx < x1 and oy + edge_rows <= ny < oy + 60 and (nx, ny) not in seen and not R.solid[ny][nx]:
                seen[(nx, ny)] = seen[(x, y)] + 1
                q.append((nx, ny))
    row = oy + edge_rows
    best = None
    for x in range(x0 + 2, x1 - 2):
        if all((xx, row) in seen for xx in (x - 1, x, x + 1)):
            d = seen[(x, row)]
            if best is None or d < best[0]:
                best = (d, x)
    if best is None:
        raise SystemExit("ring two: no way from the cabin clearing to ring one's north ridge")
    return best[1], None
