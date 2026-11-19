extends RefCounted
## The jobs rebuild (jobs spec, 19 November 2026): the engine, steps that stay
## done, finishing and rewards, the opening, gaps of one screen, trail travel
## as a reward, older saves, templates, the season's turn and the pinned note.


func _tidy_station(s: GameSession) -> void:
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)


## Plays Get the Station Shipshape as a player would.
func _shipshape(s: GameSession) -> void:
	_tidy_station(s)
	s.backpack.add("axe")
	s.structures.chests["ranger_station"].remove("axe", 1)
	s.jobs.work_spot("station_branch")
	s.jobs.work_spot("station_can")
	var m := Vector2i(s.jobs.spot_pos("gate_marker"))
	for t in [m, m + Vector2i(1, 0), m + Vector2i(-1, 0), m + Vector2i(0, -1)]:
		if s.park.place_problem(t) == "" and s.park.put_thing(t, "trash_can"):
			s.backpack.remove("trash_can", 1)
			break
	s.jobs.update(true)


## Puts up a sign naming a place on the nearest good spot beside the trail.
func _sign_near(s: GameSession, at: Vector2, place: String) -> bool:
	for r in range(1, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := Vector2i(at) + Vector2i(dx, dy)
				if s.place_problem(t, "trail_sign") == "" and s.debug_put_up(t, "trail_sign", place):
					return true
	return false


func test_a_new_game_offers_only_the_first_job(t: TestCase) -> void:
	var s := TestCase.new_session()
	var active: Array[String] = []
	for k: String in s.jobs.order:
		if s.jobs.is_active(k):
			active.append(k)
	t.equal(active, ["station_shipshape"] as Array[String], "a new game offers only Get the Station Shipshape")
	t.check(not s.jobs.unlocks.has("catalog"), "the catalog waits for the station to be shipshape")
	t.equal(s.jobs.shown_job(), "", "nothing worked on yet")


func test_the_first_job_teaches_and_pays(t: TestCase) -> void:
	var s := TestCase.new_session()
	var k := "station_shipshape"
	t.equal(s.jobs.next_step(k), 0, "the first step is tidying")
	_tidy_station(s)
	t.check(bool(s.jobs.check(k, 0)["done"]), "three spots tidied: the station is tidy")
	t.check(s.jobs.shown_job() == k, "the job last worked on shows on the note")
	var wallet := s.park.money.wallet
	var done_sigs := [0]
	s.jobs.job_done.connect(func(_k: String) -> void: done_sigs[0] += 1)
	_shipshape(s)
	t.check(s.jobs.is_done(k), "branch cleared and the trash can set out: done")
	t.equal(done_sigs[0], 1, "job_done fired once")
	t.equal(s.park.money.wallet, wallet + 50, "it paid $50")
	t.check(s.jobs.unlocks.has("catalog"), "and gave the supply catalog")
	for lm in ["test_cabin", "scenic_outlook", "kettle_pond"]:
		t.check(s.rumors.has(lm), "a rumor of %s" % lm)
	for j in ["open_cabin", "open_outlook", "open_pond", "spruce_gate", "point_fork"]:
		t.check(s.jobs.is_active(j), "%s is on the clipboard" % j)
	var card := s.jobs.take_card_to_show()
	t.equal(str(card.get("kind", "")), "done", "a finishing card waits")
	t.check((card["unlocked"] as Array).size() >= 5, "it lists what's new on the clipboard")
	t.check(not (card["map"] as Array).is_empty(), "and the map has changes to show")
	# The first choice: five jobs of three types.
	var types := {}
	for j: String in s.jobs.order:
		if s.jobs.is_active(j):
			types[s.jobs.def(j)["type"]] = true
	t.check(types.size() >= 2, "a real choice of different kinds of job")


func test_rewards_once_only_across_a_reload(t: TestCase) -> void:
	var s := TestCase.new_session()
	_shipshape(s)
	s.jobs.update(true)
	var wallet := s.park.money.wallet
	s.save_game()
	var s2 := TestCase.new_session()
	s2.save_path = s.save_path
	t.equal(s2.load_game(), "", "loads")
	t.check(s2.jobs.is_done("station_shipshape"), "still done after a reload")
	s2.jobs.update(true)
	t.equal(s2.park.money.wallet, wallet, "nothing paid twice")
	t.equal(s2.jobs.to_dict(), s.jobs.to_dict(), "the jobs save exactly")


func test_steps_that_stay_and_steps_that_break(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("reopen_pond_trail", "given")
	var k := "reopen_pond_trail"
	var d := s.jobs.def(k)
	var dig := -1
	for i in (d["steps"] as Array).size():
		if d["steps"][i]["kind"] == "dig" and d["steps"][i]["gap"] == "pond_gap_1":
			dig = i
	t.check(dig >= 0, "the pond trail job digs its first gap")
	var undone := [0]
	s.jobs.step_undone.connect(func(_k: String, _i: int) -> void: undone[0] += 1)
	var gp := s.jobs.gap("pond_gap_1")
	t.check(not bool(s.jobs.check(k, dig)["done"]), "not dug at the start")
	for p: Array in gp["tiles"]:
		s.debug_dig(Vector2i(int(p[0]), int(p[1])))
	s.jobs.update(true)
	t.check(bool(s.jobs.check(k, dig)["done"]), "dug: the gap's ends are joined")
	var mid: Array = gp["tiles"][(gp["tiles"] as Array).size() / 2]
	s.debug_dig(Vector2i(int(mid[0]), int(mid[1])), false)
	s.jobs.update(true)
	t.check(not bool(s.jobs.check(k, dig)["done"]), "a dug step that breaks comes undone")
	t.equal(undone[0], 1, "step_undone fired once")
	s.debug_dig(Vector2i(int(mid[0]), int(mid[1])))
	# Clearing (stays done) is recorded once.
	for p: Array in s.world.meta["trail_job_points"]["pond_trunks"]:
		s.debug_clear_obstacle(Vector2i(int(p[0]), int(p[1])))
	s.jobs.update(true)
	var clear_i := 1
	t.check(bool(s.jobs.check(k, clear_i)["done"]), "trunks sawn")
	for p: Array in s.world.meta["trail_job_points"]["pond_trunks"]:
		s.debug_clear_obstacle(Vector2i(int(p[0]), int(p[1])), false)
	s.jobs.update(true)
	t.check(bool(s.jobs.check(k, clear_i)["done"]), "a step that stays done never comes undone")


func test_trail_gaps_are_one_screen(t: TestCase) -> void:
	var s := TestCase.new_session()
	var most := s.tuning.num("jobs.largest_gap_tiles")
	var gaps: Dictionary = s.world.meta["trail_job_gaps"]
	t.equal(gaps.size(), 6, "six gaps: two on the pond trail, two on the stake trail, two on the road")
	var grounds: Array = s.tuning.value("sites.reach_grounds")
	for name: String in gaps:
		var g: Dictionary = gaps[name]
		var a := Vector2i(int(g["a"][0]), int(g["a"][1]))
		var b := Vector2i(int(g["b"][0]), int(g["b"][1]))
		t.check(Vector2(a).distance_to(Vector2(b)) <= most, "%s is no wider than a screen" % name)
		t.check(grounds.has(s.world.ground_at(a)) and grounds.has(s.world.ground_at(b)), "%s has old trail at both ends" % name)
		t.check(not s.trail_joins(a, b, 6), "%s really is a gap" % name)


func test_opening_a_joined_site_gives_trail_travel(t: TestCase) -> void:
	var s := TestCase.new_session()
	_shipshape(s)
	ParkHelpers.open_route(s, "cabin")
	s.sites_found["old_cabin"] = true
	s.map.mark_landmark("test_cabin")
	s.debug_repair_all("test_cabin", true)
	s.debug_put_up(Vector2i(s.site_door("old_cabin")) + Vector2i(3, 2), "trail_sign", "test_cabin")
	s.jobs.update(true)
	t.check(s.site_reached("old_cabin"), "the cabin is joined")
	s.backpack.add("shovel")
	s.jobs.update(true)
	t.check(s.site_ready("old_cabin"), "ready to open")
	s.open_site("old_cabin")
	t.check(s.jobs.is_done("open_cabin"), "opening it finishes its job")
	t.check(s.jobs.travel_open.has("old_cabin"), "and gives trail travel to it (tracker #15)")
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 1)
	var ids := s.travel_options().map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("old_cabin"), "the map offers the walk from the station, first time")
	t.check(s.jobs.is_active("reopen_pond_trail"), "it leads on to Reopen the Pond Trail")


func test_an_older_save_is_converted_and_paid(t: TestCase) -> void:
	var s := TestCase.new_session()
	# The outlook opened the long way, in the world itself.
	ParkHelpers.open_route(s, "outlook")
	s.sites_found["outlook"] = true
	s.map.mark_landmark("scenic_outlook")
	_sign_near(s, s.site_door("outlook"), "scenic_outlook")
	t.check(s.site_ready("outlook"), "the outlook is ready to open")
	s.open_site("outlook")
	var d := s.to_dict()
	d.erase("jobs2")
	var s2 := TestCase.new_session()
	var wallet := s2.park.money.wallet
	s2.from_dict(d)
	t.check(s2.jobs.is_done("open_outlook"), "a site already open: its job finished on load")
	t.check(s2.jobs.unlocks.has("catalog_bench"), "and its rewards given")
	t.check(s2.park.money.wallet > wallet - 1, "paid")
	t.check(s2.jobs.is_active("station_shipshape"), "the first job is offered as normal")
	var card := s2.jobs.take_card_to_show()
	t.equal(str(card.get("kind", "")), "away", "one \"While you were away...\" card")


func test_templates_fit_the_park(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.jobs.candidates("a_seat").is_empty(), "no open site: no bench job")
	ParkHelpers.ready_site(s, "outlook")
	s.debug_open_site("outlook")
	t.check(not s.jobs.candidates("a_seat").is_empty(), "an open site with no bench: a bench job fits")
	var c: Array = s.jobs.candidates("a_seat")
	var key := s.jobs.draw("a_seat", c[0])
	t.check(key != "" and s.jobs.is_active(key), "drawn")
	t.equal(s.jobs.draw("a_seat", c[0]), "", "never twice at the same place")
	t.check(s.jobs.def(key)["name"].contains(s.content.text("landmark_scenic_outlook")), "its blanks are filled")


func test_the_season_turn_retires_untouched_templates(t: TestCase) -> void:
	var s := TestCase.new_session()
	ParkHelpers.ready_site(s, "outlook")
	s.debug_open_site("outlook")
	var key := s.jobs.draw("a_seat", s.jobs.candidates("a_seat")[0])
	_shipshape(s)
	s.debug_skip_season()
	t.check(not s.jobs.is_active(key), "an untouched template job retires at the season's turn")
	t.check(s.jobs.is_active("open_cabin"), "exploring jobs stay")
	var found := false
	for c: Dictionary in s.jobs.cards:
		if str(c["kind"]) == "season":
			found = true
	t.check(found, "the season's card is waiting")


func test_the_pinned_note_follows_the_rules(t: TestCase) -> void:
	var s := TestCase.new_session()
	_shipshape(s)
	t.equal(s.jobs.shown_job(), "", "the finished job leaves the note")
	s.jobs.toggle_pin("open_pond")
	t.equal(s.jobs.shown_job(), "open_pond", "a pinned job stays pinned")
	s.jobs.work_spot("station_papers")
	t.equal(s.jobs.shown_job(), "open_pond", "even when other work is done")
	s.jobs.toggle_pin("open_pond")
	t.equal(s.jobs.pinned, "", "unpinned")


func test_the_clipboard_sorts_and_never_overflows(t: TestCase) -> void:
	var s := TestCase.new_session()
	_shipshape(s)
	var keys := s.jobs.list("current")
	var last := -1
	for k in keys:
		var o := Jobs.TYPE_ORDER.find(s.jobs.def(k)["type"])
		t.check(o >= last, "grouped by type in order")
		last = o
	t.equal(s.jobs.list("done"), ["station_shipshape"] as Array[String], "the done tab")
	var cb := ClipboardScreen.new()
	cb.setup(s)
	cb.open()
	for tab in ClipboardScreen.TABS:
		cb.set_tab(tab)
		t.check(cb._list_scroll.get_rect().end.x <= ClipboardScreen.FRAME.end.x and cb._detail_scroll.get_rect().end.x <= ClipboardScreen.FRAME.end.x, "%s: nothing past the paper's edge" % tab)
	cb.free()


func test_secrets_stay_out_of_the_debug_list(t: TestCase) -> void:
	var s := TestCase.new_session()
	for n: Dictionary in s.content.rows("noticeables"):
		s.jobs.add(str(n["job"]), "noticed")
	var lines := "\n".join(s.jobs.debug_lines(false))
	for n: Dictionary in s.content.rows("noticeables"):
		t.check(not lines.contains(str(n["job"])), "a noticed job is hidden without spoilers")


func test_a_job_done_by_someone_else_pays_half(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_build("gate_bathroom")
	s.debug_set_clean("gate_bathroom", 30.0)
	var c := s.jobs.candidates("clean_up")
	t.check(not c.is_empty(), "a grubby bathroom: a clean-up job fits")
	var key := s.jobs.draw("clean_up", c[0])
	var wallet := s.park.money.wallet
	s.debug_set_clean("gate_bathroom", 100.0)
	s.jobs.update(true)
	t.check(s.jobs.is_done(key), "cleaned by someone else: the job finishes on its own")
	t.equal(s.park.money.wallet, wallet + roundi(15 * s.tuning.num("jobs.half_pay_share")), "and pays half")
