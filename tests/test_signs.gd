extends RefCounted
## Phase 2a, step 4: the workbench, park-work recipes, repair kits, trail
## signs and trail markers.


func _trail_spot(s: GameSession) -> Vector2i:
	s.debug_teleport("fork")
	var start := s.ranger_tile()
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := start + Vector2i(dx, dy)
				var below := t + Vector2i(0, 1)
				if s.world.ground_at(t) == "trail" and s.world.object_at(t) == "" and not s.world.is_solid(below) and s.world.object_at(below) == "":
					s.outdoor_pos = Vector2(below) + Vector2(0.5, 0.5)
					s.facing = GameSession.FACING_UP
					return t
	return Vector2i(-1, -1)


func test_workbench_in_the_station(t: TestCase) -> void:
	var s := TestCase.new_session()
	var layout: InteriorLayout = s.interiors["ranger_station"]
	t.check(layout.find("workbench").size() > 0, "a workbench stands in the station")
	var opened := [0]
	s.workbench_opened.connect(func() -> void: opened[0] += 1)
	s.enter_building("ranger_station")
	var r := layout.furniture_rect(layout.find("workbench"))
	s.interior_pos = Vector2(r.position.x + 1.0, r.end.y + 0.5)
	s.facing = GameSession.FACING_UP
	s.interact()
	t.equal(opened[0], 1, "using it opens the workbench")
	var n := s.content.rows("recipes").filter(func(r: Dictionary) -> bool: return r["station"] == "workbench" or r["station"] == "anywhere").size()
	t.equal(s.recipes_at("workbench").size(), n, "the workbench lists its recipes and the ones made anywhere")


func test_crafting(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not s.craft("trail_sign"), "nothing made without the materials")
	t.equal(s.backpack.count("trail_sign"), 0, "no sign")
	s.debug_add_item("planks", 5)
	s.debug_add_item("nails", 5)
	t.check(s.recipe_status("trail_sign")["can"], "the recipe can be made")
	t.check(s.craft("trail_sign"), "a blank sign is made anywhere")
	t.equal(s.backpack.count("trail_sign"), 1, "it is in the backpack")
	t.equal(s.backpack.count("planks"), 3, "planks used")
	t.equal(s.backpack.count("nails"), 4, "nails used")
	t.check(not s.craft("trail_marker"), "markers need a workbench")
	s.enter_building("ranger_station")
	t.check(s.craft("trail_marker"), "markers made at the workbench")
	t.equal(s.backpack.count("trail_marker"), 2, "two at a time")


func test_repair_kit_stands_in_for_loose_materials(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("repair_kit", 1)
	t.check(s.backpack.can_pay({"planks": 4, "nails": 8}), "a kit pays for the walls")
	t.check(not s.backpack.can_pay({"roofing": 4, "nails": 8}), "but not for roofing")
	s.debug_add_item("roofing", 4)
	t.check(s.backpack.can_pay({"roofing": 4, "nails": 8}), "loose roofing plus a kit's nails")
	s.debug_add_item("nails", 3)
	t.check(s.backpack.pay({"roofing": 4, "nails": 8}), "paid")
	t.equal(s.backpack.count("nails"), 0, "loose nails used first")
	t.equal(s.backpack.count("repair_kit"), 0, "then the kit")
	# A real repair with a kit.
	s.debug_teleport("cabin")
	s.debug_add_item("repair_kit", 1)
	var res := s.hammer()
	t.check(res.get("ok", false), "the hammer starts a step paid with a kit")


func test_put_up_read_and_take_down_a_sign(t: TestCase) -> void:
	var s := TestCase.new_session()
	var spot := _trail_spot(s)
	t.check(spot.x >= 0, "a trail tile to stand by")
	s.backpack.remove("hammer", 1)
	s.backpack.add("trail_sign", 1)
	s.selected_slot = _slot_of(s, "trail_sign")
	var asked := []
	s.choice_requested.connect(func(kind: String, _title: String, options: Array) -> void: asked.append(options))
	s.begin_place()
	t.equal(asked.size(), 0, "no hammer, no sign")
	s.backpack.add("hammer", 1)
	s.selected_slot = _slot_of(s, "trail_sign")
	s.map.mark_landmark("test_cabin")
	t.check(s.begin_place(), "putting up starts")
	t.equal(asked.size(), 1, "it asks which place to name")
	var ids: Array = (asked[0] as Array).map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("ranger_station") and ids.has("test_cabin"), "the station and mapped places are offered")
	t.check(not ids.has("scenic_outlook"), "unmapped places are not")
	s.debug_set_needs(200, 100)
	var m0 := s.clock.minute
	s.answer_choice("sign_place", "test_cabin")
	t.check(s.placed.has(spot), "the sign is up")
	t.equal(s.backpack.count("trail_sign"), 0, "and out of the backpack")
	t.equal(s.clock.minute, m0 + s.tuning.integer("signs.put_up_minutes"), "it takes time")
	t.equal(s.needs.energy, 200.0 - s.tuning.num("signs.put_up_energy"), "and energy")
	var text := s.read_placed(spot)
	t.check(text.contains(s.place_name("test_cabin")), "it reads the place's name: %s" % text)
	t.check(text.contains(s.content.text("dir_e")) or text.contains(s.content.text("dir_ne")), "and points the way, roughly east")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.equal(str(s2.placed.get(spot, {}).get("place", "")), "test_cabin", "the sign is kept in the save")
	s.selected_slot = _slot_of(s, "hammer")
	t.check(s.hammer().get("ok", false), "the hammer takes it down")
	t.check(not s.placed.has(spot), "gone")
	t.equal(s.backpack.count("trail_sign"), 1, "back in the backpack")
	t.check(s.debug_put_up(spot, "trail_sign", "ranger_station"), "and it can go up again")


func test_signs_only_on_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("station")
	s.backpack.add("trail_sign", 1)
	var grass := Vector2i(-1, -1)
	for dx in range(3, 20):
		var c := s.ranger_tile() + Vector2i(dx, -6)
		if s.world.ground_at(c) == "grass" and not s.world.is_solid(c) and s.world.object_at(c) == "":
			grass = c
			break
	t.equal(s.place_problem(grass, "trail_sign"), "msg_sign_need_trail", "a sign needs trail under it")
	t.equal(s.place_problem(grass, "trail_marker"), "", "a marker can go on open ground")


func test_marker_counts_as_trail_at_night(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("station")
	var g := Vector2i(-1, -1)
	for dx in range(3, 20):
		var c := s.ranger_tile() + Vector2i(dx, -6)
		if s.world.ground_at(c) == "grass" and not s.world.is_solid(c) and s.world.object_at(c) == "":
			g = c
			break
	s.outdoor_pos = Vector2(g) + Vector2(0.5, 0.5)
	s.debug_force_weather("clear")
	s.debug_set_time(23 * 60)
	t.check(not s.on_trail(), "standing off the trail")
	t.check(not s.marker_visible(), "at night the marker is lost off the trail")
	t.check(s.debug_put_up(g + Vector2i(1, 0), "trail_marker"), "a trail marker goes up")
	t.check(s.marker_visible(), "near a trail marker it counts as trail")


func _slot_of(s: GameSession, item: String) -> int:
	for i in s.backpack.size():
		if s.backpack.item_at(i) == item:
			return i
	return 0
