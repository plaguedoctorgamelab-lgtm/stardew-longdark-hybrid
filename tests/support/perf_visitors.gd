extends SceneTree
## Windowed performance check for phase 3: 80 visitors in the park, 30 of
## them on screen around the ranger at the gate, the clock running. Reports
## frame times over 20 seconds.
## Run: godot --path . -s tests/support/perf_visitors.gd
## Exits 0 if at least 99% of frames take under 17.5 ms (60 frames a second).

var main: Node
var deltas: PackedFloat32Array = []


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void: quit(2))
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
	s.weather.today.assign(["clear", "clear", "clear"])
	s.clock.season = 1
	for id: String in ["old_cabin", "outlook"]:
		ParkHelpers.ready_site(s, id)
	s.debug_build("gate_bathroom")
	s.debug_build("gate_picnic")
	s.park.sim_day = s.clock.absolute_day()
	s.park.schedule = []
	s.debug_set_time(8 * 60)
	s.park.sim_minute = 480.0
	# 30 visitors near the gate, 50 more out on the trails.
	var near := 0
	while near < 30:
		s.park.spawn("tour_group", 10)
		near += 10
	s.park.advance_to(482.0)
	var far := 0
	while far < 50:
		var p := s.park.spawn("day_hiker", 2)
		p["pos"] = s.world.route("cabin")[100 + far * 4]
		s.park._replan_path(p)
		far += 2
	print("visitors in the park: ", s.park.visitors_in_park())
	s.outdoor_pos = Vector2(s.park.gate_node()) + Vector2(10, 0)
	main.world_view.reset_chunks()
	for i in 30:
		await process_frame
	var on_screen: int = main.world_view.park_view._people.size()
	print("drawn near the ranger: ", on_screen)
	var last := Time.get_ticks_usec()
	var start := last
	while Time.get_ticks_usec() - start < 20000000:
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
