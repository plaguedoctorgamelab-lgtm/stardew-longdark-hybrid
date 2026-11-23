"""Bakes Humdrum, the town outside the park gate (Phase 4 Spec, 4a step 1),
into data/world/town.json.

The layout is written here by hand: about 90 by 60 tiles, snug. Main Street
runs west from the park road to the square; a north lane holds most of the
houses; Creek Lane holds the library, Town Hall and the painter's house;
Dusk Creek runs along the south with a footbridge to the fortune teller's
caravan. Every building's door is in the middle of its bottom row, facing the
street, as everywhere in the game.

Ground codes: l lawn, d dark lawn (the forest floor round the edge), c
cobbles, g gravel, p the square's paving, f flower bed, b boards, s shallow
water, w deep water. Deep water, buildings and the border trees are solid.

Since Art Request 19 (0.6.7): the square's south half is paved round the
compass mosaic, the creek wanders, the north houses have backyards with a
fence, hedge or wall, bushes stand in clumps, tufts and wildflowers lie on
the lawns, and the town's seasonal pieces are placed. Objects may carry:
flat (lies on the ground, under everything standing), seasons (shown only
then), lift (pixels drawn higher, for things hung between buildings),
no_shadow, and blocks (the tiles a fence or wall run makes solid).

Run: python tools/bake_town.py
"""

import json
import math
import os
import random

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "world", "town.json")
W, H = 90, 60


def main():
    g = [["l"] * W for _ in range(H)]
    rng = random.Random(1967)

    def fill(x0, y0, x1, y1, code):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = code

    # The forest floor round the edge, darker, under the border trees.
    fill(0, 0, W - 1, 2, "d")
    fill(0, H - 3, W - 1, H - 1, "d")
    fill(0, 0, 2, H - 1, "d")
    fill(W - 3, 0, W - 1, H - 1, "d")
    # Main Street, from the park road (east) to the square.
    fill(44, 28, 89, 32, "c")
    # The square: a cobbled ring round a green with the bandstand, and the
    # paved south half with the compass set in it (Art Request 19).
    fill(26, 18, 44, 42, "c")
    fill(29, 21, 41, 30, "l")
    fill(29, 31, 41, 39, "p")
    # Lanes, and the paths joining them.
    fill(6, 13, 80, 14, "g")
    fill(6, 46, 80, 47, "g")
    fill(6, 13, 7, 47, "g")
    fill(33, 15, 36, 17, "c")
    fill(33, 43, 36, 45, "c")
    # Dusk Creek: four rows, its top row wandering a tile up and down, kept
    # straight by the footbridge and the caravan. Shallows at the banks.
    creek_top = {}
    for x in range(2, 88):
        top = 49 + round(math.sin(x / 6.0) * 0.6 + math.sin(x / 13.0 + 1.0) * 0.7)
        if 17 <= x <= 31:
            top = 49
        creek_top[x] = top
        g[top][x] = "s"
        g[top + 1][x] = "w"
        g[top + 2][x] = "w"
        g[top + 3][x] = "s"
    fill(21, 48, 23, 53, "b")
    fill(21, 54, 23, 57, "g")
    fill(23, 56, 27, 57, "g")
    # Flower beds at the square's corners, three by two so their edges fit.
    for x0, y0 in ((27, 19), (42, 19), (27, 40), (42, 40)):
        fill(x0, y0, x0 + 2, y0 + 1, "f")

    buildings = [
        # id, sprite, pos, size
        ("house_pelletier", "town_house_blue", (8, 8), (5, 5)),
        ("house_kowalski", "town_house_pink", (15, 8), (5, 5)),
        ("house_thistlewood", "town_house_green", (22, 8), (5, 5)),
        ("house_pruitt", "town_house_big", (46, 7), (6, 6)),
        ("house_abernathy", "town_house_yellow", (54, 8), (5, 5)),
        ("house_mendoza", "town_house_terracotta", (61, 8), (5, 5)),
        ("house_lindqvist", "town_house_log", (68, 8), (5, 5)),
        ("percolator", "town_percolator", (48, 22), (5, 6)),
        ("casa_luna", "town_casa_luna", (55, 23), (6, 5)),
        ("outfitters", "town_outfitters", (63, 22), (6, 6)),
        ("gifts", "town_gifts", (71, 23), (5, 5)),
        ("carpentry", "town_carpentry", (78, 22), (7, 6)),
        ("house_arden", "town_house_studio", (8, 41), (5, 5)),
        ("library", "town_library", (46, 39), (7, 7)),
        ("town_hall", "town_hall", (55, 40), (7, 6)),
        ("caravan", "town_caravan", (24, 53), (4, 3)),
        ("bandstand", "town_bandstand", (32, 25), (6, 5)),
    ]
    out_buildings = []
    for bid, sprite, (px, py), (sw, sh) in buildings:
        door = [px + sw // 2, py + sh - 1]
        out_buildings.append({"id": bid, "sprite": sprite, "pos": [px, py], "size": [sw, sh], "door": door,
                              "front": [door[0], door[1] + 1]})

    objects = []

    def put(sprite, x, y, solid=False, **more):
        o = {"sprite": sprite, "pos": [x, y], "solid": solid}
        o.update(more)
        objects.append(o)

    # The forest round the edge, two trees deep and staggered, with the park
    # road's gap on the east.
    for x in range(0, W, 2):
        put("obj_tree_pine" if (x // 2) % 3 else "obj_tree_oak", x, 1, True)
        put("obj_tree_fir" if (x // 2) % 2 else "obj_tree_pine", x + 1, 0, True)
        put("obj_tree_pine" if (x // 2) % 3 else "obj_tree_oak", x, H - 1, True)
        put("obj_tree_fir" if (x // 2) % 2 else "obj_tree_pine", x + 1, H - 2, True)
    for y in range(3, H - 2, 2):
        put("obj_tree_fir" if (y // 2) % 2 else "obj_tree_pine", 0, y, True)
        put("obj_tree_pine", 1, y + 1, True)
        if not 25 <= y <= 34:
            put("obj_tree_oak" if (y // 2) % 2 else "obj_tree_pine", 88, y, True)
            put("obj_tree_fir", 87, y + 1, True)
    # Trees on the lawns; crabapples along Main Street, in blossom in spring.
    for x, y in ((14, 22), (18, 30), (10, 34), (20, 38), (64, 17), (76, 17), (40, 55), (60, 55), (75, 55)):
        put("obj_tree_maple" if (x + y) % 2 else "obj_tree_oak", x, y, True)
    for x, y in ((52, 36), (58, 38), (66, 35), (74, 37), (82, 36)):
        put("obj_tree_crabapple", x, y, True, seasons=["spring"])
        put("obj_tree_crabapple_bare", x, y, True, seasons=["summer", "autumn", "winter"])
        put("town_petals", x - 1, y, flat=True, seasons=["spring"])
        put("town_leaves_scatter", x + 1, y, flat=True, seasons=["autumn"])
    put("town_leaf_pile", 13, 23, seasons=["autumn"])
    put("town_leaf_pile", 65, 18, seasons=["autumn"])
    # Esme's willow, over the caravan.
    put("obj_tree_willow", 29, 55, True)
    # Bushes in clumps on the lawns.
    for sprite, x, y in (
            ("town_bush_medium", 48, 35), ("town_bush_small", 56, 34), ("town_bush_large", 63, 37), ("town_bush_flowering", 71, 35),
            ("town_bush_medium", 79, 38), ("town_bush_small", 86, 37), ("town_bush_medium", 50, 18), ("town_bush_flowering", 58, 19),
            ("town_bush_large", 70, 19), ("town_bush_medium", 84, 18), ("town_bush_small", 45, 19), ("town_bush_medium", 12, 26),
            ("town_bush_flowering", 22, 24), ("town_bush_large", 16, 35), ("town_bush_small", 24, 32), ("town_bush_medium", 9, 18),
            ("town_bush_small", 11, 18), ("town_bush_large", 46, 56), ("town_bush_medium", 55, 57), ("town_bush_flowering", 68, 56),
            ("town_bush_medium", 82, 56), ("town_bush_small", 34, 57), ("town_bush_medium", 4, 10), ("town_bush_medium", 4, 30),
            ("town_bush_large", 4, 42), ("town_bush_medium", 85, 12), ("town_bush_small", 85, 44), ("town_bush_medium", 15, 56)):
        put(sprite, x, y, True)
    # The square: the compass in the paving, benches either side, the
    # notice board on the ring, a signpost where Main Street comes in.
    put("town_square_compass", 33.5, 33.5, flat=True)
    put("town_bench", 31, 38)
    put("town_bench", 39, 38)
    put("town_bench", 40, 48)
    put("town_notice_board", 43, 34, True, id="notice_board")
    put("town_signpost", 45, 27, True)
    # Main Street's things.
    put("town_sandwich_board", 47, 28, True)
    put("town_bin", 57, 33, True)
    put("town_planter", 61, 27)
    put("town_crates", 85, 27, True)
    put("town_barrel", 77, 27, True)
    put("town_planter", 45, 44)
    put("town_planter", 53, 44)
    put("town_bike_rack", 53, 45)
    lamps = [[46, 33], [54, 33], [62, 33], [70, 33], [78, 33], [86, 33], [26, 17], [44, 17], [26, 43], [44, 43], [20, 15], [60, 15], [30, 48], [60, 48]]
    for p in lamps:
        put("town_streetlamp", p[0], p[1], True, lamp=True)
    # The seasons on Main Street: bunting in summer, lights in winter, hung
    # between the shops; pumpkins on doorsteps in autumn.
    for x in (54, 62, 70, 77):
        put("town_bunting", x, 29, lift=40, no_shadow=True, seasons=["summer"])
        put("town_string_lights", x, 29, lift=40, no_shadow=True, seasons=["winter"])
    for b in out_buildings:
        if b["id"].startswith("house_") and b["pos"][1] < 20:
            put("town_pumpkins", b["door"][0] + 1.5, 13, seasons=["autumn"])

    # Backyards behind the north houses: a picket fence behind the west
    # three, a hedge behind the mayor's, a stone wall behind the east three.
    def run(piece, end, x0, x1, y, step):
        blocks = [[x, y] for x in range(x0, x1 + 1)]
        x = x0 + step / 2.0 - 0.5
        first = True
        while x <= x1 + 0.01:
            o = {"sprite": piece, "pos": [round(x, 4), y], "solid": False}
            if first:
                o["blocks"] = blocks
                first = False
            objects.append(o)
            x += step
        objects.append({"sprite": end, "pos": [x1 + 0.5, y], "solid": False})

    # Steps are each piece's width in tiles (36, 36 and 33 pixels since
    # 0.6.9); the hedge and wall overlap by 2 pixels so their rounded ends
    # leave no gaps.
    run("town_picket", "town_picket_post", 8, 27, 3, 2.25)
    run("town_hedge", "town_hedge_end", 45, 52, 3, 2.125)
    run("town_stone_wall", "town_stone_wall_end", 53, 74, 3, 1.9375)
    for sprite, x, y in (
            ("town_clothesline", 10, 5), ("town_rain_barrel", 12, 6),                                  # the Pelletiers
            ("town_birdbath", 16, 5), ("town_flower_bed", 18, 6), ("town_bush_flowering", 19, 4),     # Bev
            ("town_garden_bench", 23, 5), ("town_flower_bed", 25, 6), ("town_bush_medium", 26, 4),    # Agnes
            ("town_birdbath", 48, 5), ("town_bush_small", 46, 5), ("town_bush_small", 51, 5),         # the mayor
            ("town_veg_bed", 55, 5), ("town_wheelbarrow", 57, 6),                                       # the Abernathys
            ("town_veg_bed", 62, 5), ("town_rain_barrel", 65, 6),                                       # the Mendozas
            ("town_crates", 69, 5), ("town_wheelbarrow", 71, 6),                                        # Gus
            ("town_flower_bed", 9, 38), ("town_garden_bench", 11, 38)):                                # Sol
        # The washing line is a line and two posts: no block of shadow.
        put(sprite, x, y, True, **({"no_shadow": True} if sprite == "town_clothesline" else {}))
    for b in out_buildings:
        if b["id"].startswith("house_"):
            put("town_house_mailbox", b["pos"][0] - 1, b["pos"][1] + b["size"][1] - 1)
    # The creek's banks: reeds, stones and lily pads.
    for x in (10, 35, 47, 66, 80):
        put("town_reeds", x, creek_top[x], no_shadow=True)
    for x in (14, 58, 73):
        put("town_reeds", x, creek_top[x] + 3, no_shadow=True)
    put("town_lily_pads", 40, creek_top[40] + 1.3, flat=True)
    put("town_lily_pads", 70, creek_top[70] + 1.5, flat=True)
    put("town_creek_stones", 52, creek_top[52] + 1.4, flat=True)
    put("town_creek_stones", 84, creek_top[84] + 1.6, flat=True)

    places = {b["id"]: b["front"] for b in out_buildings}
    places.update({
        "square_bench": [36, 37],
        "square_green": [35, 22],
        "bandstand_front": [35, 32],
        "notice_board": [43, 35],
        "creek_path": [41, 48],
        "creek_bridge": [22, 48],
        "main_street": [70, 31],
        "park_road": [85, 30],
        "lane_east": [76, 14],
        "garden_pip": [56, 15],
    })
    solid = set()
    for b in out_buildings:
        for y in range(b["pos"][1], b["pos"][1] + b["size"][1]):
            for x in range(b["pos"][0], b["pos"][0] + b["size"][0]):
                solid.add((x, y))
    for o in objects:
        if o["solid"]:
            solid.add((math.floor(o["pos"][0]), math.floor(o["pos"][1])))
        for b in o.get("blocks", []):
            solid.add(tuple(b))
    # Grass tufts and wildflowers scattered on open lawn, lying flat.
    taken = set(solid) | {tuple(p) for p in places.values()}
    for i in range(260):
        x, y = rng.randrange(3, W - 3), rng.randrange(3, H - 3)
        if g[y][x] != "l" or (x, y) in taken:
            continue
        taken.add((x, y))
        kind = "town_tuft_%d" % rng.randint(1, 4) if rng.random() < 0.75 else "town_flowers_" + rng.choice(["white", "yellow", "blue", "pink"])
        objects.append({"sprite": kind, "pos": [x + rng.choice([0, 0.25, 0.5]), y + rng.choice([0, 0.25, 0.5])], "solid": False, "flat": True})
    for name, (x, y) in places.items():
        assert (x, y) not in solid and g[y][x] != "w", "place %s at %d,%d is not walkable" % (name, x, y)
    data = {
        "note": "Baked by tools/bake_town.py. Do not edit by hand.",
        "size": [W, H],
        "ground": ["".join(r) for r in g],
        "ground_art": {"l": "town_grass", "d": "town_lawn_dark", "c": "town_cobbles", "g": "town_gravel", "p": "town_paving", "f": "town_flowerbed", "b": "town_boards", "s": "town_shallows", "w": "town_water"},
        "solid_grounds": ["w"],
        "buildings": out_buildings,
        "objects": objects,
        "places": places,
        "entry": [86.5, 30.5],
        "exit_x": 89.2,
    }
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print("wrote", os.path.relpath(OUT, ROOT), "%d buildings, %d objects, %d places" % (len(out_buildings), len(objects), len(places)))


if __name__ == "__main__":
    main()
