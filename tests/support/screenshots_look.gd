extends SceneTree
## Pictures of the park poster look's screens: the title screen, and more as
## they are built. Saved to user://screenshots/look_*.png. Not part of the
## automated tests.
## Run: godot --path . -s tests/support/screenshots_look.gd

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
	var path := "user://screenshots/look_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	await create_timer(1.5).timeout
	await _shot("1_title")
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_look.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(10 * 60)
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 2)
	s.debug_add_item("planks", 12)
	s.debug_add_item("berries", 20)
	main.world_view.reset_chunks()
	main._hover_wait = 9999.0
	main.hud.world_hint = s.content.text("hint_x_go_in")
	await _shot("2_hud")
	main.hud.world_hint = ""
	main.inventory_screen.open(null, "")
	await _shot("3_backpack")
	main.inventory_screen.close()
	s.sites_found["old_cabin"] = true
	main.book_screen.open("jobs")
	await _shot("4_book")
	main.book_screen.close()
	s.debug_set_skill("trailcraft", 3)
	s.debug_set_skill("surveying", 5)
	s.debug_choose_specialty("cartographer")
	s.finds_found["glowcap"] = true
	main.book_screen.open("badges")
	await _shot("4b_badges")
	main.book_screen.close()
	main.choice_screen.open_station("anywhere")
	await _shot("5_crafting")
	main.choice_screen.close()
	main._show_dialog("notice", s.content.text("job_fix_cabin_offer"))
	await _shot("6_dialog")
	main._close_dialog(false)
	main.open_pause()
	await _shot("7_pause")
	main.close_pause()
	s.map.reveal_circle(s.door_front("ranger_station"), 40)
	s.map.mark_landmark("test_cabin")
	s.map.reveal_circle(s.world.landmark_pos("test_cabin"), 20)
	main.map_screen.zoom_index = 2
	main.map_screen.open()
	await _shot("8_map")
	main.map_screen.close()
	quit(0)
