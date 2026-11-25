extends RefCounted
## 0.7.20: Mark's tracker reports on 0.7.19 (#46 to #65), as a player would
## meet them.


func _said(s: GameSession) -> Array:
	var out := []
	s.message.connect(func(m: String) -> void: out.append(m))
	return out


func _sign_tile(s: GameSession, at: Vector2, lo: float, hi: float) -> Vector2i:
	var c := Vector2i(at)
	for d in range(int(lo), int(hi) + 3):
		for dy in range(-d, d + 1):
			for dx in range(-d, d + 1):
				var tl := c + Vector2i(dx, dy)
				var dd := (Vector2(tl) + Vector2(0.5, 0.5)).distance_to(at)
				if dd >= lo and dd <= hi and s.place_problem(tl, "trail_sign") == "":
					return tl
	return Vector2i(-1, -1)


func test_the_ford_sign_gives_no_second_sign(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.row("spoiler_jobs", "the_sign_in_ford")["rewards"]:
		t.check(not (r.get("items", {}) as Dictionary).has("trail_sign"), "#47: no blank sign as a reward")


func test_x_at_the_old_bench_uses_the_hammer(t: TestCase) -> void:
	var s := TestCase.new_session()
	var said := _said(s)
	s.outdoor_pos = s.jobs.spot_pos("old_bench") + Vector2(0, 1)
	s.backpack.remove("hammer", s.backpack.count("hammer"))
	t.check(s.guide.x_hint().contains(s.content.item_name("hammer").to_lower()), "#48: the hint names the hammer: %s" % s.guide.x_hint())
	s.interact()
	t.check(not s.jobs.spots_done.has("old_bench"), "without the hammer nothing happens")
	t.check(said.any(func(m: String) -> bool: return m.contains(s.content.item_name("hammer").to_lower())), "but it says the hammer is wanted: %s" % [said])
	s.backpack.add("hammer", 1)
	s.interact()
	t.check(s.jobs.spots_done.has("old_bench"), "with the hammer in the pack, X takes it up")


func test_the_hammer_takes_down_a_cairn_beside_it(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("hammer", 1)
	s.backpack.add("cairn", 1)
	s.debug_teleport("fork")
	var front := s.ranger_tile() + s.facing_vector()
	# A cairn beside the ranger, not in front (tracker #56).
	var side := s.ranger_tile() + Vector2i(1, 0) if front != s.ranger_tile() + Vector2i(1, 0) else s.ranger_tile() + Vector2i(-1, 0)
	t.check(s.debug_put_up(side, "cairn"), "a cairn goes up beside the ranger")
	var before := s.backpack.count("cairn")
	t.check(bool(s.hammer().get("ok", false)), "#56: the hammer takes it down")
	t.equal(s.backpack.count("cairn"), before + 1, "and it's back in the pack")


func test_the_booked_cabin_chest_opens(t: TestCase) -> void:
	var s := TestCase.new_session()
	var opened := []
	s.storage_opened.connect(func(_title: String, _inv: Inventory) -> void: opened.append(true))
	s.park.booked_by = "the Testers"
	s.park.booked_day = s.park.today()
	t.check(s.bed_taken("test_cabin"), "the cabin is booked")
	s.location = "test_cabin"
	var lay: InteriorLayout = s.interiors["test_cabin"]
	for f: Dictionary in lay.furniture:
		if str(f["kind"]) == "chest":
			s.interior_pos = Vector2(f["pos"][0], f["pos"][1]) + Vector2(0.5, 1.5)
	s._interact_inside()
	t.check(not opened.is_empty(), "#57: the chest opens while guests have the cabin")


func test_stock_is_used_when_the_job_is_done(t: TestCase) -> void:
	var s := TestCase.new_session()
	var k := _deliver_job(s)
	s.jobs.add(k, "test")
	var stp: Dictionary = {}
	for x: Dictionary in s.jobs.def(k)["steps"]:
		if str(x["kind"]) == "deliver":
			stp = x
	var chest: Inventory = s.structures.chests[str(stp["chest"])]
	var had := {}
	for it: String in stp["items"]:
		had[it] = chest.count(it)
		chest.add(it, int(stp["items"][it]))
	s.jobs.debug_finish(k)
	for it: String in stp["items"]:
		t.equal(chest.count(it), int(had[it]), "#59: the %s delivered are used up, not left to take back" % it)


func _deliver_job(s: GameSession) -> String:
	for r: Dictionary in s.content.rows("jobs"):
		for x: Dictionary in r["steps"]:
			if str(x["kind"]) == "deliver" and x.has("chest") and str(x["chest"]) != "open_buildings":
				return str(r["id"])
	return ""


func test_a_stack_splits_in_two(t: TestCase) -> void:
	var s := TestCase.new_session()
	var inv := Inventory.new(s.content, 6)
	inv.add("firewood", 9)
	var to := inv.split(0)
	t.check(to > 0, "#58: half goes to an empty slot")
	t.equal(int(inv.slot(0)["count"]), 5, "five stay")
	t.equal(int(inv.slot(to)["count"]), 4, "four move")
	t.equal(inv.count("firewood"), 9, "none lost")


func test_signs_say_whether_they_count_for_a_job(t: TestCase) -> void:
	var s := TestCase.new_session()
	var said := _said(s)
	s.backpack.add("hammer", 1)
	s.backpack.add("trail_sign", 3)
	s.jobs.add("point_fork", "test")
	var at := s.world.spawn("fork")
	var far := _sign_tile(s, at, 11.0, 16.0)
	t.check(far.x >= 0, "a trail tile a little too far from the fork")
	s.debug_put_up(far, "trail_sign", "test_cabin")
	t.check(said.any(func(m: String) -> bool: return m.contains("steps short")), "#61: a sign too far says so: %s" % [said])
	said.clear()
	var near := _sign_tile(s, at, 0.0, 6.0)
	s.debug_put_up(near, "trail_sign", "kettle_pond")
	t.check(said.any(func(m: String) -> bool: return m.contains("wants a sign to")), "the wrong place says which places: %s" % [said])
	said.clear()
	var near2 := _sign_tile(s, at, 0.0, 6.0)
	s.debug_put_up(near2, "trail_sign", "test_cabin")
	t.check(said.any(func(m: String) -> bool: return m.contains("counts for")), "the right one says it counts: %s" % [said])
	# The map draws the circle for the pinned step (tracker #55).
	s.jobs.pinned = "point_fork"
	var r := 0.0
	for m: Dictionary in s.jobs.map_marks():
		if str(m["key"]) == "point_fork":
			r = float(m["r"])
	t.equal(r, 8.0, "#55: the map mark knows the step's circle")


func test_the_busiest_place_is_named_and_kept(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.jobs.add("ready_crowds", "test")
	var i := -1
	var steps: Array = s.jobs.def("ready_crowds")["steps"]
	for n in steps.size():
		if str(steps[n].get("at", "")) == "busiest":
			i = n
	t.check(i >= 0, "the job has a busiest step")
	var label := s.jobs.step_label("ready_crowds", i)
	var place := s.park.place_name(s.jobs.busiest_for("ready_crowds"))
	t.check(label.contains(place), "#62: the step names the place: %s" % label)
	t.equal(s.jobs.busiest_for("ready_crowds"), str(s.jobs.known["ready_crowds"]["blanks"]["busiest"]), "and keeps it")


func test_the_sign_question_says_where_you_are(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("fork")
	var title := s.sign_where_title()
	t.check(title.contains("steps from"), "#54: %s" % title)
	for o: Dictionary in s.sign_places():
		t.check(str(o["label"]).contains("("), "each place says which way: %s" % o["label"])


func test_a_shelf_sale_is_told(t: TestCase) -> void:
	var s := TestCase.new_session()
	var said := _said(s)
	var item := ""
	for id: String in s.park.gift_shelf.only:
		item = id
		break
	t.check(item != "", "the gift shelf takes something")
	s.park.gift_shelf.add(item, 5)
	s.tuning.set_value("visitors.shelf_buy_share", 1.0)
	for n in 20:
		s.park._leave({"id": 900 + n, "size": 4, "mood": 0.0})
		if s.park.gift_shelf.count(item) < 5:
			break
	if s.park.gift_shelf.count(item) < 5:
		t.check(said.any(func(m: String) -> bool: return m.contains("gift shelf")), "#53: a sale says so: %s" % [said])


func test_the_station_has_a_stove(t: TestCase) -> void:
	var s := TestCase.new_session()
	var lay: InteriorLayout = s.interiors["ranger_station"]
	t.check(lay.furniture.any(func(f: Dictionary) -> bool: return str(f["kind"]) == "stove"), "#64: a stove to cook preserves on")


func test_old_notes_can_be_read_again(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.notes_read["note_tower"] = true
	var b := BookScreen.new()
	b.setup(s)
	b.open("letters")
	var all := b.letters_to_reread()
	t.check(all.any(func(x: Dictionary) -> bool: return bool(x["ranger"])), "#50: the last ranger's note is in the Log")
	b.free()


func test_the_catalog_is_a_sheet_with_a_cart(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_money(1000)
	var sh := ShopSheet.new()
	sh.setup(s)
	sh.open("catalog")
	var lines := sh.catalog_lines()
	t.check(not lines.is_empty(), "#51: there are lines to order")
	var id := str(lines[0]["id"])
	sh._do_order(id)
	sh._do_order(id)
	var cart := sh.catalog_cart()
	t.equal(cart.size(), 1, "two of the same stack as one")
	t.equal(int(cart[0]["n"]), int(lines[0]["count"]) * 2, "with both counted")
	t.check(Sheet.FRAME.encloses(sh.list_scroll.get_rect()) and Sheet.FRAME.encloses(sh.detail_scroll.get_rect()), "on the board")
	sh.free()
