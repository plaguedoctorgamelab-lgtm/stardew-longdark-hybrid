extends RefCounted
## 0.6.9: the issues left from 0.6.7. Inner corners on the creek wrap the
## sand round, the Percolator and Casa Luna light their dark glass (not
## Casa Luna's turquoise frames), and the yard fences are spaced by the
## width of their bigger pictures.


func _session() -> GameSession:
	return TestCase.new_session()


func test_dark_glass_lights_up(t: TestCase) -> void:
	var s := _session()
	for n: String in ["town_percolator", "town_casa_luna"]:
		t.check(TownView.window_glow(Art.image(n), s.tuning, n) != null, "%s has windows to light" % n)
	var luna := TownView.window_glow(Art.image("town_casa_luna"), s.tuning, "town_casa_luna")
	var src := Art.image("town_casa_luna")
	src.convert(Image.FORMAT_RGBA8)
	var frame := 0
	var lit_frame := 0
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5 and TownView.is_glass(c, s.tuning.value("town_look.window_glass")):
				frame += 1
				if luna.get_pixel(x, y).a > 0.0:
					lit_frame += 1
	t.check(frame > 0, "Casa Luna has bright turquoise frames")
	t.equal(lit_frame, 0, "and they stay dark at night: only the glass glows")


func test_inner_corners_keep_their_rim(t: TestCase) -> void:
	# The creek's inner corner: water in most of the tile, sand in the corner.
	var img := Art.image("town_edge_bank_ise")
	img.convert(Image.FORMAT_RGBA8)
	var c := img.get_pixel(1, 1)
	t.check(c.b > c.r + 0.1, "the far corner of the inner corner is water")
	var sand := 0
	for y in range(8, 16):
		for x in range(8, 16):
			var p := img.get_pixel(x, y)
			if p.r > p.b + 0.15 and p.r > 0.6:
				sand += 1
	t.check(sand >= 6, "and the near corner has a sandy rim (%d sand pixels)" % sand)


func test_fence_pieces_meet(t: TestCase) -> void:
	var s := _session()
	for piece: String in ["town_picket", "town_hedge", "town_stone_wall"]:
		var xs: Array[float] = []
		for o: Dictionary in s.town.objects:
			if str(o["sprite"]) == piece:
				xs.append(float(o["pos"][0]))
		xs.sort()
		t.check(xs.size() >= 3, "%s makes a run" % piece)
		var w := float(Art.image(piece).get_width()) / 16.0
		for i in range(1, xs.size()):
			var gap := xs[i] - xs[i - 1]
			t.check(gap <= w + 0.001 and gap >= w - 0.2, "%s pieces touch (step %.3f, width %.3f)" % [piece, gap, w])
