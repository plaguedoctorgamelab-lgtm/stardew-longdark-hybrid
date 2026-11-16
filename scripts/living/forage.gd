class_name Forage
extends RefCounted
## What the forest offers to gather. Ordinary ground forage grows at spots
## fixed when the land was baked (data/world/forage.json); each season the
## save's seed activates a share of them, each morning a free active spot may
## grow its forage, and what is not picked lasts a few days. Berries, rose hips
## and pine resin are picked from bushes and pines. The magical ingredients
## have about ten possible places each, of which a save uses a few.
##
## Nothing is stored about forage that was never picked: whether a spot holds
## something on a day is worked out from the seed, so the whole built world is
## tracked without a daily pass over it. Only picks, digs and wet days are saved.

signal changed

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]

var content: ContentDB
var tuning: Tuning
var world: WorldData
var seed_value: int = 0

var spots: Dictionary = {}          # tile -> ground forage id (fixed by the bake)
var by_chunk: Dictionary = {}       # chunk -> Array of spot tiles
var magic_places: Dictionary = {}   # forage id -> Array[Vector2i], every baked place
var magic_used: Dictionary = {}     # tile -> forage id: this save's places
var object_rows: Dictionary = {}    # object kind -> Array of forage rows picked from it

var picked: Dictionary = {}         # tile -> absolute day last picked (ground and magic)
var obj_picked: Dictionary = {}     # tile -> {forage id: absolute day} (bushes and pines)
var dug: Dictionary = {}            # tile -> true: a buried ingredient dug up for good
var wet_days: Dictionary = {}       # absolute day -> true: it rained that day

static var _baked: Dictionary = {}  # world dir -> parsed forage.json


func _init(c: ContentDB, t: Tuning, w: WorldData) -> void:
	content = c
	tuning = t
	world = w
	_load_baked()
	for r: Dictionary in content.rows("forage"):
		if str(r.get("source", "ground")) == "object":
			for kind: String in r["objects"]:
				if not object_rows.has(kind):
					object_rows[kind] = []
				(object_rows[kind] as Array).append(r)


func _load_baked() -> void:
	var dir := world._dir
	if not _baked.has(dir):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "forage.json"))
		_baked[dir] = parsed if typeof(parsed) == TYPE_DICTIONARY else {"spots": {}, "magic": {}}
	var data: Dictionary = _baked[dir]
	spots.clear()
	by_chunk.clear()
	for id: String in data.get("spots", {}):
		if not content.has("forage", id):
			continue
		for p: Array in data["spots"][id]:
			var t := Vector2i(int(p[0]), int(p[1]))
			if spots.has(t):
				continue
			spots[t] = id
			var c := world.chunk_of(t)
			if not by_chunk.has(c):
				by_chunk[c] = []
			(by_chunk[c] as Array).append(t)
	magic_places.clear()
	for id: String in data.get("magic", {}):
		var list: Array[Vector2i] = []
		for p: Array in data["magic"][id]:
			list.append(Vector2i(int(p[0]), int(p[1])))
		magic_places[id] = list


## A new save: draws which of each ingredient's places this save uses.
func start(new_seed: int) -> void:
	seed_value = new_seed
	picked.clear()
	obj_picked.clear()
	dug.clear()
	wet_days.clear()
	_choose_magic()
	changed.emit()


func _choose_magic() -> void:
	magic_used.clear()
	var n := tuning.integer("magic.places_per_save")
	for id: String in magic_places:
		var list: Array = (magic_places[id] as Array).duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, "magic", id])
		for i in range(list.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Variant = list[i]
			list[i] = list[j]
			list[j] = tmp
		for i in mini(n, list.size()):
			magic_used[list[i]] = id


# --- days and seasons -----------------------------------------------------------

func _dps() -> int:
	return tuning.integer("time.days_per_season")


func season_of(day: int) -> String:
	return SEASONS[(day / _dps()) % 4]


func in_season(r: Dictionary, day: int) -> bool:
	var s := season_of(day)
	if not (r["seasons"] as Array).has(s):
		return false
	var limits: Dictionary = r.get("season_days", {})
	if limits.has(s):
		var d := day % _dps() + 1
		return d >= int(limits[s][0]) and d <= int(limits[s][1])
	return true


func _roll(parts: Array) -> float:
	return float(posmod(hash(parts), 1000000)) / 1000000.0


# --- ground forage ----------------------------------------------------------------

## Whether a spot is one of this season's active spots in this save.
func is_active(t: Vector2i, day: int) -> bool:
	if not spots.has(t):
		return false
	var r := content.row("forage", spots[t])
	return _roll([seed_value, "active", t.x, t.y, day / _dps()]) < float(r["active_share"])


## Whether new forage grew at the spot on that morning.
func grew_on(t: Vector2i, day: int) -> bool:
	if not is_active(t, day):
		return false
	var r := content.row("forage", spots[t])
	var ok := in_season(r, day)
	if not ok and r.has("after_weather"):
		ok = wet_days.has(day - 1)
	if not ok:
		return false
	var chance := float(r["chance"]) * float((r.get("season_chance", {}) as Dictionary).get(season_of(day), 1.0))
	return _roll([seed_value, "grow", t.x, t.y, day]) < chance


## The morning the forage now at the spot grew, or -1 if the spot is empty.
func grown_day(t: Vector2i, today: int) -> int:
	var lasts := tuning.integer("forage.lasts_days")
	for d in range(today, today - lasts, -1):
		if grew_on(t, d):
			return d if d > int(picked.get(t, -1000000)) else -1
	return -1


func has_ground(t: Vector2i, today: int) -> bool:
	return spots.has(t) and grown_day(t, today) >= 0


# --- magical ingredients ---------------------------------------------------------

func magic_at(t: Vector2i) -> String:
	return str(magic_used.get(t, ""))


## Whether a magical ingredient is at its place now. ctx: {night, weather}.
## regrow_mult shortens (or lengthens) the days it takes to come back.
func has_magic(t: Vector2i, today: int, ctx: Dictionary, regrow_mult: float = 1.0) -> bool:
	var id := magic_at(t)
	if id == "":
		return false
	var r := content.row("forage", id)
	if not in_season(r, today):
		return false
	if str(r.get("source", "")) == "buried":
		return not dug.has(t)
	if picked.has(t):
		var days := ceili(tuning.num(str(r["regrow"])) * regrow_mult)
		if today - int(picked[t]) < days:
			return false
	if bool(r.get("night_only", false)) and not bool(ctx.get("night", false)):
		return false
	if r.has("weather") and not (r["weather"] as Array).has(str(ctx.get("weather", ""))):
		return false
	return true


## Like has_magic, but ignoring the hour and weather: whether it would be there
## when its time comes (for the Seeker's sense).
func magic_waiting(t: Vector2i, today: int, regrow_mult: float = 1.0) -> bool:
	return has_magic(t, today, {"night": true, "weather": _any_weather(magic_at(t))}, regrow_mult)


func _any_weather(id: String) -> String:
	if id == "":
		return ""
	var w: Array = content.row("forage", id).get("weather", [""])
	return str(w[0])


# --- bushes and pines -------------------------------------------------------------

## The forage an object of this kind gives today, or {} if none.
func object_row(kind: String, day: int) -> Dictionary:
	for r: Dictionary in object_rows.get(kind, []):
		if in_season(r, day):
			return r
	return {}


func object_ready(t: Vector2i, r: Dictionary, today: int, refresh_days: int) -> bool:
	var got: Dictionary = obj_picked.get(t, {})
	return not got.has(r["id"]) or today - int(got[r["id"]]) >= refresh_days


func mark_object(t: Vector2i, forage_id: String, today: int) -> void:
	if not obj_picked.has(t):
		obj_picked[t] = {}
	obj_picked[t][forage_id] = today
	changed.emit()


func mark_picked(t: Vector2i, today: int) -> void:
	picked[t] = today
	changed.emit()


func mark_dug(t: Vector2i) -> void:
	dug[t] = true
	changed.emit()


func note_wet_day(day: int) -> void:
	wet_days[day] = true
	for d: int in wet_days.keys():
		if d < day - 7:
			wet_days.erase(d)


## Everything grows back at once (debug and tests).
func regrow_all() -> void:
	picked.clear()
	obj_picked.clear()
	changed.emit()


## Adds a ground spot of the given kind that holds forage today (debug and tests).
func add_spot(t: Vector2i, forage_id: String) -> void:
	var r := content.row("forage", forage_id)
	if bool(r.get("magic", false)):
		magic_used[t] = forage_id
		picked.erase(t)
		dug.erase(t)
	else:
		spots[t] = forage_id
		var c := world.chunk_of(t)
		if not by_chunk.has(c):
			by_chunk[c] = []
		if not (by_chunk[c] as Array).has(t):
			(by_chunk[c] as Array).append(t)
		picked[t] = -1000000
		forced[t] = true
	changed.emit()


## Spots the debug tools filled: they hold forage until picked.
var forced: Dictionary = {}


func has_ground_now(t: Vector2i, today: int) -> bool:
	if forced.has(t):
		return true
	return has_ground(t, today)


func take_ground(t: Vector2i, today: int) -> void:
	forced.erase(t)
	mark_picked(t, today)


func to_dict() -> Dictionary:
	var objs := []
	for t: Vector2i in obj_picked:
		for id: String in obj_picked[t]:
			objs.append([t.x, t.y, id, obj_picked[t][id]])
	return {
		"picked": picked.keys().filter(func(t: Vector2i) -> bool: return int(picked[t]) > -1000000).map(func(t: Vector2i) -> Array: return [t.x, t.y, picked[t]]),
		"objects": objs,
		"dug": dug.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y]),
		"wet": wet_days.keys(),
	}


## Loads a save's forage. Saves from before this version simply start fresh.
func from_dict(d: Dictionary, save_seed: int) -> void:
	seed_value = save_seed
	picked.clear()
	obj_picked.clear()
	dug.clear()
	wet_days.clear()
	forced.clear()
	_choose_magic()
	for e: Array in d.get("picked", []):
		picked[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	for e: Array in d.get("objects", []):
		var t := Vector2i(int(e[0]), int(e[1]))
		if not obj_picked.has(t):
			obj_picked[t] = {}
		obj_picked[t][str(e[2])] = int(e[3])
	for e: Array in d.get("dug", []):
		dug[Vector2i(int(e[0]), int(e[1]))] = true
	for v: Variant in d.get("wet", []):
		wet_days[int(v)] = true
	changed.emit()
