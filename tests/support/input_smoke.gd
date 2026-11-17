extends SceneTree
## Drives the real game through its input actions, as a player would, and
## checks that walking, the backpack, the map, the debug panel, entering a
## building and the sleep question all respond.
## Run: godot --path . -s tests/support/input_smoke.gd

var main: Node
var fails: Array[String] = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _check(cond: bool, what: String) -> void:
	print(("  ok    " if cond else "  FAIL  ") + what)
	if not cond:
		fails.append(what)


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://smoke_save.json"
	# Title screen: press New game.
	for b in main.title_screen.find_children("*", "Button", true, false):
		if b is Button and (b as Button).text == s.content.text("ui_new_game"):
			(b as Button).pressed.emit()
	await _frames(5)
	s.debug_force_weather("clear")
	_check(main.started and not main.title_screen.visible, "new game starts from the title screen")
	var p0 := s.outdoor_pos
	Input.action_press("move_right")
	await _frames(30)
	Input.action_release("move_right")
	_check(s.outdoor_pos.x > p0.x + 1.0, "D walks right (%.2f tiles)" % (s.outdoor_pos.x - p0.x))
	Input.action_press("move_left")
	await _frames(30)
	Input.action_release("move_left")
	await _tap("backpack")
	_check(main.inventory_screen.visible, "E opens the backpack")
	var m0 := s.clock.minute
	await _frames(60 * 8)
	_check(s.clock.minute == m0, "the clock stops while the backpack is open")
	await _tap("backpack")
	_check(not main.inventory_screen.visible, "E closes the backpack")
	await _tap("pause")
	_check(main.pause_menu.visible, "Escape opens the pause menu")
	var m1 := s.clock.minute
	await _frames(60 * 8)
	_check(s.clock.minute == m1, "the clock stops while paused")
	await _tap("pause")
	_check(not main.pause_menu.visible, "Escape closes the pause menu")
	await _tap("backpack")
	await _tap("pause")
	_check(not main.inventory_screen.visible and not main.pause_menu.visible, "Escape closes the backpack, not into the pause menu")
	await _tap("show_version")
	_check(main.hud.message_label.text == main.version_text(), "V shows the version")
	await _tap("open_map")
	_check(main.map_screen.visible, "M opens the map")
	await _tap("open_map")
	_check(not main.map_screen.visible, "M closes the map")
	await _tap("jobs")
	_check(main.book_screen.visible, "J opens the book")
	await _tap("jobs")
	_check(not main.book_screen.visible, "J closes the book")
	_check(main.hud.money_label.text == "$500", "the wallet shows $500")
	await _tap("slot_2")
	_check(s.selected_item() == "lantern", "2 holds the lantern")
	await _tap("debug_panel")
	_check(main.debug_panel.visible, "F1 opens the debug panel")
	await _tap("debug_panel")
	# Walk back to the door and go in.
	s.outdoor_pos = s.world.spawn("station")
	await _tap("interact")
	_check(s.location == "ranger_station", "X at the door enters the station")
	var layout: InteriorLayout = s.interiors["ranger_station"]
	var desk := layout.furniture_rect(layout.find("catalog"))
	s.interior_pos = Vector2(desk.position.x + 1.0, desk.end.y + 0.5)
	s.facing = GameSession.FACING_UP
	await _tap("interact")
	_check(main.choice_screen.visible and main.choice_screen.kind == "catalog", "X at the desk opens the catalog")
	main.choice_screen.chosen.emit("catalog", "nails")
	await _frames(2)
	_check(s.park.money.wallet == 485 and main.choice_screen.visible, "ordering nails pays $15 and keeps the catalog open")
	await _tap("pause")
	_check(not main.choice_screen.visible, "Escape closes the catalog")
	var bed := layout.furniture_rect(layout.find("bed"))
	s.interior_pos = Vector2(bed.end.x + 0.5, bed.position.y + 1.0)
	await _tap("interact")
	_check(main.dialog.visible and s.pending_confirm == "sleep", "X at the bed asks to sleep")
	var day := s.clock.day
	await _tap("confirm")
	_check(s.clock.day == day + 1 and s.clock.minute == 360, "Y sleeps until 6:00 next day")
	_check(FileAccess.file_exists(s.save_path), "sleeping saved the game")
	# The wake-up note (the nails arrived) closes with Y.
	if main.dialog.visible:
		await _tap("confirm")
	s.interior_pos = layout.entry
	Input.action_press("move_down")
	await _frames(40)
	Input.action_release("move_down")
	_check(s.location == "", "walking out through the door leaves the station")
	print("input smoke: %d failed" % fails.size())
	quit(0 if fails.is_empty() else 1)
