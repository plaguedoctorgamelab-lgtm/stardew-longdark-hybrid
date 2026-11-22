extends RefCounted
## Phase 4, 4a first pass (0.6.0): Humdrum through the gate, named days,
## townsfolk and their routines, talking, friendship and gifts. From the
## Phase 4 Spec's automated tests: calendar, routines, friendship, dialogue,
## gifts, saves and child safety.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	return s


func test_days_are_named_through_a_year(t: TestCase) -> void:
	var s := _session()
	t.equal(s.clock.weekday_key(), "mon", "spring 1 is a Monday")
	var sundays := 0
	for i in 4 * s.clock.days_per_season() - 1:
		s.clock.start_next_day()
		if s.clock.day == 1:
			t.equal(s.clock.weekday_key(), "mon", "day 1 of a season is a Monday")
		if s.clock.weekday_key() == "sun":
			sundays += 1
			t.equal(s.park.week_day(), s.tuning.integer("money.week_days"), "the Chief's report day is a Sunday")
	t.equal(sundays, 16, "sixteen Sundays in a year")


func test_the_gate_leads_to_town_and_back(t: TestCase) -> void:
	var s := _session()
	s.enter_town()
	t.check(s.in_town, "through the gate into Humdrum")
	t.check(not s.is_indoors(), "the town is outdoors")
	t.equal(s.ranger_pos(), s.town.entry, "the ranger stands at the park road's end")
	for i in 30:
		s.move(Vector2(1, 0), 0.2)
	t.check(not s.in_town, "walking east along the road leads back out")
	t.check(not s.world.is_solid(Vector2i(s.outdoor_pos)), "back on the park side of the gate, on open ground")


func test_everyone_is_somewhere_valid_all_year(t: TestCase) -> void:
	var s := _session()
	var bad: Array[String] = []
	for person: String in s.content.ids("townsfolk"):
		for day in Town.DAYS:
			for rainy in [false, true]:
				for m in range(0, 1560, 30):
					var at := s.town.routine_place(person, m, day, rainy)
					if not s.town.places.has(at):
						bad.append("%s %s %d: %s" % [person, day, m, at])
					elif s.town.is_solid(s.town.places[at]):
						bad.append("%s at %s, a solid tile" % [person, at])
	t.equal(bad.size(), 0, "every person is at a known, walkable place at every hour (%s)" % ", ".join(bad.slice(0, 3)))


func test_people_walk_their_routines_along_paths(t: TestCase) -> void:
	var s := _session()
	s.enter_town()
	s.debug_set_time(14 * 60 + 50)
	s.town.place_everyone()
	var start: Vector2 = s.town.people["wren"]["pos"]
	s.debug_set_time(15 * 60)
	for i in 200:
		s.town.update(0.1)
		var p: Vector2 = s.town.people["wren"]["pos"]
		t.check(not s.town.is_solid(Vector2i(p)) or Vector2i(p) == s.town.places[s.town.people["wren"]["goal"]], "never through a wall")
	t.check((s.town.people["wren"]["pos"] as Vector2).distance_to(Vector2(s.town.places["creek_path"]) + Vector2(0.5, 0.5)) < 0.1, "Wren walked from the shop to the creek path at 15:00")
	t.check(start != s.town.people["wren"]["pos"], "she moved")


func test_keepers_stand_at_their_open_shops(t: TestCase) -> void:
	var s := _session()
	s.debug_set_time(10 * 60)
	t.check(s.town.is_open("percolator"), "The Percolator is open on a Monday morning")
	t.check(not s.town.is_open("casa_luna"), "Casa Luna is closed on Mondays")
	s.town.place_everyone()
	# 0.6.2: shops have rooms, so the keeper is inside behind the counter.
	t.check(not s.town.shown("wren") and s.shops.people_in("percolator").has("wren"), "Wren is inside her shop, behind the counter")
	t.check(not s.town.shown("agnes") or s.town.routine_place("agnes") == "library", "Agnes is at the library")
	s.debug_set_time(23 * 60)
	s.town.place_everyone()
	t.check(not s.town.shown("marge"), "at night Marge is home, inside")


func test_talking_and_gifts_give_their_points(t: TestCase) -> void:
	var s := _session()
	var tw := s.town
	tw.talk("wren")
	t.equal(tw.points("wren"), 20, "talking once a day: 20")
	tw.talk("wren")
	t.equal(tw.points("wren"), 20, "only once a day")
	s.backpack.add("roast_hazelnuts", 3)
	var r := tw.give("wren", "roast_hazelnuts")
	t.check(bool(r["ok"]) and str(r["taste"]) == "love", "Wren loves roast hazelnuts")
	t.equal(tw.points("wren"), 100, "a loved gift: 80")
	tw.give("wren", "roast_hazelnuts")
	t.equal(str(tw.give("wren", "roast_hazelnuts")["reason"]), "limit", "two gifts a week")
	t.equal(s.backpack.count("roast_hazelnuts"), 1, "the third stays in the backpack")
	t.equal(str(tw.give("wren", "hammer")["reason"]), "no", "a tool can't be given")


func test_hearts_never_go_down_and_caps_hold(t: TestCase) -> void:
	var s := _session()
	var tw := s.town
	tw.add_points("marge", 260)
	t.equal(tw.hearts("marge"), 1, "one heart")
	tw.add_points("marge", -40)
	t.equal(tw.points("marge"), 250, "a hated gift never takes a heart away")
	tw.add_points("wren", 5000)
	t.equal(tw.hearts("wren"), 8, "a romance candidate stops at 8 hearts until dating")
	tw.add_points("gus", 5000)
	t.equal(tw.hearts("gus"), 10, "everyone else reaches 10")
	for i in 30:
		s.clock.start_next_day()
	t.equal(tw.hearts("gus"), 10, "friendship never decays")


func test_birthday_gifts_count_eight_times(t: TestCase) -> void:
	var s := _session()
	var b: Dictionary = s.content.row("townsfolk", "pip")["birthday"]
	s.clock.season = int(b["season"])
	s.clock.day = int(b["day"])
	s.backpack.add("berries", 1)
	var r := s.town.give("pip", "berries")
	t.check(bool(r["birthday"]), "it's Pip's birthday")
	t.equal(s.town.points("pip"), 80 * 8, "a loved birthday gift: 80 times 8")


func test_every_item_has_a_reaction_from_everyone(t: TestCase) -> void:
	var s := _session()
	var ok := ["love", "like", "neutral", "dislike", "hate", "no"]
	var missing := 0
	for person: String in s.content.ids("townsfolk"):
		var loves_park := false
		for item: String in s.content.ids("items"):
			var r := s.town.taste(person, item)
			if not r in ok:
				missing += 1
			if r == "love" and str(s.content.row("items", item)["kind"]) in ["food", "material"]:
				loves_park = true
		t.check(loves_park, "%s loves something from the park" % person)
	t.equal(missing, 0, "every item has a reaction from every person")


func test_no_line_repeats_within_a_week(t: TestCase) -> void:
	var s := _session()
	for person: String in s.content.ids("townsfolk"):
		var said := {}
		var repeats := 0
		var s2 := _session()
		for i in 7:
			var a: String = s2.town.talk(person)["text"]
			t.equal(s2.town.talk(person)["text"], a, "%s keeps to one line a day" % person)
			if said.has(a):
				repeats += 1
			said[a] = true
			s2.clock.start_next_day()
			s2.weather.today.assign(["clear", "clear", "clear"])
			s2.weather.check_change(s2.clock.minute)
		t.equal(repeats, 0, "%s says no line twice in a week" % person)


func test_park_event_lines_wait_for_their_events(t: TestCase) -> void:
	var s := _session()
	for r: Dictionary in s.content.rows("dialogue"):
		if r.has("event"):
			t.check(not s.town.line_fits(str(r["speaker"]), r), "%s waits for %s" % [r["id"], r["event"]])
	s.sites_open["old_cabin"] = true
	var line := s.town.choose_line("gus", false)
	t.equal(str(line.get("event", "")), "site:old_cabin", "once the cabin is open, Gus mentions it first")


func test_town_saves_and_loads(t: TestCase) -> void:
	var s := _session()
	s.town.add_points("teo", 320)
	s.town.talk("sol")
	s.enter_town()
	s.town_pos = Vector2(40.5, 30.5)
	var d := s.to_dict()
	var s2 := _session()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.check(s2.in_town, "still in town")
	t.equal(s2.town_pos, Vector2(40.5, 30.5), "at the same spot")
	t.equal(s2.town.points("teo"), 320, "friendship kept")
	t.check(s2.town.met.has("sol"), "who you've met kept")
	var old := s.to_dict()
	old.erase("town")
	(old["ranger"] as Dictionary).erase("in_town")
	var s3 := _session()
	s3.from_dict(JSON.parse_string(JSON.stringify(old)))
	t.check(not s3.in_town and s3.town.friendship.is_empty(), "a save from before the town loads, outside town")


func test_pip_is_never_part_of_romance(t: TestCase) -> void:
	var s := _session()
	var row := s.content.row("townsfolk", "pip")
	t.check(not bool(row["romance"]), "Pip is not a romance candidate")
	t.check(bool(row.get("child", false)), "Pip is marked a child")
	var words := ["love you", "date", "kiss", "romance", "darling", "sweetheart", "bouquet"]
	var lines: Array[String] = []
	for table in ["dialogue", "spoiler_dialogue"]:
		for r: Dictionary in s.content.rows(table):
			if str(r["speaker"]) == "pip":
				lines.append(str(r["text"]))
				for w in words:
					t.check(not str(r["text"]).to_lower().contains(w), "Pip's line %s has nothing romantic" % r["id"])
	# Listed for the designer's review, as the spec asks.
	print("Pip's lines for review:\n  " + "\n  ".join(lines))
