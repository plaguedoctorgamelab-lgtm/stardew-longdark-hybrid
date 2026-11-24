extends SceneTree
## Phase 4b (0.7.12): the festivals in the square, Esme's cards, the garden,
## the station upgraded and decorated, and (for the lab only, a spoiler) a
## heart event under way. Saved to user://screenshots/s4b_*. Not part of the
## automated tests.
## Run: godot --path . -s tests/support/screenshots_4b.gd

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
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s4b_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _clear_messages() -> void:
	var hud: Hud = main.hud
	if hud.has_method("clear_messages"):
		hud.call("clear_messages")


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_4b.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.park.money.earn(s.clock.absolute_day(), "test", 6000)
	# The festivals, each in the square.
	for id: String in ["thaw_fair", "lantern_night", "big_foot_supper", "long_night"]:
		s.debug_start_festival(id)
		var c: Array = s.festivals.row(id)["center"]
		s.town_pos = Vector2(float(c[0]) + 0.5, float(c[1]) + 3.5)
		main._on_location_changed(s.location)
		await _shot("1_fest_" + id)
		s.festivals.end()
	# Esme's reading.
	s.fortune.read_day = -1
	var r := s.fortune.reading(true)
	main.fortune_screen.open(r)
	main.fortune_screen._t = 10.0
	await _shot("2_fortune")
	main.fortune_screen.close()
	# The garden in summer, and the station after all three upgrades.
	s.leave_town()
	s.clock.season = 1
	s.clock.day = 3
	s.debug_set_time(11 * 60)
	var crops := ["seeds_tomato", "seeds_beans", "seeds_corn"]
	for y in s.garden.size.y:
		for x in s.garden.size.x:
			var t := s.garden.origin + Vector2i(x, y)
			s.garden.dig(t)
			if y < 4:
				var seed: String = crops[x % 3]
				s.backpack.add(seed, 1)
				s.garden.plant(t, seed)
				s.garden.tiles[t]["grown"] = (x + y) % 9
			if (x + y) % 2 == 0:
				s.garden.water(t)
	s.outdoor_pos = Vector2(s.garden.origin) + Vector2(3.5, 7.2)
	main._on_location_changed(s.location)
	await _shot("3_garden")
	s.debug_finish_upgrade()
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 2.5)
	main._on_location_changed(s.location)
	await _shot("4_shipshape")
	s.debug_finish_upgrade()
	s.debug_finish_upgrade()
	main._on_location_changed(s.location)
	await _shot("5_two_rooms")
	# Inside, decorated, with a piece held over the floor.
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	for it: Array in [["deco_loveseat", [14.5, 6.5], 1], ["deco_monstera", [18.5, 6.5], 1], ["interior_rug_round", [15.5, 7.5], 0], ["deco_floor_lamp", [11.5, 5.5], 1], ["deco_bookshelf_low", [13.5, 3.5], 2]]:
		s.backpack.add(it[0], 1)
		s.interior_pos = Vector2(float(it[1][0]), float(it[1][1]))
		s.facing = int(it[2])
		s.home.place_held(it[0])
	s.backpack.add("deco_park_map", 1)
	s.interior_pos = Vector2(12.5, 3.5)
	s.facing = GameSession.FACING_UP
	s.home.place_held("deco_park_map")
	s.backpack.add("wallpaper_pines", 1)
	s.home.place_held("wallpaper_pines")
	s.backpack.add("flooring_herringbone", 1)
	s.home.place_held("flooring_herringbone")
	s.backpack.add("deco_rocking_chair", 1)
	var k := -1
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "deco_rocking_chair":
			k = i
	if k >= s.bar_slots():
		s.backpack.swap(0, k)
		k = 0
	s.selected_slot = maxi(0, k)
	s.interior_pos = Vector2(7.5, 6.5)
	s.facing = GameSession.FACING_RIGHT
	s.structures.changed.emit("ranger_station")
	await _shot("6_decorated")
	# A heart event under way (lab only: a spoiler).
	s.leave_building()
	s.debug_set_hearts("gus", 2)
	s.debug_set_time(10 * 60)
	s.debug_set_weekday("mon")
	s.enter_town()
	s.enter_town_room("carpentry")
	main._on_location_changed(s.location)
	s.debug_play_event("he_gus_2")
	await _shot("9_event_spoiler")
	quit(0)
