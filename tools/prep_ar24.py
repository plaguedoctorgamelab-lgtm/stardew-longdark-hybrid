"""Gets Mark's Art Request 24 sheets ready for art_cleanup.py.

The sheets are large drafts on a cream background, some fenced by drawn grid
lines, with each piece's name written under it. For each sheet this:
  1. clears the background and the grid lines (a flood from the edges and
     the lines through background-coloured pixels, so the cream inside a
     piece's outline stays);
  2. finds the pieces row by row: each row band (BANDS: the pieces'
     heights, the names written below left out) is split into its count of
     pieces at the widest empty gaps, or a piece's box is given outright,
     and each box is trimmed to what's drawn in it;
  3. writes the cleared sheet to art/raw/raw_ar24_<X>.png and the pieces'
     boxes, in label order, to tools/ar24_boxes.json.

The names come from AR24's lists in reading order (left to right, top to
bottom); the lab checks the cut pieces by eye.

Run: python -I tools/prep_ar24.py <folder with ar24_*.png>
"""
import json
import os
import sys
from collections import deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art", "raw")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ar24_boxes.json")

NAMES = {
    "A_sheet": ["ui_mount", "ui_label_strip", "ui_badge", "ui_tile_red", "ui_itab", "ui_itab_open", "ui_stamp_round", "ui_stamp_round_hover",
                "ui_stamp_round_pressed", "ui_key", "ui_key_wide", "ui_mouse_left", "ui_mouse_right", "ui_mouse_wheel", "ui_chip", "ui_toast_idea", "ui_mapped_bar"],
    "B_facts": ["icon_energy", "icon_warmth", "icon_speed", "icon_rest", "icon_carry", "icon_light", "icon_time", "icon_walk",
                "icon_coin", "icon_coins_up", "icon_coins_down", "icon_marks_map", "icon_have", "icon_short", "icon_lock", "icon_unknown"],
    "C_verbs": ["verb_talk", "verb_open", "verb_pick", "verb_use", "verb_read", "verb_sit", "verb_sleep", "verb_buy",
                "verb_give", "verb_dig", "verb_water", "verb_cook", "verb_make"],
    "D_make": ["station_hands", "station_workbench", "station_campfire", "station_range", "kind_tools",
               "kind_building", "kind_food", "kind_refits", "kind_decor", "kind_garden"],
    "E_town": ["icon_cake", "icon_gift_love", "icon_gift_like", "icon_gift_dislike", "icon_where"],
    "F_logbook": ["log_visitors", "log_party", "log_arriving", "log_site", "log_litter", "log_staff",
                  "log_id_card", "log_bar", "log_card", "log_card_big", "log_stamp_done", "log_envelope", "log_envelope_open",
                  "log_letter_paper", "log_note_yellow", "log_note_green", "log_note_blue", "log_note_purple", "log_note_big",
                  "doodle_footprint", "doodle_paw", "doodle_mug", "doodle_ribbon", "doodle_sign", "doodle_eye", "doodle_tracks", "doodle_question", "doodle_star",
                  "log_sky_clear", "log_sky_cloud", "log_sky_rain", "log_sky_snow", "log_sky_fog"],
    "G_shops": ["clip_percolator", "clip_outfitters", "clip_gifts", "shop_sold_out", "clip_carpentry", "clip_library", "clip_casa_luna"],
    "H_clips": ["clip_pack", "clip_jobs", "clip_map", "clip_town", "clip_make", "clip_log", "clip_chest"],
}
BANDS = {
    "A_sheet": [(15, 236, 4), (300, 458, 4), (510, 664, 4), (725, 862, 3, (0, 1080)), ("box", (1090, 700, 1425, 910)), (900, 1040, 1, (0, 1000))],
    "B_facts": [(55, 305, 4), (370, 622, 4), (705, 922, 4), (1005, 1205, 4)],
    "C_verbs": [(40, 268, 4), (360, 588, 4), (665, 888, 4), (985, 1185, 1)],
    "D_make": [(50, 360, 5), (450, 760, 5)],
    "E_town": [(100, 560, 5)],
    "F_logbook": [(0, 150, 6), (195, 413, 7), ("box", (28, 462, 402, 698)), ("box", (440, 510, 562, 641)), ("box", (598, 510, 722, 641)), ("box", (758, 510, 882, 641)), ("box", (916, 510, 1042, 641)), ("box", (1078, 458, 1508, 698)), (735, 836, 9), (875, 977, 5)],
    "G_shops": [(40, 435, 3, (0, 1260)), ("box", (1290, 405, 1515, 560)), (520, 915, 3, (0, 1260))],
    "H_clips": [(100, 455, 4), (560, 918, 3)],
}
BG_TOL = 34       # how near the cream a pixel must be to count as background


def lum(p):
    return (p[0] * 3 + p[1] * 6 + p[2]) // 10


def dist(a, b):
    return max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]))


def prep(path, key):
    w, h, px = read_png(path)
    px = bytearray(px)
    get = lambda x, y: px[(y * w + x) * 4:(y * w + x) * 4 + 4]
    corners = [get(2, 2), get(w - 3, 2), get(2, h - 3), get(w - 3, h - 3)]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))
    # Grid lines: rows or columns that are mostly dark.
    line_rows = {y for y in range(h) if sum(1 for x in range(0, w, 4) if lum(get(x, y)) < 130) > (w // 4) * 0.55}
    line_cols = {x for x in range(w) if sum(1 for y in range(0, h, 4) if lum(get(x, y)) < 130) > (h // 4) * 0.55}
    clear = bytearray(w * h)        # 1 = background or line: made see-through

    def bgish(x, y):
        return dist(get(x, y), bg) <= BG_TOL

    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            q.append((x, y))
    for y in line_rows:
        for x in range(w):
            q.append((x, y))
    for x in line_cols:
        for y in range(h):
            q.append((x, y))
    # Lines a pixel or two either side of the detected ones are line too.
    near_line = set()
    for y in line_rows:
        for d in (-3, -2, -1, 1, 2, 3):
            if 0 <= y + d < h and lum(get(w // 2, y + d)) < 170:
                near_line.add(("r", y + d))
    for x in line_cols:
        for d in (-3, -2, -1, 1, 2, 3):
            if 0 <= x + d < w and lum(get(x + d, h // 2)) < 170:
                near_line.add(("c", x + d))
    extra_rows = {v for k, v in near_line if k == "r"} | line_rows
    extra_cols = {v for k, v in near_line if k == "c"} | line_cols
    while q:
        x, y = q.popleft()
        i = y * w + x
        if clear[i]:
            continue
        if not (bgish(x, y) or y in extra_rows or x in extra_cols):
            continue
        clear[i] = 1
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not clear[ny * w + nx]:
                q.append((nx, ny))
    for i in range(w * h):
        if clear[i]:
            px[i * 4 + 3] = 0
    # Pieces: each row band (the pieces' heights, the names below left out)
    # is split into its count of pieces at the widest empty gaps; a box
    # given outright is used as it is. Each box is then trimmed to what's
    # drawn in it.
    names = NAMES[key]
    boxes = {}
    k = 0

    def solid_at(x, y):
        return px[(y * w + x) * 4 + 3] > 128

    def trim(x0, y0, x1, y1):
        xs, ys = [], []
        for y in range(max(0, y0), min(h, y1), 2):
            for x in range(max(0, x0), min(w, x1), 2):
                if solid_at(x, y):
                    xs.append(x)
                    ys.append(y)
        if not xs:
            return None
        return [min(xs), min(ys), max(xs) + 2, max(ys) + 2]

    for band in BANDS[key]:
        if band[0] == "box":
            boxes[names[k]] = trim(*band[1])
            k += 1
            continue
        y0, y1, count = band[:3]
        xa, xb = band[3] if len(band) > 3 else (0, w)
        cols = [any(solid_at(x, y) for y in range(y0, y1, 2)) for x in range(xa, xb)]
        runs, start = [], None
        for i, c in enumerate(cols + [False]):
            if c and start is None:
                start = i
            elif not c and start is not None:
                if i - start >= 3:
                    runs.append([start, i])
                start = None
        while len(runs) > count:
            gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
            j = gaps.index(min(gaps))
            runs[j] = [runs[j][0], runs[j + 1][1]]
            del runs[j + 1]
        if len(runs) < count:
            print("%s: band %s has %d pieces, expected %d" % (key, band[:3], len(runs), count))
        for r in runs:
            if k < len(names):
                boxes[names[k]] = trim(xa + r[0], y0, xa + r[1], y1)
                k += 1
    out_name = "raw_ar24_%s.png" % key
    write_png(os.path.join(RAW, out_name), w, h, bytes(px))
    return out_name, boxes


def main():
    src = sys.argv[1]
    result = {}
    for key in NAMES:
        name, boxes = prep(os.path.join(src, "ar24_%s.png" % key), key)
        missing = [n for n in NAMES[key] if boxes.get(n) is None]
        if missing:
            print("%s: no piece for %s" % (key, ", ".join(missing)))
        result[name] = boxes
        print(key, "done:", len([b for b in boxes.values() if b]), "pieces")
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=1)


if __name__ == "__main__":
    main()
