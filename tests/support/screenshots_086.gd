extends SceneTree
## 0.8.6 (Art Request 27): the new festival year and the birds. Midsummer's
## wicker moose standing and burning, Samhain in costume, the Big Foot
## Supper in the snow, Lantern Night in spring, birds in the park, an owl
## at night and the guide's Birds page. Saved to user://screenshots/s086_*.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_086.gd

var main: Node


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s086_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _fest(s: GameSession, id: String, dy: float) -> void:
	s.debug_start_festival(id)
	var c: Array = s.festivals.row(id)["center"]
	s.town_pos = Vector2(float(c[0]) + 0.5, float(c[1]) + dy)
	s.facing = GameSession.FACING_UP
	main._on_location_changed(s.location)
	main._dress_ranger()
	main.dialog.visible = false


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_086.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.recipes_new.clear()
	s.pet.choose("dog")
	s.pet.offered = true
	main.dialog.visible = false
	s.town_open = true
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	# Midsummer: the wicker moose standing, then burning.
	_fest(s, "midsummer", -1.0)
	await _shot("1_midsummer_moose")
	s.festivals.choose("fest:gave", "_word")
	main.dialog.visible = false
	await _shot("2_midsummer_burning")
	s.festivals.end()
	# Samhain, in costume.
	s.clock.year = 1
	_fest(s, "samhain", -1.0)
	await _shot("3_samhain")
	s.festivals.end()
	# The Big Foot Supper in the snow.
	_fest(s, "big_foot_supper", 0.5)
	await _shot("4_bigfoot_winter")
	s.festivals.end()
	# Lantern Night in spring.
	_fest(s, "lantern_night", 4.0)
	await _shot("5_lantern_spring")
	s.festivals.end()
	# Birds in the park by day.
	s.leave_town()
	s.clock.season = 1
	s.clock.day = 3
	s.debug_set_time(11 * 60)
	s.wildlife.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)
	var crow := {}
	for a: Dictionary in s.wildlife.animals:
		if str(a["id"]) == "crow":
			crow = a
			break
	if not crow.is_empty():
		s.outdoor_pos = Vector2(crow["home"]) + Vector2(-3, 1)
		for a: Dictionary in s.wildlife.animals:
			if str(a["kind"]) == "crow" or str(a["id"]) == "blue_jay" or str(a["id"]) == "cardinal":
				a["pos"] = Vector2(crow["home"]) + Vector2(randf_range(-2, 2), randf_range(-1.5, 1.5))
		crow["state"] = "walk"
	main._on_location_changed(s.location)
	await _shot("6_birds_day")
	# An owl, and a three-eyed one, at night.
	s.content.row("animals", "magic_owl")["chance"] = 1.0
	s.debug_set_time(23 * 60)
	s.wildlife._phase = ""
	s.wildlife.update(0.01)
	var owl := {}
	for a: Dictionary in s.wildlife.animals:
		if str(a["id"]) == "magic_owl":
			owl = a
	if not owl.is_empty():
		s.outdoor_pos = Vector2(owl["pos"]) + Vector2(-2.5, 1)
	await _shot("7_owls_night")
	# The guide's Birds page.
	for id: String in ["crow", "owl", "blue_jay", "cardinal", "magic_crow"]:
		s.wildlife.record(id, "photo" if id != "owl" else "sketch")
	main.guide_screen.open("bird")
	main.guide_screen.selected = "magic_crow"
	main.guide_screen.refresh()
	await _shot("8_guide_birds")
	quit(0)
