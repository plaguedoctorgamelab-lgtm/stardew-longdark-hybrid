extends SceneTree
## Mark's 0.7.7 playtest fixes: the mailbox beside the station, the
## Ranger page, and orders shown in the catalog. Saved to
## user://screenshots/s078_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_078.gd

var main: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/s078_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_078.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.outdoor_pos = s.mailbox_pos() + Vector2(-0.5, 1.2)
	main._on_location_changed(s.location)
	await _shot("1_mailbox")
	s.wardrobe.keep("wool_coat")
	s.wardrobe.keep("wool_toque")
	s.wardrobe.keep("waterproof_boots")
	s.put_on("wool_toque")
	main.open_tab("backpack")
	await _shot("2_ranger_page")
	main.inventory_screen.close()
	s.park.money.wallet = 400
	s.park.order("planks")
	s.open_catalog()
	await _shot("3_catalog")
	quit(0)
