"""Cuts Mark's Art Request 25 sheets (Phase 5) into game pictures.

Mark's sheets are large drafts. Their "transparent" background is a drawn
light grey checkerboard, and some have dark grid lines between cells. For
each sheet this:
  1. clears the background (a flood from the edges through light, grey
     pixels, so whites inside an outline stay) and any long straight grid
     lines;
  2. finds each drawn piece (blobs close together count as one piece) and
     sorts them into rows, left to right;
  3. hands them out in reading order to the names in SHEETS below.

Animals, cousins and pets are cut as whole sheets: every frame of one
animal gets the same scale, stands on the frame's bottom row and is
centred, so it doesn't grow or shrink as it walks. Single pieces are fitted
into their size, standing on the bottom middle. Colours are kept as drawn:
each game pixel takes the most common colour of the drawn pixels it
covers.

Writes straight to art/final/ (then run Godot's --import).

Run: python -I tools/cut_ar25.py <folder with ar25_*.png> [--list]
"""
import os
import sys
from collections import Counter, deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FINAL = os.path.join(ROOT, "art", "final")

BG_MIN = 212        # background pixels are at least this light...
BG_SPREAD = 14      # ...and this grey (max - min channel)
LINE_DARK = 150     # a grid line pixel is at most this light
LINE_RUN = 140      # and part of a straight run at least this long
SPECK = 40          # pieces smaller than this many pixels are dropped


class Sheet:
    def __init__(self, path):
        self.w, self.h, px = read_png(path)
        self.px = bytearray(px)

    def i(self, x, y):
        return (y * self.w + x) * 4

    def rgba(self, x, y):
        i = self.i(x, y)
        return tuple(self.px[i:i + 4])

    def opaque(self, x, y):
        return self.px[self.i(x, y) + 3] >= 128

    def clear(self, x, y):
        self.px[self.i(x, y) + 3] = 0


def is_bg(c):
    r, g, b, a = c
    return a < 128 or (min(r, g, b) >= BG_MIN and max(r, g, b) - min(r, g, b) <= BG_SPREAD)


def dark(c):
    """A pixel that can be part of a grid line: dark, or a mid grey."""
    r, g, b, a = c
    if a < 128:
        return False
    if (r + g + b) / 3 <= LINE_DARK:
        return True
    return max(r, g, b) - min(r, g, b) <= 12 and (r + g + b) / 3 <= 222


def clear_lines(s):
    """Clears long straight dark runs (drawn grid lines), and the light
    edge pixels beside them."""
    hit = []
    for y in range(s.h):
        run = 0
        for x in range(s.w + 1):
            if x < s.w and dark(s.rgba(x, y)):
                run += 1
                continue
            if run >= LINE_RUN:
                hit.extend((xx, y) for xx in range(x - run, x))
            run = 0
    for x in range(s.w):
        run = 0
        for y in range(s.h + 1):
            if y < s.h and dark(s.rgba(x, y)):
                run += 1
                continue
            if run >= LINE_RUN:
                hit.extend((x, yy) for yy in range(y - run, y))
            run = 0
    for x, y in hit:
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                xx, yy = x + dx, y + dy
                if 0 <= xx < s.w and 0 <= yy < s.h:
                    c = s.rgba(xx, yy)
                    if (dx == 0 and dy == 0) or is_bg(c) or dark(c):
                        s.clear(xx, yy)


def clear_background(s):
    seen = bytearray(s.w * s.h)
    q = deque()
    for x in range(s.w):
        q.append((x, 0))
        q.append((x, s.h - 1))
    for y in range(s.h):
        q.append((0, y))
        q.append((s.w - 1, y))
    while q:
        x, y = q.popleft()
        k = y * s.w + x
        if seen[k]:
            continue
        seen[k] = 1
        if not is_bg(s.rgba(x, y)):
            continue
        s.clear(x, y)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < s.w and 0 <= yy < s.h and not seen[yy * s.w + xx]:
                q.append((xx, yy))


def pieces(s, gap):
    """Bounding boxes [x0, y0, x1, y1) of the drawn pieces, blobs within
    `gap` pixels of each other joined."""
    seen = bytearray(s.w * s.h)
    boxes = []
    for y0 in range(s.h):
        for x0 in range(s.w):
            if seen[y0 * s.w + x0] or not s.opaque(x0, y0):
                continue
            q = deque([(x0, y0)])
            seen[y0 * s.w + x0] = 1
            n = 0
            bx0, by0, bx1, by1 = x0, y0, x0, y0
            while q:
                x, y = q.popleft()
                n += 1
                bx0, by0, bx1, by1 = min(bx0, x), min(by0, y), max(bx1, x), max(by1, y)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < s.w and 0 <= yy < s.h and not seen[yy * s.w + xx] and s.opaque(xx, yy):
                        seen[yy * s.w + xx] = 1
                        q.append((xx, yy))
            if n >= SPECK:
                boxes.append([bx0, by0, bx1 + 1, by1 + 1, n])
    # Join blobs that are close.
    joined = True
    while joined:
        joined = False
        out = []
        for b in boxes:
            for o in out:
                if b[0] < o[2] + gap and o[0] < b[2] + gap and b[1] < o[3] + gap and o[1] < b[3] + gap:
                    o[0], o[1], o[2], o[3], o[4] = min(o[0], b[0]), min(o[1], b[1]), max(o[2], b[2]), max(o[3], b[3]), o[4] + b[4]
                    joined = True
                    break
            else:
                out.append(list(b))
        boxes = out
    return [b for b in boxes if b[4] >= SPECK * 4]


def grid_rows(s, ys, xs, inset=6):
    """The drawn box in each cell of a grid (row lines ys, column lines
    xs): the cell's background flooded from its edge, then trimmed."""
    out = []
    for r in range(len(ys) - 1):
        row = []
        for c in range(len(xs) - 1):
            x0, y0, x1, y1 = xs[c] + inset, ys[r] + inset, xs[c + 1] - inset, ys[r + 1] - inset
            q = deque()
            for x in range(x0, x1):
                q.append((x, y0))
                q.append((x, y1 - 1))
            for y in range(y0, y1):
                q.append((x0, y))
                q.append((x1 - 1, y))
            seen = set()
            while q:
                x, y = q.popleft()
                if (x, y) in seen or not (x0 <= x < x1 and y0 <= y < y1):
                    continue
                seen.add((x, y))
                c_ = s.rgba(x, y)
                if not (is_bg(c_) or dark(c_) and (x in (x0, x1 - 1) or y in (y0, y1 - 1))):
                    continue
                s.clear(x, y)
                q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            pts = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if s.opaque(x, y)]
            if pts:
                row.append([min(p[0] for p in pts), min(p[1] for p in pts), max(p[0] for p in pts) + 1, max(p[1] for p in pts) + 1])
        out.append(row)
    return out


def rows_of(boxes):
    """Sorts boxes into rows (by overlapping height), each left to right."""
    rows = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        cy = (b[1] + b[3]) / 2
        for r in rows:
            if r["y0"] <= cy <= r["y1"]:
                r["b"].append(b)
                r["y0"], r["y1"] = min(r["y0"], b[1]), max(r["y1"], b[3])
                break
        else:
            rows.append({"y0": b[1], "y1": b[3], "b": [b]})
    rows.sort(key=lambda r: r["y0"])
    return [sorted(r["b"], key=lambda b: b[0]) for r in rows]


def shrink(s, box, scale, fw, fh, out, ox, oy, ow):
    """Draws box at `scale` into out (row width ow), standing on the bottom
    middle of the fw x fh frame at (ox, oy)."""
    x0, y0, x1, y1 = box[:4]
    tw = max(1, min(fw, round((x1 - x0) * scale)))
    th = max(1, min(fh, round((y1 - y0) * scale)))
    sx = (x1 - x0) / tw
    sy = (y1 - y0) / th
    left = ox + (fw - tw) // 2
    top = oy + fh - th
    for ty in range(th):
        for tx in range(tw):
            c = Counter()
            n = 0
            ya, yb = int(y0 + ty * sy), max(int(y0 + ty * sy) + 1, int(y0 + (ty + 1) * sy))
            xa, xb = int(x0 + tx * sx), max(int(x0 + tx * sx) + 1, int(x0 + (tx + 1) * sx))
            for y in range(ya, min(yb, s.h)):
                for x in range(xa, min(xb, s.w)):
                    n += 1
                    if s.opaque(x, y):
                        r, g, b, _a = s.rgba(x, y)
                        c[(r & 0xF8, g & 0xF8, b & 0xF8)] += 1
            if n and sum(c.values()) >= n * 0.42:
                col = c.most_common(1)[0][0]
                i = ((top + ty) * ow + left + tx) * 4
                out[i:i + 4] = bytes((col[0] | 4, col[1] | 4, col[2] | 4, 255))


def fresh(folder, tag, box=None):
    """A sheet as drawn, with (if box) only the background flooded from
    the box's edge cleared: for pieces line clearing would cut into."""
    s = Sheet(os.path.join(folder, "ar25_%s.png" % tag))
    if box:
        x0, y0, x1, y1 = box[:4]
        q = deque([(x, y0) for x in range(x0, x1)] + [(x, y1 - 1) for x in range(x0, x1)] + [(x0, y) for y in range(y0, y1)] + [(x1 - 1, y) for y in range(y0, y1)])
        seen = set()
        while q:
            x, y = q.popleft()
            if (x, y) in seen or not (x0 <= x < x1 and y0 <= y < y1):
                continue
            seen.add((x, y))
            if not is_bg(s.rgba(x, y)):
                continue
            s.clear(x, y)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return s


def sketch(s, b, name, fw, fh):
    """Pencil line art: a game pixel is a line where enough of its block is
    drawn dark, else the paper colour, so thin strokes survive."""
    x0, y0, x1, y1 = b[:4]
    paper = Counter()
    for y in range(y0, y1, 3):
        for x in range(x0, x1, 3):
            if s.opaque(x, y):
                r, g, bb, _a = s.rgba(x, y)
                if (r + g + bb) / 3 > 170:
                    paper[(r & 0xF0, g & 0xF0, bb & 0xF0)] += 1
    pc = paper.most_common(1)[0][0] if paper else (240, 224, 190)
    px = bytearray(fw * fh * 4)
    sx, sy = (x1 - x0) / fw, (y1 - y0) / fh
    for ty in range(fh):
        for tx in range(fw):
            n = d = op = 0
            for y in range(int(y0 + ty * sy), int(y0 + (ty + 1) * sy)):
                for x in range(int(x0 + tx * sx), int(x0 + (tx + 1) * sx)):
                    n += 1
                    if s.opaque(x, y):
                        op += 1
                        r, g, bb, _a = s.rgba(x, y)
                        if (r + g + bb) / 3 < 150:
                            d += 1
            i = (ty * fw + tx) * 4
            if n and d >= n * 0.34:
                px[i:i + 4] = bytes((92, 84, 76, 255))
            elif n and op >= n * 0.5:
                px[i:i + 4] = bytes((pc[0] | 8, pc[1] | 8, pc[2] | 8, 255))
    save(name, fw, fh, px)


def save(name, w, h, px):
    write_png(os.path.join(FINAL, name + ".png"), w, h, bytes(px))
    print("wrote", name, w, h)


def cut_animal(s, rows, name, fw, fh, extra_glow=False):
    """rows: lists of boxes, one list per facing. One scale for all."""
    allb = [b for r in rows for b in r]
    scale = min(fw / max(b[2] - b[0] for b in allb), fh / max(b[3] - b[1] for b in allb))
    cols = max(len(r) for r in rows)
    w, h = cols * fw, len(rows) * fh
    px = bytearray(w * h * 4)
    for ry, r in enumerate(rows):
        for cx, b in enumerate(r):
            shrink(s, b, scale, fw, fh, px, cx * fw, ry * fh, w)
    save(name, w, h, px)
    if extra_glow:
        # Only the glowing antlers: the bright greens of the sheet.
        g = bytearray(len(px))
        for k in range(0, len(px), 4):
            r_, g_, b_, a = px[k:k + 4]
            if a and g_ > r_ + 50 and g_ > b_ + 20:
                g[k:k + 4] = px[k:k + 4]
        save(name + "_glow", w, h, g)


def cut_piece(s, b, name, fw, fh):
    scale = min(fw / (b[2] - b[0]), fh / (b[3] - b[1]))
    px = bytearray(fw * fh * 4)
    shrink(s, b, scale, fw, fh, px, 0, 0, fw)
    save(name, fw, fh, px)


def cut_frames(s, bs, name, fw, fh):
    """Several pieces side by side as one strip, one scale."""
    scale = min(min(fw / (b[2] - b[0]), fh / (b[3] - b[1])) for b in bs)
    w = fw * len(bs)
    px = bytearray(w * fh * 4)
    for k, b in enumerate(bs):
        shrink(s, b, scale, fw, fh, px, k * fw, 0, w)
    save(name, w, fh, px)


def load(folder, tag, lines=False, gap=6):
    s = Sheet(os.path.join(folder, "ar25_%s.png" % tag))
    s.folder = folder
    if lines:
        clear_lines(s)
    clear_background(s)
    return s, rows_of(pieces(s, gap))


def main():
    folder = sys.argv[1]
    listing = "--list" in sys.argv
    plan = [("A1_small_animals", True, 6), ("A2_big_animals", False, 6), ("A3_cousins", True, 6), ("A4_pet", True, 6),
            ("A5_guide", False, 6), ("A6_lore", False, 6), ("A7_night", False, 30)]
    for tag, lines, gap in plan:
        s, rows = load(folder, tag, lines, gap)
        if listing:
            print(tag, [len(r) for r in rows])
            for r in rows:
                print("   ", [b[:4] for b in r])
            continue
        globals()["do_" + tag[:2]](s, rows)


# --- each sheet ------------------------------------------------------------------------

def do_A1(s, rows):
    for k, name in enumerate(["rabbit", "squirrel", "hedgehog", "raccoon", "badger"]):
        cut_animal(s, rows[k * 3:k * 3 + 3], "animal_" + name, 16, 16)


def do_A2(s, rows):
    cut_animal(s, rows[0:3], "animal_deer", 32, 32)
    cut_animal(s, rows[3:6], "animal_moose", 48, 48)
    cut_animal(s, rows[6:9], "animal_bear", 48, 32)


def do_A3(s, rows):
    cut_animal(s, grid_rows(s, [10, 109, 199, 293], [217, 365, 495, 622, 741, 866, 978]), "creature_jackalope", 16, 16)
    # Mark's separate glow cells aren't used: the glow is taken from the
    # deer itself so it lines up exactly.
    cut_animal(s, grid_rows(s, [305, 429, 545, 670], [183, 342, 481, 615, 746, 887, 1012]), "creature_magic_deer", 32, 32, extra_glow=True)
    cut_animal(s, grid_rows(s, [900, 985, 1066, 1161], [125, 268, 405, 537, 669, 803, 937, 1071]), "troll_badger_sheet", 16, 16)
    last = grid_rows(s, [1171, 1298], [128, 315, 504, 689, 880, 1068])[0]
    cut_piece(s, last[0], "obj_jackalope_burrow", 16, 16)
    cut_piece(s, last[1], "obj_jackalope_burrow_filled", 16, 16)
    cut_piece(s, last[2], "obj_badger_bowl_full", 16, 16)
    cut_piece(s, last[3], "obj_badger_bowl_empty", 16, 16)
    cut_piece(s, last[4], "obj_magic_tracks", 16, 16)


def do_A4(s, rows):
    cols = [53, 209, 360, 513, 665, 818, 969, 1121, 1274]
    cut_animal(s, grid_rows(s, [18, 159, 286, 420], cols), "pet_dog", 16, 16)
    cut_animal(s, grid_rows(s, [442, 582, 709, 842], cols), "pet_cat", 16, 16)
    last = rows[-1]
    folder = s.folder
    # The portraits are whole squares: cut from the sheet as drawn.
    raw = fresh(folder, "A4_pet")
    cut_piece(raw, [44, 892, 310, 1150], "pet_dog_face", 64, 64)
    cut_piece(raw, [338, 884, 606, 1152], "pet_cat_face", 64, 64)
    bowls = [b for b in last if 620 < b[0] < 840][0]
    mid = (bowls[0] + bowls[2]) // 2
    cut_frames(s, [[bowls[0], bowls[1], mid - 4, bowls[3]], [mid + 4, bowls[1], bowls[2], bowls[3]]], "furniture_pet_bowl", 16, 16)
    bed = last[-2]
    bs = fresh(folder, "A4_pet", [bed[0] - 4, bed[1] - 4, bed[2] + 4, bed[3] + 4])
    for y in range(bed[1], bed[3]):
        for x in range(bed[0], bed[2]):
            r, g, b_, a = bs.rgba(x, y)
            if min(r, g, b_) > 225:
                bs.clear(x, y)
    cut_piece(bs, [bed[0] + 7, bed[1], bed[2] - 7, bed[3]], "furniture_dog_bed", 32, 16)
    cut_piece(s, last[-1], "item_pet_treat", 32, 32)


def do_A5(s, rows):
    # The viewfinder's lower corners sit in a row of their own.
    top = sorted(rows[0] + rows[1], key=lambda b: b[0])
    mid, chips, sketches = rows[2], rows[3], rows[4]
    # Top: the binocular view, the viewfinder's corners and cross, the flash.
    cut_binoculars(s, top[0])
    vf = [b for b in top[1:] if b[2] < top[-1][0]]
    box = [min(b[0] for b in vf), min(b[1] for b in vf), max(b[2] for b in vf), max(b[3] for b in vf)]
    cut_piece(s, box, "ui_viewfinder", 96, 72)
    cut_piece(s, top[-1], "ui_shutter", 32, 32)
    names = ["clip_guide", "guide_tab_animals", "guide_tab_strange", "guide_tab_places", "guide_unknown", "guide_sketch_frame", "guide_photo_frame", "guide_good_stamp"]
    sizes = [(32, 32), (16, 16), (16, 16), (16, 16), (48, 40), (48, 40), (48, 40), (12, 12)]
    for b, n, sz in zip(mid, names, sizes):
        cut_piece(s, b, n, sz[0], sz[1])
    for b, n in zip(chips, ["meadow", "forest", "water", "rock", "dawn", "day", "dusk", "night", "full_moon", "snow"]):
        cut_piece(s, b, "chip_" + n, 8, 8)
    for b, n in zip(sketches, ["rabbit", "squirrel", "hedgehog", "raccoon", "badger", "deer", "moose", "bear", "jackalope", "magic_deer"]):
        sketch(s, b, "sketch_" + n, 32, 32)


def cut_binoculars(s, b):
    """The binocular view: Mark painted a scene in the lenses; the game
    needs them clear. Keeps the dark surround, clears everything else."""
    x0, y0, x1, y1 = b[:4]
    W, H = 480, 270
    px = bytearray(W * H * 4)
    for ty in range(H):
        for tx in range(W):
            x = int(x0 + (tx + 0.5) * (x1 - x0) / W)
            y = int(y0 + (ty + 0.5) * (y1 - y0) / H)
            r, g, bb, a = s.rgba(x, y)
            if a >= 128 and r + g + bb < 90:
                i = (ty * W + tx) * 4
                px[i:i + 4] = bytes((10, 22, 16, 255))
    save("ui_binocular_view", W, H, px)


def do_A6(s, rows):
    allb = [b for r in rows for b in r]
    cut_piece(s, allb[0], "skill_lore", 16, 16)
    for b, n in zip(allb[1:], ["badge_lore_2", "badge_lore_3", "badge_lore_4", "badge_spec_naturalist", "badge_spec_whisperer"]):
        cut_piece(s, b, n, 32, 32)


def do_A7(s, rows):
    # Mark drew the fireflies over a night pond; the world needs only the
    # lights, so keep the yellow-green glows and clear the rest.
    for b in rows[0]:
        x0, y0, x1, y1 = b[:4]
        for y in range(y0, y1):
            for x in range(x0, x1):
                r, g, bb, a = s.rgba(x, y)
                if not (g > 200 and r > 160 and bb < 150):
                    s.clear(x, y)
    cut_frames(s, rows[0], "night_fireflies", 32, 32)
    last = rows[1]
    cut_piece(s, last[0], "night_path_stone", 16, 16)
    cut_piece(s, last[1], "night_path_stone_dim", 16, 16)
    cut_piece(s, last[2], "night_glow_spot", 16, 16)
    cut_piece(s, last[3], "forage_moonflower_closed", 16, 16)
    cut_piece(s, last[4], "forage_moonflower_open", 16, 16)
    cut_piece(s, last[5], "item_moonflower", 32, 32)


if __name__ == "__main__":
    main()
