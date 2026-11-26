class_name Creatures
extends RefCounted
## Phase 5b, Gord and the night (docs/Phase 5b Spec.md).
##
## The park's four magical creatures (the troll badgers, the jackalopes, the
## magic deer and Gord), each with five paw hearts of friendship, a creature
## job (its "answer", steps in data/content/creature_jobs.json) and, once
## settled, a secret, hint or public choice. Also the moon (full on the 7th
## and 21st of each season), calendar events and aurora nights.
##
## Job steps of the creature kinds read their state from here: each step
## names a fact, and is done once that fact has been counted n times (see
## step_check). This module counts facts as the ranger does things, and only
## for the step that is current, so a creature job goes in order.
##
## What each creature loves, the badgers' terms and the magic deer's wish are
## in the spoiler tables (spoiler_creatures, spoiler_text), not here.

const IDS: Array[String] = ["troll_badgers", "jackalopes", "magic_deer", "gord"]
const CHOICES: Array[String] = ["secret", "hint", "public"]
## The guide's animal for each creature, and back.
const ANIMAL := {"troll_badgers": "troll_badger", "jackalopes": "jackalope", "magic_deer": "magic_deer", "gord": "gord_moose"}
const STEP_KINDS: Array[String] = ["feed", "be_near", "hearts", "lay_trail", "wait_at", "choose", "keep", "full_moon", "fill", "learn", "bring", "talk_about", "have"]

signal changed

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var points: Dictionary = {}        # creature -> friendship points
var fed_day: Dictionary = {}       # creature -> absolute day last fed
var near_day: Dictionary = {}      # creature -> day an hour near was last counted
var near_min: Dictionary = {}      # creature -> [day, minutes near today]
var bolted_day: Dictionary = {}    # creature -> day it was startled
var tastes: Dictionary = {}        # creature -> {item: "loves"/"likes"/"ok"/"wont"}
var facts: Dictionary = {}         # fact -> count
var choice: Dictionary = {}        # creature -> "secret", "hint" or "public"
var choice_turn: Dictionary = {}   # creature -> season number (year * 4 + season) it last changed
var mischief: Dictionary = {}      # place -> bits of badger mischief there
var peace: Dictionary = {}         # place -> last absolute day the badgers' deal holds (-1: for good)
var deal_place: String = ""        # the place the badgers' deal is about
var terms: String = ""             # the offering agreed
var offered_week: Dictionary = {}  # week number -> true: an offering was left the right way
var burrows: Array = []            # Vector2i: the jackalopes' holes at the campground
var filled: Dictionary = {}        # Vector2i -> true
var trail_laid: int = 0
var trail_day: int = -1
var heard: Dictionary = {}         # calendar event id -> true
var gord_along: bool = false
var gord_pos: Vector2 = Vector2.INF
var bell_hung: bool = false
var five_seen: Dictionary = {}     # creature -> true: its five-heart scene was shown
var gift_week: Dictionary = {}     # creature -> week a gift was last left
var forced_aurora: int = -1        # debug: an aurora on this absolute day
var spare_waiting: bool = false    # the second pet waits on a cabin step
var _day: int = -1
var _last_minute: int = -1
var _said: Dictionary = {}         # one-off messages today: key -> day
var _aurora: Dictionary = {}       # year -> Array of absolute days


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning


func s() -> GameSession:
	return _s.get_ref()


func _t(id: String, args: Dictionary = {}) -> String:
	return content.text(id, args)


func row(c: String) -> Dictionary:
	return content.row("creatures", c) if content.has("creatures", c) else {}


func secret_row(c: String) -> Dictionary:
	return content.row("spoiler_creatures", c) if content.has("spoiler_creatures", c) else {}


func name_of(c: String) -> String:
	return _t(str(row(c).get("name", c)))


func today() -> int:
	return s().clock.absolute_day()


func fact(f: String) -> int:
	return int(facts.get(f, 0))


func _count(f: String, n: int = 1) -> void:
	facts[f] = fact(f) + n
	s().jobs.mark_dirty()
	changed.emit()


func _say_once(key: String, text_id: String, args: Dictionary = {}) -> void:
	if int(_said.get(key, -1)) == today():
		return
	_said[key] = today()
	s().message.emit(_t(text_id, args))


# --- the moon ---------------------------------------------------------------------------

## The full moon's days in each season (tuning moon.full_days: 7 and 21).
func full_days() -> Array[int]:
	var out: Array[int] = []
	for f: Variant in tuning.value("moon.full_days"):
		out.append(int(f))
	return out


## The moon's phase on a day of the season, 0 (new) to 7; 4 is full.
func moon_phase(day_in_season: int = -1) -> int:
	if day_in_season < 0:
		day_in_season = s().clock.day
	var cycle := tuning.integer("moon.cycle_days")
	var first := int(full_days()[0])
	return (4 + roundi(posmod(day_in_season - first, cycle) * 8.0 / float(cycle))) % 8


func is_full_moon_day(day_in_season: int = -1) -> bool:
	if day_in_season < 0:
		day_in_season = s().clock.day
	return full_days().has(day_in_season)


## A full-moon night: the day of a full moon, from dusk until the day ends.
func full_moon_out() -> bool:
	var g := s()
	return is_full_moon_day() and (g.wildlife.phase() in ["dusk", "night"])


## The next day of the season with a full moon (for the calendar and jobs).
func next_full_moon_day() -> int:
	var d := s().clock.day
	for f: int in full_days():
		if f >= d:
			return f
	return int(full_days()[0])


# --- aurora nights -----------------------------------------------------------------------

## The aurora nights of a year, as absolute days: two or three, at least
## twenty days apart, at least one in winter, never on a full moon. The
## same for a seed and year, so the weather and Esme agree without a save.
static func aurora_days_for(seed_value: int, year: int, t: Tuning) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:aurora" % [seed_value, year])
	var per := t.integer("time.days_per_season")
	var start := (year - 1) * per * 4
	var fulls: Array[int] = []
	for f: Variant in t.value("moon.full_days"):
		fulls.append(int(f))
	var gap := t.integer("aurora.min_gap_days")
	var want := rng.randi_range(int(t.value("aurora.per_year")[0]), int(t.value("aurora.per_year")[1]))
	var out: Array = []
	var tries := 0
	while out.size() < want and tries < 400:
		tries += 1
		var d := start + 3 * per + rng.randi_range(0, per - 1) if out.is_empty() else start + rng.randi_range(0, per * 4 - 1)
		var dis := (d - start) % per + 1
		if fulls.has(dis) or (year == 1 and d < per):
			continue
		var ok := true
		for o: int in out:
			if absi(o - d) < gap:
				ok = false
		if ok:
			out.append(d)
	out.sort()
	return out


func aurora_days(year: int = -1) -> Array:
	if year < 0:
		year = s().clock.year
	if not _aurora.has(year):
		_aurora[year] = aurora_days_for(s().seed_value, year, tuning)
	return _aurora[year]


func aurora_on(abs_day: int) -> bool:
	return abs_day == forced_aurora or aurora_days(s().clock.year).has(abs_day)


## The aurora is in the sky now: an aurora day, after dusk.
func aurora_now() -> bool:
	return aurora_on(today()) and s().wildlife.phase() in ["dusk", "night"]


## How strongly the aurora shows now, 0 to 1 (for the sky and the tint).
func aurora_amount() -> float:
	var g := s()
	if not aurora_on(today()) or g.is_indoors() or g.in_town:
		return 0.0
	return Daylight.night_amount(tuning, g.clock.season_name(), g.clock.minute)


# --- friendship ----------------------------------------------------------------------------

func hearts(c: String) -> int:
	return mini(5, int(points.get(c, 0)) / tuning.integer("creatures.points_per_heart"))


func add_points(c: String, n: int) -> void:
	var g := s()
	var before := hearts(c)
	var v := g.skills.value("creature_friend", float(n))
	match str(choice.get(c, "")):
		"secret":
			v *= tuning.num("creatures.secret_friend_mult")
		"public":
			v *= tuning.num("creatures.public_friend_mult")
	points[c] = int(points.get(c, 0)) + roundi(v)
	var after := hearts(c)
	if after > before:
		g.message.emit(_t("cr_heart_up", {"name": name_of(c), "n": after}))
		if after >= 5 and not five_seen.has(c):
			five_seen[c] = true
			g.note_read.emit(_t("crs_five_" + c))
	s().jobs.mark_dirty()
	changed.emit()


## What a creature thinks of a food: loves, likes, ok or wont.
func taste(c: String, item: String) -> String:
	var r := secret_row(c)
	if c == "gord" and item == "coffee":
		return "loves" if fact("gord_coffee") > 0 else "wont"
	for k: String in ["loves", "likes", "wont"]:
		if (r.get(k, []) as Array).has(item):
			return k
	return "ok"


## Gives a creature the food held. Once a day each.
func feed(c: String, item: String) -> void:
	var g := s()
	if int(fed_day.get(c, -1)) == today():
		g.message.emit(_t("cr_not_hungry", {"name": name_of(c)}))
		return
	var ta := taste(c, item)
	if not tastes.has(c):
		tastes[c] = {}
	tastes[c][item] = ta
	if ta == "wont":
		g.message.emit(_t("cr_taste_wont", {"name": name_of(c), "item": content.item_name(item).to_lower()}))
		changed.emit()
		return
	g.backpack.remove(item, 1)
	fed_day[c] = today()
	g.skills.act("feed_creature")
	_count("fed:" + c)
	if ta == "loves":
		_count("fed_love:" + c)
	g.message.emit(_t("cr_taste_" + ta, {"name": name_of(c), "item": content.item_name(item).to_lower()}))
	add_points(c, tuning.integer("creatures.%s_points" % ta))


# --- where they are -----------------------------------------------------------------------

## A walkable tile near a plan point (east and north of the park gate),
## grass if there is some.
func _open_near(plan: Array) -> Vector2:
	var g := s()
	var gate: Array = g.world.meta.get("gate", [2, 1442])
	var c := Vector2i(int(gate[0]) + int(plan[0]), int(gate[1]) - int(plan[1]))
	for r in range(0, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if g.world.in_bounds(t) and not g.world.is_solid(t) and g.world.ground_at(t) in ["grass", "tall_grass"]:
					return Vector2(t) + Vector2(0.5, 0.5)
	return Vector2(c) + Vector2(0.5, 0.5)


## Gord's meadow: at the edge of the old burn, by the road to the tower.
func gord_meadow() -> Vector2:
	return _open_near(tuning.value("creatures.gord_meadow_plan"))


## The jackalopes' own meadow, past the pond.
func jack_meadow() -> Vector2:
	return _open_near(tuning.value("creatures.jack_meadow_plan"))


## The station's yard, where the magic deer comes.
func yard() -> Vector2:
	return s().door_front("ranger_station") + Vector2(-3.5, 2.5)


## The empty hook by the station door.
func hook_spot() -> Vector2:
	return s().door_front("ranger_station") + Vector2(-2.5, 0.0)


## The campground the jackalopes dig in, or Vector2.INF.
func campground() -> Vector2:
	var pads: Array = s().park.built_pads("campground")
	if pads.is_empty():
		return Vector2.INF
	return s().park.pad_center(str(pads[0]))


## The badgers' stone: beside the place the deal is about.
func stone() -> Vector2:
	if deal_place == "":
		return Vector2.INF
	var p := s().park.place_spot(deal_place)
	if p == Vector2.INF:
		return p
	var g := s()
	for off: Vector2 in [Vector2(3, 2), Vector2(-3, 2), Vector2(2, -3), Vector2(-2, -3), Vector2(4, 0)]:
		var t := Vector2i(p + off)
		if g.world.in_bounds(t) and not g.world.is_solid(t):
			return Vector2(t) + Vector2(0.5, 0.5)
	return p


## The trail's spots, campground to meadow, evenly along the way.
func trail_spots() -> Array:
	var a := campground()
	if a == Vector2.INF:
		return []
	var b := jack_meadow()
	var g := s()
	var n := tuning.integer("creatures.trail_spots")
	var out: Array = []
	for k in n:
		var p := a.lerp(b, float(k + 1) / float(n + 1))
		var t := Vector2i(p)
		for r in 4:
			if g.world.in_bounds(t) and not g.world.is_solid(t):
				break
			t += Vector2i(1, 0)
		out.append(Vector2(t) + Vector2(0.5, 0.5))
	return out


func settled(c: String) -> bool:
	return s().jobs.is_done(str(row(c).get("job", "")))


func job_active(c: String) -> bool:
	return s().jobs.is_active(str(row(c).get("job", "")))


## The step of a creature's job now, by its fact, or "".
func current(c: String) -> String:
	var j := s().jobs
	var key := str(row(c).get("job", ""))
	if not j.is_active(key):
		return ""
	var i := j.next_step(key)
	if i < 0:
		return ""
	return str(j.def(key)["steps"][i].get("fact", ""))


## The animals each creature puts out at a time of day, for the wildlife:
## [{id, home, n, creature}].
func out_at(ph: String) -> Array:
	var g := s()
	var out: Array = []
	var night := ph in ["dusk", "night"]
	if (job_active("troll_badgers") or settled("troll_badgers")) and stone() != Vector2.INF and night:
		out.append({"id": "troll_badger", "home": stone(), "n": 2, "creature": "troll_badgers"})
	if settled("jackalopes"):
		if ph == "dusk" or (night and (aurora_now() or is_full_moon_day())):
			out.append({"id": "jackalope", "home": jack_meadow(), "n": 3, "creature": "jackalopes"})
		if ph in ["day", "dawn"] and _event_today("first_snow"):
			out.append({"id": "jackalope", "home": jack_meadow(), "n": 4, "creature": "jackalopes"})
	elif job_active("jackalopes") and campground() != Vector2.INF and ph in ["dusk", "night"]:
		out.append({"id": "jackalope", "home": campground(), "n": 3, "creature": "jackalopes"})
	if ph == "night" and deer_visits_tonight():
		out.append({"id": "magic_deer", "home": yard(), "n": 1, "creature": "magic_deer"})
	if ph == "night" and _event_today("deer_outlook"):
		out.append({"id": "magic_deer", "home": g.world.landmark_pos("scenic_outlook"), "n": 4, "creature": "magic_deer"})
	if not (is_full_moon_day() and night) and ph in ["dawn", "day", "dusk"]:
		out.append({"id": "gord_moose", "home": gord_meadow(), "n": 1, "creature": "gord"})
	return out


## The magic deer comes to the yard: every few nights while its job wants
## it, every night once the bell hangs, and on autumn and winter nights once
## settled.
func deer_visits_tonight() -> bool:
	var g := s()
	if settled("magic_deer"):
		return g.clock.season >= 2 and today() % 2 == 0
	if not job_active("magic_deer"):
		return false
	return bell_hung or today() % tuning.integer("creatures.deer_every_nights") == 0


## Gord the man is in his meadow (or walking with the ranger): full-moon
## nights only.
func gord_man_out() -> bool:
	var g := s()
	return full_moon_out() and not g.in_town and g.clock.minute < tuning.integer("creatures.gord_until") and g.jobs.known.has(str(row("gord").get("job", "")))


func gord_spot() -> Vector2:
	if gord_along and gord_pos != Vector2.INF:
		return gord_pos
	return gord_meadow() + Vector2(1.0, 0.0)


## Gord sits by the Percolator's window on full-moon evenings, once he's had
## his coffee.
func gord_in_cafe(minute: int = -1) -> bool:
	var g := s()
	if minute < 0:
		minute = g.clock.minute
	var h: Array = tuning.value("creatures.gord_cafe_hours")
	return fact("gord_coffee") > 0 and is_full_moon_day() and minute >= int(h[0]) and minute < int(h[1])


## Wren keeps the Percolator open late: on the full moon she promised, and
## every full moon after Gord's coffee.
func percolator_late(minute: int) -> bool:
	if not is_full_moon_day():
		return false
	if fact("wren_late") <= 0:
		return false
	return minute >= 1080 and minute < tuning.integer("creatures.late_until")


# --- the day ----------------------------------------------------------------------------

func morning() -> void:
	var g := s()
	_day = today()
	gord_along = false
	gord_pos = Vector2.INF
	_jack_trouble()
	_gifts()
	_second_pet()
	# The trail's food is eaten overnight: the next spot shows.
	# Peace that ran out (the badgers' one-season deal).
	for p: String in peace.keys():
		if int(peace[p]) >= 0 and int(peace[p]) < today():
			peace.erase(p)
	# The bell rings in the night, now and then: a good morning.
	if bell_hung and settled("magic_deer") and g.clock.season >= 2 and today() % 3 == 0:
		g.needs.energy = minf(g.needs.max_energy(), g.needs.energy + tuning.num("creatures.bell_energy"))
		g.message.emit(_t("crs_bell_rang"))
	_hear_events()
	changed.emit()


## Spring: once the campground is open and a jackalope sketched, they dig in.
func _jack_trouble() -> void:
	var g := s()
	if not burrows.is_empty() or settled("jackalopes"):
		return
	if g.clock.season != 0:
		return
	var c := campground()
	if c == Vector2.INF or g.wildlife.level_of("jackalope") == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:burrows" % g.seed_value)
	var tries := 0
	while burrows.size() < tuning.integer("creatures.burrows") and tries < 60:
		tries += 1
		var t := Vector2i(c) + Vector2i(rng.randi_range(-4, 4), rng.randi_range(-4, 4))
		if g.world.in_bounds(t) and not g.world.is_solid(t) and not burrows.has(t) and Vector2(t).distance_to(c) > 1.5:
			burrows.append(t)
	if not burrows.is_empty():
		g.message.emit(_t("cr_burrows_dug"))


## A secret creature leaves a gift on the nearest cabin's step, about once a
## week; so does a settled one, with Whisperer.
func _gifts() -> void:
	var g := s()
	var week := today() / 7
	for c: String in IDS:
		if not settled(c):
			continue
		if str(choice.get(c, "")) != "secret" and not g.skills.flag("creature_gifts"):
			continue
		if int(gift_week.get(c, -1)) == week or hash("%d:%s:%d" % [g.seed_value, c, today()]) % 7 != 0:
			continue
		gift_week[c] = week
		var chest := "test_cabin" if g.structures.is_open("test_cabin") else "ranger_station"
		(g.structures.chests[chest] as Inventory).add("creature_gift", 1)
		g.message.emit(_t("cr_gift_left", {"name": name_of(c), "where": _t("cr_where_" + chest)}))


## The second pet (Phase 5b, 8): from the first winter, on a snowy morning,
## the other animal waits on the cabin step.
func _second_pet() -> void:
	var g := s()
	var p := g.pet
	if not p.has_pet() or not p.spare.is_empty():
		spare_waiting = false
		return
	if g.clock.season < tuning.integer("pet.second_from_season") and g.clock.year == 1:
		spare_waiting = false
		return
	if spare_waiting:
		return
	# The first snowy winter morning (or mid-winter at the latest).
	if g.weather.today.has("snow") or g.weather.today.has("blizzard") or g.clock.season != 3 or g.clock.day >= 14:
		spare_waiting = true
		g.message.emit(_t("pet_spare_waiting", {"kind": _t("pet_kind_" + p.other_kind())}))


func spare_spot() -> Vector2:
	var g := s()
	var cab := "test_cabin" if g.structures.is_open("test_cabin") else "ranger_station"
	return g.door_front(cab) + Vector2(1.5, 0.5)


# --- each frame ------------------------------------------------------------------------------

func update(_dt: float) -> void:
	var g := s()
	if _day != today():
		morning()
	var m := g.clock.minute
	var dm := 0
	if _last_minute >= 0 and m > _last_minute and m - _last_minute < 60:
		dm = m - _last_minute
	_last_minute = m
	if g.is_indoors() or g.in_town:
		return
	var near := tuning.num("creatures.near_tiles")
	var seen := {}
	for a: Dictionary in g.wildlife.visible_animals():
		if not a.has("creature"):
			continue
		var c := str(a["creature"])
		if str(a["state"]) == "flee":
			if int(bolted_day.get(c, -1)) != today():
				bolted_day[c] = today()
				g.message.emit(_t("cr_bolted"))
			continue
		if Vector2(a["pos"]).distance_to(g.outdoor_pos) <= near:
			seen[c] = true
	if gord_man_out() and gord_spot().distance_to(g.outdoor_pos) <= near:
		seen["gord"] = true
	for c: String in seen:
		_near(c, dm)
	_waits(seen)
	_follow(_dt)


func _near(c: String, dm: int) -> void:
	var g := s()
	if int(near_day.get(c, -1)) == today() or int(bolted_day.get(c, -1)) == today():
		return
	var nm: Array = near_min.get(c, [today(), 0])
	if int(nm[0]) != today():
		nm = [today(), 0]
	nm[1] = int(nm[1]) + dm
	near_min[c] = nm
	if int(nm[1]) >= tuning.integer("creatures.near_minutes"):
		near_day[c] = today()
		_count("near:" + c)
		g.message.emit(_t("cr_near_hour", {"name": name_of(c)}))
		add_points(c, tuning.integer("creatures.near_points"))


## Being at a place at the right time, for the wait-at steps.
func _waits(seen: Dictionary) -> void:
	var g := s()
	var ph := g.wildlife.phase()
	if current("jackalopes") == "jack_waited" and ph == "dusk" and g.outdoor_pos.distance_to(jack_meadow()) <= 5.0:
		_step_done("jackalopes", "jack_waited")
	if current("magic_deer") == "deer_seen_yard" and seen.has("magic_deer") and g.outdoor_pos.distance_to(yard()) <= 8.0:
		_step_done("magic_deer", "deer_seen_yard")
	if current("magic_deer") == "deer_rang" and bell_hung and seen.has("magic_deer") and g.outdoor_pos.distance_to(yard()) <= 8.0:
		if _gate("magic_deer"):
			_step_done("magic_deer", "deer_rang")
			g.note_read.emit(_t("crs_deer_rings"))


## The last step of a creature's job wants two paw hearts first.
func _gate(c: String) -> bool:
	if hearts(c) >= tuning.integer("creatures.last_step_hearts") or c == "gord":
		return true
	_say_once("gate:" + c, "cr_not_sure_yet", {"name": name_of(c), "n": tuning.integer("creatures.last_step_hearts")})
	return false


func _step_done(c: String, f: String) -> void:
	_count(f)
	s().skills.act("creature_step")
	add_points(c, tuning.integer("creatures.step_points"))


func _follow(dt: float) -> void:
	var g := s()
	if not gord_along:
		return
	if not gord_man_out() and not g.in_town:
		gord_along = false
		return
	if gord_pos == Vector2.INF:
		gord_pos = gord_spot()
	var to := g.outdoor_pos - gord_pos
	if to.length() > 14.0:
		gord_pos = g.outdoor_pos - to.normalized() * 1.5
	elif to.length() > 1.6:
		gord_pos += to.normalized() * minf(to.length() - 1.5, 5.0 * dt)


# --- X near a creature ----------------------------------------------------------------------

## The creature X would reach, and what: {creature, what, pos} or {}.
func in_reach(pos: Vector2, reach: float) -> Dictionary:
	var g := s()
	var r := reach + 0.8
	if gord_man_out() and pos.distance_to(gord_spot()) <= r:
		return {"creature": "gord", "what": "gord"}
	if (job_active("troll_badgers") or settled("troll_badgers")) and stone() != Vector2.INF and pos.distance_to(stone()) <= r:
		return {"creature": "troll_badgers", "what": "stone"}
	if job_active("jackalopes"):
		for t: Vector2i in burrows:
			if not filled.has(t) and pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r:
				return {"creature": "jackalopes", "what": "burrow", "tile": t}
		var spots := trail_spots()
		if current("jackalopes") == "trail" and trail_laid < spots.size() and pos.distance_to(spots[trail_laid]) <= r:
			return {"creature": "jackalopes", "what": "trail"}
	if (current("magic_deer") == "bell_hung" or bell_hung) and pos.distance_to(hook_spot()) <= r:
		return {"creature": "magic_deer", "what": "hook"}
	if spare_waiting and g.pet.spare.is_empty() and pos.distance_to(spare_spot()) <= r:
		return {"creature": "", "what": "spare_pet"}
	var best := {}
	var bd := r
	for a: Dictionary in g.wildlife.visible_animals():
		var c := str(a.get("creature", ""))
		if c == "":
			for k: String in ANIMAL:
				if str(ANIMAL[k]) == str(a["id"]):
					c = k
		if c == "":
			continue
		var d := Vector2(a["pos"]).distance_to(pos)
		if d <= bd:
			bd = d
			best = {"creature": c, "what": "animal"}
	return best


func interact(pos: Vector2, reach: float) -> bool:
	var hit := in_reach(pos, reach)
	if hit.is_empty():
		return false
	var g := s()
	var c := str(hit["creature"])
	var item := g.selected_item()
	match str(hit["what"]):
		"gord":
			if item != "" and content.has("foods", item) and fact("gord_met") > 0:
				feed("gord", item)
			else:
				talk_gord()
		"stone":
			_at_stone(item)
		"burrow":
			_fill(hit["tile"])
		"trail":
			_lay(item)
		"hook":
			_hang()
		"spare_pet":
			g.pet.adopt_spare()
			spare_waiting = false
		"animal":
			if item != "" and content.has("foods", item):
				feed(c, item)
			else:
				g.message.emit(_t("cr_look", {"name": name_of(c), "n": hearts(c)}))
	return true


func _at_stone(item: String) -> void:
	var g := s()
	if current("troll_badgers") == "badgers_terms":
		var opts := []
		for o: Dictionary in secret_row("troll_badgers").get("offerings", []):
			opts.append({"id": str(o["id"]), "label": _t(str(o["label"]))})
		g.choice_requested.emit("creature:terms", _t("crs_terms_title"), opts)
		return
	if terms == "":
		g.message.emit(_t("cr_stone"))
		return
	var want := str(_offering().get("item", ""))
	if item != want:
		g.message.emit(_t("crs_stone_wants", {"item": content.item_name(want).to_lower()}))
		return
	var ph := g.wildlife.phase()
	if not (ph in ["dusk", "night"]):
		g.message.emit(_t("crs_not_morning_badgers"))
		return
	var week := today() / 7
	if offered_week.has(week):
		g.message.emit(_t("crs_offered_already"))
		return
	var keeping := current("troll_badgers") == "badgers_weeks"
	if keeping and fact("badgers_weeks") + 1 >= _step_n("troll_badgers", "badgers_weeks") and not _gate("troll_badgers"):
		return
	g.backpack.remove(want, 1)
	offered_week[week] = true
	g.message.emit(_t("crs_offering_left"))
	if keeping:
		_step_done("troll_badgers", "badgers_weeks")
	elif g.jobs.is_active("cj_badgers_again"):
		_count("badgers_weeks2")


func _offering() -> Dictionary:
	for o: Dictionary in secret_row("troll_badgers").get("offerings", []):
		if str(o["id"]) == terms:
			return o
	return {}


func _step_n(c: String, f: String) -> int:
	var key := str(row(c).get("job", ""))
	var d := s().jobs.def(key)
	for stp: Dictionary in d.get("steps", []):
		if str(stp.get("fact", "")) == f:
			return int(stp.get("n", 1))
	return 1


func _fill(t: Vector2i) -> void:
	var g := s()
	if current("jackalopes") != "burrows_filled":
		g.message.emit(_t("cr_burrow"))
		return
	if not g.backpack.has("shovel"):
		g.message.emit(_t("msg_spot_needs_tool", {"tool": content.item_name("shovel").to_lower()}))
		return
	if not _gate("jackalopes"):
		return
	filled[t] = true
	_count("burrows_filled")
	g.message.emit(_t("cr_burrow_filled"))
	if fact("burrows_filled") >= burrows.size():
		g.skills.act("creature_step")
		add_points("jackalopes", tuning.integer("creatures.step_points"))


func _lay(item: String) -> void:
	var g := s()
	var love: Array = secret_row("jackalopes").get("loves", [])
	if item == "" or not love.has(item):
		g.message.emit(_t("crs_trail_wants"))
		return
	if trail_day == today():
		g.message.emit(_t("crs_trail_tomorrow"))
		return
	g.backpack.remove(item, 1)
	trail_laid += 1
	trail_day = today()
	_count("trail")
	g.message.emit(_t("crs_trail_laid", {"n": trail_laid, "of": trail_spots().size()}))
	if trail_laid >= trail_spots().size():
		g.skills.act("creature_step")
		add_points("jackalopes", tuning.integer("creatures.step_points"))


func _hang() -> void:
	var g := s()
	if bell_hung:
		g.message.emit(_t("crs_bell_hangs"))
		return
	if not g.backpack.has("old_bell"):
		g.message.emit(_t("crs_hook"))
		return
	g.backpack.remove("old_bell", 1)
	bell_hung = true
	_step_done("magic_deer", "bell_hung")
	g.message.emit(_t("crs_bell_hung"))


# --- Gord ---------------------------------------------------------------------------------

## X at Gord: what he says depends on how far along his job is.
func talk_gord() -> void:
	var g := s()
	var f := current("gord")
	var line := "crs_gord_hello"
	var mood := "neutral"
	if fact("gord_met") == 0:
		_step_done("gord", "gord_met")
		line = "crs_gord_meet"
		mood = "surprised"
	elif f == "gord_practised":
		if g.backpack.has("big_coat"):
			g.backpack.remove("big_coat", 1)
			_count("gord_dressed")
			var opts := []
			for k in 3:
				opts.append({"id": str(k), "label": _t("crs_practise_%d" % k)})
			g.choice_requested.emit("creature:practise", _t("crs_practise_title"), opts)
			return
		line = "crs_gord_needs_coat"
	elif f == "gord_coffee":
		gord_along = true
		gord_pos = gord_spot()
		line = "crs_gord_ready"
		mood = "happy"
	elif fact("gord_coffee") > 0:
		line = "crs_gord_after"
		mood = "happy"
	elif f in ["gord_words", "gord_coat", "wren_late"]:
		line = "crs_gord_waiting"
	g.townsperson_spoke.emit({"name": _t("cr_name_gord_man"), "text": _t(line), "hearts": hearts("gord"), "mood": mood, "person": "gord", "paw": true})


## Talking to someone in town: Wren tells you the words, and agrees to stay
## open late.
func on_talk(person: String) -> void:
	var g := s()
	if person != "wren":
		return
	if current("gord") == "gord_words":
		_step_done("gord", "gord_words")
		g.note_read.emit(_t("crs_wren_words"))
	elif current("gord") == "wren_late":
		if g.town.hearts("wren") >= tuning.integer("creatures.wren_hearts"):
			_step_done("gord", "wren_late")
			g.note_read.emit(_t("crs_wren_late_yes", {"day": next_full_moon_day()}))
		else:
			g.message.emit(_t("crs_wren_late_not_yet"))


## Into the Percolator with Gord on the night: he orders.
func on_enter_room(place: String) -> void:
	var g := s()
	if place != "percolator" or not gord_along or current("gord") != "gord_coffee":
		return
	if not g.town.is_open("percolator"):
		return
	_step_done("gord", "gord_coffee")
	gord_along = false
	g.note_read.emit(_t("crs_gord_coffee_scene"))


## The coat for Gord is stocked once you've met him.
func coat_stocked() -> bool:
	return fact("gord_met") > 0


func on_choice(kind: String, option: String) -> void:
	var g := s()
	match kind:
		"creature:terms":
			terms = option
			_step_done("troll_badgers", "badgers_terms")
			g.message.emit(_t("crs_terms_agreed", {"item": content.item_name(str(_offering().get("item", ""))).to_lower()}))
		"creature:practise":
			_step_done("gord", "gord_practised")
			if option == "0":
				add_points("gord", tuning.integer("creatures.likes_points"))
			g.townsperson_spoke.emit({"name": _t("cr_name_gord_man"), "text": _t("crs_practise_reply_" + option), "hearts": hearts("gord"), "mood": "happy", "person": "gord", "paw": true})
		_:
			if kind.begins_with("creature_choice:"):
				var c := kind.substr(16)
				if option in CHOICES:
					set_choice(c, option)
			elif kind == "creature_change" and option != "":
				var p := option.split(":")
				set_choice(p[0], p[1])


## The ranger sees through the binoculars: a badger caught at it.
func watched(animal: String) -> void:
	if animal == "troll_badger" and current("troll_badgers") == "badgers_watched":
		_step_done("troll_badgers", "badgers_watched")


## Into a building: the bell behind the tower's radio.
func on_enter(structure: String) -> void:
	var g := s()
	if structure == "static_tower" and current("magic_deer") == "bell_found" and not g.backpack.has("old_bell"):
		g.backpack.add("old_bell", 1)
		_step_done("magic_deer", "bell_found")
		g.note_read.emit(_t("crs_bell_found"))
	# The aurora's one thing: the tower radio's tune.
	if structure == "static_tower" and aurora_now():
		if g.wildlife.level_of("place_tower_tune") == "":
			g.wildlife.record("place_tower_tune", "photo", true)
		g.note_read.emit(_t("crs_tower_tune"))


## The station's note board: the magic deer's clue.
func board_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if current("magic_deer") == "deer_clue":
		out.append(_t("crs_bell_note"))
		_step_done("magic_deer", "deer_clue")
	return out


# --- badgers' mischief ---------------------------------------------------------------------

func badger_peace(place: String) -> bool:
	return peace.has(place)


func on_mischief(place: String) -> void:
	mischief[place] = int(mischief.get(place, 0)) + 1
	if deal_place == "" and int(mischief[place]) >= tuning.integer("creatures.mischief_for_job"):
		deal_place = place
	s().jobs.mark_dirty()


func _settle_badgers() -> void:
	var o := _offering()
	var until := -1
	if bool(o.get("one_season", false)):
		var g := s()
		until = today() + (g.clock.days_per_season() - g.clock.day)
	peace[deal_place] = until


# --- settling, and the choice -----------------------------------------------------------------

## A creature job finished: the badge, Lore, and the choice.
func on_job_done(key: String) -> void:
	var g := s()
	for c: String in IDS:
		if str(row(c).get("job", "")) == key:
			g.skills.act("settle_creature")
			if c == "troll_badgers":
				_settle_badgers()
			if c == "jackalopes":
				for t: Vector2i in burrows:
					filled[t] = true
			g.wildlife.refresh_creatures()
			var opts := []
			for ch: String in CHOICES:
				opts.append({"id": ch, "label": _t("cr_choice_" + ch)})
			g.choice_requested.emit("creature_choice:" + c, _t("cr_choice_title", {"name": name_of(c)}), opts)
			return
	if key == "cj_badgers_again":
		var o := _offering()
		for p: String in mischief:
			if int(mischief[p]) >= tuning.integer("creatures.mischief_for_job") and not peace.has(p):
				peace[p] = -1 if not bool(o.get("one_season", false)) else today() + 28


func season_number() -> int:
	return s().clock.year * 4 + s().clock.season


func set_choice(c: String, ch: String) -> void:
	var g := s()
	choice[c] = ch
	choice_turn[c] = season_number()
	g.message.emit(_t("cr_choice_made_" + ch, {"name": name_of(c)}))
	# The Chief's letter: pleased with the money, curious about what's kept.
	g.park.letters.append({"day": g.park.today(), "text": _t("cr_chief_" + ch, {"name": name_of(c)}), "read": false})
	changed.emit()


## The changes the note board can offer now: one step up or down, once a
## season each.
func change_options() -> Array:
	var out := []
	for c: String in IDS:
		if not choice.has(c):
			continue
		if int(choice_turn.get(c, -1)) == season_number():
			continue
		var i := CHOICES.find(str(choice[c]))
		for j in [i - 1, i + 1]:
			if j >= 0 and j < CHOICES.size():
				out.append({"id": "%s:%s" % [c, CHOICES[j]], "label": _t("cr_change", {"name": name_of(c), "from": _t("cr_stamp_" + str(choice[c])), "to": _t("cr_stamp_" + CHOICES[j])})})
	return out


## Creatures visitors hear of: hint or public.
func shown_count(which: String = "") -> int:
	var n := 0
	for c: String in choice:
		if (which == "" and str(choice[c]) != "secret") or str(choice[c]) == which:
			n += 1
	return n


## More visitors for each public creature.
func visitor_mult() -> float:
	return 1.0 + tuning.num("creatures.public_visitor_add") * shown_count("public")


## A public creature is shyer.
func shy_mult(animal: String) -> float:
	for c: String in ANIMAL:
		if str(ANIMAL[c]) == animal and str(choice.get(c, "")) == "public":
			return tuning.num("creatures.public_shy_mult")
	return 1.0


## At one paw heart a creature lets you walk slowly right up to it.
func calm(animal: String) -> bool:
	for c: String in ANIMAL:
		if str(ANIMAL[c]) == animal and hearts(c) >= 1:
			return true
	return false


## The brochure's lines for hint and public creatures.
func brochure_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for c: String in IDS:
		match str(choice.get(c, "")):
			"hint":
				out.append(_t("cr_brochure_hint_" + c))
			"public":
				out.append(_t("cr_brochure_public_" + c))
	return out


# --- job steps ------------------------------------------------------------------------------

## A creature step: {done, n, total}. Done once its fact is counted n times
## (and for a hearts step, once the hearts are there).
func step_check(stp: Dictionary) -> Dictionary:
	var kind := str(stp["kind"])
	if kind == "hearts":
		var c := str(stp["creature"])
		var want := int(stp["n"])
		return {"done": hearts(c) >= want, "n": mini(hearts(c), want), "total": want}
	if kind == "have":
		return {"done": s().backpack.has(str(stp["item"])) or fact(str(stp["fact"])) > 0, "n": 0, "total": 0}
	var f := str(stp.get("fact", ""))
	var want := int(stp.get("n", 1))
	if f == "burrows_filled":
		want = maxi(1, burrows.size())
	if f == "trail":
		want = trail_spots().size() if not trail_spots().is_empty() else want
	var n := fact(f)
	return {"done": n >= want, "n": mini(n, want), "total": want if want > 1 else 0}


## Where a creature step is on the map.
func step_pos(stp: Dictionary) -> Vector2:
	match str(stp.get("at", "")):
		"stone":
			return stone()
		"campground":
			return campground()
		"trail":
			var sp := trail_spots()
			return sp[mini(trail_laid, sp.size() - 1)] if not sp.is_empty() else Vector2.INF
		"jack_meadow":
			return jack_meadow()
		"burrows":
			for t: Vector2i in burrows:
				if not filled.has(t):
					return Vector2(t) + Vector2(0.5, 0.5)
		"yard":
			return yard()
		"hook":
			return hook_spot()
		"tower":
			return s().door_front("static_tower")
		"gord_meadow":
			return gord_meadow()
		"percolator", "station":
			return Vector2.INF
	return Vector2.INF


## Conditions for jobs appearing (creature: atoms).
func cond(arg: String) -> bool:
	var g := s()
	match arg:
		"badger_trouble":
			return deal_place != ""
		"badger_trouble_again":
			for p: String in mischief:
				if p != deal_place and int(mischief[p]) >= tuning.integer("creatures.mischief_for_job") and not peace.has(p):
					return true
			return false
		"jack_trouble":
			return not burrows.is_empty()
		"deer_autumn":
			return (g.clock.season >= 2 or g.clock.year > 1) and g.wildlife.level_of("magic_deer") != ""
		"gord_seen":
			return g.wildlife.level_of("gord_moose") != ""
	return fact(arg) > 0


# --- calendar events --------------------------------------------------------------------------

## A calendar event happens today (by its id).
func _event_today(id: String) -> bool:
	var g := s()
	if not content.has("calendar_events", id):
		return false
	var r := content.row("calendar_events", id)
	if str(r.get("when", "")) == "first_snow":
		var w := g.current_weather()
		return w in ["snow", "blizzard"] and settled("jackalopes") and g.clock.season == 3
	return int(r["season"]) == g.clock.season and int(r["day"]) == g.clock.day


## Events heard of: from Esme within two weeks, from a chat in the season,
## from the guide once a creature is settled.
func _hear_events() -> void:
	var g := s()
	for r: Dictionary in content.rows("calendar_events"):
		var id := str(r["id"])
		if heard.has(id):
			continue
		match str(r.get("heard", "")):
			"always":
				heard[id] = true
			"settled":
				if settled(str(r.get("creature", ""))):
					heard[id] = true


func on_reading() -> void:
	var g := s()
	for r: Dictionary in content.rows("calendar_events"):
		if str(r.get("heard", "")) != "esme" or heard.has(str(r["id"])) or not r.has("season"):
			continue
		var d := int(r["season"]) * g.clock.days_per_season() + int(r["day"]) - 1
		var now := g.clock.season * g.clock.days_per_season() + g.clock.day - 1
		var ahead := posmod(d - now, g.clock.days_per_season() * 4)
		if ahead <= tuning.integer("creatures.esme_hears_days"):
			heard[str(r["id"])] = true


func on_chat(person: String) -> void:
	var g := s()
	for r: Dictionary in content.rows("calendar_events"):
		if str(r.get("heard", "")) == "chat" and int(r.get("season", -1)) == g.clock.season and str(r.get("person", "")) in ["", person]:
			heard[str(r["id"])] = true


## The calendar's events on a day of a season: [ids], heard of only.
func events_on(season: int, day: int) -> Array:
	var out := []
	for r: Dictionary in content.rows("calendar_events"):
		if not heard.has(str(r["id"])):
			continue
		if r.has("season") and int(r["season"]) == season and int(r["day"]) == day:
			out.append(str(r["id"]))
	return out


## The sky card's line on the day before an aurora.
func aurora_tomorrow() -> bool:
	return aurora_on(today() + 1)


# --- saving -------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var bs := []
	for t: Vector2i in burrows:
		bs.append([t.x, t.y])
	var fl := []
	for t: Vector2i in filled:
		fl.append([t.x, t.y])
	return {"points": points, "fed": fed_day, "near": near_day, "bolted": bolted_day, "tastes": tastes, "facts": facts,
		"choice": choice, "choice_turn": choice_turn, "mischief": mischief, "peace": peace, "deal_place": deal_place,
		"terms": terms, "offered": offered_week.keys(), "burrows": bs, "filled": fl, "trail": trail_laid, "trail_day": trail_day,
		"heard": heard, "bell": bell_hung, "five": five_seen, "gift_week": gift_week, "spare_waiting": spare_waiting}


func from_dict(d: Dictionary) -> void:
	points = d.get("points", {})
	fed_day = d.get("fed", {})
	near_day = d.get("near", {})
	bolted_day = d.get("bolted", {})
	tastes = d.get("tastes", {})
	facts = d.get("facts", {})
	choice = d.get("choice", {})
	choice_turn = d.get("choice_turn", {})
	mischief = d.get("mischief", {})
	peace = d.get("peace", {})
	deal_place = str(d.get("deal_place", ""))
	terms = str(d.get("terms", ""))
	offered_week = {}
	for w: Variant in d.get("offered", []):
		offered_week[int(w)] = true
	burrows = []
	for p: Array in d.get("burrows", []):
		burrows.append(Vector2i(int(p[0]), int(p[1])))
	filled = {}
	for p: Array in d.get("filled", []):
		filled[Vector2i(int(p[0]), int(p[1]))] = true
	trail_laid = int(d.get("trail", 0))
	trail_day = int(d.get("trail_day", -1))
	heard = d.get("heard", {})
	bell_hung = bool(d.get("bell", false))
	five_seen = d.get("five", {})
	gift_week = d.get("gift_week", {})
	spare_waiting = bool(d.get("spare_waiting", false))
	gord_along = false
	gord_pos = Vector2.INF
	_day = -1
	_last_minute = -1
	# Saved numbers come back as floats: keep counts whole.
	for k: String in facts.keys():
		facts[k] = int(facts[k])
	for k: String in points.keys():
		points[k] = int(points[k])
	for k: String in mischief.keys():
		mischief[k] = int(mischief[k])
	_said = {}
