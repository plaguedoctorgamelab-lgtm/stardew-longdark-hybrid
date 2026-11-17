extends RefCounted
## Phase 2b: foraging, the magical ingredients, crafting in two tiers and
## cooking, ideas, the magic slot and refits, placeables, the pack frame,
## skills and specialties, saves and secrecy. One test (or more) for each line
## of the spec's table of automated tests.


func _season(s: GameSession, name: String, day: int = 10) -> void:
	s.clock.year = 1
	s.clock.season = GameClock.SEASONS.find(name)
	s.clock.day = day


func _ground_rows(s: GameSession) -> Array:
	return s.content.rows("forage").filter(func(r: Dictionary) -> bool: return str(r.get("source", "ground")) == "ground" and not bool(r.get("magic", false)))


## A spot of this forage holding something today, or (-1, -1).
func _full_spot(s: GameSession, forage_id: String) -> Vector2i:
	var today := s.clock.absolute_day()
	for t: Vector2i in s.forage.spots:
		if s.forage.spots[t] == forage_id and s.forage.has_ground_now(t, today):
			return t
	return Vector2i(-1, -1)


func _magic_place(s: GameSession, id: String) -> Vector2i:
	for t: Vector2i in s.forage.magic_used:
		if s.forage.magic_at(t) == id:
			return t
	return Vector2i(-1, -1)


## Stands the ranger on open ground beside t, facing it.
func _stand_by(s: GameSession, t: Vector2i) -> bool:
	if s.is_indoors():
		s.location = ""
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]
	var faces: Array[int] = [GameSession.FACING_UP, GameSession.FACING_RIGHT, GameSession.FACING_LEFT, GameSession.FACING_DOWN]
	for i in dirs.size():
		var p := t + dirs[i]
		if not s.world.is_solid(p):
			s.outdoor_pos = Vector2(p) + Vector2(0.5, 0.5)
			s.facing = faces[i]
			return true
	return false


## An open tile of one of these grounds near the station, with open ground
## beside it, or (-1, -1).
func _ground_near_station(s: GameSession, grounds: Array, radius: int = 120) -> Vector2i:
	var c := Vector2i(s.world.spawn("station"))
	for r in range(2, radius):
		for dy in range(-r, r + 1):
			for dx in [-r, r]:
				for tt: Vector2i in [c + Vector2i(dx, dy), c + Vector2i(dy, dx)]:
					if grounds.has(s.world.ground_at(tt)) and not s.world.is_solid(tt) and s.world.object_at(tt) == "" and not s.world.is_solid(tt + Vector2i(0, 1)):
						return tt
	return Vector2i(-1, -1)


func _at_workbench(s: GameSession) -> void:
	s.enter_building("ranger_station")


func _at_fire(s: GameSession) -> bool:
	s.debug_teleport("station")
	s.outdoor_pos += Vector2(4, 3)
	s.facing = GameSession.FACING_RIGHT
	if not s.backpack.has("bedroll"):
		s.debug_add_item("bedroll")
	s.debug_add_item("firewood", 1)
	return s.make_camp()


# --- forage --------------------------------------------------------------------

func test_forage_spots_are_on_their_ground(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in _ground_rows(s):
		var n := 0
		for p: Vector2i in s.forage.spots:
			if s.forage.spots[p] != r["id"]:
				continue
			n += 1
			var grounds := []
			for rule: Dictionary in r["where"]:
				grounds.append_array(rule["grounds"])
			if not t.check(grounds.has(s.world.ground_at(p)) and not s.world.is_solid(p) and s.world.object_at(p) == "", "%s at %s is on open %s" % [r["id"], p, s.world.ground_at(p)]):
				break
		t.check(n > 0, "%s has spots (%d)" % [r["id"], n])


func test_forage_appears_only_in_its_seasons(t: TestCase) -> void:
	var s := TestCase.new_session()
	var dps := s.tuning.integer("time.days_per_season")
	for r: Dictionary in _ground_rows(s):
		var spots := s.forage.spots.keys().filter(func(p: Vector2i) -> bool: return s.forage.spots[p] == r["id"]).slice(0, 60)
		var grew := 0
		var wrong := 0
		for day in range(0, dps * 4, 3):
			for p: Vector2i in spots:
				if s.forage.grew_on(p, day):
					grew += 1
					if not s.forage.in_season(r, day):
						wrong += 1
		t.check(grew > 0, "%s grows in its seasons" % r["id"])
		t.equal(wrong, 0, "%s never grows out of season on dry days" % r["id"])


func test_mushrooms_come_up_after_rain(t: TestCase) -> void:
	var s := TestCase.new_session()
	var spring := 5
	var spots := s.forage.spots.keys().filter(func(p: Vector2i) -> bool: return s.forage.spots[p] == "mushrooms")
	var before := spots.filter(func(p: Vector2i) -> bool: return s.forage.grew_on(p, spring)).size()
	t.equal(before, 0, "no mushrooms in spring on a dry day")
	s.forage.note_wet_day(spring - 1)
	var after := spots.filter(func(p: Vector2i) -> bool: return s.forage.grew_on(p, spring)).size()
	t.check(after > 0, "mushrooms come up the day after rain (%d)" % after)


func test_uncollected_forage_expires(t: TestCase) -> void:
	var s := TestCase.new_session()
	var lasts := s.tuning.integer("forage.lasts_days")
	var checked := 0
	for p: Vector2i in s.forage.spots:
		for day in range(30, 50):
			if not s.forage.grew_on(p, day):
				continue
			for k in lasts:
				t.check(s.forage.grown_day(p, day + k) >= day, "forage at %s stays %d days" % [p, k])
			t.check(s.forage.grown_day(p, day + lasts) != day, "and is gone after %d days" % lasts)
			checked += 1
			break
		if checked >= 20:
			break
	t.check(checked >= 20, "checked enough spots (%d)" % checked)


func test_picking_takes_the_forage(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, "spring")
	var p := _full_spot(s, "wild_onion")
	t.check(p.x >= 0, "a wild onion is out somewhere in spring")
	_stand_by(s, p)
	var res := s.pick_forage(p)
	t.check(res.get("ok", false), "picked")
	t.equal(s.backpack.count("wild_onion"), 1, "it goes in the backpack")
	t.check(not s.forage_showing(p), "and is gone from the ground")
	t.check(not s.pick_forage(p).get("ok", false), "it cannot be picked twice")


func test_active_spots_follow_the_seed(t: TestCase) -> void:
	var a := TestCase.new_session(7)
	var b := TestCase.new_session(7)
	var c := TestCase.new_session(8)
	var on_a := []
	var on_b := []
	var on_c := []
	for p: Vector2i in a.forage.spots:
		if a.forage.is_active(p, 0):
			on_a.append(p)
		if b.forage.is_active(p, 0):
			on_b.append(p)
		if c.forage.is_active(p, 0):
			on_c.append(p)
	t.check(on_a.size() > 0, "some spots are active")
	t.equal(on_a, on_b, "the same seed gives the same active spots")
	t.check(on_a != on_c, "another seed gives other active spots")
	var next := 0
	for p: Vector2i in on_a:
		if a.forage.is_active(p, a.tuning.integer("time.days_per_season")):
			next += 1
	t.check(next < on_a.size(), "and they shift with the season")


func test_bushes_and_pines(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, "summer")
	var bush := _find_object(s, "bush")
	t.check(bush.x >= 0, "a bush near the station")
	_stand_by(s, bush)
	t.equal(str(s.object_forage_ready(bush).get("item", "")), "berries", "a bush has berries in summer")
	t.check(s.pick_object(bush).get("ok", false), "berries picked")
	t.check(s.object_forage_ready(bush).is_empty(), "the bush is bare for now")
	s.clock.day += s.tuning.integer("forage.bush_refruit_days")
	t.equal(str(s.object_forage_ready(bush).get("item", "")), "berries", "it fruits again after %d days" % s.tuning.integer("forage.bush_refruit_days"))
	_season(s, "winter")
	t.equal(str(s.object_forage_ready(bush).get("item", "")), "rose_hips", "in winter it has rose hips")
	_season(s, "spring")
	t.check(s.object_forage_ready(bush).is_empty(), "and in spring nothing")
	var pine := _find_object(s, "tree_pine")
	_stand_by(s, pine)
	t.check(s.pick_object(pine).get("ok", false), "resin from a pine")
	t.equal(s.backpack.count("pine_resin"), 1, "one pine resin")
	s.clock.day += s.tuning.integer("forage.resin_days") - 1
	t.check(s.object_forage_ready(pine).is_empty(), "the pine gives once a week")
	s.clock.day += 1
	t.check(not s.object_forage_ready(pine).is_empty(), "and again after a week")


func _find_object(s: GameSession, kind: String) -> Vector2i:
	var c := Vector2i(s.world.spawn("station"))
	for r in range(1, 200):
		for dy in range(-r, r + 1):
			for dx in [-r, r]:
				for tt: Vector2i in [c + Vector2i(dx, dy), c + Vector2i(dy, dx)]:
					if s.world.object_at(tt) == kind:
						for d: Vector2i in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
							if not s.world.is_solid(tt + d):
								return tt
	return Vector2i(-1, -1)


func test_raw_forage_is_food(t: TestCase) -> void:
	var s := TestCase.new_session()
	for id in ["berries", "hazelnuts", "mushrooms", "wild_onion", "fiddleheads", "rose_hips"]:
		var e := float(s.content.row("foods", id)["energy"])
		t.check(e >= 5.0 and e <= 10.0, "%s gives 5 to 10 energy raw (%d)" % [id, e])
	t.check(not s.content.has("foods", "wildflowers"), "wildflowers are not food")


## A simulated hour's walk on the trail, in each season, picking whatever is
## near enough to see and step over to (3 tiles) without searching. Every
## hour-long stretch of the longest trail is walked, in three saves; on
## average the forage fills the tuned number of slots.
func test_an_hours_walk_yields_forage(t: TestCase) -> void:
	var range_: Array = TestCase.new_session().tuning.value("forage.walk_yield_slots")
	for season in ["spring", "summer", "autumn", "winter"]:
		var slots := _average_walk(season)
		t.check(slots >= float(range_[0]) and slots <= float(range_[1]), "%s: an hour's walk fills %.1f slots on average (want %d to %d)" % [season, slots, int(range_[0]), int(range_[1])])


func _average_walk(season: String) -> float:
	var total := 0.0
	var n := 0
	for seed_value in range(1, 4):
		var s := TestCase.new_session(seed_value)
		var hour := _hour_tiles(s)
		var length := float(s.world.meta["route_lengths"]["bridge"])
		var start := 0.0
		while start + hour <= length:
			total += _walk_hour(s, season, start)
			n += 1
			start += hour
	return total / maxf(1.0, float(n))


func _hour_tiles(s: GameSession) -> float:
	return s.tuning.num("movement.trail_speed_tiles") * s.tuning.num("time.real_seconds_per_step") * 60.0 / s.tuning.num("time.minutes_per_step")


var last_walk: Dictionary = {}


func _walk_hour(s: GameSession, season: String, start: float = 0.0) -> int:
	_season(s, season, 12)
	var reach := 3.0
	var tiles := _hour_tiles(s)
	var route: Array = s.world.meta["routes"]["bridge"]
	var got := {}
	var seen := {}
	var walked := 0.0
	var prev := Vector2(float(route[0][0]), float(route[0][1]))
	for i in range(1, route.size()):
		var nxt := Vector2(float(route[i][0]), float(route[i][1]))
		var seg := prev.distance_to(nxt)
		if walked + seg < start:
			walked += seg
			prev = nxt
			continue
		var steps := maxi(1, ceili(seg * 2.0))
		for k in steps:
			var p := prev.lerp(nxt, float(k) / steps)
			var c := Vector2i(floori(p.x), floori(p.y))
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var tt := c + Vector2i(dx, dy)
					if seen.has(tt) or p.distance_to(Vector2(tt) + Vector2(0.5, 0.5)) > reach:
						continue
					var item := ""
					if s.forage.spots.has(tt) and s.forage.has_ground_now(tt, s.clock.absolute_day()):
						item = s.content.row("forage", s.forage.spots[tt])["item"]
					elif s.content.row("forage", "berries")["objects"].has(s.world.object_at(tt)):
						item = str(s.object_forage_ready(tt).get("item", ""))
					if item != "":
						seen[tt] = true
						got[item] = int(got.get(item, 0)) + 1
		walked += seg
		prev = nxt
		if walked >= start + tiles:
			break
	last_walk = got
	var slots := 0
	for item: String in got:
		slots += ceili(float(got[item]) / s.backpack.stack_size(item))
	return slots


# --- magical ingredients -------------------------------------------------------

func test_each_save_uses_its_number_of_places(t: TestCase) -> void:
	var a := TestCase.new_session(7)
	var c := TestCase.new_session(8)
	for id: String in a.forage.magic_places:
		t.equal((a.forage.magic_places[id] as Array).size(), a.tuning.integer("magic.places_per_ingredient"), "%s has its possible places" % id)
		t.equal(a.forage.magic_used.values().count(id), a.tuning.integer("magic.places_per_save"), "%s: a save uses its tuned number" % id)
		for p: Vector2i in a.forage.magic_used:
			if a.forage.magic_at(p) == id:
				t.check((a.forage.magic_places[id] as Array).has(p), "%s: used places are possible places" % id)
	t.check(a.forage.magic_used != c.forage.magic_used, "another seed uses other places")


func test_glowcap_only_at_night_and_regrows(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := _magic_place(s, "glowcap")
	_stand_by(s, p)
	s.debug_force_weather("clear")
	s.debug_set_time(12 * 60)
	t.check(not s.forage_showing(p), "not seen by day")
	t.check(not s.pick_forage(p).get("ok", false), "nor picked by day")
	s.debug_set_time(23 * 60)
	t.check(s.forage_showing(p), "seen at night")
	t.check(s.pick_forage(p).get("ok", false), "picked at night")
	var regrow := s.tuning.integer("magic.glowcap_regrow_days")
	s.clock.day += regrow - 1
	t.check(not s.forage_showing(p), "not back before %d days" % regrow)
	s.clock.day += 1
	t.check(s.forage_showing(p), "back after %d days" % regrow)


func test_ember_moss_only_in_snowy_weather(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := _magic_place(s, "ember_moss")
	_stand_by(s, p)
	s.debug_set_time(12 * 60)
	for w in ["clear", "rain", "fog", "storm"]:
		s.debug_force_weather(w)
		t.check(not s.forage_showing(p), "no ember moss in %s" % w)
	for w in ["snow", "blizzard"]:
		s.debug_force_weather(w)
		t.check(s.forage_showing(p), "ember moss in %s" % w)
	t.check(s.pick_forage(p).get("ok", false), "picked in the snow")


func test_lodestone_is_dug_up_once(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := _magic_place(s, "lodestone_sliver")
	_stand_by(s, p)
	t.check(not s.forage_showing(p), "it does not show: it is buried")
	t.check(not s.pick_forage(p).get("ok", false), "and cannot be picked")
	s.debug_add_item("shovel")
	var res := s.dig()
	t.check(res.get("dug_up", false), "the shovel digs it up")
	t.equal(s.backpack.count("lodestone_sliver"), 1, "one sliver")
	s.clock.day += 60
	t.check(not s.forage.has_magic(p, s.clock.absolute_day(), s.forage_ctx()), "it never comes back")
	t.check(not s.dig().get("dug_up", false), "digging again finds nothing")


func test_compass_trembles_only_in_range(t: TestCase) -> void:
	var s := TestCase.new_session()
	var p := _magic_place(s, "lodestone_sliver")
	var r := s.tuning.num("magic.compass_tremble_tiles")
	s.location = ""
	s.outdoor_pos = Vector2(p) + Vector2(0.5, 0.5) + Vector2(r - 1.0, 0)
	t.check(s.compass_trembling(), "the compass trembles within %d tiles" % int(r))
	s.outdoor_pos = Vector2(p) + Vector2(0.5, 0.5) + Vector2(r + 3.0, 0)
	t.check(not s.compass_trembling(), "but not further away")
	s.outdoor_pos = Vector2(p) + Vector2(0.5, 0.5) + Vector2(r - 1.0, 0)
	s.backpack.remove("compass", 1)
	t.check(not s.compass_trembling(), "only when the compass is carried")


func test_first_find_is_logged_with_an_idea(t: TestCase) -> void:
	var s := TestCase.new_session()
	var notes := []
	s.note_read.connect(func(text: String) -> void: notes.append(text))
	s.debug_spawn_forage(Vector2i(s.ranger_tile() + Vector2i(1, 0)), "glowcap")
	s.debug_set_time(23 * 60)
	t.check(s.pick_forage(s.ranger_tile() + Vector2i(1, 0)).get("ok", false), "a glowcap picked")
	t.check(s.finds_found.has("glowcap"), "logged in the notebook as a find")
	t.equal(notes.size(), 1, "with its note")
	t.check(s.ideas_had.has("glowcap"), "and it gives an idea")


# --- crafting and ideas ----------------------------------------------------------

func _option_ids(s: GameSession, station: String) -> Array:
	return s.recipe_options(station).map(func(o: Dictionary) -> String: return o["id"])


func test_a_recipe_is_hidden_until_learned(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(not _option_ids(s, "anywhere").has("rope"), "rope is not shown before the idea")
	t.check(not s.craft("rope"), "nor can it be made")
	s.debug_add_item("reeds", 3)
	t.check(_option_ids(s, "anywhere").has("rope"), "the first reeds teach rope")
	t.check(s.craft("rope"), "rope is made")
	t.check(not _option_ids(s, "anywhere").has("trail_mix"), "trail mix waits for hazelnuts")
	for r: Dictionary in s.content.rows("recipes"):
		if r["learned"] == "start":
			t.check(s.recipes_known.has(r["id"]), "%s is known from the start" % r["id"])


func test_each_recipe_uses_and_gives_what_its_row_says(t: TestCase) -> void:
	for r: Dictionary in TestCase.new_session().content.rows("recipes"):
		if r.has("refit") or (r["result"] as Dictionary).has("effect"):
			continue
		var s := TestCase.new_session()
		s.debug_unlock_recipes()
		if r["station"] == "workbench":
			_at_workbench(s)
		elif r["station"] == "fire":
			t.check(_at_fire(s), "%s: a camp fire is lit" % r["id"])
		for k: String in r["inputs"]:
			s.backpack.add(k, int(r["inputs"][k]) + 1)
		if r.has("tool"):
			s.backpack.add(r["tool"], 1)
		var res: Dictionary = r["result"]
		var before := s.backpack.count(res["item"])
		var m0 := s.clock.minute
		var e0 := s.needs.energy
		t.check(s.craft(r["id"]), "%s is made" % r["id"])
		for k: String in r["inputs"]:
			t.equal(s.backpack.count(k), 1, "%s uses %d %s" % [r["id"], int(r["inputs"][k]), k])
		t.equal(s.backpack.count(res["item"]) - before, int(res["count"]), "%s gives %d %s" % [r["id"], int(res["count"]), res["item"]])
		if r.has("tool"):
			t.equal(s.backpack.count(r["tool"]), 1, "%s keeps the %s" % [r["id"], r["tool"]])
		t.equal(s.clock.minute - m0, s.tuning.integer("crafting.minutes"), "%s takes %d minutes" % [r["id"], s.tuning.integer("crafting.minutes")])
		t.check(s.needs.energy >= e0 - 0.01 - s.needs.walk_cost(s.needs_context()) * 2.0, "%s costs no energy of its own" % r["id"])


func test_workbench_and_fire_recipes_only_there(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_unlock_recipes()
	s.debug_add_item("firewood", 4)
	s.debug_add_item("saw")
	s.debug_add_item("mushrooms", 2)
	s.debug_add_item("wild_onion", 1)
	t.check(not s.craft("planks"), "planks need a workbench")
	t.check(not s.craft("hot_soup"), "soup needs a fire")
	_at_workbench(s)
	t.check(not s.craft("hot_soup"), "the station has no stove")
	t.check(s.craft("planks"), "planks at the workbench")
	s.debug_repair_all("test_cabin", true)
	s.enter_building("test_cabin")
	s.feed_stove()
	t.check(s.can_cook_here(), "the cabin stove is lit")
	t.check(s.craft("hot_soup"), "soup at the stove")
	t.check(not s.craft("planks"), "but no planks without a workbench there")


func test_chest_items_count_only_in_that_building(t: TestCase) -> void:
	var s := TestCase.new_session()
	var chest: Inventory = s.structures.chests["ranger_station"]
	chest.add("planks", 2)
	chest.add("nails", 2)
	t.equal(s.have("planks"), 0, "outdoors the station chest does not count")
	t.check(not s.craft("trail_sign"), "so no sign outdoors")
	_at_workbench(s)
	t.equal(s.have("planks"), 2, "at the station workbench its chest counts")
	t.check(s.craft("trail_sign"), "a sign from the chest's planks")
	t.equal(chest.count("planks"), 0, "the planks came out of the chest")
	s.debug_repair_all("test_cabin", true)
	s.enter_building("test_cabin")
	chest.add("planks", 2)
	t.equal(s.have("planks"), 0, "the station chest does not count in the cabin")


func test_each_idea_fires_once(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("ideas"):
		if not r.has("item"):
			continue   # an idea had at a place, not from an item (the gift shelf)
		var heard := []
		var fn := func(text: String) -> void: heard.append(text)
		s.message.connect(fn)
		s.debug_add_item(r["item"], 1)
		s.debug_add_item(r["item"], 1)
		s.message.disconnect(fn)
		s.backpack.remove(r["item"], 2)
		t.equal(heard.count(s.content.text(r["text"])), 1, "the %s idea is told once" % r["id"])
		for rid: String in r["recipes"]:
			t.check(s.recipes_known.has(rid), "the %s idea teaches %s" % [r["id"], rid])


# --- the magic slot and refits ---------------------------------------------------

func test_the_slot_is_hidden_until_its_idea(t: TestCase) -> void:
	var s := TestCase.new_session()
	_at_workbench(s)
	t.check(not _option_ids(s, "workbench").has("refit_lantern"), "no slot before the glowcap idea")
	s.debug_add_item("glowcap", 2)
	t.check(_option_ids(s, "workbench").has("refit_lantern"), "after it, the lantern shows its slot")
	var label := ""
	for o: Dictionary in s.recipe_options("workbench"):
		if o["id"] == "refit_lantern":
			label = o["label"]
	t.check(label.contains("?"), "marked with a question mark")
	var slot := s.backpack.find_family("lantern")
	t.check(s.craft("refit_lantern"), "the lantern is refitted")
	t.equal(s.backpack.item_at(slot), "glowcap_lantern", "the changed lantern is in the lantern's slot")
	t.equal(s.backpack.count("lantern"), 0, "the old lantern is gone")
	t.equal(s.backpack.count("glowcap"), 1, "one glowcap used")
	t.check(s.craft("refit_lantern"), "refitting again")
	t.equal(s.backpack.count("glowcap"), 0, "uses another glowcap")
	t.equal(s.backpack.count("glowcap_lantern"), 1, "and the new magic replaces the old: still one lantern")


func test_glowcap_lantern(t: TestCase) -> void:
	var s := TestCase.new_session()
	var finds: Dictionary = s.world.meta["finds"]
	var id: String = finds.keys()[0]
	var at := Vector2i(int(finds[id][0]), int(finds[id][1]))
	s.location = ""
	s.outdoor_pos = Vector2(at) + Vector2(3.5, 0.5)
	s.selected_slot = s.backpack.find_family("lantern")
	t.near(s.lantern_radius(), s.tuning.num("light.lantern_radius_tiles"), 0.01, "the plain lantern lights its radius")
	t.check(s.sparkle_tiles().is_empty(), "and shows no sparkles")
	s.backpack.replace_at(s.selected_slot, "glowcap_lantern")
	t.near(s.lantern_radius(), s.tuning.num("refits.glowcap_lantern_radius"), 0.01, "the glowcap lantern lights its tuned radius")
	t.check(s.sparkle_tiles().has(at), "an unlogged find sparkles in its light")
	s.finds_found[id] = true
	t.check(not s.sparkle_tiles().has(at), "a logged one does not")
	s.finds_found.erase(id)
	s.outdoor_pos = Vector2(at) + Vector2(s.tuning.num("refits.glowcap_lantern_radius") + 3.0, 0.5)
	t.check(not s.sparkle_tiles().has(at), "nor one outside the light")


func test_ember_bedroll(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_teleport("station")
	s.outdoor_pos += Vector2(4, 3)
	s.facing = GameSession.FACING_RIGHT
	s.debug_add_item("ember_bedroll")
	t.equal(s.backpack.count("firewood"), 0, "no firewood")
	t.check(s.make_camp(), "camp made without firewood")
	t.check(not s.campfire_lit(), "with no fire")
	t.check(bool(s.needs_context()["campfire"]), "but it stays warm")
	s.debug_set_needs(10, 10)
	s.camp_sleep()
	var f := s.tuning.num("refits.ember_bedroll_restore")
	t.near(s.needs.energy, s.needs.max_energy() * f, 0.5, "sleeping restores the tuned share of energy")
	t.near(s.needs.warmth, s.needs.max_warmth() * f, 0.5, "and of warmth")


func test_true_compass(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_force_weather("clear")
	s.debug_teleport("fork")
	s.map.reveal_circle(s.outdoor_pos, 15)
	var off := Vector2(-1, -1)
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			var tt := s.ranger_tile() + Vector2i(dx, dy)
			if s.world.ground_at(tt) == "forest_floor" and not s.world.is_solid(tt):
				off = Vector2(tt.x + 0.5, tt.y + 0.5)
	s.outdoor_pos = off
	s.debug_set_time(23 * 60)
	t.check(not s.marker_visible(), "the plain compass loses the marker at night off the trail")
	s.backpack.replace_at(s.backpack.find_family("compass"), "true_compass")
	t.check(s.marker_visible(), "the true compass keeps it at night off the trail")
	s.debug_force_weather("fog")
	t.check(s.marker_visible(), "and in fog")
	for w: String in s.tuning.value("refits.true_compass_hidden_by"):
		s.debug_force_weather(w)
		t.check(not s.marker_visible(), "but not in %s" % w)


# --- placeables and the backpack --------------------------------------------------

func test_cairns_show_on_the_map_only_on_revealed_ground(t: TestCase) -> void:
	var s := TestCase.new_session()
	t.check(s.recipes_known.has("cairn"), "the cairn is known from the start")
	s.debug_add_item("stones", 3)
	t.check(s.craft("cairn"), "a cairn made anywhere")
	s.debug_teleport("fork")
	s.map.wipe()
	var front := s.ranger_tile() + s.facing_vector()
	if s.place_problem(front, "cairn") != "":
		s.facing = GameSession.FACING_UP
		front = s.ranger_tile() + s.facing_vector()
	s.selected_slot = s.backpack.find_family("cairn")
	t.check(s.begin_place(), "set on the ground, no tool needed")
	t.check(s.placed.has(front), "it stands there")
	s.map.wipe()
	t.check(not s.map_shows_placed(front), "not on the map on unrevealed ground")
	s.map.reveal_circle(Vector2(front), 5)
	t.check(s.map_shows_placed(front), "on the map once the ground is revealed")


func test_boardwalk_counts_as_trail(t: TestCase) -> void:
	var s := TestCase.new_session()
	var wet := _ground_near_station(s, ["bog", "shallows"], 200)
	t.check(wet.x >= 0, "wet ground found")
	t.check(_stand_by(s, wet), "room to stand by it")
	s.debug_add_item("boardwalk", 1)
	t.check(s.lay_boardwalk(), "boardwalk laid")
	t.equal(s.world.ground_at(wet), "boards", "the ground is boards")
	t.check((s.tuning.value("sites.reach_grounds") as Array).has("boards"), "which a site's trail step counts")
	s.outdoor_pos = Vector2(wet) + Vector2(0.5, 0.5)
	t.check(s.on_trail(), "and the ranger is on trail there")
	var grass := _ground_near_station(s, ["grass"])
	_stand_by(s, grass)
	s.debug_add_item("boardwalk", 1)
	t.check(not s.lay_boardwalk(), "not on dry grass")


func test_workbench_kit_only_in_a_repaired_building(t: TestCase) -> void:
	var s := TestCase.new_session()
	s.debug_add_item("workbench_kit")
	s.debug_teleport("station")
	t.check(not s.set_up_kit(), "not outdoors")
	_at_workbench(s)
	t.check(not s.set_up_kit(), "not in the station, which has one")
	t.check(not s.enter_building("test_cabin"), "the cabin is still broken")
	s.debug_repair_all("test_cabin", true)
	s.enter_building("test_cabin")
	t.check(not s.at_workbench(), "the cabin has no workbench")
	t.check(s.set_up_kit(), "set up in the repaired cabin")
	t.check(s.at_workbench(), "now it has one")
	t.equal(s.backpack.count("workbench_kit"), 0, "the kit is used")
	var d := s.to_dict()
	var s2 := TestCase.new_session()
	s2.from_dict(d)
	t.check(s2.interiors["test_cabin"].find("workbench").size() > 0, "it is still there after loading")


func test_pack_frame(t: TestCase) -> void:
	var s := TestCase.new_session()
	var base := s.tuning.integer("storage.backpack_slots")
	t.equal(s.backpack.size(), base, "the backpack starts at %d slots" % base)
	s.debug_add_item("rope", 2)
	t.check(s.recipes_known.has("pack_frame"), "the first rope gives the pack frame idea")
	s.debug_add_item("sticks", 4)
	s.debug_add_item("pine_resin", 1)
	var fill := ["apple", "sandwich", "tin_of_beans", "firewood"]
	for item: String in fill:
		s.debug_add_item(item, 1)
	var before := s.backpack.to_array()
	_at_workbench(s)
	t.check(s.craft("pack_frame"), "the pack frame is made")
	t.equal(s.backpack.size(), s.tuning.integer("crafting.pack_frame_slots"), "the backpack grows to its tuned size")
	for item: String in fill:
		t.equal(s.backpack.count(item), 1, "no %s lost" % item)
	t.equal(s.backpack.count("rope"), 0, "the rope is used")
	t.check(not s.craft("pack_frame"), "it is made only once")
	var s2 := TestCase.new_session()
	s2.from_dict(s.to_dict())
	t.equal(s2.backpack.size(), s.backpack.size(), "the bigger backpack is kept in the save")
	t.equal(before.size(), base, "(the pack was full-size before)")


# --- skills ---------------------------------------------------------------------

func test_each_action_gives_its_experience(t: TestCase) -> void:
	var s := TestCase.new_session()
	for r: Dictionary in s.content.rows("skills"):
		for action: String in r["xp"]:
			var before := int(s.skills.xp[r["id"]])
			s.skills.act(action)
			t.equal(int(s.skills.xp[r["id"]]) - before, int(r["xp"][action]), "%s gives %d %s experience" % [action, int(r["xp"][action]), r["id"]])


func test_actions_in_play_give_experience(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, "spring")
	var p := _full_spot(s, "wild_onion")
	_stand_by(s, p)
	s.pick_forage(p)
	t.equal(int(s.skills.xp["foraging"]), int(s.content.row("skills", "foraging")["xp"]["pick"]), "picking gives Foraging experience")
	s.debug_add_item("firewood", 2)
	s.debug_add_item("saw")
	_at_workbench(s)
	s.craft("planks")
	t.equal(int(s.skills.xp["woodcraft"]), int(s.content.row("skills", "woodcraft")["xp"]["workbench"]), "the workbench gives Woodcraft experience")


func test_levels_arrive_at_the_listed_totals(t: TestCase) -> void:
	var s := TestCase.new_session()
	var totals: Array = s.tuning.value("skills.xp_levels")
	t.equal(totals.map(func(v: Variant) -> int: return int(v)), [100, 380, 770, 1300, 2150, 3300, 4800, 6900, 10000, 15000], "Stardew's totals")
	for i in totals.size():
		s.skills.xp["foraging"] = int(totals[i]) - 1
		t.equal(s.skills.level("foraging"), i, "level %d just before %d" % [i, int(totals[i])])
		s.skills.xp["foraging"] = int(totals[i])
		t.equal(s.skills.level("foraging"), i + 1, "level %d at %d" % [i + 1, int(totals[i])])


func test_each_level_cuts_energy(t: TestCase) -> void:
	var s := TestCase.new_session()
	var share := s.tuning.num("skills.energy_saved_per_level")
	for l in [0, 1, 3, 10]:
		s.debug_set_skill("woodcraft", l)
		t.near(s.skills.energy_for("chop"), 1.0 - share * l, 0.0001, "woodcraft %d: chopping costs %d%% less" % [l, roundi(share * l * 100)])
	s.debug_set_skill("woodcraft", 2)
	s.debug_set_needs(200, 100)
	var at := _find_tree(s)
	_stand_by(s, at)
	s.debug_add_item("axe")
	var e0 := s.needs.energy
	s.chop()
	t.near(e0 - s.needs.energy, s.tuning.num("axe.energy") * (1.0 - 2 * share), 0.6, "a chop at level 2 costs 6% less")


func _find_tree(s: GameSession) -> Vector2i:
	return _find_object(s, "tree_pine")


func test_perks_do_what_their_rows_say(t: TestCase) -> void:
	var s := TestCase.new_session()
	var base_dig := s.tuning.integer("trail.tiles_per_action")
	s.debug_set_skill("trailcraft", 2)
	t.equal(s.dig_tiles(), base_dig + 1, "Trailcraft 2: each dig lays a tile more")
	s.debug_set_skill("trailcraft", 3)
	t.check(s.recipes_known.has("boardwalk"), "Trailcraft 3: boardwalk")
	s.debug_set_skill("trailcraft", 4)
	t.near(s.skills.value("brush_minutes", 10.0), 0.0, 0.001, "Trailcraft 4: brush takes no time")
	s.debug_set_skill("surveying", 2)
	t.equal(s._survey_total_steps(), 2, "Surveying 2: surveys take 20 minutes")
	s.debug_set_skill("surveying", 3)
	t.near(s.survey_radius_here(), s.tuning.num("map.survey_radius") + 2.0, 0.001, "Surveying 3: 2 tiles further")
	s.debug_set_skill("surveying", 4)
	s.debug_force_weather("clear")
	var sun: Array = s.tuning.value("light.sun.spring")
	s.debug_set_time(int(sun[1]) + 20)
	t.check(s.is_night(), "(dusk counts as night)")
	t.equal(s._survey_conditions_ok(), "", "Surveying 4: surveys at dusk")
	s.debug_set_time(23 * 60)
	t.equal(s._survey_conditions_ok(), "msg_survey_dark", "but not in full night")
	s.debug_set_skill("woodcraft", 2)
	t.check(s.recipes_known.has("roofing"), "Woodcraft 2: roofing")
	s.debug_set_skill("woodcraft", 3)
	t.check(s.recipes_known.has("workbench_kit"), "Woodcraft 3: workbench kit")
	s.debug_set_skill("woodcraft", 4)
	t.equal(s.fire_minutes_per_firewood(), 240, "Woodcraft 4: fires burn 4 hours")
	s.debug_set_skill("foraging", 2)
	t.check(s.recipes_known.has("berry_preserve"), "Foraging 2: berry preserve")
	s.debug_set_skill("foraging", 3)
	t.check(s.recipes_known.has("roast_hazelnuts"), "Foraging 3: roast hazelnuts")
	t.near(s.skills.value("double_pick_chance", 0.0), 0.0, 0.001, "no double picks before Foraging 4")
	s.debug_set_skill("foraging", 4)
	t.near(s.skills.value("double_pick_chance", 0.0), 0.1, 0.001, "Foraging 4: a 10% double pick")


func test_specialties_do_what_their_rows_say(t: TestCase) -> void:
	var s := TestCase.new_session()
	var base_dig := s.tuning.integer("trail.tiles_per_action")
	s.debug_choose_specialty("trail_builder")
	t.equal(s.dig_tiles(), base_dig + 2, "Trail builder: one more tile again")
	t.near(s.skills.value("dig_energy", 1.0), 0.5, 0.001, "for half the energy")
	s = TestCase.new_session()
	s.debug_choose_specialty("sawyer")
	t.near(s.skills.value("trunk_actions", 3.0), 1.0, 0.001, "Sawyer: a trunk falls to one cut")
	t.near(s.skills.value("chop_firewood", 2.0), 4.0, 0.001, "and double firewood")
	s = TestCase.new_session()
	s.debug_choose_specialty("cartographer")
	t.near(s.survey_radius_here(), (s.tuning.num("map.survey_radius") + 2.0) * 1.5, 0.001, "Cartographer: half as far again")
	s.debug_set_time(12 * 60)
	s.debug_force_weather("rain")
	t.equal(s._survey_conditions_ok(), "", "and surveys in rain")
	s = TestCase.new_session()
	s.debug_force_weather("clear")
	var grass := _ground_near_station(s, ["grass"])
	s.outdoor_pos = Vector2(grass) + Vector2(0.5, 0.5)
	var plain := s.speed_tiles_per_second()
	s.debug_choose_specialty("wayfinder")
	t.near(s.speed_tiles_per_second(), plain * 1.15, 0.001, "Wayfinder: 15% faster off the trail")
	t.check(s.skills.flag("tall_grass_unslowed"), "and tall grass does not slow")
	s = TestCase.new_session()
	s.debug_choose_specialty("carpenter")
	t.equal(s.structures.actions_per_step(), 2, "Carpenter: two actions a step")
	var step: Dictionary = s.content.row("structures", "test_cabin")["repair_steps"][0]
	if (step["materials"] as Dictionary).has("planks"):
		t.equal(int(s.structures.step_materials("test_cabin", step["id"])["planks"]), roundi(int(step["materials"]["planks"]) * 0.75), "and a quarter fewer planks")
	s = TestCase.new_session()
	s.debug_choose_specialty("camp_hand")
	t.near(s.skills.value("camp_restore", 0.0), 10.0, 0.001, "Camp hand: camp restores 10 more")
	s.debug_set_needs(10, 10)
	s.debug_add_item("hot_soup")
	s.eat("hot_soup")
	t.near(s.needs.energy, 10.0 + 70.0 * 1.25, 0.01, "and cooked food gives a quarter more")
	s = TestCase.new_session()
	s.debug_choose_specialty("gatherer")
	t.near(s.skills.value("double_pick_chance", 0.0), 0.25, 0.001, "Gatherer: a 25% double pick")
	t.equal(s.object_refresh_days(s.content.row("forage", "berries")), 2, "and bushes fruit again in two days")
	s = TestCase.new_session()
	s.debug_choose_specialty("seeker")
	var p := _magic_place(s, "glowcap")
	s.location = ""
	s.outdoor_pos = Vector2(p) + Vector2(8.5, 0.5)
	var said := []
	s.message.connect(func(text: String) -> void: said.append(text))
	s._last_tile = Vector2i(-9999, -9999)
	s._update_trace()
	t.check(said.has(s.content.text("msg_sense_magic")), "Seeker: senses a magical ingredient within 10 tiles")
	t.near(s.magic_regrow_mult(), 0.5, 0.001, "and they come back twice as fast")


func test_level_ups_are_told_on_waking(t: TestCase) -> void:
	var s := TestCase.new_session()
	var notes := []
	s.note_read.connect(func(text: String) -> void: notes.append(text))
	s.skills.add_xp("trailcraft", 100)
	t.equal(s.skills.level("trailcraft"), 1, "level 1 reached")
	t.equal(notes.size(), 0, "nothing told yet")
	s.sleep()
	t.equal(notes.size(), 1, "told on waking")
	t.check((notes[0] as String).contains(s.content.text("msg_skill_level", {"skill": s.content.text("skill_trailcraft"), "level": 1})), "one line for the level")
	s.sleep()
	t.equal(notes.size(), 1, "and only once")


func test_a_specialty_is_offered_once(t: TestCase) -> void:
	var s := TestCase.new_session()
	var offers := []
	s.choice_requested.connect(func(kind: String, _title: String, opts: Array) -> void: offers.append([kind, opts.size()]))
	s.skills.add_xp("foraging", s.skills.xp_for_level(5))
	t.check(not s.wake_offer, "not before waking")
	s.wake_lines()
	t.check(s.wake_offer, "a level 5 wake-up offers the choice")
	t.check(s.offer_specialty(), "offered")
	t.equal(offers.size(), 1, "one offer")
	t.equal(int(offers[0][1]), 2, "of two specialties")
	s.wake_lines()
	t.check(not s.wake_offer, "not offered again on the next waking")
	t.check(s.choose_specialty("foraging", "gatherer"), "chosen")
	t.check(not s.choose_specialty("foraging", "seeker"), "and the choice is permanent")
	s.skills.add_xp("foraging", 20000)
	s.wake_lines()
	t.check(not s.wake_offer, "higher levels offer nothing more")


# --- saves and secrecy ---------------------------------------------------------------

func test_a_phase_2a_save_loads(t: TestCase) -> void:
	var s := TestCase.new_session()
	var d := s.to_dict()
	d.erase("living")
	(d["camp"] as Dictionary).erase("ember")
	(d["land"] as Dictionary).erase("boardwalk")
	var s2 := TestCase.new_session(99)
	s2.debug_set_skill("foraging", 3)
	s2.from_dict(d)
	t.equal(s2.skills.level("foraging"), 0, "everyone starts at level 0")
	t.equal(s2.backpack.size(), s2.tuning.integer("storage.backpack_slots"), "with the plain backpack")
	t.check(s2.recipes_known.has("cairn") and not s2.recipes_known.has("rope"), "and the starting recipes")
	t.check(s2.ideas_had.is_empty(), "and no ideas")


func test_new_state_saves_and_loads_exactly(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, "spring")
	var p := _full_spot(s, "wild_onion")
	_stand_by(s, p)
	s.pick_forage(p)
	s.debug_add_item("reeds", 3)
	s.skills.add_xp("trailcraft", 500)
	s.debug_choose_specialty("seeker")
	s.debug_repair_all("test_cabin", true)
	s.debug_add_item("workbench_kit")
	s.enter_building("test_cabin")
	s.set_up_kit()
	s.leave_building()
	var wet := _ground_near_station(s, ["bog", "shallows"], 200)
	_stand_by(s, wet)
	s.debug_add_item("boardwalk")
	s.lay_boardwalk()
	s.forage.note_wet_day(3)
	var bush := _find_object(s, "bush")
	s.forage.mark_object(bush, "berries", 2)
	var d := s.to_dict()
	var s2 := TestCase.new_session(4242)
	s2.from_dict(d)
	t.equal(JSON.stringify(s2.to_dict()), JSON.stringify(d), "everything new saves and loads exactly")
	t.check(not s2.forage_showing(p), "the picked spot stays picked")
	t.equal(s2.world.ground_at(wet), "boards", "the boardwalk is still there")


func test_debug_screen_keeps_the_places_secret(t: TestCase) -> void:
	var s := TestCase.new_session()
	var plain := s.debug_magic_text(false)
	var spoilers := s.debug_magic_text(true)
	for p: Vector2i in s.forage.magic_used:
		var at := "(%d, %d)" % [p.x, p.y]
		t.check(not plain.contains(at), "without spoilers no place is named")
		t.check(spoilers.contains(at), "with spoilers ticked it is")
	var re := RegEx.create_from_string("\\d+, \\d+")
	t.check(re.search(plain) == null, "no coordinates at all without spoilers")


func test_status_reports_keep_the_places_secret(t: TestCase) -> void:
	var s := TestCase.new_session()
	var dir := DirAccess.open("res://docs/status")
	t.check(dir != null, "the status reports are there")
	if dir == null:
		return
	var words := []
	for r: Dictionary in s.content.rows("spoiler_magic"):
		var rule: Dictionary = r["rule"]
		words.append_array(rule.get("beside_ground", []))
		words.append_array(rule.get("beside_object", []))
	for f in dir.get_files():
		if not f.ends_with(".md"):
			continue
		var text := FileAccess.get_file_as_string("res://docs/status/" + f).to_lower()
		for id: String in s.forage.magic_places:
			for p: Vector2i in s.forage.magic_places[id]:
				t.check(not text.contains("%d, %d" % [p.x, p.y]), "%s names no place" % f)
		for line: String in text.split("\n"):
			var names_one := ["glowcap", "ember moss", "lodestone"].any(func(w: String) -> bool: return line.contains(w))
			if names_one:
				for w: String in words:
					t.check(not line.contains(w.replace("_", " ")), "%s does not say what an ingredient grows beside" % f)


# --- the proving scene ------------------------------------------------------------

## The spec's scene: on a walk the ranger gathers berries and reeds; one night
## they spot something glowing; back at a workbench an idea appears beside the
## lantern; they refit it, and the next night it shows them a find they had
## walked past.
func test_the_proving_scene(t: TestCase) -> void:
	var s := TestCase.new_session()
	_season(s, "summer")
	var bush := _find_object(s, "bush")
	_stand_by(s, bush)
	t.check(s.pick_object(bush).get("ok", false), "berries gathered on the walk")
	s.debug_add_item("reeds", 3)
	t.check(s.recipes_known.has("rope"), "the reeds give an idea")
	var glow := _magic_place(s, "glowcap")
	_stand_by(s, glow)
	s.debug_force_weather("clear")
	s.debug_set_time(23 * 60)
	t.check(s.forage_showing(glow), "something glowing on the forest floor at night")
	t.check(s.pick_forage(glow).get("ok", false), "picked")
	_at_workbench(s)
	var ids := _option_ids(s, "workbench")
	t.check(ids.has("refit_lantern"), "at the workbench the lantern shows a slot")
	t.check(s.craft("refit_lantern"), "the lantern is refitted")
	var finds: Dictionary = s.world.meta["finds"]
	var id: String = finds.keys()[0]
	var at := Vector2i(int(finds[id][0]), int(finds[id][1]))
	s.leave_building()
	s.outdoor_pos = Vector2(at) + Vector2(4.5, 0.5)
	s.selected_slot = s.backpack.find_family("lantern")
	s.debug_set_time(23 * 60)
	t.check(s.sparkle_tiles().has(at), "the next night it shows a find that was walked past")
