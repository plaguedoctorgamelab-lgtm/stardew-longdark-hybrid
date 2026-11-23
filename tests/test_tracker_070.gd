extends RefCounted
## 0.7.0: Mark's tracker reports on 0.6.8 (#28 to #41), as a player would
## meet them.


func _hold(s: GameSession, item: String) -> void:
	if s.backpack.count(item) == 0:
		s.backpack.add(item, 1)
	for i in s.backpack.size():
		if s.backpack.item_at(i) == item:
			s.selected_slot = i
			return


func test_a_sign_by_the_ford_counts_at_the_edge(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("the_sign_in_ford", "test")
	var at := s.jobs.spot_pos("ford_sign")
	s.backpack.add("trail_sign", 1)
	s.backpack.add("hammer", 1)
	s.outdoor_pos = at + Vector2(0, 1)
	t.check(s.jobs.work_spot("ford_sign") != "", "the old sign is fished out of the ford")
	t.equal(s.backpack.count("trail_sign"), 2, "with a sign already in the pack, there are two")
	# A sign on the trail, near the edge of the step's circle (tracker #29).
	var best := Vector2i(-1, -1)
	var best_d := 0.0
	var c := Vector2i(at)
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var tl := c + Vector2i(dx, dy)
			var d := (Vector2(tl) + Vector2(0.5, 0.5)).distance_to(at)
			if d <= 8.0 and d > best_d and s.place_problem(tl, "trail_sign") == "":
				best = tl
				best_d = d
	t.check(best.x >= 0, "a trail tile near the ford")
	t.check(s.debug_put_up(best, "trail_sign", "ranger_station"), "the sign goes up %.1f tiles from the ford" % best_d)
	s.jobs.update(true)
	t.check(s.jobs.is_done("the_sign_in_ford"), "The Sign in the Ford is done")


func test_the_tower_step_names_the_trail_still_to_do(t: TestCase) -> void:
	var s := TestCase.new_session()
	for k in ["open_tower", "stake_east", "stake_west", "reopen_pond_trail"]:
		s.jobs.add(k, "test")
	var i := 4
	t.equal(str(s.jobs.def("open_tower")["steps"][i]["kind"]), "join_trail", "step 5 joins the tower by trail")
	t.equal(s.jobs.link_of("open_tower", i), "stake_east", "at first it points to Stake Trail, East")
	s.jobs.debug_finish("stake_east")
	t.equal(s.jobs.link_of("open_tower", i), "stake_west", "with East done it points to West, not to a finished job (tracker #34)")
	s.jobs.debug_finish("stake_west")
	t.equal(s.jobs.link_of("open_tower", i), "reopen_pond_trail", "then to the pond trail")


func test_a_door_says_it_is_shut_today(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.enter_town()
	# Day 3 is a Wednesday: the Percolator's day off.
	while s.town.weekday() != "wed":
		s.clock.start_next_day(s.tuning.integer("time.day_start_minute"))
	s.debug_set_time(16 * 60 + 20)
	var line := s.place_line("percolator")
	t.check(line.contains(s.content.text("day_wed")), "the door says why it is shut at 4:20 on a Wednesday: %s (tracker #30)" % line)
	t.check(not s.town.is_open("percolator"), "and it is shut")
	s.clock.start_next_day(s.tuning.integer("time.day_start_minute"))
	s.debug_set_time(16 * 60 + 20)
	t.check(s.town.is_open("percolator"), "on Thursday at 4:20 it is open")
	t.check(s.place_line("percolator").contains(s.content.text("day_wed")), "and its hours still name its day off")


func test_burnt_trees_can_be_chopped(t: TestCase) -> void:
	var s := TestCase.new_session()
	var tree := Vector2i(13, 29) * s.world.chunk_size + Vector2i(17, 22)
	t.equal(s.world.object_at(tree), "tree_dead", "a burnt tree in the burn")
	for off: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		if not s.world.is_solid(tree + off):
			s.outdoor_pos = Vector2(tree + off) + Vector2(0.5, 0.5)
			s.facing = {Vector2i(0, 1): GameSession.FACING_UP, Vector2i(-1, 0): GameSession.FACING_RIGHT, Vector2i(1, 0): GameSession.FACING_LEFT, Vector2i(0, -1): GameSession.FACING_DOWN}[off]
			break
	s.backpack.add("axe", 1)
	var before := s.backpack.count("firewood")
	var res := s.chop()
	t.check(bool(res.get("ok", false)) and res.get("tile") == tree, "the axe fells it (tracker #31)")
	t.equal(s.backpack.count("firewood") - before, s.tuning.integer("axe.firewood") + 1, "dry wood: one more firewood than a green tree")


func test_hot_soup_warms_and_says_so(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_needs(100, 30)
	s.backpack.add("hot_soup", 1)
	var said := []
	s.message.connect(func(m: String) -> void: said.append(m))
	t.check(s.eat("hot_soup"), "the soup is eaten")
	t.check(s.needs.warmth >= 30.0 + 34.0, "it warms a good deal: %d (tracker #32)" % s.needs.warmth)
	t.check(not said.is_empty() and str(said[-1]).contains(s.content.text("msg_ate_warmth", {"n": 35})), "and says how much: %s" % [said])


func test_spring_snow_is_rare(t: TestCase) -> void:
	var s := TestCase.new_session()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spring := 0
	var autumn := 0
	for i in 4000:
		if s.weather.draw("spring", 3, rng) == "snow":
			spring += 1
		if s.weather.draw("autumn", 26, rng) == "snow":
			autumn += 1
	t.check(spring > 0, "a spring flurry can still happen")
	t.check(spring * 2 < autumn, "but far less often than late autumn's (%d against %d, tracker #33)" % [spring, autumn])
	var later := 0
	for i in 1000:
		if s.weather.draw("spring", 10, rng) == "snow":
			later += 1
	t.equal(later, 0, "and never after the first week")


func test_full_screen_is_the_start(t: TestCase) -> void:
	t.check(bool(Settings.values.get("fullscreen", false)) or FileAccess.file_exists(Settings.PATH), "the game starts full screen unless the player chose a window (tracker #37)")
	t.check(InputMap.has_action("fullscreen"), "F11 switches it")


func test_every_reward_has_its_icon(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("rewards"):
		t.check(Art.has_picture(str(r["icon"])), "%s's icon %s is drawn, not a purple square (tracker #40)" % [r["id"], r["icon"]])
	for r: Dictionary in s.content.rows("job_types"):
		t.check(Art.has_picture(str(r["icon"])), "%s's icon is drawn" % r["id"])


func test_the_map_in_town_shows_humdrum(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town_open = true
	s.enter_town()
	var m := MapScreen.new()
	m.setup(s)
	m.open()
	t.check(m.visible and m.town_plan.visible, "M in town opens the plan of Humdrum (tracker #41)")
	t.check(not m.clip.visible, "not the park's map")
	t.equal(m.title.text, s.content.text("map_town_title"), "titled for the town")
	for b: Dictionary in s.town.buildings:
		t.check(m.map_name(str(b["id"])) != "", "%s is named on it" % b["id"])
	m.close()
	s.leave_town()
	m.open()
	t.check(m.clip.visible and not m.town_plan.visible, "back in the park, the park's map")
	m.free()


func test_toasts_and_tags_keep_words_clear(t: TestCase) -> void:
	var s := TestCase.new_session()
	var note := JobNote.new()
	note.setup(s)
	var p := note._make_toast("job_kind_note", Color.WHITE, "Tidy the station: the desk, the shelf, the boots: 1 of 3")
	t.check(p.clip_contents, "nothing is drawn past a toast's end (tracker #39)")
	var l: Label = p.get_child(p.get_child_count() - 1)
	t.check(l.position.x >= JobNote.TOAST_ICON_X + 10.0, "the words start after the icon")
	t.check(l.position.x + l.size.x <= p.size.x, "and end inside the flag")
	t.check(Hud.TAG_LEFT >= 7.0, "a hover tag's words start past its string hole")
	note.free()
