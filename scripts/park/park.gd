class_name Park
extends RefCounted
## The park that runs while the ranger is away (phase 3): money, visitors,
## facilities and small placed things, upkeep and mess, troll badgers, staff,
## the suggestion box and the Chief's letters.
##
## Everything here is simulated in game minutes, whether or not the ranger can
## see it. A party of visitors is one record moving along the trail network;
## the park view draws it as characters when the ranger is near, so it keeps
## its place, plans, trash and mood whichever way it is shown. The session
## calls advance_to() every frame and on_new_day() at the turn of each day.

signal changed            # something placed, built, dropped or moved: redraw
signal note(text: String) # a line for the ranger, shown as a message

var tuning: Tuning
var content: ContentDB
var world: WorldData
var clock: GameClock
var money: Money = Money.new()
var net: TrailNet
var gift_shelf: Inventory
var _s: WeakRef

# --- state (all saved) ---------------------------------------------------------
var pads: Dictionary = {}       # pad id -> {state: ordered|kit|building|built, done, clean}
var things: Dictionary = {}     # tile -> {id, trash, lit, tipped}
var litter: Dictionary = {}     # tile -> look (0..2)
var parties: Array = []         # party records, see _new_party
var schedule: Array = []        # today's arrivals still to come: {minute, kind, size, home, nights}
var carry: Array = []           # arrivals turned away by a full park: they come tomorrow
var orders: Array = []          # {cat, pad}: arrives at 6:00
var shelf_waiting: Array = []   # [item, count] that did not fit on the shelf yet
var rent_mode: String = "ranger"
var booked_day: int = -1        # the day whose night the cabin is booked for
var booked_by: String = ""      # who booked it, as shown on the door
var badgers: Array = []         # {place, tile, away_until, nap}
var mess_nights: Dictionary = {}
var diggings: Dictionary = {}   # tile -> ground before the badger dug it
var staff: Array = []           # {person, role, assigned: [keys], off: bool}
var board: Array = []           # person ids looking for work
var cards: Array = []           # {day, text, asks, read, pinned}
var letters: Array = []         # {day, text, read}
var notes: Array = []           # {day, text}
var events: Array = []          # today's happenings: {type, place, n}
var week: Dictionary = {}
var last_week_mood: float = -1.0
var milestones: Dictionary = {}
var lost: Dictionary = {}       # {party, center, place, since}
var sim_day: int = 0
var sim_minute: float = 360.0
var next_id: int = 1
var met_badger: bool = false
var hints_used: Array = []
var morning_lines: PackedStringArray = []
var raid_today: Dictionary = {} # place -> true: a badger will raid a picnic there today

var rng := RandomNumberGenerator.new()
var _junction_tiles: Dictionary = {}
var _junction_version: int = -1
var _speed: float = 0.0


func _init(session: GameSession) -> void:
	_s = weakref(session)
	tuning = session.tuning
	content = session.content
	world = session.world
	clock = session.clock
	var g: Array = world.meta.get("gate", [2, 1442])
	net = TrailNet.new(world, tuning, Vector2i(int(g[0]) + 1, int(g[1])))
	gift_shelf = Inventory.new(content, 12)
	for r: Dictionary in content.rows("items"):
		if r.get("kind", "") == "gift" or r.has("sell"):
			gift_shelf.only[r["id"]] = true


func s() -> GameSession:
	return _s.get_ref()


func today() -> int:
	return clock.absolute_day()


## Visitors' walking speed, in tiles per game minute.
func speed() -> float:
	var per_minute := tuning.num("time.real_seconds_per_step") / tuning.num("time.minutes_per_step")
	return tuning.num("movement.trail_speed_tiles") * per_minute * tuning.num("visitors.speed_share")


func week_day(day: int = -1) -> int:
	if day < 0:
		day = today()
	return posmod(day, tuning.integer("money.week_days")) + 1


# --- starting, saving and loading ---------------------------------------------

func new_game() -> void:
	_clear_footprints()
	money.reset(tuning.integer("money.start"))
	pads = {}
	things = {}
	litter = {}
	parties = []
	schedule = []
	carry = []
	orders = []
	shelf_waiting = []
	rent_mode = "ranger"
	booked_day = -1
	booked_by = ""
	badgers = []
	mess_nights = {}
	_undo_diggings()
	staff = []
	board = []
	cards = []
	letters = []
	notes = []
	events = []
	_reset_week()
	last_week_mood = -1.0
	milestones = {}
	lost = {}
	next_id = 1
	met_badger = false
	hints_used = []
	morning_lines = []
	raid_today = {}
	gift_shelf.clear()
	_apply_footprints()
	net.mark_dirty()
	sim_day = today()
	sim_minute = float(clock.minute)
	_refresh_board()
	_seed_rng()
	_plan_arrivals()
	morning_lines = []
	changed.emit()


func _reset_week() -> void:
	week = {"visitors": 0, "mood_sum": 0.0, "mood_n": 0, "filthy": {}, "badger_nights": 0, "grumbled": false, "dirty_days": 0, "bath_days": 0, "best_card": ""}


func _seed_rng() -> void:
	rng.seed = hash([s().seed_value, today(), "park"])


static func _v2(v: Variant) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))


static func _v2i(v: Variant) -> Vector2i:
	return Vector2i(int(v[0]), int(v[1]))


static func _tkey(t: Vector2i) -> String:
	return "%d,%d" % [t.x, t.y]


static func _tparse(k: String) -> Vector2i:
	var p := k.split(",")
	return Vector2i(int(p[0]), int(p[1]))


func to_dict() -> Dictionary:
	var th := {}
	for t: Vector2i in things:
		th[_tkey(t)] = (things[t] as Dictionary).duplicate()
	var li := {}
	for t: Vector2i in litter:
		li[_tkey(t)] = litter[t]
	var dg := {}
	for t: Vector2i in diggings:
		dg[_tkey(t)] = diggings[t]
	var ps := []
	for p: Dictionary in parties:
		var c := p.duplicate(true)
		c.erase("path")
		c.erase("pi")
		c["pos"] = [p["pos"].x, p["pos"].y]
		c["legs"] = []
		for l: Dictionary in p["legs"]:
			var lc := l.duplicate()
			lc["to"] = [l["to"].x, l["to"].y]
			c["legs"].append(lc)
		c["rested"] = (p["rested"] as Dictionary).keys()
		c["seen"] = (p["seen"] as Dictionary).keys()
		ps.append(c)
	var bd := []
	for b: Dictionary in badgers:
		var c := b.duplicate()
		c["tile"] = [b["tile"].x, b["tile"].y]
		bd.append(c)
	var lo := {}
	if not lost.is_empty():
		lo = lost.duplicate()
		lo["center"] = [lost["center"].x, lost["center"].y]
	return {
		"money": money.to_dict(),
		"pads": pads.duplicate(true),
		"things": th,
		"litter": li,
		"parties": ps,
		"schedule": schedule.duplicate(true),
		"carry": carry.duplicate(true),
		"orders": orders.duplicate(true),
		"shelf_waiting": shelf_waiting.duplicate(true),
		"rent_mode": rent_mode,
		"booked_day": booked_day,
		"booked_by": booked_by,
		"badgers": bd,
		"mess_nights": mess_nights.duplicate(),
		"diggings": dg,
		"staff": staff.duplicate(true),
		"board": board.duplicate(),
		"cards": cards.duplicate(true),
		"letters": letters.duplicate(true),
		"notes": notes.duplicate(true),
		"events": events.duplicate(true),
		"week": week.duplicate(true),
		"last_week_mood": last_week_mood,
		"milestones": milestones.keys(),
		"lost": lo,
		"sim_day": sim_day,
		"sim_minute": sim_minute,
		"next_id": next_id,
		"met_badger": met_badger,
		"hints_used": hints_used.duplicate(),
		"raid_today": raid_today.keys(),
		"gift_shelf": gift_shelf.to_array(),
	}


## Loads the park. A save from before phase 3 has none: it starts with the
## starting money and an empty park, on the day it was saved.
func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		new_game()
		return
	_clear_footprints()
	_undo_diggings()
	money.from_dict(d.get("money", {}))
	pads = {}
	for id: String in d.get("pads", {}):
		var p: Dictionary = d["pads"][id]
		pads[id] = {"state": str(p["state"]), "done": int(p.get("done", 0)), "clean": float(p.get("clean", 100.0))}
	things = {}
	for k: String in d.get("things", {}):
		var th: Dictionary = d["things"][k]
		things[_tparse(k)] = {"id": str(th["id"]), "trash": int(th.get("trash", 0)), "lit": int(th.get("lit", 0)), "tipped": bool(th.get("tipped", false))}
	litter = {}
	for k: String in d.get("litter", {}):
		litter[_tparse(k)] = int(d["litter"][k])
	parties = []
	for c: Dictionary in d.get("parties", []):
		var p := c.duplicate(true)
		p["pos"] = _v2(c["pos"])
		var legs := []
		for l: Dictionary in c["legs"]:
			var lc := l.duplicate()
			lc["to"] = _v2i(l["to"])
			legs.append(lc)
		p["legs"] = legs
		var rested := {}
		for k: Variant in c.get("rested", []):
			rested[str(k)] = true
		p["rested"] = rested
		var seen := {}
		for k: Variant in c.get("seen", []):
			seen[str(k)] = true
		p["seen"] = seen
		for k: String in ["id", "size", "leg", "mood", "trash", "nights", "guide", "picked"]:
			p[k] = int(p.get(k, 0))
		p["wait"] = float(p.get("wait", 0.0))
		p["path"] = PackedVector2Array()
		p["pi"] = 0
		parties.append(p)
	schedule = _ints(d.get("schedule", []), ["minute", "size", "nights"])
	carry = _ints(d.get("carry", []), ["minute", "size", "nights"])
	orders = (d.get("orders", []) as Array).duplicate(true)
	shelf_waiting = []
	for w: Array in d.get("shelf_waiting", []):
		shelf_waiting.append([str(w[0]), int(w[1])])
	rent_mode = str(d.get("rent_mode", "ranger"))
	booked_day = int(d.get("booked_day", -1))
	booked_by = str(d.get("booked_by", ""))
	badgers = []
	for c: Dictionary in d.get("badgers", []):
		var b := c.duplicate()
		b["tile"] = _v2i(c["tile"])
		b["away_until"] = int(c.get("away_until", -1))
		badgers.append(b)
	mess_nights = {}
	for k: String in d.get("mess_nights", {}):
		mess_nights[k] = int(d["mess_nights"][k])
	diggings = {}
	for k: String in d.get("diggings", {}):
		var t := _tparse(k)
		diggings[t] = str(d["diggings"][k])
		world.set_ground(t, "dug_earth")
	staff = _ints(d.get("staff", []), ["from"])
	board = (d.get("board", []) as Array).duplicate()
	cards = _ints(d.get("cards", []), ["day"])
	letters = _ints(d.get("letters", []), ["day"])
	notes = _ints(d.get("notes", []), ["day"])
	events = _ints(d.get("events", []), ["n"])
	_reset_week()
	var w: Dictionary = d.get("week", {})
	for k: String in w:
		week[k] = w[k]
	for k: String in ["visitors", "mood_n", "badger_nights", "dirty_days", "bath_days"]:
		week[k] = int(week[k])
	week["mood_sum"] = float(week["mood_sum"])
	var fl := {}
	for k: String in week["filthy"]:
		fl[k] = int(week["filthy"][k])
	week["filthy"] = fl
	last_week_mood = float(d.get("last_week_mood", -1.0))
	milestones = {}
	for k: Variant in d.get("milestones", []):
		milestones[str(k)] = true
	lost = {}
	var lo: Dictionary = d.get("lost", {})
	if not lo.is_empty():
		lost = lo.duplicate()
		lost["center"] = _v2(lo["center"])
		lost["party"] = int(lo["party"])
	sim_day = int(d.get("sim_day", today()))
	sim_minute = float(d.get("sim_minute", clock.minute))
	next_id = int(d.get("next_id", 1))
	met_badger = bool(d.get("met_badger", false))
	hints_used = (d.get("hints_used", []) as Array).duplicate()
	for p: Dictionary in parties:
		p["arrived"] = int(p.get("arrived", 0))
		p["look"] = int(p.get("look", 0))
	raid_today = {}
	for k: Variant in d.get("raid_today", []):
		raid_today[str(k)] = true
	gift_shelf.from_array(d.get("gift_shelf", []))
	morning_lines = []
	_apply_footprints()
	net.mark_dirty()
	_seed_rng()
	for p: Dictionary in parties:
		_replan_path(p)
	changed.emit()


## A copy of a list of records with the named fields made whole numbers again
## (a save file stores every number the same way).
static func _ints(rows: Variant, keys: Array) -> Array:
	var out := []
	for r: Dictionary in rows:
		var c := r.duplicate(true)
		for k: String in keys:
			if c.has(k):
				c[k] = int(c[k])
		out.append(c)
	return out


# --- places: the gate and the sites ----------------------------------------------

func sites() -> Array:
	return content.rows("sites")


func place_ids() -> Array:
	var out := ["gate"]
	for r: Dictionary in sites():
		out.append(r["id"])
	return out


func place_name(place: String) -> String:
	if place == "gate":
		return content.text("place_gate")
	if content.has("sites", place):
		return content.text(content.row("sites", place)["name"])
	return place


## Where a place is, in tiles.
func place_spot(place: String) -> Vector2:
	if place == "gate":
		return Vector2(net.start) + Vector2(0.5, 0.5)
	var r := content.row("sites", place)
	if str(r["structure"]) != "":
		return s().door_front(r["structure"])
	return _v2(r["spot"]) + Vector2(0.5, 0.5)


## The trail tile visitors stand on to visit a place, or (-1, -1).
func place_node(place: String) -> Vector2i:
	if place == "gate":
		return net.nearest(place_spot("gate"), 4.0)
	return net.nearest(place_spot(place), tuning.num("visitors.site_reach_tiles"))


func site_ready(place: String) -> bool:
	if place == "gate":
		return true
	return s().site_ready(place)


func gate_node() -> Vector2i:
	return place_node("gate")


# --- pads and facilities -----------------------------------------------------------

func pad_rows() -> Array:
	return content.rows("pads") + content.rows("spoiler_pads")


func pad_row(id: String) -> Dictionary:
	if content.has("pads", id):
		return content.row("pads", id)
	return content.row("spoiler_pads", id)


func fac_row(pad_id: String) -> Dictionary:
	return content.row("facilities", pad_row(pad_id)["facility"])


## Pads show once their site is ready; the lookout's once its tower is open.
func pad_shown(pad_id: String) -> bool:
	var r := pad_row(pad_id)
	if not site_ready(r["site"]):
		return false
	var need := str(fac_row(pad_id).get("needs_open", ""))
	return need == "" or s().structures.is_open(need)


func pad_state(pad_id: String) -> String:
	if bool(pad_row(pad_id).get("built", false)):
		return "built"
	return str((pads.get(pad_id, {}) as Dictionary).get("state", ""))


func built(pad_id: String) -> bool:
	return pad_state(pad_id) == "built"


func pad_rect(pad_id: String) -> Rect2i:
	var r := pad_row(pad_id)
	return Rect2i(_v2i(r["pos"]), _v2i(r["size"]))


func pad_center(pad_id: String) -> Vector2:
	var rc := pad_rect(pad_id)
	return Vector2(rc.position) + Vector2(rc.size) / 2.0


## The trail tile beside a facility that visitors use it from.
func pad_node(pad_id: String) -> Vector2i:
	var r := pad_row(pad_id)
	if str(r["facility"]) == "tower_lookout":
		return place_node(r["site"])
	var rc := pad_rect(pad_id)
	var half := maxf(rc.size.x, rc.size.y) / 2.0
	return net.nearest(pad_center(pad_id), half + tuning.num("visitors.facility_reach_tiles"))


func built_pads(facility: String, place: String = "") -> Array:
	var out := []
	for r: Dictionary in pad_rows():
		if r["facility"] == facility and (place == "" or r["site"] == place) and built(r["id"]):
			out.append(r["id"])
	return out


func _pad_tiles(pad_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rc := pad_rect(pad_id)
	for y in range(rc.position.y, rc.end.y):
		for x in range(rc.position.x, rc.end.x):
			out.append(Vector2i(x, y))
	return out


func _footprint(pad_id: String, on: bool) -> void:
	var f := fac_row(pad_id)
	if str(f.get("lays", "")) != "":
		for t in _pad_tiles(pad_id):
			if world.baked_ground_at(t) in ["shallows", "deep_water"]:
				world.set_ground(t, f["lays"] if on else "")
				s().land_changed.emit(t)
	elif bool(f.get("solid", false)):
		for t in _pad_tiles(pad_id):
			world.set_blocked(t, on)
		s()._reach_cache.clear()


func _apply_footprints() -> void:
	for r: Dictionary in pad_rows():
		if built(r["id"]):
			_footprint(r["id"], true)
	for t: Vector2i in things:
		if bool(_thing_row(things[t]["id"]).get("solid", false)):
			world.set_blocked(t, true)


func _clear_footprints() -> void:
	for r: Dictionary in pad_rows():
		if built(r["id"]):
			_footprint(r["id"], false)
	for t: Vector2i in things:
		world.set_blocked(t, false)


func _undo_diggings() -> void:
	for t: Vector2i in diggings:
		world.set_ground(t, diggings[t])
	diggings = {}


## Takes the next hammer action on a kit at a pad. Returns {ok, done, total, built}.
func build_action(pad_id: String) -> Dictionary:
	var st := pad_state(pad_id)
	if st != "kit" and st != "building":
		return {"ok": false}
	var p: Dictionary = pads[pad_id]
	p["state"] = "building"
	p["done"] = int(p["done"]) + 1
	var total := int(fac_row(pad_id)["actions"])
	var finished := int(p["done"]) >= total
	if finished:
		p["state"] = "built"
		p["clean"] = 100.0
		_footprint(pad_id, true)
		net.mark_dirty()
	changed.emit()
	return {"ok": true, "done": int(p["done"]), "total": total, "built": finished}


func take_down(pad_id: String) -> int:
	if not built(pad_id) or bool(pad_row(pad_id).get("built", false)):
		return 0
	_footprint(pad_id, false)
	pads.erase(pad_id)
	for b: Dictionary in badgers:
		if str(b.get("nap", "")) == pad_id:
			b["nap"] = ""
	var refund := roundi(int(fac_row(pad_id)["price"]) * tuning.num("facilities.refund_share"))
	money.earn(today(), "refund", refund)
	net.mark_dirty()
	changed.emit()
	return refund


func refund_for(pad_id: String) -> int:
	return roundi(int(fac_row(pad_id)["price"]) * tuning.num("facilities.refund_share"))


# --- the catalog ----------------------------------------------------------------------

## What can be ordered now: [{id, cat, pad, label, price, enabled}].
func catalog_options() -> Array:
	var out := ordered_lines()
	var jb: Jobs = s().jobs
	for r: Dictionary in content.rows("catalog"):
		var price := int(r["price"])
		# Some lines wait for a job's reward: benches, picnic tables.
		if str(r.get("unlock", "")) != "" and not jb.unlocks.has(str(r["unlock"]).trim_prefix("catalog_")) and not jb.unlocks.has(str(r["unlock"])):
			continue
		if r["kind"] == "kit":
			for pr: Dictionary in pad_rows():
				if pr["facility"] != r["facility"] or not pad_shown(pr["id"]) or pad_state(pr["id"]) != "":
					continue
				out.append({"id": r["id"] + "@" + str(pr["id"]), "cat": r["id"], "pad": pr["id"], "price": price,
					"label": content.text("ui_catalog_kit_line", {"name": content.text(r["name"]), "place": place_name(pr["site"]), "price": price}),
					"enabled": money.can_afford(price)})
		else:
			out.append({"id": r["id"], "cat": r["id"], "pad": "", "price": price,
				"label": content.text("ui_catalog_line", {"name": content.text(r["name"]), "price": price}),
				"enabled": money.can_afford(price)})
	return out


## What's already ordered, shown greyed at the top of the catalog: today's
## orders (here at 6:00) and anything still waiting for room on the shelf.
func ordered_lines() -> Array:
	var out := []
	var n := 0
	for o: Dictionary in orders:
		var r := content.row("catalog", o["cat"])
		var name := content.text(r["name"])
		if str(o.get("pad", "")) != "":
			name = content.text("ui_catalog_kit_for", {"name": name, "place": place_name(str(pad_row(o["pad"]).get("site", "")))})
		out.append({"id": "ordered:%d" % n, "label": content.text("ui_catalog_ordered", {"name": name}), "enabled": false})
		n += 1
	for w: Array in shelf_waiting:
		out.append({"id": "ordered:%d" % n, "label": content.text("ui_catalog_waiting", {"name": content.item_name(str(w[0])), "count": int(w[1])}), "enabled": false})
		n += 1
	return out


## Orders one catalog line ("id" or "kit_id@pad"). Returns "" or the text id why not.
func order(option_id: String) -> String:
	var parts := option_id.split("@")
	var cat_id := parts[0]
	if not content.has("catalog", cat_id):
		return "msg_cant_afford"
	var r := content.row("catalog", cat_id)
	var pad := parts[1] if parts.size() > 1 else ""
	if r["kind"] == "kit" and (pad == "" or not content.has("facilities", r["facility"]) or (pad_rows().filter(func(x: Dictionary) -> bool: return x["id"] == pad and x["facility"] == r["facility"])).is_empty() or pad_state(pad) != "" or not pad_shown(pad)):
		return "msg_pad_ordered"
	if not money.spend(today(), "catalog", int(r["price"])):
		return "msg_cant_afford"
	orders.append({"cat": cat_id, "pad": pad})
	if pad != "":
		pads[pad] = {"state": "ordered", "done": 0, "clean": 100.0}
	changed.emit()
	return ""


func _deliver() -> void:
	var shelf: Inventory = s().structures.shelves["ranger_station"]
	var got_supply := false
	var got_kit := false
	var waiting := shelf_waiting.duplicate(true)
	shelf_waiting = []
	for o: Dictionary in orders:
		var r := content.row("catalog", o["cat"])
		if r["kind"] == "kit":
			pads[o["pad"]] = {"state": "kit", "done": 0, "clean": 100.0}
			got_kit = true
		else:
			waiting.append([r["item"], int(r["count"])])
	orders = []
	for w: Array in waiting:
		var left := shelf.add(str(w[0]), int(w[1]))
		if left < int(w[1]):
			got_supply = true
		if left > 0:
			shelf_waiting.append([w[0], left])
	if got_supply:
		morning_lines.append(content.text("msg_order_arrived"))
	if got_kit:
		morning_lines.append(content.text("msg_kit_arrived"))
	if got_kit:
		changed.emit()


# --- small placed things ------------------------------------------------------------

func _thing_row(id: String) -> Dictionary:
	return content.row("placeables", id)


func thing_for_item(item: String) -> String:
	for r: Dictionary in content.rows("placeables"):
		if r["item"] == item:
			return r["id"]
	return ""


## "" if a small thing can go on tile t, or the text id saying why not.
func place_problem(t: Vector2i) -> String:
	if not world.in_bounds(t) or world.is_solid(t) or things.has(t) or litter.has(t):
		return "msg_place_bad_spot"
	if world.object_at(t) != "" and not s().cleared.has(t) and not s().chopped.has(t):
		return "msg_place_bad_spot"
	if s().placed.has(t) or diggings.has(t):
		return "msg_place_bad_spot"
	var g := world.ground_at(t)
	if g in ["trail", "boards", "shallows", "deep_water", "rock", "dug_earth"]:
		return "msg_place_bad_spot"
	for r: Dictionary in pad_rows():
		if pad_rect(r["id"]).grow(0).has_point(t) and pad_shown(r["id"]):
			return "msg_place_bad_spot"
	if not s().map.is_revealed(t):
		return "msg_place_thing_unseen"
	if not _near_trail(t, tuning.integer("placement.trail_distance_tiles")):
		return "msg_place_thing_far"
	return ""


func _near_trail(t: Vector2i, r: int) -> bool:
	var grounds: Array = tuning.value("visitors.walk_grounds")
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if grounds.has(world.ground_at(t + Vector2i(dx, dy))):
				return true
	return false


func put_thing(t: Vector2i, id: String) -> bool:
	if place_problem(t) != "":
		return false
	things[t] = {"id": id, "trash": 0, "lit": 0, "tipped": false}
	if bool(_thing_row(id).get("solid", false)):
		world.set_blocked(t, true)
	changed.emit()
	return true


func pick_up_thing(t: Vector2i) -> String:
	if not things.has(t):
		return ""
	var id: String = things[t]["id"]
	things.erase(t)
	world.set_blocked(t, false)
	for st: Dictionary in staff:
		(st["assigned"] as Array).erase("can:" + _tkey(t))
	changed.emit()
	return id


func things_with(effect: String) -> Array:
	var out := []
	for t: Vector2i in things:
		if _thing_row(things[t]["id"])["effect"] == effect:
			out.append(t)
	return out


func fire_ring_lit_near(p: Vector2, r: float) -> bool:
	for t: Vector2i in things_with("fire"):
		if int(things[t]["lit"]) > 0 and (Vector2(t) + Vector2(0.5, 0.5)).distance_to(p) <= r:
			return true
	return false


# --- mess ---------------------------------------------------------------------------

func _in_area(place: String, p: Vector2) -> bool:
	return place_spot(place).distance_to(p) <= tuning.num("upkeep.mess_area_tiles")


## Which place a tile belongs to, for mess and badgers: the nearest within its area.
func place_of(p: Vector2) -> String:
	var best := ""
	var best_d := tuning.num("upkeep.mess_area_tiles")
	for place: String in place_ids():
		if place != "gate" and not site_ready(place):
			continue
		var d := place_spot(place).distance_to(p)
		if d <= best_d:
			best_d = d
			best = place
	return best


func bath_state(pad_id: String) -> String:
	var c := float((pads.get(pad_id, {}) as Dictionary).get("clean", 100.0))
	if c < tuning.num("upkeep.filthy_below"):
		return "filthy"
	if c < tuning.num("upkeep.grubby_below"):
		return "grubby"
	if c >= 95.0:
		return "spotless"
	return "clean"


## How messy a place is, from 0 to 1: litter about, grubby or filthy
## bathrooms, and full or tipped trash cans.
func mess(place: String) -> float:
	var m := 0.0
	for t: Vector2i in litter:
		if place_of(Vector2(t)) == place:
			m += tuning.num("upkeep.mess_per_litter")
	for pad: String in built_pads("bathroom", place):
		var st := bath_state(pad)
		if st == "filthy":
			m += tuning.num("upkeep.mess_filthy")
		elif st == "grubby":
			m += tuning.num("upkeep.mess_grubby")
	for t: Vector2i in things_with("trash"):
		if place_of(Vector2(t)) == place and (int(things[t]["trash"]) >= tuning.integer("upkeep.can_capacity") or bool(things[t]["tipped"])):
			m += tuning.num("upkeep.mess_full_can")
	return clampf(m, 0.0, 1.0)


func messy(place: String) -> bool:
	return mess(place) >= tuning.num("upkeep.messy_at")


# --- appeal, reach and arrivals ----------------------------------------------------

func dusk_minute() -> int:
	var sun: Array = tuning.value("light.sun." + clock.season_name())
	return int(sun[1])


func deadline() -> float:
	return float(mini(tuning.integer("visitors.latest_return"), dusk_minute()))


func travel(a: Vector2i, b: Vector2i) -> float:
	return net.minutes(a, b, speed())


func dwell(act: String) -> float:
	return float((tuning.value("visitors.dwell_minutes") as Dictionary).get(act, 30))


## Whether a party starting at `from` at minute t0 can visit a place and be
## back by the deadline.
func in_reach(from: Vector2i, place: String, t0: float, act: String = "visit") -> bool:
	var n := place_node(place)
	if n.x < 0 or from.x < 0:
		return false
	var go := travel(from, n)
	if go == INF:
		return false
	return t0 + go * 2.0 + dwell(act) <= deadline()


## The sites a party could visit from a starting tile at minute t0.
func sites_in_reach(from: Vector2i, t0: float) -> Array:
	var out := []
	for r: Dictionary in sites():
		var id: String = r["id"]
		if site_ready(id) and in_reach(from, id, t0):
			out.append(id)
	return out


## Where campers can stay: built campgrounds visitors can walk to, and the
## cabin when it is booked. {home key -> trail tile}
func camp_homes() -> Dictionary:
	var out := {}
	var g := gate_node()
	for pad: String in built_pads("campground"):
		var n := pad_node(pad)
		if n.x >= 0 and travel(g, n) != INF:
			out[pad] = n
	return out


func cabin_node() -> Vector2i:
	return net.nearest(s().door_front("test_cabin"), 4.0)


## The sites some party could visit: in a day's reach of the gate, or of a
## campground or the cabin for rent.
func visitable_sites() -> Array:
	var g := gate_node()
	if g.x < 0:
		return []
	var start := tuning.num("visitors.arrive_from")
	var found := {}
	for id: String in sites_in_reach(g, start):
		found[id] = true
	var homes := camp_homes()
	if rent_mode == "rent" and s().structures.is_open("test_cabin"):
		homes["cabin"] = cabin_node()
	for h: String in homes:
		for id: String in sites_in_reach(homes[h], tuning.num("visitors.camp_day_start")):
			found[id] = true
	return found.keys()


func facility_appeal(place: String) -> float:
	var a := 0.0
	for r: Dictionary in pad_rows():
		if r["site"] == place and built(r["id"]):
			a += float(fac_row(r["id"])["appeal"])
	return a


func site_appeal(place: String) -> float:
	var a := 1.0 + facility_appeal(place) + facility_appeal("gate") / 4.0
	a -= mess(place) * tuning.num("upkeep.mess_appeal")
	return maxf(0.2, a)


## How many visitors to expect today, before rounding.
func expected_visitors() -> float:
	var vs := visitable_sites()
	if vs.is_empty():
		return 0.0
	var appeal := 0.0
	for id: String in vs:
		appeal += site_appeal(id)
	var n := tuning.num("visitors.base_per_site") * appeal
	n *= float((tuning.value("visitors.season") as Dictionary)[clock.season_name()])
	if (tuning.value("visitors.busy_days") as Array).has(week_day()):
		n *= tuning.num("visitors.busy_multiplier")
	n *= float((tuning.value("visitors.weather_multiplier") as Dictionary).get(s().weather.today[0], 1.0))
	if last_week_mood >= 0.0:
		n *= 1.0 + (last_week_mood - 0.5) * tuning.num("visitors.mood_effect")
	# Phase 4b: festival weekends bring twice the visitors, the week before more.
	if s().festivals != null:
		n *= s().festivals.visitor_mult()
	return n


## The latest a day party can arrive and still reach some site and get back.
func latest_day_start() -> int:
	var lo := tuning.integer("visitors.arrive_from")
	var hi := tuning.integer("visitors.arrive_until")
	var g := gate_node()
	var best := lo
	for r: Dictionary in sites():
		var n := place_node(r["id"])
		if not site_ready(r["id"]) or n.x < 0:
			continue
		var t := travel(g, n)
		if t == INF:
			continue
		best = maxi(best, floori(deadline() - t * 2.0 - dwell("visit")))
	return clampi(best, lo, hi)


## Which kinds of party the park can host today.
func eligible_kinds() -> Array:
	var g := gate_node()
	var start := tuning.num("visitors.arrive_from")
	var out := []
	var hike := not sites_in_reach(g, start).is_empty()
	var camps := not camp_homes().is_empty()
	for r: Dictionary in content.rows("visitor_types"):
		var ok := false
		match str(r.get("needs", "")):
			"":
				ok = hike
			"picnic":
				ok = not picnic_places(g, start).is_empty()
			"camp", "campground":
				ok = camps
			"dock":
				ok = not dock_pads(g, start).is_empty()
			"tour":
				ok = sites_in_reach(g, start).size() >= 2
			"creature_hint":
				ok = hike and s().creatures.shown_count() > 0
		if ok and r.has("most_at_once"):
			var n := 0
			for p: Dictionary in parties:
				if p["kind"] == r["id"]:
					n += 1
			ok = n < int(r["most_at_once"])
		if ok:
			out.append(r["id"])
	return out


func picnic_places(from: Vector2i, t0: float) -> Array:
	var out := []
	for place: String in place_ids():
		if not site_ready(place):
			continue
		var has := not built_pads("picnic_area", place).is_empty()
		if not has:
			for t: Vector2i in things_with("picnic"):
				if _in_area(place, Vector2(t)) and place_spot(place).distance_to(Vector2(t)) <= tuning.num("visitors.site_reach_tiles") * 2.0:
					has = true
					break
		if has and (place == "gate" or in_reach(from, place, t0, "picnic")):
			out.append(place)
	return out


func dock_pads(from: Vector2i, t0: float) -> Array:
	var out := []
	for pad: String in built_pads("dock"):
		var n := pad_node(pad)
		if n.x >= 0 and from.x >= 0 and travel(from, n) != INF and t0 + travel(from, n) * 2.0 + dwell("fish") <= deadline():
			out.append(pad)
	return out


func visitors_in_park() -> int:
	var n := 0
	for p: Dictionary in parties:
		if p["state"] != "done":
			n += int(p["size"])
	return n


## Works out today's arrivals: how many, then which parties, each with a time.
func _plan_arrivals() -> void:
	schedule = []
	var latest := latest_day_start()
	for a: Dictionary in carry:
		a["minute"] = rng.randi_range(tuning.integer("visitors.arrive_from"), latest)
		schedule.append(a)
	carry = []
	var e := expected_visitors()
	var n := floori(e)
	if rng.randf() < e - n:
		n += 1
	var kinds := eligible_kinds()
	if kinds.is_empty():
		return
	var per_day := {}
	while n > 0:
		var choices := []
		var total := 0.0
		for k: String in kinds:
			var r := content.row("visitor_types", k)
			if int(r["party"][0]) > n:
				continue
			if r.has("most_per_day") and int(per_day.get(k, 0)) >= int(r["most_per_day"]):
				continue
			choices.append(k)
			total += float(r["weight"])
		if choices.is_empty():
			break
		var pick := rng.randf() * total
		var kind: String = choices[-1]
		for k: String in choices:
			pick -= float(content.row("visitor_types", k)["weight"])
			if pick <= 0.0:
				kind = k
				break
		var r := content.row("visitor_types", kind)
		var size := mini(rng.randi_range(int(r["party"][0]), int(r["party"][1])), n)
		if bool(r.get("leader", false)):
			size = mini(size + 1, n)
		n -= size
		per_day[kind] = int(per_day.get(kind, 0)) + 1
		var nights := rng.randi_range(int(r["nights"][0]), int(r["nights"][1]))
		var home := ""
		if nights > 0:
			var homes := camp_homes().keys()
			if homes.is_empty():
				n += size
				kinds.erase(kind)
				continue
			home = homes[rng.randi() % homes.size()]
		schedule.append({"minute": rng.randi_range(tuning.integer("visitors.arrive_from"), latest), "kind": kind, "size": size, "home": home, "nights": nights})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["minute"]) < int(b["minute"]))


# --- parties ----------------------------------------------------------------------------

## Makes a party at the gate and charges its fees.
func spawn(kind: String, size: int, home: String = "", nights: int = 0) -> Dictionary:
	var g := gate_node()
	if g.x < 0:
		return {}
	var r := content.row("visitor_types", kind)
	var p := {
		"id": next_id, "kind": kind, "size": size, "home": home, "nights": nights,
		"guide": 1 if bool(r.get("guide", false)) else 0,
		"pos": Vector2(g) + Vector2(0.5, 0.5), "legs": [], "leg": 0,
		"path": PackedVector2Array(), "pi": 0, "state": "walk", "wait": 0.0,
		"mood": 0, "trash": 0, "rested": {}, "seen": {}, "dest": "", "picked": 0,
		"look": rng.randi(), "arrived": today(), "lost": false,
	}
	next_id += 1
	parties.append(p)
	# Fees at the kiosk.
	var day := sim_day
	money.earn(day, "entrance", _price("entrance") * size)
	var gear := 0
	var maps := 0
	var mapped := 0
	for sr: Dictionary in sites():
		if s().map.is_landmark_mapped(sr["landmark"]):
			mapped += 1
	for i in size:
		if rng.randf() < tuning.num("visitors.gear_rent_share"):
			gear += 1
		if mapped >= tuning.integer("visitors.map_sites_needed") and rng.randf() < tuning.num("visitors.map_buy_share"):
			maps += 1
	money.earn(day, "gear", _price("gear") * gear)
	money.earn(day, "park_map", _price("park_map") * maps)
	if str(r["plan"]) == "tour":
		money.earn(day, "tour", _price("tour") * size)
	week["visitors"] = int(week["visitors"]) + size
	_milestone("first_visitors")
	if nights > 0:
		_milestone("first_campers")
	_plan_first_day(p)
	_use_bathrooms(p, "gate")
	return p


func _price(source: String) -> int:
	return int(content.row("income_sources", source)["price"])


func party_name(p: Dictionary) -> String:
	return content.text("party_of", {"n": int(p["size"]), "kind": content.text(content.row("visitor_types", p["kind"])["name"])})


func party(id: int) -> Dictionary:
	for p: Dictionary in parties:
		if int(p["id"]) == id:
			return p
	return {}


func _home_node(p: Dictionary) -> Vector2i:
	var h := str(p["home"])
	if h == "":
		return gate_node()
	if h == "cabin":
		return cabin_node()
	return pad_node(h)


func _leg(to: Vector2i, act: String, ref: String = "") -> Dictionary:
	return {"to": to, "act": act, "ref": ref}


func _choose(options: Array) -> String:
	if options.is_empty():
		return ""
	var total := 0.0
	for o: String in options:
		total += site_appeal(o)
	var pick := rng.randf() * total
	for o: String in options:
		pick -= site_appeal(o)
		if pick <= 0.0:
			return o
	return options[-1]


## The first day's plan, made at the gate.
func _plan_first_day(p: Dictionary) -> void:
	var r := content.row("visitor_types", p["kind"])
	var g := gate_node()
	var now := sim_minute
	var legs := []
	match str(r["plan"]):
		"hike":
			var site := _choose(sites_in_reach(g, now))
			if site != "":
				legs.append(_leg(place_node(site), "visit", site))
				if not built_pads("tower_lookout", site).is_empty():
					legs.append(_leg(place_node(site), "lookout", site))
				p["dest"] = site
		"picnic":
			var opts := picnic_places(g, now)
			var place: String = opts[rng.randi() % opts.size()] if not opts.is_empty() else ""
			if place != "":
				if place != "gate":
					legs.append(_leg(place_node(place), "visit", place))
				legs.append(_leg(place_node(place), "picnic", place))
				p["dest"] = place
		"fish":
			var docks := dock_pads(g, now)
			if not docks.is_empty():
				var pad: String = docks[rng.randi() % docks.size()]
				legs.append(_leg(pad_node(pad), "fish", pad))
				p["dest"] = pad_row(pad)["site"]
		"tour":
			var at := g
			var t := now
			var left := sites_in_reach(g, now)
			while not left.is_empty():
				var best := ""
				var best_t := INF
				for site: String in left:
					var tt := travel(at, place_node(site))
					if tt < best_t:
						best_t = tt
						best = site
				left.erase(best)
				var n := place_node(best)
				if t + best_t + dwell("visit") + travel(n, g) > deadline():
					continue
				legs.append(_leg(n, "visit", best))
				t += best_t + dwell("visit")
				at = n
				if p["dest"] == "":
					p["dest"] = best
		"camp":
			var home := _home_node(p)
			legs.append(_leg(home, "pitch", str(p["home"])))
			var arrive := now + travel(g, home) + dwell("pitch")
			var site := _choose(sites_in_reach(home, arrive))
			if site != "":
				legs.append(_leg(place_node(site), "visit", site))
				p["dest"] = site
			legs.append(_leg(home, "camp", str(p["home"])))
			p["legs"] = legs
			p["leg"] = 0
			_start_leg(p)
			return
	legs.append(_leg(g, "home"))
	p["legs"] = legs
	p["leg"] = 0
	_start_leg(p)


## A camping party's plan for a morning at camp.
func _plan_camp_day(p: Dictionary) -> void:
	var home := _home_node(p)
	var start := tuning.num("visitors.cabin_day_start" if p["home"] == "cabin" else "visitors.camp_day_start")
	var legs := [_leg(home, "wake")]
	var site := _choose(sites_in_reach(home, start))
	if site != "":
		legs.append(_leg(place_node(site), "visit", site))
		p["dest"] = site
	if int(p["nights"]) > 0:
		legs.append(_leg(home, "camp", str(p["home"])))
	else:
		legs.append(_leg(gate_node(), "home"))
	p["legs"] = legs
	p["leg"] = 0
	p["rested"] = {}
	p["pos"] = Vector2(home) + Vector2(0.5, 0.5)
	p["state"] = "dwell"
	p["wait"] = maxf(0.0, start - sim_minute)
	p["path"] = PackedVector2Array()


func _cur_tile(p: Dictionary) -> Vector2i:
	var pos: Vector2 = p["pos"]
	var t := Vector2i(floori(pos.x), floori(pos.y))
	if net.has(t):
		return t
	return net.nearest(pos, 6.0)


func _start_leg(p: Dictionary) -> void:
	var legs: Array = p["legs"]
	while int(p["leg"]) < legs.size():
		var l: Dictionary = legs[int(p["leg"])]
		var from := _cur_tile(p)
		var path: PackedVector2Array = net.path(from, l["to"]) if from.x >= 0 else PackedVector2Array()
		if path.is_empty() and from != l["to"]:
			# Out of reach now (a trail was broken): head straight home instead.
			if l["act"] != "home" and l["act"] != "camp":
				p["leg"] = int(p["leg"]) + 1
				continue
			p["state"] = "done"
			return
		p["path"] = path
		p["pi"] = 0
		p["state"] = "walk"
		return
	p["state"] = "done"


func _replan_path(p: Dictionary) -> void:
	if p["state"] != "walk":
		return
	var legs: Array = p["legs"]
	if int(p["leg"]) >= legs.size():
		p["state"] = "done"
		return
	var from := _cur_tile(p)
	var path: PackedVector2Array = net.path(from, legs[int(p["leg"])]["to"]) if from.x >= 0 else PackedVector2Array()
	p["path"] = path
	p["pi"] = 0
	if path.is_empty():
		_start_leg(p)


func _next_leg(p: Dictionary) -> void:
	p["leg"] = int(p["leg"]) + 1
	_start_leg(p)


# --- the simulation ------------------------------------------------------------------

## Runs the park up to a minute of today.
func advance_to(minute: float) -> void:
	if sim_day != today():
		return
	var step := tuning.num("visitors.step_minutes")
	var guard := 4000
	while sim_minute < minute - 0.0001 and guard > 0:
		guard -= 1
		var dt := minf(step, minute - sim_minute)
		var before := floori(sim_minute / 10.0)
		sim_minute += dt
		_tick(dt)
		if floori(sim_minute / 10.0) != before:
			_ten_minutes()


func _tick(dt: float) -> void:
	while not schedule.is_empty() and float(schedule[0]["minute"]) <= sim_minute:
		var a: Dictionary = schedule.pop_front()
		if visitors_in_park() + int(a["size"]) > tuning.integer("visitors.most_in_park"):
			# Full: they come tomorrow instead.
			carry.append(a)
			continue
		spawn(a["kind"], int(a["size"]), str(a["home"]), int(a["nights"]))
	if net.version != _net_seen:
		_net_seen = net.version
		for p: Dictionary in parties:
			_replan_path(p)
	for p: Dictionary in parties:
		_update(p, dt)
	var done := parties.filter(func(p: Dictionary) -> bool: return p["state"] == "done")
	if not done.is_empty():
		for p: Dictionary in done:
			_leave(p)
		parties = parties.filter(func(p: Dictionary) -> bool: return p["state"] != "done")


var _net_seen: int = -1


func _ten_minutes() -> void:
	for t: Vector2i in things_with("fire"):
		if int(things[t]["lit"]) > 0:
			things[t]["lit"] = maxi(0, int(things[t]["lit"]) - 10)
			if int(things[t]["lit"]) == 0:
				changed.emit()
	# Storms send day parties home and campers to their tents.
	var w := s().weather.current(int(sim_minute))
	if (tuning.value("visitors.storm_weathers") as Array).has(w):
		for p: Dictionary in parties:
			if bool(p.get("storm", false)) or p["state"] in ["lost", "camp", "done"]:
				continue
			p["storm"] = true
			if p["home"] == "":
				p["legs"] = [_leg(gate_node(), "home")]
			else:
				p["legs"] = [_leg(_home_node(p), "camp", str(p["home"]))]
			p["leg"] = 0
			_start_leg(p)
			if events.filter(func(e: Dictionary) -> bool: return e["type"] == "weather").is_empty():
				events.append({"type": "weather", "place": "gate"})


func _update(p: Dictionary, dt: float) -> void:
	match str(p["state"]):
		"walk":
			_walk(p, speed() * dt)
		"dwell", "rest":
			p["wait"] = float(p["wait"]) - dt
			if float(p["wait"]) <= 0.0:
				if p["state"] == "rest":
					p["state"] = "walk"
				else:
					_next_leg(p)


func _walk(p: Dictionary, budget: float) -> void:
	var path: PackedVector2Array = p["path"]
	var pos: Vector2 = p["pos"]
	while budget > 0.0:
		var pi: int = p["pi"]
		if pi >= path.size():
			p["pos"] = pos
			_arrive(p)
			return
		var to := path[pi]
		var d := pos.distance_to(to)
		if d <= budget:
			pos = to
			budget -= d
			p["pi"] = pi + 1
			p["pos"] = pos
			if _passed(p, Vector2i(floori(to.x), floori(to.y))):
				return
		else:
			pos += (to - pos) / d * budget
			budget = 0.0
	p["pos"] = pos


## Called at each tile walked. Returns true if the party stopped.
func _passed(p: Dictionary, t: Vector2i) -> bool:
	var mood: Dictionary = tuning.value("visitors.mood")
	# A bench on the way: a rest, and a happier party.
	var br := tuning.num("visitors.bench_reach_tiles")
	for bt: Vector2i in things_with("rest"):
		var k := "b" + _tkey(bt)
		if not (p["rested"] as Dictionary).has(k) and (Vector2(bt) + Vector2(0.5, 0.5)).distance_to(p["pos"]) <= br:
			p["rested"][k] = true
			p["mood"] = int(p["mood"]) + int(mood["bench"])
			events.append({"type": "bench", "place": place_of(Vector2(bt))})
			p["state"] = "rest"
			p["wait"] = tuning.num("visitors.bench_rest_minutes")
			return true
	# A nice find on the way.
	var fr := tuning.num("visitors.find_reach_tiles")
	for fid: String in world.meta.get("finds", {}):
		if (p["seen"] as Dictionary).has(fid):
			continue
		if _v2(world.meta["finds"][fid]).distance_to(p["pos"]) <= fr:
			p["seen"][fid] = true
			p["mood"] = int(p["mood"]) + int(mood["find"])
			if fid == "rusted_truck" and p["kind"] == "scout_troop":
				events.append({"type": "scouts_road", "place": "static_tower"})
	# Scouts on their litter badge pick up what they pass.
	if bool(content.row("visitor_types", p["kind"]).get("litter_badge", false)) and int(p["picked"]) < tuning.integer("upkeep.scout_litter_per_day"):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var lt := t + Vector2i(dx, dy)
				if litter.has(lt) and int(p["picked"]) < tuning.integer("upkeep.scout_litter_per_day"):
					litter.erase(lt)
					p["picked"] = int(p["picked"]) + 1
					changed.emit()
	# A wrong turn at an unsigned junction in fog, at night or in a storm.
	if lost.is_empty() and _is_junction(t) and not (p["seen"] as Dictionary).has("j" + _tkey(t)):
		p["seen"]["j" + _tkey(t)] = true
		if _wrong_turn(p, t):
			return true
	return false


func _is_junction(t: Vector2i) -> bool:
	if _junction_version != net.version:
		_junction_version = net.version
		_junction_tiles = {}
		for j: Vector2i in net.junctions():
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					_junction_tiles[j + Vector2i(dx, dy)] = j
	return _junction_tiles.has(t)


func _bad_light() -> bool:
	var w := s().weather.current(int(sim_minute))
	if (tuning.value("visitors.wrong_turn_weathers") as Array).has(w):
		return true
	return Daylight.is_night(tuning, clock.season_name(), int(sim_minute))


func _wrong_turn(p: Dictionary, t: Vector2i) -> bool:
	if not _bad_light() or p["state"] != "walk":
		return false
	var dest := _dest_landmark(p)
	var r := tuning.num("visitors.pointer_sign_reach_tiles")
	for st: Vector2i in s().placed:
		if str(s().placed[st]["place"]) == dest and Vector2(st).distance_to(Vector2(t)) <= r:
			return false
	var chance := tuning.num("visitors.wrong_turn_chance")
	if dest != "" and dest != "ranger_station" and s().map.is_landmark_mapped(dest):
		chance *= tuning.num("visitors.mapped_wrong_turn_multiplier")
	if rng.randf() >= chance:
		return false
	return lose(p, t)


func _dest_landmark(p: Dictionary) -> String:
	var legs: Array = p["legs"]
	if int(p["leg"]) >= legs.size():
		return ""
	var l: Dictionary = legs[int(p["leg"])]
	if l["act"] == "home":
		return "ranger_station"
	var place := str(l["ref"])
	if content.has("sites", place):
		return content.row("sites", place)["landmark"]
	if p["dest"] != "" and content.has("sites", p["dest"]):
		return content.row("sites", p["dest"])["landmark"]
	return ""


## Sends a party astray a little way off the trail near t. At most one party
## is lost at a time.
func lose(p: Dictionary, t: Vector2i) -> bool:
	if not lost.is_empty():
		return false
	var spot := _off_trail_spot(t)
	if spot.x < 0:
		return false
	p["state"] = "lost"
	p["lost"] = true
	p["pos"] = Vector2(spot) + Vector2(0.5, 0.5)
	p["path"] = PackedVector2Array()
	p["mood"] = int(p["mood"]) + int((tuning.value("visitors.mood") as Dictionary)["lost"])
	var r := tuning.num("visitors.lost_rumor_radius")
	var off := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)) * r
	lost = {"party": int(p["id"]), "center": Vector2(t) + off, "place": _nearest_place_name(Vector2(t)), "since": sim_day}
	note.emit(content.text("msg_lost_radio", {"party": party_name(p), "place": lost_place_name()}))
	return true


func _nearest_place_name(p: Vector2) -> String:
	var best := "gate"
	var best_d := INF
	for place: String in place_ids():
		var d := place_spot(place).distance_to(p)
		if d < best_d:
			best_d = d
			best = place
	return best


func lost_place_name() -> String:
	if lost.is_empty():
		return ""
	var pl := str(lost["place"])
	return place_name(pl)


func _off_trail_spot(t: Vector2i) -> Vector2i:
	var range_t: Array = tuning.value("visitors.lost_off_trail_tiles")
	for attempt in 60:
		var a := rng.randf() * TAU
		var d := rng.randf_range(float(range_t[0]), float(range_t[1]))
		var c := t + Vector2i(roundi(cos(a) * d), roundi(sin(a) * d))
		if world.is_solid(c) or net.has(c):
			continue
		if world.ground_at(c) in ["grass", "tall_grass", "forest_floor"]:
			return c
	return Vector2i(-1, -1)


func lost_party() -> Dictionary:
	if lost.is_empty():
		return {}
	return party(int(lost["party"]))


## The ranger reaches the lost party: they follow back to the trail and go home.
func find_lost() -> int:
	var p := lost_party()
	if p.is_empty():
		return 0
	lost = {}
	p["lost"] = false
	var tip := rng.randi_range(int(tuning.value("visitors.tip")[0]), int(tuning.value("visitors.tip")[1]))
	money.earn(today(), "tips", tip)
	events.append({"type": "found", "place": "gate"})
	_milestone("first_found")
	var back: Vector2i = net.nearest(p["pos"], 30.0)
	if back.x >= 0:
		p["pos"] = Vector2(back) + Vector2(0.5, 0.5)
	if p["home"] == "":
		p["legs"] = [_leg(gate_node(), "home")]
	else:
		p["legs"] = [_leg(_home_node(p), "camp", str(p["home"]))]
	p["leg"] = 0
	_start_leg(p)
	return tip


func _arrive(p: Dictionary) -> void:
	var legs: Array = p["legs"]
	if int(p["leg"]) >= legs.size():
		p["state"] = "done"
		return
	var l: Dictionary = legs[int(p["leg"])]
	var act: String = l["act"]
	var ref: String = l["ref"]
	var mood: Dictionary = tuning.value("visitors.mood")
	var kmood: Dictionary = content.row("visitor_types", p["kind"]).get("mood", {})
	var wait := 0.0
	match act:
		"visit":
			p["mood"] = int(p["mood"]) + int(mood["reach"])
			events.append({"type": "reached", "place": ref})
			if p["kind"] == "tour_group":
				events.append({"type": "toured", "place": ref})
			p["trash"] = int(p["trash"]) + ceili(int(p["size"]) * tuning.num("visitors.trash_per_visitor") / 2.0)
			_use_bathrooms(p, ref)
			_drop_trash(p, ref)
			if (p["rested"] as Dictionary).is_empty() and ref != "gate" and travel(gate_node(), place_node(ref)) > 60.0 and p["home"] == "":
				events.append({"type": "want_bench", "place": ref})
			wait = dwell("visit")
		"lookout":
			wait = dwell("lookout")
		"picnic":
			if raid_today.has(ref):
				p["mood"] = int(p["mood"]) + int(mood["badger"])
				events.append({"type": "badger_picnic", "place": ref})
				raid_today.erase(ref)
			else:
				p["mood"] = int(p["mood"]) + int(kmood.get("picnic", mood["picnic"]))
				events.append({"type": "picnic", "place": ref})
			p["trash"] = int(p["trash"]) + int(p["size"])
			_use_bathrooms(p, ref)
			_drop_trash(p, ref)
			wait = dwell("picnic")
		"fish":
			money.earn(sim_day, "fishing", _price("fishing") * int(p["size"]))
			var site: String = pad_row(ref)["site"]
			events.append({"type": "fished", "place": site})
			events.append({"type": "fished:" + site, "place": site})
			p["mood"] = int(p["mood"]) + int(mood["reach"])
			_use_bathrooms(p, site)
			_drop_trash(p, site)
			wait = dwell("fish")
		"pitch":
			events.append({"type": "camped", "place": _home_place(p)})
			_use_bathrooms(p, _home_place(p))
			wait = dwell("pitch")
		"camp":
			_use_bathrooms(p, _home_place(p))
			_drop_trash(p, _home_place(p))
			if int(p["picked"]) > 0:
				events.append({"type": "scout_litter", "place": _home_place(p), "n": int(p["picked"])})
				p["picked"] = 0
			if p["kind"] == "scout_troop" and not bool(p.get("sang", false)):
				p["sang"] = true
				events.append({"type": "singalong", "place": _home_place(p)})
			p["state"] = "camp"
			return
		"home":
			_drop_trash(p, "gate")
			_use_bathrooms(p, "gate")
			p["state"] = "done"
			return
	p["state"] = "dwell"
	p["wait"] = wait


func _home_place(p: Dictionary) -> String:
	var h := str(p["home"])
	if h == "cabin":
		return "old_cabin"
	if h == "":
		return "gate"
	return pad_row(h)["site"]


## The party uses a place's bathroom, if it has one open and not filthy.
func _use_bathrooms(p: Dictionary, place: String) -> void:
	var baths := built_pads("bathroom", place).filter(func(pad: String) -> bool: return not _badger_napping(pad))
	if baths.is_empty():
		if p["kind"] == "family" and place != "gate" and site_ready(place):
			events.append({"type": "want_bathroom", "place": place})
		return
	var pad: String = baths[0]
	for b: String in baths:
		if float(pads[b]["clean"]) > float(pads[pad]["clean"]):
			pad = b
	var st := bath_state(pad)
	var mood: Dictionary = tuning.value("visitors.mood")
	if st == "filthy":
		p["mood"] = int(p["mood"]) + int(mood["dirty_bathroom"])
		events.append({"type": "bathroom_filthy", "place": place})
		return
	var uses := 0
	for i in int(p["size"]):
		if rng.randf() < tuning.num("visitors.bathroom_use_share"):
			uses += 1
	if uses == 0:
		return
	pads[pad]["clean"] = maxf(0.0, float(pads[pad]["clean"]) - tuning.num("upkeep.bathroom_per_visit") * uses)
	if st == "grubby":
		p["mood"] = int(p["mood"]) + int(mood["dirty_bathroom"])
		events.append({"type": "bathroom_grubby", "place": place})
	elif not bool(p.get("clean_used", false)):
		p["clean_used"] = true
		p["mood"] = int(p["mood"]) + int(mood["clean_bathroom"])
		events.append({"type": "bathroom_clean", "place": place})


## Puts the party's trash in a can with room nearby, or drops some of it.
func _drop_trash(p: Dictionary, place: String) -> void:
	if int(p["trash"]) <= 0:
		return
	var at: Vector2 = p["pos"]
	var reach := tuning.num("upkeep.can_reach_tiles")
	var cap := tuning.integer("upkeep.can_capacity")
	for t: Vector2i in things_with("trash"):
		if int(p["trash"]) <= 0:
			break
		var th: Dictionary = things[t]
		if bool(th["tipped"]) or (Vector2(t) + Vector2(0.5, 0.5)).distance_to(at) > reach:
			continue
		var put := mini(int(p["trash"]), cap - int(th["trash"]))
		if put > 0:
			th["trash"] = int(th["trash"]) + put
			p["trash"] = int(p["trash"]) - put
			changed.emit()
	if int(p["trash"]) <= 0:
		return
	var dropped := 0
	for i in int(p["trash"]):
		if rng.randf() < tuning.num("upkeep.litter_chance"):
			if _drop_litter_near(Vector2i(floori(at.x), floori(at.y))):
				dropped += 1
	p["trash"] = 0
	if not bool(p.get("carried", false)):
		p["carried"] = true
		p["mood"] = int(p["mood"]) + int((tuning.value("visitors.mood") as Dictionary)["no_trash_can"])
		events.append({"type": "no_trash_can", "place": place})
	if dropped > 0:
		events.append({"type": "litter", "place": place})


## Scatters litter round a point, for a job that asks it picked up.
func scatter_litter(at: Vector2, n: int, r: float, seed_value: int) -> void:
	var g := RandomNumberGenerator.new()
	g.seed = seed_value
	var put := 0
	for attempt in n * 12:
		if put >= n:
			break
		var c := Vector2i(at + Vector2(g.randf_range(-r, r), g.randf_range(-r, r)))
		if litter.has(c) or things.has(c) or world.is_solid(c) or Vector2(c).distance_to(at) > r:
			continue
		if world.ground_at(c) in ["shallows", "deep_water", "rock"]:
			continue
		litter[c] = g.randi() % 3
		put += 1
	changed.emit()


## Litter lying within r tiles of a point.
func litter_near(at: Vector2, r: float) -> int:
	var n := 0
	for t: Vector2i in litter:
		if Vector2(t).distance_to(at) <= r:
			n += 1
	return n


## Whether the cans at a place are full enough to want emptying: any can at
## or above the share of its capacity, or tipped.
func cans_need_emptying(place: String, share: float = 0.01) -> bool:
	for t: Vector2i in things_with("trash"):
		if place_of(Vector2(t)) != place:
			continue
		if bool(things[t]["tipped"]) or float(things[t]["trash"]) >= share * tuning.num("upkeep.can_capacity"):
			return true
	return false


## Visitors this week (the park's count), for templates that want a place
## people come to.
func visits_week(_place: String) -> int:
	return int(week.get("visitors", 0))


func _drop_litter_near(t: Vector2i) -> bool:
	for attempt in 12:
		var c := t + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
		if litter.has(c) or things.has(c) or world.is_solid(c):
			continue
		if world.ground_at(c) in ["shallows", "deep_water", "rock"]:
			continue
		litter[c] = rng.randi() % 3
		changed.emit()
		return true
	return false


## A party leaves the park: a last look at the gift shelf, and its mood counted.
func _leave(p: Dictionary) -> void:
	if int(lost.get("party", -1)) == int(p["id"]):
		lost = {}
	var stocked := []
	for i in gift_shelf.size():
		if gift_shelf.item_at(i) != "":
			stocked.append(gift_shelf.item_at(i))
	for i in int(p["size"]):
		if stocked.is_empty():
			break
		if rng.randf() < tuning.num("visitors.shelf_buy_share"):
			var item: String = stocked[rng.randi() % stocked.size()]
			gift_shelf.remove(item, 1)
			var price := int(content.row("items", item).get("sell", 0))
			money.earn(sim_day, "gift_shelf", price)
			# Say so (tracker #53: a sale at the kiosk went by unseen).
			note.emit(content.text("msg_shelf_sold", {"item": content.item_name(item).to_lower(), "n": price}))
			if gift_shelf.count(item) == 0:
				stocked.erase(item)
	var span := tuning.num("visitors.mood_span")
	var m := (clampf(float(p["mood"]), -span, span) + span) / (span * 2.0)
	week["mood_sum"] = float(week["mood_sum"]) + m * int(p["size"])
	week["mood_n"] = int(week["mood_n"]) + int(p["size"])


# --- the turn of the day ------------------------------------------------------------

## Called first thing on a new day, before the weather moves on: finishes
## yesterday out of sight (the clock has already moved on) and runs the night.
func on_new_day() -> void:
	if sim_day < today():
		_finish_day(sim_day)


## Called once the new day's weather is in: the morning's work and arrivals.
func start_day() -> void:
	sim_day = today()
	sim_minute = float(clock.minute)
	_seed_rng()
	_in_morning = true
	_morning()
	_in_morning = false


var _in_morning: bool = false


func _finish_day(day: int) -> void:
	# Run yesterday to its end, then everyone still out goes home or to bed.
	var end := tuning.num("time.day_end_minute")
	var step := tuning.num("visitors.step_minutes")
	while sim_minute < end:
		var dt := minf(step * 5.0, end - sim_minute)
		var before := floori(sim_minute / 10.0)
		sim_minute += dt
		_tick(dt)
		if floori(sim_minute / 10.0) != before:
			_ten_minutes()
	_night(day)


func _night(day: int) -> void:
	var price_camp := _price("camping")
	for p: Dictionary in parties:
		if p["state"] == "lost":
			continue
		if p["home"] == "":
			p["state"] = "done"
			continue
		# Campers spend the night at camp.
		if p["home"] != "cabin":
			money.earn(day, "camping", price_camp)
		events.append({"type": "camp_night:" + str(p["home"]), "place": _home_place(p)})
		p["pos"] = Vector2(_home_node(p)) + Vector2(0.5, 0.5)
		p["state"] = "camp"
		p["nights"] = int(p["nights"]) - 1
		p["storm"] = false
	# Anyone lost and not found turns up at the gate at 6:00, sheepish and fine.
	var lp := lost_party()
	if not lp.is_empty():
		lp["state"] = "done"
		events.append({"type": "lost_home", "place": "gate"})
		morning_lines.append(content.text("msg_lost_home"))
		lost = {}
	for p: Dictionary in parties.filter(func(q: Dictionary) -> bool: return q["state"] == "done"):
		_leave(p)
	parties = parties.filter(func(q: Dictionary) -> bool: return q["state"] != "done")
	schedule = []
	_night_upkeep(day)
	_night_badgers()
	_write_cards(day)
	events = []
	raid_today = {}
	for t: Vector2i in things_with("fire"):
		things[t]["lit"] = 0
	money.trim(day, tuning.integer("money.ledger_keep_days"))


func _night_upkeep(_day: int) -> void:
	var baths := built_pads("bathroom")
	if not baths.is_empty():
		week["bath_days"] = int(week["bath_days"]) + 1
	var any_dirty := false
	for pad: String in baths:
		var st := bath_state(pad)
		if st == "filthy":
			week["filthy"][pad] = int((week["filthy"] as Dictionary).get(pad, 0)) + 1
		else:
			(week["filthy"] as Dictionary).erase(pad)
		if st == "filthy" or st == "grubby":
			any_dirty = true
	if any_dirty:
		week["dirty_days"] = int(week["dirty_days"]) + 1


func _night_badgers() -> void:
	var active := false
	for b: Dictionary in badgers:
		if int(b["away_until"]) <= today():
			active = true
	if active:
		week["badger_nights"] = int(week["badger_nights"]) + 1
	for place: String in place_ids():
		if place != "gate" and not site_ready(place):
			continue
		if messy(place):
			mess_nights[place] = int(mess_nights.get(place, 0)) + 1
		else:
			mess_nights.erase(place)
			_badger_leaves(place)
	for place: String in mess_nights:
		if int(mess_nights[place]) < tuning.integer("badgers.mess_nights"):
			continue
		if badger_at(place) >= 0 or badgers.size() >= tuning.integer("badgers.most"):
			continue
		if rng.randf() < tuning.num("badgers.chance"):
			send_badger(place)


func badger_at(place: String) -> int:
	for i in badgers.size():
		if badgers[i]["place"] == place:
			return i
	return -1


func send_badger(place: String) -> bool:
	if badger_at(place) >= 0 or badgers.size() >= tuning.integer("badgers.most"):
		return false
	var c := place_spot(place)
	var spot := Vector2i(-1, -1)
	for attempt in 40:
		var t := Vector2i(floori(c.x) + rng.randi_range(-6, 6), floori(c.y) + rng.randi_range(-6, 6))
		if not world.is_solid(t) and world.ground_at(t) in ["grass", "tall_grass", "forest_floor", "trail"] and not things.has(t):
			spot = t
			break
	if spot.x < 0:
		return false
	badgers.append({"place": place, "tile": spot, "away_until": -1, "nap": ""})
	changed.emit()
	return true


func _badger_leaves(place: String) -> void:
	var i := badger_at(place)
	if i >= 0:
		badgers.remove_at(i)
		changed.emit()


func _badger_napping(pad: String) -> bool:
	for b: Dictionary in badgers:
		if str(b.get("nap", "")) == pad and int(b["away_until"]) <= today():
			return true
	return false


## Each badger at home gets up to one bit of mischief a day.
func _badger_mischief() -> void:
	for b: Dictionary in badgers:
		if int(b["away_until"]) > today():
			continue
		b["nap"] = ""
		var place: String = b["place"]
		# Phase 5b: a deal with the badgers keeps the peace there.
		if s().creatures.badger_peace(place):
			continue
		var options := []
		var cans := things_with("trash").filter(func(t: Vector2i) -> bool: return place_of(Vector2(t)) == place and int(things[t]["trash"]) > 0 and not bool(things[t]["tipped"]))
		if not cans.is_empty():
			options.append("tip_can")
		var baths := built_pads("bathroom", place)
		if not baths.is_empty():
			options.append("nap_bathroom")
		if not built_pads("picnic_area", place).is_empty():
			options.append("raid_picnic")
		var dig := _dig_spot(place)
		if dig.x >= 0:
			options.append("dig_trail")
		if options.is_empty():
			continue
		var total := 0.0
		for o: String in options:
			total += float(content.row("badger_mischief", o)["weight"])
		var pick := rng.randf() * total
		var what: String = options[-1]
		for o: String in options:
			pick -= float(content.row("badger_mischief", o)["weight"])
			if pick <= 0.0:
				what = o
				break
		do_mischief(b, what)


func do_mischief(b: Dictionary, what: String) -> bool:
	var place: String = b["place"]
	var row := content.row("badger_mischief", what)
	match what:
		"tip_can":
			var cans := things_with("trash").filter(func(t: Vector2i) -> bool: return place_of(Vector2(t)) == place and not bool(things[t]["tipped"]))
			if cans.is_empty():
				return false
			var t: Vector2i = cans[0]
			things[t]["trash"] = 0
			things[t]["tipped"] = true
			for i in int(row["litter"]):
				_drop_litter_near(t)
		"nap_bathroom":
			var baths := built_pads("bathroom", place)
			if baths.is_empty():
				return false
			b["nap"] = baths[0]
		"raid_picnic":
			if built_pads("picnic_area", place).is_empty():
				return false
			raid_today[place] = true
		"dig_trail":
			var t := _dig_spot(place)
			if t.x < 0:
				return false
			diggings[t] = world.ground_at(t) if world.baked_ground_at(t) != world.ground_at(t) else ""
			world.set_ground(t, "dug_earth")
			net.mark_dirty()
			s().land_changed.emit(t)
	events.append({"type": "badger", "place": place})
	s().creatures.on_mischief(place)
	changed.emit()
	return true


func _dig_spot(place: String) -> Vector2i:
	var n := place_node(place)
	if n.x < 0:
		return n
	for attempt in 30:
		var t := n + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		if world.ground_at(t) == "trail" and not world.is_solid(t) and not s().placed.has(t) and not diggings.has(t):
			return t
	return Vector2i(-1, -1)


## Fills in a badger's hole: the trail is as it was.
func fill_digging(t: Vector2i) -> bool:
	if not diggings.has(t):
		return false
	var was: String = diggings[t]
	diggings.erase(t)
	world.set_ground(t, was)
	net.mark_dirty()
	s().land_changed.emit(t)
	changed.emit()
	return true


func badger_near(p: Vector2, r: float) -> int:
	for i in badgers.size():
		var b: Dictionary = badgers[i]
		if int(b["away_until"]) > today():
			continue
		var bp := Vector2(b["tile"]) + Vector2(0.5, 0.5)
		if str(b.get("nap", "")) != "":
			bp = pad_center(b["nap"])
		if bp.distance_to(p) <= r:
			return i
	return -1


func shoo(i: int) -> void:
	var b: Dictionary = badgers[i]
	b["away_until"] = today() + 1
	b["nap"] = ""
	changed.emit()


## Clearing up a place sends its badger off for good.
func _check_clean(place: String) -> void:
	if place != "" and not messy(place):
		_badger_leaves(place)
		mess_nights.erase(place)


func clean_bathroom(pad: String) -> void:
	pads[pad]["clean"] = 100.0
	_check_clean(pad_row(pad)["site"])
	changed.emit()


func empty_can(t: Vector2i) -> void:
	things[t]["trash"] = 0
	things[t]["tipped"] = false
	_check_clean(place_of(Vector2(t)))
	changed.emit()


## Picks up one piece of litter. Returns the lost belonging found in it, or "".
func pick_litter(t: Vector2i) -> String:
	if not litter.has(t):
		return ""
	litter.erase(t)
	var found := ""
	if rng.randf() < tuning.num("upkeep.belonging_chance"):
		found = content.text("belonging_%d" % (rng.randi_range(1, tuning.integer("upkeep.belongings"))))
		add_note(content.text("note_belonging", {"thing": found}), "found")
	_check_clean(place_of(Vector2(t)))
	changed.emit()
	return found


## A line in the ranger's notebook. `kind` picks its doodle and paper on
## the Log's notebook page: "strange", "badger", "found", "story", "heart".
func add_note(text: String, kind: String = "") -> void:
	notes.append({"day": today(), "text": text, "kind": kind})


# --- the morning ------------------------------------------------------------------

func _morning() -> void:
	morning_lines = []
	_deliver()
	var wd := week_day()
	if wd == tuning.integer("money.week_days"):
		money.earn(today(), "budget", tuning.integer("money.weekly_budget"))
		morning_lines.append(content.text("msg_budget", {"n": tuning.integer("money.weekly_budget")}))
		_pay_wages()
		_weekly_report()
		_refresh_board()
	_check_praise()
	_check_grumbles()
	_staff_work()
	_badger_mischief()
	for p: Dictionary in parties:
		if p["state"] == "camp":
			_plan_camp_day(p)
	_plan_arrivals()
	_book_cabin()
	if not unread_cards().is_empty():
		morning_lines.append(content.text("msg_cards_waiting"))
	changed.emit()


func _pay_wages() -> void:
	var paid := 0
	var short := false
	for st: Dictionary in staff:
		var wage := int(content.row("staff_roles", st["role"])["wage"])
		if money.spend(today(), "wages", wage):
			st["off"] = false
			paid += wage
		else:
			st["off"] = true
			short = true
	if paid > 0:
		morning_lines.append(content.text("msg_staff_paid", {"n": paid}))
	if short:
		morning_lines.append(content.text("msg_staff_unpaid"))


func _staff_work() -> void:
	for st: Dictionary in staff:
		if bool(st["off"]) or int(st.get("from", 0)) > today():
			continue
		var role := content.row("staff_roles", st["role"])
		if st["role"] == "custodian":
			for key: String in st["assigned"]:
				if key.begins_with("can:"):
					var t := _tparse(key.substr(4))
					if things.has(t):
						empty_can(t)
				elif pads.has(key) and built(key):
					clean_bathroom(key)
		elif st["role"] == "trail_crew":
			var n := int(role["litter"])
			for t: Vector2i in litter.keys():
				if n <= 0:
					break
				litter.erase(t)
				n -= 1
				_check_clean(place_of(Vector2(t)))
			for t: Vector2i in diggings.keys():
				fill_digging(t)
	changed.emit()


func _book_cabin() -> void:
	if rent_mode != "rent" or not s().structures.is_open("test_cabin"):
		return
	if booked_day == today():
		return
	var home := cabin_node()
	if home.x < 0 or travel(gate_node(), home) == INF:
		return
	if rng.randf() >= tuning.num("visitors.cabin_book_chance"):
		return
	var r := content.row("visitor_types", "campers")
	var size := rng.randi_range(int(r["party"][0]), int(r["party"][1]))
	booked_day = today()
	var fake := {"size": size, "kind": "campers"}
	booked_by = party_name(fake)
	money.earn(today(), "cabin_rent", _price("cabin_rent"))
	schedule.append({"minute": rng.randi_range(tuning.integer("visitors.arrive_from"), tuning.integer("visitors.arrive_until")), "kind": "campers", "size": size, "home": "cabin", "nights": 1})
	schedule.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["minute"]) < int(b["minute"]))
	morning_lines.append(content.text("msg_cabin_booked", {"party": booked_by}))


func cabin_booked() -> bool:
	return booked_day == today()


# --- the box, the board and the Chief ----------------------------------------------

func _write_cards(day: int) -> void:
	if events.is_empty():
		return
	# One card at most for each thing that happened (at each place).
	var cands := []
	var seen := {}
	for e: Dictionary in events:
		var key := str(e["type"]) + "|" + str(e.get("place", ""))
		if seen.has(key):
			continue
		seen[key] = true
		var rows := content.rows("suggestion_cards").filter(func(r: Dictionary) -> bool: return r["event"] == e["type"])
		for r: Dictionary in content.rows("spoiler_cards"):
			if r["event"] == e["type"] and rng.randf() < float(r["chance"]):
				rows = [r]
		if not rows.is_empty():
			cands.append([rows[rng.randi() % rows.size()], e])
	var most := tuning.integer("cards.most_per_day")
	var used := {}
	while not cands.is_empty() and used.size() < most:
		var i := rng.randi() % cands.size()
		var pair: Array = cands[i]
		cands.remove_at(i)
		var r: Dictionary = pair[0]
		if used.has(r["id"]):
			continue
		used[r["id"]] = true
		var e: Dictionary = pair[1]
		var text := content.text(r["text"], {"site": place_name(str(e.get("place", "gate"))), "n": int(e.get("n", 0))})
		cards.append({"day": day, "text": text, "asks": bool(r["asks"]), "read": false, "pinned": false, "event": str(e["type"]), "place": str(e.get("place", "gate"))})
		if str(week.get("best_card", "")) == "" or (not bool(r["asks"]) and rng.randf() < 0.3):
			week["best_card"] = text


func unread_cards() -> Array:
	return cards.filter(func(c: Dictionary) -> bool: return not bool(c["read"]))


func read_cards() -> Array:
	var out := unread_cards()
	for c: Dictionary in out:
		c["read"] = true
	return out


func pin_card(i: int) -> void:
	if i >= 0 and i < cards.size():
		cards[i]["pinned"] = true


func _refresh_board() -> void:
	var hired := {}
	for st: Dictionary in staff:
		hired[st["person"]] = true
	var pool := content.ids("staff_people").filter(func(id: String) -> bool: return not hired.has(id))
	var r := RandomNumberGenerator.new()
	r.seed = hash([s().seed_value, today(), "board"])
	board = []
	while not pool.is_empty() and board.size() < tuning.integer("staff.board_size"):
		var i := r.randi() % pool.size()
		board.append(pool[i])
		pool.remove_at(i)


func hire(person: String) -> bool:
	if not board.has(person):
		return false
	var row := content.row("staff_people", person)
	board.erase(person)
	var st := {"person": person, "role": row["suits"], "assigned": [], "off": false, "from": today() + 1}
	staff.append(st)
	if st["role"] == "custodian":
		_auto_assign(st)
	return true


func let_go(person: String) -> String:
	for i in staff.size():
		if staff[i]["person"] == person:
			staff.remove_at(i)
			return content.text(content.row("staff_people", person)["goodbye"])
	return ""


## What a custodian can look after: bathrooms and trash cans. [{key, label}]
func jobs_for_custodian() -> Array:
	var out := []
	for pad: String in built_pads("bathroom"):
		out.append({"key": pad, "label": content.text("fac_at", {"name": content.text("facility_bathroom"), "place": place_name(pad_row(pad)["site"])})})
	for t: Vector2i in things_with("trash"):
		var pl := place_of(Vector2(t))
		out.append({"key": "can:" + _tkey(t), "label": content.text("thing_at", {"name": content.text("item_trash_can"), "place": place_name(pl if pl != "" else _nearest_place_name(Vector2(t)))})})
	return out


func _auto_assign(st: Dictionary) -> void:
	var taken := {}
	for o: Dictionary in staff:
		for k: String in o["assigned"]:
			taken[k] = true
	var most := int(content.row("staff_roles", "custodian")["jobs"])
	for j: Dictionary in jobs_for_custodian():
		if (st["assigned"] as Array).size() >= most:
			break
		if not taken.has(j["key"]):
			(st["assigned"] as Array).append(j["key"])


func toggle_assign(person: String, key: String) -> void:
	for st: Dictionary in staff:
		if st["person"] != person:
			continue
		var a: Array = st["assigned"]
		if a.has(key):
			a.erase(key)
		elif a.size() < int(content.row("staff_roles", "custodian")["jobs"]):
			a.append(key)


func _milestone(id: String) -> void:
	if milestones.has(id):
		return
	milestones[id] = true
	for r: Dictionary in content.rows("chief_letters"):
		if r["kind"] == "praise" and r.get("trigger", "") == id:
			_send_letter(content.text(r["text"]))


func _send_letter(text: String) -> void:
	if rng.randf() < tuning.num("chief.hint_share"):
		var hints := content.rows("chief_letters").filter(func(r: Dictionary) -> bool: return r["kind"] == "hint" and not hints_used.has(r["id"]))
		if hints.is_empty():
			hints_used = []
			hints = content.rows("chief_letters").filter(func(r: Dictionary) -> bool: return r["kind"] == "hint")
		var h: Dictionary = hints[rng.randi() % hints.size()]
		hints_used.append(h["id"])
		text += "\n\n" + content.text(h["text"])
	letters.append({"day": today(), "text": text, "read": false})
	if not _in_morning:
		note.emit(content.text("msg_letter"))
	elif not morning_lines.has(content.text("msg_letter")):
		morning_lines.append(content.text("msg_letter"))


func _check_praise() -> void:
	if week_day() != tuning.integer("money.week_days"):
		return
	var last := today() - 1
	var tot := money.totals(last - tuning.integer("money.week_days") + 1, last)
	var earned := 0
	for src: String in tot:
		if not src in ["budget", "refund"] and int(tot[src]) > 0:
			earned += int(tot[src])
	if earned >= tuning.integer("chief.praise_week"):
		_milestone("week_500")


func _check_grumbles() -> void:
	if bool(week["grumbled"]):
		return
	for pad: String in week["filthy"]:
		if int(week["filthy"][pad]) >= tuning.integer("chief.filthy_days") and built(pad):
			week["grumbled"] = true
			_send_letter(content.text("chief_grumble_bathroom", {"site": place_name(pad_row(pad)["site"])}))
			return
	if int(week["badger_nights"]) >= tuning.integer("chief.badger_nights"):
		week["grumbled"] = true
		_send_letter(content.text("chief_grumble_badgers"))


func mood_word(m: float) -> String:
	if m < 0.0:
		return content.text("mood_none")
	if m >= 0.8:
		return content.text("mood_great")
	if m >= 0.6:
		return content.text("mood_good")
	if m >= 0.45:
		return content.text("mood_ok")
	return content.text("mood_poor")


func _weekly_report() -> void:
	var last := today() - 1
	var first := last - tuning.integer("money.week_days") + 1
	var tot := money.totals(first, last)
	var inc := 0
	var out := 0
	var lines := PackedStringArray()
	for r: Dictionary in content.rows("income_sources"):
		var v := int(tot.get(r["id"], 0))
		if v == 0:
			continue
		if v > 0:
			inc += v
		else:
			out -= v
		lines.append(content.text("ledger_line", {"name": content.text(r["name"]), "sign": "+" if v > 0 else "-", "n": absi(v)}))
	var m := -1.0
	if int(week["mood_n"]) > 0:
		m = float(week["mood_sum"]) / int(week["mood_n"])
	var lines_ids := content.rows("chief_letters").filter(func(r: Dictionary) -> bool: return r["kind"] == ("report_line" if int(week["visitors"]) > 0 else "report_line_quiet"))
	var line := content.text(lines_ids[rng.randi() % lines_ids.size()]["text"])
	var card := str(week.get("best_card", ""))
	var text := content.text("chief_report", {"visitors": int(week["visitors"]), "income": inc, "spending": out, "lines": "\n".join(lines), "mood": mood_word(m), "card": card if card != "" else content.text("card_none"), "line": line})
	if int(week["bath_days"]) >= tuning.integer("money.week_days") and int(week["dirty_days"]) == 0:
		_milestone("clean_week")
	_send_letter(text)
	last_week_mood = m
	_reset_week()


func unread_letters() -> Array:
	return letters.filter(func(l: Dictionary) -> bool: return not bool(l["read"]))


# --- what the ranger reads -----------------------------------------------------------

func ledger_lines() -> PackedStringArray:
	var out := PackedStringArray([content.text("ledger_wallet", {"n": money.wallet}), ""])
	var t := today()
	var wd := week_day()
	var spans := [["ledger_today", t, t], ["ledger_this_week", t - wd + 1, t], ["ledger_last_week", t - wd - 6, t - wd]]
	for sp: Array in spans:
		out.append(content.text(sp[0]))
		var tot := money.totals(int(sp[1]), int(sp[2]))
		var any := false
		var sum := 0
		for r: Dictionary in content.rows("income_sources"):
			var v := int(tot.get(r["id"], 0))
			if v == 0:
				continue
			any = true
			sum += v
			out.append(content.text("ledger_line", {"name": content.text(r["name"]), "sign": "+" if v > 0 else "-", "n": absi(v)}))
		if any:
			out.append(content.text("ledger_total", {"sign": "+" if sum >= 0 else "-", "n": absi(sum)}))
		else:
			out.append(content.text("ledger_none"))
		out.append("")
	return out


func park_lines() -> PackedStringArray:
	var out := PackedStringArray([content.text("park_title"), ""])
	out.append(content.text("park_visitors", {"n": visitors_in_park(), "parties": parties.size()}))
	var coming := 0
	for a: Dictionary in schedule:
		coming += int(a["size"])
	out.append(content.text("park_arriving", {"n": coming}))
	var vs := visitable_sites()
	var names: PackedStringArray = []
	for id: String in vs:
		names.append(place_name(id))
	out.append(content.text("park_sites", {"list": ", ".join(names)}) if not names.is_empty() else content.text("park_sites_none"))
	out.append(content.text("park_badgers", {"n": badgers.size()}))
	var sn: PackedStringArray = []
	for st: Dictionary in staff:
		sn.append(content.text(content.row("staff_people", st["person"])["name"]))
	out.append(content.text("park_staff", {"list": ", ".join(sn)}) if not sn.is_empty() else content.text("park_staff_none"))
	var mode := content.text("rent_for_rent" if rent_mode == "rent" else "rent_ranger_only")
	if cabin_booked():
		mode += ", " + content.text("park_cabin_booked")
	out.append(content.text("park_cabin", {"mode": mode}))
	var fl := PackedStringArray()
	for r: Dictionary in pad_rows():
		var st := pad_state(r["id"])
		if st == "" or bool(r.get("built", false)):
			continue
		var state := ""
		match st:
			"ordered":
				state = content.text("fac_state_ordered")
			"kit":
				state = content.text("fac_state_kit")
			"building":
				state = content.text("fac_state_building", {"done": int(pads[r["id"]]["done"]), "total": int(fac_row(r["id"])["actions"])})
			"built":
				state = content.text("fac_state_built")
				if r["facility"] == "bathroom":
					state = content.text("bath_" + bath_state(r["id"]))
		fl.append(content.text("park_facility", {"name": content.text(fac_row(r["id"])["name"]), "place": place_name(r["site"]), "state": state}))
	if not fl.is_empty():
		out.append("")
		out.append(content.text("park_facilities"))
		out.append_array(fl)
	return out


func card_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in cards:
		if bool(c["read"]):
			out.append(content.text("cards_line", {"day": _day_label(int(c["day"])), "text": c["text"]}))
	if out.is_empty():
		out.append(content.text("cards_none"))
	return out


func letter_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for l: Dictionary in letters:
		if bool(l["read"]):
			out.append(str(l["text"]))
			out.append("")
	if out.is_empty():
		out.append(content.text("letters_none"))
	return out


func note_lines() -> PackedStringArray:
	var out := PackedStringArray()
	for n: Dictionary in notes:
		out.append(content.text("notes_line", {"day": _day_label(int(n["day"])), "text": n["text"]}))
	if out.is_empty():
		out.append(content.text("notes_none"))
	return out


func _day_label(day: int) -> int:
	return day + 1


## Lines for the job list: a lost party, and cards pinned from the box.
func job_extra_lines() -> PackedStringArray:
	var out := PackedStringArray()
	var lp := lost_party()
	if not lp.is_empty():
		out.append(content.text("job_lost_title"))
		out.append(content.text("job_lost_line", {"party": party_name(lp), "place": lost_place_name()}))
	var pins := cards.filter(func(c: Dictionary) -> bool: return bool(c["pinned"]))
	if not pins.is_empty():
		out.append(content.text("job_pinned_title"))
		for c: Dictionary in pins:
			out.append(content.text("job_pinned", {"text": c["text"]}))
	return out
