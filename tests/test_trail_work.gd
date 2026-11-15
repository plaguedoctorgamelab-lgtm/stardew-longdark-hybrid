extends RefCounted
## Phase 2a, step 3: the shovel and saw, clearing brush and fallen trunks,
## and digging new trail. Changes to the land are kept in the save.


func _obstacle(s: GameSession, kind: String) -> Vector2i:
	for o: Array in s.world.meta["obstacles_on_routes"]:
		if str(o[2]) == kind:
			return Vector2i(int(o[0]), int(o[1]))
	return Vector2i(-1, -1)


## Stands the ranger on an open tile next to t, facing it.
func _stand_by(s: GameSession, t: Vector2i) -> bool:
	var dirs := [[Vector2i(0, 1), GameSession.FACING_UP], [Vector2i(0, -1), GameSession.FACING_DOWN], [Vector2i(-1, 0), GameSession.FACING_RIGHT], [Vector2i(1, 0), GameSession.FACING_LEFT]]
	for d: Array in dirs:
		var at: Vector2i = t + (d[0] as Vector2i)
		if not s.world.is_solid(at):
			s.outdoor_pos = Vector2(at) + Vector2(0.5, 0.5)
			s.facing = int(d[1])
			return true
	return false


func _open_grass(s: GameSession) -> Vector2i:
	s.debug_teleport("station")
	var start := s.ranger_tile()
	for dy in range(-12, 12):
		for dx in range(3, 20):
			var t := start + Vector2i(dx, dy)
			if s.world.ground_at(t) == "grass" and not s.world.is_solid(t) and not s.world.is_solid(t + Vector2i(-1, 0)):
				s.outdoor_pos = Vector2(t) + Vector2(-0.5, 0.5)
				s.facing = GameSession.FACING_RIGHT
				return t
	return Vector2i(-1, -1)


func test_new_tools_are_found(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.equal((s.structures.chests["ranger_station"] as Inventory).count("shovel"), 1, "a shovel in the station chest")
	t.equal((s.structures.chests["test_cabin"] as Inventory).count("saw"), 1, "a saw in the old cabin's chest")
	t.check(not s.structures.is_open("test_cabin"), "which opens only once the cabin is repaired")


func test_brush_needs_the_axe(t: TestCase) -> void:
	var s := TestCase.new_session()
	var b := _obstacle(s, "brush")
	t.check(b.x >= 0, "there is brush across an old trail")
	t.check(s.world.is_solid(b), "brush blocks the way")
	t.check(_stand_by(s, b), "room to stand by it")
	t.equal(s.clear_obstacle().get("reason", ""), "no_tool", "no clearing without the axe")
	s.debug_add_item("axe")
	s.debug_set_needs(200, 100)
	var m0 := s.clock.minute
	var res := s.clear_obstacle()
	t.check(res.get("cleared", false), "one axe action clears brush")
	t.equal(s.needs.energy, 200.0 - s.tuning.num("clearing.brush.energy"), "costs its energy")
	t.equal(s.clock.minute, m0 + s.tuning.integer("clearing.brush.minutes"), "takes its time")
	t.check(not s.world.is_solid(b), "the way is open")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	t.equal(s2.load_game(), "", "loads")
	t.check(not s2.world.is_solid(b), "cleared brush stays cleared")


func test_trunks_need_the_saw_and_several_actions(t: TestCase) -> void:
	var s := TestCase.new_session()
	var tr := _obstacle(s, "fallen_trunk")
	t.check(tr.x >= 0, "a fallen trunk across an old trail")
	t.check(_stand_by(s, tr + Vector2i(1, 0)), "room to stand by it")
	s.debug_add_item("axe")
	t.equal(s.clear_obstacle().get("reason", ""), "no_tool", "the axe will not do for a trunk")
	s.debug_add_item("saw")
	s.debug_set_needs(200, 100)
	var total := s.tuning.integer("clearing.fallen_trunk.actions")
	var m0 := s.clock.minute
	var res := s.clear_obstacle()
	t.check(res.get("ok", false) and not res.get("cleared", true), "the first cut does not clear it")
	t.equal(int(res["done"]), 1, "one of %d" % total)
	t.check(s.world.is_solid(tr + Vector2i(1, 0)), "still in the way")
	t.check(s.save_game(), "saved part way")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.equal(int(s2.clearing_progress.get(res["origin"], 0)), 1, "progress kept between visits")
	for i in total - 1:
		res = s.clear_obstacle()
	t.check(res.get("cleared", false), "cleared after %d actions" % total)
	t.equal(s.needs.energy, 200.0 - s.tuning.num("clearing.fallen_trunk.energy") * total, "each action costs energy")
	t.equal(s.clock.minute, m0 + s.tuning.integer("clearing.fallen_trunk.minutes") * total, "each action takes time")
	for dx in 3:
		t.check(not s.world.is_solid(Vector2i(res["origin"]) + Vector2i(dx, 0)), "all of the trunk is gone")


func test_digging_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	var g := _open_grass(s)
	t.check(g.x >= 0, "open grass by the station")
	t.equal(s.dig().get("reason", ""), "no_tool", "no digging without the shovel")
	s.debug_add_item("shovel")
	s.debug_set_needs(200, 100)
	var m0 := s.clock.minute
	var res := s.dig()
	t.check(res.get("ok", false), "dug")
	t.equal(s.world.ground_at(g), "trail", "the grass is now trail")
	t.equal((res["tiles"] as Array).size(), mini(s.tuning.integer("trail.tiles_per_action"), 2 if s.can_dig(g + Vector2i(1, 0)) or s.world.ground_at(g + Vector2i(1, 0)) == "trail" else 1), "digs %d tiles a go" % s.tuning.integer("trail.tiles_per_action"))
	t.equal(s.needs.energy, 200.0 - s.tuning.num("trail.energy"), "digging costs energy")
	t.equal(s.clock.minute, m0 + s.tuning.integer("trail.minutes"), "and time")
	s.outdoor_pos = Vector2(g) + Vector2(0.5, 0.5)
	s.debug_force_weather("clear")
	t.near(s.speed_tiles_per_second(), s.tuning.num("movement.trail_speed_tiles"), 0.001, "dug trail walks at trail speed")
	t.check(s.on_trail(), "and counts as trail")
	s.debug_set_time(23 * 60)
	s.map.reveal_circle(s.outdoor_pos, 3)
	t.check(s.marker_visible(), "so the marker shows at night there")
	t.check(s.save_game(), "saved")
	var s2 := TestCase.new_session(1)
	s2.save_path = s.save_path
	s2.load_game()
	t.equal(s2.world.ground_at(g), "trail", "dug trail is kept in the save")
	var img := MapScreen.render(s2, Rect2i(g - Vector2i(2, 2), Vector2i(5, 5)))
	var want: Color = MapScreen.GROUND_COLORS["trail"]
	var got := img.get_pixelv(g)
	t.check(absf(got.r - want.r) < 0.01 and absf(got.g - want.g) < 0.01 and absf(got.b - want.b) < 0.01, "the map shows it as trail")


func test_cannot_dig_rock_water_or_solid(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("shovel")
	var w := s.world
	var tested := {}
	var b := w.baked_bounds()
	for y in range(b.position.y + 40, b.end.y - 40, 3):
		for x in range(b.position.x + 40, b.position.x + 400, 3):
			var tile := Vector2i(x, y)
			var g := w.ground_at(tile)
			var key := g if not w.is_solid(tile) or g in ["rock", "deep_water"] else "solid"
			if g in ["rock", "deep_water", "shallows"] or (w.is_solid(tile) and g == "forest_floor"):
				if not tested.has(key):
					tested[key] = true
					t.check(not s.can_dig(tile), "no digging on %s" % key)
	t.check(tested.size() >= 3, "tried several kinds (%s)" % ", ".join(tested.keys()))


func test_debug_land_tools(t: TestCase) -> void:
	var s := TestCase.new_session()
	var b := _obstacle(s, "brush")
	t.check(s.debug_clear_obstacle(b), "debug clears an obstacle")
	t.check(not s.world.is_solid(b), "gone")
	t.check(s.debug_clear_obstacle(b, false), "and puts it back")
	t.check(s.world.is_solid(b), "back")
	var g := _open_grass(s)
	s.debug_dig(g)
	t.equal(s.world.ground_at(g), "trail", "debug digs")
	s.debug_dig(g, false)
	t.equal(s.world.ground_at(g), "grass", "and undoes")
	s.new_game(5)
	t.check(s.cleared.is_empty() and s.dug.is_empty(), "a new game starts with untouched land")
