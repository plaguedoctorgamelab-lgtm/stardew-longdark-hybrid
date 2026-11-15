extends SceneTree
## Starts the real game in a window, sets up a few moments with the debug
## tools, and saves a picture of each to user://screenshots/. Used by the lab
## to check what the game looks like; not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots.gd

var main: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save.json"
	s.new_game(4242)
	main._begin()
	s.debug_force_weather("clear")
	s.debug_set_time(10 * 60)
	await _frames(10)
	await _shot("01_station_morning")
	s.debug_teleport("fork")
	main.world_view.reset_chunks()
	await _shot("02_fork")
	s.debug_teleport("cabin")
	main.world_view.reset_chunks()
	await _shot("03_cabin_broken")
	s.debug_set_time(21 * 60)
	s.selected_slot = 1
	await _shot("04_cabin_night_lantern")
	s.debug_set_time(12 * 60)
	s.debug_force_weather("fog")
	await _shot("05_fog")
	s.debug_force_weather("blizzard")
	await _shot("06_blizzard")
	for st in ["door", "walls", "roof", "window"]:
		s.debug_cabin_step(st, true)
	s.debug_force_weather("rain")
	await _shot("07_cabin_repaired_rain")
	s.enter_building("test_cabin")
	await _shot("08_cabin_inside")
	s.leave_building()
	s.debug_force_weather("clear")
	s.debug_teleport("outlook")
	main.world_view.reset_chunks()
	s.start_survey()
	s.pass_minutes(30)
	main.map_screen.open()
	await _shot("09_map_after_outlook_survey")
	main.map_screen.close()
	s.debug_teleport("station")
	main.world_view.reset_chunks()
	s.enter_building("ranger_station")
	await _shot("10_station_inside")
	s.use_radio()
	await _shot("11_radio")
	quit(0)
