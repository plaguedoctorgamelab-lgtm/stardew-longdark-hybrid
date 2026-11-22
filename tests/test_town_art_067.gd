extends RefCounted
## 0.6.7: Mark's Art Request 19 in Humdrum. Every building and piece has its
## finished picture, grounds meet with edge pieces, windows glow at night,
## seasonal pieces keep to their seasons, and the yards' fences are solid.


func _session() -> GameSession:
	var s := TestCase.new_session()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	return s


func test_every_town_picture_is_finished(t: TestCase) -> void:
	var s := _session()
	var missing: Array[String] = []
	var names: Array[String] = []
	for b: Dictionary in s.town.buildings:
		names.append(str(b["sprite"]))
	for o: Dictionary in s.town.objects:
		names.append(str(o["sprite"]))
	for n: String in names:
		if not FileAccess.file_exists("res://art/final/%s.png" % n) and not missing.has(n):
			missing.append(n)
	t.equal(missing, [] as Array[String], "every building and piece in town has Mark's picture")


func test_grounds_meet_with_edges(t: TestCase) -> void:
	var s := _session()
	var view := TownView.new()
	view.session = s
	view.town = s.town
	var looks: Dictionary = s.tuning.value("town_look.ground")
	var edges: Dictionary = s.tuning.value("town_look.edges")
	var weights := {}
	for code: String in looks:
		weights[code] = WorldView._running_total(looks[code]["weights"])
	# Main Street's top row (y 28) has lawn above it, away from the buildings.
	t.equal(view.picture_at(Vector2i(87, 28), looks, edges, weights), "town_edge_cobbles_n", "cobbles under lawn take the north edge")
	t.equal(view.picture_at(Vector2i(87, 32), looks, edges, weights), "town_edge_cobbles_s", "and the south edge on the other side")
	t.check(view.picture_at(Vector2i(87, 30), looks, edges, weights).begins_with("town_edge_cobbles_c"), "the middle of the street is plain cobbles")
	t.check(view.picture_at(Vector2i(35, 35), looks, edges, weights).begins_with("town_paving"), "the square's middle is paving")
	t.equal(view.picture_at(Vector2i(29, 31), looks, edges, weights), "town_edge_paving_nw", "the paving has a border of setts where it meets the cobbles and the green")
	view.free()


func test_windows_glow_at_night(t: TestCase) -> void:
	var s := _session()
	for n: String in ["town_house_blue", "town_library", "town_outfitters", "town_house_studio"]:
		t.check(TownView.window_glow(Art.image(n), s.tuning) != null, "%s has windows to light" % n)
	t.check(TownView.window_glow(Art.image("town_square_compass"), s.tuning) == null, "the compass in the paving has no windows")


func test_seasonal_pieces_name_real_seasons(t: TestCase) -> void:
	var s := _session()
	var seasons := ["spring", "summer", "autumn", "winter"]
	var blossom := 0
	for o: Dictionary in s.town.objects:
		for se: String in o.get("seasons", []):
			t.check(seasons.has(se), "%s shows in a real season" % o["sprite"])
		if str(o["sprite"]) == "obj_tree_crabapple":
			blossom += 1
			t.equal(o["seasons"], ["spring"], "crabapple blossom is spring only")
	t.check(blossom >= 3, "crabapples line Main Street")


func test_fences_are_solid_and_places_are_open(t: TestCase) -> void:
	var s := _session()
	t.check(s.town.is_solid(Vector2i(10, 3)), "the Pelletiers' back fence blocks the way")
	t.check(s.town.is_solid(Vector2i(60, 3)), "and so does the stone wall in the east")
	for k: String in s.town.places:
		t.check(not s.town.is_solid(s.town.places[k]), "%s can be walked to" % k)
	t.check(not s.town.is_solid(Vector2i(22, 50)), "the footbridge crosses the creek")
