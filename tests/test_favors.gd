extends RefCounted
## Phase 4, 4a step 7: Townsfolk Favors.


func _town(s: GameSession) -> void:
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true


func _fill(s: GameSession, item: String, n: int) -> void:
	s.backpack.add(item, n)


func _hand(s: GameSession, person: String, item: String) -> void:
	var want := s.jobs.wants(person, item)
	s._hand_over(person, item, want)


func test_each_favor_is_well_made(t: TestCase) -> void:
	var s := TestCase.new_session()
	var per := {}
	for r: Dictionary in s.content.rows("town_favors"):
		per[str(r["from"])] = int(per.get(str(r["from"]), 0)) + 1
		t.check(str(r["offer"]) in ["board", "ask", "mail"], "%s comes by board, asking or mail" % r["id"])
	t.equal(s.content.rows("town_favors").size(), 24, "24 hand-written favors")
	for r: Dictionary in s.content.rows("townsfolk"):
		t.equal(int(per.get(str(r["id"]), 0)), 2, "two from %s" % r["id"])


func test_the_board_hands_out_its_notes(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.favors.morning()
	t.check(s.favors.notes_up() >= 3, "notes are pinned up: %d" % s.favors.notes_up())
	var text := s.favors.read_board()
	t.check(text.length() > 0, "reading the board: %s" % text)
	t.equal(s.favors.notes_up(), 0, "the notes are taken down")
	var tpl := 0
	var hand := 0
	for k: String in s.jobs.order:
		if s.jobs.is_active(k) and str(s.jobs.def(k)["type"]) == "townsfolk":
			if bool(s.jobs.known[k]["tpl"]):
				tpl += 1
			else:
				hand += 1
	t.check(tpl >= 3, "the board keeps at least three template favors: %d" % tpl)
	t.check(hand >= 1, "and hand-written ones")


func test_handing_over_finishes_a_favor_and_gives_friendship(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.jobs.add("gus_planks", "board")
	_fill(s, "planks", 10)
	var before := s.town.points("gus")
	var gifts := s.town.gifts_left("gus")
	_hand(s, "gus", "planks")
	s.jobs.update(true)
	t.check(s.jobs.is_done("gus_planks"), "ten planks for Gus: done")
	t.equal(s.backpack.count("planks"), 0, "the planks are handed over")
	t.equal(s.town.points("gus") - before, 120 + s.tuning.integer("friendship.talk_points"), "and Gus's friendship grows by 120, and handing over counts as talking (tracker #63)")
	t.equal(s.town.gifts_left("gus"), gifts, "it doesn't count as one of the week's gifts")


func test_steps_count_in_order(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.jobs.add("wren_rumor_run", "board")
	s.jobs.event("talk", {"person": "wren"})
	t.check(not bool(s.jobs.check("wren_rumor_run", 2)["done"]), "telling Wren before asking Bev counts for nothing")
	s.jobs.event("talk", {"person": "bev"})
	s.jobs.event("talk", {"person": "agnes"})
	s.jobs.event("talk", {"person": "wren"})
	s.jobs.update(true)
	t.check(s.jobs.is_done("wren_rumor_run"), "Bev, then Agnes, then Wren: done")


func test_asking_and_not_now(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	t.equal(s.favors.ask_offer("teo"), "teo_notebook", "Teo asks about his notebook")
	s.favors.answer("teo_notebook", false)
	t.equal(s.favors.ask_offer("teo"), "", "not now: he doesn't ask again this week")
	for i in 7:
		s.clock.start_next_day(s.tuning.integer("time.day_start_minute"))
	t.equal(s.favors.ask_offer("teo"), "teo_notebook", "a week on he asks again")
	s.favors.answer("teo_notebook", true)
	t.check(s.jobs.is_active("teo_notebook"), "yes: it's on the clipboard")
	var b: Dictionary = s.jobs.known["teo_notebook"]["blanks"]
	t.check(b.has("lost_x"), "the notebook is out on the trail")
	var tile := Vector2i(int(b["lost_x"]), int(b["lost_y"]))
	t.check(s.piles.has(tile) and (s.piles[tile] as Inventory).count("song_notebook") == 1, "lying where it fell")
	t.check(s.jobs.step_pos("teo_notebook", 0) != Vector2.INF, "with a mark near it on the map")
	(s.piles[tile] as Inventory).remove("song_notebook", 1)
	s.backpack.add("song_notebook", 1)
	s.jobs.update(true)
	t.check(bool(s.jobs.check("teo_notebook", 0)["done"]), "found")
	_hand(s, "teo", "song_notebook")
	s.jobs.update(true)
	t.check(s.jobs.is_done("teo_notebook"), "and given back: done")


func test_the_parcel_and_the_mailbox(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.favors.morning()
	t.check(s.favors.mailbox.has("lyle_parcel"), "the mayor's letter comes to the mailbox")
	var text := s.favors.read_mail()
	t.check(s.jobs.is_active("lyle_parcel") and text.contains(s.content.text("fv_lyle_parcel")), "reading it takes the favor on")
	s.enter_town()
	s.enter_town_room("town_hall")
	t.equal(s.backpack.count("parcel"), 1, "the post office hands over the parcel")
	s.leave_town_room()
	_hand(s, "agnes", "parcel")
	s.jobs.update(true)
	t.check(s.jobs.is_done("lyle_parcel"), "delivered to Agnes: done")


func test_helping_at_a_shop(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.jobs.add("gus_hand", "asked")
	for i in 6:
		s.jobs.event("help", {"place": "carpentry", "n": 10})
	s.jobs.update(true)
	t.check(s.jobs.is_done("gus_hand"), "an hour at the carpentry: done")


func test_agnes_only_copies_the_page(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.jobs.add("agnes_archive", "asked")
	_fill(s, "journal_page_one", 1)
	_hand(s, "agnes", "journal_page_one")
	s.jobs.update(true)
	t.check(s.jobs.is_done("agnes_archive"), "shown to Agnes: done")
	t.equal(s.backpack.count("journal_page_one"), 1, "and the page comes back")


func test_favors_save_and_load(t: TestCase) -> void:
	var s := TestCase.new_session()
	_town(s)
	s.favors.morning()
	s.favors.answer("teo_notebook", false)
	var s2 := TestCase.new_session()
	s2.from_dict(s.to_dict())
	t.equal(s2.favors.notes_up(), s.favors.notes_up(), "the board's notes are saved")
	t.check(s2.favors.declined.has("teo_notebook"), "and who was told not now")
