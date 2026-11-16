extends RefCounted
## Backpack: stacking and slot limits hold; the shelf restocks each morning.
## Cabin: each step needs its materials and the hammer; progress persists;
## the cabin opens only after all four steps.
## Sleep and save: sleeping advances to 6:00 and saves; loading restores every
## saved value exactly.


func test_stacking_and_slot_limits(t: TestCase) -> void:
	var c := ContentDB.new()
	var inv := Inventory.new(c, 12)
	t.equal(inv.add("nails", 25), 0, "25 nails fit")
	t.equal(inv.add("nails", 10), 0, "10 more nails fit")
	t.equal(inv.count("nails"), 35, "nails counted")
	t.equal(inv.slot(0)["count"], 30, "first stack full at 30")
	t.equal(inv.slot(1)["count"], 5, "second stack holds the rest")
	t.equal(inv.add("hammer", 2), 0, "two hammers fit")
	t.check(inv.slot(2)["item"] == "hammer" and inv.slot(3)["item"] == "hammer", "tools do not stack")
	var left := inv.add("apple", 100)
	t.equal(left, 100 - 8 * 5, "only 8 empty slots of 5 apples fit")
	t.equal(inv.add("planks", 1), 1, "a full backpack takes nothing more")
	t.check(inv.remove("apple", 7), "removed apples")
	t.equal(inv.count("apple"), 33, "apples left")
	t.check(not inv.remove("apple", 99), "cannot remove more than held")


func test_starting_backpack(t: TestCase) -> void:
	var s := TestCase.new_session()
	for item in ["hammer", "lantern", "map", "compass", "pencil"]:
		t.check(s.backpack.has(item), "starts with %s" % item)
	t.equal(s.backpack.size(), 12, "12 slots")


func test_packing_just_fits(t: TestCase) -> void:
	# Five tools, every cabin repair material, food and firewood only just fit.
	var s := TestCase.new_session()
	var need := {"planks": 8, "nails": 20, "roofing": 4, "window_glass": 1}
	for k: String in need:
		t.equal(s.backpack.add(k, need[k]), 0, "%s fits" % k)
	t.equal(s.backpack.add("sandwich", 5), 0, "sandwiches fit")
	t.equal(s.backpack.add("tin_of_beans", 5), 0, "beans fit")
	t.equal(s.backpack.add("firewood", 5), 0, "firewood fits")
	var empty := 0
	for i in s.backpack.size():
		if s.backpack.slot(i).is_empty():
			empty += 1
	t.check(empty <= 1, "the backpack is nearly full (%d empty)" % empty)


func test_shelf_restocks_each_morning(t: TestCase) -> void:
	var s := TestCase.new_session()
	var shelf: Inventory = s.structures.shelves["ranger_station"]
	t.equal(shelf.count("planks"), 10, "shelf stocked at the start")
	shelf.move_slot_to(0, s.backpack)
	shelf.remove("planks", 10)
	t.equal(shelf.count("planks"), 0, "planks taken")
	s.sleep()
	t.equal(shelf.count("planks"), 10, "planks back next morning")
	for st: Dictionary in s.content.row("structures", "ranger_station")["shelf_stock"]:
		t.equal(shelf.count(st["item"]), int(st["count"]), "%s restocked" % st["item"])


func test_chests_hold_twelve(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal((s.structures.chests["ranger_station"] as Inventory).size(), 12, "station chest")
	t.equal((s.structures.chests["test_cabin"] as Inventory).size(), 12, "cabin chest")
	s.debug_add_item("apple", 3)
	var slot := -1
	for i in s.backpack.size():
		if s.backpack.item_at(i) == "apple":
			slot = i
	s.backpack.move_slot_to(slot, s.structures.chests["ranger_station"])
	t.equal((s.structures.chests["ranger_station"] as Inventory).count("apple"), 3, "apples moved to the chest")
	t.equal(s.backpack.count("apple"), 0, "apples left the backpack")


func test_cabin_supplies_come_from_the_seed(t: TestCase) -> void:
	var a := TestCase.new_session(1)
	var b := TestCase.new_session(1)
	var c := TestCase.new_session(2)
	var ca: Array = (a.structures.chests["test_cabin"] as Inventory).to_array()
	t.equal(ca, (b.structures.chests["test_cabin"] as Inventory).to_array(), "same seed, same supplies")
	var differs := false
	for sd in range(2, 12):
		var other := TestCase.new_session(sd)
		if (other.structures.chests["test_cabin"] as Inventory).to_array() != ca:
			differs = true
			break
	t.check(differs, "different seeds give different supplies")
	t.check((c.structures.chests["test_cabin"] as Inventory).count("firewood") >= 1, "always some firewood")


func _at_cabin() -> GameSession:
	var s := TestCase.new_session()
	s.debug_teleport("cabin")
	s.map.mark_landmark("test_cabin")
	s.debug_drain(false, false)
	return s


func test_cabin_needs_hammer_and_materials(t: TestCase) -> void:
	var s := _at_cabin()
	var res := s.hammer()
	t.equal(res.get("reason", ""), "no_materials", "nothing happens without materials")
	s.debug_add_item("planks", 2)
	s.debug_add_item("nails", 4)
	s.backpack.remove("hammer")
	res = s.structures.repair_action("test_cabin", s.backpack)
	t.equal(res.get("reason", ""), "no_tool", "nothing happens without the hammer")
	s.debug_add_item("hammer")
	res = s.hammer()
	t.check(res.get("ok", false), "hammer and door materials start the door")
	t.equal(res["step"], "door", "the door step")
	t.equal(s.backpack.count("planks"), 0, "door planks used")
	t.equal(s.backpack.count("nails"), 0, "door nails used")


func test_each_step_needs_its_materials(t: TestCase) -> void:
	var c := ContentDB.new()
	var tun := Tuning.new()
	var spec := {
		"door": {"planks": 2, "nails": 4},
		"walls": {"planks": 4, "nails": 8},
		"roof": {"roofing": 4, "nails": 8},
		"window": {"window_glass": 1, "planks": 2},
	}
	for step: String in spec:
		var st := Structures.new(c, tun)
		var mats: Dictionary = st.step_row("test_cabin", step)["materials"]
		var as_int := {}
		for k: String in mats:
			as_int[k] = int(mats[k])
		t.equal(as_int, spec[step], "%s materials match the spec" % step)
		# Mark the other steps done so this one is the only choice.
		for other: String in spec:
			if other != step:
				st.debug_complete_step("test_cabin", other)
		var pack := Inventory.new(c, 12)
		pack.add("hammer")
		# One short of each material: this step cannot start.
		for k: String in spec[step]:
			var partial: Dictionary = (spec[step] as Dictionary).duplicate()
			partial[k] = int(partial[k]) - 1
			var p2 := Inventory.new(c, 12)
			p2.add("hammer")
			for m: String in partial:
				if int(partial[m]) > 0:
					p2.add(m, partial[m])
			t.check(st.choose_step("test_cabin", p2) != step, "%s needs all its %s" % [step, k])
		for k: String in spec[step]:
			pack.add(k, spec[step][k])
		t.equal(st.choose_step("test_cabin", pack), step, "%s starts with its materials" % step)


func test_three_actions_of_twenty_minutes(t: TestCase) -> void:
	var s := _at_cabin()
	s.debug_set_time(9 * 60)
	s.debug_add_item("planks", 2)
	s.debug_add_item("nails", 4)
	for i in 3:
		var res := s.hammer()
		t.equal(res["done"], i + 1, "action %d" % (i + 1))
	t.equal(s.clock.minute, 9 * 60 + 60, "three actions take an hour")
	t.check(s.structures.step_done("test_cabin", "door"), "door finished")
	t.equal(s.hammer().get("reason", ""), "no_materials", "no further work without materials")


func test_progress_persists_and_cabin_opens_last(t: TestCase) -> void:
	var s := _at_cabin()
	s.debug_set_time(8 * 60)
	s.debug_add_item("planks", 8)
	s.debug_add_item("nails", 20)
	s.debug_add_item("roofing", 4)
	s.debug_add_item("window_glass", 1)
	s.hammer()
	# Leave and come back another day: progress kept.
	s.debug_teleport("station")
	s.sleep()
	s.debug_teleport("cabin")
	t.equal(int(s.structures.progress["test_cabin"]["door"]), 1, "progress kept between visits")
	var opened_at := -1
	for i in 11:
		t.check(not s.structures.is_open("test_cabin"), "still closed before the last action (%d)" % i)
		if i == 5:
			t.check(not s.enter_building("test_cabin"), "cannot enter yet")
		var res := s.hammer()
		if res.get("opened", false):
			opened_at = i
	t.equal(opened_at, 10, "opened on the twelfth action")
	t.check(s.structures.is_open("test_cabin"), "open after all four steps")
	t.check(s.enter_building("test_cabin"), "the door opens")
	var layout: InteriorLayout = s.interiors["test_cabin"]
	for kind in ["bed", "stove", "chest"]:
		t.check(not layout.find(kind).is_empty(), "the cabin has a %s" % kind)


func test_cabin_picture_changes(t: TestCase) -> void:
	var s := _at_cabin()
	var view := WorldView.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	view.setup(s, RangerSprite.new())
	var before: Texture2D = (view.building_sprites["test_cabin"] as Sprite2D).texture
	for st in ["door", "walls", "roof", "window"]:
		s.debug_cabin_step(st, true)
	var after: Texture2D = (view.building_sprites["test_cabin"] as Sprite2D).texture
	t.check(before != after, "the repaired picture replaces the run-down one")
	t.equal(after.resource_path.get_file(), "building_cabin_repaired.png", "repaired picture")
	view.queue_free()


func test_sleep_advances_and_saves(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.enter_building("ranger_station")
	s.debug_set_time(22 * 60)
	s.debug_set_needs(40, 50)
	var day := s.clock.day
	var saves := s.save_count
	var bed := (s.interiors["ranger_station"] as InteriorLayout).furniture_rect((s.interiors["ranger_station"] as InteriorLayout).find("bed"))
	s.interior_pos = Vector2(bed.end.x + 0.5, bed.position.y + 1.0)
	s.interact()
	t.equal(s.pending_confirm, "sleep", "the bed asks for confirmation")
	s.answer_confirm(false)
	t.equal(s.clock.day, day, "saying no does nothing")
	s.request_sleep()
	s.answer_confirm(true)
	t.equal(s.clock.day, day + 1, "next day")
	t.equal(s.clock.minute, 360, "wakes at 6:00")
	t.equal(s.needs.energy, 270.0, "full energy")
	t.equal(s.needs.warmth, 100.0, "full warmth")
	t.equal(s.save_count, saves + 1, "saved")


func test_save_and_load_restores_everything(t: TestCase) -> void:
	var s := TestCase.new_session(31337)
	s.debug_set_time(14 * 60 + 20)
	s.clock.season = 2
	s.clock.day = 17
	s.weather.today = ["fog", "rain", "storm"]
	s.weather.tomorrow = ["clear", "overcast", "fog"]
	s.outdoor_pos = Vector2(123.25, 77.75)
	s.facing = GameSession.FACING_LEFT
	s.selected_slot = 3
	s.needs.set_values(123.5, 42.0)
	s.debug_add_item("nails", 17)
	s.debug_cabin_step("roof", true)
	s.structures.progress["test_cabin"]["door"] = 2
	s.structures.stove_minutes["test_cabin"] = 70
	(s.structures.chests["ranger_station"] as Inventory).add("apple", 4)
	s.map.reveal_circle(Vector2(100, 100), 10)
	s.map.record_trace(Vector2i(5, 5), true)
	s.map.record_trace(Vector2i(6, 6), false)
	s.map.mark_landmark("scenic_outlook")
	var before := s.to_dict()
	t.check(s.save_game(), "saved")
	var fresh := GameSession.new()
	fresh.save_path = s.save_path
	t.equal(fresh.load_game(), "", "loaded")
	var after := fresh.to_dict()
	for key: String in before:
		t.equal(JSON.stringify(after[key]), JSON.stringify(before[key]), "%s restored exactly" % key)
	t.equal(fresh.map.revealed_count, s.map.revealed_count, "revealed count")
	t.check(fresh.map.is_pending(Vector2i(6, 6)), "hidden trace kept")


func test_bad_saves_fail_clearly(t: TestCase) -> void:
	var path := "user://test_saves/bad.json"
	DirAccess.make_dir_recursive_absolute("user://test_saves")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	t.equal(SaveSystem.read(path)["error"], "msg_save_broken", "garbage is refused")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": SaveSystem.VERSION + 1}))
	f.close()
	t.equal(SaveSystem.read(path)["error"], "msg_save_too_new", "a newer version is refused")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 0}))
	f.close()
	t.equal(SaveSystem.read(path)["error"], "msg_save_broken", "an incomplete old save is refused")
	var s := TestCase.new_session()
	s.save_path = path
	t.check(s.load_game() != "", "the session reports the problem")
	t.equal(FileAccess.get_file_as_string(path), JSON.stringify({"version": 0}), "the bad file is left untouched")


func test_rooms_have_a_back_wall(t: TestCase) -> void:
	var s := TestCase.new_session()
	for id: String in s.interiors:
		var layout: InteriorLayout = s.interiors[id]
		t.check(layout.wall_height >= 2, "%s has a tall back wall" % id)
		for y in layout.wall_height:
			t.check(layout.is_solid(Vector2i(layout.size.x / 2, y)), "%s back wall row %d is solid" % [id, y])
		var e := Vector2i(floori(layout.entry.x), floori(layout.entry.y))
		t.check(not layout.is_solid(e), "%s entry is on the floor" % id)
		t.check(not layout.is_solid(layout.door_tile), "%s door can be walked onto" % id)


func test_loading_into_a_wall_moves_to_the_entry(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.location = "ranger_station"
	s.interior_pos = Vector2(5.5, 0.5)
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(d)
	var layout: InteriorLayout = s2.interiors["ranger_station"]
	t.equal(s2.interior_pos, layout.entry, "moved off the back wall to the entry")
