extends SceneTree
## Pictures of Humdrum's shops from inside (0.6.2), and the shop list.
## Saved to user://screenshots/s062_*.png. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_062.gd

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
	var path := "user://screenshots/s063_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_062.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_money(300)
	main.dialog.visible = false
	s.enter_town()
	for place in ["percolator", "outfitters", "gifts", "carpentry", "library", "town_hall"]:
		s.debug_set_time(11 * 60)
		s.town.place_everyone()
		s.leave_town_room()
		s.enter_town_room(place)
		var c := (s.shops.rooms[place] as InteriorLayout).find("counter")
		s.interior_pos = Vector2(float(c["pos"][0]) + 1.5, float(c["pos"][1]) + 1.5)
		s.facing = GameSession.FACING_UP
		await _shot("inside_" + place)
	s.leave_town_room()
	s.clock.start_next_day()
	s.debug_set_time(12 * 60)
	s.town.place_everyone()
	s.enter_town_room("casa_luna")
	await _shot("inside_casa_luna")
	s.interact()
	await _shot("casa_luna_menu")
	main.choice_screen.chosen.emit("shop:casa_luna", "buy")
	await _shot("casa_luna_buy")
	quit(0)
