extends SceneTree
## Tracker #5: after a collapse that wakes the ranger in the fire tower, the
## walking keys must move them. Runs the real game window, collapses inside
## the repaired tower, closes the rescue note and holds each walking key.
## Not part of the automated tests (they cover the rule; this the window).
## Run: godot --path . -s tests/support/tower_revive_check.gd

var main: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://tower_revive.json"
	s.new_game(4242)
	main._begin()
	s.debug_repair_all("static_tower", true)
	s.debug_repair_all("test_cabin", false)
	s.outdoor_pos = s.door_front("static_tower")
	s.enter_building("static_tower")
	await _frames(5)
	s.needs.set_values(0.0, s.needs.warmth)
	s._check_collapse()
	await _frames(5)
	print("woke in ", s.location, " at ", s.interior_pos, "; dialog open ", main.dialog.visible, "; menu open ", main.menu_open(), "; pending ", s.pending_confirm)
	main._close_dialog(true)
	await _frames(5)
	print("after closing: menu open ", main.menu_open(), "; pending ", s.pending_confirm, "; dialog ", main.dialog.visible)
	var moved := 0
	for act in ["move_right", "move_down", "move_left", "move_up"]:
		var before: Vector2 = s.interior_pos
		Input.action_press(act)
		await create_timer(0.4).timeout
		Input.action_release(act)
		await _frames(3)
		var d := before.distance_to(s.interior_pos)
		print(act, " moved ", d, " to ", s.interior_pos, " location ", s.location)
		if d > 0.05:
			moved += 1
	print("TOWER REVIVE: ", "ok" if moved > 0 else "STUCK")
	quit(0)
