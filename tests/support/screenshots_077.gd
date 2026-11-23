extends SceneTree
## Mark's portraits in the talk box: Gus talking, Teo asking a favor, and
## Wren with her sprite's face until her portrait is redrawn. Saved to
## user://screenshots/s077_*. Not part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_077.gd

var main: Node


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(2))
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
	var path := "user://screenshots/s077_%s.png" % name
	img.save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _run() -> void:
	await _frames(5)
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_077.json"
	s.debug_sites_open_start(4242)
	main._start_playtest() if false else main._begin()
	s.enter_town()
	main._on_location_changed(s.location)
	s.debug_set_time(11 * 60)
	await _frames(5)
	s._talk_to("gus")
	await _shot("1_gus")
	main._close_dialog(true)
	main._close_dialog(false)
	s.pending_confirm = ""
	s.favor_offer = "teo_notebook"
	s.offer_favor()
	await _shot("2_teo_asks")
	main._close_dialog(false)
	s._talk_to("wren")
	await _shot("3_wren")
	quit(0)
