class_name Wildlife
extends RefCounted
## Phase 5a (Phase 5 Spec, Animals, Binoculars and the camera, The field
## guide, Strange cousins, Night): the park's animals and what the ranger
## has learned of them.
##
## Each kind is a row of the animals table: the ground it likes, the hours
## it's out (dawn, day, dusk, night), its seasons, how many at once and how
## shy it is. Each morning a few home places are picked for each kind (the
## same for everyone on a given day of a given park, but not where they were
## yesterday). While a kind's hours last, its animals wander slowly round
## their home, eat and rest; come closer than its shy distance and one moves
## off at an easy pace and is gone for a while. A bear doesn't move off: it
## looks at you. Animals live only while they're out; nothing about them is
## saved but what the guide has learned.
##
## Now and then a strange cousin is among its ordinary cousin's group: a
## jackalope among the rabbits at dusk, a magic deer among the deer. Troll
## badgers are already in the park (the park's badgers) and count for the
## guide when seen.
##
## The binoculars sketch what they rest on for a moment; the camera takes a
## photo of what's in front, within range. A photo of an animal doing
## something (eating, resting) is a good one. A photo of a place in special
## light (dawn, dusk, night, fog, rain, snow) near a site fills the guide's
## third page. Every few entries the Chief writes.
##
## After dark: moonflowers open on meadows, and for each site open a short
## path of glowing stones leads to a glowing spot with something to find.

signal guide_changed
signal sketched(kind: String)
signal photographed(kind: String, good: bool)

const PHASES: Array[String] = ["dawn", "day", "dusk", "night"]

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var animals: Array = []         # live: {id, kind, home, pos, target, state, facing, t, gone_until, look}
var homes: Dictionary = {}      # kind -> Array of Vector2 (today's)
var guide: Dictionary = {}      # entry id -> {level: "sketch"/"photo", good, count, where, when, day}
var letters_sent: int = 0
var picked: Dictionary = {}     # "moonflower:i" or "glow:i" -> absolute day picked
var binoculars_given: bool = false
var looking: bool = false       # through the binoculars
var _day: int = -1
var _phase: String = ""
var _seen_badger: Dictionary = {}
var flowers: Array[Vector2i] = []
var paths: Array = []           # [{stones: Array[Vector2i], spot: Vector2i, site}]


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


func row(id: String) -> Dictionary:
	return content.row("animals", id) if content.has("animals", id) else {}


func kinds(kind: String) -> Array:
	return content.rows("animals").filter(func(r: Dictionary) -> bool: return str(r["kind"]) == kind)


# --- time of day ---------------------------------------------------------------------

## dawn, day, dusk or night, from the season's sunrise and sunset.
func phase() -> String:
	var g := s()
	var sun: Array = tuning.value("light.sun." + g.clock.season_name())
	var m := g.clock.minute
	var w := tuning.num("wildlife.dawn_dusk_minutes")
	if m >= 1440:
		return "night"
	if absf(m - float(sun[0])) <= w:
		return "dawn"
	if absf(m - float(sun[1])) <= w:
		return "dusk"
	if m > float(sun[0]) and m < float(sun[1]):
		return "day"
	return "night"


func is_out(r: Dictionary, ph: String) -> bool:
	return (r["hours"] as Array).has(ph) and (r["seasons"] as Array).has(s().clock.season_name())


# --- the morning: homes, flowers and paths ------------------------------------------

func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s" % [s().seed_value, s().clock.absolute_day(), salt])
	return rng


func _anchors() -> Array[Vector2]:
	var g := s()
	var out: Array[Vector2] = []
	for n: String in (g.world.meta.get("spawns", {}) as Dictionary):
		out.append(g.world.spawn(n))
	return out


## A walkable tile of one of the grounds, near an anchor, or Vector2.INF.
func _find_ground(rng: RandomNumberGenerator, ground: Array, tries: int = 60) -> Vector2:
	var g := s()
	var anchors := _anchors()
	if anchors.is_empty():
		return Vector2.INF
	var span := tuning.integer("wildlife.home_search_tiles")
	for i in tries:
		var a: Vector2 = anchors[rng.randi() % anchors.size()]
		var t := Vector2i(a) + Vector2i(rng.randi_range(-span, span), rng.randi_range(-span, span))
		if not g.world.in_bounds(t) or g.world.is_solid(t):
			continue
		if ground.is_empty() or ground.has(g.world.ground_at(t)):
			return Vector2(t) + Vector2(0.5, 0.5)
	return Vector2.INF


func morning() -> void:
	var g := s()
	_day = g.clock.absolute_day()
	animals = []
	homes = {}
	for r: Dictionary in kinds("animal"):
		var rng := _rng(str(r["id"]))
		var list: Array = []
		for i in int(r["homes"]):
			var p := _find_ground(rng, r["ground"])
			if p != Vector2.INF:
				list.append(p)
		homes[str(r["id"])] = list
	_lay_night()
	if not binoculars_given:
		give_binoculars()


## The last ranger's binoculars wait in the station's chest (Phase 5 Spec:
## found early).
func give_binoculars() -> void:
	var g := s()
	binoculars_given = true
	if g.backpack.has("binoculars") or (g.structures.chests["ranger_station"] as Inventory).count("binoculars") > 0:
		return
	(g.structures.chests["ranger_station"] as Inventory).add("binoculars", 1)


func _lay_night() -> void:
	var g := s()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:night" % g.seed_value)   # the same every night: they're places
	flowers = []
	var fr := content.row("night_finds", "moonflower")
	for i in int(fr["count"]):
		var p := _find_ground(rng, fr["ground"])
		if p != Vector2.INF:
			flowers.append(Vector2i(p))
	paths = []
	var gr := content.row("night_finds", "glow")
	var sites: Array = g.sites_open.keys()
	sites.sort()
	for site: String in sites:
		var c := g.park.place_spot(site)
		if c == Vector2.INF:
			continue
		var prng := RandomNumberGenerator.new()
		prng.seed = hash("%d:path:%s" % [g.seed_value, site])
		var dir := Vector2.RIGHT.rotated(prng.randf() * TAU)
		var stones: Array[Vector2i] = []
		var start := c + dir * 4.0
		for k in int(gr["stones"]):
			var t := Vector2i(start + dir * (k * 2.0))
			if g.world.in_bounds(t) and not g.world.is_solid(t):
				stones.append(t)
		var spot := Vector2i(start + dir * (int(gr["stones"]) * 2.0 + 1.0))
		if stones.size() >= 2 and g.world.in_bounds(spot) and not g.world.is_solid(spot):
			paths.append({"stones": stones, "spot": spot, "site": site})


func is_night() -> bool:
	return Daylight.is_night(tuning, s().clock.season_name(), s().clock.minute)


# --- the animals out now ---------------------------------------------------------------

func update(real_delta: float) -> void:
	var g := s()
	if _day != g.clock.absolute_day():
		morning()
	if g.is_indoors() or g.in_town:
		return
	var ph := phase()
	if ph != _phase:
		_phase = ph
		_turn_out(ph)
	var near := tuning.num("wildlife.spawn_near_tiles")
	for a: Dictionary in animals:
		if Vector2(a["home"]).distance_to(g.outdoor_pos) > near:
			continue
		_move(a, real_delta)
	if looking:
		_look(real_delta)
	_see_badgers()


## Puts out the animals whose hours have come, and sends home the rest.
func _turn_out(ph: String) -> void:
	var g := s()
	var keep: Array = []
	for a: Dictionary in animals:
		if is_out(row(str(a["kind"])), ph) or (str(a["kind"]) != str(a["id"]) and is_out(row(str(a["id"])), ph)):
			keep.append(a)
	animals = keep
	var have := {}
	for a: Dictionary in animals:
		have[str(a["id"]) + "@" + str(a["home"])] = true
	for r: Dictionary in kinds("animal"):
		if not is_out(r, ph):
			continue
		var id := str(r["id"])
		var rng := _rng(id + ph)
		for home: Vector2 in homes.get(id, []):
			if have.has(id + "@" + str(home)):
				continue
			var n := rng.randi_range(int(r["group"][0]), int(r["group"][1]))
			for k in n:
				animals.append(_animal(id, id, home, rng))
			# A strange cousin, now and then, among them.
			for c: Dictionary in kinds("cousin"):
				if str(c["cousin_of"]) != id or bool(c.get("park", false)) or not is_out(c, ph):
					continue
				var ch := float(c["chance"])
				ch = float((c.get("chance_season", {}) as Dictionary).get(g.clock.season_name(), ch))
				ch = g.skills.value("cousin_chance", ch)
				if rng.randf() < ch:
					animals.append(_animal(str(c["id"]), id, home, rng))


func _animal(id: String, kind: String, home: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var r := tuning.num("wildlife.home_radius")
	var p := home + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
	if not s().world.in_bounds(Vector2i(p)) or s().world.is_solid(Vector2i(p)):
		p = home
	return {"id": id, "kind": kind, "home": home, "pos": p, "target": p, "state": "eat", "facing": rng.randi() % 4, "t": rng.randf_range(0.5, 3.0), "gone_until": -1, "look": 0.0, "seed": rng.randi(), "key": rng.randi()}


func visible_animals() -> Array:
	var m := s().clock.absolute_day() * 1440 + s().clock.minute
	return animals.filter(func(a: Dictionary) -> bool: return int(a["gone_until"]) < m)


## How close the ranger may come before it moves off, in tiles.
func shy_distance(id: String) -> float:
	var g := s()
	var d := float(row(id).get("shy", 0.0))
	if d <= 0.0:
		return 0.0
	d = g.skills.value("shy_mult", d)
	if g.walking_slow:
		if g.skills.flag("slow_never_shy"):
			return 0.0
		d *= tuning.num("wildlife.slow_walk_shy")
	if g.pet.along and g.pet.kind == "cat":
		d *= tuning.num("pet.cat_shy_mult")
	return d


func _move(a: Dictionary, dt: float) -> void:
	var g := s()
	var now := g.clock.absolute_day() * 1440 + g.clock.minute
	if int(a["gone_until"]) >= now:
		return
	if int(a["gone_until"]) >= 0:
		# Back home after a while away.
		a["gone_until"] = -1
		a["pos"] = a["home"]
		a["state"] = "eat"
	var id := str(a["id"])
	var r := row(id)
	var to_ranger := g.outdoor_pos - Vector2(a["pos"])
	var shy := shy_distance(id)
	if str(a["state"]) == "flee":
		a["t"] = float(a["t"]) - dt
		var away := -to_ranger.normalized() if to_ranger.length() > 0.01 else Vector2.RIGHT
		_step(a, away, float(r["speed"]) * 1.5 * dt)
		if float(a["t"]) <= 0.0:
			a["gone_until"] = now + tuning.integer("wildlife.back_after_minutes")
		return
	if shy > 0.0 and to_ranger.length() < shy:
		a["state"] = "flee"
		a["t"] = tuning.num("wildlife.flee_seconds")
		return
	if float(r.get("shy", 0.0)) <= 0.0 and to_ranger.length() < 2.5:
		# A bear in the way just looks.
		a["state"] = "eat" if a["state"] == "walk" else a["state"]
		a["facing"] = _facing_of(to_ranger)
		return
	a["t"] = float(a["t"]) - dt
	if str(a["state"]) == "walk":
		var d := Vector2(a["target"]) - Vector2(a["pos"])
		if d.length() < 0.15 or float(a["t"]) <= 0.0:
			_decide(a)
		else:
			_step(a, d.normalized(), minf(d.length(), float(r["speed"]) * 0.5 * dt))
		return
	if float(a["t"]) <= 0.0:
		_decide(a)


func _decide(a: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	a["seed"] = int(a["seed"]) * 1103515245 + 12345
	rng.seed = int(a["seed"])
	var pick := rng.randf()
	if pick < 0.5:
		var r := tuning.num("wildlife.home_radius")
		a["target"] = Vector2(a["home"]) + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		a["state"] = "walk"
		a["t"] = rng.randf_range(3.0, 7.0)
	elif pick < 0.8:
		a["state"] = "eat"
		a["t"] = rng.randf_range(2.0, 5.0)
	else:
		a["state"] = "rest"
		a["t"] = rng.randf_range(4.0, 9.0)


func _step(a: Dictionary, dir: Vector2, dist: float) -> void:
	var g := s()
	var p := Vector2(a["pos"]) + dir * dist
	if g.world.in_bounds(Vector2i(p)) and not g.world.is_solid(Vector2i(p)):
		a["pos"] = p
	elif str(a["state"]) == "walk":
		a["target"] = a["pos"]
	a["facing"] = _facing_of(dir)


static func _facing_of(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return GameSession.FACING_RIGHT if v.x > 0.0 else GameSession.FACING_LEFT
	return GameSession.FACING_DOWN if v.y > 0.0 else GameSession.FACING_UP


## The sheet frame for an animal now: row by facing, column by state.
func frame_of(a: Dictionary, time: float) -> Vector2i:
	var f := int(a["facing"])
	var rw := 1 if f == GameSession.FACING_LEFT else f
	var col := 0
	match str(a["state"]):
		"walk", "flee":
			col = 1 + int(time * 6.0) % 3
		"eat":
			col = 4 if int(time * 1.5 + float(int(a["seed"]) % 7)) % 3 != 0 else 0
		"rest":
			col = 5
	return Vector2i(col, rw)


# --- the guide ----------------------------------------------------------------------------

func entries(kind: String) -> Array:
	return content.rows("animals").filter(func(r: Dictionary) -> bool: return str(r["kind"]) == kind)


func level_of(id: String) -> String:
	return str((guide.get(id, {}) as Dictionary).get("level", ""))


func count_known() -> int:
	return guide.size()


func _place_here() -> String:
	var g := s()
	var best := ""
	var bd := 30.0
	for lm: String in content.ids("landmarks"):
		var d := g.outdoor_pos.distance_to(g.world.landmark_pos(lm))
		if d < bd:
			bd = d
			best = lm
	return best


## Records what the ranger has seen. level: "sketch" or "photo".
func record(id: String, level: String, good: bool = false) -> bool:
	var g := s()
	var was: Dictionary = guide.get(id, {})
	var before := str(was.get("level", ""))
	var better := before == "" or (before == "sketch" and level == "photo") or (level == "photo" and good and not bool(was.get("good", false)))
	var e := was.duplicate(true)
	e["level"] = "photo" if before == "photo" or level == "photo" else "sketch"
	e["good"] = bool(was.get("good", false)) or good
	e["count"] = int(was.get("count", 0)) + 1
	var when: Dictionary = e.get("when", {})
	when[phase()] = true
	when[g.clock.season_name()] = true
	e["when"] = when
	var where: Dictionary = e.get("where", {})
	var here := _place_here()
	if here != "":
		where[here] = true
	e["where"] = where
	if not e.has("day"):
		e["day"] = g.clock.absolute_day()
	guide[id] = e
	if better:
		guide_changed.emit()
	if before == "":
		_maybe_letter()
	return better


func _maybe_letter() -> void:
	var g := s()
	var every := tuning.integer("wildlife.letter_every")
	while count_known() >= (letters_sent + 1) * every:
		letters_sent += 1
		var n := tuning.integer("wildlife.letter_money")
		g.park.money.earn(g.clock.absolute_day(), "jobs", n)
		g.park.letters.append({"day": g.park.today(), "text": content.text("guide_chief_letter", {"n": count_known(), "money": n}), "read": false})
		g.message.emit(content.text("msg_letter"))


func _see_badgers() -> void:
	# The park's troll badgers count once seen up close.
	var g := s()
	var i := g.park.badger_near(g.outdoor_pos, 6.0)
	if i >= 0 and not guide.has("troll_badger") and not _seen_badger.has(_day):
		_seen_badger[_day] = true
		if record("troll_badger", "sketch"):
			g.skills.act("sketch")
			g.message.emit(content.text("guide_new_sketch", {"name": content.text("animal_troll_badger")}))


# --- binoculars -----------------------------------------------------------------------------

func toggle_binoculars() -> bool:
	looking = not looking
	for a: Dictionary in animals:
		a["look"] = 0.0
	return looking


## While looking, each animal within range is sketched after a moment.
func _look(dt: float) -> void:
	var g := s()
	if g.moving:
		looking = false
		return
	var reach := tuning.num("wildlife.binocular_range")
	for a: Dictionary in visible_animals():
		if Vector2(a["pos"]).distance_to(g.outdoor_pos) > reach:
			continue
		a["look"] = float(a["look"]) + dt
		var id := str(a["id"])
		if float(a["look"]) >= tuning.num("wildlife.sketch_seconds") and level_of(id) == "":
			if record(id, "sketch"):
				g.skills.act("sketch")
				g.message.emit(content.text("guide_new_sketch", {"name": content.text(str(row(id)["name"]))}))
				sketched.emit(id)


# --- the camera -----------------------------------------------------------------------------

## The animal the camera would take now: in front, within range, nearest.
func in_frame() -> Dictionary:
	var g := s()
	var fv := Vector2(g.facing_vector())
	var reach := tuning.num("wildlife.camera_range")
	var cone := deg_to_rad(tuning.num("wildlife.camera_cone_degrees")) / 2.0
	var best := {}
	var bd := reach + 0.01
	for a: Dictionary in visible_animals():
		var v := Vector2(a["pos"]) - g.outdoor_pos
		var d := v.length()
		if d > reach or d < 0.01:
			continue
		if absf(fv.angle_to(v)) > cone:
			continue
		if d < bd:
			bd = d
			best = a
	return best


## Takes a photo. Returns {kind, good, place} of what it took.
func take_photo() -> Dictionary:
	var g := s()
	looking = false
	var a := in_frame()
	if not a.is_empty():
		var id := str(a["id"])
		var good := str(a["state"]) in ["eat", "rest"] or g.skills.flag("every_photo_good")
		var new := record(id, "photo", good)
		var nm := content.text(str(row(id)["name"]))
		if new:
			g.skills.act("photo")
			if good:
				g.skills.act("good_photo")
		g.message.emit(content.text("guide_new_photo_good" if new and good else ("guide_new_photo" if new else "guide_photo_again"), {"name": nm}))
		photographed.emit(id, good)
		return {"kind": id, "good": good, "place": ""}
	# Nothing in frame: a place, if the light is special and a site is near.
	var cond := place_condition()
	var near := _place_here()
	if cond != "" and near != "" and g.outdoor_pos.distance_to(g.world.landmark_pos(near)) <= tuning.num("wildlife.place_photo_tiles"):
		var pid := "place_" + cond
		var new := record(pid, "photo", true)
		if new:
			g.skills.act("photo")
		g.message.emit(content.text("guide_new_place" if new else "guide_photo_again", {"name": content.text("guide_place_" + cond)}))
		return {"kind": pid, "good": true, "place": near}
	g.message.emit(content.text("guide_photo_nothing"))
	return {}


## What's special about the light now, for a place's photo, or "".
func place_condition() -> String:
	var g := s()
	var w := g.current_weather()
	if w in ["fog"]:
		return "fog"
	if w in ["rain", "storm"]:
		return "rain"
	if w in ["snow", "blizzard"]:
		return "snow"
	var ph := phase()
	return ph if ph in ["dawn", "dusk", "night"] else ""


# --- after dark --------------------------------------------------------------------------

func flower_open() -> bool:
	return is_night()


## A moonflower or glowing spot within reach, as "moonflower:i"/"glow:i", or "".
func night_find_in_reach(pos: Vector2, reach: float) -> String:
	if not is_night():
		return ""
	var g := s()
	for i in flowers.size():
		if pos.distance_to(Vector2(flowers[i]) + Vector2(0.5, 0.5)) <= reach + 0.5 and int(picked.get("moonflower:%d" % i, -99)) != g.clock.absolute_day():
			return "moonflower:%d" % i
	var every := int(content.row("night_finds", "glow")["every_days"])
	for i in paths.size():
		var sp: Vector2i = paths[i]["spot"]
		if pos.distance_to(Vector2(sp) + Vector2(0.5, 0.5)) <= reach + 0.5 and g.clock.absolute_day() - int(picked.get("glow:%d" % i, -99)) >= every:
			return "glow:%d" % i
	return ""


func take_night_find(key: String) -> bool:
	var g := s()
	var kind := key.get_slice(":", 0)
	var gives: Dictionary = content.row("night_finds", kind)["gives"]
	for it: String in gives:
		if g.backpack.room_for(it) < int(gives[it]):
			g.message.emit(content.text("msg_backpack_full"))
			return false
	for it: String in gives:
		g.backpack.add(it, int(gives[it]))
	picked[key] = g.clock.absolute_day()
	g.skills.act("pick_magic" if kind == "glow" else "pick")
	g.message.emit(content.text("night_" + kind + "_taken"))
	return true


# --- saving ---------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"guide": guide.duplicate(true), "letters": letters_sent, "picked": picked.duplicate(), "binoculars": binoculars_given}


func from_dict(d: Dictionary) -> void:
	guide = (d.get("guide", {}) as Dictionary).duplicate(true)
	letters_sent = int(d.get("letters", 0))
	picked = (d.get("picked", {}) as Dictionary).duplicate()
	binoculars_given = bool(d.get("binoculars", false))
	_day = -1
	animals = []
