extends SceneTree
## Phase 5b, Gord and the night: Gord by day and on the full moon, the
## aurora, the badgers' stone, the jackalopes' burrows, the calendar, the
## Log's Creatures page and the badges. Saved to user://screenshots/s5b_*.
## Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_5b.gd

var main: Node


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/s5b_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	var c := s.creatures
	s.save_path = "user://screenshots/save_5b.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.recipes_new.clear()
	s.pet.choose("dog")
	s.pet.offered = true
	# Gord the moose by day, in his meadow.
	s.clock.season = 0
	s.clock.day = 5
	s.debug_set_time(11 * 60)
	s.wildlife.morning()
	c.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)
	s.outdoor_pos = c.gord_meadow() + Vector2(-4, 1.5)
	s.facing = GameSession.FACING_RIGHT
	await _shot("1_moose_by_day")
	# The full moon: Gord the man, the moon in the sky.
	s.wildlife.record("gord_moose", "sketch")
	s.jobs.update(true)
	s.debug_next_full_moon()
	s.outdoor_pos = c.gord_meadow() + Vector2(-2.5, 1.0)
	await _shot("2_gord_full_moon")
	c.talk_gord()
	await _shot("3_gord_meets")
	main.dialog.visible = false
	# An aurora night.
	c.forced_aurora = s.clock.absolute_day()
	s.debug_set_time(23 * 60)
	s.wildlife._phase = ""
	s.wildlife.update(0.01)
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 4)
	await _shot("4_aurora")
	c.forced_aurora = -1
	# The badgers' stone and the calendar.
	for k in 3:
		c.on_mischief("old_cabin")
	s.jobs.update(true)
	s.debug_set_time(13 * 60)
	if c.stone() != Vector2.INF:
		s.outdoor_pos = c.stone() + Vector2(-2, 1)
		await _shot("5_badger_stone")
	c.heard["deer_outlook"] = true
	main.social_screen.open("calendar")
	await _shot("6_calendar")
	main.social_screen.visible = false
	# The Log's Creatures page, and the badges.
	c.points["gord"] = 230
	c.facts["gord_met"] = 1
	c.set_choice("troll_badgers", "public")
	main.book_screen.open("creatures")
	await _shot("7_log_creatures")
	main.book_screen.open("badges")
	await _shot("8_badges")
	main.book_screen.visible = false
	# The jobs clipboard with a creature job.
	main.clipboard.open("cj_gord")
	await _shot("9_creature_job")
	quit(0)
