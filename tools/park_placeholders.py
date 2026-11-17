"""Stand-ins for phase 3, run by make_placeholders.py.

Visitors are made of layers: a plain body, and clothes, hats and packs drawn
in pale greys so the game can colour them, all on one sheet layout (4
walking frames across, 4 directions down: down, right, up, left; 16 x 24
each). Also the troll badger, the facilities, small placed things, litter,
gift goods and the station's catalog desk and staff board.
"""

G = {"w": (250, 250, 250, 255), "l": (210, 210, 210, 255), "m": (160, 160, 160, 255), "d": (110, 110, 110, 255)}


def park_art(Canvas):
    def pic(name, *shapes, size=(16, 16)):
        c = Canvas(*size)
        for sh in shapes:
            getattr(c, sh[0])(*sh[1:])
        c.save(name)

    def sheet(name, draw):
        c = Canvas(64, 96)
        for row in range(4):
            for f in range(4):
                draw(c, f * 16, row * 24, row, (0, 1, 0, -1)[f])
        c.save(name)

    def body(c, ox, oy, row, step):
        c.rect(ox + 6, oy + 4, 5, 6, G["w"])
        c.outline(ox + 5, oy + 3, 7, 8, "ink")
        if row == 0:
            c.set(ox + 7, oy + 7, "ink")
            c.set(ox + 9, oy + 7, "ink")
        elif row == 1:
            c.set(ox + 10, oy + 7, "ink")
        elif row == 3:
            c.set(ox + 6, oy + 7, "ink")
        c.rect(ox + 4, oy + 12, 1, 5, G["l"])
        c.rect(ox + 12, oy + 12, 1, 5, G["l"])
        c.rect(ox + 6, oy + 19, 2, 4 + max(0, step), G["l"])
        c.rect(ox + 9, oy + 19, 2, 4 + max(0, -step), G["l"])

    def shirt(c, ox, oy, row, step):
        c.rect(ox + 5, oy + 11, 7, 7, G["w"])
        c.rect(ox + 5, oy + 17, 7, 1, G["m"])

    def pants(c, ox, oy, row, step):
        c.rect(ox + 5, oy + 18, 7, 2, G["w"])
        c.rect(ox + 6, oy + 20, 2, 2 + max(0, step), G["l"])
        c.rect(ox + 9, oy + 20, 2, 2 + max(0, -step), G["l"])

    def hair(c, ox, oy, row, step):
        c.rect(ox + 5, oy + 2, 7, 2, G["m"])
        if row == 2:
            c.rect(ox + 5, oy + 2, 7, 7, G["m"])

    def hat_cap(c, ox, oy, row, step):
        c.rect(ox + 5, oy + 1, 7, 3, G["w"])
        c.rect(ox + (3 if row == 3 else 5), oy + 3, 9 if row in (1, 3) else 7, 1, G["l"])

    def hat_wide(c, ox, oy, row, step):
        c.rect(ox + 6, oy, 5, 3, G["w"])
        c.rect(ox + 3, oy + 3, 11, 1, G["l"])

    def hat_beanie(c, ox, oy, row, step):
        c.rect(ox + 5, oy + 1, 7, 3, G["w"])
        c.rect(ox + 8, oy, 1, 1, G["l"])

    def pack_small(c, ox, oy, row, step):
        if row == 0:
            c.rect(ox + 5, oy + 11, 1, 6, G["d"])
            c.rect(ox + 11, oy + 11, 1, 6, G["d"])
        elif row == 2:
            c.rect(ox + 5, oy + 11, 7, 7, G["w"])
            c.outline(ox + 5, oy + 11, 7, 7, G["d"])
        else:
            c.rect(ox + (3 if row == 1 else 11), oy + 11, 3, 6, G["w"])

    def pack_big(c, ox, oy, row, step):
        if row == 0:
            c.rect(ox + 4, oy + 9, 1, 9, G["d"])
            c.rect(ox + 12, oy + 9, 1, 9, G["d"])
        elif row == 2:
            c.rect(ox + 4, oy + 8, 9, 10, G["w"])
            c.outline(ox + 4, oy + 8, 9, 10, G["d"])
            c.rect(ox + 4, oy + 8, 9, 2, G["l"])
        else:
            c.rect(ox + (2 if row == 1 else 11), oy + 8, 4, 10, G["w"])

    def scarf(c, ox, oy, row, step):
        c.rect(ox + 6, oy + 11, 5, 1, G["w"])
        if row == 0:
            c.tri(ox + 8, oy + 11, oy + 14, 2, G["w"])

    for name, fn in (("visitor_body", body), ("visitor_shirt", shirt), ("visitor_pants", pants), ("visitor_hair", hair),
                     ("visitor_hat_cap", hat_cap), ("visitor_hat_wide", hat_wide), ("visitor_hat_beanie", hat_beanie),
                     ("visitor_pack_small", pack_small), ("visitor_pack_big", pack_big), ("visitor_scarf", scarf)):
        sheet(name, fn)

    # The troll badger: two walking frames, sitting, asleep. 16 x 16 each.
    c = Canvas(64, 16)
    for f in range(4):
        ox = f * 16
        if f == 3:
            c.disc(ox + 8, 12, 4.5, "metal", "ink")
            c.rect(ox + 4, 11, 8, 1, "white")
            c.set(ox + 12, 8, "white")
            c.set(ox + 13, 7, "white")
            continue
        c.disc(ox + 8, 10, 5, "metal", "ink")
        c.rect(ox + 5, 6, 6, 2, "white")
        c.rect(ox + 7, 5, 2, 6, "white")
        c.set(ox + 6, 9, "red")
        c.set(ox + 10, 9, "red")
        c.rect(ox + 7, 11, 2, 1, "ink")
        if f < 2:
            c.rect(ox + 4 + f, 15, 2, 1, "ink")
            c.rect(ox + 10 - f, 15, 2, 1, "ink")
    c.save("troll_badger")

    # Facilities, standing on the bottom of their pads.
    c = Canvas(48, 40)
    c.rect(2, 14, 44, 24, "wood")
    c.outline(2, 14, 44, 24, "ink")
    c.tri(24, 2, 14, 24, "roof")
    c.rect(8, 20, 32, 8, "wood_d")
    c.rect(10, 21, 28, 6, "paper")
    c.rect(8, 28, 32, 2, "wood_l")
    for x in (12, 20, 28):
        c.rect(x, 31, 5, 3, "cloth")
    c.save("fac_kiosk")
    pic("fac_suggestion_box", ("rect", 7, 10, 2, 14, "wood_d"), ("rect", 3, 3, 10, 9, "roof"), ("outline", 3, 3, 10, 9, "ink"), ("rect", 5, 6, 6, 1, "ink"), size=(16, 24))
    for badger in (False, True):
        c = Canvas(32, 40)
        c.rect(2, 10, 28, 28, "wood_l")
        c.outline(2, 10, 28, 28, "ink")
        c.tri(16, 2, 10, 16, "roof_d")
        c.rect(5, 14, 9, 22, "wood_d")
        c.rect(18, 14, 9, 22, "wood_d")
        c.disc(9, 18, 1.5, "white")
        c.disc(22, 18, 1.5, "white")
        if badger:
            c.disc(9, 30, 4, "metal", "ink")
            c.rect(6, 27, 6, 2, "white")
            c.rect(14, 22, 4, 6, "paper")
        c.save("fac_bathroom_badger" if badger else "fac_bathroom")
    c = Canvas(64, 32)
    for ox in (2, 34):
        c.rect(ox, 12, 28, 6, "wood_l")
        c.outline(ox, 12, 28, 6, "wood_d")
        c.rect(ox + 2, 8, 24, 3, "wood")
        c.rect(ox + 2, 19, 24, 3, "wood")
        c.rect(ox + 4, 18, 2, 10, "wood_d")
        c.rect(ox + 22, 18, 2, 10, "wood_d")
    c.save("fac_picnic_area")
    c = Canvas(96, 64)
    for (x, y, col) in ((6, 6, "cloth"), (36, 2, "blue"), (66, 6, "yellow"), (6, 36, "leaf_l"), (66, 36, "roof"), (36, 44, "cloth")):
        c.tri(x + 12, y, y + 16, 12, col)
        c.tri(x + 12, y + 6, y + 16, 3, "ink")
    c.disc(48, 30, 6, "rock", "rock_d")
    c.disc(48, 30, 3, "ink")
    c.rect(46, 28, 4, 3, "glow")
    c.save("fac_campground")
    c = Canvas(32, 112)
    for y in range(0, 112, 6):
        c.rect(1, y, 30, 5, "wood_l")
        c.rect(1, y + 5, 30, 1, "wood_d")
    for y in range(4, 112, 24):
        c.rect(1, y, 3, 6, "wood_d")
        c.rect(28, y, 3, 6, "wood_d")
    c.save("fac_dock")
    pic("fac_lookout_sign", ("rect", 7, 10, 2, 14, "wood_d"), ("rect", 2, 3, 12, 8, "paper"), ("outline", 2, 3, 12, 8, "wood_d"), ("rect", 4, 5, 8, 1, "leaf"), ("rect", 4, 8, 6, 1, "leaf"), size=(16, 24))
    pic("obj_pad_stakes", ("rect", 3, 6, 1, 10, "wood_l"), ("rect", 12, 8, 1, 8, "wood_l"), ("rect", 4, 6, 6, 3, "roof"), ("rect", 4, 13, 8, 1, "yellow"))
    pic("obj_kit_crates", ("rect", 1, 7, 9, 8, "wood_l"), ("outline", 1, 7, 9, 8, "wood_d"), ("rect", 7, 3, 8, 7, "wood"), ("outline", 7, 3, 8, 7, "wood_d"), ("rect", 2, 10, 7, 1, "wood_d"))
    pic("obj_rent_sign", ("rect", 7, 9, 2, 7, "wood_d"), ("rect", 2, 3, 12, 7, "paper"), ("outline", 2, 3, 12, 7, "wood_d"), ("rect", 4, 5, 8, 1, "roof"), ("rect", 4, 7, 6, 1, "roof"))

    # Small placed things.
    pic("obj_bench", ("rect", 1, 5, 14, 3, "wood"), ("rect", 1, 9, 14, 3, "wood_l"), ("rect", 2, 12, 2, 4, "wood_d"), ("rect", 12, 12, 2, 4, "wood_d"), ("outline", 1, 9, 14, 3, "wood_d"))
    for name, fill, tipped in (("obj_trash_can", None, False), ("obj_trash_can_full", "paper", False), ("obj_trash_can_tipped", None, True)):
        c = Canvas(16, 16)
        if tipped:
            c.rect(2, 9, 10, 6, "leaf")
            c.outline(2, 9, 10, 6, "ink")
            c.rect(12, 10, 3, 4, "paper")
        else:
            c.rect(3, 4, 10, 11, "leaf")
            c.outline(3, 4, 10, 11, "ink")
            c.rect(2, 3, 12, 2, "pine")
            if fill:
                c.rect(4, 1, 8, 2, fill)
                c.set(6, 0, "red")
        c.save(name)
    pic("obj_picnic_table", ("rect", 1, 5, 14, 5, "wood_l"), ("outline", 1, 5, 14, 5, "wood_d"), ("rect", 2, 2, 12, 2, "wood"), ("rect", 2, 11, 12, 2, "wood"), ("rect", 3, 10, 2, 6, "wood_d"), ("rect", 11, 10, 2, 6, "wood_d"))
    pic("obj_fire_ring", ("disc", 8, 10, 5, "rock", "rock_d"), ("disc", 8, 10, 3, "ink"), ("rect", 6, 9, 4, 2, "bark"))
    pic("obj_fire_ring_lit", ("disc", 8, 10, 5, "rock", "rock_d"), ("disc", 8, 10, 3, "ink"), ("tri", 8, 3, 11, 3, "roof"), ("tri", 8, 6, 11, 2, "glow"))
    pic("obj_litter_0", ("rect", 5, 9, 5, 4, "white"), ("rect", 6, 10, 3, 1, "red"))
    pic("obj_litter_1", ("rect", 6, 8, 3, 6, "glass"), ("rect", 7, 7, 1, 1, "metal"))
    pic("obj_litter_2", ("disc", 8, 11, 2.5, "paper", "hat"))
    c = Canvas(16, 16, "floor")
    c.speckle("bark", 30, 7)
    c.disc(8, 8, 4, "floor_d")
    c.disc(7, 7, 1.5, "bark")
    c.save("ground_dug_earth")

    # Backpack icons.
    pic("item_bench", ("rect", 1, 4, 14, 3, "wood"), ("rect", 1, 8, 14, 3, "wood_l"), ("rect", 2, 11, 2, 4, "wood_d"), ("rect", 12, 11, 2, 4, "wood_d"))
    pic("item_trash_can", ("rect", 3, 4, 10, 11, "leaf"), ("outline", 3, 4, 10, 11, "ink"), ("rect", 2, 3, 12, 2, "pine"))
    pic("item_picnic_table", ("rect", 1, 5, 14, 5, "wood_l"), ("outline", 1, 5, 14, 5, "wood_d"), ("rect", 3, 10, 2, 5, "wood_d"), ("rect", 11, 10, 2, 5, "wood_d"))
    pic("item_fire_ring", ("disc", 8, 9, 6, "rock", "rock_d"), ("disc", 8, 9, 3, "ink"))
    pic("item_radio_valve", ("rect", 6, 10, 4, 4, "metal"), ("disc", 8, 7, 4, "glass", "metal"), ("rect", 7, 5, 2, 4, "glow"))
    pic("item_pressed_flower_card", ("rect", 3, 2, 10, 12, "paper"), ("outline", 3, 2, 10, 12, "hat"), ("disc", 8, 7, 2, "yellow"), ("rect", 8, 9, 1, 3, "leaf"))
    pic("item_pine_resin_candle", ("rect", 5, 6, 6, 8, "glow"), ("outline", 5, 6, 6, 8, "wood_d"), ("rect", 8, 3, 1, 3, "ink"), ("disc", 8, 2, 1, "roof"))
    pic("item_carved_pinecone_figure", ("disc", 8, 10, 4, "wood", "wood_d"), ("disc", 8, 5, 2.5, "wood_l", "wood_d"), ("set", 7, 5, "ink"), ("set", 9, 5, "ink"))
    pic("item_painted_stone", ("disc", 8, 9, 5, "rock_l", "rock_d"), ("rect", 5, 8, 6, 1, "purple"), ("disc", 8, 10, 1, "roof"))
    pic("item_glowcap_night_light", ("rect", 4, 10, 8, 4, "wood"), ("disc", 8, 7, 4, "glass", "metal"), ("disc", 8, 7, 2, "purple"))

    # The station's catalog desk and staff board.
    c = Canvas(32, 24)
    c.rect(1, 6, 30, 12, "wood")
    c.outline(1, 6, 30, 12, "ink")
    c.rect(3, 18, 3, 6, "wood_d")
    c.rect(26, 18, 3, 6, "wood_d")
    c.rect(8, 2, 12, 6, "paper")
    c.rect(9, 3, 10, 1, "roof")
    c.rect(9, 5, 7, 1, "ink")
    c.save("furniture_catalog_desk")
    c = Canvas(16, 24)
    c.rect(1, 2, 14, 14, "wood_l")
    c.outline(1, 2, 14, 14, "wood_d")
    for (x, y) in ((3, 4), (9, 5), (4, 10)):
        c.rect(x, y, 4, 4, "paper")
        c.set(x + 1, y, "red")
    c.save("furniture_staff_board")
