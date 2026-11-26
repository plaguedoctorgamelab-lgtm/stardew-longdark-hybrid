"""Cuts Mark's Art Request 25 Part B sheets (Gord and the night) and his
Art Request 26 sheets into game pictures, with the same tools as
cut_ar25.py.

Run: python -I tools/cut_ar25b_26.py <folder with ar25_B*.png and ar26_C*.png>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cut_ar25 as C  # noqa: E402


def by_rows(boxes, ys):
    """Boxes into rows by their centre's height (ys: row edges), each
    left to right."""
    rows = [[] for _ in range(len(ys) - 1)]
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        for k in range(len(ys) - 1):
            if ys[k] <= cy < ys[k + 1]:
                rows[k].append(b)
    return [sorted(r, key=lambda b: b[0]) for r in rows]


def split(b, n):
    """A box cut into n equal columns."""
    w = (b[2] - b[0]) / n
    return [[int(b[0] + k * w), b[1], int(b[0] + (k + 1) * w), b[3]] for k in range(n)]


def do_B1(s, rows):
    C.cut_animal(s, rows[0:3], "creature_gord_moose", 48, 48)
    rest = rows[3] + rows[4]
    ys = [500, 647, 765, 892, 1020]
    man = by_rows([b for b in rest if b[0] < 420], ys)
    # The dressed-up frames touch top to bottom, so they're cut by grid.
    dressed = C.grid_rows(s, [512, 644, 764, 890, 1014], [446, 541, 629, 719, 812], inset=2)
    C.cut_animal(s, man, "npc_gord", 16, 32)
    C.cut_animal(s, dressed, "npc_gord_dressed", 16, 32)
    faces = sorted([b for b in rest if b[0] >= 830 and b[0] < 1300], key=lambda b: (b[1] > 750, b[0]))
    for b, mood in zip(faces, ["neutral", "happy", "sad", "surprised"]):
        C.cut_piece(s, b, "portrait_gord_" + mood, 64, 64)
    C.cut_piece(s, [b for b in rest if b[0] >= 1300][0], "obj_gord_meadow_sign", 16, 32)


def do_B2(s, rows):
    r = rows[0]
    C.cut_piece(s, r[0], "ui_paw_heart_full", 8, 8)
    C.cut_piece(s, r[1], "ui_paw_heart_empty", 8, 8)
    C.cut_piece(s, r[2], "job_kind_creature_clip", 16, 16)
    C.cut_piece(s, r[3], "job_kind_creature", 16, 16)
    # The gift is drawn on a cabin step: keep the whole square as drawn.
    C.cut_piece(s, r[4], "obj_creature_gift_scene", 32, 32)


def do_B3(s, rows):
    for b, n in zip(rows[0], ["stamp_secret", "stamp_hint", "stamp_public"]):
        C.cut_piece(s, b, n, 24, 24)
    C.cut_piece(s, rows[1][0], "brochure_creature", 64, 48)


def do_B4(s, rows):
    C.cut_piece(s, rows[0][0], "ui_cal_moon", 12, 12)
    C.cut_piece(s, rows[0][1], "ui_cal_event", 12, 12)
    C.cut_frames(s, rows[1], "hud_moon", 12, 12)


def do_B5(s, rows):
    w, h = 480, 64
    px = bytearray(w * h * 3 * 4)
    for k in range(3):
        one = bytearray(w * h * 4)
        b = rows[k][0]
        sc = min(w / (b[2] - b[0]), h / (b[3] - b[1]))
        C.shrink(s, b, sc, w, h, one, 0, 0, w)
        px[k * w * h * 4:(k + 1) * w * h * 4] = one
    C.save("sky_aurora", w, h * 3, px)
    names = ["badge_guide_10", "badge_guide_half", "badge_guide_animals", "badge_guide_strange", "badge_photo_night",
             "badge_photo_fog", "badge_photo_aurora", "badge_creature_settled", "badge_creature_friend", "badge_gord_coffee"]
    cells = split(rows[3][0], 5) + split(rows[4][0], 5)
    for b, n in zip(cells, names):
        C.cut_piece(s, b, n, 32, 32)


def do_C1(s, rows):
    a, b = rows
    C.cut_piece(s, a[0], "job_pic_creature", 32, 32)
    C.cut_piece(s, a[1], "job_type_creature", 16, 16)
    C.cut_piece(s, a[2], "obj_burrow", 16, 16)
    C.cut_piece(s, a[3], "obj_burrow_filled", 16, 16)
    C.cut_piece(s, b[0], "obj_trail_food", 16, 16)
    C.cut_piece(s, b[1], "obj_offering_stone", 16, 16)
    C.cut_piece(s, b[2], "obj_offering_stone_full", 16, 16)
    # The moon has a soft magenta glow round it: keep only the pale disc.
    x0, y0, x1, y1 = b[3][:4]
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, bb, al = s.rgba(x, y)
            if al < 200 or (r > 150 and bb > 150 and g < 120):
                s.clear(x, y)
    C.cut_piece(s, b[3], "sky_full_moon", 32, 32)


def do_C2(s, rows):
    r = rows[0]
    C.cut_piece(s, r[0], "portrait_cryptid_hunter", 64, 64)
    C.cut_frames(s, [r[1], r[2]], "npc_cafe_regular_sit", 16, 32)
    C.cut_piece(s, r[3], "obj_percolator_late", 16, 16)


def do_C3(s, rows):
    a, chips = rows
    C.cut_piece(s, a[0], "fortune_card_aurora", 48, 72)
    C.cut_piece(s, a[1], "log_creatures", 48, 16)
    C.cut_piece(s, a[2], "obj_creature_gift", 16, 16)
    C.cut_piece(s, a[2], "log_creature_gift", 16, 16)
    for b, n in zip(chips, ["chip_aurora", "chip_loves", "chip_likes", "chip_wont"]):
        C.cut_piece(s, b, n, 8, 8)


def main():
    folder = sys.argv[1]
    for tag in ["B1_gord", "B2_friendship", "B3_secret_public", "B4_moon_calendar", "B5_aurora_badges"]:
        s, rows = C.load(folder, tag, False, 6)
        globals()["do_" + tag[:2]](s, rows)
    for tag in ["C1_creature_jobs", "C2_people", "C3_guide_log"]:
        s = C.Sheet(os.path.join(folder, "ar26_%s.png" % tag))
        # Mark's AR26 sheets come with a real transparent background.
        for k in range(3, len(s.px), 4):
            if s.px[k] < 128:
                s.px[k] = 0
        globals()["do_" + tag[:2]](s, C.rows_of(C.pieces(s, 6)))


if __name__ == "__main__":
    main()
