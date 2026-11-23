extends SceneTree
## Pictures of the 0.7.0 tracker fixes: the title's one-colour sky, the
## calmer station and shop floors, a hover tag and toasts, the bigger
## finishing card, and the map of Humdrum. Saved to user://screenshots/s070_*.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_070.gd

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
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s070_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	await _shot("1_title")
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_070.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(9 * 60)
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	s.interior_pos = Vector2(5.5, 6.5)
	main.hud.world_hint = "Bed: X to sleep"
	main.hud._update_tip()
	s.jobs.work_spot("station_papers")
	s.jobs.work_spot("station_shelf")
	await _shot("2_station_floor_tag_toasts")
	main.hud.world_hint = ""
	s.jobs.work_spot("station_boots")
	s.leave_building()
	main._on_location_changed(s.location)
	s.outdoor_pos = Vector2(22.5, 1440.5)
	s.backpack.add("axe")
	s.jobs.work_spot("station_branch")
	s.jobs.work_spot("station_can")
	var m := Vector2i(s.jobs.spot_pos("gate_marker"))
	s.park.put_thing(m, "trash_can")
	s.backpack.remove("trash_can", 1)
	s.jobs.update(true)
	await _frames(5)
	main._process(0.1)
	await create_timer(2.5).timeout
	await _shot("3_finishing_card")
	main.job_card.try_close()
	await _frames(10)
	main.map_screen.close()
	s.town_open = true
	s.enter_town()
	s.town_pos = Vector2(62, 31)
	await _frames(4)
	main.map_screen.open()
	await _shot("4_town_map")
	main.map_screen.close()
	s.town_pos = Vector2(50.5, 28.5)
	s.enter_town_room("percolator")
	await _shot("5_percolator_floor")
	quit(0)
