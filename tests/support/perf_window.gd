extends SceneTree
## Windowed performance check: starts the real game, walks the ranger along
## the trails from the station through ring one and ring two to the broken
## bridge at three times trail speed (so
## chunks load faster than in play), with drawing on, and reports frame times.
## Run: godot --path . -s tests/support/perf_window.gd
## Exits 0 if at least 99% of frames take under 17.5 ms.

var main: Node
var deltas: PackedFloat32Array = []


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://perf_save.json"
	s.new_game(99)
	main._begin()
	s.debug_drain(false, false)
	s.debug_force_weather("rain")
	s.debug_set_time(17 * 60)
	s.tuning.set_value("movement.trail_speed_tiles", 13.5)
	for o: Array in s.world.meta.get("obstacles_on_routes", []):
		s.debug_clear_obstacle(Vector2i(int(o[0]), int(o[1])))
	var route := s.world.route("bridge")
	s.outdoor_pos = route[0]
	main.world_view.reset_chunks()
	for i in 30:
		await process_frame
	var i := 1
	var last := Time.get_ticks_usec()
	while i < route.size():
		var to := route[i] - s.outdoor_pos
		if to.length() < 0.6:
			i += 1
			continue
		s.move(to, 1.0 / 60.0)
		await process_frame
		var now := Time.get_ticks_usec()
		deltas.append((now - last) / 1000.0)
		last = now
	var sorted := deltas.duplicate()
	sorted.sort()
	var over := 0
	var total := 0.0
	for d in deltas:
		total += d
		if d > 17.5:
			over += 1
	var share := 100.0 * over / deltas.size()
	print("frames %d, average %.2f ms (%.1f fps), 99th percentile %.2f ms, worst %.2f ms, over 17.5 ms: %.2f%%" % [
		deltas.size(), total / deltas.size(), 1000.0 / (total / deltas.size()), sorted[int(sorted.size() * 0.99)], sorted[sorted.size() - 1], share])
	quit(0 if share < 1.0 else 1)
