class_name Fortune
extends RefCounted
## Phase 4b, step 11: Esme Vale's readings, the game's gentle hint system in
## place of quest markers (Phase 4 Spec, The fortune teller).
##
## Once a day, while her caravan is open, the ranger can pay $10 for three
## cards. The Sky tells the weather two days ahead, and is always right (it
## reads the day the weather will really draw). The Path draws a large, vague
## circle on the map round one thing the ranger hasn't found, marked with a
## symbol rather than words, and never round anything out of reach. The Heart
## tells something true about a townsperson: a gift they'd love, a birthday
## coming, or where they'll be tomorrow. A card with nothing left to tell
## says something kind; if neither the Path nor the Heart has anything, the
## reading is free.

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var read_day: int = -1           # the absolute day of the last reading
var paths: Array = []            # {target, kind, center: [x, y], radius, day}
var last: Dictionary = {}        # the last reading, for the screen


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


func line(id: String, args: Dictionary = {}) -> String:
	return str(content.row("fortune", id)["text"]).format(args)


## Whether Esme reads now: her caravan open, and Esme there.
func open_now() -> bool:
	var g := s()
	return g.town.is_open("caravan") and g.town.routine_place("esme") == "caravan"


func read_today() -> bool:
	return read_day == s().clock.absolute_day()


# --- the Sky ------------------------------------------------------------------------

## The weather a day will really have, as WeatherSystem will draw it: today
## and tomorrow are known; the day after is drawn from tomorrow's evening.
func weather_on(abs_day: int) -> String:
	var w := s().weather
	var today := s().clock.absolute_day()
	var blocks: Array[String] = []
	if abs_day == today:
		blocks = w.today
	elif abs_day == today + 1:
		blocks = w.tomorrow
	else:
		var prev := w.tomorrow[2]
		for d in range(today + 2, abs_day + 1):
			blocks = w.generate_day(d, prev)
			prev = blocks[2]
	return w._main_weather(blocks)


func sky_text() -> String:
	var wid := weather_on(s().clock.absolute_day() + tuning.integer("fortune.days_ahead"))
	for r: Dictionary in content.rows("fortune"):
		if str(r.get("card", "")) == "sky" and str(r.get("weather", "")) == wid:
			return str(r["text"])
	return line("sky_other", {"weather": content.text(str(content.row("weather_types", wid)["name"])).to_lower() if content.has("weather_types", wid) else wid})


# --- the Path -----------------------------------------------------------------------

## Things the ranger hasn't found and can reach: unmapped landmarks inside the
## park's known land (never past the river), and finds not yet found.
func path_targets() -> Array:
	var g := s()
	var out := []
	var taken := {}
	for p: Dictionary in paths:
		taken[str(p["target"])] = true
	for r: Dictionary in content.rows("landmarks"):
		var id := str(r["id"])
		if not r.has("hint") or g.map.is_landmark_mapped(id) or taken.has("landmark:" + id):
			continue
		if not g.world.meta["landmarks"].has(id):
			continue
		var at := g.world.landmark_pos(id)
		if reachable(at):
			out.append({"target": "landmark:" + id, "kind": "landmark", "pos": at})
	var where: Dictionary = g.world.meta.get("finds", {})
	for r: Dictionary in content.rows("spoiler_finds"):
		var id := str(r["id"])
		if g.finds_found.has(id) or taken.has("find:" + id) or not where.has(id):
			continue
		var at := Vector2(float(where[id][0]), float(where[id][1]))
		if reachable(at):
			out.append({"target": "find:" + id, "kind": "find", "pos": at})
	return out


## Inside the land the ranger can walk to now: on the baked world, and on
## this side of the river (the broken bridge marks it; the far bank waits
## for a later phase).
func reachable(at: Vector2) -> bool:
	var g := s()
	var t := Vector2i(at)
	if not g.world.in_bounds(t):
		return false
	if g.world.meta["landmarks"].has("broken_bridge") and at.x > float(g.world.meta["landmarks"]["broken_bridge"][0]) + 1.0:
		return false
	var mask := g.world.explorable_mask()
	if mask.is_empty():
		return true
	var i := t.y * g.world.width + t.x
	return i >= 0 and i < mask.size() and mask[i] != 0


## Whether a Path circle's thing has been found since.
func path_done(p: Dictionary) -> bool:
	var g := s()
	var tg := str(p["target"])
	var id := tg.get_slice(":", 1)
	if tg.begins_with("landmark:"):
		return g.map.is_landmark_mapped(id)
	if tg.begins_with("find:"):
		return g.finds_found.has(id)
	return true


## The Path circles still to show on the map: {center, radius, text, icon}.
func map_hints() -> Array:
	var out := []
	for p: Dictionary in paths:
		if path_done(p):
			continue
		out.append({"id": "fortune:" + str(p["target"]), "center": Vector2(float(p["center"][0]), float(p["center"][1])), "radius": float(p["radius"]), "text": content.text("fortune_map_label"), "icon": "map_fortune_path"})
	return out


func _draw_path(rng: RandomNumberGenerator) -> String:
	var all := path_targets()
	if all.is_empty():
		return ""
	var t: Dictionary = all[rng.randi_range(0, all.size() - 1)]
	var radius := tuning.num("fortune.base_radius") * tuning.num("fortune.path_radius_mult")
	# The circle is off-centre, so the thing is somewhere inside, not at its middle.
	var off := Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.6)
	var c: Vector2 = (t["pos"] as Vector2) + off
	paths.append({"target": t["target"], "kind": t["kind"], "center": [c.x, c.y], "radius": radius, "day": s().clock.absolute_day()})
	return line("path_" + str(t["kind"]))


# --- the Heart ----------------------------------------------------------------------

## Something true about someone the ranger has met: what they'd love, a
## birthday within the week, or where they'll be tomorrow afternoon.
func _draw_heart(rng: RandomNumberGenerator) -> String:
	var g := s()
	var people: Array[String] = []
	for r: Dictionary in content.rows("townsfolk"):
		var id := str(r["id"])
		if g.town.met.has(id) and id != "esme":
			people.append(id)
	if people.is_empty():
		return ""
	var who := people[rng.randi_range(0, people.size() - 1)]
	var name := g.shops.first_name(who)
	# A birthday within seven days comes first: it's the most useful.
	var b: Dictionary = content.row("townsfolk", who)["birthday"]
	var today := g.clock.absolute_day()
	var dps := g.clock.days_per_season()
	var bday := int(b["season"]) * dps + int(b["day"]) - 1
	var now_in_year := g.clock.season * dps + g.clock.day - 1
	var ahead := posmod(bday - now_in_year, dps * 4)
	if ahead > 0 and ahead <= 7:
		var when := content.text("fest_tomorrow") if ahead == 1 else content.text("fest_in_days", {"n": ahead})
		return line("heart_birthday", {"name": name, "when": when})
	var kind := rng.randi_range(0, 1)
	if kind == 0 and content.has("gift_tastes", who):
		var loves: Array = content.row("gift_tastes", who).get("love", [])
		loves = loves.filter(func(x: Variant) -> bool: return content.has("items", str(x)))
		if not loves.is_empty():
			var item := str(loves[rng.randi_range(0, loves.size() - 1)])
			return line("heart_love", {"name": name, "item": content.item_name(item).to_lower()})
	# Where they'll be tomorrow, from tomorrow's own weather: never wrong.
	var minute := tuning.integer("fortune.heart_hour")
	var day := Town.DAYS[posmod(today + 1, 7)]
	var wet := (tuning.value("town.rain_weathers") as Array).has(g.weather._main_weather(g.weather.tomorrow))
	var place := g.town.routine_place(who, minute, day, wet)
	var pname := str(content.row("town_places", place)["name"]) if content.has("town_places", place) else place.replace("_", " ")
	return line("heart_where", {"name": name, "time": GameClock.time_of(minute), "place": pname})


# --- a reading ------------------------------------------------------------------------

## Draws the three cards and charges for them. {cards: [{card, text}],
## price, free}. Returns {} if Esme isn't reading or it's been done today.
func reading(force: bool = false) -> Dictionary:
	var g := s()
	if not force and (read_today() or not open_now()):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:fortune:%d" % [g.seed_value, g.clock.absolute_day()])
	var path := _draw_path(rng)
	var heart := _draw_heart(rng)
	var free := path == "" and heart == ""
	var price := 0 if free else tuning.integer("fortune.price")
	if price > 0 and not g.park.money.can_afford(price):
		if path != "":
			paths.pop_back()
		return {"cant_afford": true}
	if price > 0:
		g.park.money.spend(g.clock.absolute_day(), "shops", price)
	read_day = g.clock.absolute_day()
	g.town.met["esme"] = true
	last = {"cards": [
		{"card": "sky", "text": sky_text()},
		{"card": "path", "text": path if path != "" else line("path_none")},
		{"card": "heart", "text": heart if heart != "" else line("heart_none")},
	], "price": price, "free": free, "intro": line("intro_free" if free else "intro")}
	return last


# --- saving -------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"read_day": read_day, "paths": paths.duplicate(true)}


func from_dict(d: Dictionary) -> void:
	read_day = int(d.get("read_day", -1))
	paths = []
	for p: Variant in d.get("paths", []):
		paths.append((p as Dictionary).duplicate(true))
	last = {}


func new_game() -> void:
	from_dict({})
