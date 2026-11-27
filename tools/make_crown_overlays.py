"""Makes the Midsummer flower crown pieces from Mark's fest_flower_crown
(Art Request 27): a small crown for the townsfolk (fest_flower_crown_small)
and the ranger's overlay sheet (ranger_wear_crown, 4 x 4 frames of
16 x 32, the crown sat on the head in every frame).

Run: python -I tools/make_crown_overlays.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import read_png, write_png  # noqa: E402

FINAL = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art", "final")
CW, CH = 10, 6


def small_crown():
    w, h, px = read_png(os.path.join(FINAL, "fest_flower_crown.png"))
    out = bytearray(CW * CH * 4)
    for y in range(CH):
        for x in range(CW):
            sx, sy = x * w // CW, y * h // CH
            i = (sy * w + sx) * 4
            out[(y * CW + x) * 4:(y * CW + x) * 4 + 4] = px[i:i + 4]
    return out


def main():
    crown = small_crown()
    write_png(os.path.join(FINAL, "fest_flower_crown_small.png"), CW, CH, bytes(crown))
    w, h, px = read_png(os.path.join(FINAL, "ranger.png"))
    out = bytearray(w * h * 4)
    for fy in range(0, h, 32):
        for fx in range(0, w, 16):
            top = None
            for y in range(32):
                xs = [x for x in range(16) if px[((fy + y) * w + fx + x) * 4 + 3] > 0]
                if xs:
                    top = y
                    cx = (min(xs) + max(xs)) // 2
                    break
            if top is None:
                continue
            ox, oy = fx + cx - CW // 2 + 1, fy + max(0, top - 2)
            for y in range(CH):
                for x in range(CW):
                    c = crown[(y * CW + x) * 4:(y * CW + x) * 4 + 4]
                    if c[3] and 0 <= ox + x < w:
                        j = ((oy + y) * w + ox + x) * 4
                        out[j:j + 4] = c
    write_png(os.path.join(FINAL, "ranger_wear_crown.png"), w, h, bytes(out))
    print("wrote fest_flower_crown_small, ranger_wear_crown")


if __name__ == "__main__":
    main()
