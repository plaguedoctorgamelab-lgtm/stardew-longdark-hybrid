extends RefCounted
## Added after the designer's first play: a rough hint of the old cabin on the
## map, a camp with a small fire to sleep at, chopping trees for firewood, and
## the "fix up the old cabin" job from the station note board.


func _outdoors_on_grass(s: GameSession) -> void:
	s.debug_teleport("station")
	s.outdoor_pos += Vector2(4, 3)
	s.facing = GameSession.FACING_RIGHT


func test_cabin_hint_on_map(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(MapScreen.hints(s).size(), 0, "no hint before the station's papers turn up the notes (jobs rebuild)")
	s.rumors["test_cabin"] = true
	var hints := MapScreen.hints(s)
	t.equal(hints.size(), 1, "one hint once the cabin is rumored")
	var h: Dictionary = hints[0]
	var cabin := s.world.landmark_pos("test_cabin")
	t.check((h["center"] as Vector2).distance_to(cabin) < float(h["radius"]), "the circle contains the cabin")
	t.check((h["center"] as Vector2).distance_to(cabin) > 2.0, "but is only rough, not centred on it")
	var img := MapScreen.render(s)
	var red := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.5 and c.g < 0.25:
				red += 1
	t.check(red > 50, "the dashed circle is drawn on the map")
	s.map.mark_landmark("test_cabin")
	t.equal(MapScreen.hints(s).size(), 0, "the hint goes once the cabin is mapped")


func test_axe_and_bedroll_in_station_chest(t: TestCase) -> void:
	var s := TestCase.new_session()
	var chest: Inventory = s.structures.chests["ranger_station"]
	t.equal(chest.count("axe"), 1, "an axe in the station chest")
	t.equal(chest.count("bedroll"), 1, "a bedroll in the station chest")


func test_make_camp_needs_bedroll_firewood_and_open_ground(t: TestCase) -> void:
	var s := TestCase.new_session()
	_outdoors_on_grass(s)
	s.debug_add_item("bedroll")
	t.check(not s.make_camp(), "no camp without firewood")
	s.debug_add_item("firewood", 2)
	s.enter_building("ranger_station")
	t.check(not s.make_camp(), "no camp indoors")
	s.leave_building()
	_outdoors_on_grass(s)
	t.check(s.make_camp(), "camp made on open grass")
	t.equal(s.backpack.count("firewood"), 1, "the fire used one firewood")
	t.check(s.campfire_lit(), "the fire is lit")
	t.equal(s.camp["fire"], s.camp["bed"] + Vector2i(1, 0), "the fire is in front of the bedroll")
	# Water is not a camp site.
	s.debug_teleport("fork")
	var ford := Vector2i(-1, -1)
	for p in s.world.route("fork"):
		if s.world.ground_at(Vector2i(p)) == "shallows":
			ford = Vector2i(p)
			break
	s.outdoor_pos = Vector2(ford) + Vector2(0.5, 0.5)
	t.check(not s.make_camp(), "no camp in the ford")


func test_use_bedroll_item_makes_camp(t: TestCase) -> void:
	var s := TestCase.new_session()
	_outdoors_on_grass(s)
	s.debug_add_item("bedroll")
	s.debug_add_item("firewood")
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "bedroll":
			s.selected_slot = i
	s.use_item()
	t.check(not s.camp.is_empty(), "using the bedroll makes camp")


func test_campfire_warms_and_burns_down(t: TestCase) -> void:
	var s := TestCase.new_session()
	_outdoors_on_grass(s)
	s.debug_add_item("bedroll")
	s.debug_add_item("firewood", 3)
	s.make_camp()
	s.debug_set_time(22 * 60)
	s.debug_force_weather("overcast")
	var ctx := s.needs_context()
	t.check(ctx["campfire"], "beside the lit fire")
	var with_fire := s.needs.warmth_delta(ctx)
	ctx["campfire"] = false
	t.equal(with_fire - s.needs.warmth_delta(ctx), s.tuning.num("camp.fire_warmth"), "the fire adds its tuned warmth")
	s.outdoor_pos += Vector2(6, 0)
	t.check(not s.needs_context()["campfire"], "no warmth away from the fire")
	s.outdoor_pos -= Vector2(6, 0)
	s.debug_set_time(8 * 60)
	s.pass_minutes(s.tuning.integer("camp.fire_minutes_per_firewood"))
	t.check(not s.campfire_lit(), "the fire burns out")
	t.check(s.feed_campfire(), "more wood relights it")
	t.check(s.campfire_lit(), "lit again")


func test_sleep_at_camp(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("cabin")
	s.outdoor_pos += Vector2(-3, 1)
	s.facing = GameSession.FACING_RIGHT
	s.debug_add_item("bedroll")
	s.debug_add_item("firewood", 2)
	t.check(s.make_camp(), "camp beside the run-down cabin")
	s.debug_set_time(21 * 60)
	s.debug_set_needs(40, 30)
	var day := s.clock.day
	var saves := s.save_count
	var bed: Vector2i = s.camp["bed"]
	s.interact()
	t.equal(s.pending_confirm, "camp_sleep", "the bedroll asks to sleep")
	s.answer_confirm(true)
	t.equal(s.clock.day, day + 1, "next day")
	t.equal(s.clock.minute, 360, "wakes at 6:00")
	t.equal(s.needs.energy, 270.0 * 0.75, "75% energy")
	t.equal(s.needs.warmth, 75.0, "75% warmth")
	t.equal(s.location, "", "wakes outdoors at camp")
	t.check(s.outdoor_pos.distance_to(Vector2(bed) + Vector2(0.5, 0.5)) < 0.01, "where the bedroll was")
	t.check(s.save_count > saves, "the game saved")
	t.check(s.camp.is_empty(), "the bedroll is packed up and the fire put out")
	t.check(not s.campfire_lit(), "no fire is left burning")
	t.equal(s.backpack.count("bedroll"), 1, "the bedroll is back in the backpack")
	# Camp sleep never lowers energy or warmth.
	s.camp = {"bed": bed, "fire": bed + Vector2i(0, 1), "fire_minutes": 0}
	s.debug_set_needs(260, 95)
	s.camp_sleep()
	t.equal(s.needs.energy, 260.0, "energy kept when already higher")


func _near_tree(s: GameSession) -> Vector2i:
	var w := s.world
	for y in range(100, 200):
		for x in range(120, 200):
			var tile := w.r1(x, y)
			if w.object_at(tile) in ["tree_pine", "tree_fir", "tree_oak"] and not w.is_solid(tile + Vector2i(-1, 0)):
				s.outdoor_pos = Vector2(tile.x - 0.5, tile.y + 0.5)
				s.facing = GameSession.FACING_RIGHT
				return tile
	return Vector2i(-1, -1)


func test_chop_tree_for_firewood(t: TestCase) -> void:
	var s := TestCase.new_session()
	var tree := _near_tree(s)
	t.check(tree.x > 0, "found a tree")
	t.equal(s.chop().get("ok", false), false, "no chopping without an axe")
	s.debug_add_item("axe")
	s.debug_set_needs(200, 100)
	var m0 := s.clock.minute
	var res := s.chop()
	t.check(res["ok"], "chopped")
	t.equal(res["tile"], tree, "the tree in front was chopped")
	t.equal(s.backpack.count("firewood"), s.tuning.integer("axe.firewood"), "got firewood")
	t.equal(s.needs.energy, 200.0 - s.tuning.num("axe.energy"), "chopping costs energy")
	t.equal(s.clock.minute, m0 + s.tuning.integer("axe.minutes"), "chopping takes time")
	t.check(not s.world.is_solid(tree), "the stump can be walked over")
	var again := s.chop()
	t.check(not again.get("ok", false) or again["tile"] != tree, "a stump cannot be chopped again")


func test_dead_landmark_tree_is_not_choppable(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("axe")
	var dead := s.world.r1(243, 96)
	t.equal(s.world.object_at(dead), "tree_dead", "the dead tree at the fork")
	s.outdoor_pos = Vector2(dead) + Vector2(-0.5, 0.5)
	s.facing = GameSession.FACING_RIGHT
	var res := s.chop()
	t.check(not res.get("ok", false) or res["tile"] != dead, "the dead tree is a landmark and stays")


func test_stumps_regrow_and_save(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("axe")
	var tree := _near_tree(s)
	s.chop()
	t.check(s.chopped.has(tree), "stump recorded")
	s.save_game()
	var again := GameSession.new()
	again.save_path = s.save_path
	t.equal(again.load_game(), "", "loaded")
	t.check(again.chopped.has(tree) and not again.world.is_solid(tree), "the stump survives save and load")
	var days := s.tuning.integer("axe.regrow_days")
	s.debug_teleport("station")
	for i in days - 1:
		s.debug_skip_day()
	t.check(s.chopped.has(tree), "still a stump before %d days" % days)
	s.debug_skip_day()
	t.check(not s.chopped.has(tree), "regrown after %d days" % days)
	t.check(s.world.is_solid(tree), "the tree is solid again")


## Jobs rebuild: the cabin's job counts what the repair still needs, as
## materials for parts not begun, and finishes when the cabin opens.
func test_cabin_job_tracks_what_it_needs(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("open_cabin", "given")
	var need := s.jobs.needs("open_cabin")
	t.equal(int(need["planks"]), 8, "every plank for the four parts")
	t.equal(int(need["nails"]), 20, "and the nails")
	t.equal(int(need["hammer"]), 1, "and the hammer")
	s.debug_teleport("cabin")
	s.map.mark_landmark("test_cabin")
	s.debug_drain(false, false)
	s.debug_add_item("planks", 2)
	s.debug_add_item("nails", 4)
	s.hammer()
	t.equal(int(s.jobs.needs("open_cabin")["planks"]), 6, "door planks no longer needed once begun")
	for step in ["door", "walls", "roof", "window"]:
		s.debug_cabin_step(step, true)
	s.jobs.update(true)
	var rep := -1
	for i in (s.jobs.def("open_cabin")["steps"] as Array).size():
		if s.jobs.def("open_cabin")["steps"][i]["kind"] == "repair":
			rep = i
	t.check(bool(s.jobs.check("open_cabin", rep)["done"]), "the repair step is done when the cabin opens")
