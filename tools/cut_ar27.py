"""Cuts Mark's Art Request 27 sheets (the new festivals and the birds)
into game pictures, with the same tools as cut_ar25.py.

His AR27 sheets are drawn on a flat cream background, so the background
test is swapped for a cream one before cutting.

Run: python -I tools/cut_ar27.py <folder with raw_ar27_B_birds.png and raw_ar27_F_festivals.png> [--list]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_ar25 as C  # noqa: E402


def cream(c):
    r, g, b, a = c
    return a < 128 or (r >= 232 and g >= 218 and b >= 180 and r >= g >= b - 6 and r - b <= 70)


C.is_bg = cream


def load(path, gap):
    s = C.Sheet(path)
    C.clear_background(s)
    return s, C.rows_of(C.pieces(s, gap))


BIRDS = ["animal_crow", "animal_owl", "animal_blue_jay", "animal_cardinal", "creature_magic_crow", "creature_magic_owl"]
# The bird rows touch, so they're cut by grid: 18 rows (6 birds x down,
# right, up) and 6 columns (standing, fly 1-3, pecking, perched).
BIRD_YS = [0, 66, 136, 211, 283, 352, 423, 494, 562, 637, 709, 777, 855, 920, 986, 1057, 1121, 1180, 1250]
BIRD_XS = [120, 250, 390, 535, 665, 800, 920]


def cell_box(s, x0, y0, x1, y1):
    pts = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if s.opaque(x, y)]
    if not pts:
        return None
    return [min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts) + 1, max(p[1] for p in pts) + 1]


def keep_only(name, test):
    """A copy of art/final/<name>.png with only the pixels test() likes."""
    w, h, px = C.read_png(os.path.join(C.FINAL, name + ".png"))
    px = bytearray(px)
    out = bytearray(len(px))
    for k in range(0, len(px), 4):
        r, g, b, a = px[k:k + 4]
        y = (k // 4) // w % 16
        if a and test(r, g, b, y):
            out[k:k + 4] = px[k:k + 4]
    C.save(name + "_glow", w, h, out)


def do_birds(s, rows):
    grid = []
    for r in range(18):
        grid.append([cell_box(s, BIRD_XS[c], BIRD_YS[r], BIRD_XS[c + 1], BIRD_YS[r + 1]) for c in range(6)])
    for k, name in enumerate(BIRDS):
        C.cut_animal(s, grid[k * 3:k * 3 + 3], name, 16, 16)
    # Glow: the crow's stars are its pale pixels; the owl's eyes are the
    # gold ones above its feet.
    keep_only("creature_magic_crow", lambda r, g, b, y: (r + g + b) / 3 > 150)
    keep_only("creature_magic_owl", lambda r, g, b, y: r > 190 and g > 140 and b < 110 and y < 12)
    sk = rows[-2]
    for b, n in zip(sk, ["crow", "owl", "blue_jay", "cardinal", "magic_crow", "magic_owl"]):
        C.sketch(s, b, "sketch_" + n, 32, 32)
    fe = [b for b in rows[-1] if b[2] - b[0] > 20]
    for b, n in zip(fe[:6], ["crow", "owl", "blue_jay", "cardinal", "magic_crow", "magic_owl"]):
        C.cut_piece(s, b, "item_feather_" + n, 16, 16)
    C.cut_piece(s, fe[6], "guide_tab_birds", 16, 16)


def do_festivals(s, rows):
    m = rows[0]
    # The cream showing between the moose's legs is shut in by the
    # platform, so the flood can't reach it: clear it by colour (the paper
    # wishes are yellower, so they stay).
    for b in m[0:4]:
        for y in range(b[1], b[3]):
            for x in range(b[0], b[2]):
                r_, g_, b_, a_ = s.rgba(x, y)
                if r_ >= 246 and g_ >= 232 and 200 <= b_ <= 228:
                    s.clear(x, y)
    # The moose and its three burning stages share one scale.
    sc = min(min(64 / (b[2] - b[0]), 96 / (b[3] - b[1])) for b in m[0:4])
    for k, n in enumerate(["fest_wicker_moose", "fest_wicker_moose_burn_0", "fest_wicker_moose_burn_1", "fest_wicker_moose_burn_2"]):
        px = bytearray(64 * 96 * 4)
        C.shrink(s, m[k], sc, 64, 96, px, 0, 0, 64)
        C.save(n, 64, 96, px)
    C.cut_piece(s, m[4], "fest_wicker_moose_embers", 64, 32)
    a = rows[1]
    C.cut_piece(s, a[0], "fest_wish_tag", 8, 12)
    C.cut_piece(s, a[1], "fest_garland_summer", 48, 16)
    C.cut_piece(s, a[2], "fest_flower_crown", 16, 10)
    C.cut_piece(s, a[3], "decor_wicker_moose", 24, 24)
    C.cut_piece(s, a[4], "fest_pumpkin", 16, 16)
    b = rows[2]
    for k, face in enumerate(["friendly", "spooky", "silly", "cat", "moose"]):
        C.cut_piece(s, b[k], "fest_jack_o_lantern_" + face, 16, 16)
    C.cut_piece(s, b[5], "fest_carving_table", 48, 32)
    C.cut_piece(s, b[6], "fest_apple_tub", 32, 24)
    C.cut_piece(s, b[7], "fest_sweets_bowl", 16, 24)
    bowl = list(b[7])
    bowl[3] = bowl[1] + int((bowl[3] - bowl[1]) * 0.52)
    C.cut_piece(s, bowl, "item_sweets", 32, 32)
    c = rows[3]
    C.cut_piece(s, c[0], "fest_garland_samhain", 48, 16)
    C.cut_piece(s, c[1], "fest_scarecrow", 32, 48)
    C.cut_piece(s, c[2], "fest_corn_stalks", 24, 32)
    C.cut_piece(s, c[3], "decor_ribbon_samhain", 16, 24)
    d = rows[4]
    C.cut_piece(s, d[0], "fest_supper_table_snow", 64, 40)
    C.cut_piece(s, d[1], "fest_supper_bench_snow", 64, 32)
    # Four frames of flame, so the square animates them (fest_brazier_0..3).
    sc = min(min(16 / (b[2] - b[0]), 32 / (b[3] - b[1])) for b in d[2:6])
    for k, b in enumerate(d[2:6]):
        px = bytearray(16 * 32 * 4)
        C.shrink(s, b, sc, 16, 32, px, 0, 0, 16)
        C.save("fest_brazier_%d" % k, 16, 32, px)
    C.cut_piece(s, d[6], "fest_spruce_lights", 32, 48)
    C.cut_piece(s, d[7], "fest_willow_jar", 16, 24)


def main():
    folder = sys.argv[1]
    listing = "--list" in sys.argv
    for tag, gap in [("B_birds", 4), ("F_festivals", 2)]:
        s, rows = load(os.path.join(folder, "raw_ar27_%s.png" % tag), gap)
        if listing:
            print(tag)
            for r in rows:
                print(" ", len(r), [b[:4] for b in r])
            continue
        (do_birds if tag == "B_birds" else do_festivals)(s, rows)


if __name__ == "__main__":
    main()
