extends RefCounted
## The tracker items fixed in 0.4.7: #5 waking in the tower, #6 why the ranger
## passed out, #2 and #3 jobs as ordered steps with what to bring first and
## flags where to dig, #4 the workshop (what things are for, hidden until
## learned, a pop-up when learned, the workbench's box), #7 hover tips on the
## Options screen, #8 picking forage with the mouse.


func test_waking_in_any_bed_leaves_room_to_walk(t: TestCase) -> void:
	var s := TestCase.new_session()
	var box_arr: Array = s.tuning.value("movement.ranger_box_tiles")
	var half := Vector2(float(box_arr[0]), float(box_arr[1])) / 2.0
	for r: Dictionary in s.content.rows("structures"):
		if not r.get("has_bed", false):
			continue
		var id: String = r["id"]
		s._put_in_bed(id)
		var layout: InteriorLayout = s.interiors[id]
		t.check(not Mover.box_hits(s.interior_pos, half, layout.is_solid), "%s: the ranger wakes clear of furniture" % id)
		var moved := 0
		for d: Vector2 in [Vector2(0.05, 0), Vector2(-0.05, 0), Vector2(0, 0.05), Vector2(0, -0.05)]:
			if Mover.move(s.interior_pos, d, Vector2(float(box_arr[0]), float(box_arr[1])), layout.is_solid) != s.interior_pos:
				moved += 1
		t.check(moved >= 1, "%s: a small step moves the ranger (%d ways)" % [id, moved])


func test_passing_out_says_why(t: TestCase) -> void:
	for cause in ["warmth", "energy"]:
		var s := TestCase.new_session()
		var told := [""]
		s.collapsed.connect(func(text: String) -> void: told[0] = text)
		s.needs.set_values(0.0 if cause == "energy" else s.needs.max_energy(), 0.0 if cause == "warmth" else s.needs.max_warmth())
		s._check_collapse()
		t.check(told[0].begins_with(s.content.text("msg_collapse_why_" + cause)), "%s: the note says why" % cause)
		t.check(told[0].contains(s.content.text("msg_collapse_tip_" + cause, {"time": GameClock.time_of(s.tuning.integer("time.day_end_minute"))})), "%s: and what to do next time" % cause)
	t.equal(GameClock.time_of(1560), "2:00 am", "the end of the day reads as the clock shows it")


func test_job_card_puts_what_to_bring_first(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.sites_found["static_tower"] = true
	var card: Dictionary = s.guide.job_cards().filter(func(k: Dictionary) -> bool: return k["id"] == "static_tower")[0]
	var keys: Array = card["steps"].map(func(st: Dictionary) -> String: return st["key"])
	t.equal(keys[0], "gather", "gathering comes first")
	t.equal(keys[keys.size() - 1], "open", "opening comes last")
	t.check(keys.find("map") < keys.find("reach") and keys.find("reach") < keys.find("repair") and keys.find("repair") < keys.find("sign"), "the steps are in order")
	var gather: String = card["steps"][0]["text"]
	t.check(gather.contains(s.content.item_name("planks")) and gather.contains(s.content.item_name("roofing")), "it lists the tower's repair materials")
	t.check(gather.contains(s.content.item_name("shovel")) and gather.contains(s.content.item_name("hammer")), "and the tools")
	t.equal(card["next"], "gather", "the next thing is to gather")
	var lines := s.guide.job_page_lines()
	t.check(lines[0].begins_with(s.content.text("job_current", {"title": ""}).strip_edges()), "the page starts with the job being worked on")


func test_trail_gap_is_flagged_until_dug(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.sites_found["static_tower"] = true
	s.debug_site_step("static_tower", "map", true)
	var gap := s.trail_gap("static_tower")
	t.check(not gap.is_empty(), "the tower is not joined yet: there is a gap")
	t.check((s._reach_cache["station"] as Dictionary).has(gap["a"]), "one flag is on the station's trail")
	t.equal(s.guide.trail_gaps().size(), 1, "the map shows its flags")
	ParkHelpers.open_route(s, "tower")
	t.check(s.trail_gap("static_tower").is_empty(), "once joined, no gap")
	t.equal(s.guide.trail_gaps().size(), 0, "and no flags")


func test_workshop_hides_unlearned_and_tells_new(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not s.recipe_options("anywhere").any(func(o: Dictionary) -> bool: return str(o["id"]).begins_with("#learn:")), "unlearned recipes are hidden")
	t.equal(s.take_new_recipes_text(), "", "nothing new at the start")
	s.learn_recipe("boardwalk")
	var text := s.take_new_recipes_text()
	t.check(text.contains(s.content.text("recipe_boardwalk")) and text.contains(s.content.text("recipe_use_boardwalk")), "a pop-up names the new recipe and what it is for")
	t.equal(s.take_new_recipes_text(), "", "told once")
	for r: Dictionary in s.content.rows("recipes"):
		t.check(s.content.has("text", "recipe_use_" + str(r["id"])), "%s says what it is for" % r["id"])


func test_workbench_box_takes_what_the_backpack_cannot(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.enter_building("ranger_station")
	t.check(s.at_workbench(), "at the station's workbench")
	var ids := s.recipe_options("workbench").map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("#bench_box"), "the workbench offers its box")
	var box := s.bench_box()
	t.equal(box.size(), s.tuning.integer("storage.bench_slots"), "the box has the tuned slots")
	box.add("planks", 4)
	box.add("nails", 8)
	t.equal(s.have("planks"), 4, "what is in the box counts for making")
	# Fill the backpack so a bench can't fit.
	while s.backpack.room_for("stones") > 0:
		s.backpack.add("stones", s.backpack.room_for("stones"))
	t.check(s.craft("repair_kit"), "made with a full backpack")
	t.equal(box.count("repair_kit"), 1, "it went in the workbench's box")
	s.save_game()
	var s2 := TestCase.new_session()
	s2.save_path = s.save_path
	s2.load_game()
	t.equal((s2.bench_boxes["ranger_station"] as Inventory).count("repair_kit"), 1, "the box is saved")


func test_hover_tips_follow_the_setting(t: TestCase) -> void:
	var keep: String = Settings.values["hover_tips"]
	Settings._loaded = true
	Settings.values["hover_tips"] = "first_week"
	t.check(Settings.tips_showing(3, 7) and not Settings.tips_showing(8, 7), "first week only")
	Settings.values["hover_tips"] = "always"
	t.check(Settings.tips_showing(40, 7), "always")
	Settings.values["hover_tips"] = "off"
	t.check(not Settings.tips_showing(1, 7), "off")
	Settings.values["hover_tips"] = keep


func test_clicking_forage_in_reach_picks_it(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := Vector2i(s.world.spawn("station")) + Vector2i(0, 6)
	s.debug_spawn_forage(c, "stones")
	s.outdoor_pos = Vector2(c) + Vector2(1.5, 0.5)
	t.equal(s.forage_at(Vector2(c) + Vector2(0.5, 0.5)), c, "the forage under the mouse is in reach")
	t.equal(s.forage_at(Vector2(c) + Vector2(0.5, 9.5)), Vector2i(-1, -1), "empty ground is not")
	var before := s.backpack.count("stones")
	t.check(s.pick_at(c).get("ok", false), "a click picks it")
	t.equal(s.backpack.count("stones"), before + 1, "into the backpack")
	s.debug_spawn_forage(c, "stones")
	s.outdoor_pos = Vector2(c) + Vector2(8.5, 0.5)
	t.equal(s.forage_at(Vector2(c) + Vector2(0.5, 0.5)), Vector2i(-1, -1), "too far away to reach")
