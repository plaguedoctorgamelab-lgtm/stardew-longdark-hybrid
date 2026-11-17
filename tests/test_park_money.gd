extends RefCounted
## Phase 3, steps 1 and 2: money and the trail network.


func test_start_with_500(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.park.money.wallet, 500, "a new game starts with $500")


func test_budget_every_seventh_day(t: TestCase) -> void:
	var s := TestCase.new_session()
	for i in 6:
		s.debug_skip_day()
	t.equal(s.park.week_day(), 7, "the seventh day")
	t.equal(s.park.money.wallet, 750, "the Chief's $250 arrived")
	for i in 6:
		s.debug_skip_day()
	t.equal(s.park.money.wallet, 750, "nothing more during the week")
	s.debug_skip_day()
	t.equal(s.park.money.wallet, 1000, "and again on the fourteenth")


func test_orders_arrive_next_morning(t: TestCase) -> void:
	var s := TestCase.new_session()
	var shelf: Inventory = s.structures.shelves["ranger_station"]
	var nails := shelf.count("nails")
	t.equal(s.park.order("nails"), "", "nails ordered")
	t.equal(s.park.money.wallet, 485, "$15 paid")
	t.equal(shelf.count("nails"), nails, "not here yet")
	s.debug_skip_day()
	t.equal(shelf.count("nails"), nails + 10, "a bag of ten on the shelf at 6:00")
	t.equal(s.park.order("kit_bathroom@gate_bathroom"), "", "a bathroom kit ordered for the gate")
	t.equal(s.park.pad_state("gate_bathroom"), "ordered", "on its way")
	s.debug_skip_day()
	t.equal(s.park.pad_state("gate_bathroom"), "kit", "the kit is waiting at its pad")
	t.equal(s.park.order("kit_picnic_area@gate_picnic"), "msg_cant_afford", "no money left for a picnic area")
	t.equal(s.park.order("kit_campground@gate_picnic"), "msg_pad_ordered", "a pad takes only its own facility")


func test_cant_spend_what_is_not_there(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_money(-500)
	t.equal(s.park.money.wallet, 0, "an empty wallet")
	t.equal(s.park.order("planks"), "msg_cant_afford", "nothing can be ordered")
	t.equal(s.park.money.wallet, 0, "and the wallet never goes below zero")


func test_rescue_fee(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.collapse()
	t.equal(s.park.money.wallet, 450, "10% of $500 taken")
	s.debug_money(5000)
	var before := s.park.money.wallet
	s.collapse()
	t.equal(before - s.park.money.wallet, 250, "no more than $250")
	s.debug_money(-s.park.money.wallet)
	s.collapse()
	t.equal(s.park.money.wallet, 0, "nothing from an empty wallet")


func test_ledger_matches_wallet(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.park.order("nails")
	s.park.order("planks")
	for i in 40:
		s.debug_skip_day()
	s.collapse()
	var m := s.park.money
	t.equal(m.opening + m.ledger_sum(), m.wallet, "the ledger adds up to the wallet")
	t.check(s.park.ledger_lines().size() > 4, "the ledger page has lines")


func test_old_save_starts_with_500(t: TestCase) -> void:
	var s := TestCase.new_session()
	var d := s.to_dict()
	d.erase("park")
	s.debug_money(1000)
	s.from_dict(d)
	t.equal(s.park.money.wallet, 500, "a phase 2b save loads with $500")


func test_wallet_on_screen(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.content.text("hud_money", {"n": s.park.money.wallet}), "500 gold", "the wallet reads 500 gold")


# --- the trail network -------------------------------------------------------------

func test_network_updates_at_once(t: TestCase) -> void:
	var s := TestCase.new_session()
	var net := s.park.net
	var g := s.park.gate_node()
	t.check(g.x >= 0, "the gate is on the network")
	# Dig a spur off the trail and see it join the network at once.
	var spur := Vector2i(-1, -1)
	for tile: Vector2i in net.tiles():
		var n := tile + Vector2i(0, 1)
		if s.can_dig(n) and s.can_dig(n + Vector2i(0, 1)):
			spur = n
			break
	t.check(spur.x >= 0, "a place to dig")
	s.debug_dig(spur)
	t.check(net.has(spur), "a dug tile joins the network the same frame")
	s.debug_dig(spur, false)
	t.check(not net.has(spur), "and leaves it when filled")


func test_travel_times_match_walking(t: TestCase) -> void:
	var s := TestCase.new_session()
	var net := s.park.net
	var st := net.nearest(s.world.spawn("station"), 3.0)
	for name: String in ["cabin", "outlook", "fork"]:
		var pts := s.world.route(name)
		var n := net.nearest(pts[pts.size() - 1], 6.0)
		var walked := float(s.world.meta["route_lengths"][name])
		var d := net.distance(st, n)
		t.near(d / walked, 1.0, 0.05, "the %s by the network is within 5%% of the walked route" % name)


func test_obstacles_break_the_network(t: TestCase) -> void:
	var s := TestCase.new_session()
	var net := s.park.net
	var size := net.size()
	var ob: Array = s.world.meta["obstacles_on_routes"][0]
	s.debug_clear_obstacle(Vector2i(int(ob[0]), int(ob[1])))
	t.check(net.size() >= size, "clearing a trunk can only add trail")
