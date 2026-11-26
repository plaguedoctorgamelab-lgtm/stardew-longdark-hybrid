extends RefCounted
## Phase 5a, out in the woods: animals, binoculars and camera, the field
## guide, Lore, night finds and the pet (Phase 5 Spec).


func _out(s: GameSession, minute: int, season: int = 1) -> void:
	s.clock.season = season
	s.clock.set_minute(minute)
	s.wildlife.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)


func _first(s: GameSession, id: String) -> Dictionary:
	for a: Dictionary in s.wildlife.animals:
		if str(a["id"]) == id:
			return a
	return {}


func test_every_animal_has_its_sheet(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("animals"):
		if str(r["kind"]) == "place":
			continue
		t.check(Art.has_picture(str(r["sprite"])), "%s has a sheet" % r["id"])
		var tex := Art.texture(str(r["sprite"]))
		t.equal(tex.get_width(), int(r["cols"]) * int(r["frame"][0]), "%s: its columns" % r["id"])
		t.equal(tex.get_height(), 3 * int(r["frame"][1]), "%s: three facings" % r["id"])
		t.check(s.content.has("text", "animal_" + str(r["id"])) and s.content.has("text", "guide_line_" + str(r["id"])), "%s has words" % r["id"])


func test_homes_are_on_their_ground(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.wildlife.morning()
	var any := 0
	for r: Dictionary in s.wildlife.kinds("animal"):
		for h: Vector2 in s.wildlife.homes.get(str(r["id"]), []):
			any += 1
			t.check((r["ground"] as Array).has(s.world.ground_at(Vector2i(h))), "%s lives on its ground" % r["id"])
	t.check(any > 8, "most kinds have homes today (%d)" % any)


func test_animals_keep_their_hours(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	t.check(not _first(s, "rabbit").is_empty(), "rabbits by day")
	t.check(_first(s, "raccoon").is_empty() and _first(s, "hedgehog").is_empty(), "no night animals at noon")
	_out(s, 23 * 60)
	t.check(not _first(s, "raccoon").is_empty(), "raccoons at night")
	t.check(_first(s, "rabbit").is_empty(), "rabbits gone in")
	_out(s, 13 * 60, 3)
	t.check(_first(s, "bear").is_empty(), "no bears in winter")


func test_come_too_close_and_it_moves_off(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	var a := _first(s, "rabbit")
	s.outdoor_pos = Vector2(a["home"]) + Vector2(30, 0)
	a["pos"] = a["home"]
	var shy := s.wildlife.shy_distance("rabbit")
	s.walking_slow = true
	t.near(s.wildlife.shy_distance("rabbit"), shy * 0.5, 0.01, "walking slowly halves it")
	s.walking_slow = false
	s.outdoor_pos = Vector2(a["pos"]) + Vector2(shy - 0.5, 0)
	s.wildlife._move(a, 0.1)
	t.equal(str(a["state"]), "flee", "too close: it moves off")
	t.equal(s.wildlife.shy_distance("bear"), 0.0, "a bear doesn't")


func test_binoculars_sketch_and_the_camera_photographs(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	var a := _first(s, "rabbit")
	s.wildlife.animals = [a]
	s.outdoor_pos = Vector2(a["pos"]) + Vector2(-9, 0)
	s.moving = false
	t.check(s.wildlife.toggle_binoculars(), "up go the binoculars")
	s.wildlife._look(0.6)
	t.equal(s.wildlife.level_of("rabbit"), "", "not yet")
	s.wildlife._look(0.6)
	t.equal(s.wildlife.level_of("rabbit"), "sketch", "a moment later, sketched")
	t.check(s.skills.xp["lore"] > 0, "Lore grows")
	# Now the camera, in range and facing it.
	s.wildlife.looking = false
	s.outdoor_pos = Vector2(a["pos"]) + Vector2(-3, 0)
	s.facing = GameSession.FACING_RIGHT
	a["state"] = "eat"
	var r := s.wildlife.take_photo()
	t.equal(str(r.get("kind", "")), "rabbit", "the photo is of the rabbit")
	t.equal(s.wildlife.level_of("rabbit"), "photo", "the guide has a photo")
	t.check(bool(s.wildlife.guide["rabbit"]["good"]), "eating: a good one")


func test_a_place_in_special_light(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 23 * 60)
	s.wildlife.animals = []
	s.outdoor_pos = s.world.landmark_pos("scenic_outlook") + Vector2(3, 3)
	var r := s.wildlife.take_photo()
	t.equal(str(r.get("kind", "")), "place_night", "a site at night")


func test_every_five_entries_the_chief_writes(t: TestCase) -> void:
	var s := TestCase.new_session()
	var letters := s.park.letters.size()
	for id in ["rabbit", "squirrel", "hedgehog", "raccoon", "badger"]:
		s.wildlife.record(id, "sketch")
	t.equal(s.park.letters.size(), letters + 1, "five entries: a letter")
	t.equal(s.wildlife.letters_sent, 1, "counted")


func test_a_strange_cousin_among_its_cousins(t: TestCase) -> void:
	var s := TestCase.new_session()
	var r := s.content.row("animals", "jackalope")
	var was: float = r["chance"]
	r["chance"] = 1.0
	r["chance_season"] = {}
	var sun: Array = s.tuning.value("light.sun.summer")
	_out(s, int(sun[1]))
	r["chance"] = was
	t.check(not _first(s, "jackalope").is_empty(), "a jackalope at dusk among the rabbits")
	t.equal(str(_first(s, "jackalope")["kind"]), "rabbit", "it lives with them")


func test_moonflowers_open_at_night(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	t.check(not s.wildlife.flowers.is_empty(), "there are moonflowers")
	var f: Vector2i = s.wildlife.flowers[0]
	t.equal(s.wildlife.night_find_in_reach(Vector2(f) + Vector2(0.5, 0.5), 1.0), "", "closed by day")
	s.clock.set_minute(23 * 60)
	var key := s.wildlife.night_find_in_reach(Vector2(f) + Vector2(0.5, 0.5), 1.0)
	t.check(key.begins_with("moonflower"), "open at night")
	t.check(s.wildlife.take_night_find(key), "picked")
	t.equal(s.backpack.count("moonflower"), 1, "into the pack")
	t.equal(s.wildlife.night_find_in_reach(Vector2(f) + Vector2(0.5, 0.5), 1.0), "", "once a night")


func test_night_paths_grow_with_the_park(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.sites_open = {}
	s.wildlife.morning()
	var none := s.wildlife.paths.size()
	s.debug_sites_open_start(4242)
	s.wildlife.morning()
	t.check(s.wildlife.paths.size() > none, "more sites open, more paths (%d)" % s.wildlife.paths.size())


func test_the_pet(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not s.pet.has_pet(), "no pet at first")
	t.equal(s.pet.offer_options().size(), 2, "a dog or a cat")
	s.answer_choice("pet", "cat")
	t.equal(s.pet.kind, "cat", "the cat")
	s.outdoor_pos = s.pet.pos
	t.equal(s.pet.touch(), "petted", "first a pat")
	t.check(s.pet.points > 0, "friendship")
	t.equal(s.pet.touch(), "along", "then it comes along")
	var plain := s.tuning.num("wildlife.slow_walk_shy")
	t.check(s.wildlife.shy_distance("deer") < s.content.row("animals", "deer")["shy"] * 0.75, "the cat makes shy things trusting (%s)" % plain)
	t.check(s.pet.fill_bowl(), "the bowl filled")
	t.check(not s.pet.fill_bowl(), "once a day")
	var s2 := TestCase.new_session()
	s2.from_dict(s.to_dict())
	t.equal(s2.pet.kind, "cat", "saved")
	t.equal(s2.pet.points, s.pet.points, "with its friendship")


func test_the_guide_is_saved(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.wildlife.record("deer", "photo", true)
	var s2 := TestCase.new_session()
	s2.from_dict(s.to_dict())
	t.equal(s2.wildlife.level_of("deer"), "photo", "the photo is kept")
	t.check(bool(s2.wildlife.guide["deer"]["good"]), "and that it's good")


func test_binoculars_wait_in_the_station_chest(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.wildlife.morning()
	t.equal((s.structures.chests["ranger_station"] as Inventory).count("binoculars"), 1, "the last ranger's pair")
	s.wildlife.morning()
	t.equal((s.structures.chests["ranger_station"] as Inventory).count("binoculars"), 1, "only once")


func test_the_guide_sits_on_the_clipboard(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.wildlife.record("rabbit", "photo", true)
	var g := GuideScreen.new()
	g.setup(s)
	for pg in GuideScreen.PAGES:
		g.open(pg)
		t.check(g.list.get_child_count() == g.entries().size(), "%s: a card for each" % pg)
		t.check(Sheet.FRAME.encloses(g.list_scroll.get_rect()) and Sheet.FRAME.encloses(g.detail_scroll.get_rect()), "%s: on the board" % pg)
	g.free()


func test_lore_is_the_fifth_skill(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.content.has("skills", "lore"), "Lore")
	t.equal(s.skills.offered_specialties("lore").size(), 2, "with two specialties")
