extends SceneTree
## Inside the eight houses, each with whoever is home. Saved to
## user://screenshots/s075_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_075.gd

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
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s075_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_075.json"
	s.debug_sites_open_start(4242)
	main._start_playtest() if false else main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.enter_town()
	main._on_location_changed(s.location)
	var k := 1
	for place: String in ["house_pelletier", "house_kowalski", "house_thistlewood", "house_pruitt", "house_abernathy", "house_mendoza", "house_lindqvist", "house_arden"]:
		var m := -1
		for mm in range(480, 1260, 30):
			if s.town.someone_home(place, mm) != "":
				m = mm
				break
		s.debug_set_time(m if m >= 0 else 20 * 60)
		s.town.place_everyone()
		s.enter_town_room(place)
		main._on_location_changed(s.location)
		s.interior_pos = Vector2(5.5, 7.5)
		await _frames(6)
		await _shot("%d_%s" % [k, place])
		s.leave_town_room()
		main._on_location_changed(s.location)
		k += 1
	quit(0)
