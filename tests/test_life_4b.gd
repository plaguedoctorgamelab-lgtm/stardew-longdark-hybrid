extends RefCounted
## Phase 4b, steps 11 to 14: Esme's readings, the festivals, the station as a
## home, and the garden; and saving all of it.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.town_open = true
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_money(5000)
	return s


# --- the fortune teller -----------------------------------------------------------

func test_the_sky_card_is_always_right(t: TestCase) -> void:
	var s := _session()
	for i in 30:
		var said := s.fortune.weather_on(s.clock.absolute_day() + 2)
		var text := s.fortune.sky_text()
		t.check(text != "", "day %d: the Sky says something" % i)
		s.clock.start_next_day()
		s.clock.start_next_day()
		t.equal(s.weather._main_weather(s.weather.today), said, "day %d: the weather came as foretold" % i)


func test_a_reading_costs_ten_once_a_day(t: TestCase) -> void:
	var s := _session()
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.debug_set_weekday("mon")
	s.debug_set_time(19 * 60)
	s.enter_town()
	t.check(s.fortune.open_now(), "Esme reads in the evening")
	var w := s.park.money.wallet
	var r := s.fortune.reading()
	t.equal((r["cards"] as Array).size(), 3, "three cards")
	t.equal(s.park.money.wallet, w - 10, "ten gold")
	t.check(s.fortune.reading().is_empty(), "one reading a day")
	s.debug_set_time(12 * 60)
	t.check(not s.fortune.open_now(), "not at noon")


func test_nothing_charged_when_nothing_is_left(t: TestCase) -> void:
	var s := _session()
	s.town.met.clear()
	for r: Dictionary in s.content.rows("landmarks"):
		s.map.mark_landmark(str(r["id"]))
	for id: String in s.content.ids("spoiler_finds"):
		s.finds_found[id] = true
	var w := s.park.money.wallet
	var r := s.fortune.reading(true)
	t.check(bool(r["free"]), "nothing left to tell: free")
	t.equal(s.park.money.wallet, w, "nothing charged")


func test_path_circles_never_point_out_of_reach(t: TestCase) -> void:
	var s := _session()
	var river := float(s.world.meta["landmarks"]["broken_bridge"][0])
	var n := 0
	for i in 12:
		s.fortune.read_day = -1
		s.fortune.reading(true)
		s.clock.start_next_day()
	for p: Dictionary in s.fortune.paths:
		n += 1
		var c := Vector2(float(p["center"][0]), float(p["center"][1]))
		t.check(c.x < river + float(p["radius"]), "circle %s is this side of the river" % p["target"])
		t.check(float(p["radius"]) >= s.tuning.num("fortune.base_radius") * 1.5 - 0.01, "Path circles are big and vague")
	t.check(n > 0, "the Path drew circles: %d" % n)
	t.check(s.fortune.map_hints().size() > 0, "and they're on the map")
	for h: Dictionary in s.fortune.map_hints():
		t.equal(str(h["icon"]), "map_fortune_path", "marked with a symbol, not words")


func test_the_heart_card_tells_the_truth(t: TestCase) -> void:
	var s := _session()
	s.town.met["gus"] = true
	for i in 10:
		s.fortune.read_day = -1
		var r := s.fortune.reading(true)
		var heart := str((r["cards"] as Array)[2]["text"])
		t.check(heart.contains("Gus"), "the Heart is about the one person met: %s" % heart)
		s.clock.start_next_day()


# --- festivals --------------------------------------------------------------------

func test_a_festival_starts_stops_time_and_ends(t: TestCase) -> void:
	var s := _session()
	s.debug_start_festival("thaw_fair")
	t.equal(s.festivals.active, "thaw_fair", "walking into the square starts it")
	var m := s.clock.minute
	for i in 50:
		s.process(1.0)
	t.equal(s.clock.minute, m, "time stands still at the festival")
	for id: String in s.content.ids("townsfolk"):
		t.check(s.town.shown(id), "%s is there" % id)
	s.town_pos = Vector2(80.5, 30.5)
	s.process(0.1)
	t.equal(s.festivals.active, "", "walking out ends it")
	t.equal(s.clock.minute, int(s.festivals.row("thaw_fair")["end"]), "the clock jumps to its end")
	s.town_pos = Vector2(35.5, 35.5)
	s.process(0.1)
	t.equal(s.festivals.active, "", "it doesn't start again")


func test_festivals_fall_on_their_days_and_come_back(t: TestCase) -> void:
	var s := _session()
	for r: Dictionary in s.content.rows("festivals"):
		s.clock.season = int(r["season"])
		s.clock.day = int(r["day"])
		t.equal(str(s.festivals.today().get("id", "")), str(r["id"]), "%s is on its day" % r["id"])
		s.clock.set_minute(int(r["start"]) - 10)
		t.check(not s.festivals.on_now(), "not before its hours")
		s.clock.set_minute(int(r["start"]))
		t.check(s.festivals.on_now(), "on at its start")
		s.clock.set_minute(int(r["end"]))
		t.check(not s.festivals.on_now(), "over at its end")
	s.debug_start_festival("lantern_night")
	s.festivals.end()
	t.check(s.festivals.been_this_year("lantern_night"), "been this year")
	s.clock.year += 1
	t.check(not s.festivals.been_this_year("lantern_night"), "it comes round next year")


func test_skipping_a_festival_costs_nothing(t: TestCase) -> void:
	var s := _session()
	var r := s.festivals.row("big_foot_supper")
	s.clock.season = int(r["season"])
	s.clock.day = int(r["day"])
	var pts := s.town.points("gus")
	s.clock.start_next_day()
	t.equal(s.town.points("gus"), pts, "no friendship lost")
	t.check(not s.festivals.been_this_year("big_foot_supper"), "nothing marked against the ranger")
	t.equal(s.festivals.active, "", "and nothing still on")


func test_each_activity_gives_its_prize(t: TestCase) -> void:
	var s := _session()
	# The Thaw Fair: a grown thing is most admired.
	s.backpack.add("tomato", 1)
	s.debug_start_festival("thaw_fair")
	var a := s.festivals.activity()
	t.equal(str(a["kind"]), "fest:entry", "the Grand Display asks for an entry")
	var w := s.park.money.wallet
	var text := s.festivals.choose("fest:entry", "tomato")
	t.check(text.contains("Agnes"), "the judges speak")
	t.equal(s.park.money.wallet, w + 100, "100g for the most admired")
	t.check(s.have("decor_ribbon_thaw") > 0, "and the ribbon")
	t.check(s.festivals.activity().has("text"), "one entry")
	s.festivals.end()
	# Lantern Night: a colour, a wish, a kind word, a lantern.
	s.debug_start_festival("lantern_night")
	t.equal(str(s.festivals.activity()["kind"]), "fest:colour", "a colour first")
	s.festivals.choose("fest:colour", "blue")
	t.equal(str(s.festivals.activity()["kind"]), "fest:wish", "then a wish")
	t.check(s.festivals.choose("fest:wish", "park") != "", "someone answers it")
	t.check(s.have("decor_paper_lantern") > 0, "the paper lantern")
	s.festivals.end()
	# The Big Foot Supper: judge, and eat.
	s.debug_start_festival("big_foot_supper")
	for who: Variant in s.festivals.row("big_foot_supper")["contestants"]:
		t.check(s.festivals.in_suit(str(who)), "%s is in the suit" % who)
	var before := s.town.points("marge")
	s.festivals.choose("fest:winner", "marge")
	t.equal(s.town.points("marge"), before + s.tuning.integer("festivals.bigfoot_points"), "the winner's friendship rises")
	s.needs.set_values(10, 10)
	s.festivals.supper()
	t.near(s.needs.energy, s.needs.max_energy(), 0.01, "the supper restores full energy")
	t.near(s.needs.warmth, s.needs.max_warmth(), 0.01, "and warmth")
	t.check(s.have("judges_sash") > 0, "the judge's sash")
	t.equal(s.festivals.overlay(), "ranger_wear_sash", "worn while judging")
	t.check(Art.has_picture("ranger_wear_sash"), "Mark's sash is drawn")
	s.festivals.end()
	t.equal(s.festivals.overlay(), "", "and off again after the supper")
	# The Long Night: give the fire something; Agnes's story goes in the notebook.
	s.debug_start_festival("long_night")
	var notes := s.park.notes.size()
	var story := s.festivals.choose("fest:gave", "_word")
	t.check(story.contains(s.content.text("fest_story_1")), "year one's story")
	t.equal(s.park.notes.size(), notes + 1, "added to the notebook")
	t.check(s.have("decor_blanket") > 0, "the blanket")
	s.clock.year = 2
	t.equal(s.festivals.story_id(), "fest_story_2", "a different story next year")


func test_festival_lines_and_stall(t: TestCase) -> void:
	var s := _session()
	s.debug_start_festival("thaw_fair")
	for id: String in s.content.ids("townsfolk"):
		var line := s.town.choose_line(id, false)
		t.equal(str(line.get("festival", "")), "thaw_fair", "%s has a Thaw Fair line" % id)
	var opts := s.festivals.stall_options()
	t.check(opts.size() > 2, "the stall sells things")
	s.clock.year = 2
	t.check(str(s.festivals.stall_stock()[0]["item"]) != str(s.festivals.row("thaw_fair")["sells"][0]["item"]), "and different things next year")


func test_festival_weekends_bring_visitors(t: TestCase) -> void:
	var s := _session()
	var r := s.festivals.row("thaw_fair")
	s.clock.season = 0
	s.clock.day = int(r["day"])
	t.check(s.festivals.visitor_mult() > 1.0, "the festival's day is busy")
	s.clock.day = int(r["day"]) - 5
	t.check(s.festivals.visitor_mult() > 1.0, "the week before is busier")
	s.clock.day = int(r["day"]) + 10
	t.near(s.festivals.visitor_mult(), 1.0, 0.001, "a normal week isn't")


# --- the station --------------------------------------------------------------------

func test_upgrades_go_in_order_and_take_three_days(t: TestCase) -> void:
	var s := _session()
	s.backpack.add("planks", 30)
	(s.structures.chests["ranger_station"] as Inventory).add("planks", 30)
	t.equal(s.home.order("kitchen"), "home_busy", "the kitchen waits for Shipshape")
	t.equal(s.home.order("shipshape"), "", "Shipshape is ordered")
	t.equal(s.backpack.count("planks") + (s.structures.chests["ranger_station"] as Inventory).count("planks"), 10, "its 50 planks are taken from pack and chest")
	t.equal(s.home.order("kitchen"), "home_busy", "one at a time")
	s.clock.start_next_day()
	s.clock.start_next_day()
	t.check(not s.home.has("shipshape"), "not done in two days")
	s.clock.start_next_day()
	t.check(s.home.has("shipshape"), "done on the third")
	t.equal(s.home.station_sprite(), "building_station_shipshape", "the station looks cared-for")
	var w0 := 50.0
	s.needs.set_values(100, w0)
	s.leave_town()
	s.outdoor_pos = s.door_front("ranger_station")
	s.enter_building("ranger_station")
	s._on_step(s.clock.minute)
	t.check(s.needs.warmth > w0, "and warmer inside")
	s.backpack.add("planks", 100)
	s.backpack.add("window_glass", 10)
	t.equal(s.home.order("kitchen"), "", "then the kitchen")
	s.debug_finish_upgrade()
	t.check(not s.home.layout().find("range").is_empty(), "a cooking range")
	t.check(not s.home.layout().find("pantry").is_empty(), "a pantry")
	t.equal(s.home.pantry.size(), 24, "of 24 slots")
	t.check(s.home.pantry.accepts("tomato") and not s.home.pantry.accepts("planks"), "that keeps food")
	t.check(s.home.way_ok(), "the kitchen blocks nothing")
	s.debug_finish_upgrade()
	t.check(s.home.has("second_room"), "the second room")
	t.equal(s.home.layout().size.x, 21, "the floor is twice as wide")
	t.check(not s.home.layout().find("reading_chair").is_empty(), "with a reading chair")
	t.check(s.home.way_ok(), "and nothing blocked")
	t.check(s.world.is_solid(Vector2i(20, 1437)), "the new room is solid outside")
	t.equal(s.mailbox_pos().x, 23.5, "the mailbox moves along")


func test_the_range_cooks_without_a_fire(t: TestCase) -> void:
	var s := _session()
	s.debug_finish_upgrade()
	s.debug_finish_upgrade()
	s.outdoor_pos = s.door_front("ranger_station")
	s.enter_building("ranger_station")
	var r := s.home.layout().find("range")
	s.interior_pos = Vector2(float(r["pos"][0]) + 0.5, float(r["pos"][1]) + 1.5)
	t.check(s.can_cook_here(), "at the range: cooking, no fire lit")
	s.interior_pos = s.home.layout().entry
	t.check(not s.can_cook_here(), "not across the room")


func _in_station(s: GameSession) -> void:
	s.leave_town()
	s.outdoor_pos = s.door_front("ranger_station")
	s.enter_building("ranger_station")


func test_placing_and_picking_up_furniture(t: TestCase) -> void:
	var s := _session()
	_in_station(s)
	s.backpack.add("deco_fern", 1)
	s.interior_pos = Vector2(6.5, 6.5)
	s.facing = GameSession.FACING_RIGHT
	t.equal(s.home.place_held("deco_fern"), "", "the fern goes down")
	t.equal(s.backpack.count("deco_fern"), 0, "out of the backpack")
	t.check(s.home.layout().is_solid(Vector2i(7, 6)), "it stands there")
	t.equal(s.home.use_empty_hand(), "picked", "and comes back up")
	t.equal(s.backpack.count("deco_fern"), 1, "into the backpack")
	# The doorway is never blocked.
	s.interior_pos = Vector2(6.5, 8.5)
	s.facing = GameSession.FACING_DOWN
	t.check(s.home.place_held("deco_fern") != "", "not on the doorway")
	# Wall pieces hang on the wall.
	s.backpack.add("deco_clock", 1)
	s.interior_pos = Vector2(4.5, 3.5)
	s.facing = GameSession.FACING_UP
	t.equal(s.home.place_held("deco_clock"), "home_cant_place", "not over a window")
	s.interior_pos = Vector2(10.5, 3.5)
	s.facing = GameSession.FACING_UP
	t.equal(s.home.place_held("deco_clock"), "", "the clock hangs on the back wall")
	var hung := false
	for d: Dictionary in s.home.inside_row()["decor"]:
		if str(d["sprite"]) == "deco_clock":
			hung = true
	t.check(hung, "and is drawn there")
	# A wallpaper covers the room, and the old one comes back.
	s.backpack.add("wallpaper_pines", 1)
	s.backpack.add("wallpaper_logs", 1)
	t.equal(s.home.place_held("wallpaper_pines"), "", "pines up")
	t.equal(str(s.home.inside_row()["wall"]), "interior_wall_pines", "the whole wall")
	s.home.place_held("wallpaper_logs")
	t.equal(s.backpack.count("wallpaper_pines"), 1, "the old paper comes back")


## Whatever is put where, the door still reaches the bed, chest, workbench
## and everything else the ranger uses.
func test_furniture_never_blocks_the_bed_chest_or_door(t: TestCase) -> void:
	var s := _session()
	s.debug_finish_upgrade()
	s.debug_finish_upgrade()
	_in_station(s)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var placed := 0
	var lay := s.home.layout()
	for i in 400:
		var item: String = ["deco_trunk", "deco_loveseat", "deco_fern", "deco_writing_desk", "int_bookcase", "deco_stool"][rng.randi_range(0, 5)]
		s.backpack.add(item, 1)
		s.interior_pos = Vector2(rng.randi_range(1, lay.size.x - 2) + 0.5, rng.randi_range(lay.wall_height, lay.size.y - 2) + 0.5)
		s.facing = rng.randi_range(0, 3)
		if s.home.place_held(item) == "":
			placed += 1
		if not s.home.way_ok():
			t.check(false, "after try %d the way is clear" % i)
	t.check(placed > 10, "plenty went down: %d" % placed)
	t.check(s.home.way_ok(), "the door reaches everything")


func test_the_bed_moves_but_stays(t: TestCase) -> void:
	var s := _session()
	_in_station(s)
	var bed := s.home.layout().find("bed")
	s.interior_pos = Vector2(3.5, 4.5)
	s.facing = GameSession.FACING_LEFT
	t.equal(s.home.use_empty_hand(), "lifted", "the bed is lifted")
	t.check(s.home.layout().find("bed").is_empty(), "off its spot")
	s.leave_building()
	t.check(not s.home.layout().find("bed").is_empty(), "leaving puts it back: never removed")
	_in_station(s)
	s.interior_pos = Vector2(3.5, 4.5)
	s.facing = GameSession.FACING_LEFT
	s.home.use_empty_hand()
	s.interior_pos = Vector2(6.5, 5.5)
	s.facing = GameSession.FACING_RIGHT
	t.equal(s.home.use_empty_hand(), "", "set down somewhere else")
	var moved := s.home.layout().find("bed")
	t.check(int(moved["pos"][0]) != int(bed["pos"][0]), "the bed has moved")
	t.check(s.home.way_ok(), "and nothing is blocked")


# --- the garden ------------------------------------------------------------------------

func _garden(s: GameSession) -> Vector2i:
	s.leave_town()
	var t := s.garden.origin + Vector2i(2, 2)
	s.outdoor_pos = Vector2(t) + Vector2(0.5, -0.5)
	s.facing = GameSession.FACING_DOWN
	return t


func test_the_plot_is_fenced_and_walkable(t: TestCase) -> void:
	var s := _session()
	for y in s.garden.size.y:
		for x in s.garden.size.x:
			t.check(not s.world.is_solid(s.garden.origin + Vector2i(x, y)), "plot tile %d,%d is walkable" % [x, y])
	var fence := 0
	for f: Vector2i in s.garden.fence_tiles():
		if f != s.garden.gate:
			fence += 1
			t.check(s.world.is_solid(f), "the fence is solid")
	t.check(not s.world.is_solid(s.garden.gate), "the gate opens")
	t.equal(fence, 27, "a fence round six by six, less the gate")


func test_crops_grow_only_on_watered_days_and_never_die(t: TestCase) -> void:
	var s := _session()
	s.weather.today.assign(["clear", "clear", "clear"])
	var tile := _garden(s)
	t.equal(s.garden.plant(tile, "seeds_radish"), "garden_needs_soil", "dig first")
	t.equal(s.garden.dig(tile), "garden_dug", "the shovel turns the soil")
	s.backpack.add("seeds_tomato", 1)
	t.equal(s.garden.plant(tile, "seeds_tomato"), "garden_wrong_season", "tomatoes are for summer")
	s.backpack.add("seeds_radish", 1)
	t.equal(s.garden.plant(tile, "seeds_radish"), "garden_planted", "radishes in spring")
	for i in 10:
		s.garden.morning(false)
	t.equal(int(s.garden.tiles[tile]["grown"]), 0, "unwatered it waits")
	t.check(not bool(s.garden.tiles[tile]["withered"]), "and never dies")
	for i in 4:
		s.garden.water(tile)
		s.clock.start_next_day()
		s.jobs.flags.erase("rain_day")
	t.check(s.garden.ripe(tile), "four watered days: ripe")
	t.equal(s.garden.pick(tile), "radish", "picked")
	t.equal(str(s.garden.tiles[tile]["crop"]), "", "a radish doesn't regrow")


func test_rain_waters_and_regrowing_crops_regrow(t: TestCase) -> void:
	var s := _session()
	s.clock.season = 1
	var tile := _garden(s)
	s.garden.dig(tile)
	s.backpack.add("seeds_beans", 1)
	s.garden.plant(tile, "seeds_beans")
	for i in 7:
		s.garden.morning(true)
	t.check(s.garden.ripe(tile), "seven days of rain: ripe")
	t.equal(s.garden.pick(tile), "beans", "picked")
	t.check(not s.garden.ripe(tile) and str(s.garden.tiles[tile]["crop"]) == "beans", "still growing")
	t.equal(s.garden.pictures(tile)[1], "crop_beans_regrow", "regrowing")
	for i in 3:
		s.garden.morning(true)
	t.check(s.garden.ripe(tile), "ripe again in three")


func test_seasons_clear_old_crops_and_winter_rests(t: TestCase) -> void:
	var s := _session()
	var tile := _garden(s)
	s.garden.dig(tile)
	s.backpack.add("seeds_peas", 1)
	s.garden.plant(tile, "seeds_peas")
	s.clock.season = 1
	s.garden.morning(false)
	t.check(bool(s.garden.tiles[tile]["withered"]), "spring's peas wither in summer")
	t.equal(s.garden.pictures(tile)[1], "crop_withered", "gently")
	t.equal(s.garden.dig(tile), "garden_cleared", "and clear away")
	s.clock.season = 3
	t.equal(s.garden.dig(tile + Vector2i(1, 0)), "garden_winter", "winter: the garden rests")
	t.equal(s.garden.pictures(tile)[0], "garden_soil_snow", "under snow")


func test_picking_a_first_tomato_gives_an_idea(t: TestCase) -> void:
	var s := _session()
	s.clock.season = 1
	var tile := _garden(s)
	s.garden.dig(tile)
	s.backpack.add("seeds_tomato", 1)
	s.garden.plant(tile, "seeds_tomato")
	s.recipes_known.erase("tomato_soup")
	for i in 8:
		s.garden.morning(true)
	s.garden.pick(tile)
	t.check(s.recipes_known.has("tomato_soup"), "tomato soup, from the first tomato")


func test_seeds_are_sold_in_season(t: TestCase) -> void:
	var s := _session()
	var spring := ""
	for o: Dictionary in s.shops.buy_options("outfitters"):
		spring += str(o["id"]) + " "
	t.check(spring.contains("seeds_peas") and not spring.contains("seeds_tomato"), "spring seeds in spring")
	t.check(spring.contains("watering_can"), "and the watering can")
	s.clock.season = 1
	var summer := ""
	for o: Dictionary in s.shops.buy_options("outfitters"):
		summer += str(o["id"]) + " "
	t.check(summer.contains("seeds_tomato") and not summer.contains("seeds_peas"), "summer's in summer")


# --- saving -------------------------------------------------------------------------------

func test_everything_saves_and_loads_exactly(t: TestCase) -> void:
	var s := _session()
	s.debug_set_hearts("sol", 8)
	s.life.play_through("he_sol_2")
	s.life.dating["sol"] = true
	s.life.mail_gifts.append(["sol", "painted_stone"])
	s.fortune.reading(true)
	s.debug_start_festival("thaw_fair")
	s.backpack.add("apple", 1)
	s.festivals.choose("fest:entry", "apple")
	s.festivals.end()
	s.debug_finish_upgrade()
	s.debug_finish_upgrade()
	_in_station(s)
	s.backpack.add("deco_fern", 1)
	s.interior_pos = Vector2(6.5, 6.5)
	s.facing = GameSession.FACING_RIGHT
	s.home.place_held("deco_fern")
	s.home.pantry.add("tomato", 3)
	var tile := _garden(s)
	s.garden.dig(tile)
	s.backpack.add("seeds_radish", 1)
	s.garden.plant(tile, "seeds_radish")
	s.garden.water(tile)
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.equal(s2.town.points("sol"), s.town.points("sol"), "hearts")
	t.check(s2.life.seen.has("he_sol_2") and s2.life.dating.has("sol"), "events seen and dating")
	t.equal(s2.life.mail_gifts.size(), 1, "the mailbox gift")
	t.equal(s2.fortune.paths.size(), s.fortune.paths.size(), "Esme's circles")
	t.equal(s2.fortune.read_day, s.fortune.read_day, "today's reading")
	t.check(s2.festivals.been_this_year("thaw_fair"), "festivals been to")
	t.equal(s2.home.level, 2, "the upgrades")
	t.equal(s2.home.placed.size(), 1, "the furniture placed")
	t.equal(s2.home.pantry.count("tomato"), 3, "the pantry")
	t.equal(str(s2.garden.tiles[tile]["crop"]), "radish", "the garden")
	t.equal(int(s2.garden.tiles[tile]["watered"]), int(s.garden.tiles[tile]["watered"]), "watered today")
	t.equal(s2.home.layout().furniture.size(), s.home.layout().furniture.size(), "the station's room")


func test_a_save_from_before_4b_loads(t: TestCase) -> void:
	var s := _session()
	var d := s.to_dict()
	for k: String in ["life", "fortune", "festivals", "home", "garden"]:
		d.erase(k)
	var s2 := TestCase.new_session()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.equal(s2.home.level, 0, "no upgrades")
	t.equal(s2.life.seen.size(), 0, "no events seen")
	t.equal(s2.garden.tiles.size(), 0, "an empty garden")
	t.equal(s2.home.layout().size, Vector2i(13, 11), "the station as it was")
