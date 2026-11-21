extends SceneTree
## Pictures of 0.5.1: Art Request 16 in the game (the rooms furnished and
## bigger, lamps and windows at night, the new trees and calmer ground, the
## new item icons) and the jobs look carried into other screens. Saved to
## user://screenshots/s051_*.png. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_051.gd

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
	var path := "user://screenshots/s051_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _enter(s: GameSession, id: String, at: Vector2) -> void:
	s.enter_building(id)
	main._on_location_changed(s.location)
	s.interior_pos = at


func _out(s: GameSession, at: Vector2) -> void:
	if s.is_indoors():
		s.leave_building()
		main._on_location_changed(s.location)
	s.outdoor_pos = at
	main.world_view.update_chunks(true)


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_051.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	_enter(s, "ranger_station", Vector2(6.5, 8.5))
	await _shot("1_station_day")
	s.debug_set_time(22 * 60)
	await _shot("2_station_night")
	s.debug_set_time(10 * 60)
	s.debug_repair_all("test_cabin", true)
	s.debug_repair_all("static_tower", true)
	_out(s, s.door_front("ranger_station"))
	_enter(s, "test_cabin", Vector2(4.5, 7.5))
	await _shot("3_cabin_day")
	s.debug_set_time(22 * 60)
	await _shot("4_cabin_night")
	s.debug_set_time(10 * 60)
	_out(s, s.door_front("test_cabin"))
	_enter(s, "static_tower", Vector2(4.5, 7.5))
	await _shot("5_tower")
	_out(s, s.door_front("test_cabin") + Vector2(0, 2))
	await _shot("6_cabin_outside_day")
	s.debug_set_time(22 * 60)
	await _shot("7_cabin_outside_night")
	s.debug_set_time(10 * 60)
	_out(s, Vector2(150.5, 1350.5))
	await _shot("8_forest")
	_out(s, s.door_front("ranger_station") + Vector2(0, 3))
	await _shot("9_station_grounds")
	for it in ["sticks", "stones", "reeds", "berries", "hazelnuts", "mushrooms", "glowcap", "rope", "cairn", "trail_mix", "true_compass", "glowcap_lantern"]:
		s.backpack.add(it, 1)
	_out(s, Vector2(12.5, 1442.5))
	s.park.put_thing(Vector2i(15, 1442), "trash_can")
	s.park.put_thing(Vector2i(16, 1442), "bench")
	s.park.put_thing(Vector2i(17, 1442), "picnic_table")
	main.dialog.visible = false
	s.recipes_new.clear()
	await _shot("13_gate")
	main.inventory_screen.open(s.structures.chests["ranger_station"], s.content.text("ui_chest"))
	await _shot("10_backpack_framed")
	main.inventory_screen.close()
	main.book_screen.open()
	await _shot("11_book_framed")
	main.book_screen.close()
	main.open_pause()
	main.open_options()
	await _shot("12_options_framed")
	quit(0)
