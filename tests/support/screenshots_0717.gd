extends SceneTree
## 0.7.17: the Pack, Map and Town sheets on the clipboard. Saved to
## user://screenshots/s0717_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_0717.gd

var main: Node


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s0717_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_0717.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.recipes_new.clear()
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	for it: Array in [["hot_soup", 2], ["berries", 7], ["planks", 12], ["nails", 20], ["painted_stone", 1], ["wool_coat", 1]]:
		s.backpack.add(it[0], it[1])
	s.wardrobe.keep("rain_shell")
	s.wardrobe.keep("waterproof_boots")
	s.park.money.earn(s.clock.absolute_day(), "test", 1240)
	s.recipes_new.clear()
	main.open_tab("backpack")
	await _shot("1_pack")
	main.inventory_screen.show_item("hot_soup", 2)
	await _shot("2_pack_pointed")
	main.open_tab("")
	main.inventory_screen.open(s.structures.chests["ranger_station"], s.content.text("ui_chest"))
	await _shot("3_chest")
	main.inventory_screen.close()
	if main.has_method("open_tab"):
		main.open_tab("map")
		await _shot("4_map")
		main.open_tab("people")
		await _shot("5_town")
		main.open_tab("")
	quit(0)
