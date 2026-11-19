extends SceneTree
## Pictures of the jobs rebuild: the untidy station, the pinned note and a
## toast, the branch on the trail, the clipboard with the first job, the
## finishing card, the map's flourish and job flags, the clipboard full, a
## season's card. Saved to user://screenshots/jobs_*.png. Not part of the
## automated tests. Run: godot --path . -s tests/support/screenshots_jobs.gd

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
	var path := "user://screenshots/jobs_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_jobs.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(9 * 60)
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	s.interior_pos = Vector2(5.5, 6.5)
	await _shot("1_station_untidy")
	main.clipboard.open()
	await _shot("2_clipboard_first_job")
	main.clipboard.close()
	s.jobs.work_spot("station_papers")
	s.jobs.work_spot("station_shelf")
	await _shot("3_note_and_toasts")
	s.jobs.work_spot("station_boots")
	s.leave_building()
	main._on_location_changed(s.location)
	s.outdoor_pos = Vector2(22.5, 1440.5)
	await _shot("4_branch")
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
	await _shot("5_finishing_card")
	main.job_card.try_close()
	await _frames(10)
	main._process(0.1)
	await create_timer(1.2).timeout
	await _shot("6_map_flourish")
	main.map_screen.close()
	s.jobs.toggle_pin("open_cabin")
	main.clipboard.open("open_cabin")
	await _shot("7_clipboard_cabin")
	main.clipboard.open("spruce_gate")
	await _shot("8_clipboard_gate")
	main.clipboard.set_tab("done")
	await _shot("9_clipboard_done")
	main.clipboard.close()
	s.map.reveal_circle(s.door_front("ranger_station"), 80)
	main.map_screen.zoom_index = 1
	main.map_screen.open()
	await _shot("10_map_job_flags")
	main.map_screen.close()
	s.jobs.cards.append({"kind": "season", "season": "summer", "retired": 2, "new": 3})
	main._process(0.1)
	await create_timer(1.5).timeout
	await _shot("11_season_card")
	main.job_card.try_close()
	quit(0)
