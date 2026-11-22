extends RefCounted
## 0.6.7: the road to Humdrum opens once the ranger has found their feet in
## the park: after the first job, or by day 4 whatever happens, with a letter
## from the chief.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	return s


func _try_gate(s: GameSession) -> void:
	s.use_gate()


func test_the_road_is_closed_at_first(t: TestCase) -> void:
	var s := _session()
	t.check(not s.town_open, "a new game starts with the road closed")
	var said := []
	s.message.connect(func(m: String) -> void: said.append(m))
	_try_gate(s)
	t.check(not s.in_town, "the gate does not lead to town yet")
	t.check(said.has(s.content.text("msg_town_road_closed")), "the gate says the road is closed")


func test_the_first_job_opens_it_next_morning(t: TestCase) -> void:
	var s := _session()
	s.jobs.debug_finish("station_shipshape")
	t.check(not s.town_open, "not the same day")
	s.clock.start_next_day()
	t.check(s.town_open, "open the morning after the first job")
	var texts := s.park.letters.map(func(l: Dictionary) -> String: return str(l["text"]))
	t.check(texts.has(s.content.text("letter_town_opens")), "with a letter from the chief")
	_try_gate(s)
	t.check(s.in_town, "and the gate leads to town")


func test_day_four_opens_it_anyway(t: TestCase) -> void:
	var s := _session()
	for i in 2:
		s.clock.start_next_day()
	t.check(not s.town_open, "still closed on day 3")
	s.clock.start_next_day()
	t.check(s.town_open, "open on day 4 without the job")
	var letters := s.park.letters.filter(func(l: Dictionary) -> bool: return str(l["text"]) == s.content.text("letter_town_opens"))
	s.clock.start_next_day()
	var again := s.park.letters.filter(func(l: Dictionary) -> bool: return str(l["text"]) == s.content.text("letter_town_opens"))
	t.equal(again.size(), letters.size(), "the letter comes once")


func test_saves_keep_it_and_old_saves_are_open(t: TestCase) -> void:
	var s := _session()
	var d := s.to_dict()
	t.equal(d["ranger"]["town_open"], false, "a save remembers the road closed")
	var s2 := _session()
	s2.from_dict(d)
	t.check(not s2.town_open, "and loads it closed")
	(d["ranger"] as Dictionary).erase("town_open")
	s2.from_dict(d)
	t.check(s2.town_open, "a save from before 0.6.7 has the road open")


func test_debug_can_still_go_to_town(t: TestCase) -> void:
	var s := _session()
	s.enter_town()
	t.check(s.in_town, "enter_town (the debug panel's way in) is not gated")
