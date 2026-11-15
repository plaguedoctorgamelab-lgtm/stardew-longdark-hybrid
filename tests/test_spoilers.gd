extends RefCounted
## SPOILERS. Phase 2a, step 7: every hidden thing can be found and works.
## Kept in its own file, as the working rules ask.


## Stands the ranger on open ground next to an object's footprint.
func _stand_next_to(s: GameSession, t: Vector2i) -> bool:
	var kind := s.world.object_at(t)
	var size: Array = s.world.object_type(kind)["size"]
	var w := int(size[0])
	var h := int(size[1])
	var center := Vector2(t) + Vector2(w / 2.0, h / 2.0)
	var best := Vector2(-1, -1)
	for y in range(t.y - 1, t.y + h + 1):
		for x in range(t.x - 1, t.x + w + 1):
			var c := Vector2i(x, y)
			if s.world.is_solid(c) or (x >= t.x and x < t.x + w and y >= t.y and y < t.y + h):
				continue
			var p := Vector2(c) + Vector2(0.5, 0.5)
			if best.x < 0 or p.distance_to(center) < best.distance_to(center):
				best = p
	if best.x < 0:
		return false
	s.outdoor_pos = best
	return true


func _spot(s: GameSession, id: String) -> Vector2i:
	var p: Array = s.world.meta["finds"][id]
	return Vector2i(int(p[0]), int(p[1]))


func test_placed_things_can_be_found(t: TestCase) -> void:
	var placed: Dictionary = TestCase.new_session().world.meta["finds"]
	t.check(placed.size() >= 10, "the placed hidden things are in the world (%d)" % placed.size())
	for id: String in placed:
		var s := TestCase.new_session()
		s.debug_set_time(12 * 60)
		var at := _spot(s, id)
		t.check(_stand_next_to(s, at), "%s: room to stand by it" % id)
		var shown := []
		s.note_read.connect(func(text: String) -> void: shown.append(text))
		s.interact()
		t.check(s.finds_found.has(id), "%s: found by looking at it" % id)
		t.equal(shown.size(), 1, "%s: its text is shown" % id)
		if shown.size() == 1:
			t.equal(shown[0], s.content.text(s.content.row("spoiler_finds", id)["text"]), "%s: the right text" % id)
		s.interact()
		t.equal(shown.size(), 1, "%s: noticed only once" % id)


func test_stakes(t: TestCase) -> void:
	var s := TestCase.new_session()
	var stake := Vector2i(-1, -1)
	for c: Vector2i in [s.world.chunk_of(Vector2i(s.world.landmark_pos("kettle_pond")))]:
		for r in range(0, 4):
			for cy in range(c.y - r, c.y + r + 1):
				for cx in range(c.x - r, c.x + r + 1):
					for o: Array in s.world.objects_in_chunk(Vector2i(cx, cy)):
						if stake.x < 0 and str(o[2]) == "survey_stake":
							stake = Vector2i(cx, cy) * s.world.chunk_size + Vector2i(int(o[0]), int(o[1]))
	t.check(stake.x >= 0, "a survey stake near the pond")
	s.outdoor_pos = Vector2(stake) + Vector2(0.5, 1.5)
	s.interact()
	t.check(s.finds_found.has("survey_stakes"), "the first stake touched is noticed")


func test_cache_tin_gives_once(t: TestCase) -> void:
	var s := TestCase.new_session(31)
	s.backpack.clear()
	_stand_next_to(s, _spot(s, "cache_tin"))
	s.interact()
	var got := 0
	for i in s.backpack.size():
		if s.backpack.item_at(i) != "":
			got += int(s.backpack.slot(i)["count"])
	t.check(got > 0, "the tin holds supplies (%d)" % got)
	s.interact()
	var again := 0
	for i in s.backpack.size():
		if s.backpack.item_at(i) != "":
			again += int(s.backpack.slot(i)["count"])
	t.equal(again, got, "and gives them once")


func test_dawn_moment(t: TestCase) -> void:
	var s := TestCase.new_session()
	var w: Dictionary = s.content.row("spoiler_finds", "dawn_ripple")["when"]
	s.outdoor_pos = s.world.landmark_pos(w["landmark"]) + Vector2(0, float(w["within"]) - 2.0)
	while s.world.is_solid(Vector2i(s.outdoor_pos)):
		s.outdoor_pos.y += 1.0
	s.debug_force_weather("fog")
	s.debug_set_time(int(w["from"]))
	s.clock.advance_step()
	t.check(not s.finds_found.has("dawn_ripple"), "not in fog")
	s.debug_set_time(12 * 60)
	s.debug_force_weather(w["weather"])
	s.clock.advance_step()
	t.check(not s.finds_found.has("dawn_ripple"), "not at noon")
	s.debug_set_time(int(w["from"]))
	s.debug_force_weather(w["weather"])
	t.check(s.find_moment_now("dawn_ripple"), "the moment is now")
	s.clock.advance_step()
	t.check(s.finds_found.has("dawn_ripple"), "seen at the right time and place")


func test_seasonal_thing(t: TestCase) -> void:
	var s := TestCase.new_session()
	var at := _spot(s, "sleeping_boulder")
	t.check(s.world.is_solid(at), "there in spring")
	s.debug_skip_season()
	s.debug_skip_season()
	s.debug_skip_season()
	t.equal(s.clock.season_name(), "winter", "winter")
	t.check(not s.world.is_solid(at), "gone all winter")
	_stand_next_to(s, at)
	s.interact()
	t.check(not s.finds_found.has("sleeping_boulder"), "nothing to notice while it is away")
	s.debug_skip_season()
	t.check(s.world.is_solid(at), "back in spring")


func test_tower_things(t: TestCase) -> void:
	var s := TestCase.new_session()
	for st: Dictionary in s.content.row("structures", "static_tower")["repair_steps"]:
		s.structures.debug_complete_step("static_tower", st["id"])
	s.debug_teleport("tower")
	s.enter_building("static_tower")
	var layout: InteriorLayout = s.interiors["static_tower"]
	var r := layout.furniture_rect(layout.find("find"))
	s.interior_pos = Vector2(r.position.x + 0.5, r.position.y - 0.5)
	s.facing = GameSession.FACING_DOWN
	s.interact()
	t.check(s.finds_found.has("lookout_log"), "the log on the desk")
	var chest: Inventory = s.structures.chests["static_tower"]
	t.equal(chest.count("journal_page_one"), 1, "a page in the chest")
	chest.remove("journal_page_one", 1)
	s.backpack.add("journal_page_one", 1)
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "journal_page_one":
			s.selected_slot = i
	s.use_item()
	t.check(s.finds_found.has("journal_page_one"), "read, it is noticed")


func test_berry_patch_moves_between_saves(t: TestCase) -> void:
	var spots := {}
	for sd in range(1, 30):
		var s := TestCase.new_session(sd)
		spots[s.berry_spot()] = true
		t.equal(s.berry_spot(), s.berry_spot(), "the same save keeps its spot")
	t.check(spots.size() >= 3, "different saves, different spots (%d)" % spots.size())


func test_finds_saved(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.discover("carved_tree")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.check(s2.finds_found.has("carved_tree"), "noticed things are kept in the save")
	t.equal(s.content.rows("spoiler_finds").size(), 14, "fourteen hidden things in ring two")
