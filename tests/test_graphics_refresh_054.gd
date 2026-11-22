extends RefCounted
## 0.5.4 (21 November 2026): the Graphics Polish request's first pass and the
## Interior Art Guide's old cabin. A tool landing says so, the ranger holds
## still and breathes, the effects can be switched off, and the cabin keeps
## the guide's room rules.


func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_a_felled_tree_tells_the_views(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("axe", 1)
	var heard: Array = []
	s.tool_landed.connect(func(tool: String, tile: Vector2i, kind: String) -> void: heard.append([tool, tile, kind]))
	# Stand beside a tree, facing it.
	var found := false
	for y in range(1400, 1460):
		for x in range(20, 120):
			var tile := Vector2i(x, y)
			if s.world.object_at(tile).begins_with("tree_") and not s.world.is_solid(tile + Vector2i(0, 1)):
				s.outdoor_pos = Vector2(tile) + Vector2(0.5, 1.5)
				s.facing = GameSession.FACING_UP
				found = true
				break
		if found:
			break
	t.check(found, "a tree to stand by")
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "axe":
			s.selected_slot = i
	s.use_item()
	t.equal(heard.size(), 1, "one landing heard")
	if heard.size() == 1:
		t.equal(str(heard[0][2]), "fell", "the tree fell")


func test_the_ranger_holds_still_and_breathes(t: TestCase) -> void:
	var r := RangerSprite.new()
	_scene_tree().root.add_child(r)
	r.motion = true
	r.show_state(Vector2(10, 10), 0, false, 0.016)
	r.freeze(3)
	r.show_state(Vector2(40, 10), 0, true, 0.016)
	t.equal(r.position, Vector2(10, 10), "frozen: the ranger holds still")
	for i in 3:
		r.show_state(Vector2(40, 10), 0, true, 0.016)
	t.equal(r.position, Vector2(40, 10), "then moves on")
	r.show_state(Vector2(40, 10), 0, false, r.bob_delay + 0.01)
	t.check(r.bob_up(), "after standing still, the ranger rises a pixel")
	t.equal(r.sprite.position.y, -1.0, "by one whole pixel")
	r.motion = false
	t.check(not r.bob_up(), "no bob with Motion off")
	r.freeze(3)
	t.equal(r.frozen, 0, "no hit-stop with Motion off")
	r.queue_free()


func test_effects_switch_off_and_stay_off(t: TestCase) -> void:
	for key in ["motion", "weather_effects"]:
		var was := Settings.flag(key)
		Settings.toggle(key)
		t.equal(Settings.flag(key), not was, "%s switches" % key)
		Settings._loaded = false
		Settings.load_once()
		t.equal(Settings.flag(key), not was, "%s stays switched after a reload" % key)
		Settings.toggle(key)


func test_the_overlay_is_pale_and_pixel_sharp(t: TestCase) -> void:
	var s := TestCase.new_session()
	var tex := Polish.make_overlay_texture(s.tuning.value("look.weather_overlay_color"))
	var img := tex.get_image()
	var alphas := {}
	for y in img.get_height():
		for x in img.get_width():
			alphas[snappedf(img.get_pixel(x, y).a, 0.01)] = true
	t.check(alphas.size() <= 4, "a few steps of strength, no smooth gradient (%d)" % alphas.size())
	t.check(alphas.size() >= 2, "some patches")
	for w in ["fog", "snow"]:
		t.check((s.tuning.value("look.weather_overlay") as Dictionary).has(w), "%s has an overlay" % w)


func test_the_old_cabin_keeps_the_guides_rules(t: TestCase) -> void:
	var s := TestCase.new_session()
	var layout: InteriorLayout = s.interiors["test_cabin"]
	var floor_tiles := 0
	var covered := 0
	for y in range(layout.wall_height, layout.size.y - 1):
		for x in range(1, layout.size.x - 1):
			floor_tiles += 1
			if layout.is_solid(Vector2i(x, y)):
				covered += 1
	t.check(float(covered) / floor_tiles <= 0.4, "furniture covers no more than 40%% of the floor (%d of %d)" % [covered, floor_tiles])
	# Every piece the ranger uses can be walked to from the door.
	var start := Vector2i(layout.entry)
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and not layout.is_solid(n) and n.x >= 0 and n.y >= 0 and n.x < layout.size.x and n.y < layout.size.y:
				seen[n] = true
				q.append(n)
	for f: Dictionary in layout.furniture:
		if str(f["kind"]) in ["bed", "stove", "chest"]:
			var r := layout.furniture_rect(f)
			var reach := false
			for p: Vector2i in seen:
				if Rect2(r).grow(1.0).has_point(Vector2(p) + Vector2(0.5, 0.5)):
					reach = true
			t.check(reach, "%s can be reached from the door" % f["id"])
	t.equal(str(layout.find("bed")["sprite"]), "int_bed", "Mark's interior bed")
	t.check(Art.has_picture("int_stove") and Art.has_picture("int_stove_lit"), "the stove cold and lit")


func test_the_faced_piece_has_a_name(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_repair_all("test_cabin", true)
	s.enter_building("test_cabin")
	var layout: InteriorLayout = s.interiors["test_cabin"]
	var r := layout.furniture_rect(layout.find("stove"))
	s.interior_pos = Vector2(r.get_center().x, r.end.y + 0.5)
	t.equal(s.furniture_label(s.furniture_in_reach()), "Wood stove", "the stove is named")
