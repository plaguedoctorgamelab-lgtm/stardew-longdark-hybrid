"""The art audit (Graphics Polish request, part two, 21 Nov 2026).

Inspects every finished picture in art/final, measures what can be measured,
and writes docs/art/art_audit.md: one row per picture with the problems found
(numbered as in the request's table), a severity from 1 to 3 and a fix, then
the ten pictures most worth redoing, each with a ready-to-paste prompt or a
note that it needs a hand pass. A contact sheet of the ten, each shown alone
at game size, enlarged, and under the night tint, goes to
docs/art/art_audit_top10.png.

Pictures for things the designer has not found (named in the spoiler
content) are counted only, never named.

Run: python tools/art_audit.py
"""

import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(__file__))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FINAL = os.path.join(ROOT, "art", "final")
CONTENT = os.path.join(ROOT, "data", "content")
TUNING = os.path.join(ROOT, "data", "tuning", "tuning.json")
MANIFEST = os.path.join(ROOT, "tools", "art_manifest.json")
OUT = os.path.join(ROOT, "docs", "art", "art_audit.md")
SHEET = os.path.join(ROOT, "docs", "art", "art_audit_top10.png")

PROBLEMS = {
    1: "Mush",
    2: "Stray pixels",
    3: "Unreadable icon",
    6: "Outline trouble",
    7: "Wrong scale",
    8: "Flat or banded",
    10: "Lost at night",
}

STYLE = ("True pixel art, crisp hard-edged pixels on an exact grid, every pixel a solid square, no anti-aliasing, "
         "no blur, no gradients, warm cozy 16-bit farming game style, bright cheerful palette, mid-century national "
         "park poster and scout patch feel, light from the top left.")

FIX = {
    1: "Redo with much simpler shapes, far fewer pixels",
    2: "Cleanup removes them; redo if many",
    3: "Redo with one bold shape and two or three colours",
    6: "Recolour black outlines to a dark shade of the object's own colour; redo if outlines are missing",
    7: "Resize in the manifest, or redo at the right size",
    8: "Redo, or a hand pass to set 2 to 3 tones per material",
    10: "Redo with stronger contrast, or brighten its lightest tone",
}

PROMPT_LINE = {
    1: "Draw it with MUCH simpler shapes and far fewer pixels: nothing finer than one game pixel, big flat areas of colour.",
    2: "Every pixel touches others of its own colour: no lone specks.",
    3: "ONE bold, simple shape with two or three colours, recognisable at a glance at 16 by 16.",
    6: "A one-pixel outline all round, in a dark shade of the object's own colour, never pure black.",
    7: "Drawn exactly at its game size, filling its picture.",
    8: "Two or three tones per material: a light, a mid and a dark, never one flat colour or a staircase of many.",
    10: "Strong contrast between its light and dark tones, so it still reads under a dark blue night tint.",
}


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def exposure(name):
    """How often the player sees a picture: 3 always on screen, 1 rarely."""
    if name.startswith(("ranger", "ground_", "tree_", "edge_", "ui_", "hud_")):
        return 3
    if name.startswith(("item_", "furniture_", "int_", "interior_", "building_", "obj_", "fac_", "forage_", "visitor_", "town_", "npc_")):
        return 2
    return 1


def spoiler_names():
    """Every picture named in the spoiler content: counted, never named."""
    names = set()
    for f in os.listdir(CONTENT):
        if not f.startswith("spoiler_") or not f.endswith(".json"):
            continue
        with open(os.path.join(CONTENT, f), encoding="utf-8") as fh:
            data = json.load(fh)

        def walk(v):
            if isinstance(v, dict):
                for k, x in v.items():
                    if k in ("sprite", "icon", "sprite_done", "picture", "art") and isinstance(x, str):
                        names.add(x)
                    walk(x)
            elif isinstance(v, list):
                for x in v:
                    walk(x)
        walk(data)
    return names


def target_sizes():
    with open(MANIFEST, encoding="utf-8") as f:
        m = json.load(f)
    out = {}
    for e in m["images"]:
        for c in e.get("cells", []):
            if c and "size" in c:
                out[c["name"]] = tuple(c["size"])
    return out


def measure(name, w, h, px, night):
    pix = [tuple(px[i:i + 4]) for i in range(0, len(px), 4)]
    solid = [i for i, p in enumerate(pix) if p[3] >= 128]
    m = {"w": w, "h": h, "solid": len(solid)}
    if not solid:
        return m
    colors = Counter(pix[i][:3] for i in solid)
    m["colors"] = len(colors)
    stray = 0
    edge = 0
    dark_edge = 0
    black = 0
    for i in solid:
        x, y = i % w, i // w
        c = pix[i][:3]
        same = False
        open_side = False
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                q = pix[ny * w + nx]
                if q[3] < 128:
                    open_side = True
                elif q[:3] == c:
                    same = True
            else:
                open_side = True
        if not same:
            stray += 1
        if open_side:
            edge += 1
            if lum(c) < 70:
                dark_edge += 1
            if max(c) < 14:
                black += 1
    m["stray"] = stray
    m["stray_share"] = stray / len(solid)
    m["edge"] = edge
    m["dark_edge_share"] = dark_edge / edge if edge else 1.0
    m["black_share"] = black / edge if edge else 0.0
    m["full"] = len(solid) == w * h
    tinted = sorted(lum((c[0] * night[0], c[1] * night[1], c[2] * night[2])) for c in (pix[i][:3] for i in solid))
    lo = tinted[len(tinted) // 10]
    hi = tinted[len(tinted) * 9 // 10]
    m["night_range"] = hi - lo
    top = colors.most_common(1)[0][1] / len(solid)
    m["flat_share"] = top
    return m


def judge(name, m, targets):
    """The problems found: [(number, severity)]."""
    out = []
    if m.get("solid", 0) == 0:
        return out
    small = m["w"] * m["h"] <= 32 * 32
    s = m["stray_share"]
    if s > 0.14:
        out.append((1, 3 if s > 0.22 else 2))
    elif s >= 0.05:
        out.append((2, 1 if s < 0.09 else 2))
    if name.startswith("item_") and (m["colors"] > 14 or s > 0.12):
        out.append((3, 2 if m["colors"] > 20 or s > 0.18 else 1))
    tile_like = name.startswith(("ground_", "edge_", "detail_", "town_", "interior_", "ui_", "cursor_", "hud_"))
    if not m["full"] and m["edge"] > 8 and not tile_like:
        if m["black_share"] > 0.15:
            out.append((6, 2))
        elif m["dark_edge_share"] < 0.25:
            out.append((6, 2 if m["dark_edge_share"] < 0.1 else 1))
    t = targets.get(name)
    # A picture cut pixel for pixel may be a little larger than its spot;
    # only a real mismatch counts.
    if t and (m["w"] < t[0] * 0.75 or m["h"] < t[1] * 0.75 or m["w"] > t[0] * 1.5 or m["h"] > t[1] * 1.5):
        out.append((7, 1))
    if not m["full"] and not tile_like and m["flat_share"] > 0.75 and m["solid"] > 40:
        out.append((8, 1))
    elif small and m["colors"] > 22:
        out.append((8, 1))
    if m["night_range"] < 6 and not name.startswith(("ground_", "edge_", "ui_", "cursor_", "interior_")):
        out.append((10, 2 if m["night_range"] < 3 else 1))
    return out


def main():
    with open(TUNING, encoding="utf-8") as f:
        night = json.load(f)["light"]["night_tint"]
    secret = spoiler_names()
    targets = target_sizes()
    rows = []
    hidden = 0
    for f in sorted(os.listdir(FINAL)):
        if not f.endswith(".png"):
            continue
        name = f[:-4]
        w, h, px = read_png(os.path.join(FINAL, f))
        m = measure(name, w, h, px, night)
        probs = judge(name, m, targets)
        sev = max((s for _, s in probs), default=0)
        if name in secret:
            hidden += 1
            continue
        rows.append({"name": name, "m": m, "probs": probs, "sev": sev, "score": sev * exposure(name) + 0.1 * len(probs)})
    rows.sort(key=lambda r: (-r["score"], r["name"]))
    top = [r for r in rows if r["sev"] > 0][:10]
    lines = [
        "# Strange Ranger: art audit",
        "",
        "Made by `tools/art_audit.py` from every finished picture in `art/final` (Graphics Polish request, part two). "
        "Measured: stray pixels, colours used, outline colour, size against the manifest's target, and the contrast left under the night tint. "
        "The rest of the request's twelve problems (wrong view, wrong light, visible repeats, wobbly frames, clashing pieces) need an eye in a test scene and are not scored here.",
        "",
        "**Severity:** 1 barely noticeable, 2 noticeable, 3 stands out in play. **Ranked** by severity times how often the picture is on screen (3 for the ranger, ground and trees, 2 for items, furniture and buildings, 1 for the rest).",
        "",
        "%d pictures checked; %d have something to look at. %d more are pictures of things not found yet, counted only." % (len(rows), sum(1 for r in rows if r["sev"]), hidden),
        "",
        "Contact sheet of the ten: `docs/art/art_audit_top10.png` (each alone at game size, enlarged four times, and under the night tint).",
        "",
        "## The ten most worth redoing",
        "",
    ]
    for n, r in enumerate(top, 1):
        m = r["m"]
        found = ", ".join("%s (%d)" % (PROBLEMS[p], s) for p, s in r["probs"])
        lines.append("### %d. `%s`" % (n, r["name"]))
        lines.append("")
        lines.append("%d by %d, %d colours, %d stray pixels (%d%%), night contrast %.0f. Found: %s." % (m["w"], m["h"], m.get("colors", 0), m.get("stray", 0), round(100 * m.get("stray_share", 0)), m.get("night_range", 0), found))
        lines.append("")
        if any(p == 11 for p, _ in r["probs"]):
            lines.append("Needs a hand pass.")
        else:
            extra = " ".join(PROMPT_LINE[p] for p, _ in r["probs"] if p in PROMPT_LINE)
            lines.append("```text")
            lines.append("%s Redraw `%s` at %d by %d game pixels, on a transparent background. %s Match the pixel size, colours and shading of the attached accepted pictures." % (STYLE, r["name"], m["w"], m["h"], extra))
            lines.append("```")
        lines.append("")
    lines += [
        "## The likely candidates",
        "",
        "The request named three to look at first:",
        "",
    ]
    rr = next((r for r in rows if r["name"] == "ranger"), None)
    if rr:
        lines.append("- **The ranger's walk frames:** %d colours, %d%% stray pixels, night contrast %.0f; %s." % (rr["m"]["colors"], round(100 * rr["m"]["stray_share"]), rr["m"]["night_range"], ", ".join(PROBLEMS[p] for p, _ in rr["probs"]) or "nothing measured wrong; the squat shape and wide hat need an eye"))
    tools = [r for r in rows if r["name"] in ("item_axe", "item_saw", "item_shovel", "item_hammer", "item_lantern", "item_compass")]
    if tools:
        lines.append("- **The tool icons:** " + "; ".join("`%s` %d colours, %d%% stray" % (r["name"], r["m"]["colors"], round(100 * r["m"]["stray_share"])) for r in tools) + ".")
    tiles = [r for r in rows if r["name"].startswith("interior_") and r["m"]["w"] == 16 and r["m"]["h"] == 16]
    if tiles:
        lines.append("- **The interior floor and wall tiles:** " + "; ".join("`%s` %s" % (r["name"], ", ".join(PROBLEMS[p] for p, _ in r["probs"]) or "nothing measured") for r in tiles) + ".")
    lines += ["", "## Every picture with something found", "", "| Picture | Size | Colours | Stray | Night | Problems (severity) | Fix |", "| --- | --- | --- | --- | --- | --- | --- |"]
    for r in rows:
        if not r["sev"]:
            continue
        m = r["m"]
        lines.append("| `%s` | %dx%d | %d | %d%% | %.0f | %s | %s |" % (r["name"], m["w"], m["h"], m.get("colors", 0), round(100 * m.get("stray_share", 0)), m.get("night_range", 0), ", ".join("%s (%d)" % (PROBLEMS[p], s) for p, s in r["probs"]), "; ".join(FIX[p] for p, _ in r["probs"])))
    lines.append("")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))
    _contact_sheet(top, night)
    print("wrote %s: %d checked, %d with findings, %d counted only" % (os.path.relpath(OUT, ROOT), len(rows), sum(1 for r in rows if r["sev"]), hidden))


def _contact_sheet(top, night):
    if not top:
        return
    Z = 4
    cells = []
    for r in top:
        w, h, px = read_png(os.path.join(FINAL, r["name"] + ".png"))
        cells.append((w, h, px))
    cw = max(w for w, _, _ in cells) * (1 + Z + 1) + 24
    ch = max(h for _, h, _ in cells) * Z + 8
    W, H = cw, ch * len(cells)
    out = bytearray([96, 128, 80, 255] * (W * H))

    def put(ox, oy, w, h, px, z, tint):
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if px[i + 3] < 128:
                    continue
                c = (px[i], px[i + 1], px[i + 2])
                if tint:
                    c = tuple(min(255, int(c[k] * night[k])) for k in range(3))
                for dy in range(z):
                    for dx in range(z):
                        j = ((oy + y * z + dy) * W + ox + x * z + dx) * 4
                        out[j:j + 4] = bytes(c + (255,))
    for n, (w, h, px) in enumerate(cells):
        oy = n * ch + 4
        put(4, oy, w, h, px, 1, False)
        put(12 + w, oy, w, h, px, Z, False)
        put(20 + w + w * Z, oy, w, h, px, 1, True)
    write_png(SHEET, W, H, out)


if __name__ == "__main__":
    main()
