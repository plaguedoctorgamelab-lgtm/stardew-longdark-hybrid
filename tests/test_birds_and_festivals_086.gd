extends RefCounted
## 0.8.6: the birds (crows, owls, blue jays, cardinals, the starry crow and
## the three-eyed owl) and the new festival year (Art Request 27).


func _out(s: GameSession, minute: int, season: int = 1) -> void:
	s.clock.season = season
	s.clock.set_minute(minute)
	s.wildlife.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)


func _first(s: GameSession, id: String) -> Dictionary:
	for a: Dictionary in s.wildlife.animals:
		if str(a["id"]) == id:
			return a
	return {}


func test_six_birds_with_their_pictures(t: TestCase) -> void:
	var s := TestCase.new_session()
	var birds := s.wildlife.entries("bird")
	t.equal(birds.size(), 6, "six birds in the guide")
	for r: Dictionary in birds:
		var id := str(r["id"])
		t.check(Art.has_picture("sketch_" + id), "%s has a sketch" % id)
		t.check(s.content.has("items", str(r["feather"])), "%s has a feather" % id)
		t.check(Art.has_picture("item_" + str(r["feather"])), "%s's feather is drawn" % id)
		if str(r["cousin_of"]) != "":
			t.check(Art.has_picture(str(r["glow"])), "%s glows" % id)
	t.check(Art.has_picture("guide_tab_birds"), "the Birds tab is drawn")
	t.check(GuideScreen.PAGES.has("bird"), "and in the guide")


func test_birds_keep_their_hours(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	t.check(not _first(s, "crow").is_empty(), "crows by day")
	t.check(_first(s, "owl").is_empty(), "no owls at noon")
	_out(s, 23 * 60)
	t.check(not _first(s, "owl").is_empty(), "owls at night")
	t.check(_first(s, "crow").is_empty(), "crows gone to roost")
	_out(s, 13 * 60, 3)
	t.check(not _first(s, "crow").is_empty(), "crows in winter too")


func test_a_magic_owl_among_the_owls(t: TestCase) -> void:
	var s := TestCase.new_session()
	var r := s.content.row("animals", "magic_owl")
	var was: float = r["chance"]
	r["chance"] = 1.0
	_out(s, 23 * 60)
	r["chance"] = was
	t.check(not _first(s, "magic_owl").is_empty(), "a three-eyed owl at night among the owls")


func test_birds_fly_off_and_drop_feathers(t: TestCase) -> void:
	var s := TestCase.new_session()
	_out(s, 13 * 60)
	var a := _first(s, "crow")
	t.check(not a.is_empty(), "a crow out")
	t.check(not s.wildlife.in_air(a) or str(a["state"]) == "walk", "on the ground unless moving")
	s.tuning.data["wildlife"]["feather_chance"] = 1.0
	s.outdoor_pos = Vector2(a["pos"]) + Vector2(1.0, 0)
	s.wildlife._move(a, 0.1)
	t.equal(str(a["state"]), "flee", "too close: it flies off")
	t.check(s.wildlife.in_air(a), "in the air")
	t.equal(s.wildlife.feathers.size(), 1, "and leaves a feather")
	var fe := s.wildlife.feather_in_reach(Vector2(s.wildlife.feathers[0]["pos"]), 1.0)
	t.equal(fe, 0, "within reach")
	t.check(s.wildlife.take_feather(fe), "picked up")
	t.equal(s.have("feather_crow"), 1, "a crow feather")
	t.equal(s.wildlife.feathers.size(), 0, "gone from the ground")


func test_the_new_festival_year(t: TestCase) -> void:
	var s := TestCase.new_session()
	var want := {"lantern_night": [0, 20], "midsummer": [1, 14], "samhain": [2, 28], "big_foot_supper": [3, 18]}
	t.equal(s.content.rows("festivals").size(), 4, "four festivals")
	for id: String in want:
		var r := s.festivals.row(id)
		t.equal([int(r["season"]), int(r["day"])], want[id], "%s on its day" % id)
		t.check(not (int(r["day"]) in [7, 21]), "%s isn't on a full moon" % id)
		for d: Array in r["decor"]:
			var art := str(d[0])
			t.check(Art.has_picture(art) or Art.has_picture(art + "_0"), "%s: %s is drawn" % [id, art])
	for p: String in ["fest_wicker_moose", "fest_wicker_moose_burn_1", "fest_wicker_moose_embers", "ranger_wear_crown", "fest_flower_crown_small", "decor_wicker_moose", "decor_ribbon_samhain", "item_sweets"]:
		t.check(Art.has_picture(p), "%s is drawn" % p)
	for f: Variant in s.festivals.row("samhain")["faces"]:
		t.check(Art.has_picture("fest_jack_o_lantern_" + str(f)), "the %s jack-o'-lantern" % f)
