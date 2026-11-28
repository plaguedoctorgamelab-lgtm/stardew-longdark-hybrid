extends SceneTree
## Phase 6a, the far bank: the mended bridge and its toll box, Dusk River
## Landing and the canoe, Skull Lake in summer and frozen, the logging camp
## and the cart, and the map with the skull on it. Saved to
## user://screenshots/s6a_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_6a.gd

var main: Node


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	main.world_view.update_chunks(true)
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s6a_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _pt(s: GameSession, name: String) -> Vector2:
	var v: Array = s.world.meta["trail_job_points"][name]
	return Vector2(float(v[0]) + 0.5, float(v[1]) + 0.5)


func _season(s: GameSession, season: int, day: int) -> void:
	s.clock.season = season
	s.clock.day = day
	s._apply_seasons()
	main.world_view.redraw_land()


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_6a.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.recipes_new.clear()
	s.pet.choose("dog")
	s.pet.offered = true
	main.dialog.visible = false
	s.debug_set_time(11 * 60)
	_season(s, 1, 5)
	# The mended bridge and the toll box.
	s.debug_far_bank("bridge")
	s.jobs.spots_done["landing_boathouse"] = true
	s.jobs.spots_changed.emit()
	s.outdoor_pos = _pt(s, "toll_box") + Vector2(-3, 2)
	main._on_location_changed(s.location)
	await _shot("1_bridge")
	# The landing and the canoe on the river.
	s.debug_far_bank("canoe")
	s.facing = GameSession.FACING_RIGHT
	s.outdoor_pos += Vector2(4, 0)
	await _shot("2_canoe")
	s.vehicles.riding = ""
	# Skull Lake in summer, from the west shore.
	var lake := s.world.landmark_pos("skull_lake")
	var p := lake + Vector2(-150, 0)
	while s.world.is_solid(Vector2i(p)):
		p.x -= 1
	s.outdoor_pos = p
	await _shot("3_lake_summer")
	# Frozen, out on the ice by the eye island.
	_season(s, 3, 18)
	s.outdoor_pos = s.world.landmark_pos("left_eye_island") + Vector2(0, 16)
	await _shot("4_lake_frozen")
	_season(s, 1, 5)
	# The logging camp and the cart.
	s.jobs.spots_done["sawmill"] = true
	s.jobs.spots_changed.emit()
	s.debug_far_bank("cart")
	s.facing = GameSession.FACING_RIGHT
	await _shot("5_cart")
	s.vehicles.leave()
	# The map, with the skull showing.
	s.debug_reveal_map()
	main.map_screen.open()
	s.outdoor_pos = lake
	await _shot("6_map")
	quit(0)
