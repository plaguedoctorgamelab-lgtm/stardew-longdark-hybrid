extends RefCounted
## Warmth: each weather, season and night value changes warmth as tuned;
## indoors and stove values apply; chill doubles energy drain.
## Energy: each action costs its tuned amount; each food restores its amount;
## exhaustion slows walking (see test_movement).
## Collapse: zero energy, zero warmth and 2:00 each cause a collapse; the
## ranger wakes at 10:00 in the nearer valid bed with half energy; the game
## saves.


func _ctx(s: GameSession, weather: String, season: String, night: bool) -> Dictionary:
	return {"indoors": false, "weather": s.weather.row(weather), "season": season, "night": night, "walked": true, "rough": false}


func test_warmth_per_weather_season_night(t: TestCase) -> void:
	var s := TestCase.new_session()
	var n := s.needs
	var tun := s.tuning
	for w: String in s.content.ids("weather_types"):
		for season: String in GameClock.SEASONS:
			for night in [false, true]:
				var expect := float(s.weather.row(w)["warmth"]) + tun.num("warmth.season." + season) + 1.0
				if night:
					expect += tun.num("warmth.night")
				t.equal(n.warmth_delta(_ctx(s, w, season, night)), expect, "%s %s night=%s" % [w, season, night])
	# Spot checks against the spec table.
	t.equal(n.warmth_delta(_ctx(s, "clear", "summer", false)), 4.0, "clear summer day: +2 +1 +1")
	t.equal(n.warmth_delta(_ctx(s, "blizzard", "winter", true)), -11.0, "winter blizzard night: -7 -3 -2 +1")


func test_warmth_applies_each_step_outdoors(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_time(12 * 60)
	s.debug_force_weather("rain")
	s.debug_set_needs(200, 60)
	s.clock.advance_step()
	# Spring, rain, day: -2 -1 +1 = -2
	t.equal(s.needs.warmth, 58.0, "one step in spring rain")


func test_indoors_and_stove(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("blizzard")
	s.debug_set_needs(200, 30)
	s.enter_building("ranger_station")
	s.clock.advance_step()
	t.equal(s.needs.warmth, 40.0, "indoors +10")
	for st in ["door", "walls", "roof", "window"]:
		s.debug_cabin_step(st, true)
	s.leave_building()
	s.debug_teleport("cabin")
	t.check(s.enter_building("test_cabin"), "entered the repaired cabin")
	s.debug_add_item("firewood", 2)
	t.check(s.feed_stove(), "lit the stove")
	s.debug_set_needs(200, 30)
	s.clock.advance_step()
	t.equal(s.needs.warmth, 55.0, "stove lit +25")
	var burn := s.tuning.integer("warmth.stove_minutes_per_firewood")
	t.equal(int(s.structures.stove_minutes["test_cabin"]), burn - 10, "stove burns down")
	s.pass_minutes(burn)
	t.check(not s.structures.stove_lit("test_cabin"), "stove goes out after its burn time")


func test_hot_soup_warms(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_needs(100, 50)
	s.debug_add_item("hot_soup")
	t.check(s.eat("hot_soup"), "ate soup")
	t.equal(s.needs.warmth, 85.0, "hot soup +35 warmth (0.7.0, tracker #32)")
	t.equal(s.needs.energy, 170.0, "hot soup +70 energy")


func test_foods_restore_their_amounts(t: TestCase) -> void:
	var s := TestCase.new_session()
	for f: Dictionary in s.content.rows("foods"):
		s.debug_set_needs(50, 50)
		s.debug_add_item(f["item"])
		t.check(s.eat(f["item"]), "ate %s" % f["item"])
		t.equal(s.needs.energy, 50.0 + float(f["energy"]), "%s energy" % f["item"])
	var tun := s.tuning
	var expected := {"tin_of_beans": 60, "apple": 25, "sandwich": 50, "hot_soup": 70}
	for id: String in expected:
		t.equal(float(s.content.row("foods", id)["energy"]), float(expected[id]), "%s matches the spec" % id)


func test_walking_energy_per_step(t: TestCase) -> void:
	var s := TestCase.new_session()
	var n := s.needs
	var ctx := _ctx(s, "clear", "spring", false)
	t.equal(n.walk_cost(ctx), 1.0, "walking costs 1 per step")
	ctx["walked"] = false
	t.equal(n.walk_cost(ctx), 0.0, "standing still costs nothing")
	ctx["walked"] = true
	ctx["rough"] = true
	t.equal(n.walk_cost(ctx), 1.5, "rough ground 1.5x")
	ctx["weather"] = s.weather.row("blizzard")
	t.equal(n.walk_cost(ctx), 2.25, "rough ground in a blizzard 1.5x each")
	ctx["rough"] = false
	ctx["weather"] = s.weather.row("clear")
	n.set_values(200, 20)
	t.equal(n.walk_cost(ctx), 2.0, "chilled doubles the drain")


func test_walking_drains_in_play(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("overcast")
	s.debug_set_time(12 * 60)
	s.debug_set_needs(200, 100)
	s.outdoor_pos = s.world.spawn("station") + Vector2(8, 0)
	for i in 72:
		s.move(Vector2.RIGHT if i % 20 < 10 else Vector2.LEFT, 0.1)
		s.process(0.1)
	t.equal(s.needs.energy, 199.0, "one step of walking cost 1 energy")


func test_action_costs(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_drain(true, false)
	s.debug_set_time(9 * 60)
	s.debug_force_weather("clear")
	# Repair action: 8
	s.debug_teleport("cabin")
	s.map.mark_landmark("test_cabin")
	s.debug_add_item("planks", 2)
	s.debug_add_item("nails", 4)
	s.debug_set_needs(200, 100)
	var res := s.hammer()
	t.check(res.get("ok", false), "hammered")
	t.near(s.needs.energy, 200.0 - 8.0, 0.01, "a repair action costs 8")
	# Survey: 4
	s.debug_set_needs(200, 100)
	s.debug_set_time(9 * 60)
	t.check(s.start_survey(), "survey started")
	s.pass_minutes(30)
	t.near(s.needs.energy, 196.0, 0.01, "a survey costs 4")
	# Mapping a location: 2
	s.debug_set_needs(200, 100)
	s.debug_teleport("outlook")
	s.map_location("scenic_outlook")
	t.near(s.needs.energy, 198.0, 0.01, "mapping a location costs 2")


func test_exhausted_and_chilled_flags(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_needs(19, 24)
	t.check(s.needs.is_exhausted(), "exhausted below 20")
	t.check(s.needs.is_chilled(), "chilled below 25")
	s.debug_set_needs(20, 25)
	t.check(not s.needs.is_exhausted() and not s.needs.is_chilled(), "not at the thresholds")


func test_blizzard_drains_full_warmth_in_under_two_hours(t: TestCase) -> void:
	# The spec's check: about 77 real seconds (11 steps). By night the drain
	# is -11 a step; by day -9, which empties 100 warmth on the 12th step.
	for start in [21 * 60, 10 * 60]:
		var s := TestCase.new_session()
		s.clock.season = 3
		s.debug_set_time(start)
		s.debug_set_needs(270, 100)
		var steps := 0
		while s.collapse_count == 0 and steps < 50:
			s.weather.today.assign(["blizzard", "blizzard", "blizzard"])
			s.clock.advance_step()
			steps += 1
		var limit := 110 if start > 18 * 60 else 120
		t.check(steps * 10 <= limit, "winter blizzard from %d:00 drained warmth in %d minutes" % [start / 60, steps * 10])


func _collapse_case(t: TestCase, how: String) -> void:
	var s := TestCase.new_session()
	s.debug_set_time(15 * 60)
	s.debug_force_weather("clear")
	s.debug_teleport("fork")
	var saves := s.save_count
	var day := s.clock.day
	match how:
		"energy":
			s.needs.set_values(0.5, 100)
			s.outdoor_pos += Vector2(0, 0)
			s.debug_add_item("planks", 0)
			s.needs.spend(1.0)
			s.clock.advance_step()
		"warmth":
			s.needs.set_values(200, 1)
			s.debug_force_weather("storm")
			s.clock.advance_step()
		"late":
			s.debug_set_time(1550)
			s.clock.advance_step()
	t.equal(s.collapse_count, 1, "%s causes a collapse" % how)
	t.equal(s.clock.day, day + 1, "%s: wakes the next day" % how)
	t.equal(s.clock.minute, 600, "%s: wakes at 10:00" % how)
	t.equal(s.needs.energy, 135.0, "%s: half energy" % how)
	t.equal(s.needs.warmth, 100.0, "%s: full warmth" % how)
	t.equal(s.location, "ranger_station", "%s: wakes in the station bed" % how)
	t.check(s.save_count > saves, "%s: the game saves" % how)


func test_collapse_from_zero_energy(t: TestCase) -> void:
	_collapse_case(t, "energy")


func test_collapse_from_zero_warmth(t: TestCase) -> void:
	_collapse_case(t, "warmth")


func test_collapse_at_two_am(t: TestCase) -> void:
	_collapse_case(t, "late")


func test_collapse_wakes_in_nearer_bed(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("cabin")
	t.equal(s.nearest_bed(), "ranger_station", "a broken cabin is not a valid bed")
	for st in ["door", "walls", "roof", "window"]:
		s.debug_cabin_step(st, true)
	t.equal(s.nearest_bed(), "test_cabin", "the repaired cabin is nearer")
	s.debug_teleport("fork")
	var fork := s.outdoor_pos
	var to_station := fork.distance_to(s.door_front("ranger_station"))
	var to_cabin := fork.distance_to(s.door_front("test_cabin"))
	t.equal(s.nearest_bed(), "test_cabin" if to_cabin < to_station else "ranger_station", "nearer bed from the fork")
	s.debug_teleport("cabin")
	var texts := []
	s.collapsed.connect(func(text: String) -> void: texts.append(text))
	s.collapse()
	t.equal(s.location, "test_cabin", "woke in the cabin")
	t.equal(texts.size(), 1, "a message says who found the ranger")
	t.check(str(texts[0]).length() > 10, "rescue message has text")
