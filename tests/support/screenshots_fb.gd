extends SceneTree
## Pictures of the 0.4.2 playtest fixes: the X and C hint line and the "?"
## over the station, the aim square for boardwalk, the backpack with Drop and
## Trash, the crafting page with recipes still to learn, the book's "Next"
## list and the map's trail travel list. Saved to user://screenshots/.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_fb.gd

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
	var path := "user://screenshots/%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


## Moves the mouse to a point on the 480 x 270 screen, as a real move would.
func _move_mouse(p: Vector2) -> void:
	var win := p * (Vector2(root.size) / Vector2(480, 270))
	root.warp_mouse(win)
	var e := InputEventMouseMotion.new()
	e.position = win
	e.global_position = win
	Input.parse_input_event(e)


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_fb.json"
	s.new_game(4242)
	main._begin()
	s.weather.today.assign(["clear", "clear", "clear"])
	s.weather.check_change(s.clock.minute)
	s.debug_set_time(9 * 60)
	# Outside the station: the "?" over the door, and the hint line.
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 0.2)
	s.facing = GameSession.FACING_UP
	s.selected_slot = s.backpack.find_family("map")
	main.world_view.reset_chunks()
	await _frames(4)
	# The mouse over the station building, then over the map's item-bar slot.
	var st: Dictionary = s.world.structure_placement("ranger_station")
	var roof := (Vector2(float(st["pos"][0]) + float(st["size"][0]) / 2.0, float(st["pos"][1]) + 1.0)) * 16.0
	var scr: Vector2 = main.world.get_canvas_transform() * roof
	# A scripted mouse can't be trusted to land, so the hover is set as the
	# game would set it, to see how the tooltip looks.
	_move_mouse(scr)
	main._hover_wait = 9999.0
	main.hud.world_hint = s.guide.x_hint_at(roof / 16.0)
	print("hover over the station says: ", main.hud.world_hint)
	await _shot("fb_1_hint_and_question_mark")
	main.hud.world_hint = ""
	var slot: Panel = main.hud.slot_panels[s.backpack.find_family("map")]
	_move_mouse(slot.position + Vector2(8, 8))
	main.hud._bar_hover = s.backpack.find_family("map")
	await _shot("fb_1b_bar_hover")
	main.hud._bar_hover = -1
	# Holding boardwalk off the bog: the red square.
	s.debug_add_item("boardwalk", 3)
	s.selected_slot = s.backpack.find_family("boardwalk")
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(3, 3)
	s.facing = GameSession.FACING_RIGHT
	await _shot("fb_2_boardwalk_aim")
	# A pile on the ground and the backpack with Drop and Trash.
	s.debug_add_item("stones", 12)
	s.drop_slot(s.backpack, s.backpack.find_family("stones"))
	s.debug_add_item("berries", 25)
	s.debug_add_item("planks", 18)
	main.inventory_screen.open(null, "")
	await _shot("fb_3_backpack")
	main.inventory_screen.close()
	# The crafting page with workbench recipes and the ones to learn.
	main.choice_screen.open_station("anywhere")
	await _shot("fb_4_crafting")
	main.choice_screen.close()
	# The book's Next list with a site found.
	s.sites_found["static_tower"] = true
	s.sites_found["old_cabin"] = true
	main.book_screen.open("jobs")
	await _shot("fb_5_book_next")
	main.book_screen.close()
	# The map with trail travel on offer.
	ParkHelpers.open_route(s, "cabin")
	s.visits["old_cabin"] = 2
	s.outdoor_pos = s.door_front("ranger_station")
	main.map_screen.open()
	await _shot("fb_6_map_travel")
	main.map_screen.close()
	quit(0)
