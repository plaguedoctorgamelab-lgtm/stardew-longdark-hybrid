extends RefCounted
## Phase 4, 4a: the insides of the eight houses, entered when someone who
## lives there is home.


func _house_open(s: GameSession, place: String) -> int:
	for m in range(s.tuning.integer("town.visit_from"), s.tuning.integer("town.visit_until"), 30):
		if s.town.someone_home(place, m) != "":
			return m
	return -1


func test_every_house_has_a_room_and_residents(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("town_places"):
		if str(r["kind"]) != "home" or str(r["id"]) == "percolator":
			continue
		var id := str(r["id"])
		t.check(s.shops.has_room(id), "%s has an inside" % id)
		t.check(not s.town.residents(id).is_empty(), "%s has someone living there" % id)
		for f: Dictionary in (s.shops.rooms[id] as InteriorLayout).furniture:
			t.check(Art.has_picture(str(f["sprite"])), "%s: %s is drawn" % [id, f["sprite"]])
		for d: Dictionary in s.shops.inside_row(id).get("decor", []):
			t.check(Art.has_picture(str(d["sprite"])), "%s: %s is drawn" % [id, d["sprite"]])


func test_knocking_lets_the_ranger_in_when_someone_is_home(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town_open = true
	s.enter_town()
	var place := "house_lindqvist"
	var m := _house_open(s, place)
	t.check(m >= 0, "Gus is home at some visiting hour")
	s.debug_set_time(m)
	s.town.place_everyone()
	t.check(s.town.can_visit(place), "his door can be knocked at")
	var b := s.town.building(place)
	s.town_pos = Vector2(float(b["door"][0]) + 0.5, float(b["door"][1]) + 1.2)
	s.facing = GameSession.FACING_UP
	s.interact()
	t.equal(s.town_inside, place, "Gus lets the ranger in")
	t.check(s.shops.people_in(place).has("gus"), "and is there inside")
	# Late in the evening he sees the ranger out.
	s.debug_set_time(s.tuning.integer("town.visit_until") + 10)
	s.process(0.01)
	t.equal(s.town_inside, "", "late in the evening he sees the ranger to the door")


func test_nobody_home_keeps_the_door_shut(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.town_open = true
	s.enter_town()
	t.check(not s.town.can_visit("house_lindqvist", 3 * 60), "nobody knocks at three in the morning")
	t.check(not s.town.can_visit("percolator", 9 * 60), "a shop is not a house")
