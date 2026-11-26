extends SceneTree
## 0.8.0, Phase 5a: animals in the park, the binoculars, the camera, the
## field guide, the pet and night. Saved to user://screenshots/s080_*. Not
## part of the automated tests.
## Run: godot --path . -s tests/support/screenshots_080.gd

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
	var path := "user://screenshots/s080_%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


## Stands the ranger a few tiles from a group of this kind, facing it.
func _go_to(s: GameSession, id: String, off: Vector2) -> Dictionary:
	for a: Dictionary in s.wildlife.animals:
		if str(a["id"]) == id:
			s.outdoor_pos = Vector2(a["pos"]) + off
			s.facing = Wildlife._facing_of(-off)
			for b: Dictionary in s.wildlife.animals:
				if Vector2(b["home"]) == Vector2(a["home"]):
					b["state"] = "eat"
			return a
	return {}


func _run() -> void:
	for i in 5:
		await process_frame
	var s: GameSession = main.session
	s.save_path = "user://screenshots/save_080.json"
	s.debug_sites_open_start(4242)
	main._begin()
	s.clock.season = 1
	s.debug_set_time(int((s.tuning.value("light.sun.summer") as Array)[1]) - 20)
	s.pet.choose("dog")
	s.pet.offered = true
	s.recipes_new.clear()
	s.wildlife.morning()
	s.wildlife._phase = ""
	s.wildlife.update(0.01)
	_go_to(s, "deer", Vector2(-4, 1))
	s.pet.along = true
	s.pet.pos = s.outdoor_pos + Vector2(-1.4, 0.4)
	await _shot("1_deer_at_dusk")
	var r := _go_to(s, "rabbit", Vector2(-3, 0.5))
	await _shot("2_rabbits")
	s.wildlife.toggle_binoculars()
	s.binoculars_changed.emit(true)
	await _shot("3_binoculars")
	s.wildlife.looking = false
	s.backpack.add("camera", 1)
	s.wildlife.take_photo()
	s.wildlife.record("deer", "sketch")
	s.wildlife.record("squirrel", "photo", true)
	s.wildlife.record("place_dusk", "photo", true)
	main.guide_screen.selected = "rabbit"
	main.open_tab("guide")
	await _shot("4_guide_animals")
	main.guide_screen.turn(1)
	await _shot("5_guide_cousins")
	main.open_tab("")
	# Night: moonflowers and a night path.
	s.debug_set_time(23 * 60)
	if not s.wildlife.paths.is_empty():
		var p: Dictionary = s.wildlife.paths[0]
		s.outdoor_pos = Vector2(p["spot"]) + Vector2(-3, 1.5)
		await _shot("6_night_path")
	if not s.wildlife.flowers.is_empty():
		s.outdoor_pos = Vector2(s.wildlife.flowers[0]) + Vector2(-2, 1)
		await _shot("7_moonflower")
	# The pet at home by the station door, and the letter that offers it.
	s.debug_set_time(9 * 60)
	s.pet.along = false
	s.pet.pos = s.pet.home_spot()
	s.outdoor_pos = s.door_front("ranger_station") + Vector2(0, 2.5)
	await _shot("8_pet_at_home")
	main.choice_screen.open("pet", s.content.text("pet_offer_title"), s.pet.offer_options())
	await _shot("9_pet_letter")
	quit(0)
