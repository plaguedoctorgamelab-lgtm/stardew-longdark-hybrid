"""Stand-ins for the Interior Art Guide's pieces and phase 4's town (21 Nov
2026): plain shapes at the right sizes, so the game runs before the art
comes. Finished art with the same name in art/final/ replaces each one.
Called from make_placeholders.py.
"""


def interior_guide_art(Canvas):
    c = Canvas(32, 48)
    c.rect(2, 4, 28, 42, "wood")
    c.rect(4, 8, 24, 8, "white")
    c.rect(4, 16, 24, 26, "cloth")
    c.outline(2, 4, 28, 42, "wood_d")
    c.save("int_bed")
    for name, fire in (("int_stove", "metal"), ("int_stove_lit", "glow")):
        c = Canvas(32, 32)
        c.rect(12, 0, 6, 10, "metal")
        c.rect(4, 10, 24, 20, "metal")
        c.rect(10, 16, 12, 8, fire)
        c.outline(4, 10, 24, 20, "ink")
        c.save(name)
    for name in ("int_workbench", "int_desk"):
        c = Canvas(48, 32)
        c.rect(1, 8, 46, 8, "wood_l")
        c.rect(3, 16, 4, 16, "wood_d")
        c.rect(41, 16, 4, 16, "wood_d")
        c.rect(30, 16, 10, 12, "wood")
        c.outline(1, 8, 46, 8, "wood_d")
        c.save(name)
    c = Canvas(32, 32)
    c.rect(2, 10, 28, 20, "wood")
    c.rect(2, 14, 28, 2, "metal")
    c.rect(14, 16, 4, 4, "metal_l")
    c.outline(2, 10, 28, 20, "wood_d")
    c.save("int_chest")
    c = Canvas(32, 48)
    c.rect(2, 2, 28, 46, "wood_d")
    for y in (6, 20, 34):
        c.rect(4, y, 24, 10, "wood")
        c.rect(6, y + 2, 6, 6, "paper")
        c.rect(18, y + 2, 6, 6, "red")
    c.save("int_supply_shelf")
    c = Canvas(16, 24)
    c.rect(3, 2, 10, 12, "wood")
    c.rect(2, 12, 12, 4, "wood_l")
    c.rect(3, 16, 2, 8, "wood_d")
    c.rect(11, 16, 2, 8, "wood_d")
    c.save("furniture_chair")


# --- Phase 4: Humdrum ---------------------------------------------------------

INK = (26, 22, 32, 255)
CREAM = (246, 236, 208, 255)
GLASS = (130, 190, 214, 255)
WOOD = (157, 102, 62, 255)
WOOD_D = (93, 62, 48, 255)
WOOD_L = (199, 144, 95, 255)
STONE = (182, 176, 168, 255)
STONE_D = (130, 124, 120, 255)
GOLD = (232, 196, 60, 255)


def _shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def _building(Canvas, wt, ht, wall, roof, door=WOOD, sign=None, windows=2, siding=True):
    """A small town building on its footprint: a gabled roof, siding,
    windows, a door in the middle and a sign board above it. A tile taller
    than its footprint, like the park's buildings."""
    W, H = wt * 16, ht * 16 + 16
    c = Canvas(W, H)
    roof_h = H * 2 // 5
    wall_top = roof_h - 2
    wall_d = _shade(wall, 0.8)
    c.rect(2, wall_top, W - 4, H - wall_top, wall)
    if siding:
        for y in range(wall_top + 3, H, 4):
            c.rect(3, y, W - 6, 1, wall_d)
    for y in range(4, roof_h + 1):
        t = (y - 4) / max(1, roof_h - 4)
        half = int(W * 0.18 + (W / 2 + 1 - W * 0.18) * t)
        c.rect(W // 2 - half, y, half * 2, 1, roof if (y // 3) % 2 else _shade(roof, 0.88))
    c.rect(W // 2 - 1, 3, 2, roof_h - 3, _shade(roof, 1.15))
    c.rect(0, roof_h, W, 1, _shade(roof, 0.6))
    wy = wall_top + 6
    xs = [W // 5, W - W // 5 - 10] if windows == 2 else [W // 7, W - W // 7 - 10]
    for x in xs:
        c.rect(x, wy, 10, 10, GLASS)
        c.rect(x, wy, 10, 3, _shade(GLASS, 1.15))
        c.outline(x, wy, 10, 10, WOOD_D)
        c.rect(x + 4, wy, 1, 10, WOOD_D)
        c.rect(x - 1, wy + 10, 12, 2, CREAM)
    dw, dh = 12, 18
    dx = W // 2 - dw // 2
    c.rect(dx, H - dh - 2, dw, dh, door)
    c.outline(dx, H - dh - 2, dw, dh, _shade(door, 0.6))
    c.rect(dx + dw - 4, H - dh // 2 - 2, 2, 2, GOLD)
    c.rect(dx - 2, H - 2, dw + 4, 2, STONE)
    if sign:
        sw = min(W - 8, 36)
        sy = H - dh - 12
        c.rect(W // 2 - sw // 2, sy, sw, 7, sign)
        c.outline(W // 2 - sw // 2, sy, sw, 7, WOOD_D)
        for x in range(W // 2 - sw // 2 + 3, W // 2 + sw // 2 - 3, 3):
            c.rect(x, sy + 3, 2, 1, WOOD_D)
    c.outline(2, wall_top, W - 4, H - wall_top, INK)
    return c


def town_art(Canvas):
    houses = [
        ("town_house_blue", (120, 168, 214), (176, 70, 52)),
        ("town_house_pink", (236, 170, 178), (90, 110, 150)),
        ("town_house_green", (150, 196, 140), (110, 70, 40)),
        ("town_house_yellow", (240, 214, 120), (56, 110, 80)),
        ("town_house_terracotta", (214, 130, 90), (150, 98, 58)),
        ("town_house_log", (170, 116, 70), (70, 74, 90)),
        ("town_house_studio", (214, 220, 230), (100, 150, 190)),
    ]
    for name, wall, roof in houses:
        _building(Canvas, 5, 5, wall + (255,), roof + (255,), siding=name != "town_house_log").save(name)
    _building(Canvas, 6, 6, (236, 226, 200, 255), (70, 74, 90, 255), windows=3).save("town_house_big")
    _building(Canvas, 6, 6, (56, 110, 80, 255), (150, 98, 58, 255), sign=CREAM).save("town_outfitters")
    _building(Canvas, 5, 5, (220, 110, 150, 255), (246, 236, 208, 255), door=(100, 150, 190, 255), sign=CREAM).save("town_gifts")
    c = _building(Canvas, 7, 6, (190, 140, 90, 255), (110, 70, 40, 255), sign=CREAM)
    for y in range(84, 108, 4):
        c.rect(6, y, 18, 3, WOOD_L)
        c.rect(6, y + 3, 18, 1, WOOD_D)
    c.save("town_carpentry")
    c = _building(Canvas, 7, 7, STONE, (90, 60, 120, 255), door=(90, 60, 120, 255), sign=CREAM, siding=False)
    for x in (8, 26, 80, 98):
        c.rect(x, 66, 6, 60, CREAM)
        c.outline(x, 66, 6, 60, STONE_D)
    c.save("town_library")
    c = _building(Canvas, 7, 6, (226, 214, 190, 255), (176, 70, 52, 255), sign=CREAM, siding=False)
    c.disc(56, 28, 6, CREAM, INK)
    c.rect(56, 24, 1, 4, INK)
    c.rect(56, 28, 3, 1, INK)
    c.save("town_hall")
    # The caravan: a painted wagon on wheels under its curved roof.
    c = Canvas(64, 56)
    c.rect(4, 12, 56, 32, (90, 60, 130, 255))
    for y in range(6, 14):
        c.rect(4 + (13 - y) // 2, y, 56 - (13 - y), 1, GOLD)
    for x in (8, 44):
        c.rect(x, 18, 10, 10, GLASS)
        c.outline(x, 18, 10, 10, GOLD)
    c.rect(26, 22, 12, 22, (176, 70, 52, 255))
    for x in range(6, 58, 6):
        c.rect(x, 40, 3, 2, GOLD)
    c.outline(4, 12, 56, 32, INK)
    for cx in (14, 50):
        c.disc(cx, 48, 7, WOOD_D, INK)
        c.disc(cx, 48, 2, GOLD)
    c.save("town_caravan")
    # The bandstand: posts under an eight-sided roof, on a stone base.
    c = Canvas(112, 112)
    c.rect(4, 86, 104, 22, STONE)
    c.outline(4, 86, 104, 22, STONE_D)
    for x in (10, 34, 74, 98):
        c.rect(x, 40, 4, 48, CREAM)
        c.outline(x, 40, 4, 48, STONE_D)
    for y in range(6, 42):
        t = (y - 6) / 36
        half = int(10 + 46 * t)
        c.rect(56 - half, y, half * 2, 1, (56, 110, 80, 255) if (y // 3) % 2 else (46, 96, 70, 255))
    c.rect(0, 40, 112, 4, CREAM)
    for x in range(4, 108, 6):
        c.rect(x, 72, 2, 14, CREAM)
    c.rect(4, 72, 104, 2, CREAM)
    c.save("town_bandstand")
    # The notice board: a little roofed board on two posts.
    c = Canvas(16, 32)
    c.rect(2, 2, 12, 3, (176, 70, 52, 255))
    c.rect(2, 5, 12, 14, WOOD_L)
    c.outline(2, 5, 12, 14, WOOD_D)
    for x, y in ((4, 7), (9, 8), (5, 12)):
        c.rect(x, y, 4, 4, CREAM)
    c.rect(3, 19, 2, 13, WOOD_D)
    c.rect(11, 19, 2, 13, WOOD_D)
    c.save("town_notice_board")
    # A streetlamp: a dark post with a warm lantern.
    c = Canvas(16, 40)
    c.rect(7, 10, 2, 30, (70, 74, 90, 255))
    c.rect(5, 38, 6, 2, (70, 74, 90, 255))
    c.rect(4, 2, 8, 9, (250, 210, 90, 255))
    c.outline(4, 2, 8, 9, (70, 74, 90, 255))
    c.rect(3, 1, 10, 2, (70, 74, 90, 255))
    c.save("town_streetlamp")
    # Stand-ins for the pieces Mark has drawn, in case a sheet goes missing.
    _building(Canvas, 5, 5, (236, 226, 200, 255), (56, 110, 80, 255), sign=CREAM).save("town_percolator")
    _building(Canvas, 6, 4, (214, 130, 90, 255), (150, 98, 58, 255), sign=CREAM).save("town_casa_luna")
    tiles = {"town_lawn": (110, 160, 80), "town_cobbles": (160, 150, 140), "town_gravel": (210, 196, 170), "town_flowerbed_warm": (90, 60, 40),
             "town_flowerbed_cool": (90, 60, 40), "town_boards": (150, 98, 58), "town_doormat": (190, 150, 90), "town_kerb": (150, 146, 140)}
    for name, col in tiles.items():
        c = Canvas(16, 16)
        c.rect(0, 0, 16, 16, col + (255,))
        c.save(name)
        alts = 3 if name in ("town_lawn", "town_cobbles") else (1 if name in ("town_gravel", "town_kerb") else 0)
        for k in range(1, alts + 1):
            c.save("%s_alt_%d" % (name, k))
    c = Canvas(64, 128)
    for fy in range(4):
        for fx in range(4):
            ox, oy = fx * 16, fy * 32
            c.rect(ox + 5, oy + 10, 6, 6, (170, 120, 90, 255))
            c.rect(ox + 4, oy + 6, 8, 5, (30, 24, 24, 255))
            c.rect(ox + 4, oy + 16, 8, 10, (232, 180, 60, 255))
            c.rect(ox + 5, oy + 26, 6, 6, (40, 40, 40, 255))
    c.save("npc_wren")
