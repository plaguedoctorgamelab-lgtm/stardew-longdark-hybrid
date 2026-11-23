extends SceneTree
## The gear wall (0.7.9): the pack page with the ID card, the opened pack and
## the gear wall, an item tag, the patches over other pages, and a chest. Saved to
## user://screenshots/s079_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_079.gd

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
	var path := "user://screenshots/s079_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_079.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	for it: Array in [["hot_soup", 2], ["berries", 7], ["planks", 12], ["nails", 20], ["glowcap", 1], ["painted_stone", 1], ["wool_coat", 1]]:
		s.backpack.add(it[0], it[1])
	s.park.money.earn(s.clock.absolute_day(), "test", 1240)
	s.wardrobe.keep("rain_shell")
	s.wardrobe.keep("waterproof_boots")
	s.backpack.add("wool_toque", 1)
	s.put_on("wool_toque")
	main.open_tab("backpack")
	await _shot("1_backpack")
	var inv: InventoryScreen = main.inventory_screen
	var k := 0
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "hot_soup":
			k = i
	var b: Button = inv._pack_buttons[k]
	root.warp_mouse(b.get_global_rect().get_center() * Vector2(root.size) / Vector2(480, 270))
	inv._on_hover(k, true)
	await _shot("2_tooltip")
	inv._tip.hide_tip()
	for id: String in ["jobs", "map", "people", "crafting", "book"]:
		main.open_tab(id)
		await _shot("3_tab_" + id)
	main.open_tab("")
	main.inventory_screen.open(s.structures.chests["ranger_station"], s.content.text("ui_chest"))
	await _shot("4_chest")
	quit(0)
