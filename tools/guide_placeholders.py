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
