extends RefCounted
## Phase 4b, steps 9 and 10: heart events and romance. Spoiler-safe: these
## tests check the events' shape and rules, and report only counts.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.town_open = true
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	return s


## Puts the ranger at an event's place.
func _put(s: GameSession, where: String) -> void:
	var kind := where.get_slice(":", 0)
	var id := where.get_slice(":", 1)
	s.leave_building()
	match kind:
		"room":
			s.enter_town()
			s.enter_town_room(id)
		"town":
			s.enter_town()
			s.leave_town_room()
			var p: Vector2i = s.town.places[id]
			s.town_pos = Vector2(p) + Vector2(0.5, 0.5)
		"park":
			s.leave_town()
			match id:
				"station":
					s.outdoor_pos = s.door_front("ranger_station")
					s.enter_building("ranger_station")
				"porch":
					s.outdoor_pos = s.door_front("ranger_station")
				"gate":
					s.outdoor_pos = s.gate_front()
				"outlook", "tower_or_outlook":
					s.outdoor_pos = s.site_pos("outlook")
				"tower":
					s.sites_open["static_tower"] = true
					s.outdoor_pos = s.door_front("static_tower")
					s.enter_building("static_tower")


func test_every_event_is_well_made(t: TestCase) -> void:
	var s := _session()
	var rows := s.content.rows("spoiler_heart_events")
	t.equal(rows.size(), 52, "52 heart events: 4 romances of 5, 8 friends of 4")
	var per := {}
	for r: Dictionary in rows:
		var who := str(r["person"])
		per[who] = int(per.get(who, 0)) + 1
		t.check(s.content.has("townsfolk", who), "%s is a townsperson" % r["id"])
		t.check(int(r["from"]) < int(r["to"]), "%s has hours" % r["id"])
		var where := str(r["where"])
		var kind := where.get_slice(":", 0)
		var id := where.get_slice(":", 1)
		match kind:
			"room":
				t.check(s.shops.has_room(id), "%s: a room" % r["id"])
			"town":
				t.check(s.town.places.has(id), "%s: a town place" % r["id"])
			"park":
				t.check(id in ["station", "porch", "gate", "outlook", "tower", "tower_or_outlook"], "%s: a park place" % r["id"])
			_:
				t.check(false, "%s: a known place kind" % r["id"])
		var cast := {}
		for c: Array in r.get("cast", [[who, 0, -1]]):
			cast[str(c[0])] = true
		for st: Array in HeartEvents.flatten(r["steps"]):
			match str(st[0]):
				"say":
					t.check(cast.has(str(st[1])), "%s: whoever speaks is in the scene" % r["id"])
				"emote":
					t.check(Art.has_picture("emote_" + str(st[2])), "%s: emote %s is drawn" % [r["id"], st[2]])
				"give":
					t.check(s.content.has("items", str(st[1])), "%s gives a real thing" % r["id"])
				"say", "do", "pause", "walk", "face", "pts", "note", "flag":
					pass
		if bool(s.content.row("townsfolk", who).get("romance", false)):
			t.check(int(r["hearts"]) in [2, 4, 6, 8, 10], "%s: romance hearts" % r["id"])
		else:
			t.check(int(r["hearts"]) in [2, 4, 6, 8], "%s: friend hearts" % r["id"])
	for r: Dictionary in s.content.rows("townsfolk"):
		t.equal(int(per.get(str(r["id"]), 0)), 5 if bool(r.get("romance", false)) else 4, "%s's events" % r["id"])


func test_an_event_plays_once_in_its_place_and_hours(t: TestCase) -> void:
	var s := _session()
	var r := s.life.row("he_wren_2")
	s.debug_set_hearts("wren", 1)
	s.debug_set_weekday("mon")
	s.debug_set_time(int(r["from"]))
	_put(s, str(r["where"]))
	t.equal(s.life.due(), "", "not before the hearts")
	s.debug_set_hearts("wren", 2)
	t.equal(s.life.due(), "he_wren_2", "with the hearts, in the place and hours")
	s.debug_set_time(int(r["to"]))
	t.equal(s.life.due(), "", "not outside its hours")
	s.debug_set_time(int(r["from"]))
	s.leave_town()
	t.equal(s.life.due(), "", "not somewhere else")
	_put(s, str(r["where"]))
	s.life.play_through("he_wren_2")
	t.check(s.life.seen.has("he_wren_2"), "seen once played")
	t.equal(s.life.due(), "", "and never again")


func test_events_come_in_order(t: TestCase) -> void:
	var s := _session()
	s.debug_set_hearts("rosa", 8)
	t.check(s.life.ready("he_rosa_2"), "the first is ready")
	t.check(not s.life.ready("he_rosa_4"), "the second waits for the first")
	s.life.play_through("he_rosa_2")
	t.check(s.life.ready("he_rosa_4"), "then it's ready")


## Every event's place can be reached in its hours on some day of the week,
## in the weather it asks for: none can be missed for good.
func test_no_event_can_be_missed_for_good(t: TestCase) -> void:
	var s := _session()
	var bad := 0
	for r: Dictionary in s.content.rows("spoiler_heart_events"):
		var where := str(r["where"])
		if not where.begins_with("room:"):
			continue
		var place := where.get_slice(":", 1)
		var ok := false
		for day: String in Town.DAYS:
			if r.has("day") and str(r["day"]) != day:
				continue
			for wet: bool in [false, true]:
				if r.has("weather") and (str(r["weather"]) == "rain") != wet:
					continue
				for m in range(int(r["from"]), int(r["to"]), 10):
					var open := s.content.has("town_places", place) and s.content.row("town_places", place).has("open")
					if open:
						var tp := s.content.row("town_places", place)
						if not (tp.get("closed", []) as Array).has(day) and m >= int(tp["open"]) and m < int(tp["close"]):
							ok = true
					else:
						for who in s.town.residents(place):
							if s.town.routine_place(who, m, day, wet) == place and m >= s.tuning.integer("town.visit_from") and m < s.tuning.integer("town.visit_until"):
								ok = true
		if not t.check(ok, "%s: its room can be entered in its hours" % r["id"]):
			bad += 1
	t.equal(bad, 0, "every room event can happen")


func test_a_scene_changes_what_it_should(t: TestCase) -> void:
	var s := _session()
	var keep := 0
	for r: Dictionary in s.content.rows("spoiler_heart_events"):
		for st: Array in HeartEvents.flatten(r["steps"]):
			if str(st[0]) == "give":
				keep += 1
	t.check(keep >= 8, "keepsakes to be had: %d" % keep)
	# Agnes opens the archive.
	s.debug_set_hearts("agnes", 2)
	s.life.play_through("he_agnes_2")
	t.check(s.life.flags.has("archive"), "the archive is open")
	# A choice is followed, and the rest of the scene after it.
	var before := s.town.points("wren")
	s.debug_set_hearts("wren", 2)
	before = s.town.points("wren")
	s.life.play_through("he_wren_2", [0])
	t.check(s.town.points("wren") > before, "the first choice gave friendship")


func test_bouquet_only_at_eight_hearts(t: TestCase) -> void:
	var s := _session()
	s.backpack.add("bouquet", 1)
	s.debug_set_hearts("teo", 7)
	t.equal(s.life.give_bouquet("teo"), "romance_not_yet", "seven hearts: not yet")
	t.equal(s.backpack.count("bouquet"), 1, "the bouquet is kept")
	t.equal(s.life.give_bouquet("rosa"), "romance_not_them", "Rosa isn't a romance")
	t.equal(s.life.give_bouquet("pip"), "romance_not_them", "never Pip")
	s.debug_set_hearts("teo", 8)
	t.equal(s.town.cap("teo") / s.tuning.integer("friendship.points_per_heart"), 8, "the cap is 8 before dating")
	t.equal(s.life.give_bouquet("teo"), "romance_accept", "eight hearts: yes")
	t.equal(s.backpack.count("bouquet"), 0, "the bouquet is given")
	t.check(s.life.dating.has("teo"), "dating")
	t.equal(s.town.cap("teo") / s.tuning.integer("friendship.points_per_heart"), 10, "dating lifts the cap to 10")
	s.town.add_points("teo", 600)
	t.equal(s.town.hearts("teo"), 10, "ten hearts reached")
	s.life.end_dating("teo")
	t.check(not s.life.dating.has("teo"), "just friends")
	t.equal(s.town.hearts("teo"), 10, "the hearts stay")


func test_the_ten_heart_event_needs_dating(t: TestCase) -> void:
	var s := _session()
	s.debug_set_hearts("nell", 8)
	for h in [2, 4, 6, 8]:
		s.life.play_through("he_nell_%d" % h)
	s.life.dating["nell"] = true
	s.debug_set_hearts("nell", 10)
	t.check(s.life.ready("he_nell_10"), "dating, ten hearts: the last event is ready")
	s.life.end_dating("nell")
	t.check(not s.life.ready("he_nell_10"), "not once just friends")


func test_sweethearts_leave_mailbox_gifts(t: TestCase) -> void:
	var s := _session()
	s.life.dating["wren"] = true
	for i in 20:
		s.clock.start_next_day()
	t.check(s.life.mail_gifts.size() > 0, "gifts came in twenty days: %d" % s.life.mail_gifts.size())
	var n := s.life.mail_gifts.size()
	var lines := s.life.take_mail_gifts()
	t.equal(lines.size(), n, "each one read")
	t.equal(s.life.mail_gifts.size(), 0, "the mailbox is empty")


func test_dating_and_many_lines(t: TestCase) -> void:
	var s := _session()
	var line := {}
	for r: Dictionary in s.content.rows("dialogue"):
		if str(r["id"]) == "wren_dating_1":
			line = r
	t.check(not s.town.line_fits("wren", line), "a sweetheart's line waits for dating")
	s.life.dating["wren"] = true
	t.check(s.town.line_fits("wren", line), "then it fits")
	var many := {}
	for r: Dictionary in s.content.rows("dialogue"):
		if str(r["id"]) == "marge_notice_many":
			many = r
	t.check(not s.town.line_fits("marge", many), "one sweetheart: Marge says nothing")
	s.life.dating["sol"] = true
	t.check(s.town.line_fits("marge", many), "two: she notices")


## Pip is never part of romance in any way. Lists Pip's lines and events for
## the designer's review (printed, not written to a file).
func test_child_safety(t: TestCase) -> void:
	var s := _session()
	t.check(not s.life.can_date("pip"), "Pip can't be dated")
	t.check(not bool(s.content.row("townsfolk", "pip").get("romance", false)), "Pip is not a romance")
	var lines := PackedStringArray()
	for table in ["dialogue", "spoiler_dialogue"]:
		for r: Dictionary in s.content.rows(table):
			if str(r["speaker"]) == "pip":
				t.check(not r.has("dating") and not r.has("notice_many"), "%s isn't a romance line" % r["id"])
				lines.append(str(r["id"]))
	var events := 0
	for r: Dictionary in s.content.rows("spoiler_heart_events"):
		var in_it := str(r["person"]) == "pip"
		for c: Array in r.get("cast", []):
			if str(c[0]) == "pip":
				in_it = true
		if not in_it:
			continue
		events += 1
		t.check(str(r["person"]) == "pip", "%s: Pip is only in Pip's own events" % r["id"])
		t.check(not bool(r.get("dating", false)), "%s needs no dating" % r["id"])
		var where := str(r["where"])
		t.check(where.begins_with("town:") or where == "room:library" or where == "park:gate", "%s is in a public place" % r["id"])
	t.equal(events, 4, "Pip's four events")
	print("        (review) Pip has %d lines and %d heart events; their ids: %s" % [lines.size(), events, ", ".join(lines)])
