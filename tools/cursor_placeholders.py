"""Stand-in mouse cursors (tracker #8), run by make_placeholders.py or alone.

Two pictures in art/placeholder/, drawn on a 12 x 12 grid and doubled to
24 x 24 so they read at the game's window size:
  cursor_arrow  the usual pointer: cream with a walnut edge;
  cursor_pick   a small pointer with a green plus, over forage in reach.
The point of both is the top-left pixel (the hotspot the game uses).

Run: python tools/cursor_placeholders.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "placeholder")
COLORS = {".": (0, 0, 0, 0), "k": (66, 44, 34, 255), "w": (252, 248, 237, 255),
          "g": (56, 142, 76, 255), "G": (167, 218, 133, 255)}

ARROW = [
    "k...........",
    "kk..........",
    "kwk.........",
    "kwwk........",
    "kwwwk.......",
    "kwwwwk......",
    "kwwwwwk.....",
    "kwwwwwwk....",
    "kwwwwkkkk...",
    "kwkwwk......",
    "kk.kwwk.....",
    "....kk......",
]

PICK = [
    "k...........",
    "kk..........",
    "kwk.........",
    "kwwk........",
    "kwwwk.......",
    "kwkkk.kkk...",
    "kk....kGk...",
    "....kkkGkkk.",
    "....kGGGGGk.",
    "....kkkGkkk.",
    "......kGk...",
    "......kkk...",
]


def save(name, rows):
    w = 12
    px = bytearray()
    grid = [r[:w].ljust(w, ".") for r in rows]
    for r in grid:
        line = bytearray()
        for ch in r:
            line.extend(COLORS.get(ch, COLORS["."]) * 2)
        px.extend(line * 2)
    write_png(os.path.join(OUT, name + ".png"), w * 2, len(grid) * 2, bytes(px))


def cursor_art():
    os.makedirs(OUT, exist_ok=True)
    save("cursor_arrow", ARROW)
    save("cursor_pick", PICK)


if __name__ == "__main__":
    cursor_art()
    print("cursors written to", OUT)
