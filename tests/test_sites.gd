extends RefCounted
## Phase 2a, step 5: sites and the six steps of opening one.

const SITE := "static_tower"


func _route_tiles(s: GameSession, route_name: String) -> Array[Vector2i]:
	var pts := s.world.route(route_name)
	var out: Array[Vector2i] = []
	var last := Vector2i(-99999, -99999)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var n := int(ceil(a.distance_to(b) * 4.0)) + 1
		for k in n + 1:
			var t := Vector2i((a + (b - a) * (float(k) / n)).floor())
			if t == last:
				continue
			if last.x > -99999 and t.x != last.x and t.y != last.y:
				# Keep the path joined side to side.
				var mid := Vector2i(t.x, last.y)
				if s.world.is_solid(mid):
					mid = Vector2i(last.x, t.y)
				out.append(mid)
			out.append(t)
			last = t
	return out


## Lays unbroken trail along the walking route to the tower, clearing what
## lies across it, as a ranger doing all the trail work would.
func _build_trail_to_tower(s: GameSession) -> Array[Vector2i]:
	var tiles := _route_tiles(s, "tower")
	for o: Array in s.world.meta["obstacles_on_routes"]:
		s.debug_clear_obstacle(Vector2i(int(o[0]), int(o[1])))
	var dug: Array[Vector2i] = []
	for t in tiles:
		if s.can_dig(t):
			s.debug_dig(t)
			dug.append(t)
	# The plateau between the steps and the tower's door.
	var door := Vector2i(s.door_front(SITE))
	var path := _route_tiles_between(s, Vector2(door) + Vector2(0.5, 0.5), s.world.route("tower")[s.world.route("tower").size() - 1])
	for t in path:
		if s.can_dig(t):
			s.debug_dig(t)
	return dug


func _route_tiles_between(s: GameSession, a: Vector2, b: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := int(ceil(a.distance_to(b) * 4.0)) + 1
	var last := Vector2i(-99999, -99999)
	for k in n + 1:
		var t := Vector2i((a + (b - a) * (float(k) / n)).floor())
		if t != last:
			if last.x > -99999 and t.x != last.x and t.y != last.y:
				out.append(Vector2i(t.x, last.y))
			out.append(t)
			last = t
	return out


func test_steps_start_undone(t: TestCase) -> void:
	var s := TestCase.new_session()
	for step in ["find", "map", "reach", "repair", "sign"]:
		t.check(not s.site_step_done(SITE, step), "%s not done at the start" % step)
	t.check(s.site_step_done(SITE, "settle"), "nothing strange to settle in phase two")
	t.check(not s.site_ready(SITE), "not ready to open")
	t.equal(s.site_lines()[1], s.content.text("site_none"), "the Sites page lists nothing until found")


func test_find_and_map(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("tower")
	t.check(s.site_step_done(SITE, "find"), "found by coming close")
	t.check(s.site_lines().size() == 2 and s.site_lines()[1].contains(s.content.text("landmark_static_tower")), "now on the Sites page")
	s.interact()
	t.check(s.site_step_done(SITE, "map"), "mapped at the door")


func test_reach_needs_unbroken_cleared_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not s.site_reached(SITE), "no trail joins it at the start")
	var dug := _build_trail_to_tower(s)
	t.check(s.site_reached(SITE), "trail all the way, obstacles cleared: reached (%d tiles dug)" % dug.size())
	# Break it: undo one dug tile somewhere in the middle.
	var mid := dug[dug.size() / 2]
	s.debug_dig(mid, false)
	var still := s.site_reached(SITE)
	s.debug_dig(mid)
	t.check(not still, "a gap in the trail breaks the reach")
	# Put a trunk back across the old trail, and undo any digging that went
	# round its ends: blocked again.
	var o: Array = s.world.meta["obstacles_on_routes"][0]
	var trunk := Vector2i(int(o[0]), int(o[1]))
	t.equal(str(o[2]), "fallen_trunk", "the first obstacle is a trunk")
	s.debug_clear_obstacle(trunk, false)
	for dx in range(-3, 6):
		s.debug_dig(trunk + Vector2i(dx, 0), false)
	t.check(not s.site_reached(SITE), "an uncleared trunk breaks the reach")


func test_open_the_site(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_set_needs(270, 100)
	s.debug_teleport("tower")
	s.interact()
	_build_trail_to_tower(s)
	for st: Dictionary in s.content.row("structures", SITE)["repair_steps"]:
		s.structures.debug_complete_step(SITE, st["id"])
	t.check(s.site_step_done(SITE, "repair"), "repaired")
	t.check(not s.site_ready(SITE), "not ready without a sign")
	var door := Vector2i(s.door_front(SITE))
	var spot := Vector2i(-1, -1)
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			var c := door + Vector2i(dx, r)
			if spot.x < 0 and s.world.ground_at(c) == "trail" and s.place_problem(c, "trail_sign") in ["", "msg_place_need_hammer"]:
				spot = c
	t.check(spot.x >= 0, "a trail tile near the door for a sign")
	t.check(s.debug_put_up(spot, "trail_sign", SITE), "a sign naming the tower")
	t.check(s.site_step_done(SITE, "sign"), "signposted")
	t.check(s.site_ready(SITE), "ready to open")
	var asked := []
	s.confirm_requested.connect(func(kind: String, _text: String) -> void: asked.append(kind))
	s.debug_teleport("tower")
	s.interact()
	t.equal(asked, ["open_site"], "the door offers to declare it open")
	s.answer_confirm(true)
	t.check(s.sites_open.has(SITE), "the site is open")
	t.check(s.site_lines()[1].contains(s.content.text("site_open", {"name": s.content.text("landmark_static_tower")})), "and the Sites page says so")
	s.interact()
	t.check(s.is_indoors(), "after that the door just opens")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.check(s2.sites_open.has(SITE), "opening survives a reload")


func test_debug_site_tools(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_site_step(SITE, "reach", true)
	t.check(s.site_step_done(SITE, "reach"), "debug completes a step")
	s.debug_site_step(SITE, "reach", false)
	t.check(not s.site_step_done(SITE, "reach"), "and undoes it")
	s.debug_open_site(SITE)
	t.check(s.sites_open.has(SITE), "debug opens a site")
