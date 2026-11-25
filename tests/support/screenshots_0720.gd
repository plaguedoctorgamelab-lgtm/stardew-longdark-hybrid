extends SceneTree
## 0.7.20: Mark's tracker fixes (#46 to #65). Saved to
## user://screenshots/s0720_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_0720.gd

var main: Node


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s0720_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_0720.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.recipes_new.clear()
	s.jobs.unlocks["catalog"] = true
	s.debug_money(800)
	# The catalog sheet with things on order (#51).
	var lines: Array = []
	main.shop_sheet.open("catalog")
	lines = main.shop_sheet.catalog_lines()
	if not lines.is_empty():
		main.shop_sheet._do_order(str(lines[0]["id"]))
		main.shop_sheet._do_order(str(lines[0]["id"]))
	if lines.size() > 2:
		main.shop_sheet._do_order(str(lines[2]["id"]))
	main.shop_sheet.refresh()
	await _shot("1_catalog")
	main.shop_sheet.close()
	# The pack: warmth beside each worn thing (#52).
	main.open_tab("backpack")
	await _shot("2_pack_warmth")
	main.open_tab("")
	# The sign question says where you are (#54).
	s.debug_teleport("fork")
	s.backpack.add("trail_sign", 2)
	s.backpack.add("hammer", 1)
	main.choice_screen.open("sign_place", s.sign_where_title(), s.sign_places())
	await _shot("3_sign_question")
	main.choice_screen.visible = false
	# The map circle for a put-down step (#55).
	s.jobs.add("point_fork", "test")
	s.jobs.pinned = "point_fork"
	main.open_tab("map")
	await _shot("4_map_circle")
	main.open_tab("")
	# The Town sheet's next-heart chip (#63).
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.town.add_points("marge", 130)
	main.social_screen.selected = "marge"
	main.open_tab("people")
	await _shot("5_town_next_heart")
	main.open_tab("")
	quit(0)
