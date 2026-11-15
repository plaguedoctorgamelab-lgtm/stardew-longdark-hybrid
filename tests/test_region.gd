extends RefCounted
## Phase 2a, step 1: the world is the whole forest region with ring one placed
## in it, saves are version 2, and phase one saves upgrade cleanly.


func test_world_is_the_whole_region(t: TestCase) -> void:
	var s := TestCase.new_session()
	var w := s.world
	t.check(w.width > 384 and w.height > 256, "the world is larger than the test area (%dx%d)" % [w.width, w.height])
	var o := w.ring_one_offset()
	t.equal(w.ground_at(w.r1(221, 62)), "deep_water", "ring one's pool is where ring one says, moved by its offset")
	t.equal(w.spawn("station"), Vector2(17.5, 224.8) + Vector2(o), "the station spawn moved with ring one")
	t.check(w.baked_count() >= 96, "at least ring one's 96 chunks are built (%d)" % w.baked_count())
	t.check(not w.has_chunk_file(Vector2i(w.chunk_count().x - 1, 0)), "the far corner is not built yet")
	t.check(w.is_solid(Vector2i(w.width - 5, 5)), "unbuilt ground cannot be walked")
	t.equal(w.ground_at(Vector2i(w.width - 5, 5)), "rock", "and reads as rock")


func test_map_share_counts_only_built_ground(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal(s.map.explorable_count, s.world.baked_count() * s.world.chunk_size * s.world.chunk_size, "every built tile counts")
	s.debug_reveal_map()
	t.equal(s.map.percent_revealed(), 100.0, "revealing everything is 100%")


func test_map_redraws_only_changed_chunks(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.map.take_dirty()
	s.map.reveal_circle(s.world.spawn("fork"), 5)
	var d := s.map.take_dirty()
	t.check(not d["all"], "a survey does not redraw the whole sheet")
	t.check((d["chunks"] as Array).size() >= 1 and (d["chunks"] as Array).size() <= 4, "only the chunks it touched (%d)" % (d["chunks"] as Array).size())
	t.check(s.map.take_dirty()["chunks"].is_empty(), "nothing left to redraw")
	var screen := MapScreen.new()
	screen.setup(s)
	screen.open()
	var c := s.world.spawn("fork")
	t.check(screen.image.get_pixelv(Vector2i(c)) != MapScreen.PAPER, "the map picture shows the surveyed ground")
	screen.change_zoom(-2)
	t.equal(screen.zoom(), 0.25, "zooms out")
	screen.free()


## Builds a phase one (version 1) save from a running game, as phase one
## would have written it: ring one coordinates and a ring-one-sized map.
func _as_v1(s: GameSession) -> Dictionary:
	var d := s.to_dict()
	var o := s.world.ring_one_offset()
	var r: Dictionary = d["ranger"]
	r["outdoor_pos"] = [float(r["outdoor_pos"][0]) - o.x, float(r["outdoor_pos"][1]) - o.y]
	var size: Array = s.world.meta["ring_one_size"]
	var w1 := int(size[0])
	var h1 := int(size[1])
	var m: Dictionary = d["map"]
	for key in ["revealed", "traced", "pending"]:
		var full := MapState.unpack(m[key], s.world.width * s.world.height)
		var small := PackedByteArray()
		for y in h1:
			var at := (y + o.y) * s.world.width + o.x
			small.append_array(full.slice(at, at + w1))
		m[key] = MapState.pack(small)
	m["width"] = w1
	m["height"] = h1
	var moved := []
	for e: Array in d["chopped"]:
		moved.append([int(e[0]) - o.x, int(e[1]) - o.y, int(e[2])])
	d["chopped"] = moved
	d.erase("land")
	d["version"] = 1
	return d


func test_phase_one_saves_upgrade(t: TestCase) -> void:
	var s := TestCase.new_session(77)
	s.debug_teleport("fork")
	s.map.reveal_circle(s.outdoor_pos, 6)
	s.map.mark_landmark("scenic_outlook")
	var pos := s.outdoor_pos
	var revealed := s.map.revealed_count
	var path := "user://test_saves/v1_upgrade.json"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(_as_v1(s)))
	f.close()
	var s2 := TestCase.new_session(1)
	s2.save_path = path
	t.equal(s2.load_game(), "", "a version 1 save loads")
	t.check(s2.outdoor_pos.distance_to(pos) < 0.01, "the ranger is where they were")
	t.equal(s2.map.revealed_count, revealed, "the map holds what it held")
	t.check(s2.map.is_revealed(Vector2i(pos)), "revealed ground is in the right place")
	t.check(s2.map.is_landmark_mapped("scenic_outlook"), "mapped landmarks kept")
	t.check(s2.save_game(), "it saves again")
	var again := SaveSystem.read(path)
	t.equal(int(again["data"]["version"]), SaveSystem.VERSION, "now as version %d" % SaveSystem.VERSION)
