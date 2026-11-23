extends RefCounted
## 0.7.1: Mark's Art Request 20 pieces: the roped-off pads, the calmer
## floors and the catalog desk.


func test_the_new_pictures_are_in(t: TestCase) -> void:
	for n: String in ["obj_pad_stakes", "obj_pad_tape_h", "obj_pad_tape_v", "furniture_catalog_desk", "interior_plank_floor", "interior_boards_warm", "interior_boards_warm_alt_1", "interior_boards_warm_alt_2"]:
		t.check(Art.has_picture(n), "%s is drawn" % n)
	t.equal(Art.texture("obj_pad_stakes").get_height(), 32, "the stake is 32 high")
	t.equal(Art.texture("furniture_catalog_desk").get_size(), Vector2(32, 24), "the desk keeps its 32 x 24 spot")


func test_floors_are_whole_tiles_with_few_colours(t: TestCase) -> void:
	for n: String in ["interior_plank_floor", "interior_boards_warm", "interior_boards_warm_alt_1", "interior_boards_warm_alt_2"]:
		var im := Art.texture(n).get_image()
		t.equal(im.get_size(), Vector2i(16, 16), "%s is a 16 x 16 tile" % n)
		var colours := {}
		var holes := 0
		for y in 16:
			for x in 16:
				var c := im.get_pixel(x, y)
				if c.a < 0.99:
					holes += 1
				colours[c.to_html()] = true
		t.equal(holes, 0, "%s has no holes" % n)
		t.check(colours.size() <= 4, "%s is quiet: %d colours (tracker #36)" % [n, colours.size()])


func test_rooms_use_the_new_floors(t: TestCase) -> void:
	for f: String in ["res://data/content/structures.json", "res://data/content/town_interiors.json"]:
		var text := FileAccess.get_file_as_string(f)
		t.check(text.contains("\"floor\""), "%s has floors" % f)
		t.check(not text.contains("_calm"), "%s stands on Mark's floors, not the lab's stand-ins" % f)


func test_a_staked_pad_is_roped_off(t: TestCase) -> void:
	var s := TestCase.new_session()
	var pad := "gate_bathroom"
	t.check(s.park.pad_shown(pad) and s.park.pad_state(pad) == "", "the gate's bathroom pad is staked out")
	var root := Node2D.new()
	var view := ParkView.new()
	view.setup(s, root)
	t.check(view._rope.has(pad), "it is roped off")
	var rc := s.park.pad_rect(pad)
	var pieces: Array = view._rope[pad]
	t.equal(pieces.size(), 4 + 2 * rc.size.x + 2 * rc.size.y, "four stakes and a piece of tape per tile of edge")
	var corners := {}
	for n: Sprite2D in pieces:
		if n.texture == Art.texture("obj_pad_stakes"):
			corners[Vector2i(n.position / ParkView.TILE)] = true
	for c: Vector2i in [rc.position, Vector2i(rc.end.x, rc.position.y), Vector2i(rc.position.x, rc.end.y), rc.end]:
		t.check(corners.has(c), "a stake at %s" % c)
	t.check(not (view._fac[pad] as Sprite2D).visible, "no lone stake in the middle")
	s.park.order("kit_bathroom@" + pad)
	s.debug_skip_day()
	view.refresh()
	t.check(not view._rope.has(pad), "once the kit arrives the roping comes down")
	view.free()
	root.free()
