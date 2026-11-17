extends RefCounted
## Phase 3, steps 4 and 5: facilities, small placed things, the cabin for
## rent and income.


func _park() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	for id: String in ["old_cabin", "outlook"]:
		ParkHelpers.ready_site(s, id)
	return s


func _stand_by_pad(s: GameSession, pad: String) -> void:
	var rc := s.park.pad_rect(pad)
	s.outdoor_pos = Vector2(rc.position.x + rc.size.x / 2.0, rc.end.y + 0.6)
	s.location = ""


func test_pads_show_when_their_site_is_ready(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.park.pad_shown("gate_bathroom"), "the gate's pads from the start")
	t.check(not s.park.pad_shown("cabin_picnic"), "the cabin's not before it is ready")
	ParkHelpers.ready_site(s, "old_cabin")
	t.check(s.park.pad_shown("cabin_picnic"), "once it is")
	t.check(s.park.built("gate_kiosk"), "the kiosk is already built")


func test_building_a_bathroom(t: TestCase) -> void:
	var s := _park()
	s.park.order("kit_bathroom@gate_bathroom")
	s.debug_skip_day()
	_stand_by_pad(s, "gate_bathroom")
	var n := int(s.content.row("facilities", "bathroom")["actions"])
	var m0 := s.clock.minute
	for i in n - 1:
		var r := s.hammer()
		t.check(r["ok"] and not r["built"], "hammer action %d" % (i + 1))
	t.equal(s.clock.minute - m0, (n - 1) * 20, "each action takes 20 minutes")
	t.check(s.hammer()["built"], "built after %d actions" % n)
	t.check(s.park.built("gate_bathroom"), "the bathroom stands")
	var rc := s.park.pad_rect("gate_bathroom")
	t.check(s.world.is_solid(rc.position), "it is solid")
	var w := s.park.money.wallet
	s.hammer()
	t.equal(s.pending_confirm, "take_down:gate_bathroom", "the hammer offers to take it down")
	s.answer_confirm(true)
	t.equal(s.park.money.wallet - w, 200, "half its price back")
	t.check(not s.park.built("gate_bathroom"), "gone")
	t.check(not s.world.is_solid(rc.position), "and the ground is clear")


func test_dock_lays_boards(t: TestCase) -> void:
	var s := TestCase.new_session()
	var rc := s.park.pad_rect("pond_dock")
	var water := rc.position
	t.equal(s.world.ground_at(water), "shallows", "water before")
	s.debug_build("pond_dock")
	t.equal(s.world.ground_at(water), "boards", "boards after")
	s.park.take_down("pond_dock")
	t.equal(s.world.ground_at(water), "shallows", "water again")


func test_placing_small_things(t: TestCase) -> void:
	var s := _park()
	var g := s.park.gate_node()
	t.equal(s.park.place_problem(g), "msg_place_bad_spot", "never on the trail")
	var near := Vector2i(-1, -1)
	for dy in range(2, 6):
		var c := g + Vector2i(4, dy)
		if s.park.place_problem(c) == "":
			near = c
			break
	t.check(near.x >= 0, "open ground near the trail")
	var far := Vector2i(-1, -1)
	for dy in range(8, 40):
		var c := g + Vector2i(10, dy)
		if s.world.ground_at(c) in ["grass", "forest_floor", "tall_grass"] and not s.world.is_solid(c) and s.world.object_at(c) == "":
			if s.park._near_trail(c, 6):
				continue
			far = c
			break
	if far.x >= 0:
		s.map.reveal_circle(Vector2(far), 3.0)
		t.equal(s.park.place_problem(far), "msg_place_thing_far", "not far from a trail")
	s.debug_add_item("bench", 1)
	s.selected_slot = s.backpack.find_family("bench")
	s.outdoor_pos = Vector2(near) + Vector2(0.5, 1.5)
	s.facing = GameSession.FACING_UP
	t.check(s.place_park_thing(), "a bench put down")
	t.equal(s.park.things[near]["id"], "bench", "it is there")
	t.check(s.world.is_solid(near), "and solid")
	s.selected_slot = s.backpack.find_family("hammer")
	var r := s.hammer()
	t.equal(r["reason"], "picked_up", "the hammer picks it up again")
	t.equal(s.backpack.count("bench"), 1, "back in the backpack, whole")
	s.map.wipe()
	t.equal(s.park.place_problem(near), "msg_place_thing_unseen", "not on ground never seen")


func test_income_sources(t: TestCase) -> void:
	var s := _park()
	s.park.sim_minute = 480.0
	var day := s.clock.absolute_day()
	s.park.spawn("day_hiker", 2)
	t.equal(int(s.park.money.totals(day, day)["entrance"]), 10, "$5 entrance each")
	t.check(not s.park.money.totals(day, day).has("park_map"), "no maps for sale before three sites are mapped")
	for lm: String in ["test_cabin", "scenic_outlook", "kettle_pond"]:
		s.map.mark_landmark(lm)
	s.tuning.set_value("visitors.map_buy_share", 1.0)
	s.tuning.set_value("visitors.gear_rent_share", 1.0)
	var gear0 := int(s.park.money.totals(day, day).get("gear", 0))
	s.park.spawn("day_hiker", 2)
	var tot := s.park.money.totals(day, day)
	t.equal(int(tot["park_map"]), 16, "$8 maps once three sites are mapped")
	t.equal(int(tot["gear"]) - gear0, 10, "$5 gear rental")
	s.park.spawn("tour_group", 6)
	t.equal(int(s.park.money.totals(day, day)["tour"]), 72, "$12 a person for a tour")


func test_fishing_permits(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	for r in ["pond"]:
		ParkHelpers.open_route(s, r)
	ParkHelpers.ready_site(s, "kettle_pond")
	s.debug_build("pond_dock")
	s.park.sim_minute = 480.0
	var p := s.park.spawn("anglers", 2)
	var day := s.clock.absolute_day()
	# Walk them straight to the dock.
	p["legs"] = [s.park._leg(s.park.pad_node("pond_dock"), "fish", "pond_dock"), s.park._leg(s.park.gate_node(), "home")]
	p["leg"] = 0
	s.park._start_leg(p)
	s.park.advance_to(1500.0)
	t.equal(int(s.park.money.totals(day, day).get("fishing", 0)), 12, "$6 for each angler who fished")


func test_gift_shelf_sells_only_what_is_stocked(t: TestCase) -> void:
	var s := _park()
	s.tuning.set_value("visitors.shelf_buy_share", 1.0)
	var day := s.clock.absolute_day()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	s.park._leave(p)
	t.check(not s.park.money.totals(day, day).has("gift_shelf"), "nothing sold from an empty shelf")
	t.equal(s.park.gift_shelf.add("planks", 1), 1, "planks can't go on the gift shelf")
	s.park.gift_shelf.add("painted_stone", 1)
	s.park._leave(p)
	t.equal(int(s.park.money.totals(day, day)["gift_shelf"]), 8, "a painted stone sold for $8")
	t.equal(s.park.gift_shelf.count("painted_stone"), 0, "and it's gone")


func test_gift_ideas_at_the_empty_shelf(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not s.recipes_known.has("painted_stone"), "not known at first")
	s.open_gift_shelf()
	for rid: String in s.content.row("ideas", "gift_shelf")["recipes"]:
		t.check(s.recipes_known.has(rid), "%s learned at the empty shelf" % rid)


func test_cabin_for_rent(t: TestCase) -> void:
	var s := _park()
	s.debug_repair_all("test_cabin", true)
	s.park.rent_mode = "rent"
	s.tuning.set_value("visitors.cabin_book_chance", 1.0)
	s.sleep()
	t.check(s.park.cabin_booked(), "booked for tonight")
	var lines := "\n".join(s.wake_lines())
	t.check(s.read_note_board().contains(s.content.text("msg_cabin_booked", {"party": s.park.booked_by})), "the station's board says so")
	t.equal(int(s.park.money.totals(s.clock.absolute_day(), s.clock.absolute_day()).get("cabin_rent", 0)), 40, "$40 a night")
	t.check(s.bed_taken("test_cabin"), "the bed is the renters'")
	s.enter_building("test_cabin")
	var layout: InteriorLayout = s.interiors["test_cabin"]
	var bed := layout.furniture_rect(layout.find("bed"))
	s.interior_pos = Vector2(bed.end.x + 0.5, bed.position.y + 1.0)
	s.interact()
	t.equal(s.pending_confirm, "", "no sleeping in a booked bed")
	t.equal(s.nearest_bed(), "ranger_station", "a rescue goes elsewhere tonight")
	s.park.rent_mode = "ranger"
	s.leave_building()
	s.sleep()
	t.check(not s.bed_taken("test_cabin"), "the ranger's again the next night")
	t.check(lines == lines, "announced in the morning")
