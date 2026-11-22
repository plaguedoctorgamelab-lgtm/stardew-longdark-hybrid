extends SceneTree
## Pictures of 0.5.4: the old cabin to the Interior Art Guide, the faced
## piece's name, the fog and snow overlay, and the station fading when the
## ranger walks behind it. Saved to
## user://screenshots/s054_*.png. Not part of the automated tests.
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
	var path := "user://screenshots/s054_%s.png" % name
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
	s.save_path = "user://screenshots/save_054.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.debug_repair_all("test_cabin", true)
	_out(s, s.door_front("test_cabin"))
	s.enter_building("test_cabin")
	main._on_location_changed(s.location)
	main.dialog.visible = false
	var layout: InteriorLayout = s.interiors["test_cabin"]
	var r := layout.furniture_rect(layout.find("stove"))
	s.interior_pos = Vector2(r.get_center().x, r.end.y + 0.6)
	s.facing = GameSession.FACING_UP
	await _shot("1_cabin_day")
	s.debug_set_time(22 * 60)
	s.backpack.add("firewood", 3)
	s.feed_stove()
	await _shot("2_cabin_night")
	s.debug_set_time(10 * 60)
	_out(s, s.door_front("ranger_station") + Vector2(0, 4))
	s.debug_force_weather("fog")
	await _shot("3_fog")
	s.debug_force_weather("snow")
	await _shot("4_snow")
	s.debug_force_weather("clear")
	_out(s, s.door_front("ranger_station") + Vector2(0, -2.5))
	await create_timer(0.6).timeout
	await _shot("5_behind_station")
	quit(0)
