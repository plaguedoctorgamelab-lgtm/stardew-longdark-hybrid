extends RefCounted
## Phase 3, steps 7 to 10: upkeep and mess, troll badgers, staff, lost
## visitors, the suggestion box, the Chief, saves and the unattended park.


func _park() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.tomorrow.assign(["clear", "clear", "clear"])
	for id: String in ["old_cabin", "outlook"]:
		ParkHelpers.ready_site(s, id)
	return s


func _can_near_gate(s: GameSession) -> Vector2i:
	var g := s.park.gate_node()
	for dy in range(2, 6):
		for dx in range(3, 9):
			var c := g + Vector2i(dx, dy)
			if s.park.place_problem(c) == "":
				s.park.put_thing(c, "trash_can")
				return c
	return Vector2i(-1, -1)


func test_bathrooms_get_dirty_and_clean(t: TestCase) -> void:
	var s := _park()
	s.debug_build("gate_bathroom")
	s.tuning.set_value("visitors.bathroom_use_share", 1.0)
	s.park.sim_minute = 480.0
	s.park.spawn("day_hiker", 2)
	t.equal(float(s.park.pads["gate_bathroom"]["clean"]), 92.0, "two visits, 4 each")
	s.debug_set_clean("gate_bathroom", 30)
	t.equal(s.park.bath_state("gate_bathroom"), "grubby", "below 40 is grubby")
	s.debug_set_clean("gate_bathroom", 10)
	t.equal(s.park.bath_state("gate_bathroom"), "filthy", "below 15 is filthy")
	s.park.spawn("day_hiker", 2)
	t.equal(float(s.park.pads["gate_bathroom"]["clean"]), 10.0, "visitors avoid a filthy bathroom")
	var m0 := s.clock.minute
	var e0 := s.needs.energy
	s.clean_bathroom("gate_bathroom")
	t.equal(float(s.park.pads["gate_bathroom"]["clean"]), 100.0, "spotless again")
	t.equal(s.clock.minute - m0, 20, "20 minutes")
	t.near(e0 - s.needs.energy, 10.0, 0.5, "10 energy")


func test_trash_cans_and_litter(t: TestCase) -> void:
	var s := _park()
	var can := _can_near_gate(s)
	t.check(can.x >= 0, "a can by the gate")
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	p["trash"] = 5
	p["pos"] = Vector2(s.park.gate_node()) + Vector2(0.5, 0.5)
	s.park._drop_trash(p, "gate")
	t.equal(int(s.park.things[can]["trash"]), 5, "trash in the can")
	s.debug_set_can(can, 20)
	p["trash"] = 40
	s.tuning.set_value("upkeep.litter_chance", 1.0)
	s.park._drop_trash(p, "gate")
	t.check(s.park.litter.size() > 0, "a full can: trash dropped as litter")
	t.equal(int(s.park.things[can]["trash"]), 20, "a full can takes no more")
	var m0 := s.clock.minute
	s.empty_can(can)
	t.equal(int(s.park.things[can]["trash"]), 0, "emptied")
	t.equal(s.clock.minute - m0, 10, "10 minutes")
	var lt: Vector2i = s.park.litter.keys()[0]
	var e0 := s.needs.energy
	m0 = s.clock.minute
	s.pick_litter(lt)
	t.check(not s.park.litter.has(lt), "litter picked up")
	t.equal(s.clock.minute, m0, "no time")
	t.near(e0 - s.needs.energy, 1.0, 0.01, "1 energy")


func test_lost_belongings(t: TestCase) -> void:
	var s := _park()
	s.tuning.set_value("upkeep.belonging_chance", 1.0)
	var c := s.park.gate_node() + Vector2i(3, 3)
	s.park.litter[c] = 0
	var found := s.park.pick_litter(c)
	t.check(found != "", "a lost belonging")
	t.equal(s.park.notes.size(), 1, "logged in the notebook")


func test_mess_and_badgers(t: TestCase) -> void:
	var s := _park()
	s.tuning.set_value("badgers.chance", 1.0)
	for i in 8:
		s.park.litter[s.park.gate_node() + Vector2i(3 + i, 3)] = 0
	t.check(s.park.messy("gate"), "the gate is messy")
	s.debug_skip_day()
	t.equal(s.park.badgers.size(), 0, "no badger after one night")
	var signs_before := JSON.stringify(s.land_to_dict()["placed"])
	s.debug_skip_day()
	t.equal(s.park.badgers.size(), 1, "one comes after two nights of mess")
	s.debug_skip_day()
	t.equal(s.park.badgers.size(), 1, "never two at a site")
	t.equal(JSON.stringify(s.land_to_dict()["placed"]), signs_before, "badgers never touch a sign")
	s.shoo_badger(0)
	t.equal(s.park.badger_near(Vector2(s.park.badgers[0]["tile"]), 3.0), -1, "shooed for the day")
	s.debug_skip_day()
	t.check(s.park.badgers[0]["away_until"] <= s.clock.absolute_day(), "back the next day, the mess remains")
	for tile: Vector2i in s.park.litter.keys():
		s.pick_litter(tile)
	t.equal(s.park.badgers.size(), 0, "clearing the mess sends it off for good")


func test_never_more_than_three_badgers(t: TestCase) -> void:
	var s := _park()
	for place: String in ["gate", "old_cabin", "outlook", "kettle_pond"]:
		s.debug_send_badger(place)
	t.equal(s.park.badgers.size(), 3, "three at most")


func test_badger_mischief(t: TestCase) -> void:
	var s := _park()
	s.debug_build("gate_bathroom")
	s.debug_build("gate_picnic")
	var can := _can_near_gate(s)
	s.debug_set_can(can, 10)
	s.debug_send_badger("gate")
	var b: Dictionary = s.park.badgers[0]
	t.check(s.park.do_mischief(b, "tip_can"), "a can tipped")
	t.check(bool(s.park.things[can]["tipped"]), "tipped over")
	t.equal(s.park.litter.size(), 6, "six pieces of litter")
	t.check(s.park.do_mischief(b, "nap_bathroom"), "a nap")
	t.check(s.park._badger_napping("gate_bathroom"), "the bathroom is closed")
	s.tuning.set_value("visitors.bathroom_use_share", 1.0)
	s.park.sim_minute = 480.0
	s.park.spawn("day_hiker", 2)
	t.equal(float(s.park.pads["gate_bathroom"]["clean"]), 100.0, "nobody can use it")
	s.clean_bathroom("gate_bathroom")
	t.check(not s.park._badger_napping("gate_bathroom"), "shooing it opens the bathroom")
	t.check(s.park.do_mischief(b, "raid_picnic"), "a picnic raided")
	t.check(s.park.raid_today.has("gate"), "today, at the gate")
	t.check(s.park.do_mischief(b, "dig_trail"), "a hole dug")
	var hole: Vector2i = s.park.diggings.keys()[0]
	t.equal(s.world.ground_at(hole), "dug_earth", "the trail is dug up")
	t.check(not s.park.net.has(hole), "and off the network")
	s.outdoor_pos = Vector2(hole) + Vector2(0.5, 1.5)
	s.facing = GameSession.FACING_UP
	s.debug_add_item("shovel")
	s.dig()
	t.equal(s.world.ground_at(hole), "trail", "the shovel fills it in")
	t.check(s.park.net.has(hole), "back on the network")


func test_lost_and_found(t: TestCase) -> void:
	var s := _park()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	s.park.advance_to(540.0)
	var heard := []
	s.park.note.connect(func(x: String) -> void: heard.append(x))
	t.check(s.debug_lose_party(), "a party is lost")
	t.check(not heard.is_empty(), "announced")
	t.check(not s.lost_hint().is_empty(), "a circle on the map")
	t.check(s.use_radio()[-1].contains(s.park.party_name(p)), "on the radio")
	var p2 := s.park.spawn("day_hiker", 1)
	p2["state"] = "walk"
	t.check(not s.park.lose(p2, s.park.gate_node()), "only one lost at a time")
	s.outdoor_pos = p["pos"]
	var w := s.park.money.wallet
	var xp := s.skills.progress("surveying")
	s.interact()
	t.check(s.park.lost.is_empty(), "found")
	t.check(s.park.money.wallet - w >= 20 and s.park.money.wallet - w <= 50, "a tip of $20 to $50")
	t.check(s.skills.progress("surveying") != xp, "Surveying experience")
	t.equal(p["state"], "walk", "they make their way back")
	t.check(not p["lost"], "no harm done")


func test_unfound_party_turns_up_at_6(t: TestCase) -> void:
	var s := _park()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	s.park.advance_to(540.0)
	s.debug_lose_party()
	s.sleep()
	t.check(s.park.party(int(p["id"])).is_empty(), "home safe by morning")
	t.check(s.park.lost.is_empty(), "nobody lost")


func test_staff(t: TestCase) -> void:
	var s := _park()
	s.debug_build("gate_bathroom")
	s.debug_set_clean("gate_bathroom", 20)
	var cust := ""
	var crew := ""
	s.park.board = s.content.ids("staff_people")
	for pid: String in s.park.board.duplicate():
		var role: String = s.content.row("staff_people", pid)["suits"]
		if role == "custodian" and cust == "":
			cust = pid
			s.park.hire(pid)
		elif role == "trail_crew" and crew == "":
			crew = pid
			s.park.hire(pid)
	t.equal(s.park.staff.size(), 2, "two hired")
	t.check((s.park.staff[0]["assigned"] as Array).has("gate_bathroom"), "the custodian takes the bathroom")
	for i in 3:
		s.park.litter[s.park.gate_node() + Vector2i(3 + i, 4)] = 0
	s.debug_skip_day()
	t.equal(float(s.park.pads["gate_bathroom"]["clean"]), 100.0, "the custodian cleaned it")
	t.equal(s.park.litter.size(), 0, "the trail crew picked up the litter")
	s.debug_money(-s.park.money.wallet)
	s.park._pay_wages()
	t.equal(s.park.money.wallet, 0, "no debt")
	t.check(bool(s.park.staff[0]["off"]) and bool(s.park.staff[1]["off"]), "unpaid staff take the week off")
	s.debug_set_clean("gate_bathroom", 20)
	s.debug_skip_day()
	t.check(float(s.park.pads["gate_bathroom"]["clean"]) <= 20.0, "and do no work")
	t.equal(s.park.staff.size(), 2, "but nobody quits")
	s.debug_money(1000)
	s.park._pay_wages()
	t.check(not bool(s.park.staff[0]["off"]) and not bool(s.park.staff[1]["off"]), "paid, they come back")
	t.check(s.park.let_go(cust) != "", "let go with a kind word")


func test_cards_come_from_what_happened(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_skip_day()
	t.equal(s.park.cards.size(), 0, "no visitors, no cards")
	s.park.events = [{"type": "bench", "place": "outlook"}, {"type": "want_picnic", "place": "old_cabin"}]
	s.debug_skip_day()
	t.equal(s.park.cards.size(), 2, "one card for each happening")
	for c: Dictionary in s.park.cards:
		var ok := false
		for r: Dictionary in s.content.rows("suggestion_cards"):
			if r["event"] in ["bench", "want_picnic"] and s.content.text(r["text"], {"site": s.park.place_name("old_cabin")}) == c["text"]:
				ok = true
			if r["event"] in ["bench", "want_picnic"] and s.content.text(r["text"], {"site": s.park.place_name("outlook")}) == c["text"]:
				ok = true
		t.check(ok, "card '%s' matches its event" % c["text"])
	t.equal(s.read_box(), "\n\n".join(s.park.cards.map(func(c: Dictionary) -> String: return c["text"])), "the box reads them")
	t.check(s.park.unread_cards().is_empty(), "read")


func test_the_chief_writes(t: TestCase) -> void:
	var s := _park()
	s.debug_skip_to_week_end()
	t.check(not s.park.letters.is_empty(), "a weekly report on the seventh morning")
	t.check(s.park.letters.any(func(l: Dictionary) -> bool: return str(l["text"]).begins_with("WEEKLY REPORT")), "it is the report")
	s.debug_build("gate_bathroom")
	s.debug_set_clean("gate_bathroom", 0)
	var grumbles := 0
	for i in 14:
		var n := s.park.letters.size()
		s.debug_skip_day()
		for l: Dictionary in s.park.letters.slice(n):
			if str(l["text"]).contains(s.park.place_name("gate")) and str(l["text"]).begins_with("Ranger, I've had a letter"):
				grumbles += 1
	t.check(grumbles >= 1, "a grumble about the filthy bathroom")
	t.check(grumbles <= 2, "at most one a week (%d in two weeks)" % grumbles)
	var t2 := s.read_note_board()
	t.check(t2.contains("WEEKLY REPORT"), "letters are on the station's note board")


func test_full_park_saves_exactly(t: TestCase) -> void:
	var s := _park()
	s.clock.season = 1
	s.debug_build("gate_bathroom")
	_can_near_gate(s)
	s.debug_send_badger("gate")
	s.debug_skip_day()
	s.park.advance_to(700.0)
	s.save_game()
	var saved := JSON.stringify(s.to_dict())
	var again := GameSession.new()
	again.save_path = s.save_path
	t.equal(again.load_game(), "", "loaded")
	t.equal(JSON.stringify(again.to_dict()), saved, "every visitor, badger and thing as it was")
	t.check(again.park.parties.size() > 0, "with visitors in it")


func test_unattended_month(t: TestCase) -> void:
	var s := _park()
	s.debug_build("gate_bathroom")
	s.debug_build("gate_picnic")
	_can_near_gate(s)
	var low := s.park.money.wallet
	for i in 28:
		s.park.advance_to(1560.0)
		s.debug_skip_day()
		low = mini(low, s.park.money.wallet)
		t.check(s.park.visitors_in_park() <= 80, "day %d: under the cap" % i)
	t.check(low >= 0, "the wallet never below zero")
	t.check(s.park.letters.size() >= 4, "four weekly reports")
	t.check(s.collapse_count == 0, "nothing failed")


func test_debug_panel_hides_spoiler_pads(t: TestCase) -> void:
	var s := TestCase.new_session()
	var panel := DebugPanel.new()
	panel.setup(s)
	var names := []
	for i in panel._pad_pick.item_count:
		names.append(panel._pad_pick.get_item_text(i))
	for i in panel._place_pick.item_count:
		names.append(panel._place_pick.get_item_text(i))
	for r: Dictionary in s.content.rows("spoiler_pads"):
		t.check(not names.has(r["id"]), "%s not listed" % r["id"])
	t.check(not names.has("kettle_pond"), "nor the pond")
	panel._spoilers.button_pressed = true
	t.check(panel._pad_pick.item_count > names.size() - panel._place_pick.item_count, "listed with spoilers ticked")
	panel.free()
