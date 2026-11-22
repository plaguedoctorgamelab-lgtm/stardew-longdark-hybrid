extends SceneTree
## Humdrum as it looks today, for Art Request 19 (the town).
## Saved to user://screenshots/town_*.png. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_town_today.gd

var main: Node


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/town_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_town.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	main.dialog.visible = false
	s.enter_town()
	var spots := {"main_street": Vector2(62, 31), "square": Vector2(35, 33), "houses": Vector2(30, 15), "houses_east": Vector2(60, 15), "south": Vector2(50, 50), "creek": Vector2(24, 52)}
	for t in [[12 * 60, "day"], [21 * 60 + 30, "night"]]:
		s.debug_set_time(t[0])
		s.town.place_everyone()
		for k: String in spots:
			if t[1] == "night" and k not in ["main_street", "square"]:
				continue
			s.town_pos = spots[k]
			await _shot("%s_%s" % [k, t[1]])
	quit(0)
