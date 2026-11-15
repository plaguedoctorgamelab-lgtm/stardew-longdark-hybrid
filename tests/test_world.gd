extends RefCounted
## World: chunks load and unload as the ranger moves; walking times to the
## four landmarks are within 10% of target. (Baking twice gives identical
## chunks is checked by tools/run_tests.py, since baking is a Python tool.)

var _tree: SceneTree


func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func test_chunks_load_and_unload(t: TestCase) -> void:
	var s := TestCase.new_session()
	var view := WorldView.new()
	_scene_tree().root.add_child(view)
	var r := RangerSprite.new()
	view.setup(s, r)
	view.update_chunks(true)
	var first := view.loaded.keys().duplicate()
	t.check(first.size() > 0 and first.size() <= 9, "a few chunks loaded at the station (%d)" % first.size())
	t.check(view.loaded.has(s.world.chunk_of(s.ranger_tile())), "the ranger's chunk is loaded")
	s.debug_teleport("cabin")
	view.update_chunks(true)
	var second := view.loaded.keys()
	t.check(second.size() <= 9, "still only a few chunks loaded (%d)" % second.size())
	for c: Vector2i in first:
		t.check(not view.loaded.has(c), "chunk %s near the station was unloaded" % c)
	t.check(view.loaded.has(s.world.chunk_of(s.ranger_tile())), "the cabin's chunk is loaded")
	t.check(view.ground_layer.get_cell_source_id(s.ranger_tile()) >= 0, "ground drawn under the ranger")
	t.check(view.ground_layer.get_cell_source_id(Vector2i(5, 230)) < 0, "ground near the station no longer drawn")
	# Gradual loading while walking: work is spread over frames.
	s.debug_teleport("station")
	view.update_chunks(true)
	s.outdoor_pos += Vector2(40, 0)
	view.update_chunks(false)
	t.check(view.is_busy(), "new chunks are placed over several frames")
	var frames := 1
	while view.is_busy() and frames < 1000:
		view.update_chunks(false)
		frames += 1
	t.check(frames > 1 and not view.is_busy(), "all placed after %d frames" % frames)
	t.check(view.loaded.has(s.world.chunk_of(s.ranger_tile())), "the new chunk is in place")
	view.queue_free()


func test_data_cache_is_trimmed(t: TestCase) -> void:
	var s := TestCase.new_session()
	for x in range(5, 380, 8):
		s.world.ground_at(Vector2i(x, 100))
	s.world.trim_cache(Vector2i(0, 3), 1)
	for c: Vector2i in s.world.cached_chunks():
		t.check(absi(c.x) <= 1, "far chunk %s dropped from memory" % c)


## Walks the ranger along a trail route with the real movement code, in clear
## weather, and returns the game minutes it takes.
func _walk_route(s: GameSession, route_name: String) -> float:
	var pts := s.world.route(route_name)
	s.outdoor_pos = pts[0]
	var dt := 1.0 / 60.0
	var seconds := 0.0
	var i := 1
	var guard := 0
	while i < pts.size() and guard < 200000:
		guard += 1
		var to := pts[i] - s.outdoor_pos
		if to.length() < 0.15:
			i += 1
			continue
		var step := s.speed_tiles_per_second() * dt
		if step >= to.length():
			# Arrive exactly, counting only the fraction of the frame used.
			seconds += dt * to.length() / step
			s.outdoor_pos = pts[i]
			i += 1
			continue
		s.move(to, dt)
		seconds += dt
	var real_per_step := s.tuning.num("time.real_seconds_per_step")
	return seconds / real_per_step * s.tuning.num("time.minutes_per_step")


func test_walking_times(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_drain(false, false)
	var targets: Dictionary = s.world.meta["route_targets_minutes"]
	for route: String in ["forest_edge", "fork", "outlook", "cabin"]:
		var minutes := _walk_route(s, route)
		var target := float(targets[route])
		print("        walk to %-12s %5.1f game minutes (target %d)" % [route, minutes, target])
		t.near(minutes, target, target * 0.10, "walking time to %s" % route)


func test_routes_reach_their_landmarks(t: TestCase) -> void:
	var s := TestCase.new_session()
	var cabin := s.world.route("cabin")
	t.check(cabin[cabin.size() - 1].distance_to(s.door_front("test_cabin")) < 2.0, "cabin route ends at the cabin door")
	var outlook := s.world.route("outlook")
	t.check(outlook[outlook.size() - 1].distance_to(s.world.landmark_pos("scenic_outlook")) < 2.0, "outlook route ends at the outlook")
	var edge := s.world.route("forest_edge")
	var end := edge[edge.size() - 1]
	t.check(s.world.ground_at(Vector2i(floori(end.x) + 2, floori(end.y))) == "forest_floor" or s.world.ground_at(Vector2i(floori(end.x) + 3, floori(end.y))) == "forest_floor", "forest edge route ends where the trees begin")


func test_ford_is_shallow_and_pool_is_deep(t: TestCase) -> void:
	var s := TestCase.new_session()
	var fork := s.world.route("fork")
	var crossed_shallows := false
	for p in fork:
		var g := s.world.ground_at(Vector2i(floori(p.x), floori(p.y)))
		t.check(g != "deep_water", "the trail never crosses deep water")
		if g == "shallows":
			crossed_shallows = true
	t.check(crossed_shallows, "the trail fords the stream through shallows")
	var pool: Array = [221, 62]
	t.equal(s.world.ground_at(Vector2i(int(pool[0]), int(pool[1]))), "deep_water", "the pool north of the ford is deep")
