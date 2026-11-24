extends SceneTree
## The UI review (24 November 2026): every menu page, list and tag as it is
## now, for the cozy-UI plan. Saved to user://screenshots/ui_*. Not part of
## the automated tests.
## Run: godot --path . -s tests/support/screenshots_ui_review.gd

var main: Node


func _initialize() -> void:
	create_timer(200.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/ui_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_ui_review.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	for it: Array in [["hot_soup", 2], ["berries", 7], ["planks", 12], ["nails", 20], ["glowcap", 1], ["painted_stone", 1], ["wool_coat", 1]]:
		s.backpack.add(it[0], it[1])
	s.park.money.earn(s.clock.absolute_day(), "test", 1240)
	s.park.notes.append({"day": 0, "text": "Strange tracks by the pond, too big for a bear."})
	await _shot("00_world")
	main.open_tab("backpack")
	await _shot("01_backpack")
	var inv: InventoryScreen = main.inventory_screen
	var k := 0
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "hot_soup":
			k = i
	var b: Button = inv._pack_buttons[k]
	root.warp_mouse(b.get_global_rect().get_center() * Vector2(root.size) / Vector2(480, 270))
	inv._on_hover(k, true)
	await _shot("02_item_tag")
	inv._tip.hide_tip()
	main.open_tab("jobs")
	await _shot("03_jobs")
	main.open_tab("map")
	await _shot("04_map")
	main.open_tab("people")
	await _shot("05_people")
	main.social_screen.turn()
	await _shot("06_people_2")
	main.social_screen.open("calendar")
	await _shot("07_calendar")
	main.open_tab("crafting")
	await _shot("08_crafting")
	main.open_tab("book")
	for pg: String in ["park", "ledger", "cards", "letters", "notes", "badges"]:
		main.book_screen.show_page(pg)
		await _shot("09_book_" + pg)
	main.open_tab("")
	main.inventory_screen.open(s.structures.chests["ranger_station"], s.content.text("ui_chest"))
	await _shot("10_chest")
	main.inventory_screen.close()
	main.choice_screen.open("shop:percolator", "The Percolator", s.shops.menu_options("percolator"))
	await _shot("11_shop_menu")
	main.choice_screen.close()
	main.choice_screen.open("buy:outfitters", "Outfitters", s.shops.buy_options("outfitters"))
	await _shot("12_shop_buy")
	main.choice_screen.close()
	main._face("gus", "happy")
	main._show_dialog("talk", "Morning, ranger! The crew's got the roof half done.")
	await _shot("13_talk")
	main.dialog.visible = false
	quit(0)
