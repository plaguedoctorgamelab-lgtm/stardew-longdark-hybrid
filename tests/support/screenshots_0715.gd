extends SceneTree
## 0.7.15: the Make sheet on the clipboard. Saved to
## user://screenshots/s0715_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_0715.gd

var main: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _shot(name: String) -> void:
	for i in 8:
		await process_frame
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/s0715_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_0715.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.debug_set_time(10 * 60)
	s.recipes_new.clear()
	for it: Array in [["planks", 12], ["nails", 20], ["stones", 4], ["firewood", 3], ["berries", 6]]:
		s.backpack.add(it[0], it[1])
	for r in ["hot_soup", "trail_mix", "rope", "painted_stone", "berry_preserve"]:
		s.recipes_known[r] = true
	s.recipes_new.clear()
	var m: MakeSheet = main.make_sheet
	main.open_tab("crafting")
	m.selected = "cairn"
	m.refresh()
	await _shot("1_make_all")
	m.selected = "bench"
	m.refresh()
	await _shot("2_bench_away")
	m.set_tab("fire")
	await _shot("3_fire_tab")
	main.open_tab("")
	m.open("fire")
	await _shot("4_at_a_fire")
	quit(0)
