"""Makes the plain stand-in pictures in art/placeholder/.

Flat palette colors, correct sizes, simple shapes. Finished art with the same
file name in art/final/ replaces each one with no code change.
Run: python tools/make_placeholders.py
"""
import json
import os
import random
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngio import write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "art", "placeholder")

P = {
    "clear": (0, 0, 0, 0),
    "ink": (40, 30, 30, 255),
    "grass": (98, 158, 72, 255),
    "grass_d": (78, 132, 60, 255),
    "tall": (126, 176, 70, 255),
    "tall_d": (84, 136, 50, 255),
    "floor": (96, 70, 48, 255),
    "floor_d": (78, 56, 40, 255),
    "trail": (196, 152, 98, 255),
    "trail_d": (172, 128, 82, 255),
    "shallow": (88, 160, 196, 255),
    "shallow_l": (130, 196, 222, 255),
    "deep": (34, 84, 128, 255),
    "deep_l": (52, 108, 150, 255),
    "rock": (110, 112, 120, 255),
    "rock_l": (150, 152, 160, 255),
    "rock_d": (78, 80, 90, 255),
    "leaf": (52, 112, 60, 255),
    "leaf_l": (82, 146, 72, 255),
    "pine": (36, 92, 64, 255),
    "pine_l": (60, 122, 80, 255),
    "bark": (110, 70, 42, 255),
    "dead": (168, 146, 118, 255),
    "wood": (150, 98, 58, 255),
    "wood_l": (186, 132, 80, 255),
    "wood_d": (110, 70, 40, 255),
    "roof": (176, 70, 52, 255),
    "roof_d": (136, 52, 40, 255),
    "glass": (150, 200, 220, 255),
    "glow": (250, 210, 90, 255),
    "metal": (90, 92, 100, 255),
    "metal_l": (150, 152, 160, 255),
    "red": (196, 56, 48, 255),
    "white": (236, 232, 220, 255),
    "cloth": (180, 60, 50, 255),
    "skin": (232, 180, 140, 255),
    "shirt": (92, 120, 60, 255),
    "pants": (150, 120, 80, 255),
    "hat": (196, 160, 104, 255),
    "hair": (90, 60, 40, 255),
    "paper": (230, 214, 170, 255),
    "yellow": (232, 196, 60, 255),
    "blue": (60, 100, 180, 255),
    "grey": (170, 176, 186, 255),
    "snow": (240, 244, 255, 255),
    "sun": (250, 200, 60, 255),
    "purple": (80, 40, 90, 255),
}


class Canvas:
    def __init__(self, w, h, fill="clear"):
        self.w, self.h = w, h
        self.px = [P[fill]] * (w * h)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = P[c] if isinstance(c, str) else c

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def outline(self, x, y, w, h, c="ink"):
        for xx in range(x, x + w):
            self.set(xx, y, c)
            self.set(xx, y + h - 1, c)
        for yy in range(y, y + h):
            self.set(x, yy, c)
            self.set(x + w - 1, yy, c)

    def disc(self, cx, cy, r, c, edge=None):
        for yy in range(int(cy - r - 1), int(cy + r + 2)):
            for xx in range(int(cx - r - 1), int(cx + r + 2)):
                d = ((xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2) ** 0.5
                if d <= r:
                    self.set(xx, yy, c)
                    if edge and d > r - 1:
                        self.set(xx, yy, edge)

    def tri(self, cx, top, base_y, half, c):
        for yy in range(top, base_y + 1):
            t = (yy - top) / max(1, base_y - top)
            hw = int(round(half * t))
            for xx in range(cx - hw, cx + hw):
                self.set(xx, yy, c)

    def speckle(self, c, count, seed):
        rnd = random.Random(seed)
        for _ in range(count):
            self.set(rnd.randrange(self.w), rnd.randrange(self.h), c)

    def save(self, name):
        data = bytearray()
        for p in self.px:
            data.extend(p)
        write_png(os.path.join(OUT, name + ".png"), self.w, self.h, data)


def ground():
    specs = {
        "trail": ("trail", "trail_d"),
        "grass": ("grass", "grass_d"),
        "forest_floor": ("floor", "floor_d"),
        "tall_grass": ("tall", "tall_d"),
        "shallows": ("shallow", "shallow_l"),
        "deep_water": ("deep", "deep_l"),
        "rock": ("rock", "rock_d"),
    }
    for i, (name, (base, spot)) in enumerate(specs.items()):
        c = Canvas(16, 16, base)
        if name == "tall_grass":
            for x in range(1, 16, 3):
                for y in range(2, 16, 5):
                    c.rect(x, y, 1, 3, spot)
        elif name in ("shallows", "deep_water"):
            for y in (3, 9, 14):
                c.rect(2 + (y % 5), y, 5, 1, spot)
        elif name == "rock":
            c.outline(0, 0, 16, 16, "rock_d")
            c.rect(3, 3, 5, 3, "rock_l")
            c.rect(9, 9, 4, 3, "rock_l")
        else:
            c.speckle(spot, 14, i)
        c.save("ground_" + name)


def trees():
    c = Canvas(32, 48)
    c.rect(14, 38, 4, 9, "bark")
    c.tri(16, 2, 40, 13, "pine")
    c.tri(16, 6, 30, 8, "pine_l")
    c.save("obj_tree_pine")
    c = Canvas(32, 48)
    c.rect(13, 36, 6, 11, "bark")
    c.tri(16, 4, 38, 15, "pine_l")
    c.tri(16, 10, 36, 11, "pine")
    c.save("obj_tree_fir")
    c = Canvas(32, 48)
    c.rect(13, 32, 6, 15, "bark")
    c.disc(16, 18, 14, "leaf", "pine")
    c.disc(12, 14, 5, "leaf_l")
    c.save("obj_tree_oak")
    c = Canvas(32, 48)
    c.rect(14, 14, 4, 33, "dead")
    for (x, y, w) in ((6, 12, 8), (18, 8, 9), (8, 22, 6), (18, 20, 8)):
        c.rect(x, y, w, 2, "dead")
    c.save("obj_tree_dead")


def objects():
    c = Canvas(16, 16)
    c.disc(8, 9, 7, "leaf", "pine")
    c.disc(6, 7, 2.5, "leaf_l")
    c.save("obj_bush")
    c = Canvas(16, 16)
    c.disc(8, 9, 7, "rock", "rock_d")
    c.rect(5, 5, 4, 2, "rock_l")
    c.save("obj_boulder")
    c = Canvas(48, 16)
    c.rect(1, 4, 46, 9, "bark")
    c.outline(1, 4, 46, 9, "wood_d")
    c.disc(44, 8, 4, "wood_l", "wood_d")
    c.save("obj_fallen_trunk")
    c = Canvas(16, 32)
    c.rect(2, 4, 2, 28, "wood_d")
    c.rect(12, 4, 2, 28, "wood_d")
    c.rect(1, 6, 14, 3, "wood")
    c.rect(1, 18, 14, 3, "wood")
    c.save("obj_gate")
    c = Canvas(16, 32)
    c.rect(7, 12, 2, 20, "wood_d")
    c.rect(2, 4, 12, 9, "wood_l")
    c.outline(2, 4, 12, 9, "wood_d")
    c.rect(5, 7, 6, 1, "ink")
    c.rect(5, 9, 4, 1, "ink")
    c.save("obj_outlook_post")


def buildings():
    # Station: 6x4 footprint, 96 wide; drawn 96x80 so the roof rises above.
    c = Canvas(96, 80)
    c.rect(4, 40, 88, 40, "wood")
    for y in range(44, 80, 6):
        c.rect(4, y, 88, 1, "wood_d")
    c.outline(4, 40, 88, 40, "ink")
    for y in range(4, 44):
        t = (y - 4) / 40
        hw = int(20 + 28 * t)
        c.rect(48 - hw, y, hw * 2, 1, "roof" if y % 6 else "roof_d")
    c.rect(64, 6, 8, 16, "metal")
    c.rect(40, 58, 16, 22, "wood_d")
    c.outline(40, 58, 16, 22, "ink")
    c.rect(52, 68, 2, 2, "yellow")
    c.rect(14, 52, 14, 12, "glass")
    c.outline(14, 52, 14, 12, "ink")
    c.rect(68, 52, 14, 12, "glass")
    c.outline(68, 52, 14, 12, "ink")
    c.save("building_station")
    for broken in (True, False):
        c = Canvas(64, 64)
        c.rect(4, 28, 56, 36, "wood" if not broken else "wood_d")
        for y in range(32, 64, 5):
            c.rect(4, y, 56, 1, "wood_d" if not broken else "floor_d")
        c.outline(4, 28, 56, 36, "ink")
        for y in range(2, 30):
            t = (y - 2) / 28
            hw = int(12 + 20 * t)
            c.rect(32 - hw, y, hw * 2, 1, "wood_l" if y % 5 else "wood_d")
        c.rect(26, 44, 12, 20, "floor_d" if broken else "wood_d")
        c.outline(26, 44, 12, 20, "ink")
        c.rect(8, 38, 10, 9, "ink" if broken else "glow")
        c.outline(8, 38, 10, 9, "ink")
        if broken:
            c.rect(16, 10, 8, 5, "ink")
            c.rect(40, 18, 6, 4, "ink")
            c.rect(36, 46, 3, 14, "wood")
            c.rect(44, 56, 10, 3, "wood_l")
        c.save("building_cabin_broken" if broken else "building_cabin_repaired")


def ranger():
    # 4 columns (walk frames) x 4 rows (down, right, up, left), 16x32 each.
    c = Canvas(64, 128)
    for row in range(4):
        for f in range(4):
            ox, oy = f * 16, row * 32
            step = (0, 1, 0, -1)[f]
            c.rect(ox + 5, oy + 26, 2, 5 + max(0, step), "pants")
            c.rect(ox + 9, oy + 26, 2, 5 + max(0, -step), "pants")
            c.rect(ox + 4, oy + 16, 8, 11, "shirt")
            c.rect(ox + 5, oy + 8, 6, 8, "skin")
            if row == 2:
                c.rect(ox + 5, oy + 8, 6, 7, "hair")
                c.rect(ox + 5, oy + 17, 6, 7, "wood_d")
            elif row == 1:
                c.rect(ox + 9, oy + 11, 1, 1, "ink")
                c.rect(ox + 4, oy + 17, 2, 7, "wood_d")
            elif row == 3:
                c.rect(ox + 6, oy + 11, 1, 1, "ink")
                c.rect(ox + 10, oy + 17, 2, 7, "wood_d")
            else:
                c.rect(ox + 6, oy + 11, 1, 1, "ink")
                c.rect(ox + 9, oy + 11, 1, 1, "ink")
            c.rect(ox + 1, oy + 6, 14, 2, "hat")
            c.rect(ox + 4, oy + 2, 8, 5, "hat")
            c.rect(ox + 4, oy + 5, 8, 1, "hair")
    c.save("ranger")


def interior():
    c = Canvas(16, 16, "wood_l")
    for y in (3, 8, 13):
        c.rect(0, y, 16, 1, "wood")
    c.save("interior_floor")
    c = Canvas(16, 16, "wood_d")
    for y in (4, 9, 14):
        c.rect(0, y, 16, 1, "bark")
    c.save("interior_wall")
    c = Canvas(32, 32)
    c.rect(1, 2, 30, 29, "wood_d")
    c.rect(3, 4, 26, 8, "white")
    c.rect(3, 12, 26, 17, "cloth")
    for x in range(3, 29, 4):
        c.rect(x, 12, 2, 17, "roof_d")
    c.save("furniture_bed")
    c = Canvas(16, 16)
    c.rect(1, 5, 14, 10, "wood")
    c.outline(1, 5, 14, 10, "ink")
    c.rect(3, 7, 5, 6, "wood_d")
    c.disc(11, 10, 2, "paper")
    c.rect(11, 1, 1, 5, "metal")
    c.save("furniture_radio")
    c = Canvas(32, 16)
    c.rect(1, 0, 30, 16, "wood_d")
    c.rect(2, 7, 28, 1, "wood_l")
    for x in range(4, 28, 5):
        c.rect(x, 2, 3, 4, "metal_l")
        c.rect(x, 9, 3, 5, "red")
    c.save("furniture_shelf")
    c = Canvas(16, 16)
    c.rect(1, 3, 14, 12, "wood")
    c.outline(1, 3, 14, 12, "ink")
    c.rect(1, 7, 14, 1, "wood_d")
    c.rect(7, 8, 2, 2, "yellow")
    c.save("furniture_chest")
    for lit in (False, True):
        c = Canvas(16, 16)
        c.rect(2, 4, 12, 11, "metal")
        c.outline(2, 4, 12, 11, "ink")
        c.rect(6, 0, 3, 5, "metal")
        c.rect(5, 8, 6, 4, "glow" if lit else "ink")
        c.save("furniture_stove_lit" if lit else "furniture_stove")
    c = Canvas(16, 16, "wood_d")
    c.rect(3, 0, 10, 16, "wood")
    c.outline(3, 0, 10, 16, "ink")
    c.save("furniture_door")


def icons():
    def icon(name, *shapes):
        c = Canvas(16, 16)
        for s in shapes:
            getattr(c, s[0])(*s[1:])
        c.save(name)

    icon("item_hammer", ("rect", 7, 5, 2, 10, "wood"), ("rect", 3, 2, 10, 4, "metal"))
    icon("item_lantern", ("rect", 4, 4, 8, 10, "metal"), ("rect", 5, 6, 6, 6, "glow"), ("rect", 6, 1, 4, 3, "metal"))
    icon("item_map", ("rect", 2, 3, 12, 10, "paper"), ("rect", 5, 5, 2, 6, "leaf"), ("rect", 9, 4, 2, 8, "blue"))
    icon("item_compass", ("disc", 8, 8, 6, "yellow", "ink"), ("disc", 8, 8, 4, "white"), ("rect", 8, 5, 1, 3, "red"), ("rect", 8, 8, 1, 3, "blue"))
    icon("item_pencil", *[("rect", 3 + i, 12 - i, 2, 2, "yellow") for i in range(9)], ("rect", 2, 13, 2, 2, "ink"))
    icon("item_tin_of_beans", ("rect", 4, 3, 8, 11, "red"), ("rect", 4, 3, 8, 2, "metal_l"), ("rect", 6, 7, 4, 3, "yellow"))
    icon("item_apple", ("disc", 8, 9, 5, "red"), ("rect", 8, 2, 1, 3, "bark"), ("rect", 9, 3, 3, 2, "leaf_l"))
    icon("item_sandwich", ("rect", 2, 5, 12, 3, "wood_l"), ("rect", 2, 8, 12, 2, "leaf_l"), ("rect", 2, 10, 12, 3, "wood_l"))
    icon("item_hot_soup", ("rect", 3, 8, 10, 5, "white"), ("rect", 4, 8, 8, 2, "wood"), ("rect", 5, 3, 1, 4, "grey"), ("rect", 9, 2, 1, 5, "grey"))
    icon("item_firewood", ("rect", 2, 9, 12, 4, "bark"), ("rect", 3, 5, 10, 4, "wood"), ("disc", 13, 11, 2, "wood_l"))
    icon("item_planks", ("rect", 1, 4, 14, 3, "wood_l"), ("rect", 1, 8, 14, 3, "wood"), ("outline", 1, 4, 14, 7, "wood_d"))
    icon("item_nails", *[s for x in (4, 8, 12) for s in (("rect", x, 4, 1, 9, "metal_l"), ("rect", x - 1, 4, 3, 1, "metal"))])
    icon("item_roofing", *[("rect", 1, y, 14, 2, "roof" if y % 4 else "roof_d") for y in range(3, 13, 2)])
    icon("item_window_glass", ("rect", 3, 2, 10, 12, "glass"), ("outline", 3, 2, 10, 12, "metal"), ("rect", 5, 4, 2, 2, "white"))

    icon("item_axe", ("rect", 7, 4, 2, 11, "wood"), ("rect", 3, 2, 6, 5, "metal"), ("rect", 3, 2, 2, 5, "metal_l"))
    icon("item_bedroll", ("rect", 2, 5, 12, 7, "leaf"), ("rect", 5, 5, 1, 7, "wood_d"), ("rect", 10, 5, 1, 7, "wood_d"))
    icon("item_saw", ("rect", 2, 7, 10, 4, "metal_l"), ("rect", 11, 6, 4, 6, "wood"), *[("rect", x, 11, 1, 1, "metal") for x in range(3, 12, 2)])
    icon("item_shovel", ("rect", 7, 1, 2, 9, "wood"), ("rect", 5, 9, 6, 5, "metal_l"), ("rect", 5, 1, 6, 2, "wood_d"))
    icon("item_trail_sign", ("rect", 7, 6, 2, 9, "wood_d"), ("rect", 2, 2, 12, 5, "wood_l"), ("outline", 2, 2, 12, 5, "wood_d"), ("rect", 4, 4, 6, 1, "ink"))
    icon("item_trail_marker", ("rect", 7, 3, 2, 12, "wood_l"), ("rect", 6, 3, 4, 2, "red"))
    icon("item_repair_kit", ("rect", 2, 5, 12, 6, "wood"), ("outline", 2, 5, 12, 6, "wood_d"), ("rect", 2, 7, 12, 1, "pants"), ("rect", 5, 3, 1, 2, "metal_l"), ("rect", 9, 3, 1, 2, "metal_l"))
    icon("obj_trail_marker", ("rect", 7, 4, 2, 12, "wood_l"), ("outline", 7, 4, 2, 12, "wood_d"), ("rect", 6, 4, 4, 2, "red"))
    icon("obj_sign_arrow", ("rect", 7, 6, 2, 10, "wood_d"), ("rect", 1, 2, 12, 5, "wood_l"), ("outline", 1, 2, 12, 5, "wood_d"))
    icon("obj_stump", ("rect", 4, 7, 8, 8, "bark"), ("disc", 8, 7, 4, "wood_l", "wood_d"))
    icon("obj_firepit", *[("disc", 8 + dx, 10 + dy, 2, "rock", "rock_d") for dx, dy in ((-4, 0), (4, 0), (0, -3), (0, 3))], ("rect", 6, 9, 4, 2, "bark"))
    icon("obj_campfire", *[("disc", 8 + dx, 12 + dy, 2, "rock", "rock_d") for dx, dy in ((-4, 0), (4, 0), (0, 2))], ("rect", 6, 11, 4, 2, "bark"), ("disc", 8, 8, 3, "red"), ("disc", 8, 9, 2, "glow"))
    icon("obj_camp_bedroll", ("rect", 3, 1, 10, 14, "leaf"), ("rect", 3, 1, 10, 3, "white"), ("outline", 3, 1, 10, 14, "pine"))
    icon("furniture_note_board", ("rect", 1, 2, 14, 11, "wood_d"), ("rect", 2, 3, 12, 9, "bark"), ("rect", 4, 4, 5, 6, "paper"), ("rect", 9, 6, 4, 4, "paper"), ("rect", 6, 4, 1, 1, "red"))

    icon("weather_clear", ("disc", 8, 8, 5, "sun"))
    icon("weather_clear_night", ("disc", 8, 8, 5, "white"), ("disc", 10, 6, 4, "clear"))
    icon("weather_overcast", ("disc", 6, 9, 4, "grey"), ("disc", 10, 8, 5, "grey"))
    icon("weather_rain", ("disc", 8, 6, 5, "grey"), *[("rect", x, 11, 1, 3, "blue") for x in (4, 8, 12)])
    icon("weather_fog", *[("rect", 2, y, 12, 2, "grey") for y in (4, 8, 12)])
    icon("weather_storm", ("disc", 8, 6, 5, "metal"), ("rect", 8, 9, 2, 3, "yellow"), ("rect", 6, 12, 2, 3, "yellow"))
    icon("weather_snow", ("disc", 8, 6, 5, "grey"), *[("rect", x, 12, 2, 2, "snow") for x in (3, 7, 11)])
    icon("weather_blizzard", *[("rect", 1 + (y % 3), y, 13, 1, "snow") for y in range(2, 15, 2)])


def ring_two_art():
    """Phase 2a: ground and objects for ring two, and the fire tower."""
    c = Canvas(16, 16, "floor_d")
    c.speckle("leaf", 12, 21)
    c.speckle("shallow", 8, 22)
    c.rect(3, 11, 4, 1, "shallow")
    c.save("ground_bog")
    c = Canvas(16, 16, "wood")
    for y in (0, 5, 10, 15):
        c.rect(0, y, 16, 1, "wood_d")
    c.rect(7, 2, 1, 1, "ink")
    c.rect(3, 12, 1, 1, "ink")
    c.save("ground_boards")
    c = Canvas(16, 16)
    c.rect(1, 3, 2, 13, "wood_d")
    c.rect(13, 3, 2, 13, "wood_d")
    for y in (6, 10):
        c.rect(0, y, 16, 1, "metal_l")
    c.save("obj_fence")
    c = Canvas(16, 16)
    c.disc(8, 9, 7, "pine", "ink")
    c.disc(5, 7, 2.5, "leaf")
    c.disc(11, 11, 2, "leaf")
    for (x, y) in ((4, 11), (9, 6), (12, 8), (7, 13)):
        c.rect(x, y, 1, 1, "purple")
    c.save("obj_thicket")
    c = Canvas(16, 16)
    for (x, y, r) in ((5, 10, 4), (11, 9, 4), (8, 6, 3.5)):
        c.disc(x, y, r, "tall_d", "pine")
    for (x, y) in ((3, 8), (12, 6), (8, 12), (10, 3)):
        c.rect(x, y, 1, 2, "bark")
    c.save("obj_brush")
    c = Canvas(32, 24)
    c.rect(1, 6, 30, 6, "wood")
    c.outline(1, 6, 30, 6, "wood_d")
    c.rect(3, 12, 3, 12, "wood_d")
    c.rect(26, 12, 3, 12, "wood_d")
    c.rect(8, 3, 6, 3, "metal_l")
    c.rect(18, 4, 8, 2, "wood_l")
    c.save("furniture_table")
    c = Canvas(16, 16)
    c.rect(7, 4, 2, 12, "wood_l")
    c.rect(9, 5, 4, 2, "red")
    c.rect(10, 7, 2, 1, "red")
    c.save("obj_survey_stake")
    c = Canvas(16, 16)
    c.disc(8, 12, 5, "rock", "rock_d")
    c.disc(8, 8, 3.5, "rock_l", "rock_d")
    c.disc(8, 4, 2.2, "rock", "rock_d")
    c.save("obj_cairn")
    c = Canvas(16, 32)
    c.rect(6, 6, 4, 26, "wood_d")
    c.rect(4, 4, 8, 3, "wood")
    c.outline(6, 6, 4, 26, "ink")
    c.save("obj_bridge_post")
    for broken in (True, False):
        c = Canvas(48, 112)
        leg = "wood_d" if broken else "wood"
        for x in (6, 40):
            c.rect(x, 40, 3, 72, leg)
        for y in range(48, 112, 16):
            for k in range(34):
                c.set(8 + k, y + k // 3, leg)
                c.set(40 - k, y + k // 3, leg)
        c.rect(4, 22, 40, 20, "wood" if not broken else "floor_d")
        c.outline(4, 22, 40, 20, "ink")
        c.rect(8, 26, 32, 8, "glow" if not broken else "ink")
        for y in range(6, 23):
            t = (y - 6) / 16
            hw = int(8 + 16 * t)
            c.rect(24 - hw, y, hw * 2, 1, "roof" if y % 4 else "roof_d")
        if broken:
            c.rect(14, 8, 8, 5, "ink")
            c.rect(30, 30, 6, 6, "floor_d")
            c.rect(20, 60, 3, 10, "clear")
        c.rect(20, 100, 8, 12, "wood_d")
        c.outline(20, 100, 8, 12, "ink")
        c.save("building_tower_broken" if broken else "building_tower_repaired")


def finds_art():
    """Stand-ins for the hidden things (spoilers; plain shapes)."""
    c = Canvas(16, 16)
    c.rect(6, 9, 4, 6, "wood_d")
    c.outline(6, 9, 4, 6, "ink")
    c.rect(5, 15, 6, 1, "red")
    c.save("obj_tiny_door")
    c = Canvas(48, 16)
    c.rect(2, 5, 44, 7, "red")
    c.outline(2, 5, 44, 7, "ink")
    c.rect(20, 7, 4, 3, "ink")
    c.save("obj_canoe")
    c = Canvas(48, 32)
    for i in range(20):
        c.rect(4 + i, 26 - i, 40 - 2 * i, 1, "wood" if i % 3 else "wood_d")
    c.rect(4, 26, 40, 6, "floor_d")
    c.save("obj_lean_to")
    c = Canvas(16, 16)
    for (x, y) in ((4, 10), (9, 8), (11, 12)):
        c.rect(x, y, 1, 3, "white")
        c.rect(x - 1, y - 1, 3, 2, "red")
    c.save("obj_mushrooms")
    c = Canvas(16, 16)
    c.disc(8, 9, 7, "leaf", "pine")
    for (x, y) in ((5, 7), (9, 6), (11, 10), (6, 11), (8, 9)):
        c.rect(x, y, 1, 1, "purple")
    c.save("obj_berry_bush")
    c = Canvas(32, 32)
    c.disc(16, 20, 12, "rock", "rock_d")
    c.disc(8, 12, 4, "rock", "rock_d")
    c.disc(24, 12, 4, "rock", "rock_d")
    c.rect(12, 22, 8, 1, "rock_d")
    c.save("obj_bear_boulder")
    c = Canvas(32, 48)
    c.rect(14, 30, 4, 17, "bark")
    c.rect(15, 36, 2, 4, "wood_l")
    c.tri(16, 2, 34, 13, "pine")
    c.save("obj_carved_tree")
    c = Canvas(32, 16)
    c.rect(2, 6, 28, 4, "rock_l")
    c.rect(4, 10, 3, 5, "rock")
    c.rect(25, 10, 3, 5, "rock")
    c.speckle("leaf", 8, 31)
    c.save("obj_stone_bench")
    c = Canvas(48, 32)
    c.rect(2, 10, 44, 18, "red")
    c.outline(2, 10, 44, 18, "ink")
    c.rect(30, 12, 12, 8, "glass")
    c.disc(10, 28, 3, "ink")
    c.disc(38, 28, 3, "ink")
    c.disc(16, 6, 6, "leaf", "pine")
    c.save("obj_rusted_truck")
    c = Canvas(16, 32)
    c.rect(7, 12, 2, 20, "wood_d")
    c.rect(1, 2, 14, 11, "paper")
    c.outline(1, 2, 14, 11, "wood_d")
    for y in (5, 8):
        c.rect(3, y, 10, 1, "ink")
    c.save("obj_toll_board")
    c = Canvas(16, 16)
    for (x, y) in ((3, 4), (7, 9), (11, 3), (12, 12)):
        c.rect(x, y, 2, 2, "floor_d")
    c.save("obj_pawprints")
    c = Canvas(32, 16)
    c.disc(8, 9, 7, "pine", "ink")
    c.disc(24, 9, 7, "pine", "ink")
    c.rect(12, 11, 8, 5, "floor_d")
    c.save("obj_berry_tunnel")
    c = Canvas(16, 16)
    c.rect(3, 2, 10, 12, "paper")
    c.outline(3, 2, 10, 12, "wood_d")
    for y in (5, 7, 9, 11):
        c.rect(5, y, 6, 1, "ink")
    c.save("item_journal_page")


def variety_art():
    """Stand-ins for the extra versions in data/content/art_variety.json
    (each a copy of its first version) and for the small ground details."""
    with open(os.path.join(ROOT, "data", "content", "art_variety.json"), encoding="utf-8") as f:
        rows = json.load(f)["rows"]
    for r in rows:
        first = os.path.join(OUT, r["pictures"][0] + ".png")
        for n in r["pictures"][1:]:
            shutil.copyfile(first, os.path.join(OUT, n + ".png"))
        for k, n in enumerate(r.get("details", [])):
            c = Canvas(16, 16)
            c.speckle("white" if "flower" in n or "dais" in n else "rock_l", 5, k + 1)
            c.save(n)
    shutil.copyfile(os.path.join(OUT, "furniture_table.png"), os.path.join(OUT, "furniture_workbench.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    ground()
    trees()
    objects()
    buildings()
    ranger()
    interior()
    icons()
    ring_two_art()
    finds_art()
    variety_art()
    print("placeholders written to", OUT, len(os.listdir(OUT)), "files")


if __name__ == "__main__":
    main()
