extends SceneTree
## Phase 3 pictures: the gate with facilities and visitors, small placed
## things, litter and a troll badger, the catalog, the staff board, the book
## and the map with a lost party's circle. Saved to user://screenshots/.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_p3.gd

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
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _thing_near(s: GameSession, base: Vector2i, id: String, dx: int, dy: int) -> Vector2i:
	for r in range(0, 6):
		for oy in range(-r, r + 1):
			for ox in range(-r, r + 1):
				var c := base + Vector2i(dx + ox, dy + oy)
				if s.park.place_problem(c) == "":
					s.park.put_thing(c, id)
					return c
	return Vector2i(-1, -1)


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_p3.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.clock.season = 1
	for id: String in ["old_cabin", "outlook"]:
		ParkHelpers.ready_site(s, id)
	s.debug_build("gate_bathroom")
	s.debug_build("gate_picnic")
	var g := s.park.gate_node()
	var can := _thing_near(s, g, "trash_can", 14, 2)
	_thing_near(s, g, "bench", 20, -3)
	_thing_near(s, g, "picnic_table", 28, 3)
	_thing_near(s, g, "fire_ring", 34, 3)
	s.debug_set_can(can, 20)
	s.park.sim_day = s.clock.absolute_day()
	s.park.sim_minute = 480.0
	s.debug_set_time(8 * 60)
	for k: String in ["family", "day_hiker", "tour_group", "day_hiker"]:
		s.park.spawn(k, 4 if k == "family" else (8 if k == "tour_group" else 2))
	s.park.advance_to(486.0)
	s.debug_set_time(8 * 60)
	s.debug_teleport("station")
	s.outdoor_pos = Vector2(g) + Vector2(14, 1)
	main.world_view.reset_chunks()
	main.world_view.park_view.refresh()
	await _shot("3_gate_with_visitors")
	for i in 6:
		s.park.litter[g + Vector2i(12 + i, 4 + i % 2)] = i % 3
	s.debug_send_badger("gate")
	s.park.badgers[0]["tile"] = g + Vector2i(16, 4)
	s.park.changed.emit()
	s.outdoor_pos = Vector2(g) + Vector2(15, 2)
	main.world_view.reset_chunks()
	await _shot("3_litter_and_badger")
	s.debug_skip_day()
	s.debug_teleport("station")
	main.world_view.reset_chunks()
	s.enter_building("ranger_station")
	s.open_catalog()
	await _shot("3_catalog")
	main.choice_screen.close()
	s.open_staff_board()
	await _shot("3_staff_board")
	main.choice_screen.close()
	main.book_screen.open("ledger")
	await _shot("3_book_ledger")
	main.book_screen.show_page("park")
	await _shot("3_book_park")
	main.book_screen.close()
	s.leave_building()
	s.park.sim_minute = 480.0
	var p := s.park.spawn("day_hiker", 2)
	s.park.advance_to(600.0)
	s.park.lose(p, s.park._cur_tile(p))
	main.map_screen.open()
	await _shot("3_map_lost_party")
	main.map_screen.close()
	quit(0)
