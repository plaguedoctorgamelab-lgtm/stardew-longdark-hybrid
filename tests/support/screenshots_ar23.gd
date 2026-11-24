extends SceneTree
## Art Request 23 (0.7.13): Mark's last 4b pieces in the game: the judge's
## sash worn at the Big Foot Supper, the scaffolding over the station, the
## keepsakes in the backpack and on the station's walls, a sweetheart's
## heart on the People page and Wren's new portrait. Saved to
## user://screenshots/ar23_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_ar23.gd

const KEEPSAKES := ["ranger_mug", "teo_song", "town_key", "esme_card", "marge_coat", "judges_sash"]

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
	var path := "user://screenshots/ar23_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_ar23.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.park.money.earn(s.clock.absolute_day(), "test", 6000)
	# The judge's sash, facing down at the Big Foot Supper.
	s.debug_start_festival("big_foot_supper")
	var c: Array = s.festivals.row("big_foot_supper")["center"]
	s.town_pos = Vector2(float(c[0]) + 0.5, float(c[1]) + 3.5)
	s.facing = GameSession.FACING_DOWN
	main._on_location_changed(s.location)
	await _shot("1_sash")
	s.festivals.end()
	# Scaffolding while Gus's crew works.
	s.leave_town()
	s.debug_set_time(11 * 60)
	s.home.building = "shipshape"
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 2.5)
	main._on_location_changed(s.location)
	s.structures.changed.emit("ranger_station")
	await _shot("2_scaffold")
	s.home.building = ""
	s.structures.changed.emit("ranger_station")
	# The keepsakes on the station's walls and floor.
	s.enter_building("ranger_station")
	main._on_location_changed(s.location)
	for it: Array in [["pip_bigfoot_drawing", 2], ["ranger_painting", 2], ["gus_shelf", 2], ["carved_figure", 1]]:
		s.backpack.add(it[0], 1)
		s.facing = int(it[1])
		var placed := false
		for y in ([3.5] if int(it[1]) == 2 else [5.5, 6.5, 8.5, 9.5]):
			for x in range(1, 12):
				if placed:
					break
				s.interior_pos = Vector2(x + 0.5, y)
				placed = s.home.place_held(it[0]) == ""
		print(it[0], ": ", "placed" if placed else "no room")
	s.interior_pos = Vector2(8.5, 6.5)
	s.facing = GameSession.FACING_DOWN
	s.structures.changed.emit("ranger_station")
	await _shot("3_station_walls")
	# The keepsakes in the backpack.
	for k: String in KEEPSAKES:
		s.backpack.add(k, 1)
	main.inventory_screen.open(null, "")
	await _shot("4_backpack")
	main.inventory_screen.close()
	# Dating Wren: her heart on the People page, then her face in the talk box.
	s.town.debug_set_points("wren", 2000) if s.town.has_method("debug_set_points") else s.debug_set_hearts("wren", 8)
	s.life.dating["wren"] = true
	main.social_screen.open()
	await _shot("5_people")
	main.social_screen.close()
	for mood: String in ["happy"]:
		main._face("wren", mood)
		main._show_dialog("talk", "Wren (%s)." % mood)
		await _shot("6_wren_" + mood)
	quit(0)
