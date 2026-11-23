extends SceneTree
## Pictures of Art Request 21 in the game: the townsfolk in their own
## sprites, and the playtest start's park. Saved to user://screenshots/s074_*.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_074.gd

var main: Node


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/s074_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_074.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(9 * 60)
	await _frames(5)
	main.map_screen.open()
	await _shot("1_playtest_map")
	main.map_screen.close()
	s.enter_town()
	main._on_location_changed(s.location)
	# Everyone lined up on the square for the picture, facing each way.
	s.debug_set_time(12 * 60 + 30)
	s.town.place_everyone()
	var at := Vector2(s.town.places["square_green"]) + Vector2(0.5, 0.5)
	var k := 0
	for id: String in s.town.people:
		var p: Dictionary = s.town.people[id]
		p["pos"] = at + Vector2(-6 + (k % 6) * 2.2, -1.5 + (k / 6) * 3.0)
		p["path"] = []
		p["goal"] = "square_green"
		p["facing"] = [GameSession.FACING_DOWN, GameSession.FACING_RIGHT, GameSession.FACING_LEFT, GameSession.FACING_UP][k % 4] if k >= 6 else GameSession.FACING_DOWN
		k += 1
	s.town_pos = at + Vector2(0, 4.5)
	await _frames(10)
	await _shot("2_town_people")
	# The outfitters' list, then the ranger in a wool coat and toque.
	s.debug_set_time(10 * 60)
	s.town_pos = s.town_pos
	s.enter_town_room("outfitters")
	main._on_location_changed(s.location)
	s.list_requested.emit("buy:outfitters", s.list_title("buy:outfitters"), s.list_options("buy:outfitters"))
	await _shot("3_outfitters")
	main.choice_screen.visible = false
	for id: String in ["wool_coat", "wool_toque", "insulated_boots"]:
		s.backpack.add(id, 1)
		s.put_on(id)
	s.leave_town_room()
	main._on_location_changed(s.location)
	await _frames(10)
	await _shot("4_wearing_out")
	main.inventory_screen.open(null, "")
	await _shot("5_backpack")
	main.inventory_screen.close()
	# The People page and the calendar, with a few friends made.
	for id: String in ["wren", "rosa", "teo", "gus", "agnes", "pip", "bev", "sol"]:
		s.town.met[id] = true
	s.town.add_points("wren", 2 * 250 + 30)
	s.town.add_points("gus", 4 * 250)
	s.town.add_points("pip", 250)
	s.town.talked_day["wren"] = s.clock.absolute_day()
	s.town.gifts_week["gus"] = [s.clock.absolute_day() / 7, 1]
	main.social_screen.open()
	await _shot("6_people")
	main.social_screen.turn()
	await _shot("7_calendar")
	quit(0)
