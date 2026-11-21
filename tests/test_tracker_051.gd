extends RefCounted
## The 0.5.0 tracker reports (21 November 2026), played as a player would:
## cans and benches counting for template jobs (#16, #24), the pond trail and
## stake trail joining (#19, #23), X at the pond's cairn (#25), walking out of
## something put down on top of you (#12, #14), packing up a camp (#20),
## placing beside a fussy tile (#17), and Show on map (#22).


func _start(s: GameSession) -> void:
	s.debug_reveal_map()
	for id in ["station_papers", "station_shelf", "station_boots"]:
		s.jobs.work_spot(id)
	s.backpack.add("axe")
	s.jobs.work_spot("station_branch")
	s.jobs.work_spot("station_can")
	var m := Vector2i(s.jobs.spot_pos("gate_marker"))
	s.park.put_thing(m, "trash_can")
	s.jobs.update(true)


func _hold(s: GameSession, item: String) -> void:
	if s.backpack.count(item) == 0:
		s.backpack.add(item, 1)
	for i in s.backpack.size():
		if s.backpack.item_at(i) == item:
			s.selected_slot = i
			return


## Clears what a clear step asks for and digs a gap along an open route.
func _clear(s: GameSession, job: String, i: int) -> void:
	if not s.jobs.known.has(job):
		s.jobs.add(job, "given")
	var tg := s.jobs._clear_targets(s.jobs.def(job)["steps"][i])
	for t: Vector2i in tg["tiles"]:
		s.debug_clear_obstacle(t)
	for sp: String in tg["spots"]:
		s.jobs.spots_done[sp] = true


func _dig(s: GameSession, gname: String) -> void:
	var gp := s.jobs.gap(gname)
	var a := Vector2i(int(gp["a"][0]), int(gp["a"][1]))
	var b := Vector2i(int(gp["b"][0]), int(gp["b"][1]))
	for p: Array in gp["tiles"]:
		s.debug_dig(Vector2i(int(p[0]), int(p[1])))
	if s.trail_joins(a, b, 6):
		return
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	var h := 0
	while h < q.size() and not prev.has(b):
		var t := q[h]
		h += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := t + d
			if not prev.has(n) and not s.world.is_solid(n) and absi(n.x - a.x) <= 30 and absi(n.y - a.y) <= 30:
				prev[n] = t
				q.append(n)
	var c := b
	while prev.has(b) and c != a:
		s.debug_dig(c)
		c = prev[c]


func test_cans_and_a_bench_count_for_a_site_job(t: TestCase) -> void:
	var s := TestCase.new_session(777)
	_start(s)
	s.debug_open_site("outlook")
	var k := s.jobs.draw("more_cans", {"site_id": "outlook", "site": "Scenic Outlook", "_at": "outlook", "count": 2})
	var k2 := s.jobs.draw("a_seat", {"site_id": "outlook", "site": "Scenic Outlook", "_at": "outlook"})
	t.equal(str(s.jobs.def(k)["steps"][0]["at"]), "place:outlook", "the blank inside the place is filled in")
	var spot := Vector2i(s.park.place_spot("outlook"))
	var n := 0
	for off in [Vector2i(2, 2), Vector2i(-2, 2), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(3, 3), Vector2i(-3, 3)]:
		if n >= 3:
			break
		_hold(s, "trash_can" if n < 2 else "bench")
		s.outdoor_pos = Vector2(spot + off) + Vector2(0.5, 1.5)
		s.facing = 2
		var before := s.park.things.size()
		s.use_item()
		if s.park.things.size() > before:
			n += 1
	s.jobs.update(true)
	t.equal(n, 3, "two cans and a bench put down by the outlook")
	t.check(s.jobs.is_done(k), "the cans job is done (tracker #16)")
	t.check(s.jobs.is_done(k2), "the bench job is done (tracker #24)")


func test_the_pond_trail_joins_once_its_work_is_done(t: TestCase) -> void:
	var s := TestCase.new_session(777)
	_start(s)
	s.debug_open_site("old_cabin")
	s.jobs.update(true)
	_clear(s, "reopen_pond_trail", 1)
	_dig(s, "pond_gap_1")
	_dig(s, "pond_gap_2")
	s._reach_cache.clear()
	s.jobs.update(true)
	t.check(s.site_reached("kettle_pond"), "trail joins the station to the pond (tracker #19)")
	for i in [1, 2, 3, 4]:
		t.check(bool(s.jobs.check("reopen_pond_trail", i)["done"]), "pond trail step %d done" % i)


func test_the_stake_trail_reaches_the_tower(t: TestCase) -> void:
	var s := TestCase.new_session(777)
	_start(s)
	s.debug_open_site("old_cabin")
	_clear(s, "reopen_pond_trail", 1)
	_dig(s, "pond_gap_1")
	_dig(s, "pond_gap_2")
	s.debug_open_site("kettle_pond")
	_clear(s, "stake_west", 1)
	_clear(s, "stake_east", 1)
	_dig(s, "stake_gap_west")
	_dig(s, "stake_gap_east")
	s._reach_cache.clear()
	s.jobs.update(true)
	for job in ["stake_west", "stake_east"]:
		for i in [1, 2, 3]:
			t.check(bool(s.jobs.check(job, i)["done"]), "%s step %d done (tracker #23)" % [job, i])
	t.check(s.site_reached("static_tower"), "trail joins the station to the tower")


func test_x_at_the_pond_cairn_maps_it_among_reeds(t: TestCase) -> void:
	var s := TestCase.new_session(777)
	s.debug_reveal_map()
	s.map.mapped_landmarks.erase("kettle_pond")
	var lm := s.world.interactive_near(s.site_door("kettle_pond"), 8.0)
	t.check(not lm.is_empty(), "the pond has its cairn")
	var p0: Vector2 = lm["pos"]
	for off: Vector2 in [Vector2(0, 1.2), Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, -1.2)]:
		if not s.world.is_solid(Vector2i(p0 + off)):
			s.outdoor_pos = p0 + off
			break
	s.debug_spawn_forage(Vector2i(s.outdoor_pos) + Vector2i(1, 0), "reeds")
	s.interact()
	t.check(s.map.is_landmark_mapped("kettle_pond"), "X maps the cairn, not the reeds (tracker #25)")


func test_walking_out_of_something_put_down_on_you(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := s.outdoor_pos
	var t0 := Vector2i(p)
	s.world._blocked[t0] = true
	s.move(Vector2(1, 0), 0.5)
	t.check(s.outdoor_pos.x > p.x, "a step walks out of a solid tile (tracker #12, #14)")
	s.world._blocked.erase(t0)


func test_a_camp_packs_up_with_the_hammer(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.backpack.add("firewood", 2)
	s.backpack.add("hammer", 1)
	t.check(s.make_camp(), "camp made")
	_hold(s, "hammer")
	s.use_item()
	t.check(s.camp.is_empty(), "the hammer packs it up (tracker #20)")


func test_placing_tries_the_tiles_beside_the_faced_one(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_reveal_map()
	var tiles := s.place_tiles()
	t.equal(tiles.size(), 5, "the faced tile and four beside")
	t.equal(tiles[0], s.ranger_tile() + s.facing_vector(), "the faced tile first")


func test_show_on_map_has_somewhere_for_a_place_not_found(t: TestCase) -> void:
	var s := TestCase.new_session(777)
	_start(s)
	var k := "open_pond"
	if not s.jobs.known.has(k):
		s.jobs.add(k, "given")
	t.equal(s.jobs.step_pos(k, 0), Vector2.INF, "finding the pond has no place of its own")
	if s.hint_known("kettle_pond"):
		t.check(s.jobs.map_pos(k, 0) != Vector2.INF, "but Show on map goes to its rumor (tracker #22)")
