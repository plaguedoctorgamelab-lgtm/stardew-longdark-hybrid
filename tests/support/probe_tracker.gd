extends SceneTree
## Lab probe for the 0.5.0 tracker reports (#16, #19, #23, #24, #25): plays
## each case the way a player would and prints what the jobs engine sees.
## Not part of the automated tests. Run:
##   godot --headless --path . -s tests/support/probe_tracker.gd


func _initialize() -> void:
	var s := GameSession.new()
	s.save_path = "user://probe_save.json"
	s.new_game(777)
	_shipshape(s)
	for site in ["old_cabin", "outlook", "kettle_pond", "static_tower"]:
		s.debug_open_site(site)
	s.debug_reveal_map()
	s.jobs.update(true)
	print("active: ", _active(s))
	# Template jobs that want cans and a bench at the outlook and the cabin.
	for tid in ["more_cans", "a_seat", "v_cans", "v_bench"]:
		print(tid, " candidates: ", s.jobs.candidates(tid))
	for site in ["outlook", "old_cabin"]:
		var k := s.jobs.draw("more_cans", {"site_id": site, "count": 2, "site": site, "_at": site})
		var k2 := s.jobs.draw("a_seat", {"site_id": site, "site": site, "_at": site})
		print("  step ", s.jobs.def(k)["steps"][0] if k != "" else "-", " base ", s.jobs.known[k]["base"] if k != "" else "-")
		print("drew ", k, " and ", k2, " spot ", s.park.place_spot(site))
		var spot := s.park.place_spot(site)
		var placed := 0
		for off in [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(3, 0), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(4, 4)]:
			if placed >= 3:
				break
			var item := "trash_can" if placed < 2 else "bench"
			s.backpack.add(item, 1)
			if _place_as_player(s, Vector2i(spot) + off, item):
				placed += 1
		s.jobs.update(true)
		for kk in [k, k2]:
			if kk == "":
				continue
			print("  ", kk, " done=", s.jobs.is_done(kk), " step0=", s.jobs.check(kk, 0), " where=", s.jobs._where(kk, str(s.jobs.def(kk)["steps"][0]["at"])), " count=", s.jobs._count_placed(kk, s.jobs.def(kk)["steps"][0]))
	quit(0)


func _active(s: GameSession) -> Array:
	var out := []
	for k: String in s.jobs.order:
		if s.jobs.is_active(k):
			out.append(k)
	return out


## Stands the ranger beside t, facing it, and uses the held item.
func _place_as_player(s: GameSession, t: Vector2i, item: String) -> bool:
	s.outdoor_pos = Vector2(t) + Vector2(0.5, 1.5)
	s.facing = 2
	for i in s.backpack.size():
		if s.backpack.item_at(i) == item:
			s.selected_slot = i
	var before := s.park.things.size() + s.placed.size()
	s.use_item()
	var ok := s.park.things.size() + s.placed.size() > before
	print("   put ", item, " at ", t, " ok=", ok, " why=", s.park.place_problem(t))
	return ok


func _shipshape(s: GameSession) -> void:
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.backpack.add("axe")
	s.jobs.work_spot("station_branch")
	s.jobs.work_spot("station_can")
	var m := Vector2i(s.jobs.spot_pos("gate_marker"))
	s.park.put_thing(m, "trash_can")
	s.backpack.remove("trash_can", 1)
	s.jobs.update(true)
