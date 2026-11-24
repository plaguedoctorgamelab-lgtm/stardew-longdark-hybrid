extends SceneTree
## 0.7.19: the Log, the shops, Jobs, and the world without tags (the action
## chip and the toast). Saved to user://screenshots/s0719_*. Not part of the
## automated tests. Run: godot --path . -s tests/support/screenshots_0719.gd

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
	var path := "user://screenshots/s0719_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_0719.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.recipes_new.clear()
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.park.money.earn(s.clock.absolute_day(), "jobs", 240)
	s.park.money.earn(s.clock.absolute_day(), "entrance", 60)
	s.park.add_note("Behind a loose board: a chipped mug, painted with a moose. It's still warm.", "strange")
	s.park.add_note("A badger has dug in by the gate.", "badger")
	s.park.letters.append({"day": 0, "text": "Ranger, welcome to Dusk River. The station is yours. Keep the trails open and the visitors happy. - The Chief", "read": true})
	s.recipes_new.clear()
	main.open_tab("book")
	await _shot("1_log_park")
	main.book_screen.show_page("ledger")
	await _shot("2_log_ledger")
	main.book_screen.show_page("notes")
	main.book_screen.selected = s.park.notes.size() - 2
	main.book_screen.refresh()
	await _shot("3_log_notes")
	main.book_screen.show_page("letters")
	await _shot("4_log_letters")
	main.open_tab("jobs")
	await _shot("5_jobs")
	main.open_tab("")
	s.backpack.add("berries", 6)
	main.shop_sheet.open("percolator")
	await _shot("6_shop_percolator")
	main.shop_sheet.close()
	main.shop_sheet.open("outfitters")
	main.shop_sheet.tab = "sell"
	main.shop_sheet.refresh()
	await _shot("7_shop_sell")
	main.shop_sheet.close()
	s.recipes_new.append("trail_mix")
	main.hud.world_hint = s.content.text("hint_x_go_in")
	await _shot("8_world_chip_toast")
	quit(0)
