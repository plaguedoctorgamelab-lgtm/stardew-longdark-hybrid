extends RefCounted
## Phase 4, 4a step 6: clothing for warmth.


func _ctx(s: GameSession, weather: String) -> Dictionary:
	var c := s.needs_context()
	c["indoors"] = false
	c["weather"] = s.weather.row(weather)
	c["night"] = false
	c["campfire"] = false
	return c


func test_the_starting_clothes_give_the_old_warmth(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.wardrobe.worn, {"hat": "ranger_hat", "coat": "ranger_jacket", "boots": "work_boots"}, "the ranger starts in hat, jacket and boots")
	t.equal(s.wardrobe.warmth(), 1.0, "they add up to the old clothing value")
	t.equal(s.wardrobe.base_sheet(), "ranger", "drawn as the ranger always was")
	t.equal(s.wardrobe.overlays().size(), 0, "with nothing over them")


func test_each_piece_adds_its_warmth(t: TestCase) -> void:
	for r: Dictionary in TestCase.new_session().content.rows("clothing"):
		var s := TestCase.new_session()
		var before := s.needs.warmth_delta(_ctx(s, "clear"))
		var old := float(s.wardrobe.row(str(s.wardrobe.worn[str(r["slot"])]))["warmth"])
		s.backpack.add(str(r["id"]), 1)
		if bool(r.get("start", false)):
			continue
		t.check(s.put_on(str(r["id"])), "%s goes on" % r["id"])
		t.equal(s.needs.warmth_delta(_ctx(s, "clear")) - before, float(r["warmth"]) - old, "%s adds what its row says" % r["id"])
		t.check(s.content.has("items", str(r["id"])) and Art.has_picture(str(s.content.row("items", str(r["id"]))["icon"])), "%s has an icon" % r["id"])
		t.check(Art.has_picture(str(r["overlay"])), "%s is drawn on the ranger" % r["id"])


func test_putting_on_swaps_into_the_spare_clothes(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("wool_coat", 1)
	t.check(s.put_on("wool_coat"), "the wool coat goes on")
	t.equal(s.wardrobe.worn["coat"], "wool_coat", "and is worn")
	t.equal(s.backpack.count("wool_coat"), 0, "out of the backpack")
	t.check(s.wardrobe.spare.has("ranger_jacket"), "the jacket goes with the spare clothes (0.7.8)")
	t.check(s.put_on("ranger_jacket"), "and can go back on")
	t.check(s.wardrobe.spare.has("wool_coat"), "the coat kept with the spare clothes")
	s.backpack.add("wool_toque", 1)
	s.put_on("wool_toque")
	t.equal(s.wardrobe.base_sheet(), "ranger_nohat", "under a toque the ranger's hat comes off")
	t.check(s.wardrobe.overlays().has("ranger_wear_wool_toque"), "and the toque is drawn")


func test_the_rain_shell_halves_the_rains_chill(t: TestCase) -> void:
	var s := TestCase.new_session()
	var wet := s.needs.warmth_delta(_ctx(s, "rain"))
	s.backpack.add("rain_shell", 1)
	s.put_on("rain_shell")
	var dry := s.needs.warmth_delta(_ctx(s, "rain"))
	t.equal(dry - wet, -float(s.weather.row("rain")["warmth"]) / 2.0, "half the rain's chill is kept off")


func test_parka_slows_and_boots_wade(t: TestCase) -> void:
	var s := TestCase.new_session()
	var v := s.speed_tiles_per_second()
	s.backpack.add("down_parka", 1)
	s.put_on("down_parka")
	t.check(absf(s.speed_tiles_per_second() - v * 0.95) < 0.001, "the down parka walks 5% slower")
	t.equal(s.wardrobe.speed_factor(), 0.95, "as its row says")
	t.check(s.wardrobe.has_effect("slow") and not s.wardrobe.has_effect("wade"), "only the parka's effect")
	s.backpack.add("waterproof_boots", 1)
	s.put_on("waterproof_boots")
	t.check(s.wardrobe.has_effect("wade"), "waterproof boots wade")


func test_clothes_are_sold_and_saved(t: TestCase) -> void:
	var s := TestCase.new_session()
	var sold := {}
	for it: Dictionary in s.content.row("shops", "outfitters")["sells"]:
		sold[str(it["item"])] = int(it["price"])
	for r: Dictionary in s.content.rows("clothing"):
		if not bool(r.get("start", false)):
			t.equal(sold.get(str(r["id"]), -1), int(r["price"]), "the outfitters sells %s for %d" % [r["id"], r["price"]])
	t.check(sold.has("bedroll_big"), "and the big bedroll")
	s.backpack.add("insulated_boots", 1)
	s.put_on("insulated_boots")
	var s2 := TestCase.new_session()
	s2.from_dict(s.to_dict())
	t.equal(s2.wardrobe.worn["boots"], "insulated_boots", "what is worn is saved")
	var old := s.to_dict()
	old.erase("wardrobe")
	s2.from_dict(old)
	t.equal(s2.wardrobe.worn["boots"], "work_boots", "a save from before clothing starts in the starting clothes")
