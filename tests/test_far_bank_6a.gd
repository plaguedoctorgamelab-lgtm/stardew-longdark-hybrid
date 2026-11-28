extends RefCounted
## Phase 6a, the far bank (docs/Phase 6 Spec.md, sections 1 to 3): the
## river and Skull Lake, Troll Badger Bridge, the seasons that change the
## land, the canoe and the cart.


func _season(s: GameSession, season: int, day: int) -> void:
	s.clock.season = season
	s.clock.day = day
	s._apply_seasons()


func _pt(s: GameSession, name: String) -> Vector2i:
	var v: Array = s.world.meta["trail_job_points"][name]
	return Vector2i(int(v[0]), int(v[1]))


func _tiles(s: GameSession, key: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for v: Array in s.world.meta["seasonal"][key]:
		out.append(Vector2i(int(v[0]), int(v[1])))
	return out


## Whether b can be walked to from a, within a box around both.
func _walk(s: GameSession, a: Vector2i, b: Vector2i, margin: int = 160) -> bool:
	var lo := Vector2i(mini(a.x, b.x) - margin, mini(a.y, b.y) - margin)
	var hi := Vector2i(maxi(a.x, b.x) + margin, maxi(a.y, b.y) + margin)
	var seen := {a: true}
	var q: Array[Vector2i] = [a]
	var head := 0
	while head < q.size():
		var t := q[head]
		head += 1
		if t == b:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var u := t + d
			if seen.has(u) or u.x < lo.x or u.y < lo.y or u.x > hi.x or u.y > hi.y:
				continue
			if s.world.is_solid(u):
				continue
			seen[u] = true
			q.append(u)
	return false


func test_the_far_bank_is_baked_with_its_lake(t: TestCase) -> void:
	var s := TestCase.new_session()
	for k: String in ["dusk_river_landing", "logging_camp", "skull_lake", "left_eye_island", "right_eye_island", "nose_island"]:
		t.check(s.world.meta["landmarks"].has(k), "%s is on the land" % k)
	var lake := Vector2i(s.world.landmark_pos("skull_lake"))
	t.equal(s.world.ground_at(lake + Vector2i(0, -80)), "lake", "the lake is lake")
	t.check(s.world.is_solid(lake + Vector2i(0, -80)), "and can't be walked on")
	t.equal(s.world.ground_at(Vector2i(s.world.landmark_pos("left_eye_island"))), "grass", "the eye island is land")
	t.check(s.world.width >= 1460, "the region reaches 1,460 tiles east")


func test_only_the_mended_bridge_crosses(t: TestCase) -> void:
	var s := TestCase.new_session()
	var near := Vector2i(s.world.spawn("bridge"))
	var landing := Vector2i(s.world.spawn("landing"))
	t.check(not _walk(s, near, landing), "the gap can't be crossed")
	s.debug_far_bank("bridge")
	t.check(_walk(s, near, landing), "the mended bridge crosses to the landing")
	t.equal(s.world.ground_at(_pt(s, "bridge_gap")), "boards", "boards over the gap")


func test_seasons_change_the_land(t: TestCase) -> void:
	var s := TestCase.new_session()
	var lake := Vector2i(s.world.landmark_pos("skull_lake")) + Vector2i(0, -80)
	var ford: Vector2i = _tiles(s, "fords")[0]
	var sand: Vector2i = _tiles(s, "summer_ford")[0]
	var ice: Vector2i = _tiles(s, "ice_crossing")[0]
	var snow: Vector2i = _tiles(s, "snow_closed")[0]
	_season(s, 0, 2)
	t.check(not s.world.is_solid(ford), "no melt in the very first spring")
	s.clock.year = 2
	_season(s, 0, 2)
	t.check(s.world.is_solid(ford), "the melt floods the fords")
	t.check(not s.world.is_solid(snow), "the high trail is open in spring")
	_season(s, 0, 10)
	t.check(not s.world.is_solid(ford), "and they're fordable after a week")
	t.check(s.world.is_solid(sand), "no summer ford in spring")
	_season(s, 1, 5)
	t.equal(s.world.ground_at(sand), "sandbar", "low water: the summer ford")
	t.check(not s.world.is_solid(sand), "walkable")
	_season(s, 3, 3)
	t.check(s.world.is_solid(lake), "the lake isn't frozen yet")
	t.check(s.world.is_solid(snow), "the high trail is snowed in")
	_season(s, 3, 7)
	t.equal(s.world.ground_at(lake), "ice", "the lake freezes on the 7th of winter")
	t.check(not s.world.is_solid(lake), "and can be walked on")
	t.check(s.world.is_solid(ice), "the river isn't frozen yet")
	_season(s, 3, 14)
	t.check(not s.world.is_solid(ice), "the ice crossing from the 14th")
	_season(s, 0, 1)
	t.check(s.world.is_solid(lake), "the thaw in spring")


func test_the_islands_need_the_ice(t: TestCase) -> void:
	var s := TestCase.new_session()
	var shore := Vector2i(s.world.landmark_pos("skull_lake")) + Vector2i(0, -125)
	while s.world.is_solid(shore):
		shore.y -= 1
	var eye := Vector2i(s.world.landmark_pos("left_eye_island"))
	_season(s, 2, 10)
	t.check(not _walk(s, shore, eye, 40), "no walking to the island in autumn")
	_season(s, 3, 10)
	t.check(_walk(s, shore, eye, 40), "across the ice in winter")


func test_the_canoe(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, 1, 5)
	s.debug_far_bank("bridge")
	s.debug_far_bank("canoe")
	var v := s.vehicles
	t.equal(v.riding, "canoe", "in the canoe")
	t.check(v.blocks(Vector2i(s.world.spawn("landing"))), "it doesn't go on land")
	# Out onto the river and test the current.
	var water := Vector2i(-1, -1)
	for p: Variant in s.world.meta["river_flow"]:
		var q := Vector2i(int(p[0]), int(p[1]))
		if s.world.ground_at(q) == "deep_water":
			water = q
	s.outdoor_pos = Vector2(water) + Vector2(0.5, 0.5)
	var f := v.flow_at(s.outdoor_pos)
	t.check(f != Vector2.ZERO, "the river has a current")
	t.check(v.speed(f) > v.speed(-f), "faster downstream than up")
	s.clock.year = 2
	_season(s, 0, 2)
	t.equal(v.speed(-f), 0.0, "no paddling upstream in the melt")
	_season(s, 1, 5)
	s.outdoor_pos = v.canoe_pos
	var said := v.leave()
	t.equal(v.riding, "", "stepped ashore")
	t.check(said != "", "and said so")
	_season(s, 3, 2)
	t.equal(v.board("canoe"), s.content.text("fb_canoe_winter"), "put away for the winter")


func test_the_cart_and_cart_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_far_bank("cart")
	var v := s.vehicles
	t.equal(v.riding, "cart", "in the cart")
	t.check(v.is_cart_trail(Vector2i(v.cart_pos)), "parked on cart trail: the old logging road")
	t.near(v.speed(Vector2.RIGHT), s.tuning.num("movement.trail_speed_tiles") * 3.0, 0.01, "three times walking speed")
	# Off the cart trail it can't go.
	var off := Vector2i(s.world.spawn("logging_camp"))
	t.check(v.blocks(off), "not onto the camp's grass")
	v.leave()
	# Widen a plain trail with the shovel.
	var tr := Vector2i(-1, -1)
	var c := Vector2i(s.world.spawn("pond"))
	for dy in range(-30, 30):
		for dx in range(-30, 30):
			var u := c + Vector2i(dx, dy)
			if s.world.ground_at(u) == "trail" and not v.is_cart_trail(u):
				tr = u
				break
		if tr.x >= 0:
			break
	t.check(tr.x >= 0, "a plain trail near the pond")
	t.check(not v.is_cart_trail(tr), "not cart trail yet")
	s.backpack.add("shovel", 1)
	s.outdoor_pos = Vector2(tr) + Vector2(0.5, 1.5)
	s.facing = GameSession.FACING_UP
	var r := s.dig()
	t.check(bool(r.get("ok", false)), "the shovel widens it")
	t.check(v.is_cart_trail(tr), "cart trail now")


func test_the_toll(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_far_bank("bridge")
	s.backpack.add("apple", 2)
	var hearts := s.creatures.points.get("troll_badgers", 0) as int
	var said := s.vehicles.pay_toll()
	t.check(said.contains("apple"), "an apple in the toll box")
	t.equal(s.backpack.count("apple"), 1, "one apple paid")
	t.check(int(s.creatures.points.get("troll_badgers", 0)) > hearts, "the badgers like it")
	s.vehicles.pay_toll()
	t.equal(s.backpack.count("apple"), 1, "once a day")


func test_the_jobs_lead_on(t: TestCase) -> void:
	var s := TestCase.new_session()
	for id: String in ["mend_bridge", "open_landing", "build_canoe", "open_logging_camp", "fix_cart"]:
		t.check(s.content.has("jobs", id), "%s is a job" % id)
	var steps: Array = s.content.row("jobs", "build_canoe")["rewards"]
	t.equal(str(steps[0]["what"]), "canoe", "building the canoe unlocks it")
	for sp: String in ["bridge_mend", "landing_boathouse", "canoe_build", "sawmill", "plank_pile", "cart_fix"]:
		t.check(s.jobs.spot_pos(sp) != Vector2.INF, "%s has its place" % sp)


func test_vehicles_save_and_load(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_far_bank("bridge")
	s.debug_far_bank("cart")
	s.vehicles.leave()
	s.vehicles.widened[Vector2i(10, 10)] = true
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(JSON.parse_string(JSON.stringify(d)))
	t.check(s2.vehicles.cart_pos.distance_to(s.vehicles.cart_pos) < 0.01, "the cart where it was parked")
	t.check(s2.vehicles.widened.has(Vector2i(10, 10)), "widened trail")
	s2.vehicles.update()
	t.equal(s2.world.ground_at(_pt(s2, "bridge_gap")), "boards", "the bridge still mended")
