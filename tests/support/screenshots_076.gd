extends SceneTree
## Townsfolk Favors in the game: the station's mailbox with a letter, the
## town board, a favor asked in person, and the clipboard's favors. Saved
## to user://screenshots/s076_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_076.gd

var main: Node


func _initialize() -> void:
	create_timer(200.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/s076_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_076.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	for r: Dictionary in s.content.rows("townsfolk"):
		s.town.met[str(r["id"])] = true
	s.debug_set_time(9 * 60)
	s.favors.morning()
	main.park_view.refresh() if "park_view" in main else null
	s.outdoor_pos = s.mailbox_pos() + Vector2(-1.0, 1.2)
	await _frames(10)
	await _shot("1_mailbox")
	s.outdoor_pos = s.mailbox_pos() + Vector2(0, 0.6)
	s.interact()
	await _shot("2_letter")
	main._close_dialog(true)
	s.enter_town()
	main._on_location_changed(s.location)
	var board := Vector2.ZERO
	for o: Dictionary in s.town.objects:
		if str(o.get("sprite", "")) == "town_notice_board":
			board = Vector2(float(o["pos"][0]), float(o["pos"][1]))
	s.town_pos = board + Vector2(0.5, 1.5)
	s.facing = GameSession.FACING_UP
	await _frames(6)
	s.interact()
	await _shot("3_board")
	main._close_dialog(true)
	s.favor_offer = "teo_notebook"
	s.offer_favor()
	await _shot("4_asked")
	main._close_dialog(true)
	main.clipboard.open("wren_rumor_run")
	await _shot("5_clipboard")
	quit(0)
