extends RefCounted
## Map: each of the four actions reveals its tuned area; survey is refused at
## night and in fog, rain, storm, snow and blizzard; the marker shows only
## under its three conditions; the hidden trace appears when the marker
## returns.


func _area(r: float) -> float:
	return PI * r * r


func test_trace_while_walking(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_set_time(9 * 60)
	s.map.reveal_circle(s.outdoor_pos, 30)
	var start := s.outdoor_pos
	for i in 20:
		s.move(Vector2.RIGHT, 0.1)
	var traced := 0
	for x in range(floori(start.x), floori(s.outdoor_pos.x) + 1):
		if s.map.is_traced(Vector2i(x, floori(start.y))):
			traced += 1
	t.check(traced >= 8, "walking leaves a trace (%d tiles)" % traced)
	var before := s.map.revealed_count
	t.equal(before, s.map.revealed_count, "a trace reveals no ground")


func test_survey_reveals_its_radius(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_wipe_map()
	s.debug_force_weather("clear")
	s.debug_set_time(9 * 60)
	s.debug_teleport("fork")
	t.check(s.start_survey(), "survey starts")
	s.clock.advance_step()
	s.clock.advance_step()
	t.equal(s.map.revealed_count, 0, "nothing until the survey is done")
	s.clock.advance_step()
	var r := s.tuning.num("map.survey_radius")
	t.near(float(s.map.revealed_count), _area(r), _area(r) * 0.08, "survey reveals radius %d" % r)
	t.check(s.map.is_revealed(Vector2i(s.outdoor_pos + Vector2(r - 1, 0))), "edge of the survey revealed")
	t.check(not s.map.is_revealed(Vector2i(s.outdoor_pos + Vector2(r + 2, 0))), "beyond the survey not revealed")


func test_survey_takes_thirty_minutes_and_moving_cancels(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_wipe_map()
	s.debug_force_weather("overcast")
	s.debug_set_time(9 * 60)
	s.debug_teleport("fork")
	s.start_survey()
	s.clock.advance_step()
	s.move(Vector2.RIGHT, 0.1)
	s.clock.advance_step()
	s.clock.advance_step()
	t.equal(s.map.revealed_count, 0, "moving cancelled the survey")
	t.equal(s.survey_steps_left, 0, "no survey running")


func test_survey_needs_tools(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_set_time(9 * 60)
	s.backpack.remove("compass")
	t.check(not s.start_survey(), "no survey without the compass")
	s.debug_add_item("compass")
	s.backpack.remove("pencil")
	t.check(not s.start_survey(), "no survey without the pencil")


func test_survey_refused_at_night_and_in_bad_weather(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_time(23 * 60)
	s.debug_force_weather("clear")
	t.check(not s.start_survey(), "refused at night")
	s.debug_set_time(9 * 60)
	for w in ["fog", "rain", "storm", "snow", "blizzard"]:
		s.debug_force_weather(w)
		t.check(not s.start_survey(), "refused in %s" % w)
	for w in ["clear", "overcast"]:
		s.debug_force_weather(w)
		t.check(s.start_survey(), "allowed in %s" % w)
		s.survey_steps_left = 0


func test_map_location_reveals_landmark(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_wipe_map()
	s.debug_force_weather("blizzard")
	s.debug_set_time(23 * 60)
	s.debug_teleport("cabin")
	var m0 := s.clock.minute
	s.interact()
	t.check(s.map.is_landmark_mapped("test_cabin"), "interacting with the cabin maps it, even at night in a blizzard")
	t.equal(s.clock.minute, m0 + 20, "mapping a location takes 20 minutes")
	var r := s.tuning.num("map.location_radius")
	t.near(float(s.map.revealed_count), _area(r), _area(r) * 0.12, "location reveals radius %d" % r)


func test_outlook_survey_reveals_forty(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_wipe_map()
	s.debug_force_weather("clear")
	s.debug_set_time(9 * 60)
	s.debug_teleport("outlook")
	t.check(s.on_outlook(), "standing on the outlook")
	t.check(s.start_survey(), "survey starts")
	s.pass_minutes(30)
	var r := s.tuning.num("map.outlook_radius")
	# Near the north edge some of the circle falls off the map.
	var c := s.outdoor_pos
	var inside := 0
	for y in range(floori(c.y - r), ceili(c.y + r) + 1):
		for x in range(floori(c.x - r), ceili(c.x + r) + 1):
			if x >= 0 and y >= 0 and x < s.world.width and y < s.world.height and s.map.explorable[y * s.world.width + x] == 1 and Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				inside += 1
	t.equal(s.map.revealed_count, inside, "outlook survey reveals radius %d" % r)


func test_marker_three_conditions(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_set_time(12 * 60)
	s.debug_teleport("fork")
	t.check(not s.marker_visible(), "hidden on unrevealed ground")
	s.map.record_trace(s.ranger_tile(), true)
	t.check(not s.marker_visible(), "a trace alone does not count")
	s.map.reveal_circle(s.outdoor_pos, 15)
	t.check(s.marker_visible(), "shown on revealed ground by day")
	for w in ["fog", "storm", "blizzard"]:
		s.debug_force_weather(w)
		t.check(not s.marker_visible(), "hidden in %s" % w)
	for w in ["rain", "snow", "overcast", "clear"]:
		s.debug_force_weather(w)
		t.check(s.marker_visible(), "shown in %s" % w)
	s.debug_set_time(23 * 60)
	t.check(s.on_trail(), "the fork is on the trail")
	t.check(s.marker_visible(), "shown at night on a trail")
	# Step off the trail at night.
	var off := Vector2(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tt := s.ranger_tile() + Vector2i(dx, dy)
			if s.world.ground_at(tt) == "forest_floor" and not s.world.is_solid(tt):
				off = Vector2(tt.x + 0.5, tt.y + 0.5)
	t.check(off.x > 0, "found forest floor near the fork")
	s.outdoor_pos = off
	t.check(not s.marker_visible(), "hidden at night off the trail")
	s.debug_set_time(12 * 60)
	t.check(s.marker_visible(), "shown by day off the trail")


func test_hidden_trace_appears_when_marker_returns(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_time(12 * 60)
	s.debug_teleport("fork")
	s.map.reveal_circle(s.outdoor_pos, 6)
	s.debug_force_weather("fog")
	# Walk east out of the revealed patch in fog: trace held back.
	var path_tiles: Array[Vector2i] = []
	for i in 40:
		s.move(Vector2.RIGHT, 0.1)
		path_tiles.append(s.ranger_tile())
	var lost_tile := path_tiles[path_tiles.size() - 1]
	t.check(s.map.is_pending(lost_tile), "trace walked while lost is held back")
	t.check(not s.map.is_traced(lost_tile), "and not drawn")
	var img := MapScreen.render(s)
	var px := img.get_pixelv(lost_tile)
	t.check(absf(px.r - MapScreen.PAPER.r) < 0.01 and absf(px.g - MapScreen.PAPER.g) < 0.01 and absf(px.b - MapScreen.PAPER.b) < 0.01, "the map picture does not show it")
	s.debug_force_weather("clear")
	s.map.reveal_circle(s.outdoor_pos, 3)
	s.move(Vector2.LEFT, 0.05)
	t.check(s.map.is_traced(lost_tile), "trace appears once the marker returns")
	t.check(not s.map.has_pending(), "nothing left held back")


func test_map_share_and_debug(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_wipe_map()
	t.equal(s.map.percent_revealed(), 0.0, "blank at the start")
	s.debug_reveal_map()
	t.equal(s.map.percent_revealed(), 100.0, "debug reveal")
	s.debug_wipe_map()
	t.equal(s.map.percent_revealed(), 0.0, "debug wipe")


func test_home_area_starts_mapped(t: TestCase) -> void:
	var s := TestCase.new_session()
	var r := s.tuning.num("map.home_reveal_radius")
	t.check(s.map.is_revealed(s.ranger_tile()), "the station door is on mapped ground")
	t.near(float(s.map.revealed_count), _area(r), _area(r) * 0.08, "home area of radius %d revealed" % r)
	t.check(s.marker_visible(), "the marker shows at the start")
	t.check(not s.map.is_revealed(Vector2i(s.world.spawn("fork"))), "the rest of the map starts blank")
