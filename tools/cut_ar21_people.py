"""Cuts Art Request 21's walking sheets and the ranger's clothes to game size.

Mark drew each person as a 4 x 4 block of frames (rows facing down, right,
up and left; a standing frame then three walking). A plain shrink would
scale each frame on its own, so a person would grow and shrink as they
walk. This tool gives every frame of a person one scale, stands their feet
on one row and lines their heads up, so the walk holds still.

The ranger's clothes Mark drew as garments on their own, not worn. This
tool fits each garment onto the ranger's own frames: a coat over the
jacket, boots over the boots, a toque on a ranger whose hat is taken off
(with Mark's bare-head hair in its place). Each comes out as an overlay
sheet the same shape as the ranger's.

It also cuts the three new walls (as 16 x 48 strips) and three new floors
(16 x 16) from sheet B8.

Writes, in art/raw/ (the art manifest cuts them pixel for pixel):
  raw_ar21_people_16.png  one 64 x 128 sheet per person, and the costume
  raw_ar21_wear_16.png    the ranger without a hat, and six overlays
  raw_ar21_walls_16.png   three 16 x 48 walls
  raw_ar21_floors_16.png  three 16 x 16 floors

Run: python tools/cut_ar21_people.py
"""
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art", "raw")
FINAL = os.path.join(ROOT, "art", "final")
ACUT = 200          # a sheet pixel this opaque counts as drawn
FW, FH = 16, 32     # a frame at game size
FEET = 31           # the row a person's feet stand on, as on Wren's sheet

# Each person: (sheet, block box [x0, y0, x1, y1], height in game pixels).
PEOPLE = [
    ("rosa", "raw_ar21_A1_rosa_teo_marge_nell.png", (130, 0, 600, 600), 26),
    ("teo", "raw_ar21_A1_rosa_teo_marge_nell.png", (700, 0, 1260, 600), 27),
    ("marge", "raw_ar21_A1_rosa_teo_marge_nell.png", (130, 610, 600, 1217), 26),
    ("nell", "raw_ar21_A1_rosa_teo_marge_nell.png", (700, 610, 1260, 1217), 27),
    ("agnes", "raw_ar21_A2_agnes_bev_gus_sol.png", (80, 0, 610, 595), 24),
    ("bev", "raw_ar21_A2_agnes_bev_gus_sol.png", (680, 0, 1240, 595), 26),
    ("gus", "raw_ar21_A2_agnes_bev_gus_sol.png", (80, 600, 620, 1217), 28),
    ("sol", "raw_ar21_A2_agnes_bev_gus_sol.png", (680, 600, 1240, 1217), 27),
    ("lyle", "raw_ar21_A3_lyle_esme_pip.png", (40, 0, 600, 809), 27),
    ("esme", "raw_ar21_A3_lyle_esme_pip.png", (680, 0, 1260, 809), 27),
    ("pip", "raw_ar21_A3_lyle_esme_pip.png", (1340, 0, 1942, 809), 22),
]
# The Big Foot costume: a 4 x 4 block among labels, so each frame has a box.
COSTUME_COLS = [(112, 250), (270, 410), (432, 572), (595, 735)]
COSTUME_ROWS = [(130, 340), (355, 565), (580, 790), (798, 1008)]

# The clothes sheet: each garment a 4 x 4 block.
WEAR = [
    ("wool_toque", (25, 10, 360, 370), "hat"),
    ("rain_shell", (385, 10, 720, 370), "coat"),
    ("wool_coat", (745, 10, 1075, 370), "coat"),
    ("down_parka", (20, 385, 360, 785), "parka"),
    ("waterproof_boots", (385, 385, 720, 785), "boots"),
    ("insulated_boots", (745, 385, 1075, 785), "boots"),
]
HAIR_BLOCK = (360, 795, 725, 1125)


class Sheet:
    def __init__(self, name):
        self.w, self.h, px = read_png(os.path.join(RAW, name))
        self.ch = len(px) // (self.w * self.h)
        self.px = px

    def get(self, x, y):
        i = (y * self.w + x) * self.ch
        a = self.px[i + 3] if self.ch == 4 else 255
        return self.px[i], self.px[i + 1], self.px[i + 2], a

    def solid(self, x, y):
        return self.get(x, y)[3] >= ACUT


def bbox(sh, box):
    x0, y0, x1, y1 = box
    xs, ys = [], []
    for y in range(y0, y1, 2):
        for x in range(x0, x1, 2):
            if sh.solid(x, y):
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs) + 2, max(ys) + 2


def runs(flags, gap=10):
    """Runs of True in a list, joining runs less than gap apart."""
    out = []
    for i, f in enumerate(flags):
        if not f:
            continue
        if out and i - out[-1][1] <= gap:
            out[-1][1] = i + 1
        else:
            out.append([i, i + 1])
    return out


def four(rs):
    """The four biggest runs, in order: a block's frame columns or rows."""
    rs = sorted(rs, key=lambda r: r[1] - r[0], reverse=True)[:4]
    return sorted(rs)


def grid_boxes(sh, block):
    """The 16 frames of an evenly laid-out block, by its 4 x 4 grid, each
    cropped to what is drawn in it (the clothes sheet)."""
    x0, y0, x1, y1 = block
    cw, chh = (x1 - x0) / 4.0, (y1 - y0) / 4.0
    return [bbox(sh, (int(x0 + c * cw), int(y0 + r * chh), int(x0 + (c + 1) * cw), int(y0 + (r + 1) * chh))) for r in range(4) for c in range(4)]


def frame_boxes(sh, block):
    """The 16 frames of a block: its four columns and four rows of drawing,
    found by where the drawing is, each frame cropped to what is in it."""
    x0, y0, x1, y1 = block
    cols = [any(sh.solid(x, y) for y in range(y0, y1, 3)) for x in range(x0, x1)]
    rows = [any(sh.solid(x, y) for x in range(x0, x1, 3)) for y in range(y0, y1)]
    cs = four(runs(cols))
    rs = four(runs(rows, 3))
    out = []
    for r in rs:
        for c in cs:
            out.append(bbox(sh, (x0 + c[0], y0 + r[0], x0 + c[1], y0 + r[1])))
    while len(out) < 16:
        out.append(None)
    return out


def sample(sh, x0, y0, x1, y1, clip=None):
    """The most common colour in a block of the sheet, if half of it is
    drawn. A clip box keeps it to one frame's own drawing."""
    votes = Counter()
    total = solid = 0
    sx = max(1, int((x1 - x0) // 5))
    sy = max(1, int((y1 - y0) // 5))
    for y in range(int(y0), max(int(y0) + 1, int(y1)), sy):
        for x in range(int(x0), max(int(x0) + 1, int(x1)), sx):
            if not (0 <= x < sh.w and 0 <= y < sh.h):
                continue
            total += 1
            if clip and not (clip[0] <= x < clip[2] and clip[1] <= y < clip[3]):
                continue
            r, g, b, a = sh.get(x, y)
            if a >= ACUT:
                solid += 1
                votes[(r >> 3, g >> 3, b >> 3)] += 1
    if votes and solid * 2 >= total:
        (r, g, b), _ = votes.most_common(1)[0]
        return (r * 8 + 4, g * 8 + 4, b * 8 + 4, 255)
    return None


def head_centre(sh, b):
    """Where the head is across: the middle of what is drawn in the top
    quarter of the frame, so a walking stride doesn't sway the body."""
    x0, y0, x1, y1 = b
    top = y0 + (y1 - y0) // 4
    xs = [x for y in range(y0, top, 2) for x in range(x0, x1, 2) if sh.solid(x, y)]
    return sum(xs) / len(xs) if xs else (x0 + x1) / 2


def person(sh, boxes, height):
    """A 64 x 128 sheet from 16 frame boxes, all at one scale."""
    tallest = max(b[3] - b[1] for b in boxes if b)
    s = tallest / float(height)
    out = [[None] * 64 for _ in range(128)]
    for k, b in enumerate(boxes):
        if b is None:
            continue
        fx, fy = (k % 4) * FW, (k // 4) * FH
        cx = head_centre(sh, b)
        for ty in range(FH):
            # Row ty of the frame shows sheet rows ending at the feet.
            sy0 = b[3] - (FEET + 1 - ty) * s
            if sy0 + s <= b[1] or sy0 >= b[3]:
                continue
            for tx in range(FW):
                sx0 = cx + (tx - FW / 2.0) * s
                p = sample(sh, sx0, sy0, sx0 + s, sy0 + s, b)
                if p:
                    out[fy + ty][fx + tx] = p
    return out


# --- the ranger's clothes ------------------------------------------------------

def ranger_frames():
    w, h, px = read_png(os.path.join(FINAL, "ranger.png"))
    frames = []
    for k in range(16):
        fx, fy = (k % 4) * FW, (k // 4) * FH
        f = [[None] * FW for _ in range(FH)]
        for y in range(FH):
            for x in range(FW):
                i = ((fy + y) * w + fx + x) * 4
                if px[i + 3] > 128:
                    f[y][x] = (px[i], px[i + 1], px[i + 2], 255)
        frames.append(f)
    return frames


def rows_span(f):
    ys = [y for y in range(FH) if any(f[y])]
    return ys[0], ys[-1]


def cols_in(f, y0, y1):
    xs = [x for y in range(y0, y1 + 1) for x in range(FW) if f[y][x]]
    return (min(xs), max(xs)) if xs else (4, 11)


def fit(sh, b, box, out):
    """Stretches a garment frame (sheet box b) over a frame box [x0, y0,
    x1, y1] (game pixels, inclusive) and lays it over out."""
    x0, y0, x1, y1 = box
    gw, gh = x1 - x0 + 1, y1 - y0 + 1
    sx = (b[2] - b[0]) / float(gw)
    sy = (b[3] - b[1]) / float(gh)
    for ty in range(gh):
        for tx in range(gw):
            p = sample(sh, b[0] + tx * sx, b[1] + ty * sy, b[0] + (tx + 1) * sx, b[1] + (ty + 1) * sy, b)
            if p and 0 <= y0 + ty < FH and 0 <= x0 + tx < FW:
                out[y0 + ty][x0 + tx] = p


def hat_rows(f):
    """The ranger's hat: the rows from the top down to the brim, found as
    the last of the top rows still mostly in the crown's colours."""
    t, _ = rows_span(f)
    crown = Counter(f[y][x][:3] for y in range(t, t + 3) for x in range(FW) if f[y][x])
    hat_cols = {c for c, _ in crown.most_common(4)}
    last = t + 2
    for y in range(t, t + 9):
        n = sum(1 for x in range(FW) if f[y][x] and f[y][x][:3] in hat_cols)
        if n >= 3:
            last = y
    return t, last, hat_cols


def wear(sheet, frames, hair_boxes):
    """The ranger without a hat, and an overlay sheet per garment."""
    sheets = {}
    # Without a hat: the hat's colours cleared from the top rows, and
    # Mark's bare-head hair laid where the hat was.
    nohat = []
    for k, f in enumerate(frames):
        g = [row[:] for row in f]
        t, last, hat_cols = hat_rows(f)
        for y in range(t, last + 1):
            for x in range(FW):
                if g[y][x] and (g[y][x][:3] in hat_cols or y < last - 1):
                    g[y][x] = None
        # Any outline left floating where the brim was goes too.
        for y in range(t, last + 1):
            for x in range(FW):
                if g[y][x] and not any(g[yy][xx] for yy, xx in ((y + 1, x), (y, x - 1), (y, x + 1)) if 0 <= yy < FH and 0 <= xx < FW):
                    g[y][x] = None
        hx0, hx1 = cols_in(f, last + 1, last + 3)
        if hair_boxes[k]:
            fit(sheet, hair_boxes[k], (hx0, last - 2, hx1, last + 3), g)
        nohat.append(g)
    sheets["ranger_nohat"] = nohat
    for name, block, kind in WEAR:
        boxes = grid_boxes(sheet, block)
        over = []
        for k, f in enumerate(frames):
            g = [[None] * FW for _ in range(FH)]
            t, b = rows_span(f)
            _, last, _ = hat_rows(f)
            if boxes[k] is None:
                over.append(g)
                continue
            if kind == "hat":
                hx0, hx1 = cols_in(f, last + 1, last + 3)
                fit(sheet, boxes[k], (hx0 - 1, last - 4, hx1 + 1, last + 1), g)
            elif kind in ("coat", "parka"):
                y0 = last + 4
                y1 = y0 + (10 if kind == "parka" else 8)
                cx0, cx1 = cols_in(f, y0 + 1, y0 + 6)
                fit(sheet, boxes[k], (cx0, y0, cx1, y1), g)
            else:
                cx0, cx1 = cols_in(f, b - 3, b)
                fit(sheet, boxes[k], (cx0, b - 3, cx1, b), g)
            over.append(g)
        sheets["ranger_wear_" + name] = over
    return sheets


def frames_to_sheet(frames):
    out = [[None] * 64 for _ in range(128)]
    for k, f in enumerate(frames):
        fx, fy = (k % 4) * FW, (k // 4) * FH
        for y in range(FH):
            for x in range(FW):
                out[fy + y][fx + x] = f[y][x]
    return out


# --- walls and floors -----------------------------------------------------------

def tile(sh, box, tw, th):
    x0, y0, w, h = box
    sx, sy = w / float(tw), h / float(th)
    out = [[None] * tw for _ in range(th)]
    for ty in range(th):
        for tx in range(tw):
            out[ty][tx] = sample(sh, x0 + tx * sx, y0 + ty * sy, x0 + (tx + 1) * sx, y0 + (ty + 1) * sy) or (0, 0, 0, 255)
    return out


def save_strip(name, pics, pw, ph):
    w = pw * len(pics)
    data = bytearray(w * ph * 4)
    for k, p in enumerate(pics):
        for y in range(ph):
            for x in range(pw):
                c = p[y][x]
                if c:
                    i = (y * w + k * pw + x) * 4
                    data[i:i + 4] = bytes(c)
    write_png(os.path.join(RAW, name), w, ph, bytes(data))
    print("wrote", name, w, ph)


def main():
    cache = {}
    people = []
    for pid, file, block, height in PEOPLE:
        sh = cache.setdefault(file, Sheet(file))
        boxes = frame_boxes(sh, block)
        missing = [k for k, b in enumerate(boxes) if b is None]
        if missing:
            print("%s: no frame drawn at %s" % (pid, missing))
        people.append(person(sh, boxes, height))
    sh = Sheet("raw_ar21_B6_big_foot_supper.png")
    boxes = [bbox(sh, (cx[0], ry[0], cx[1], ry[1])) for ry in COSTUME_ROWS for cx in COSTUME_COLS]
    people.append(person(sh, boxes, 27))
    save_strip("raw_ar21_people_16.png", people, 64, 128)

    clothes = Sheet("raw_ar21_A4_clothes.png")
    frames = ranger_frames()
    hair = grid_boxes(clothes, HAIR_BLOCK)
    sheets = wear(clothes, frames, hair)
    order = ["ranger_nohat"] + ["ranger_wear_" + n for n, _, _ in WEAR]
    save_strip("raw_ar21_wear_16.png", [frames_to_sheet(sheets[n]) for n in order], 64, 128)

    b8 = Sheet("raw_ar21_B8_station.png")
    walls = []
    for box in [(155, 862, 112, 112), (337, 862, 110, 112), (512, 862, 112, 112)]:
        t = tile(b8, box, 16, 16)
        walls.append(t + t + t)
    save_strip("raw_ar21_walls_16.png", walls, 16, 48)
    floors = [tile(b8, box, 16, 16) for box in [(738, 900, 96, 96), (894, 900, 96, 96), (1047, 900, 96, 96)]]
    save_strip("raw_ar21_floors_16.png", floors, 16, 16)


if __name__ == "__main__":
    main()
