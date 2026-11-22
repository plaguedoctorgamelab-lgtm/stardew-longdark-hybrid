"""Bakes Humdrum, the town outside the park gate (Phase 4 Spec, 4a step 1),
into data/world/town.json.

The layout is written here by hand: about 90 by 60 tiles, snug. Main Street
runs west from the park road to the square; a north lane holds most of the
houses; Creek Lane holds the library, Town Hall and the painter's house;
Dusk Creek runs along the south with a footbridge to the fortune teller's
caravan. Every building's door is in the middle of its bottom row, facing the
street, as everywhere in the game.

Ground codes: l lawn, c cobbles, g gravel, f flower bed, b boards, s shallow
water, w deep water. Deep water, buildings and the border trees are solid.

Run: python tools/bake_town.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "world", "town.json")
W, H = 90, 60


def main():
    g = [["l"] * W for _ in range(H)]

    def fill(x0, y0, x1, y1, code):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                g[y][x] = code

    # Main Street, from the park road (east) to the square.
    fill(44, 28, 89, 32, "c")
    # The square: a cobbled ring round a green.
    fill(26, 18, 44, 42, "c")
    fill(29, 21, 41, 39, "l")
    # Lanes, and the paths joining them.
    fill(6, 13, 80, 14, "g")
    fill(6, 46, 80, 47, "g")
    fill(6, 13, 7, 47, "g")
    fill(33, 15, 36, 17, "c")
    fill(33, 43, 36, 45, "c")
    # Dusk Creek, and its footbridge to the caravan on the far bank.
    fill(2, 49, 87, 49, "s")
    fill(2, 50, 87, 51, "w")
    fill(2, 52, 87, 52, "s")
    fill(21, 48, 23, 53, "b")
    fill(21, 54, 23, 57, "g")
    fill(23, 56, 27, 57, "g")
    # Flower beds by the square and the library.
    for x0, y0 in ((27, 19), (42, 19), (27, 40), (42, 40), (45, 47), (53, 47)):
        fill(x0, y0, x0 + 1, y0, "f")

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
        ("bandstand", "town_bandstand", (32, 25), (7, 6)),
    ]
    out_buildings = []
    for bid, sprite, (px, py), (sw, sh) in buildings:
        door = [px + sw // 2, py + sh - 1]
        out_buildings.append({"id": bid, "sprite": sprite, "pos": [px, py], "size": [sw, sh], "door": door,
                              "front": [door[0], door[1] + 1]})

    objects = []
    # Border trees, with the park road's gap on the east.
    for x in range(0, W, 2):
        for y in (1, H - 1):
            objects.append({"sprite": "obj_tree_pine" if (x // 2) % 3 else "obj_tree_oak", "pos": [x, y], "solid": True})
    for y in range(3, H - 2, 2):
        objects.append({"sprite": "obj_tree_fir" if (y // 2) % 2 else "obj_tree_pine", "pos": [0, y], "solid": True})
        if not 26 <= y <= 34:
            objects.append({"sprite": "obj_tree_oak" if (y // 2) % 2 else "obj_tree_pine", "pos": [88, y], "solid": True})
    # Trees on the lawns, and the willow over the caravan.
    for x, y in ((52, 36), (58, 38), (66, 35), (74, 37), (82, 36), (14, 22), (18, 30), (10, 34), (20, 38), (64, 17), (76, 17), (40, 55), (60, 55), (75, 55)):
        objects.append({"sprite": "obj_tree_maple" if (x + y) % 2 else "obj_tree_oak", "pos": [x, y], "solid": True})
    objects.append({"sprite": "obj_tree_birch", "pos": [29, 54], "solid": True})
    # The square's things: notice board and benches.
    objects.append({"sprite": "town_notice_board", "pos": [43, 34], "solid": True, "id": "notice_board"})
    objects.append({"sprite": "obj_bench", "pos": [35, 38], "solid": False})
    objects.append({"sprite": "obj_bench", "pos": [38, 38], "solid": False})
    objects.append({"sprite": "obj_bench", "pos": [40, 48], "solid": False})
    lamps = [[46, 33], [54, 33], [62, 33], [70, 33], [78, 33], [86, 33], [26, 17], [44, 17], [26, 43], [44, 43], [20, 15], [60, 15], [30, 48], [60, 48]]
    for p in lamps:
        objects.append({"sprite": "town_streetlamp", "pos": p, "solid": True, "lamp": True})

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
            solid.add(tuple(o["pos"]))
    for name, (x, y) in places.items():
        assert (x, y) not in solid and g[y][x] != "w", "place %s at %d,%d is not walkable" % (name, x, y)
    data = {
        "note": "Baked by tools/bake_town.py. Do not edit by hand.",
        "size": [W, H],
        "ground": ["".join(r) for r in g],
        "ground_art": {"l": "town_lawn", "c": "town_cobbles", "g": "town_gravel", "f": "town_flowerbed", "b": "town_boards", "s": "ground_shallows", "w": "ground_deep_water"},
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
