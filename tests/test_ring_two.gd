extends RefCounted
## Phase 2a, step 2: ring two is built around ring one. Its places can be
## reached in the planned times, its edges cannot be crossed, and ring one is
## unchanged apart from where the two join (checked tile by tile by
## tools/run_tests.py).


## Clears the fallen trunks lying across the routes, as a ranger who has done
## the trail work would find them.
func _clear_route_obstacles(s: GameSession) -> void:
	for o: Array in s.world.meta.get("obstacles_on_routes", []):
		s.debug_clear_obstacle(Vector2i(int(o[0]), int(o[1])))


func _walk(s: GameSession, route_name: String) -> float:
	var pts := s.world.route(route_name)
	s.outdoor_pos = pts[0]
	var dt := 1.0 / 60.0
	var seconds := 0.0
	var i := 1
	var guard := 0
	var stuck := 0
	while i < pts.size() and guard < 400000:
		guard += 1
		var to := pts[i] - s.outdoor_pos
		if to.length() < 0.15:
			i += 1
			continue
		var step := s.speed_tiles_per_second() * dt
		if step >= to.length():
			seconds += dt * to.length() / step
			s.outdoor_pos = pts[i]
			i += 1
			continue
		var before := s.outdoor_pos
		s.move(to, dt)
		seconds += dt
		if s.outdoor_pos.distance_to(before) < step * 0.2:
			stuck += 1
			if stuck > 120:
				return -1.0
		else:
			stuck = 0
	var real_per_step := s.tuning.num("time.real_seconds_per_step")
	return seconds / real_per_step * s.tuning.num("time.minutes_per_step")


func test_walking_times_to_ring_two(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_drain(false, false)
	_clear_route_obstacles(s)
	var targets: Dictionary = s.world.meta["route_targets_minutes"]
	for route: String in ["pond", "tower", "bridge"]:
		var minutes := _walk(s, route)
		var target := float(targets[route])
		print("        walk to %-12s %5.1f game minutes (target %d)" % [route, minutes, target])
		t.check(minutes > 0.0, "the walk to the %s is not blocked" % route)
		t.near(minutes, target, target * 0.10, "walking time to the %s" % route)


func test_ring_two_places(t: TestCase) -> void:
	var s := TestCase.new_session()
	var w := s.world
	for id in ["kettle_pond", "static_tower", "broken_bridge"]:
		t.check(w.meta["landmarks"].has(id), "%s is placed" % id)
		t.check(s.content.has("landmarks", id), "%s is a landmark" % id)
	t.check(not w.structure_placement("static_tower").is_empty(), "the fire tower stands in the world")
	t.check(not s.structures.is_open("static_tower"), "and starts run-down")
	t.equal(w.ground_at(Vector2i(w.landmark_pos("kettle_pond"))), "deep_water", "the pond is deep in the middle")


func test_ring_two_landmarks_can_be_mapped(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_needs(270, 100)
	for spot in ["pond", "bridge"]:
		s.debug_teleport(spot)
		var near := s.world.interactive_near(s.outdoor_pos, s.tuning.num("world.interact_reach_tiles") + 2.0)
		t.check(not near.is_empty(), "something to map near the %s" % spot)
		if near.is_empty():
			continue
		s.outdoor_pos = near["pos"] + Vector2(0, 1.2)
		s.interact()
	t.check(s.map.is_landmark_mapped("kettle_pond"), "the pond can be mapped")
	t.check(s.map.is_landmark_mapped("broken_bridge"), "the bridge can be mapped")
	s.debug_teleport("tower")
	s.interact()
	t.check(s.map.is_landmark_mapped("static_tower"), "the tower is mapped at its door")


func test_river_cannot_be_crossed(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("bridge")
	var start := s.outdoor_pos
	for i in 200:
		s.move(Vector2.RIGHT, 0.1)
	t.check(s.outdoor_pos.x < start.x + 20, "the broken bridge ends over deep water (walked %.1f tiles)" % (s.outdoor_pos.x - start.x))
	t.check(s.world.ground_at(s.ranger_tile() + Vector2i(2, 0)) == "deep_water", "deep water ahead")


func test_new_grounds(t: TestCase) -> void:
	var s := TestCase.new_session()
	var speeds: Dictionary = s.tuning.value("movement.ground_speed")
	t.equal(float(speeds["bog"]), float(speeds["shallows"]), "bog walks like shallows")
	t.check((s.tuning.value("energy.rough_grounds") as Array).has("bog"), "bog is rough going")
	t.equal(float(speeds["boards"]), 1.0, "bridge boards walk like trail")
