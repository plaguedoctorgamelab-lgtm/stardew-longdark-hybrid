extends SceneTree
## Starts the real game in a window, sets up a few moments with the debug
## tools, and saves a picture of each to user://screenshots/. Used by the lab
## to check what the game looks like; not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots.gd

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
	main._close_dialog(false)
	# Added after the first play: note board, job list, map hint, camp, stumps.
	var layout: InteriorLayout = s.interiors["ranger_station"]
	var board := layout.furniture_rect(layout.find("note_board"))
	s.interior_pos = Vector2(board.position.x + 0.5, board.end.y + 0.5)
	s.interact()
	await _shot("12_note_board")
	main._close_dialog(false)
	main._show_dialog("jobs", s.content.text("job_list_title") + "\n\n" + "\n".join(s.job_lines()))
	await _shot("13_job_list")
	main._close_dialog(false)
	s.leave_building()
	s.debug_wipe_map()
	s.map.reveal_circle(s.door_front("ranger_station"), 20)
	main.map_screen.open()
	await _shot("14_map_cabin_hint")
	main.map_screen.close()
	s.debug_teleport("fork")
	main.world_view.reset_chunks()
	s.debug_add_item("axe")
	s.debug_add_item("bedroll")
	s.debug_add_item("firewood", 3)
	s.outdoor_pos += Vector2(3, 3)
	for i in 3:
		s.facing = i % 4
		s.chop()
	s.facing = GameSession.FACING_RIGHT
	s.make_camp()
	s.outdoor_pos += Vector2(0, 1.2)
	s.debug_set_time(22 * 60)
	s.debug_force_weather("clear")
	s.selected_slot = 0
	await _shot("15_camp_at_night")
	# Phase 2a: ring two, the tower, signs and the bigger map.
	s.debug_set_time(11 * 60)
	for spot in ["pond", "tower", "bridge"]:
		s.debug_teleport(spot)
		main.world_view.reset_chunks()
		await _shot("2a_%s" % spot)
	s.debug_teleport("tower")
	for st: Dictionary in s.content.row("structures", "static_tower")["repair_steps"]:
		s.structures.debug_complete_step("static_tower", st["id"])
	main.world_view.reset_chunks()
	await _shot("2a_tower_repaired")
	s.enter_building("static_tower")
	await _shot("2a_tower_inside")
	s.start_survey()
	s.pass_minutes(30)
	s.leave_building()
	s.debug_teleport("fork")
	main.world_view.reset_chunks()
	var front := s.ranger_tile() + Vector2i(0, -2)
	s.debug_put_up(front, "trail_marker")
	s.debug_add_item("shovel")
	s.outdoor_pos += Vector2(4, 4)
	s.facing = GameSession.FACING_RIGHT
	s.dig()
	s.dig()
	await _shot("2a_marker_and_dug_trail")
	main.map_screen.open()
	main.map_screen.change_zoom(-2)
	await _shot("2a_map_zoomed_out")
	main.map_screen.close()
	s.debug_teleport("station")
	main.world_view.reset_chunks()
	s.enter_building("ranger_station")
	s.debug_add_item("planks", 6)
	s.debug_add_item("nails", 6)
	main.choice_screen.open_workbench()
	await _shot("2a_workbench")
	quit(0)
