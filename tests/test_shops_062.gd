extends RefCounted
## Phase 4, step 5 (0.6.2): Humdrum's shops. From the Phase 4 Spec's tests:
## each opens and closes on time; buying and selling move money and items
## exactly. Also: every shop's room is laid out to the Interior Art Guide,
## the coffee's boost, the library's books, and saves.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_money(500)
	return s


## Into town at a minute of today, and through a shop's door.
func _into(s: GameSession, place: String, minute: int) -> void:
	s.debug_set_time(minute)
	s.enter_town()
	var b := s.town.building(place)
	s.town_pos = Vector2(float(b["door"][0]) + 0.5, float(b["door"][1]) + 1.0)
	s.interact()


## Walks the ranger up to the counter, in front of it.
func _at_counter(s: GameSession) -> void:
	var c := (s.shops.rooms[s.town_inside] as InteriorLayout).find("counter")
	s.interior_pos = Vector2(float(c["pos"][0]) + 1.5, float(c["pos"][1]) + 1.5)


func test_every_shop_room_is_laid_out_well(t: TestCase) -> void:
	var s := _session()
	for place: String in s.shops.rooms:
		var room: InteriorLayout = s.shops.rooms[place]
		var inside := s.shops.inside_row(place)
		var entry := Vector2i(int(inside["entry"][0]), int(inside["entry"][1]))
		t.check(not room.is_solid(entry), "%s: the entry is clear" % place)
		var pieces := room.furniture.filter(func(f: Dictionary) -> bool: return f["kind"] != "exit")
		for i in pieces.size():
			var a := room.furniture_rect(pieces[i])
			t.check(not a.has_point(entry), "%s: %s keeps off the doorway" % [place, pieces[i]["id"]])
			for j in range(i + 1, pieces.size()):
				t.check(not a.intersects(room.furniture_rect(pieces[j])), "%s: %s and %s don't overlap" % [place, pieces[i]["id"], pieces[j]["id"]])
		# The keeper's spot (a shop's) and the guests' spots are open floor.
		if inside.has("keeper_at"):
			var ka: Array = inside["keeper_at"]
			t.check(not room.is_solid(Vector2i(int(ka[0]), int(ka[1]))), "%s: the keeper stands on open floor" % place)
		for g: Array in inside.get("guest_spots", []):
			t.check(not room.is_solid(Vector2i(int(g[0]), int(g[1]))), "%s: guest spot %s is open floor" % [place, g])
		# Every counter and bookshelf can be walked up to from the door, from in front.
		var seen := {entry: true}
		var q: Array[Vector2i] = [entry]
		var h := 0
		while h < q.size():
			var c := q[h]
			h += 1
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if not seen.has(n) and not room.is_solid(n) and n != room.door_tile:
					seen[n] = true
					q.append(n)
		for f: Dictionary in pieces:
			if str(f["kind"]) in ["counter", "bookshelf"]:
				var r := room.furniture_rect(f)
				var front := false
				for x in range(r.position.x, r.end.x):
					front = front or seen.has(Vector2i(x, r.end.y))
				t.check(front, "%s: %s can be walked up to from in front" % [place, f["id"]])
		var floor_tiles := (room.size.x - 2) * (room.size.y - room.wall_height - 1)
		var covered := 0
		for f: Dictionary in pieces:
			covered += room.furniture_rect(f).get_area()
		t.check(covered <= floor_tiles * 0.4, "%s: furniture covers no more than 40%% of the floor" % place)


func test_shops_open_and_close_on_time(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 4 * 60)
	t.equal(s.town_inside, "", "The Percolator is shut before 5:00: the door doesn't open")
	_into(s, "percolator", 9 * 60)
	t.equal(s.town_inside, "percolator", "open at 9:00: in through the door")
	t.check(s.in_town_room() and not s.is_indoors(), "inside a town shop, not a park building")
	t.check(s.needs_context()["indoors"], "under a roof, out of the weather")
	s.leave_town_room()
	_into(s, "casa_luna", 12 * 60)
	t.equal(s.town_inside, "", "Casa Luna is closed on Mondays")
	# Closing time sees the ranger out onto the street.
	_into(s, "gifts", 17 * 60 + 50)
	t.equal(s.town_inside, "gifts", "in Gifts & Notions before 18:00")
	s.debug_set_time(18 * 60)
	s.process(0.0)
	t.equal(s.town_inside, "", "at 18:00 Bev sees the ranger out")
	t.check(s.in_town and not s.town.is_solid(Vector2i(s.town_pos)), "back on the street, on open ground")


func test_walking_out_of_the_door(t: TestCase) -> void:
	var s := _session()
	_into(s, "carpentry", 10 * 60)
	t.equal(s.town_inside, "carpentry", "in the carpentry")
	for i in 40:
		s.move(Vector2(0, 1), 0.1)
	t.equal(s.town_inside, "", "walking down through the door leads out")
	t.check(s.in_town, "still in town")


func test_the_keeper_is_behind_the_counter(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 9 * 60)
	t.check(s.shops.people_in("percolator").has("wren"), "Wren is behind the counter")
	var opts := s.shops.menu_options("percolator")
	t.equal(opts[0]["id"], "talk", "the counter's menu starts with talking to her")
	t.check(opts.any(func(o: Dictionary) -> bool: return o["id"] == "buy"), "and buying")
	t.equal(s.answer_list("shop:percolator", "talk"), "close", "talking closes the menu")
	t.equal(s.town.points("wren"), 20, "and counts as the day's talk")
	t.equal(s.answer_list("shop:percolator", "buy"), "buy:percolator", "Buy shows what's for sale")


func test_buying_moves_money_and_items_exactly(t: TestCase) -> void:
	var s := _session()
	_into(s, "carpentry", 10 * 60)
	var w := s.park.money.wallet
	var planks := s.backpack.count("planks")
	t.equal(s.answer_list("buy:carpentry", "buy:planks"), "", "the list stays open")
	t.equal(s.park.money.wallet, w - 8, "a plank costs 8g, as in the catalog")
	t.equal(s.backpack.count("planks"), planks + 1, "and goes in the backpack the same day")
	var nails := s.backpack.count("nails")
	s.answer_list("buy:carpentry", "buy:nails")
	t.equal(s.backpack.count("nails"), nails + 10, "nails come ten to a box")
	t.equal(s.park.money.wallet, w - 8 - 15, "for 15g")
	s.debug_money(-s.park.money.wallet)
	s.answer_list("buy:carpentry", "buy:roofing")
	t.equal(s.backpack.count("roofing"), 0, "nothing without the money")


func test_coffee_here_speeds_the_ranger_for_two_hours(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 9 * 60)
	var before := s.speed_tiles_per_second()
	var w := s.park.money.wallet
	s.answer_list("buy:percolator", "here:coffee")
	t.equal(s.park.money.wallet, w - 5, "coffee is 5g")
	t.check(is_equal_approx(s.speed_tiles_per_second(), before * 1.1), "walking 10% faster")
	s.answer_list("buy:percolator", "here:coffee")
	t.check(is_equal_approx(s.speed_tiles_per_second(), before * 1.1), "one boost at a time")
	s.debug_set_time(s.clock.minute + 125)
	s.process(0.0)
	t.check(is_equal_approx(s.speed_tiles_per_second(), before), "worn off after two hours")


func test_eating_here_and_taking_away(t: TestCase) -> void:
	var s := _session()
	s.clock.start_next_day()   # Tuesday: Casa Luna is open
	_into(s, "casa_luna", 12 * 60)
	t.equal(s.town_inside, "casa_luna", "Casa Luna is open on a Tuesday")
	s.needs.set_values(10, 10)
	var w := s.park.money.wallet
	var m := s.clock.minute
	s.shops.rng.seed = 1
	s.answer_list("buy:casa_luna", "here:pozole")
	t.equal(s.park.money.wallet, w - 20, "pozole is 20g")
	t.check(s.needs.energy > 100 and s.needs.warmth >= 40, "+100 energy, +40 warmth, eaten at a table")
	t.check(s.clock.minute >= m + 30, "a meal takes half an hour")
	s.answer_list("buy:casa_luna", "away:tamales")
	t.equal(s.park.money.wallet, w - 20 - 20, "to take away costs 2g more")
	t.equal(s.backpack.count("tamales"), 1, "wrapped in the backpack")
	var e := s.needs.energy
	s.eat("tamales")
	t.check(s.needs.energy > e, "eaten later, at full effect")


func test_trail_breakfast_only_before_ten(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 9 * 60)
	s.answer_list("buy:percolator", "away:trail_breakfast")
	t.equal(s.backpack.count("trail_breakfast"), 1, "served at 9:00")
	s.debug_set_time(10 * 60 + 10)
	s.answer_list("buy:percolator", "away:trail_breakfast")
	t.equal(s.backpack.count("trail_breakfast"), 1, "not after 10:00")


func test_selling_at_gifts_and_notions(t: TestCase) -> void:
	var s := _session()
	_into(s, "gifts", 11 * 60)
	s.backpack.add("berry_preserve", 2)
	s.backpack.add("berries", 3)
	t.equal(s.shops.sell_price("gifts", "berry_preserve"), 8, "half the kiosk's 15g, rounded")
	t.equal(s.shops.sell_price("gifts", "berries"), 2, "half the forage price")
	t.equal(s.shops.sell_price("gifts", "hammer"), 0, "tools aren't bought")
	t.equal(s.shops.sell_price("carpentry", "berry_preserve"), 0, "only Gifts & Notions buys")
	var w := s.park.money.wallet
	s.answer_list("sell:gifts", "sell:berry_preserve")
	t.equal(s.park.money.wallet, w + 8, "8g for one jar")
	t.equal(s.backpack.count("berry_preserve"), 1, "one jar left")
	var ids := s.shops.sell_options("gifts").map(func(o: Dictionary) -> String: return o["id"])
	t.check(ids.has("sell:berries") and not ids.has("sell:hammer"), "the sell list shows only what Bev buys")


func test_honour_jar_while_the_keeper_is_out(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 16 * 60)
	t.equal(s.town_inside, "percolator", "open at 16:00")
	s.town.place_everyone()
	t.check(not s.shops.people_in("percolator").has("wren"), "Wren is at the creek")
	t.check(not s.shops.menu_options("percolator").any(func(o: Dictionary) -> bool: return o["id"] == "talk"), "nobody to talk to")
	var w := s.park.money.wallet
	s.answer_list("buy:percolator", "away:muffin")
	t.equal(s.park.money.wallet, w - 6, "the honour jar takes the money")
	t.equal(s.backpack.count("muffin"), 1, "for a muffin")


func test_library_books(t: TestCase) -> void:
	var s := _session()
	t.equal(s.content.rows("books").size(), 10, "ten books")
	_into(s, "library", 10 * 60)
	var teaches := ""
	for b: Dictionary in s.content.rows("books"):
		if str(b.get("teaches", "")) != "":
			teaches = str(b["id"])
			break
	var recipe := str(s.content.row("books", teaches)["teaches"])
	s.recipes_known.erase(recipe)
	t.equal(s.answer_list("books", teaches), "close", "reading closes the list")
	t.check(s.recipes_known.has(recipe), "a book teaches its recipe the first time")
	t.check(s.shops.books_read.has(teaches), "and is marked read")


func test_post_office_takes_catalog_orders(t: TestCase) -> void:
	var s := _session()
	_into(s, "town_hall", 10 * 60)
	s.jobs.unlocks["catalog"] = true
	t.equal(s.answer_list("shop:town_hall", "catalog"), "catalog", "the post office counter opens the catalog")


func test_shops_save_and_load(t: TestCase) -> void:
	var s := _session()
	_into(s, "percolator", 9 * 60)
	s.answer_list("buy:percolator", "here:coffee")
	s.shops.books_read["birds_of_the_valley"] = true
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.equal(s2.town_inside, "percolator", "still inside the Percolator")
	t.equal(s2.shops.boost_until, s.shops.boost_until, "the coffee keeps its time")
	t.check(s2.shops.books_read.has("birds_of_the_valley"), "books read are kept")
	# A save from before the shops has none of it.
	d.erase("shops")
	(d["ranger"] as Dictionary).erase("town_inside")
	var s3 := TestCase.new_session()
	s3.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.equal(s3.town_inside, "", "an older save is outdoors in town")
	t.equal(s3.shops.boost_until, -1, "with no coffee")
