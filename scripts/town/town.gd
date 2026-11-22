class_name Town
extends RefCounted
## Humdrum, the town outside the park gate (Phase 4 Spec, 4a first pass):
## its map, its twelve people and their routines, talking, friendship and
## gifts. The town is its own area: the ranger walks into it through the
## park gate, like walking into a building but outdoors. While the ranger is
## here, the park still has them at its gate, so weather, warmth and the
## clock carry on unchanged.
##
## People are simple records (where they should be) when the ranger is not in
## town, and walk between places along the town's paths when the ranger is.
## Friendship never goes down: a disliked gift never takes anyone below a
## heart already earned.

const DAYS: Array[String] = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var size: Vector2i
var ground: PackedStringArray = []
var buildings: Array = []
var objects: Array = []
var places: Dictionary = {}       # place id -> Vector2i (a walkable tile)
var entry: Vector2 = Vector2.ZERO
var exit_x: float = 0.0
var _solid: Dictionary = {}       # Vector2i -> true
var _paths: Dictionary = {}       # "from|to" -> Array[Vector2i], cached

# People: id -> {"pos": Vector2, "path": Array[Vector2i], "facing": int, "goal": String}
var people: Dictionary = {}
# Friendship and talk, saved: id -> int points.
var friendship: Dictionary = {}
var met: Dictionary = {}            # id -> true
var talked_day: Dictionary = {}     # id -> absolute day last talked to
var gifts_week: Dictionary = {}     # id -> [week number, gifts given that week]
var birthday_gift_year: Dictionary = {}   # id -> year a birthday gift was last given
var heard: Dictionary = {}          # line id -> absolute day last said
var today_line: Dictionary = {}     # id -> [absolute day, line id]: a person keeps one line a day


func _init(session: GameSession, path: String = "res://data/world/town.json") -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	size = Vector2i(int(d["size"][0]), int(d["size"][1]))
	for r: String in d["ground"]:
		ground.append(r)
	buildings = d["buildings"]
	objects = d["objects"]
	for k: String in d["places"]:
		places[k] = Vector2i(int(d["places"][k][0]), int(d["places"][k][1]))
	entry = Vector2(float(d["entry"][0]), float(d["entry"][1]))
	exit_x = float(d["exit_x"])
	var solid_grounds: Array = d["solid_grounds"]
	for y in size.y:
		for x in size.x:
			if ground[y][x] in solid_grounds:
				_solid[Vector2i(x, y)] = true
	for b: Dictionary in buildings:
		for y in range(int(b["pos"][1]), int(b["pos"][1]) + int(b["size"][1])):
			for x in range(int(b["pos"][0]), int(b["pos"][0]) + int(b["size"][0])):
				_solid[Vector2i(x, y)] = true
	for o: Dictionary in objects:
		if bool(o["solid"]):
			_solid[Vector2i(int(o["pos"][0]), int(o["pos"][1]))] = true


func session() -> GameSession:
	return _s.get_ref()


# --- the map ------------------------------------------------------------------

func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y


## Solid: off the map, deep water, a building or a tree. The park road's end
## (east) is open, so the ranger can walk back out.
func is_solid(t: Vector2i) -> bool:
	if t.x >= size.x and t.y >= 0 and t.y < size.y:
		return false
	return not in_bounds(t) or _solid.has(t)


func ground_at(t: Vector2i) -> String:
	if not in_bounds(t):
		return "l"
	return ground[t.y][t.x]


func building(id: String) -> Dictionary:
	for b: Dictionary in buildings:
		if b["id"] == id:
			return b
	return {}


## The building whose door the ranger stands at, or "".
func door_at(pos: Vector2, reach: float) -> String:
	for b: Dictionary in buildings:
		var door := Vector2(float(b["door"][0]) + 0.5, float(b["door"][1]) + 1.0)
		if door.distance_to(pos) <= reach:
			return str(b["id"])
	return ""


## The town notice board, if within reach.
func notice_board_near(pos: Vector2, reach: float) -> bool:
	for o: Dictionary in objects:
		if str(o.get("id", "")) == "notice_board" and (Vector2(float(o["pos"][0]), float(o["pos"][1])) + Vector2(0.5, 0.5)).distance_to(pos) <= reach + 0.5:
			return true
	return false


# --- days and hours -----------------------------------------------------------

## Today's day of the week, "mon" to "sun". Day 1 of every season is a Monday.
func weekday() -> String:
	return DAYS[posmod(session().clock.absolute_day(), 7)]


func _rainy() -> bool:
	return session().current_weather() in (tuning.value("town.rain_weathers") as Array)


## Whether a shop or the caravan is open at a minute of today.
func is_open(place: String, minute: int = -1) -> bool:
	if not content.has("town_places", place):
		return false
	var r := content.row("town_places", place)
	if not r.has("open"):
		return false
	if minute < 0:
		minute = session().clock.minute
	if (r.get("closed", []) as Array).has(weekday()):
		return false
	return minute >= int(r["open"]) and minute < int(r["close"])


# --- routines -----------------------------------------------------------------

## Where a person should be at a minute of today: the place held from the
## last routine entry at or before it.
func routine_place(person: String, minute: int = -1, day: String = "", rainy: Variant = null) -> String:
	if minute < 0:
		minute = session().clock.minute
	if day == "":
		day = weekday()
	var wet: bool = _rainy() if rainy == null else bool(rainy)
	var r := content.row("routines", person)
	var plan: Array = r["default"]
	if wet and r.has("rain"):
		plan = r["rain"]
	elif r.has(day):
		plan = r[day]
	# After midnight (the day runs past 24:00) the day's last place holds.
	var at := str(plan[0][1])
	for e: Array in plan:
		if int(e[0]) <= minute:
			at = str(e[1])
	return at


## Whether a person at a place is inside (not seen): at home, or in a shop
## (the keeper behind its counter). The caravan's keeper stands at its door.
func is_inside(person: String, place: String) -> bool:
	if not content.has("town_places", place):
		return false
	var r := content.row("town_places", place)
	match str(r["kind"]):
		"home":
			return true
		"shop", "caravan":
			# A shop with a room (Phase 4, step 5): everyone there is inside,
			# the keeper behind the counter.
			if content.has("town_interiors", place):
				return true
			return str(r.get("keeper", "")) != person or not is_open(place)
	return false


## Whether a person is out where the ranger can see them: walking, or
## standing somewhere outdoors (not inside at home or a shut shop).
func shown(person: String) -> bool:
	if not people.has(person):
		return false
	var p: Dictionary = people[person]
	return not (p["path"] as Array).is_empty() or not is_inside(person, str(p["goal"]))


## Sets everyone where their routine has them now: used on entering town and
## when time jumps (sleep, debug).
func place_everyone() -> void:
	for r: Dictionary in content.rows("townsfolk"):
		var id := str(r["id"])
		var at := routine_place(id)
		var t: Vector2i = places.get(at, places["square_green"])
		people[id] = {"pos": Vector2(t) + Vector2(0.5, 0.5), "path": [], "facing": GameSession.FACING_DOWN, "goal": at}


## Walks everyone toward where their routine has them now.
func update(delta: float) -> void:
	if people.is_empty():
		place_everyone()
	var speed := tuning.num("town.walk_tiles_per_second") * delta
	for id: String in people:
		var p: Dictionary = people[id]
		var want := routine_place(id)
		if want != str(p["goal"]):
			p["goal"] = want
			p["path"] = path_between(Vector2i(p["pos"]), places.get(want, places["square_green"]))
		var path: Array = p["path"]
		var left := speed
		while left > 0.0 and not path.is_empty():
			var target := Vector2(path[0]) + Vector2(0.5, 0.5)
			var d: Vector2 = target - p["pos"]
			if d.length() <= left:
				p["pos"] = target
				left -= d.length()
				path.pop_front()
			else:
				p["pos"] = (p["pos"] as Vector2) + d.normalized() * left
				left = 0.0
			if d.length() > 0.001:
				p["facing"] = _facing_of(d)


static func _facing_of(d: Vector2) -> int:
	if absf(d.x) > absf(d.y):
		return GameSession.FACING_RIGHT if d.x > 0 else GameSession.FACING_LEFT
	return GameSession.FACING_DOWN if d.y > 0 else GameSession.FACING_UP


## The tiles from a to b along walkable ground (breadth-first), b included.
func path_between(a: Vector2i, b: Vector2i) -> Array:
	var key := "%d,%d|%d,%d" % [a.x, a.y, b.x, b.y]
	if _paths.has(key):
		return (_paths[key] as Array).duplicate()
	var prev := {a: a}
	var q: Array[Vector2i] = [a]
	var h := 0
	while h < q.size() and not prev.has(b):
		var c := q[h]
		h += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if prev.has(n) or not in_bounds(n) or (_solid.has(n) and n != b):
				continue
			prev[n] = c
			q.append(n)
	var out: Array = []
	if not prev.has(b):
		out = [b]
	else:
		var c := b
		while c != a:
			out.push_front(c)
			c = prev[c]
	_paths[key] = out.duplicate()
	return out


# --- friendship ---------------------------------------------------------------

func points(person: String) -> int:
	return int(friendship.get(person, 0))


func hearts(person: String) -> int:
	return points(person) / tuning.integer("friendship.points_per_heart")


## The most points a person's friendship can reach now: romance candidates
## stop at 8 hearts until dating (4b), everyone else reaches 10.
func cap(person: String) -> int:
	var per := tuning.integer("friendship.points_per_heart")
	var r := content.row("townsfolk", person)
	if bool(r.get("romance", false)):
		return per * tuning.integer("romance.hearts_before_dating")
	return per * tuning.integer("friendship.max_hearts")


## Adds friendship. A loss never goes below the heart already earned.
func add_points(person: String, n: int) -> void:
	var now := points(person)
	var floor_pts := hearts(person) * tuning.integer("friendship.points_per_heart")
	friendship[person] = clampi(now + n, floor_pts if n < 0 else 0, cap(person))


func is_birthday(person: String) -> bool:
	var b: Dictionary = content.row("townsfolk", person)["birthday"]
	var c := session().clock
	return int(b["season"]) == c.season and int(b["day"]) == c.day


# --- talking ------------------------------------------------------------------

## The person within reach of pos, nearest first, or "".
func person_near(pos: Vector2, reach: float) -> String:
	var best := ""
	var best_d := reach
	for id: String in people:
		if not shown(id):
			continue
		var d := (people[id]["pos"] as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = id
	return best


## What a person says now, with the friendship for talking once a day. Returns
## {"name", "text", "hearts"}.
func talk(person: String) -> Dictionary:
	var s := session()
	var day := s.clock.absolute_day()
	var first := not met.has(person)
	met[person] = true
	if int(talked_day.get(person, -1)) != day:
		talked_day[person] = day
		add_points(person, tuning.integer("friendship.talk_points"))
	# Like Stardew: once spoken to today, a person keeps to today's line.
	var line := {}
	var kept: Array = today_line.get(person, [-1, ""])
	if int(kept[0]) == day and not first:
		line = _line_by_id(str(kept[1]))
	if line.is_empty():
		line = choose_line(person, first)
	if not line.is_empty():
		heard[str(line["id"])] = day
		today_line[person] = [day, str(line["id"])]
	return {"name": str(content.row("townsfolk", person)["name"]), "text": str(line.get("text", "")), "hearts": hearts(person)}


## Every line a person could say now, best first: the first meeting, then
## lines about something done in the park, then heart lines, then the rest.
## No line said within the week, unless nothing else is left.
func choose_line(person: String, first: bool) -> Dictionary:
	var s := session()
	var day := s.clock.absolute_day()
	var all: Array = []
	for table in ["dialogue", "spoiler_dialogue"]:
		for r: Dictionary in content.rows(table):
			if str(r["speaker"]) == person:
				all.append(r)
	if first:
		for r: Dictionary in all:
			if bool(r.get("intro", false)):
				return r
	var fit: Array = []
	for r: Dictionary in all:
		if not bool(r.get("intro", false)) and line_fits(person, r):
			fit.append(r)
	var fresh := fit.filter(func(r: Dictionary) -> bool: return day - int(heard.get(str(r["id"]), -9999)) >= 7)
	var pool := fresh if not fresh.is_empty() else fit
	if pool.is_empty():
		return {}
	var best := -1
	var top: Array = []
	for r: Dictionary in pool:
		var score := 0
		if r.has("event"):
			score = 3
		elif r.has("min_hearts"):
			score = 2
		elif r.has("season") or r.has("weather") or r.has("time"):
			score = 1
		if score > best:
			best = score
			top = [r]
		elif score == best:
			top.append(r)
	# Least recently said first, then a fixed order, so a test can follow it.
	top.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ha := int(heard.get(str(a["id"]), -9999))
		var hb := int(heard.get(str(b["id"]), -9999))
		return ha < hb if ha != hb else str(a["id"]) < str(b["id"]))
	return top[0]


func _line_by_id(id: String) -> Dictionary:
	for table in ["dialogue", "spoiler_dialogue"]:
		if content.has(table, id):
			return content.row(table, id)
	return {}


func line_fits(person: String, r: Dictionary) -> bool:
	var s := session()
	if r.has("min_hearts") and hearts(person) < int(r["min_hearts"]):
		return false
	if r.has("season") and str(r["season"]) != s.clock.season_name():
		return false
	if r.has("weather") and (str(r["weather"]) == "rain") != _rainy():
		return false
	if r.has("time"):
		var h := (s.clock.minute / 60) % 24
		var part := "morning" if h < 12 else ("afternoon" if h < 18 else "evening")
		if part != str(r["time"]):
			return false
	if r.has("event") and not park_event(str(r["event"])):
		return false
	return true


## Whether something happened in the park that the town talks about.
func park_event(key: String) -> bool:
	var s := session()
	if key.begins_with("site:"):
		return s.sites_open.has(key.substr(5))
	if key.begins_with("milestone:"):
		return s.park.milestones.has(key.substr(10))
	if key == "badger":
		return s.park.met_badger
	if key.begins_with("jobs:"):
		var n := 0
		for k: String in s.jobs.known:
			if s.jobs.is_done(k):
				n += 1
		return n >= int(key.substr(5))
	return false


# --- gifts --------------------------------------------------------------------

## How a person feels about an item: "love", "like", "neutral", "dislike",
## "hate", or "no" for things that can't be given (tools, kits, pages).
func taste(person: String, item: String) -> String:
	var kind := str(content.row("items", item)["kind"])
	if not kind in (tuning.value("town.giftable_kinds") as Array):
		return "no"
	for level in ["hate", "dislike", "love", "like"]:
		for who in [person, "_all"]:
			if not content.has("gift_tastes", who):
				continue
			var list: Array = content.row("gift_tastes", who).get(level, [])
			if list.has(item) or list.has("group:" + kind):
				return level
	return "neutral"


## Gifts left this week (the birthday gift is extra, once a year).
func gifts_left(person: String) -> int:
	var week := session().clock.absolute_day() / 7
	var g: Array = gifts_week.get(person, [week, 0])
	var used := int(g[1]) if int(g[0]) == week else 0
	return tuning.integer("friendship.gifts_per_week") - used


## Gives one of an item from the backpack. Returns {"ok", "taste", "points",
## "reason"}: reason "no" (can't be given), "limit" (two this week already).
func give(person: String, item: String) -> Dictionary:
	var s := session()
	var t := taste(person, item)
	if t == "no":
		return {"ok": false, "reason": "no", "taste": t}
	var bday := is_birthday(person) and int(birthday_gift_year.get(person, 0)) != s.clock.year
	if not bday and gifts_left(person) <= 0:
		return {"ok": false, "reason": "limit", "taste": t}
	if not s.backpack.remove(item, 1):
		return {"ok": false, "reason": "none", "taste": t}
	var pts := int((tuning.value("friendship.gift_points") as Dictionary)[t])
	if bday:
		pts *= tuning.integer("friendship.birthday_multiplier")
		birthday_gift_year[person] = s.clock.year
	else:
		var week := s.clock.absolute_day() / 7
		var g: Array = gifts_week.get(person, [week, 0])
		gifts_week[person] = [week, (int(g[1]) if int(g[0]) == week else 0) + 1]
	met[person] = true
	add_points(person, pts)
	return {"ok": true, "taste": t, "points": pts, "birthday": bday}


# --- saving -------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"friendship": friendship.duplicate(),
		"met": met.keys(),
		"talked_day": talked_day.duplicate(),
		"gifts_week": gifts_week.duplicate(true),
		"birthday_gift_year": birthday_gift_year.duplicate(),
		"heard": heard.duplicate(),
		"today_line": today_line.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	friendship = {}
	for k: String in d.get("friendship", {}):
		friendship[k] = int(d["friendship"][k])
	met = {}
	for k: Variant in d.get("met", []):
		met[str(k)] = true
	talked_day = {}
	for k: String in d.get("talked_day", {}):
		talked_day[k] = int(d["talked_day"][k])
	gifts_week = {}
	for k: String in d.get("gifts_week", {}):
		gifts_week[k] = [int(d["gifts_week"][k][0]), int(d["gifts_week"][k][1])]
	birthday_gift_year = {}
	for k: String in d.get("birthday_gift_year", {}):
		birthday_gift_year[k] = int(d["birthday_gift_year"][k])
	heard = {}
	for k: String in d.get("heard", {}):
		heard[k] = int(d["heard"][k])
	today_line = {}
	for k: String in d.get("today_line", {}):
		today_line[k] = [int(d["today_line"][k][0]), str(d["today_line"][k][1])]
	people = {}


func new_game() -> void:
	from_dict({})
