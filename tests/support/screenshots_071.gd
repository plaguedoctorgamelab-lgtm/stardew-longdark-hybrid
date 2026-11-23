extends SceneTree
## Pictures of Mark's Art Request 20 pieces in the game: the station's new
## floor and catalog desk, a shop's floor, and a pad roped off with stakes
## and tape. Saved to user://screenshots/s071_*.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_071.gd

var main: Node


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(8)
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s071_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_071.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(11 * 60)
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	s.interior_pos = Vector2(5.5, 6.5)
	await _shot("1_station_floor_desk")
	s.leave_building()
	main._on_location_changed(s.location)
	var rc := s.park.pad_rect("gate_bathroom")
	s.outdoor_pos = Vector2(rc.position.x + rc.size.x / 2.0 - 1.5, rc.end.y + 1.6)
	await _frames(4)
	await _shot("2_roped_pad")
	s.town_open = true
	s.enter_town()
	s.town_pos = Vector2(50.5, 28.5)
	s.enter_town_room("percolator")
	await _shot("3_percolator_floor")
	quit(0)
