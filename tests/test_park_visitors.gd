extends RefCounted
## Phase 3, steps 3 and 6: visitors, how far they go, how many come.


func _park(open_ring_two: bool = false) -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.tomorrow.assign(["clear", "clear", "clear"])
	if open_ring_two:
		for r in ["pond", "tower"]:
			ParkHelpers.open_route(s, r)
		for id: String in ["kettle_pond", "static_tower"]:
			ParkHelpers.ready_site(s, id)
	for id: String in ["old_cabin", "outlook"]:
		ParkHelpers.ready_site(s, id)
	return s


func test_no_ready_site_no_visitors(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.park.expected_visitors(), 0.0, "nobody expected")
	s.debug_skip_day()
	t.equal(s.park.schedule.size(), 0, "nobody comes")


func test_visitors_walk_only_on_trail_to_ready_sites(t: TestCase) -> void:
	var s := _park()
	s.clock.season = 1
	s.debug_skip_day()
	t.check(s.park.schedule.size() > 0, "visitors are coming")
	var reached := {}
	var off := 0
	var ticks := 0
	for m in range(360, 1560, 4):
		s.park.advance_to(float(m))
		for p: Dictionary in s.park.parties:
			if p["state"] in ["walk", "dwell", "rest"]:
				var pos: Vector2 = p["pos"]
				if not s.park.net.has(Vector2i(floori(pos.x), floori(pos.y))):
					off += 1
				ticks += 1
		for e: Dictionary in s.park.events:
			if e["type"] == "reached":
				reached[e["place"]] = true
	t.check(ticks > 100, "visitors were about (%d)" % ticks)
	t.equal(off, 0, "no visitor ever stood off the trail")
	for place: String in reached:
		t.check(s.site_ready(place), "%s was ready" % place)
	t.check(reached.has("outlook") or reached.has("old_cabin"), "someone reached a site")
	t.check(not reached.has("kettle_pond") and not reached.has("static_tower"), "nobody went where there is no trail")


func test_day_parties_only_choose_what_they_can_get_back_from(t: TestCase) -> void:
	var s := _park(true)
	s.clock.season = 1
	s.debug_skip_day()
	var g := s.park.gate_node()
	var checked := 0
	for m in range(480, 700, 2):
		var before := s.park.parties.size()
		s.park.advance_to(float(m))
		for p: Dictionary in s.park.parties.slice(before):
			if p["home"] != "":
				continue
			for l: Dictionary in p["legs"]:
				if l["act"] == "visit":
					checked += 1
					t.check(s.park.in_reach(g, l["ref"], float(m) - 2.0), "%s within reach of a day party arriving at %d" % [l["ref"], m])
	t.check(checked > 0, "day parties planned visits (%d)" % checked)
	for place: String in ["kettle_pond", "static_tower"]:
		t.check(not s.park.in_reach(g, place, 480.0), "%s is beyond a day from the gate" % place)


func test_a_campground_and_the_cabin_extend_reach(t: TestCase) -> void:
	var s := _park(true)
	var g := s.park.gate_node()
	t.check(not s.park.visitable_sites().has("static_tower"), "the tower can't be visited yet")
	s.debug_build("pond_campground")
	t.check(s.park.visitable_sites().has("kettle_pond"), "the pond can, with a campground there")
	t.check(s.park.visitable_sites().has("static_tower"), "and the tower, from camp")
	t.check(s.park.in_reach(s.park.pad_node("pond_campground"), "static_tower", s.tuning.num("visitors.camp_day_start")), "campers walk to the tower and back in a day")
	t.check(not s.park.in_reach(g, "static_tower", 480.0), "still not from the gate")
	var s2 := _park(true)
	s2.debug_repair_all("test_cabin", true)
	s2.park.rent_mode = "rent"
	t.check(s2.park.visitable_sites().has("kettle_pond"), "a rented cabin opens the pond to the public")


func test_campers_stay_and_pay(t: TestCase) -> void:
	var s := _park(true)
	s.debug_build("pond_campground")
	s.clock.season = 1
	var p := s.park.spawn("campers", 3, "pond_campground", 2)
	t.equal(p["legs"][0]["act"], "pitch", "campers head for camp first")
	var before := int(s.park.money.totals(0, 99).get("camping", 0))
	s.debug_skip_day()
	t.equal(int(s.park.money.totals(0, 99).get("camping", 0)) - before, 15, "a night's camping permit")
	t.check(not s.park.party(int(p["id"])).is_empty(), "still here in the morning")
	s.debug_skip_day()
	s.debug_skip_day()
	t.check(s.park.party(int(p["id"])).is_empty(), "gone home after their nights")


func test_arrivals_follow_season_day_and_weather(t: TestCase) -> void:
	var s := _park()
	var pk := s.park
	var mults: Dictionary = s.tuning.value("visitors.season")
	# Over a year of mornings, scheduled arrivals match the expected number.
	var expected := 0.0
	var got := 0
	var by_season := [0.0, 0.0, 0.0, 0.0]
	var exp_season := [0.0, 0.0, 0.0, 0.0]
	for day in 112:
		s.clock.season = day / 28
		s.clock.day = day % 28 + 1
		var w: String = ["clear", "clear", "rain", "clear", "storm", "overcast", "clear"][day % 7]
		s.weather.today.assign([w, w, w])
		pk.rng.seed = day
		var e := pk.expected_visitors()
		# Short winter days put some sites out of a day's reach.
		var appeal := 0.0
		for id: String in pk.visitable_sites():
			appeal += pk.site_appeal(id)
		var want := s.tuning.num("visitors.base_per_site") * appeal * float(mults[s.clock.season_name()])
		if (s.tuning.value("visitors.busy_days") as Array).has(pk.week_day()):
			want *= s.tuning.num("visitors.busy_multiplier")
		want *= float((s.tuning.value("visitors.weather_multiplier") as Dictionary).get(w, 1.0))
		t.near(e, want, 0.0001, "day %d expected" % day)
		pk._plan_arrivals()
		var n := 0
		for a: Dictionary in pk.schedule:
			n += int(a["size"])
		expected += e
		got += n
		by_season[s.clock.season] += n
		exp_season[s.clock.season] += e
	t.near(float(got) / expected, 1.0, 0.05, "a year of arrivals within 5%")
	for i in 4:
		t.near(by_season[i] / exp_season[i], 1.0, 0.2, "season %d within 20%%" % i)


func test_the_park_never_holds_more_than_80(t: TestCase) -> void:
	var s := _park()
	s.clock.season = 1
	s.tuning.set_value("visitors.base_per_site", 200)
	s.debug_skip_day()
	var most := 0
	for m in range(360, 1560, 10):
		s.park.advance_to(float(m))
		most = maxi(most, s.park.visitors_in_park())
	t.check(most <= 80, "never more than 80 in the park (%d)" % most)
	t.check(most > 40, "it did fill up (%d)" % most)
	t.check(not s.park.carry.is_empty(), "the rest come tomorrow")


func test_storms_send_day_parties_home(t: TestCase) -> void:
	var s := _park()
	s.clock.season = 1
	s.park.sim_day = s.clock.absolute_day()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	s.park.advance_to(600.0)
	s.debug_force_weather("storm")
	s.park.advance_to(620.0)
	t.equal(p["legs"][-1]["act"], "home", "the hikers head home")
	t.equal(p["legs"].size(), 1, "with nothing else planned: %s" % str(p["legs"]))


func test_party_record_unchanged_by_being_drawn(t: TestCase) -> void:
	var s := _park()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("family", 4) if not s.park.picnic_places(s.park.gate_node(), 480.0).is_empty() else s.park.spawn("day_hiker", 2)
	s.park.advance_to(520.0)
	var before := JSON.stringify(s.park.to_dict()["parties"])
	var root := Node2D.new()
	var view := ParkView.new()
	view.setup(s, root)
	s.outdoor_pos = p["pos"]
	view._draw_people()
	t.check(view._people.size() > 0, "drawn as characters near the ranger")
	s.outdoor_pos = Vector2(p["pos"]) + Vector2(200, 0)
	view._draw_people()
	t.equal(view._people.size(), 0, "a record again when the ranger is far")
	t.equal(JSON.stringify(s.park.to_dict()["parties"]), before, "position, plans, trash and mood kept")
	view.free()
	root.free()


func test_moods_count_toward_the_week(t: TestCase) -> void:
	var s := _park()
	s.clock.season = 1
	s.debug_skip_day()
	s.park.advance_to(1559.0)
	s.debug_skip_day()
	t.check(int(s.park.week["mood_n"]) > 0 or int(s.park.week["visitors"]) == 0, "visitors' moods are counted as they leave")
