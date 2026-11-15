extends RefCounted
## Movement: speed on each ground type matches tuning; solid objects and map
## edges block; bad weather and exhaustion slow walking.


## Finds an open stretch of the given ground, running east or south.
func _find_ground(s: GameSession, ground: String, dir: Vector2i) -> Vector2:
	var w := s.world
	var side := Vector2i(dir.y, dir.x)
	var b := w.baked_bounds()
	for y in range(b.position.y + 4, b.end.y - 12):
		for x in range(b.position.x + 4, b.end.x - 12):
			var ok := true
			for k in range(-1, 10):
				for j in range(-1, 2):
					var t := Vector2i(x, y) + dir * k + side * j
					if w.ground_at(t) != ground or w.is_solid(t):
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2(x + 0.5, y + 0.5)
	return Vector2(-1, -1)


func _measure_speed(s: GameSession, ground: String) -> float:
	for dir: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		var p := _find_ground(s, ground, dir)
		if p.x < 0:
			continue
		s.outdoor_pos = p
		var start := s.outdoor_pos
		for i in 10:
			s.move(Vector2(dir), 0.1)
		return start.distance_to(s.outdoor_pos)
	return -1.0


func test_ground_speeds(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	var base := s.tuning.num("movement.trail_speed_tiles")
	var table: Dictionary = s.tuning.value("movement.ground_speed")
	for g: String in ["trail", "grass", "forest_floor", "tall_grass", "shallows"]:
		var v := _measure_speed(s, g)
		t.check(v >= 0.0, "found a stretch of %s to walk on" % g)
		if v >= 0.0:
			t.near(v, base * float(table[g]), 0.01, "speed on %s" % g)


func test_trail_speed_is_fastest(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	var trail := _measure_speed(s, "trail")
	for g: String in ["grass", "forest_floor", "tall_grass", "shallows"]:
		t.check(_measure_speed(s, g) < trail, "%s is slower than trail" % g)


func test_weather_slows_walking(t: TestCase) -> void:
	var s := TestCase.new_session()
	var table: Dictionary = {"rain": 0.95, "storm": 0.85, "snow": 0.85, "blizzard": 0.6}
	for w: String in table:
		s.debug_force_weather(w)
		var v := _measure_speed(s, "grass")
		t.near(v, s.tuning.num("movement.trail_speed_tiles") * 0.9 * float(table[w]), 0.01, "grass speed in %s" % w)


func test_exhausted_slows_walking(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_drain(false, false)
	s.debug_set_needs(10, 100)
	var v := _measure_speed(s, "trail")
	t.near(v, 4.5 * 0.6, 0.01, "exhausted trail speed")


func test_objects_block(t: TestCase) -> void:
	var s := TestCase.new_session()
	var w := s.world
	# Find a tree with open ground on its west side, and walk into it.
	for cy in w.chunk_count().y:
		for cx in w.chunk_count().x:
			for o: Array in w.objects_in_chunk(Vector2i(cx, cy)):
				if not str(o[2]).begins_with("tree"):
					continue
				var tile := Vector2i(cx * 32 + int(o[0]), cy * 32 + int(o[1]))
				var west := tile + Vector2i(-2, 0)
				if w.is_solid(west) or w.is_solid(tile + Vector2i(-1, 0)):
					continue
				s.outdoor_pos = Vector2(west.x + 0.5, west.y + 0.5)
				for i in 30:
					s.move(Vector2.RIGHT, 0.1)
				t.check(s.outdoor_pos.x < tile.x, "tree at %s stops the ranger (stopped at %.2f)" % [tile, s.outdoor_pos.x])
				t.check(s.outdoor_pos.x > tile.x - 0.4, "ranger reaches the tree")
				return
	t.check(false, "found a tree to test against")


func test_buildings_block(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := s.world.structure_placement("ranger_station")
	s.outdoor_pos = Vector2(float(p["pos"][0]) + 1.5, float(p["pos"][1]) + float(p["size"][1]) + 1.5)
	for i in 30:
		s.move(Vector2.UP, 0.1)
	t.check(s.outdoor_pos.y >= float(p["pos"][1]) + float(p["size"][1]), "station wall stops the ranger")


func test_water_and_edges_block(t: TestCase) -> void:
	var s := TestCase.new_session()
	# Map edge: walk west from near the west edge.
	s.outdoor_pos = Vector2(s.world.r1(5, 100)) + Vector2(0.5, 0.5)
	for i in 60:
		s.move(Vector2.LEFT, 0.1)
	t.check(s.outdoor_pos.x >= 3.0, "the edge of the map blocks (x=%.2f)" % s.outdoor_pos.x)
	# Deep water blocks.
	var w := s.world
	var found := false
	var o := w.ring_one_offset()
	for y in range(20 + o.y, 200 + o.y):
		for x in range(200 + o.x, 240 + o.x):
			if w.ground_at(Vector2i(x, y)) == "deep_water" and not w.is_solid(Vector2i(x - 4, y)) and w.ground_at(Vector2i(x - 1, y)) != "deep_water":
				s.outdoor_pos = Vector2(x - 3.5, y + 0.5)
				for i in 30:
					s.move(Vector2.RIGHT, 0.1)
				t.check(s.outdoor_pos.x < x, "deep water blocks")
				found = true
				break
		if found:
			break
	t.check(found, "found deep water to test")


func test_eight_directions_four_facings(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.outdoor_pos = s.world.spawn("station") + Vector2(6, 0)
	var start := s.outdoor_pos
	s.move(Vector2(1, -1), 0.2)
	t.check(s.outdoor_pos.x > start.x and s.outdoor_pos.y < start.y, "diagonal move")
	t.check(s.facing in [GameSession.FACING_RIGHT, GameSession.FACING_UP], "faces one of four")
	s.move(Vector2.LEFT, 0.05)
	t.equal(s.facing, GameSession.FACING_LEFT, "faces left")
	s.move(Vector2.DOWN, 0.05)
	t.equal(s.facing, GameSession.FACING_DOWN, "faces down")
