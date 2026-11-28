"""Cuts Mark's Art Request 28 sheets (Phase 6, the whole forest) into game
pictures, with the same tools as cut_ar25.py.

Phase 6a uses G1 (the far bank's ground and trees), G2 (the canoe, the cart
and cart trail) and G3 (the wave 1 sites). The other sheets are cut when
their part is built.

His AR28 sheets have a real transparent background (a blurred picture sits
under alpha 0), so only alpha decides what's drawn.

Run: python -I tools/cut_ar28.py <folder with raw_ar28_G*.png>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_ar25 as C  # noqa: E402


def load(folder, tag, thr=200):
    s = C.Sheet(os.path.join(folder, "raw_ar28_%s.png" % tag))
    for k in range(3, len(s.px), 4):
        if s.px[k] < thr:
            s.px[k] = 0
    return s


def drawn_box(s, box):
    """The drawn part of a hand-placed box."""
    x0, y0, x1, y1 = box
    xs, ys = [], []
    for y in range(y0, y1):
        for x in range(x0, x1):
            if s.opaque(x, y):
                xs.append(x)
                ys.append(y)
    return [min(xs), min(ys), max(xs) + 1, max(ys) + 1]


def tiles(s, row, names_counts):
    """A row of 16 x 16 ground tiles: (name, how many) in order."""
    i = 0
    for name, n in names_counts:
        for k in range(n):
            b = row[i]
            i += 1
            # Trim the soft rim Mark's tiles have, then fill the tile.
            m = (b[2] - b[0]) // 14
            inner = [b[0] + m, b[1] + m, b[2] - m, b[3] - m]
            px = bytearray(16 * 16 * 4)
            C.shrink(s, inner, 16 / (inner[2] - inner[0]), 16, 16, px, 0, 0, 16)
            # A ground tile has no holes: any pixel the shrink left empty takes
            # its neighbour's colour.
            for y in range(16):
                for x in range(16):
                    j = (y * 16 + x) * 4
                    if px[j + 3] == 0:
                        for dx, dy in ((-1, 0), (0, -1), (1, 0), (0, 1)):
                            xx, yy = x + dx, y + dy
                            if 0 <= xx < 16 and 0 <= yy < 16 and px[(yy * 16 + xx) * 4 + 3]:
                                px[j:j + 4] = px[(yy * 16 + xx) * 4:(yy * 16 + xx) * 4 + 4]
                                break
                        else:
                            px[j:j + 4] = px[0:4]
            C.save("%s%s" % (name, "" if k == 0 else "_alt_%d" % k), 16, 16, px)


def do_G1(folder):
    s = load(folder, "G1_ground")
    rows = C.rows_of(C.pieces(s, 3))
    tiles(s, rows[0], [("ground_lake", 4), ("ground_ice", 4), ("ground_ice_edge", 4)])
    tiles(s, rows[1], [("ground_sandbar", 4), ("ground_fen", 4), ("ground_trail_snowed", 4)])
    t = rows[2]
    C.cut_piece(s, t[0], "obj_sign_closed_winter", 16, 32)
    for b, n in zip(t[1:4], ["obj_tree_birch", "obj_tree_birch_autumn", "obj_tree_birch_winter"]):
        C.cut_piece(s, b, n, 32, 48)
    C.cut_piece(s, t[4], "obj_tree_hemlock", 32, 64)
    C.cut_piece(s, t[5], "obj_tree_hemlock_winter", 32, 64)


def mirror(px, w, h):
    out = bytearray(len(px))
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            j = (y * w + (w - 1 - x)) * 4
            out[j:j + 4] = px[i:i + 4]
    return out


def sheet_rows(s, frames, fw, fh, name, flip_rows=()):
    """frames: one list of boxes per facing row (down, right, up, left); one
    scale for all. Rows in flip_rows are drawn mirrored (left from right)."""
    allb = [b for r in frames for b in r]
    sc = min(fw / max(b[2] - b[0] for b in allb), fh / max(b[3] - b[1] for b in allb))
    cols = max(len(r) for r in frames)
    w, h = cols * fw, len(frames) * fh
    px = bytearray(w * h * 4)
    for ry, r in enumerate(frames):
        for cx, b in enumerate(r):
            one = bytearray(fw * fh * 4)
            C.shrink(s, b, sc, fw, fh, one, 0, 0, fw)
            if ry in flip_rows:
                one = mirror(one, fw, fh)
            for y in range(fh):
                j = ((ry * fh + y) * w + cx * fw) * 4
                px[j:j + fw * 4] = one[y * fw * 4:(y + 1) * fw * 4]
    C.save(name, w, h, px)


def do_G2(folder):
    s = load(folder, "G2_vehicles")
    rows = C.rows_of(C.pieces(s, 6))
    a, b, c, d = rows
    # The canoe: down, right, up, left (Mark drew every facing).
    sheet_rows(s, [a[0:2], a[2:4], b[0:2], b[2:4]], 32, 32, "ranger_canoe")
    C.cut_piece(s, a[4], "obj_canoe_beached", 32, 16)
    C.cut_piece(s, b[4], "item_canoe_kit", 32, 32)
    # The cart: one frame a facing.
    sheet_rows(s, [[c[0]], [c[1]], [c[2]], [c[3]]], 32, 32, "vehicle_cart")
    C.cut_piece(s, c[4], "obj_cart_broken", 32, 32)
    tiles(s, d, [("ground_cart_trail", 6)])


G3_BOXES = {
    "building_bridge_mended": [10, 10, 640, 280],
    "obj_toll_box": [650, 80, 750, 225],
    "building_boathouse_broken": [780, 10, 1140, 278],
    "building_boathouse_repaired": [1160, 10, 1522, 278],
    "obj_dock": [10, 350, 322, 475],
    "building_sawmill_broken": [330, 282, 725, 482],
    "building_sawmill_repaired": [750, 282, 1180, 482],
    "obj_rail_track": [1190, 380, 1520, 470],
    "obj_plank_pile": [10, 560, 378, 725],
    "building_hollow_giant_broken": [360, 485, 885, 755],
    "building_hollow_giant_repaired": [902, 485, 1432, 755],
    "obj_beaver_dam": [10, 755, 505, 893],
    "obj_beaver_lodge": [565, 755, 955, 890],
    "obj_boardwalk": [980, 755, 1520, 893],
}
G3_SIZES = {
    "building_bridge_mended": (96, 48), "obj_toll_box": (16, 16),
    "building_boathouse_broken": (80, 64), "building_boathouse_repaired": (80, 64),
    "obj_dock": (32, 16), "building_sawmill_broken": (96, 64), "building_sawmill_repaired": (96, 64),
    "obj_rail_track": (32, 16), "obj_plank_pile": (32, 16),
    "building_hollow_giant_broken": (96, 128), "building_hollow_giant_repaired": (96, 128),
    "obj_beaver_dam": (48, 24), "obj_beaver_lodge": (32, 24), "obj_boardwalk": (48, 16),
}


def do_G3(folder):
    s = load(folder, "G3_wave1")
    for name, box in G3_BOXES.items():
        fw, fh = G3_SIZES[name]
        C.cut_piece(s, drawn_box(s, box), name, fw, fh)
    # The beaver: one side row (stand, swim x3, gnaw, rest) for every facing.
    row = C.rows_of(C.pieces(s, 6))[-1]
    sheet_rows(s, [row, row, row], 16, 16, "animal_beaver")


def main():
    folder = sys.argv[1]
    do_G1(folder)
    do_G2(folder)
    do_G3(folder)


if __name__ == "__main__":
    main()
