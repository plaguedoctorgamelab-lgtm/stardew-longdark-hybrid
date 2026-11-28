"""A rough view of the split station (docs/Split Station Spec.md).

Draws the proposed room from the game's own sprites, the way
interior_view.gd draws a room: back wall, plank floor, trim, then each
piece standing on the bottom middle of its tiles. Pieces with no art yet use
a stand-in, listed in the spec. Writes docs/art/split_station_mock.png at
three times size.

Run: python tools/mock_split_station.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import pngio  # noqa: E402

T = 16
W, H, WH = 22, 11, 3          # tiles; back wall rows
PART_X, PART_DOOR_Y = 8, 7    # the inside wall, and its doorway
ART = os.path.join(os.path.dirname(__file__), "..", "art", "final")
OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "art", "split_station_mock.png")
SCALE = 3

img = bytearray(W * T * H * T * 4)


def put(x, y, rgba):
    if 0 <= x < W * T and 0 <= y < H * T:
        i = (y * W * T + x) * 4
        a = rgba[3] / 255.0
        if a <= 0:
            return
        for k in range(3):
            img[i + k] = int(rgba[k] * a + img[i + k] * (1 - a))
        img[i + 3] = 255


def rect(x0, y0, w, h, c):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            put(x, y, c)


_cache = {}


def sprite(name):
    if name not in _cache:
        w, h, px = pngio.read_png(os.path.join(ART, name + ".png"))
        _cache[name] = (w, h, px)
    return _cache[name]


def blit(name, px0, py0, crop=None):
    w, h, px = sprite(name)
    cx, cy, cw, ch = crop if crop else (0, 0, w, h)
    for y in range(ch):
        for x in range(cw):
            i = ((cy + y) * w + cx + x) * 4
            put(px0 + x, py0 + y, px[i:i + 4])


def piece(name, pos, size):
    """Stands on the bottom middle of its tiles, like interior_view.gd."""
    w, h, _ = sprite(name)
    bx = (pos[0] + size[0] / 2.0) * T
    by = (pos[1] + size[1]) * T
    blit(name, int(round(bx - w / 2.0)), int(by - h))


# Dark round the room.
rect(0, 0, W * T, H * T, (13, 10, 10, 255))
# Back wall and floor, both halves.
for x in range(1, W - 1):
    for y in range(WH):
        blit("interior_wall_base" if y == WH - 1 else "interior_back_wall", x * T, y * T)
    for y in range(WH, H - 1):
        blit("interior_plank_floor", x * T, y * T)

TRIM = (92, 58, 36, 255)
TRIM_HI = (150, 98, 58, 255)
WALLTOP = (54, 34, 24, 255)

# Windows, a picture and the coat hook.
for d in [("interior_window_curtains", 4, 0), ("interior_window_curtains", 11, 0),
          ("interior_window_curtains", 18, 0), ("interior_picture", 6, 1),
          ("interior_picture", 13, 1), ("furniture_coat_hook", 16, 1)]:
    blit(d[0], d[1] * T, d[2] * T)

# Rugs.
blit("interior_rug_round", 3 * T, 6 * T)
blit("interior_rug", 13 * T, 5 * T)
blit("interior_doormat", 3 * T + 8, 9 * T)
blit("interior_doormat", 14 * T + 8, 9 * T)

# The inside wall: a thick wall top from the ceiling to the floor's end, with
# a doorway one tile tall near the bottom, like the house in the picture.
for y in range(0, H - 1):
    if y == PART_DOOR_Y:
        continue
    rect(PART_X * T + 2, y * T, T - 4, T, WALLTOP)
    rect(PART_X * T, y * T, 2, T, TRIM)
    rect(PART_X * T + T - 2, y * T, 2, T, TRIM)
# The doorway's lintel and step.
rect(PART_X * T, PART_DOOR_Y * T, T, 2, TRIM_HI)
rect(PART_X * T, PART_DOOR_Y * T + T - 2, T, 2, TRIM)
# Trim round the outside.
rect(T - 2, 0, 2, (H - 1) * T + 2, TRIM)
rect((W - 1) * T, 0, 2, (H - 1) * T + 2, TRIM)
rect(T - 2, (H - 1) * T, (W - 2) * T + 4, 2, TRIM)

# The two doors out.
for dx in (4, 15):
    blit("furniture_door", dx * T, (H - 1) * T)

# The living half.
LIVING = [
    ("int_bed", (1, 3), (2, 2)),
    ("furniture_oil_lamp", (3, 3), (1, 1)),        # stand-in: the nightstand
    ("furniture_table_chairs", (5, 3), (2, 2)),
    ("furniture_stove", (1, 8), (2, 1)),           # the woodstove
    ("int_chest", (5, 8), (2, 1)),
]
# The station half.
STATION = [
    ("furniture_radio", (10, 3), (1, 1)),
    ("furniture_note_board", (12, 3), (1, 1)),
    ("furniture_wardrobe", (14, 3), (2, 1)),       # stand-in: the supply closet
    ("furniture_staff_board", (17, 3), (1, 1)),
    ("furniture_oil_lamp", (19, 3), (1, 1)),
    ("int_workbench", (10, 7), (3, 1)),
    ("furniture_catalog_desk", (17, 6), (2, 1)),
    ("int_chest", (18, 8), (2, 1)),
]
# Back to front, so nearer pieces cover farther ones.
for name, pos, size in sorted(LIVING + STATION, key=lambda p: p[1][1] + p[2][1]):
    piece(name, pos, size)

# Three times size, for reading.
big = bytearray(W * T * SCALE * H * T * SCALE * 4)
bw = W * T * SCALE
for y in range(H * T * SCALE):
    for x in range(bw):
        si = ((y // SCALE) * W * T + x // SCALE) * 4
        di = (y * bw + x) * 4
        big[di:di + 4] = img[si:si + 4]
pngio.write_png(OUT, bw, H * T * SCALE, big)
print("wrote", os.path.abspath(OUT))
