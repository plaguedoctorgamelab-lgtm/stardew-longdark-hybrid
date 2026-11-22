extends SceneTree
## Pictures for tracker #26 and #27: the west stake gap, the pond approach,
## and the three interiors. Saved to user://screenshots/s061_*.png.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_061.gd

var main: Node


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(8)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s061_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _out(s: GameSession, at: Vector2) -> void:
	if s.is_indoors():
		s.leave_building()
		main._on_location_changed(s.location)
	s.outdoor_pos = at
	main.world_view.update_chunks(true)


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_061.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	main.dialog.visible = false
	s.jobs.add("stake_west", "debug")
	s.jobs.add("reopen_pond_trail", "debug")
	var gp: Dictionary = s.jobs.gap("stake_gap_west")
	var tiles: Array = gp["tiles"]
	for f in [0.25, 0.5]:
		var p: Array = tiles[int(f * (tiles.size() - 1))]
		_out(s, Vector2(float(p[0]) + 0.5, float(p[1]) + 0.5))
		await _shot("west_gap_%d" % int(f * 100))
	var pts: Array = s.world.meta["trail_job_points"]["pond_trunks"]
	_out(s, Vector2(float(pts[0][0]) + 0.5, float(pts[0][1]) + 1.5))
	await _shot("pond_trunks")
	for b in ["ranger_station", "test_cabin", "static_tower"]:
		for st in s.structures.steps_remaining(b):
			s.structures.debug_complete_step(b, st)
		_out(s, s.door_front(b))
		if s.enter_building(b):
			main._on_location_changed(s.location)
			await _shot("inside_" + b)
	quit(0)
