extends RefCounted
## Phase 5b, Gord and the night (docs/Phase 5b Spec.md): creature
## friendship, creature jobs, the three cousins' answers, the secret, hint or
## public choice, the moon, calendar events, Gord, aurora nights and the
## second pet.


func _at(s: GameSession, season: int, day: int, minute: int) -> void:
	s.clock.season = season
	s.clock.day = day
	s.clock.set_minute(minute)
	s.wildlife.morning()
	s.creatures.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)


func _dusk(s: GameSession) -> int:
	var sun: Array = s.tuning.value("light.sun." + s.clock.season_name())
	return int(sun[1]) + 10


func _job_steps_done(s: GameSession, key: String) -> int:
	s.jobs.update(true)
	return s.jobs.steps_done_count(key)


func test_full_moons_on_the_7th_and_21st(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	t.equal(c.moon_phase(7), 4, "full on the 7th")
	t.equal(c.moon_phase(21), 4, "full on the 21st")
	t.equal(c.moon_phase(14), 0, "new between")
	t.check(c.is_full_moon_day(7) and c.is_full_moon_day(21) and not c.is_full_moon_day(14), "two full moons a season")
	_at(s, 0, 7, 14 * 60)
	t.check(not c.full_moon_out(), "not out at noon")
	_at(s, 0, 7, _dusk(s) + 60)
	t.check(c.full_moon_out(), "out after dusk")
	var cal := s.town.calendar(0)
	t.check(bool(cal[6]["moon"]) and bool(cal[20]["moon"]) and not bool(cal[9]["moon"]), "the calendar shows them")


func test_aurora_nights(t: TestCase) -> void:
	var s := TestCase.new_session()
	for year in [1, 2, 3]:
		var days := Creatures.aurora_days_for(s.seed_value, year, s.tuning)
		t.check(days.size() >= 2 and days.size() <= 3, "year %d: two or three (%d)" % [year, days.size()])
		var winter := false
		for k in days.size():
			var d: int = days[k]
			var dis := d % 28 + 1
			t.check(not s.creatures.is_full_moon_day(dis), "never on a full moon")
			if (d % 112) / 28 == 3:
				winter = true
			if k > 0:
				t.check(d - int(days[k - 1]) >= 20, "at least 20 days apart")
		t.check(winter, "year %d: one in winter" % year)
	# The night of an aurora is clear, and Esme's Sky card says so the day before.
	var d0: int = Creatures.aurora_days_for(s.seed_value, 1, s.tuning)[0]
	var blocks := s.weather.generate_day(d0, "rain")
	t.equal(blocks[2], "clear", "an aurora night is clear")
	s.clock.season = (d0 - 1) / 28
	s.clock.day = (d0 - 1) % 28 + 1
	t.check(s.creatures.aurora_tomorrow(), "the day before")
	s.town.met["esme"] = true
	var r := s.fortune.reading(true)
	t.equal(str(r["cards"][0]["card"]), "aurora", "Esme's Sky is the aurora card")


func test_paw_hearts_from_food_and_time(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	s.backpack.add("fiddleheads", 3)
	c.feed("jackalopes", "fiddleheads")
	t.equal(int(c.points.get("jackalopes", 0)), 40, "loved: 40")
	t.equal(str(c.tastes["jackalopes"]["fiddleheads"]), "loves", "the taste is learned")
	c.feed("jackalopes", "fiddleheads")
	t.equal(int(c.points.get("jackalopes", 0)), 40, "once a day")
	t.equal(s.backpack.count("fiddleheads"), 2, "only one eaten")
	s.backpack.add("hot_soup", 1)
	c.fed_day.erase("jackalopes")
	c.feed("jackalopes", "hot_soup")
	t.equal(s.backpack.count("hot_soup"), 1, "won't eat it: kept")
	t.equal(str(c.tastes["jackalopes"]["hot_soup"]), "wont", "and remembered")
	# An hour near.
	c._near("magic_deer", 30)
	c._near("magic_deer", 31)
	t.equal(int(c.points.get("magic_deer", 0)), 10, "an hour near: 10")
	t.equal(c.fact("near:magic_deer"), 1, "counted for the jobs")
	c.points["gord"] = 250
	t.equal(c.hearts("gord"), 2, "100 a paw heart")
	c.points["gord"] = 9999
	t.equal(c.hearts("gord"), 5, "five at most")


func test_whisperer_and_secret_grow_faster(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	s.debug_choose_specialty("whisperer")
	c.add_points("gord", 20)
	t.equal(int(c.points["gord"]), 30, "Whisperer: half again")
	c.choice["jackalopes"] = "public"
	c.add_points("jackalopes", 20)
	t.equal(int(c.points["jackalopes"]), 15, "public: half (of 30)")


func test_creature_steps_go_in_order(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	s.jobs.add("cj_gord", "given")
	t.equal(c.current("gord"), "gord_met", "first, meet him")
	c.facts["wren_late"] = 1
	t.equal(_job_steps_done(s, "cj_gord"), 0, "a later step's fact counts for nothing yet")
	c.facts["gord_met"] = 1
	t.equal(_job_steps_done(s, "cj_gord"), 1, "the first step done")
	t.equal(c.current("gord"), "gord_words", "then the words")


func test_the_badgers_deal(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	t.check(not s.jobs.cond("creature:badger_trouble"), "no trouble yet")
	for k in 3:
		c.on_mischief("old_cabin")
	t.equal(c.deal_place, "old_cabin", "third mischief: the deal is about this place")
	s.jobs.update(true)
	t.check(s.jobs.is_active("cj_badgers"), "the job appears")
	c.watched("troll_badger")
	c.facts["near:troll_badgers"] = 2
	s.jobs.update(true)
	t.equal(c.current("troll_badgers"), "badgers_terms", "then terms")
	c.on_choice("creature:terms", "beans")
	t.equal(c.terms, "beans", "terms agreed")
	s.jobs.update(true)
	c.points["troll_badgers"] = 200
	s.backpack.add("tin_of_beans", 3)
	s.clock.set_minute(13 * 60)
	c._at_stone("tin_of_beans")
	t.equal(s.backpack.count("tin_of_beans"), 3, "by day they ignore it")
	s.clock.set_minute(_dusk(s) + 30)
	c._at_stone("tin_of_beans")
	t.equal(c.fact("badgers_weeks"), 1, "one week kept")
	c._at_stone("tin_of_beans")
	t.equal(c.fact("badgers_weeks"), 1, "once a week")
	s.clock.day += 7
	c._at_stone("tin_of_beans")
	s.jobs.update(true)
	t.check(s.jobs.is_done("cj_badgers"), "two weeks: settled")
	t.check(c.badger_peace("old_cabin"), "no more mischief there")


func test_the_jackalopes_coaxed(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	# A campground, a jackalope sketched, spring: they dig in.
	var pads: Array = s.content.ids("pads").filter(func(p: String) -> bool: return str(s.content.row("pads", p).get("facility", "")) == "campground")
	if pads.is_empty():
		t.check(true, "no campground pad in ring one: skipped")
		return
	s.debug_build(str(pads[0]))
	s.wildlife.record("jackalope", "sketch")
	_at(s, 0, 3, 13 * 60)
	t.check(c.burrows.size() == 3, "three burrows at the campground")
	s.jobs.update(true)
	t.check(s.jobs.is_active("cj_jackalopes"), "the job appears")
	s.backpack.add("fiddleheads", 10)
	c.feed("jackalopes", "fiddleheads")
	s.jobs.update(true)
	t.equal(c.current("jackalopes"), "trail", "found what they love; now the trail")
	for k in c.trail_spots().size():
		c.trail_day = -1
		c._lay("fiddleheads")
	s.jobs.update(true)
	t.equal(c.current("jackalopes"), "jack_waited", "trail laid")
	s.outdoor_pos = c.jack_meadow()
	_at(s, 0, 9, _dusk(s) - 15)
	c.update(0.1)
	s.jobs.update(true)
	t.equal(c.current("jackalopes"), "burrows_filled", "waited at dusk")
	s.backpack.add("shovel", 1)
	c.points["jackalopes"] = 0
	c._fill(c.burrows[0])
	t.equal(c.fact("burrows_filled"), 0, "two paw hearts first")
	c.points["jackalopes"] = 200
	for b: Vector2i in c.burrows:
		c._fill(b)
	s.jobs.update(true)
	t.check(s.jobs.is_done("cj_jackalopes"), "settled")
	var out := c.out_at("dusk")
	var at_meadow := out.any(func(o: Dictionary) -> bool: return str(o["creature"]) == "jackalopes" and Vector2(o["home"]) == c.jack_meadow())
	t.check(at_meadow, "they live in their meadow now")


func test_the_magic_deer_and_the_bell(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	s.wildlife.record("magic_deer", "sketch")
	_at(s, 2, 2, 13 * 60)
	s.jobs.update(true)
	t.check(s.jobs.is_active("cj_magic_deer"), "from the first autumn")
	c.facts["deer_seen_yard"] = 1
	s.jobs.update(true)
	var board := c.board_lines()
	t.check(board.size() == 1, "the clue on the note board")
	s.jobs.update(true)
	t.equal(c.current("magic_deer"), "bell_found", "then find it")
	c.on_enter("static_tower")
	t.check(s.backpack.has("old_bell"), "behind the tower's radio")
	s.jobs.update(true)
	c._hang()
	t.check(c.bell_hung and not s.backpack.has("old_bell"), "hung on its hook")
	s.jobs.update(true)
	t.check(c.deer_visits_tonight(), "the deer comes every night now")


func test_gord(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	_at(s, 0, 3, 13 * 60)
	t.check(c.out_at("day").any(func(o: Dictionary) -> bool: return str(o["id"]) == "gord_moose"), "a moose in the meadow by day")
	s.wildlife.record("gord_moose", "sketch")
	s.jobs.update(true)
	t.check(s.jobs.is_active("cj_gord"), "seen through the binoculars: his job")
	t.check(not c.gord_man_out(), "not a man by day")
	_at(s, 0, 7, _dusk(s) + 30)
	t.check(c.gord_man_out(), "a man on the full moon")
	t.check(not c.out_at("night").any(func(o: Dictionary) -> bool: return str(o["id"]) == "gord_moose"), "and no moose")
	c.talk_gord()
	s.jobs.update(true)
	t.equal(c.current("gord"), "gord_words", "met")
	t.check(c.coat_stocked(), "the outfitters stock his coat")
	c.on_talk("wren")
	s.jobs.update(true)
	s.backpack.add("big_coat", 1)
	s.jobs.update(true)
	t.equal(c.current("gord"), "gord_practised", "the coat bought")
	c.talk_gord()
	c.on_choice("creature:practise", "0")
	s.jobs.update(true)
	t.equal(c.current("gord"), "wren_late", "practised")
	c.on_talk("wren")
	t.equal(c.fact("wren_late"), 0, "Wren wants two hearts first")
	s.debug_set_hearts("wren", 2)
	c.on_talk("wren")
	s.jobs.update(true)
	t.equal(c.current("gord"), "gord_coffee", "she'll stay open late")
	_at(s, 0, 21, 20 * 60)
	t.check(s.town.is_open("percolator", 20 * 60), "the Percolator open late on the full moon")
	c.talk_gord()
	t.check(c.gord_along, "he walks with you")
	s.in_town = true
	s.town_inside = ""
	c.on_enter_room("percolator")
	s.jobs.update(true)
	t.check(s.jobs.is_done("cj_gord"), "a coffee, black")
	t.check(c.gord_in_cafe(20 * 60), "by the window on full-moon evenings")
	t.check(BadgesView.creature_badges(s).any(func(b: Array) -> bool: return b[0] == "gord_coffee" and bool(b[1])), "the badge")


func test_secret_hint_or_public(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	c.set_choice("gord", "public")
	t.check(c.visitor_mult() > 1.0, "public brings more visitors")
	t.check(c.shy_mult("gord_moose") > 1.0, "and makes him shyer")
	t.check(c.change_options().is_empty(), "no change in the same season")
	s.clock.season += 1
	var opts := c.change_options()
	t.equal(opts.size(), 1, "one step at a time: public can only go to hint")
	c.on_choice("creature_change", str(opts[0]["id"]))
	t.equal(str(c.choice["gord"]), "hint", "down to hint")
	t.check(c.brochure_lines().size() == 1, "a line on the brochure")
	t.check(c.shown_count() == 1, "cryptid hunters can come")


func test_calendar_events_once_heard(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.town.calendar(2)[6]["events"].is_empty(), "not heard of yet")
	s.clock.season = 1
	s.clock.day = 25
	s.creatures.on_reading()
	t.check(not (s.town.calendar(2)[6]["events"] as Array).is_empty(), "Esme mentions the deer at the outlook")
	s.creatures.on_chat("rosa")
	t.check(not (s.town.calendar(1)[13]["events"] as Array).is_empty(), "midsummer heard in a chat")


func test_the_second_pet(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.pet.choose("dog")
	_at(s, 2, 5, 9 * 60)
	t.check(not s.creatures.spare_waiting, "not before winter")
	_at(s, 3, 15, 9 * 60)
	t.check(s.creatures.spare_waiting, "in winter, the other animal waits at a cabin")
	s.pet.adopt_spare()
	t.equal(str(s.pet.spare["kind"]), "cat", "the cat")
	s.pet.swap()
	t.equal(s.pet.kind, "cat", "X swaps: the cat comes along")
	t.equal(str(s.pet.spare["kind"]), "dog", "the dog stays home")
	var d := s.pet.to_dict()
	s.pet.from_dict(d)
	t.equal(str(s.pet.spare["kind"]), "dog", "both saved")


func test_creatures_are_saved(t: TestCase) -> void:
	var s := TestCase.new_session()
	var c := s.creatures
	c.points["gord"] = 130
	c.facts["gord_met"] = 1
	c.set_choice("jackalopes", "secret")
	c.burrows = [Vector2i(3, 4)]
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2 := TestCase.new_session()
	s2.from_dict(d)
	t.equal(s2.creatures.hearts("gord"), 1, "hearts")
	t.equal(s2.creatures.fact("gord_met"), 1, "facts")
	t.equal(str(s2.creatures.choice["jackalopes"]), "secret", "the choice")
	t.equal(s2.creatures.burrows.size(), 1, "burrows")


func test_every_5b_picture_is_in(t: TestCase) -> void:
	for p: String in ["creature_gord_moose", "npc_gord", "npc_gord_dressed", "portrait_gord_neutral", "portrait_gord_happy", "obj_gord_meadow_sign",
			"ui_paw_heart_full", "ui_paw_heart_empty", "job_type_creature", "job_pic_creature", "stamp_secret", "stamp_hint", "stamp_public",
			"brochure_creature", "ui_cal_moon", "ui_cal_event", "hud_moon", "sky_aurora", "sky_full_moon", "obj_burrow", "obj_trail_food",
			"obj_offering_stone", "fortune_card_aurora", "chip_aurora", "badge_gord_coffee", "item_old_bell", "log_creature_gift"]:
		t.check(Art.has_picture(p), p)
