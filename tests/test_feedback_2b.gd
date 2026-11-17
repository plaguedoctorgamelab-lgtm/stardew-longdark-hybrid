extends RefCounted
## The Phase 2b playtest feedback (0.4.2): gold coins, the map after a survey,
## recipes shown everywhere with how they are learned, signs beside a trail,
## gathering in a radius, bigger stacks, dragging, dropping and throwing away,
## the X and C hints, the "?" marks, what's next, and trail travel.


func test_money_reads_gold(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.content.text("hud_money", {"n": 500}), "500 gold", "the wallet reads in gold")
	for r: Dictionary in s.content.rows("text"):
		t.check(not str(r["text"]).contains("$"), "no dollar sign in %s" % r["id"])


func test_survey_opens_the_map(t: TestCase) -> void:
	var s := TestCase.new_session()
	var got := [false]
	s.survey_finished.connect(func() -> void: got[0] = true)
	s.weather.today.assign(["clear", "clear", "clear"])
	s.debug_force_weather("clear")
	s.debug_set_time(12 * 60)
	t.check(s.start_survey(), "a survey starts")
	for i in 40:
		if s.survey_steps_left == 0:
			break
		s.clock.advance_step()
	t.check(got[0], "finishing it asks for the map")


func test_crafting_page_shows_every_recipe(t: TestCase) -> void:
	var s := TestCase.new_session()
	var opts := s.recipe_options("anywhere")
	var ids := opts.map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("planks"), "a workbench recipe shows on the crafting page")
	var planks: Dictionary = opts[ids.find("planks")]
	t.check(not planks["enabled"], "greyed away from a workbench")
	t.check(str(planks["label"]).contains(s.content.text("ui_made_at_workbench")), "and says where it is made")
	t.check(ids.has("#learn:pack_frame"), "the pack frame shows before it is learned")
	t.check(ids.has("#learn:boardwalk"), "so does the boardwalk")
	t.check(str(opts[ids.find("#learn:boardwalk")]["label"]).contains(s.content.text("skill_trailcraft")), "the boardwalk says which skill teaches it")
	t.check(not ids.has("#learn:refit_lantern"), "magic refits stay unseen")
	t.check(not ids.has("#learn:glowcap_night_light"), "so does anything made with a magical ingredient")


func test_cooking_shows_recipes_to_learn(t: TestCase) -> void:
	var s := TestCase.new_session()
	var ids := s.recipe_options("fire").map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("#firewood"), "adding firewood is still there")
	t.check(ids.has("#learn:hot_soup"), "and hot soup shows, with how to learn it")
	t.check(ids.size() > 3, "more than firewood on offer")


func test_sign_goes_beside_the_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("trail_sign", 2)
	var door := Vector2i(s.site_door("static_tower"))
	var spot := Vector2i(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tt := door + Vector2i(dx, dy)
			if spot.x < 0 and s.world.ground_at(tt) != "trail" and s.world.ground_at(tt) in ["grass", "forest_floor"] and not s.world.is_solid(tt) and s.world.object_at(tt) == "" and s.near_trail(tt):
				spot = tt
	t.check(spot.x >= 0, "grass beside the tower's trail")
	t.equal(s.place_problem(spot, "trail_sign"), "", "a sign may go there")
	s.sites_found["static_tower"] = true
	var names := s.sign_places().map(func(o: Dictionary) -> String: return o["id"])
	t.check(names.has("static_tower"), "a found site can be named before it is mapped")
	t.check(s.put_up(spot, "trail_sign", "static_tower"), "put up")
	t.check(s.site_signed("static_tower"), "and it counts for the tower")


func test_gathering_takes_everything_close_by(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.clock.season = 1
	var today := s.clock.absolute_day()
	var c := Vector2i(s.world.spawn("station")) + Vector2i(0, 6)
	var tiles: Array[Vector2i] = []
	for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1)]:
		s.debug_spawn_forage(c + o, "stones")
		tiles.append(c + o)
	s.outdoor_pos = Vector2(c) + Vector2(0.5, 0.5)
	var before := s.backpack.count("stones")
	var res := s.pick_forage_around(s.forage_in_reach())
	t.check(res["ok"], "gathered")
	t.equal(s.backpack.count("stones") - before, 3, "all three spots picked at once")
	for tt in tiles:
		t.check(not s.forage.has_ground_now(tt, today), "spot %s taken" % tt)


func test_stacks_are_bigger(t: TestCase) -> void:
	var c := ContentDB.new()
	var inv := Inventory.new(c, 1)
	t.check(inv.stack_size("berries") >= 30, "berries stack to 30 or more")
	t.check(inv.stack_size("planks") >= 30, "planks stack to 30 or more")
	t.equal(inv.stack_size("hammer"), 1, "tools still one to a slot")


func test_dragging_moves_merges_and_swaps(t: TestCase) -> void:
	var c := ContentDB.new()
	var a := Inventory.new(c, 4)
	var b := Inventory.new(c, 4)
	a.add("planks", 5)
	a.add("hammer")
	t.check(a.move_to_slot(0, a, 3), "moved within")
	t.equal(a.item_at(3), "planks", "to the empty slot")
	t.check(a.item_at(0) == "", "leaving it empty")
	t.check(a.move_to_slot(1, a, 3), "dropped on a different item")
	t.check(a.item_at(3) == "hammer" and a.item_at(1) == "planks", "they swap")
	b.add("planks", b.stack_size("planks") - 2)
	t.check(a.move_to_slot(1, b, 0), "onto the same item across")
	t.equal(int(b.slot(0)["count"]), b.stack_size("planks"), "tops that stack up")
	t.equal(int(a.slot(1)["count"]), 3, "the rest stays")
	var shelf := Inventory.new(c, 2)
	shelf.only = {"painted_stone": true}
	t.check(not a.move_to_slot(3, shelf, 0), "the gift shelf refuses a hammer")


func test_drop_and_pick_up_again(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("stones", 7)
	var i := s.backpack.find_family("stones")
	t.check(s.drop_slot(s.backpack, i), "dropped")
	t.equal(s.backpack.count("stones"), 0, "out of the backpack")
	t.check(s.piles.has(s.ranger_tile()), "a pile where the ranger stands")
	t.equal(s.pile_in_reach(), s.ranger_tile(), "and in reach")
	var pile: Inventory = s.piles[s.ranger_tile()]
	pile.move_slot_to(0, s.backpack)
	s.tidy_piles()
	t.equal(s.backpack.count("stones"), 7, "picked up again")
	t.check(s.piles.is_empty(), "the empty pile is gone")
	s.backpack.add("stones", 3)
	s.save_game()
	s.drop_slot(s.backpack, s.backpack.find_family("stones"))
	s.save_game()
	var s2 := TestCase.new_session()
	s2.save_path = s.save_path
	s2.load_game()
	t.equal(s2.piles.size(), 1, "a pile is saved")


func test_trash_keeps_tools(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("sticks", 4)
	t.check(s.trash_slot(s.backpack, s.backpack.find_family("sticks")), "sticks thrown away")
	t.equal(s.backpack.count("sticks"), 0, "gone")
	t.check(not s.trash_slot(s.backpack, s.backpack.find_family("map")), "the map is kept")
	t.check(s.backpack.has("map"), "still there")


func test_hints_say_what_x_and_c_do(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.enter_building("ranger_station")
	var layout: InteriorLayout = s.interiors["ranger_station"]
	var f := layout.find("note_board")
	var r := layout.furniture_rect(f)
	s.interior_pos = Vector2(r.position.x + r.size.x / 2.0, r.end.y + 0.5)
	t.equal(s.guide.x_hint(), s.content.text("hint_x_note_board"), "X at the note board")
	s.leave_building()
	s.selected_slot = s.backpack.find_family("map")
	t.check(s.guide.use_hint().begins_with("C:"), "the map says what C does")
	s.debug_add_item("boardwalk", 1)
	s.selected_slot = s.backpack.find_family("boardwalk")
	t.equal(s.guide.use_hint(), s.content.text("hint_c_boardwalk_where"), "boardwalk says where it goes")
	t.check(not bool(s.guide.aim()["ok"]), "and the aim square is red off the bog")


func test_question_marks(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.guide.markers().size() > 0, "the station shows a ? for its unread note board")
	s.enter_building("ranger_station")
	t.check(s.guide.markers().size() > 0, "inside, over the board")
	s.read_note_board()
	var layout: InteriorLayout = s.interiors["ranger_station"]
	var r := layout.furniture_rect(layout.find("shelf"))
	s.interior_pos = Vector2(r.position.x + r.size.x / 2.0, r.end.y + 0.5)
	s._interact_inside()
	t.equal(s.guide.markers().size(), 0, "reading the board and looking at the shelf clear their ?")
	s.leave_building()
	t.equal(s.guide.markers().size(), 0, "and the door's")
	s.structures.shelves["ranger_station"].add("nails", 5)
	t.equal(s.guide.markers().size(), 1, "a new delivery brings the ? back")


func test_next_steps_for_a_found_site(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.guide.next_steps().size(), 0, "nothing found, nothing listed")
	s.sites_found["static_tower"] = true
	var lines := s.guide.next_steps()
	t.equal(lines.size(), 1, "one line for the tower")
	t.check(lines[0].contains(s.content.text("next_map")), "the next thing is mapping it")


func test_trail_travel(t: TestCase) -> void:
	var s := TestCase.new_session()
	ParkHelpers.open_route(s, "cabin")
	s.sites_found["old_cabin"] = true
	s.outdoor_pos = s.door_front("ranger_station")
	t.equal(s.travel_options().size(), 0, "not before going there twice")
	var door := s.site_door("old_cabin")
	for k in 2:
		s.outdoor_pos = door
		s._watch_visits()
		s.outdoor_pos = s.door_front("ranger_station")
		s._watch_visits()
	t.equal(int(s.visits.get("old_cabin", 0)), 2, "two arrivals counted")
	var opts := s.travel_options()
	t.equal(opts.size(), 1, "the cabin is on offer")
	var m0 := s.clock.absolute_day() * 10000 + s.clock.minute
	var e0 := s.needs.energy
	t.check(s.travel_to("old_cabin"), "walked there")
	t.check(s.outdoor_pos.distance_to(door) < 1.0, "the ranger is at the cabin")
	t.check(s.clock.absolute_day() * 10000 + s.clock.minute > m0, "time passed")
	t.check(s.needs.energy < e0, "and it was tiring")
	s.enter_building("ranger_station")
	t.equal(s.travel_options().size(), 0, "not from indoors")
