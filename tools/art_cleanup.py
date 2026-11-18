"""Turns the designer's raw images into finished game art.

Never alters anything in art/raw/. For each raw image listed in
tools/art_manifest.json:
  1. read it and its manifest entry (grid layout, target size of each item);
  2. remove the background if it is not already transparent;
  3. shrink each cell to its target size in game pixels, taking the most
     common color in each block so edges stay hard (a sheet marked "pixel"
     is true pixel art already at game size: it is cut pixel for pixel);
  4. snap every color to the nearest palette color;
  5. cut the sheet into separate named images in art/final/;
  6. write a short report of each image, whether it passed, and why not.

Run: python tools/art_cleanup.py [--only NAME]
"""
import argparse
import json
import os
import sys
from collections import Counter, deque

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "art", "raw")
FINAL = os.path.join(ROOT, "art", "final")
MANIFEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "art_manifest.json")
PALETTE = os.path.join(ROOT, "art", "palette.json")
REPORT = os.path.join(ROOT, "art", "cleanup_report.md")

ALPHA_CUT = 128
BG_TOLERANCE = 48
MIN_PART_SHARE = 0.002   # a blob smaller than this share of the cell is a speck


class Img:
    def __init__(self, w, h, px):
        self.w, self.h, self.px = w, h, px

    def get(self, x, y):
        i = (y * self.w + x) * 4
        return self.px[i], self.px[i + 1], self.px[i + 2], self.px[i + 3]

    def alpha(self, x, y):
        return self.px[(y * self.w + x) * 4 + 3]

    def clear(self, x, y):
        self.px[(y * self.w + x) * 4 + 3] = 0


def has_transparency(img):
    a = img.px[3::4]
    clear = sum(1 for v in a[::97] if v < ALPHA_CUT)
    return clear > len(a[::97]) * 0.05


def remove_background(img):
    """Clears the background by flood fill from the edges, matching the
    color found around the border. Returns the background color."""
    border = []
    for x in range(0, img.w, 7):
        border.append(img.get(x, 0)[:3])
        border.append(img.get(x, img.h - 1)[:3])
    for y in range(0, img.h, 7):
        border.append(img.get(0, y)[:3])
        border.append(img.get(img.w - 1, y)[:3])
    bg = tuple(sorted(c[i] for c in border)[len(border) // 2] for i in range(3))
    tol2 = BG_TOLERANCE * BG_TOLERANCE
    seen = bytearray(img.w * img.h)
    q = deque()
    for x in range(img.w):
        q.append((x, 0))
        q.append((x, img.h - 1))
    for y in range(img.h):
        q.append((0, y))
        q.append((img.w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * img.w + x
        if seen[i]:
            continue
        seen[i] = 1
        r, g, b, _ = img.get(x, y)
        if (r - bg[0]) ** 2 + (g - bg[1]) ** 2 + (b - bg[2]) ** 2 > tol2:
            continue
        img.clear(x, y)
        if x > 0:
            q.append((x - 1, y))
        if x < img.w - 1:
            q.append((x + 1, y))
        if y > 0:
            q.append((x, y - 1))
        if y < img.h - 1:
            q.append((x, y + 1))
    return bg


def parts_in(img, x0, y0, x1, y1, step=3):
    """Counts separate blobs of solid pixels in a box (sampled every step
    pixels), ignoring specks. Returns (count, bbox, touches_edge)."""
    w = (x1 - x0 + step - 1) // step
    h = (y1 - y0 + step - 1) // step
    grid = bytearray(w * h)
    for gy in range(h):
        for gx in range(w):
            if img.alpha(x0 + gx * step, y0 + gy * step) >= ALPHA_CUT:
                grid[gy * w + gx] = 1
    seen = bytearray(w * h)
    blobs = []
    for start in range(w * h):
        if not grid[start] or seen[start]:
            continue
        q = deque([start])
        seen[start] = 1
        cells = []
        while q:
            i = q.popleft()
            cells.append(i)
            cx, cy = i % w, i // w
            for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    j = ny * w + nx
                    if grid[j] and not seen[j]:
                        seen[j] = 1
                        q.append(j)
        blobs.append(cells)
    min_size = max(4, int(w * h * MIN_PART_SHARE))
    big = [b for b in blobs if len(b) >= min_size]
    if not big:
        return 0, None, False
    xs = [i % w for b in big for i in b]
    ys = [i // w for b in big for i in b]
    bbox = (x0 + min(xs) * step, y0 + min(ys) * step, min(x1, x0 + (max(xs) + 1) * step), min(y1, y0 + (max(ys) + 1) * step))
    touches = min(xs) == 0 or min(ys) == 0 or max(xs) == w - 1 or max(ys) == h - 1
    return len(big), bbox, touches


def shrink(img, box, tw, th, stretch, full, anchor="bottom"):
    """Shrinks the box to tw x th by the most common color per block. Keeps
    the item's shape unless stretched, standing it on the bottom middle, or
    with anchor "top_left" in the top-left corner (a cursor, whose point
    must be the corner pixel)."""
    bx0, by0, bx1, by1 = box
    bw, bh = bx1 - bx0, by1 - by0
    if stretch or full:
        sx, sy = bw / tw, bh / th
        ow, oh, ox, oy = tw, th, 0, 0
    else:
        s = max(bw / tw, bh / th)
        sx = sy = s
        ow, oh = max(1, round(bw / s)), max(1, round(bh / s))
        ox, oy = (0, 0) if anchor == "top_left" else ((tw - ow) // 2, th - oh)
    out = [(0, 0, 0, 0)] * (tw * th)
    for ty in range(oh):
        for tx in range(ow):
            x0 = bx0 + int(tx * sx)
            x1 = max(x0 + 1, bx0 + int((tx + 1) * sx))
            y0 = by0 + int(ty * sy)
            y1 = max(y0 + 1, by0 + int((ty + 1) * sy))
            votes = Counter()
            solid = 0
            total = 0
            stepx = max(1, (x1 - x0) // 6)
            stepy = max(1, (y1 - y0) // 6)
            for y in range(y0, y1, stepy):
                for x in range(x0, x1, stepx):
                    r, g, b, a = img.get(x, y)
                    total += 1
                    if a >= ALPHA_CUT:
                        solid += 1
                        votes[(r >> 3, g >> 3, b >> 3)] += 1
            if solid * 2 >= total and votes:
                (qr, qg, qb), _ = votes.most_common(1)[0]
                out[(oy + ty) * tw + ox + tx] = (qr * 8 + 4, qg * 8 + 4, qb * 8 + 4, 255)
    return out


def bleeds(img, x0, y0, x1, y1):
    """True if a solid pixel on the box edge has a solid neighbour just
    outside it: the item runs on into the next cell."""
    for x in range(x0, x1):
        for y, oy in ((y0, y0 - 1), (y1 - 1, y1)):
            if 0 <= oy < img.h and img.alpha(x, y) >= ALPHA_CUT and img.alpha(x, oy) >= ALPHA_CUT:
                return True
    for y in range(y0, y1):
        for x, ox in ((x0, x0 - 1), (x1 - 1, x1)):
            if 0 <= ox < img.w and img.alpha(x, y) >= ALPHA_CUT and img.alpha(ox, y) >= ALPHA_CUT:
                return True
    return False


def pixel_cell(img, box, tw, th, full, anchor, pad_left):
    """True pixel art: cut the item out pixel for pixel, with no shrinking.
    Returns (w, h, pixels, note). A full tile must be exactly tw x th. An
    item is cropped to its solid pixels and stood on the bottom middle (or
    centred) of a tw x th picture; one drawn larger than that keeps its own
    size, so the game shows it a little larger than its spot."""
    x0, y0, x1, y1 = box
    if full:
        if (x1 - x0, y1 - y0) != (tw, th):
            return None, "tile is %dx%d, expected %dx%d" % (x1 - x0, y1 - y0, tw, th)
        return (tw, th, [img.get(x, y) for y in range(y0, y1) for x in range(x0, x1)]), ""
    xs = [x for y in range(y0, y1) for x in range(x0, x1) if img.alpha(x, y) >= ALPHA_CUT]
    ys = [y for y in range(y0, y1) for x in range(x0, x1) if img.alpha(x, y) >= ALPHA_CUT]
    if not xs:
        return None, "no item found in its cell"
    bx0, by0, bx1, by1 = min(xs), min(ys), max(xs) + 1, max(ys) + 1
    bw, bh = bx1 - bx0, by1 - by0
    ow, oh = max(tw, bw + pad_left), max(th, bh)
    ox = pad_left + (ow - pad_left - bw) // 2
    oy = oh - bh if anchor == "bottom" else (oh - bh) // 2
    out = [(0, 0, 0, 0)] * (ow * oh)
    for y in range(bh):
        for x in range(bw):
            p = img.get(bx0 + x, by0 + y)
            if p[3] >= ALPHA_CUT:
                out[(oy + y) * ow + ox + x] = p[:3] + (255,)
    note = "" if (ow, oh) == (tw, th) else "drawn %dx%d, larger than its %dx%d spot" % (bw, bh, tw, th)
    return (ow, oh, out), note


def atlas_cut(img, at):
    """Builds a cols x cols atlas of square cells from a block of the sheet.
    "order" lists, for each atlas cell, the sheet cell (index in the block)
    to copy, or a list of sheet cells laid over each other, so a missing
    cell can be made from the ones that were drawn."""
    ox, oy = at["origin"]
    cs, cols = at["cell"], at["cols"]
    size = cs * cols
    if ox + size > img.w or oy + size > img.h:
        return None, "block runs off the sheet"
    out = [(0, 0, 0, 0)] * (size * size)
    built = []
    for dst, src in enumerate(at["order"]):
        srcs = src if isinstance(src, list) else [src]
        if isinstance(src, list):
            built.append(str(dst))
        dx, dy = (dst % cols) * cs, (dst // cols) * cs
        for s in srcs:
            sx, sy = ox + (s % cols) * cs, oy + (s // cols) * cs
            for y in range(cs):
                for x in range(cs):
                    p = img.get(sx + x, sy + y)
                    if p[3] >= ALPHA_CUT:
                        out[(dy + y) * size + dx + x] = p[:3] + (255,)
    note = "cells reordered" if at["order"] != list(range(cols * cols)) else ""
    if built:
        note += "; cell %s made by laying drawn cells together" % ", ".join(built)
    return (size, size, out), note


def median_cut(colors, n):
    """A palette of n colors from a list of (r, g, b), by median cut."""
    boxes = [list(colors)]
    while len(boxes) < n:
        boxes.sort(key=len, reverse=True)
        box = boxes.pop(0)
        if len(box) < 2:
            boxes.append(box)
            break
        ranges = [max(c[i] for c in box) - min(c[i] for c in box) for i in range(3)]
        ch = ranges.index(max(ranges))
        box.sort(key=lambda c: c[ch])
        mid = len(box) // 2
        boxes += [box[:mid], box[mid:]]
    pal = []
    for b in boxes:
        if b:
            pal.append(tuple(sum(c[i] for c in b) // len(b) for i in range(3)))
    return sorted(set(pal))


def snap(pixels, palette):
    cache = {}
    out = []
    for p in pixels:
        if p[3] == 0:
            out.append(p)
            continue
        key = p[:3]
        if key not in cache:
            cache[key] = min(palette, key=lambda c: (c[0] - key[0]) ** 2 + (c[1] - key[1]) ** 2 + (c[2] - key[2]) ** 2)
        out.append(cache[key] + (255,))
    return out


def calm(w, h, pixels, keep):
    """Makes a ground tile quieter: the marks on it (4-connected patches of
    any color but the tile's main one, joined across the tile's edges so it
    still tiles) are thinned to the share `keep`, spread evenly in reading
    order. Dropped marks take the main color. No new colors appear."""
    main = Counter(p for p in pixels if p[3]).most_common(1)[0][0]
    seen = [False] * (w * h)
    patches = []
    for i in range(w * h):
        if seen[i] or pixels[i] == main:
            continue
        stack, patch = [i], []
        seen[i] = True
        while stack:
            j = stack.pop()
            patch.append(j)
            x, y = j % w, j // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                k = (ny % h) * w + nx % w
                if not seen[k] and pixels[k] != main:
                    seen[k] = True
                    stack.append(k)
        patches.append(patch)
    out = list(pixels)
    for n, patch in enumerate(patches):
        if int((n + 1) * keep) == int(n * keep):
            for j in patch:
                out[j] = main
    return out


def save(name, w, h, pixels):
    data = bytearray()
    for p in pixels:
        data.extend(p)
    write_png(os.path.join(FINAL, name + ".png"), w, h, data)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    with open(MANIFEST, encoding="utf-8") as f:
        manifest = json.load(f)
    os.makedirs(FINAL, exist_ok=True)
    report = []
    shrunk = []   # (name, w, h, pixels) before palette snapping
    exact = []    # the same, from pixel-for-pixel sheets: saved last, so they win
    soft = set()  # pictures whose see-through pixels keep their alpha
    sheets = []
    raw_files = set(os.listdir(RAW))
    listed = set()
    for entry in manifest["images"]:
        listed.add(entry["file"])
        if args.only and args.only not in entry["file"]:
            continue
        if entry.get("reference"):
            report.append(("%s (%s)" % (entry["file"], entry["label"]), [("-", "SKIPPED", entry["reference"])]))
            continue
        if entry.get("duplicate_of"):
            report.append(("%s (%s)" % (entry["file"], entry["label"]), [("-", "SKIPPED", "byte-identical copy of %s" % entry["duplicate_of"])]))
            continue
        path = os.path.join(RAW, entry["file"])
        if not os.path.exists(path):
            report.append((entry["file"], [("-", "FAIL", "raw image not found")]))
            continue
        w, h, px = read_png(path)
        img = Img(w, h, bytearray(px))   # a copy: the raw file is never touched
        full = entry.get("full", False)
        if entry.get("pixel"):
            # True pixel art at game size: cut pixel for pixel, no shrink.
            cols, rows = entry["grid"]
            cw, ch = w // cols, h // rows
            results = []
            for idx, cell in enumerate(entry["cells"]):
                if cell is None:
                    continue
                if "box" in cell:
                    bx, by, bw, bh = cell["box"]
                    box = (bx, by, bx + bw, by + bh)
                else:
                    box = ((idx % cols) * cw, (idx // cols) * ch, (idx % cols + 1) * cw, (idx // cols + 1) * ch)
                tw, th = cell["size"]
                # On an exact grid the cell edge is the cut: an item touching
                # its neighbour is noted for a look by eye, not failed.
                cell_full = cell.get("full", full)
                touch = not cell_full and bleeds(img, *box)
                got, note = pixel_cell(img, box, tw, th, cell_full, cell.get("anchor", entry.get("anchor", "bottom")), cell.get("pad_left", 0))
                if got is None:
                    results.append((cell["name"], "FAIL", note))
                    continue
                ow, oh, pix = got
                # "soft": keep see-through pixels (a drawn shadow) as drawn;
                # "drop_soft": leave them out (a sparkle needs no shadow).
                if cell.get("drop_soft"):
                    pix = [p if p[3] == 255 else (0, 0, 0, 0) for p in pix]
                elif cell.get("soft"):
                    soft.add(cell["name"])
                exact.append((cell["name"], ow, oh, pix))
                if touch:
                    note = (note + "; " if note else "") + "touches the next cell's item (checked by eye)"
                results.append((cell["name"], "pass", "%dx%d pixel for pixel%s" % (ow, oh, "; " + note if note else "")))
            for at in entry.get("atlases", []):
                got, note = atlas_cut(img, at)
                if got is None:
                    results.append((at["name"], "FAIL", note))
                    continue
                exact.append((at["name"],) + got)
                results.append((at["name"], "pass", "%dx%d atlas%s" % (got[0], got[1], "; " + note if note else "")))
            report.append(("%s (%s)" % (entry["file"], entry["label"]), results))
            continue
        notes = []
        if not full and not has_transparency(img):
            bg = remove_background(img)
            notes.append("background %s removed by flood fill" % (bg,))
        cols, rows = entry["grid"]
        cw, ch = w // cols, h // rows
        results = []
        sheet_cells = []
        for idx, cell in enumerate(entry["cells"]):
            if cell is None:
                continue
            cx, cy = idx % cols, idx // cols
            x0, y0 = cx * cw, cy * ch
            x1, y1 = x0 + cw, y0 + ch
            # "spill": the item may reach this many pixels into empty space
            # beyond its cell (checked by eye on the raw sheet).
            sp = cell.get("spill", 0)
            x0, y0, x1, y1 = max(0, x0 - sp), max(0, y0 - sp), min(w, x1 + sp), min(h, y1 + sp)
            tw, th = cell["size"]
            if full:
                box = (x0, y0, x1, y1)
                parts, touches = 1, False
            else:
                parts, box, touches = parts_in(img, x0, y0, x1, y1)
            if parts == 0 or box is None:
                results.append((cell["name"], "FAIL", "no item found in its cell"))
                continue
            problems = []
            # "edge_ok": the item may touch its cell's edge (a cursor drawn
            # right up to the border of its picture).
            if touches and not cell.get("edge_ok"):
                problems.append("item crosses its cell edge")
            expected = cell.get("parts", 1)
            if parts > expected:
                problems.append("%d separate pieces, expected %d" % (parts, expected))
            pix = shrink(img, box, tw, th, cell.get("stretch", False), full, cell.get("anchor", "bottom"))
            sheet_cells.append((cell["name"], tw, th))
            # A failed image is reported, not used: the stand-in stays in play.
            if not problems or entry.get("sheet"):
                shrunk.append((cell["name"], tw, th, pix))
            results.append((cell["name"], "FAIL" if problems else "pass", "; ".join(problems) or "%dx%d" % (tw, th)))
        if entry.get("sheet"):
            sheets.append((entry["sheet"], sheet_cells))
        report.append(("%s (%s)%s" % (entry["file"], entry["label"], ": " + "; ".join(notes) if notes else ""), results))
    for f in sorted(raw_files - listed):
        if f.lower().endswith(".png"):
            report.append((f, [("-", "SKIPPED", "not in the art manifest")]))

    # Palette: the style guide's palette is not in the repository yet, so the
    # lab uses a stand-in drawn from the raw art itself (64 colors).
    if os.path.exists(PALETTE):
        with open(PALETTE, encoding="utf-8") as f:
            palette = [tuple(c) for c in json.load(f)["colors"]]
        pal_note = "palette from art/palette.json (%d colors)" % len(palette)
    else:
        colors = [p[:3] for (_, _, _, pix) in shrunk for p in pix if p[3]]
        palette = median_cut(colors, 64)
        with open(PALETTE, "w", encoding="utf-8", newline="\n") as f:
            json.dump({"note": "Stand-in palette made by the lab from the raw art by median cut. Replace with the style guide palette.", "colors": [list(c) for c in palette]}, f, indent=1)
            f.write("\n")
        pal_note = "stand-in palette of %d colors made from the raw art (art/palette.json)" % len(palette)

    by_name = {}
    for name, tw, th, pix in shrunk:
        pix = snap(pix, palette)
        by_name[name] = (tw, th, pix)
        save(name, tw, th, pix)
    for sheet, cells in sheets:
        cols = sheet["cols"]
        fw, fh = cells[0][1], cells[0][2]
        rows = (len(cells) + cols - 1) // cols
        out = [(0, 0, 0, 0)] * (fw * cols * fh * rows)
        for i, (name, _, _) in enumerate(cells):
            tw, th, pix = by_name[name]
            ox, oy = (i % cols) * fw, (i // cols) * fh
            for y in range(th):
                for x in range(tw):
                    out[(oy + y) * fw * cols + ox + x] = pix[y * tw + x]
        save(sheet["name"], fw * cols, fh * rows, out)
        for name, _, _ in cells:
            os.remove(os.path.join(FINAL, name + ".png"))
    calm_keep = manifest.get("calm", {}).get("tiles", {})
    for name, tw, th, pix in exact:
        snapped = snap(pix, palette)
        if name in soft:
            snapped = [q[:3] + (p[3],) if p[3] else q for q, p in zip(snapped, pix)]
        pix = snapped
        if name in calm_keep:
            pix = calm(tw, th, pix, float(calm_keep[name]))
        save(name, tw, th, pix)

    lines = ["# Art cleanup report", "", "Made by tools/art_cleanup.py. " + pal_note + ". A picture cut pixel for pixel from a refresh sheet replaces any earlier picture of the same name.", ""]
    n_pass = n_fail = 0
    for title, results in report:
        lines.append("## " + title)
        lines.append("")
        for name, status, why in results:
            lines.append("- %s: **%s** %s" % (name, status, why))
            n_pass += status == "pass"
            n_fail += status == "FAIL"
        lines.append("")
    lines.insert(3, "%d images passed, %d failed." % (n_pass, n_fail))
    lines.insert(4, "")
    with open(REPORT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))


if __name__ == "__main__":
    main()
