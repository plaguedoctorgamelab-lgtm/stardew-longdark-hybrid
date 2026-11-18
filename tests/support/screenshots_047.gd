extends SceneTree
## Pictures of the 0.4.7 tracker fixes: the job page with the tower found,
## the map's dig flags, the workbench with its box and recipe uses, the
## Options screen, and the wake-up note after passing out from cold.
## Saved to user://screenshots/t047_*.png. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_047.gd

var main: Node


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/t047_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_047.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.enter_building("ranger_station")
	s.read_note_board()
	main._close_dialog(false)
	s.leave_building()
	s.sites_found["static_tower"] = true
	s.debug_site_step("static_tower", "map", true)
	s.debug_add_item("planks", 5)
	s.debug_add_item("nails", 12)
	main.book_screen.open("jobs")
	await _shot("1_jobs")
	main.book_screen.close()
	s.map.reveal_circle(s.door_front("ranger_station"), 60)
	s.map.reveal_circle(s.world.landmark_pos("static_tower"), 30)
	main.map_screen.zoom_index = 1
	main.map_screen.open()
	await _shot("2_map_flags")
	main.map_screen.close()
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	s.learn_recipe("boardwalk")
	await _frames(4)
	await _shot("3_new_recipe")
	main._close_dialog(false)
	main.choice_screen.open_workbench()
	await _shot("4_workbench")
	main.choice_screen.close()
	main.open_pause()
	main.open_options()
	await _shot("5_options")
	main.close_options()
	main.close_pause()
	s.leave_building()
	main._on_location_changed(s.location)
	s.needs.set_values(s.needs.max_energy(), 0.0)
	s._check_collapse()
	await _shot("6_passed_out")
	quit(0)
