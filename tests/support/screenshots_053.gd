extends SceneTree
## Pictures of 0.5.3: Mark's station furniture, sent again on a plain
## background, and the water's new shore and movement. Saved to
## user://screenshots/s053_*.png. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_053.gd

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
	var path := "user://screenshots/s053_%s.png" % name
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
	s.save_path = "user://screenshots/save_053.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	s.interior_pos = Vector2(6.5, 7.5)
	main.dialog.visible = false
	await _shot("1_station_day")
	s.debug_set_time(22 * 60)
	await _shot("2_station_night")
	s.debug_set_time(10 * 60)
	_out(s, s.site_door("kettle_pond") + Vector2(0, 2))
	await _shot("3_pond_a")
	await create_timer(1.0).timeout
	await _shot("4_pond_b")
	_out(s, s.door_front("ranger_station") + Vector2(0, 3))
	await _shot("5_station_grounds")
	quit(0)
