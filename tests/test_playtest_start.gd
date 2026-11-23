extends RefCounted
## The playtest start: Get the Station Shipshape done and the cabin, the
## outlook, the pond and the tower open, done in the world.


func test_the_playtest_start_opens_the_first_sites(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_sites_open_start(4242)
	t.check(s.jobs.is_done("station_shipshape"), "Get the Station Shipshape is done")
	for k: String in ["open_cabin", "open_outlook", "open_pond", "open_tower"]:
		t.check(s.jobs.is_done(k), "%s is done" % k)
	for id: String in GameSession.PLAYTEST_SITES:
		t.check(s.sites_open.has(id), "%s is open" % id)
		t.check(s.site_reached(id), "%s is joined to the station by trail" % id)
		t.check(s.site_signed(id), "%s has its sign" % id)
	t.check(s.structures.is_open("test_cabin") and s.structures.is_open("static_tower"), "the cabin and the tower are repaired")
	for k: String in GameSession.PLAYTEST_TRAIL_JOBS:
		t.check(s.jobs.is_done(k), "%s is done" % k)
	t.check(s.jobs.travel_open.has("static_tower"), "trail travel reaches the tower")
	t.check(s.town_open, "the road to town is open")
	t.equal(s.location, "", "the ranger is outside")
	t.check(s.clock.day >= 2, "on a fresh morning")
	t.equal(s.jobs.take_card_to_show(), {}, "no old \"done\" cards wait to pop up")
	for id: String in GameSession.PLAYTEST_SITES:
		var lm := str(s.content.row("sites", id)["landmark"])
		t.check(s.map.is_landmark_mapped(lm), "%s is on the map" % id)


func test_the_playtest_start_saves_and_loads(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_sites_open_start(4242)
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(d)
	for id: String in GameSession.PLAYTEST_SITES:
		t.check(s2.sites_open.has(id), "%s is still open after a load" % id)
	t.check(s2.jobs.is_done("open_tower"), "and the jobs stay done")
