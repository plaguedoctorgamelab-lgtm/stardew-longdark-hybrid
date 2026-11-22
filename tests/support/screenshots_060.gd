extends SceneTree
## Pictures of 0.6.0: Humdrum, the town through the gate, its people, a
## talk with Wren, and Main Street at night. Saved to
## user://screenshots/s060_*.png. Not part of the automated tests.
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
	var path := "user://screenshots/s060_%s.png" % name
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
	s.save_path = "user://screenshots/save_060.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.enter_town()
	main.dialog.visible = false
	s.debug_set_time(10 * 60)
	s.town.place_everyone()
	await _shot("1_arrive")
	s.town_pos = Vector2(50.5, 30.0)
	s.facing = GameSession.FACING_UP
	await _shot("2_percolator")
	s.town.talk("wren")
	s.interact()
	await _shot("3_talk_wren")
	main._close_dialog(false)
	s.town_pos = Vector2(36.5, 34.5)
	await _shot("4_square")
	s.town_pos = Vector2(30.5, 46.5)
	await _shot("5_creek")
	s.debug_set_time(21 * 60)
	s.town_pos = Vector2(60.5, 31.0)
	await _shot("6_main_street_night")
	quit(0)
