extends RefCounted
## 0.5.3 (21 November 2026): Mark's station furniture in use, and the water's
## new look: open water moves, and a shore lies where water meets land.


func _scene_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func _view(s: GameSession) -> WorldView:
	var view := WorldView.new()
	_scene_tree().root.add_child(view)
	view.setup(s, RangerSprite.new())
	view.update_chunks(true)
	return view


func test_open_water_moves_and_shores_line_it(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.outdoor_pos = s.site_door("kettle_pond")
	var view := _view(s)
	var water: Dictionary = s.tuning.value("look.water")
	var frames := (water["sway"] as Array).size()
	var moving := 0
	var shores := 0
	var dock_shore := 0
	for c: Vector2i in view.loaded:
		for y in s.world.chunk_size:
			for x in s.world.chunk_size:
				var tile := c * s.world.chunk_size + Vector2i(x, y)
				var g := s.world.ground_at(tile)
				if not g in (water["grounds"] as Array):
					continue
				var src := view.ground_layer.tile_set.get_source(view.ground_layer.get_cell_source_id(tile)) as TileSetAtlasSource
				var at := view.ground_layer.get_cell_atlas_coords(tile)
				if src.get_tile_animation_frames_count(at) == frames:
					moving += 1
				if view.edge_layer.get_cell_source_id(tile) == view._shore_source:
					shores += 1
					var by_boards := false
					for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
						if s.world.ground_at(tile + d) == "boards":
							by_boards = true
					if by_boards:
						var next_land := false
						for d: Vector2i in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
							if s.world.ground_at(tile + d) in (water["shore_from"] as Array):
								next_land = true
						if not next_land:
							dock_shore += 1
	t.check(moving > 0, "open water moves (%d tiles)" % moving)
	t.check(shores > 0, "a shore lines the water (%d tiles)" % shores)
	t.equal(dock_shore, 0, "no sand where water only meets boards")
	view.queue_free()


func test_a_shore_tile_has_sand_on_the_land_side_only(t: TestCase) -> void:
	var s := TestCase.new_session()
	var water: Dictionary = s.tuning.value("look.water")
	var atlas := WorldView._shore_atlas(water)
	var nf := int(water["shore_frames"])
	var sand := Color8(int(water["shore_sand"][0]), int(water["shore_sand"][1]), int(water["shore_sand"][2]))
	# Mask 1: land to the north. Sand along the top, clear at the bottom.
	var ox := 1 * nf * WorldView.TILE
	t.equal(atlas.get_pixel(ox + 4, 0), sand, "sand on the land side")
	t.equal(atlas.get_pixel(ox + 4, WorldView.TILE - 1).a, 0.0, "clear on the water side")
	t.equal(atlas.get_width(), WorldView.TILE * 16 * nf, "16 masks, each with its frames")


func test_the_station_furniture_is_marks_new_drawing(t: TestCase) -> void:
	for n in ["bed", "stove", "stove_lit", "workbench", "catalog_desk", "radio", "shelf", "staff_board", "note_board", "chest", "desk", "door"]:
		t.check(Art.has_picture("furniture_" + n), "furniture_%s has its picture" % n)
	var f := FileAccess.open("res://tools/art_manifest.json", FileAccess.READ)
	var m: Dictionary = JSON.parse_string(f.get_as_text())
	var found := false
	for e: Dictionary in m["images"]:
		if e["file"] == "ar17_station_plain.png":
			found = e.get("final_say", false) and (e["cells"] as Array).size() == 12
	t.check(found, "the plain station sheet has the final say on all twelve pieces")
