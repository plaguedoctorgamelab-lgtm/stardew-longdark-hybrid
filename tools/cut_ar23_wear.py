"""Builds the two worn layers of Art Request 23 from what came back.

- ranger_wear_sash: Mark's sash (cut by art_cleanup.py as ranger_sash_piece,
  7 x 12) laid across the ranger's chest on the four facing-down frames of a
  64 x 128 layer; the other facings stay empty (the request asked for
  facing down only).
- ranger_wear_marge_coat: the coat came back as whole ranger figures, not a
  layer, so the wool coat's layer is recoloured in the browns of Mark's coat
  (item_marge_coat), shade for shade by brightness.

Run after art_cleanup.py: python tools/cut_ar23_wear.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FINAL = os.path.join(ROOT, "art", "final")
FRAME_W, FRAME_H = 16, 32
SASH_AT = (4, 13)   # top left of the sash in a facing-down frame
COAT_SHADES = [(12, (28, 20, 20)), (22, (84, 52, 44)), (40, (132, 76, 52)), (999, (148, 92, 64))]


def load(name):
    return read_png(os.path.join(FINAL, name + ".png"))


def sash():
    sw, sh, sp = load("ranger_sash_piece")
    w, h = FRAME_W * 4, FRAME_H * 4
    out = bytearray(w * h * 4)
    for f in range(4):
        for y in range(sh):
            for x in range(sw):
                i = (y * sw + x) * 4
                if sp[i + 3]:
                    j = ((SASH_AT[1] + y) * w + f * FRAME_W + SASH_AT[0] + x) * 4
                    out[j:j + 4] = sp[i:i + 4]
    write_png(os.path.join(FINAL, "ranger_wear_sash.png"), w, h, out)


def coat():
    w, h, px = load("ranger_wear_wool_coat")
    out = bytearray(px)
    for i in range(0, len(out), 4):
        if out[i + 3]:
            lum = (out[i] * 3 + out[i + 1] * 6 + out[i + 2]) // 10
            out[i:i + 3] = bytes(next(c for top, c in COAT_SHADES if lum < top))
    write_png(os.path.join(FINAL, "ranger_wear_marge_coat.png"), w, h, out)


if __name__ == "__main__":
    sash()
    coat()
    print("ranger_wear_sash and ranger_wear_marge_coat written")
