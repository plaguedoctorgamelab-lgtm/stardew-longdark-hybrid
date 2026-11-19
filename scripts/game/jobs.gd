class_name Jobs
extends RefCounted
## The jobs module (jobs spec, 19 November 2026). The only thing that decides
## what a job is. Jobs are content data: hand-written jobs (jobs, spoiler_jobs),
## templates filled from the park (job_templates), typed steps (job_steps) and
## rewards (rewards). Progress is worked out from the world; a step that stays
## done is recorded the first time it is true and never undone. The Jobs page,
## the pinned note, the map, the toasts and the cards all read from here or
## listen to the five signals.

signal job_added(key: String, source: String)
signal step_done(key: String, step: int)
signal step_undone(key: String, step: int)
signal job_done(key: String)
signal job_retired(key: String)
signal toast(icon: String, color: Color, text: String, sound: String)
signal noticed_now(key: String)
signal spots_changed

const TYPE_ORDER: Array[String] = ["exploring", "upkeep", "trail", "visitor", "townsfolk"]

var _s: WeakRef
var known: Dictionary = {}          # key -> job state, see _new_state
var order: Array[String] = []       # keys, in the order they were added
var spots_done: Dictionary = {}     # spot id -> true
var unlocks: Dictionary = {}        # unlock id -> true: catalog, catalog_bench ...
var travel_open: Dictionary = {}    # travel place id -> true
var seen_landmarks: Dictionary = {} # landmark id -> true: come within finding distance
var noticed_seen: Dictionary = {}   # noticeable id -> true
var more_given: Dictionary = {}     # something-more id -> true
var flags: Dictionary = {}          # small facts: rain_day, first_badger_more ...
var pinned: String = ""             # the job the player pinned, or ""
var working: String = ""            # the job last made progress on
var cards: Array = []               # finishing and season cards waiting to be shown
var draws_today: Dictionary = {}    # type -> day last drawn
var _rows: Dictionary = {}          # hand-written job id -> row
var _tpl: Dictionary = {}           # template id -> row
var _spots: Dictionary = {}         # spot id -> row
var _defs: Dictionary = {}          # key -> filled definition, cached
var _dirty: bool = true
var _since: float = 0.0
var _away: Array = []               # jobs finished while converting an older save
var _quiet: bool = false
var rng := RandomNumberGenerator.new()


func _init(session: GameSession) -> void:
	_s = weakref(session)
	var c := session.content
	for r: Dictionary in c.rows("jobs") + c.rows("spoiler_jobs"):
		_rows[r["id"]] = r
	for r: Dictionary in c.rows("job_templates"):
		_tpl[r["id"]] = r
	for r: Dictionary in c.rows("job_spots") + c.rows("spoiler_job_spots"):
		_spots[r["id"]] = r


func s() -> GameSession:
	return _s.get_ref()


func _t(id: String, args: Dictionary = {}) -> String:
	return s().content.text(id, args)


# --- starting, saving --------------------------------------------------------------

func new_game() -> void:
	known = {}
	order = []
	spots_done = {}
	unlocks = {}
	travel_open = {}
	seen_landmarks = {}
	noticed_seen = {}
	more_given = {}
	flags = {}
	pinned = ""
	working = ""
	cards = []
	draws_today = {}
	_defs = {}
	_away = []
	_dirty = true
	update(true)
	spots_changed.emit()


func to_dict() -> Dictionary:
	var jobs := []
	for k: String in order:
		jobs.append(known[k])
	return {"jobs": jobs, "spots": spots_done.keys(), "unlocks": unlocks.keys(), "travel": travel_open.keys(),
		"seen": seen_landmarks.keys(), "noticed": noticed_seen.keys(), "more": more_given.keys(), "flags": flags.duplicate(true),
		"pinned": pinned, "working": working, "draws": draws_today.duplicate()}


## Loads the jobs; an older save has none, and is converted: every job is
## worked out from the world, those already done are finished and paid, and
## one "While you were away..." card lists them.
func from_dict(d: Dictionary, older: bool) -> void:
	known = {}
	order = []
	_defs = {}
	for e: Variant in d.get("jobs", []):
		var st: Dictionary = (e as Dictionary).duplicate(true)
		var k := str(st["key"])
		if not _resolvable(st):
			continue
		for f in ["steps_done", "broken", "counts", "q", "base", "live"]:
			if not st.has(f):
				st[f] = {}
		# JSON gives every number back as a float.
		for f in ["day", "season", "year", "fin_day", "fin_season"]:
			st[f] = int(st.get(f, -1))
		for f in ["counts", "q", "base"]:
			for kk: Variant in (st[f] as Dictionary).keys():
				st[f][kk] = int(st[f][kk])
		st["paid"] = bool(st.get("paid", false))
		st["finished"] = bool(st.get("finished", false))
		known[k] = st
		order.append(k)
	spots_done = _set_of(d.get("spots", []))
	unlocks = _set_of(d.get("unlocks", []))
	travel_open = _set_of(d.get("travel", []))
	seen_landmarks = _set_of(d.get("seen", []))
	noticed_seen = _set_of(d.get("noticed", []))
	more_given = _set_of(d.get("more", []))
	flags = (d.get("flags", {}) as Dictionary).duplicate(true)
	pinned = str(d.get("pinned", ""))
	working = str(d.get("working", ""))
	draws_today = (d.get("draws", {}) as Dictionary).duplicate()
	for kk: Variant in flags.keys():
		if flags[kk] is float:
			flags[kk] = int(flags[kk])
	cards = []
	_away = []
	_dirty = true
	if older:
		_convert_older()
	spots_changed.emit()


func _set_of(a: Variant) -> Dictionary:
	var out := {}
	for v: Variant in a:
		out[str(v)] = true
	return out


func _resolvable(st: Dictionary) -> bool:
	if bool(st.get("tpl", false)):
		return _tpl.has(str(st["id"]))
	return _rows.has(str(st["id"]))


func _convert_older() -> void:
	var g := s()
	# The designer's park already has its catalog in use.
	unlocks["catalog"] = true
	for site: Dictionary in g.content.rows("sites"):
		for lm in [str(site["landmark"])]:
			if g.map.is_landmark_mapped(lm):
				seen_landmarks[lm] = true
	_quiet = true
	update(true)
	_quiet = false
	# A site opened and joined in the older save gets its trail travel.
	for site: Dictionary in g.content.rows("sites"):
		if g.sites_open.has(site["id"]) and g.site_reached(site["id"]):
			travel_open[site["id"]] = true
	if not _away.is_empty():
		cards.append({"kind": "away", "jobs": _away.duplicate()})
	_away = []


# --- definitions -------------------------------------------------------------------

## The job's definition, with any template blanks filled: {id, key, type,
## giver, name, note, size, steps, rewards, more, season, handy, noticed}.
func def(key: String) -> Dictionary:
	if _defs.has(key):
		return _defs[key]
	if not known.has(key):
		return {}
	var st: Dictionary = known[key]
	var d := {}
	if bool(st.get("tpl", false)):
		d = _fill_template(_tpl[st["id"]], st.get("blanks", {}))
	else:
		var r: Dictionary = _rows[st["id"]]
		d = r.duplicate(true)
		d["name"] = _t(r["name"])
		d["note"] = _t(r["note"])
		d["giver"] = str(r.get("giver", s().content.row("job_types", r["type"])["giver"]))
	d["key"] = key
	_defs[key] = d
	return d


func _fill_template(r: Dictionary, blanks: Dictionary) -> Dictionary:
	var d := r.duplicate(true)
	var args := {}
	for b: String in blanks:
		args[b] = blanks[b]
	d["name"] = _t(r["name"], args)
	var notes: Array = r["notes"]
	var pick := int(blanks.get("_note", 0)) % notes.size()
	d["note"] = _t(notes[pick], args)
	d["giver"] = str(r.get("giver", "")) if str(r.get("giver", "")) != "" else str(s().content.row("job_types", r["type"])["giver"])
	if blanks.has("_giver"):
		d["giver_name"] = str(blanks["_giver"])
	d["steps"] = _fill(d["steps"], args)
	d["season"] = "template"
	return d


func _fill(v: Variant, args: Dictionary) -> Variant:
	if v is String:
		var sv := v as String
		if sv.begins_with("{") and sv.ends_with("}") and args.has(sv.substr(1, sv.length() - 2)):
			return args[sv.substr(1, sv.length() - 2)]
		return sv
	if v is Array:
		var out := []
		for e: Variant in v:
			out.append(_fill(e, args))
		return out
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = _fill(v[k], args)
		return out
	return v


func step_label(key: String, i: int) -> String:
	var d := def(key)
	var stp: Dictionary = d["steps"][i]
	var args := {}
	if known.has(key):
		args = (known[key].get("blanks", {}) as Dictionary).duplicate()
	return _t(stp["label"], args)


func type_row(key: String) -> Dictionary:
	return s().content.row("job_types", def(key)["type"])


func type_color(type_id: String) -> Color:
	return Color.html("#" + str(s().content.row("job_types", type_id)["color"]))


func giver_name(key: String) -> String:
	var d := def(key)
	if d.has("giver_name"):
		return str(d["giver_name"])
	return _t(s().content.row("givers", d["giver"])["name"])


func giver_how(key: String) -> String:
	return str(s().content.row("givers", def(key)["giver"])["how"])


# --- adding jobs ---------------------------------------------------------------------

func _new_state(id: String, tpl: bool, blanks: Dictionary, source: String) -> Dictionary:
	var g := s()
	return {"key": "", "id": id, "tpl": tpl, "blanks": blanks, "source": source, "day": g.clock.absolute_day(),
		"season": g.clock.season, "year": g.clock.year, "steps_done": {}, "broken": {}, "counts": {}, "q": {}, "base": {}, "live": {},
		"finished": false, "fin_day": -1, "fin_season": -1, "paid": false, "given": [], "new": true, "noticed": source == "noticed"}


## Adds a hand-written job by id. False if it is already known.
func add(id: String, source: String) -> bool:
	if known.has(id) or not _rows.has(id):
		return false
	var st := _new_state(id, false, {}, source)
	st["key"] = id
	_put(st)
	var r: Dictionary = _rows[id]
	_on_add(id, r.get("on_add", {}))
	return true


func _put(st: Dictionary) -> void:
	var k: String = st["key"]
	known[k] = st
	order.append(k)
	_defs.erase(k)
	_take_base(k)
	_dirty = true
	if not _quiet:
		var d := def(k)
		if bool(st["noticed"]):
			toast.emit(type_row(k)["icon"], type_color(d["type"]), _t("jt_noted", {"name": d["name"]}), "pencil")
			noticed_now.emit(k)
		else:
			toast.emit(type_row(k)["icon"], type_color(d["type"]), _t("jt_new_job", {"name": d["name"]}), "paper")
	job_added.emit(k, str(st["source"]))
	spots_changed.emit()


## What a job sets going when it appears: a rumor on the map, litter to
## pick up.
func _on_add(key: String, on_add: Dictionary) -> void:
	var g := s()
	if on_add.has("rumor"):
		g.rumors[str(on_add["rumor"])] = true
	if on_add.has("litter"):
		var l: Dictionary = on_add["litter"]
		var at := _where(key, str(l["at"]))
		if at != Vector2.INF:
			g.park.scatter_litter(at, int(l["n"]), float(l["r"]), hash([g.seed_value, key]))


## Records the counts a step measures from: things already standing, so
## "2 more trash cans" means more.
func _take_base(key: String) -> void:
	var d := def(key)
	var st: Dictionary = known[key]
	for i in (d["steps"] as Array).size():
		var stp: Dictionary = d["steps"][i]
		if stp["kind"] == "place" and bool(stp.get("more_than_now", false)):
			st["base"][str(i)] = _count_placed(key, stp)


func is_active(key: String) -> bool:
	return known.has(key) and not bool(known[key]["finished"])


func is_done(key: String) -> bool:
	return known.has(key) and bool(known[key]["finished"])


# --- conditions ---------------------------------------------------------------------

## The shared condition format: atoms joined by " and " and " or " ("and"
## binds tighter). See the spec's "Conditions".
func cond(text: String) -> bool:
	if text == "" or text == "always" or text == "new_game":
		return true
	for part in text.split(" or "):
		var all := true
		for atom in part.split(" and "):
			if not _atom(atom.strip_edges()):
				all = false
				break
		if all:
			return true
	return false


func _atom(a: String) -> bool:
	var g := s()
	var i := a.find(":")
	var head := a if i < 0 else a.substr(0, i)
	var arg := "" if i < 0 else a.substr(i + 1)
	match head:
		"always", "new_game":
			return true
		"never":
			return false
		"job_done":
			return is_done(arg)
		"job_active":
			return is_active(arg)
		"not_done":
			return not is_done(arg)
		"site_found":
			return g.sites_found.has(arg)
		"site_open":
			return g.sites_open.has(arg)
		"site_mapped":
			return g.map.is_landmark_mapped(g.content.row("sites", arg)["landmark"])
		"rumor":
			return g.rumors.has(arg)
		"season":
			return g.clock.season_name() == arg
		"weather":
			return g.current_weather() == arg
		"time":
			var ab := arg.split("-")
			return g.clock.minute >= int(ab[0]) and g.clock.minute <= int(ab[1])
		"find":
			return g.finds_found.has(arg)
		"rain_recent":
			return int(flags.get("rain_day", -99)) >= g.clock.absolute_day() - 1
		"scouts_camped":
			return not _scout_party().is_empty()
		"site_open_any_building":
			return not _open_buildings().is_empty()
	push_error("Jobs: unknown condition %s" % a)
	return false


func _open_buildings() -> Array[String]:
	var g := s()
	var out: Array[String] = []
	for id in g.structures.ids():
		if id != "ranger_station" and g.structures.is_open(id):
			out.append(id)
	return out


func _scout_party() -> Dictionary:
	for p: Dictionary in s().park.parties:
		if str(p["kind"]) == "scout_troop" and str(p.get("home", "")) != "" and not bool(p.get("gone", false)):
			return p
	return {}


# --- places ----------------------------------------------------------------------------

## A place named in job data, in tiles, or Vector2.INF when it is not known.
func _where(key: String, at: String) -> Vector2:
	var g := s()
	if at.begins_with("spot:"):
		return spot_pos(at.substr(5))
	if at.begins_with("spawn:"):
		return g.world.spawn(at.substr(6))
	if at.begins_with("place:"):
		var pl := at.substr(6)
		if pl != "gate" and not g.content.has("sites", pl):
			return Vector2.INF
		return g.park.place_spot(pl)
	if at.begins_with("pad:"):
		return g.park.pad_center(at.substr(4))
	if at.begins_with("point_xy:"):
		var xy := at.substr(9).split(",")
		return Vector2(float(xy[0]) + 0.5, float(xy[1]) + 0.5)
	if at.begins_with("point:"):
		return _point(at.substr(6), 0)
	if at == "scout_camp":
		if known.has(key) and (known[key]["blanks"] as Dictionary).has("camp_x"):
			return Vector2(float(known[key]["blanks"]["camp_x"]), float(known[key]["blanks"]["camp_y"]))
		var p := _scout_party()
		if p.is_empty():
			return Vector2.INF
		var home := g.park.place_spot(g.park._home_place(p))
		if known.has(key):
			known[key]["blanks"]["camp_x"] = home.x
			known[key]["blanks"]["camp_y"] = home.y
		return home
	if at == "lost":
		var lost: Dictionary = g.park.lost
		if lost.is_empty():
			return Vector2.INF
		return lost["center"] as Vector2
	if at == "busiest":
		return g.park.place_spot(_busiest())
	return Vector2.INF


func _point(name: String, idx: int) -> Vector2:
	var pts: Dictionary = s().world.meta.get("trail_job_points", {})
	if not pts.has(name):
		return Vector2.INF
	var v: Array = pts[name]
	if v.size() > 0 and v[0] is Array:
		v = v[idx]
	return Vector2(float(v[0]) + 0.5, float(v[1]) + 0.5)


func _busiest() -> String:
	var g := s()
	var best := "gate"
	var most := -1
	for id: String in g.sites_open:
		var n := 0
		for t: Vector2i in g.park.things:
			if g.park.place_of(Vector2(t)) == id:
				n += 1
		if n > most:
			most = n
			best = id
	return best


func gap(name: String) -> Dictionary:
	return (s().world.meta.get("trail_job_gaps", {}) as Dictionary).get(name, {})


# --- spots ----------------------------------------------------------------------------

func spot_row(id: String) -> Dictionary:
	return _spots.get(id, {})


func spot_ids() -> Array:
	return _spots.keys()


func spot_pos(id: String) -> Vector2:
	var r := spot_row(id)
	if r.is_empty():
		return Vector2.INF
	if str(r["where"]) != "outdoor":
		return s().door_front(r["where"])
	var p: Variant = r.get("pos", [0, 0])
	if p is String:
		var parts := (p as String).split(":")
		return _point(parts[1], int(parts[2]))
	return Vector2(float(p[0]) + float(r["size"][0]) / 2.0, float(p[1]) + 0.5)


func spot_tile(id: String) -> Vector2i:
	var p := spot_pos(id)
	var r := spot_row(id)
	if p is Vector2 and r.has("size"):
		return Vector2i(floori(p.x - float(r["size"][0]) / 2.0), floori(p.y))
	return Vector2i(floori(p.x), floori(p.y))


## Whether a spot is shown in the world now: not done (or done with a
## picture of after), and its condition holds.
func spot_shown(id: String) -> bool:
	var r := spot_row(id)
	if r.is_empty():
		return false
	if spots_done.has(id) and str(r.get("sprite_done", "")) == "":
		return false
	return cond(str(r.get("shows", "")))


## Whether a spot is there to work on now.
func spot_open(id: String) -> bool:
	return not spots_done.has(id) and spot_shown(id) and str(spot_row(id).get("action", "")) != ""


func spot_sprite(id: String) -> String:
	var r := spot_row(id)
	if spots_done.has(id):
		return str(r.get("sprite_done", ""))
	if r.has("sprite_winter") and s().clock.season_name() == "winter":
		return str(r["sprite_winter"])
	return str(r.get("sprite", ""))


## The outdoor spot in reach for an action ("x", "axe" or "hammer"), or "".
func spot_in_reach(action: String, pos: Vector2, reach: float) -> String:
	var best := ""
	var best_d := reach + 0.6
	for id: String in _spots:
		var r: Dictionary = _spots[id]
		if str(r["where"]) != "outdoor" or str(r.get("action", "")) != action or not spot_open(id):
			continue
		var d := pos.distance_to(spot_pos(id))
		if d <= best_d:
			best_d = d
			best = id
	return best


## Works a spot: tidies it, chops it, knocks it open. Returns the text to
## say, or "" if it could not be done.
func work_spot(id: String) -> String:
	var g := s()
	var r := spot_row(id)
	if r.is_empty() or spots_done.has(id):
		return ""
	var needs: Dictionary = r.get("needs", {})
	for it: String in needs:
		if g.backpack.count(it) < int(needs[it]):
			g.message.emit(_t("jt_spot_need", {"what": g.content.item_name(it).to_lower()}))
			return ""
	for it: String in needs:
		g.backpack.remove(it, int(needs[it]))
	spots_done[id] = true
	var gives: Dictionary = r.get("gives", {})
	for it: String in gives:
		if g.backpack.add(it, int(gives[it])) > 0:
			g.message.emit(_t("msg_backpack_full"))
	var text := _t(str(r["done_text"])) if str(r.get("done_text", "")) != "" else ""
	_dirty = true
	spots_changed.emit()
	if int(r.get("minutes", 0)) > 0:
		g.pass_minutes(int(r["minutes"]))
	update()
	return text


## Whether a spot that blocks digging stands on a tile.
func spot_blocks_dig(t: Vector2i) -> bool:
	for id: String in _spots:
		var r: Dictionary = _spots[id]
		if bool(r.get("blocks_dig", false)) and not spots_done.has(id) and spot_tile(id) == t:
			return true
	return false


# --- events -----------------------------------------------------------------------------

## Something happened that a step counts: litter picked up, a bathroom
## cleaned, a badger shooed, a survey done, a stove lit, a party talked to,
## a can emptied. data: {pos, pad, place, structure, party}.
func event(kind: String, data: Dictionary) -> void:
	for k: String in order:
		if not is_active(k):
			continue
		var d := def(k)
		for i in (d["steps"] as Array).size():
			var stp: Dictionary = d["steps"][i]
			if not _event_matches(k, stp, kind, data):
				continue
			var key := str(i)
			if kind == "clean" and data.has("pad"):
				key = str(i) + ":" + str(data["pad"])
			elif kind == "light" and data.has("structure"):
				key = str(i) + ":" + str(data["structure"])
			known[k]["counts"][key] = int(known[k]["counts"].get(key, 0)) + 1
			working = k
	_dirty = true
	update()


func _event_matches(key: String, stp: Dictionary, kind: String, data: Dictionary) -> bool:
	match str(stp["kind"]):
		"pick_up":
			if kind != "pick_up":
				return false
			var at := _where(key, str(stp["at"]))
			return at != Vector2.INF and (data["pos"] as Vector2).distance_to(at) <= float(stp["r"])
		"clean":
			if kind != "clean" or not stp.has("bathroom"):
				return false
			return str(stp["bathroom"]) == "all" or str(stp["bathroom"]) == str(data.get("pad", ""))
		"shoo":
			return kind == "shoo" and str(data.get("place", "")) == str(stp["place"])
		"empty":
			return kind == "empty" and str(data.get("place", "")) == str(stp["place"])
		"survey":
			if kind != "survey":
				return false
			var at := _where(key, str(stp["at"]))
			return at != Vector2.INF and (data["pos"] as Vector2).distance_to(at) <= float(stp["r"])
		"light":
			return kind == "light"
		"talk_to":
			return kind == "talk" and (str(stp["party"]) == str(data.get("party", "")))
	return false


# --- the step checks -------------------------------------------------------------------

## A step as it stands: {done, n, total}. n and total are given for steps
## with a count (0 and 0 otherwise).
func check(key: String, i: int) -> Dictionary:
	var st: Dictionary = known[key]
	var d := def(key)
	var stp: Dictionary = d["steps"][i]
	var kind := str(stp["kind"])
	if (st["steps_done"] as Dictionary).has(str(i)):
		return {"done": true, "n": 0, "total": 0}
	var g := s()
	match kind:
		"pack":
			var need := needs(key)
			for it: String in need:
				if g.backpack.count(it) < int(need[it]):
					return {"done": _others_done(key, i), "n": 0, "total": 0}
			return {"done": true, "n": 0, "total": 0}
		"go_to":
			return _check_go_to(key, i, stp)
		"find":
			if stp.has("site"):
				return {"done": g.sites_found.has(stp["site"]), "n": 0, "total": 0}
			return {"done": seen_landmarks.has(stp["landmark"]), "n": 0, "total": 0}
		"map":
			var lm := str(stp.get("landmark", ""))
			if stp.has("site"):
				lm = str(g.content.row("sites", stp["site"])["landmark"])
			return {"done": g.map.is_landmark_mapped(lm), "n": 0, "total": 0}
		"read":
			return {"done": g.notes_read.has(stp["note"]), "n": 0, "total": 0}
		"talk_to":
			return {"done": int(st["counts"].get(str(i), 0)) > 0, "n": 0, "total": 0}
		"clear":
			return _check_clear(stp)
		"dig":
			return _check_dig(stp)
		"join_trail":
			return {"done": joined(key, stp), "n": 0, "total": 0}
		"repair":
			if stp.has("spot"):
				return {"done": spots_done.has(stp["spot"]), "n": 0, "total": 0}
			var sid := str(stp["structure"])
			var parts := g.content.row("structures", sid)["repair_steps"] as Array
			var done := 0
			for rs: Dictionary in parts:
				if g.structures.step_done(sid, rs["id"]):
					done += 1
			return {"done": g.structures.is_open(sid), "n": done, "total": parts.size()}
		"sign":
			return _check_sign(key, stp)
		"place":
			var have := _count_placed(key, stp) - int(st["base"].get(str(i), 0))
			var want := int(stp["n"])
			return {"done": have >= want, "n": clampi(have, 0, want), "total": want if want > 1 else 0}
		"deliver":
			if stp.has("spot"):
				return {"done": spots_done.has(stp["spot"]), "n": 0, "total": 0}
			return _check_deliver(stp)
		"clean":
			if stp.has("spots"):
				var n := 0
				for sp: String in stp["spots"]:
					if spots_done.has(sp):
						n += 1
				var tot := (stp["spots"] as Array).size()
				return {"done": n >= tot, "n": n, "total": tot if tot > 1 else 0}
			return _check_clean(key, i, stp)
		"empty":
			return {"done": int(st["counts"].get(str(i), 0)) > 0 and not g.park.cans_need_emptying(str(stp["place"])), "n": 0, "total": 0}
		"pick_up":
			var n := int(st["counts"].get(str(i), 0))
			var want := int(stp["n"])
			return {"done": n >= want, "n": mini(n, want), "total": want if want > 1 else 0}
		"shoo":
			return {"done": int(st["counts"].get(str(i), 0)) > 0 or g.park.badger_at(str(stp["place"])) < 0, "n": 0, "total": 0}
		"survey":
			return {"done": int(st["counts"].get(str(i), 0)) > 0, "n": 0, "total": 0}
		"light":
			var bs := _open_buildings()
			var n := 0
			for b in bs:
				if int(st["counts"].get(str(i) + ":" + b, 0)) > 0:
					n += 1
			return {"done": n >= bs.size() and not bs.is_empty(), "n": n, "total": bs.size() if bs.size() > 1 else 0}
		"open":
			return {"done": g.sites_open.has(stp["site"]), "n": 0, "total": 0}
	return {"done": false, "n": 0, "total": 0}


func _others_done(key: String, i: int) -> bool:
	var d := def(key)
	for j in (d["steps"] as Array).size():
		if j == i or str(d["steps"][j]["kind"]) == "open":
			continue
		if not bool(check(key, j)["done"]):
			return false
	return true


func _check_go_to(key: String, i: int, stp: Dictionary) -> Dictionary:
	var g := s()
	var st: Dictionary = known[key]
	if str(stp["at"]) == "open_buildings":
		var bs := _open_buildings()
		var n := 0
		for b in bs:
			if int(st["counts"].get(str(i) + ":" + b, 0)) > 0:
				n += 1
			elif g.location == b or (not g.is_indoors() and g.outdoor_pos.distance_to(g.door_front(b)) <= float(stp["r"])):
				st["counts"][str(i) + ":" + b] = 1
				n += 1
		return {"done": n >= bs.size() and not bs.is_empty(), "n": n, "total": bs.size() if bs.size() > 1 else 0}
	if g.is_indoors():
		return {"done": false, "n": 0, "total": 0}
	var at := _where(key, str(stp["at"]))
	if at == Vector2.INF or g.outdoor_pos.distance_to(at) > float(stp["r"]):
		return {"done": false, "n": 0, "total": 0}
	if stp.has("window"):
		var w: Array = stp["window"]
		if g.clock.minute < int(w[0]) or g.clock.minute > int(w[1]):
			return {"done": false, "n": 0, "total": 0}
	if stp.has("weather") and g.current_weather() != str(stp["weather"]):
		return {"done": false, "n": 0, "total": 0}
	if bool(stp.get("fresh_day", false)) and g.clock.absolute_day() <= int(st["day"]):
		return {"done": false, "n": 0, "total": 0}
	return {"done": true, "n": 0, "total": 0}


func _clear_targets(stp: Dictionary) -> Dictionary:
	# {"tiles": [obstacle tiles to clear], "spots": [spot ids]}
	var tiles: Array[Vector2i] = []
	if stp.has("points"):
		var pts: Variant = (s().world.meta.get("trail_job_points", {}) as Dictionary).get(str(stp["points"]), [])
		if pts is Array and (pts as Array).size() > 0:
			if (pts as Array)[0] is Array:
				for p: Array in pts:
					tiles.append(Vector2i(int(p[0]), int(p[1])))
			else:
				tiles.append(Vector2i(int(pts[0]), int(pts[1])))
	if stp.has("gap_brush"):
		var gp := gap(str(stp["gap_brush"]))
		for p: Array in gp.get("tiles", []):
			var t := Vector2i(int(p[0]), int(p[1]))
			if s().world.object_at(t) == "brush":
				tiles.append(t)
	return {"tiles": tiles, "spots": stp.get("spots", [])}


func _check_clear(stp: Dictionary) -> Dictionary:
	var g := s()
	var tg := _clear_targets(stp)
	var n := 0
	var tot := 0
	for t: Vector2i in tg["tiles"]:
		tot += 1
		if g.cleared.has(t) or g.obstacle_at(t).is_empty():
			n += 1
	for sp: String in tg["spots"]:
		tot += 1
		if spots_done.has(sp):
			n += 1
	return {"done": n >= tot, "n": n, "total": tot if tot > 1 else 0}


## A gap is dug when trail joins its two ends; its count is the tiles of its
## line that are trail.
func _check_dig(stp: Dictionary) -> Dictionary:
	var g := s()
	if stp.has("diggings"):
		var place := str(stp["diggings"])
		for t: Vector2i in g.park.diggings:
			if g.park.place_of(Vector2(t)) == place:
				return {"done": false, "n": 0, "total": 0}
		return {"done": true, "n": 0, "total": 0}
	var gp := gap(str(stp["gap"]))
	if gp.is_empty():
		return {"done": false, "n": 0, "total": 0}
	var grounds: Array = g.tuning.value("sites.reach_grounds")
	var n := 0
	var tiles: Array = gp["tiles"]
	for p: Array in tiles:
		if grounds.has(g.world.ground_at(Vector2i(int(p[0]), int(p[1])))):
			n += 1
	var a := Vector2i(int(gp["a"][0]), int(gp["a"][1]))
	var b := Vector2i(int(gp["b"][0]), int(gp["b"][1]))
	var done := g.trail_joins(a, b, 6)
	return {"done": done, "n": n if not done else tiles.size(), "total": tiles.size()}


## Whether a join_trail step's two ends are joined by trail.
func joined(key: String, stp: Dictionary) -> bool:
	var g := s()
	var to := Vector2.INF
	var to_site := ""
	if stp.has("site"):
		to_site = str(stp["site"])
	elif stp.has("point"):
		to = _point(str(stp["point"]), 0)
	if not stp.has("from_site") and not stp.has("from_point"):
		return to_site != "" and g.site_reached(to_site)
	var from := Vector2.INF
	if stp.has("from_site"):
		from = g.site_door(str(stp["from_site"]))
	else:
		from = _point(str(stp["from_point"]), 0)
	if to_site != "":
		to = g.site_door(to_site)
	if from == Vector2.INF or to == Vector2.INF:
		return false
	return g.trail_reach_near(from, to, g.tuning.integer("sites.spot_reach_tiles"))


func _check_sign(key: String, stp: Dictionary) -> Dictionary:
	var g := s()
	if stp.has("site"):
		return {"done": g.site_signed(str(stp["site"])), "n": 0, "total": 0}
	var at := _where(key, str(stp["at"]))
	if at == Vector2.INF:
		return {"done": false, "n": 0, "total": 0}
	var places: Array = stp.get("places", [])
	var n := 0
	for pl: String in places:
		for t: Vector2i in g.placed:
			if str(g.placed[t]["item"]) != "trail_sign" or Vector2(t).distance_to(at) > float(stp["r"]):
				continue
			if pl == "any" or str(g.placed[t]["place"]) == pl:
				n += 1
				break
	return {"done": n >= places.size(), "n": n, "total": places.size() if places.size() > 1 else 0}


func _count_placed(key: String, stp: Dictionary) -> int:
	var g := s()
	var at := _where(key, str(stp["at"]))
	if at == Vector2.INF:
		return 0
	var r := float(stp["r"])
	var thing := str(stp["thing"])
	var n := 0
	for t: Vector2i in g.park.things:
		if str(g.park.things[t]["id"]) == thing and (Vector2(t) + Vector2(0.5, 0.5)).distance_to(at) <= r + 0.5:
			n += 1
	for t: Vector2i in g.placed:
		if str(g.placed[t]["item"]) == thing and (Vector2(t) + Vector2(0.5, 0.5)).distance_to(at) <= r + 0.5:
			n += 1
	return n


func _check_deliver(stp: Dictionary) -> Dictionary:
	var g := s()
	var chests: Array[String] = []
	if str(stp["chest"]) == "open_buildings":
		chests = _open_buildings()
	else:
		chests.append(str(stp["chest"]))
	var items: Dictionary = stp["items"]
	var n := 0
	for c in chests:
		if not g.structures.chests.has(c):
			continue
		var all := true
		for it: String in items:
			if (g.structures.chests[c] as Inventory).count(it) < int(items[it]):
				all = false
		if all:
			n += 1
	return {"done": n >= chests.size() and not chests.is_empty(), "n": n, "total": chests.size() if chests.size() > 1 else 0}


func _check_clean(key: String, i: int, stp: Dictionary) -> Dictionary:
	var g := s()
	var st: Dictionary = known[key]
	var pads: Array[String] = []
	if str(stp["bathroom"]) == "all":
		for p: String in g.park.built_pads("bathroom"):
			pads.append(p)
	else:
		pads.append(str(stp["bathroom"]))
	var n := 0
	for p in pads:
		if int(st["counts"].get(str(i) + ":" + p, 0)) > 0:
			n += 1
	return {"done": n >= pads.size(), "n": n, "total": pads.size() if pads.size() > 1 else 0}


## Everything the steps still to do will need, with counts: {item: count}.
## Tools once each; materials added up.
func needs(key: String) -> Dictionary:
	var g := s()
	var d := def(key)
	var need := {}
	for i in (d["steps"] as Array).size():
		var stp: Dictionary = d["steps"][i]
		if str(stp["kind"]) == "pack":
			for it: String in stp.get("items", {}):
				need[it] = int(need.get(it, 0)) + int(stp["items"][it])
			continue
		if bool(check(key, i)["done"]):
			continue
		match str(stp["kind"]):
			"repair":
				if stp.has("spot"):
					var r := spot_row(str(stp["spot"]))
					if str(r.get("action", "")) in ["axe", "hammer"]:
						need[r["action"]] = 1
					for it: String in r.get("needs", {}):
						need[it] = maxi(int(need.get(it, 0)), int(r["needs"][it]))
				else:
					var sid := str(stp["structure"])
					for rs: Dictionary in g.content.row("structures", sid)["repair_steps"]:
						if int(g.structures.progress[sid][rs["id"]]) > 0:
							continue
						for m: String in rs["materials"]:
							need[m] = int(need.get(m, 0)) + int(rs["materials"][m])
					need["hammer"] = 1
			"dig", "join_trail":
				need["shovel"] = 1
			"clear":
				var tg := _clear_targets(stp)
				for t: Vector2i in tg["tiles"]:
					var ob := g.obstacle_at(t)
					if not ob.is_empty():
						need[str(g.content.row("obstacles", ob["id"])["tool"])] = 1
				for sp: String in tg["spots"]:
					var r := spot_row(sp)
					if not spots_done.has(sp) and str(r.get("action", "")) in ["axe", "hammer"]:
						need[r["action"]] = 1
				if stp.has("tool"):
					need[stp["tool"]] = 1
			"sign":
				var c := check(key, i)
				var missing := 1
				if int(c["total"]) > 0:
					missing = int(c["total"]) - int(c["n"])
				need["trail_sign"] = int(need.get("trail_sign", 0)) + missing
				need["hammer"] = 1
			"place":
				var c := check(key, i)
				var want := int(stp["n"])
				var have := int(c["n"]) if int(c["total"]) > 0 else 0
				var item := str(stp["thing"])
				need[item] = int(need.get(item, 0)) + want - have
				if item == "cairn" or s().content.row("items", item).get("needs_tool", "") == "hammer":
					need["hammer"] = 1
			"deliver":
				if stp.has("spot"):
					for it: String in stp.get("items", {}):
						need[it] = int(need.get(it, 0)) + int(stp["items"][it])
				else:
					var chests := _open_buildings() if str(stp["chest"]) == "open_buildings" else [str(stp["chest"])]
					for it: String in stp["items"]:
						var more := 0
						for c: String in chests:
							if g.structures.chests.has(c):
								more += maxi(0, int(stp["items"][it]) - (g.structures.chests[c] as Inventory).count(it))
						if more > 0:
							need[it] = int(need.get(it, 0)) + more
			"light":
				need["firewood"] = int(need.get("firewood", 0)) + maxi(1, _open_buildings().size())
			"survey":
				for it in ["map", "compass", "pencil"]:
					need[it] = 1
	return need


## Where to get something a job needs, in a few words, or "".
func where_to_get(key: String, item: String) -> String:
	var g := s()
	var d := def(key)
	for stp: Dictionary in d["steps"]:
		if str(stp.get("from_spot", "")) != "" and str(stp.get("thing", "")) == item and not spots_done.has(str(stp["from_spot"])):
			return _t("jt_where_spot")
	var lock := catalog_lock(item)
	if lock != "" and g.guide.where_to_get(item) == _t("where_order"):
		return _t("jt_where_locked_catalog", {"what": _t("jt_lock_" + lock)})
	return g.guide.where_to_get(item)


## The unlock a catalog item waits for, or "" when it can be ordered.
func catalog_lock(item: String) -> String:
	if not unlocks.has("catalog"):
		return "catalog"
	for r: Dictionary in s().content.rows("catalog"):
		if str(r.get("item", "")) == item and str(r.get("unlock", "")) != "" and not unlocks.has(str(r["unlock"]).trim_prefix("catalog_")) and not unlocks.has(str(r["unlock"])):
			return str(r["unlock"]).trim_prefix("catalog_")
	return ""


# --- the tick ---------------------------------------------------------------------------

func mark_dirty() -> void:
	_dirty = true


## Called each frame by the session: checks jobs a few times a second, or at
## once when something changed.
func process(real_delta: float) -> void:
	_since += real_delta
	if _dirty or _since >= 0.5:
		update()


## Works everything out: new jobs, noticed jobs, steps done and undone, jobs
## finished. force skips the wait.
func update(_force: bool = false) -> void:
	_since = 0.0
	_dirty = false
	var g := s()
	if g == null:
		return
	_watch_landmarks()
	_appear()
	_notice()
	_lost_party()
	for k: String in order.duplicate():
		if is_active(k):
			_update_job(k)


func _watch_landmarks() -> void:
	var g := s()
	if g.is_indoors():
		return
	var r := g.tuning.num("sites.find_radius_tiles")
	for lm: String in ["broken_bridge"]:
		if not seen_landmarks.has(lm) and g.outdoor_pos.distance_to(g.world.landmark_pos(lm)) <= r:
			seen_landmarks[lm] = true


## Adds the hand-written jobs whose time has come. Seasonal jobs appear only
## on a season's first morning (the season's turn).
func _appear(season_turn: bool = false) -> void:
	for id: String in _rows:
		var r: Dictionary = _rows[id]
		if known.has(id) or bool(r.get("noticed", false)):
			continue
		var season := str(r.get("season", "until_done"))
		if season not in ["until_done", "template"]:
			if not season_turn or flags.has("retired:%s:%d" % [id, s().clock.year]):
				continue
		if cond(str(r["appears"])):
			add(id, "given")


func _notice() -> void:
	var g := s()
	if g.is_indoors():
		return
	if g.is_night() and not g.lantern_lit():
		return
	for n: Dictionary in g.content.rows("noticeables"):
		var nid: String = n["id"]
		if noticed_seen.has(nid) or known.has(str(n["job"])):
			continue
		var pos := Vector2.INF
		if n.has("spot"):
			pos = spot_pos(str(n["spot"]))
		else:
			pos = Vector2(float(n["pos"][0]) + 0.5, float(n["pos"][1]) + 0.5)
		if pos == Vector2.INF or g.outdoor_pos.distance_to(pos) > float(n.get("radius", g.tuning.num("jobs.notice_radius_tiles"))):
			continue
		if not cond(str(n.get("condition", ""))):
			continue
		noticed_seen[nid] = true
		var id := str(n["job"])
		var st := _new_state(id, false, {}, "noticed")
		st["key"] = id
		_put(st)
		_on_add(id, n.get("on_add", {}))


## The radio's lost party is a Visitor Request: it appears with the party
## lost, and is retired (not failed) when they turn up at the gate.
func _lost_party() -> void:
	var g := s()
	var lost: Dictionary = g.park.lost
	var active := ""
	for k: String in order:
		if is_active(k) and bool(known[k]["tpl"]) and str(known[k]["id"]) == "find_lost":
			active = k
	if not lost.is_empty() and active == "":
		var p := g.park.lost_party()
		var key := "tpl:find_lost:%d" % int(lost["party"])
		if known.has(key):
			return
		var st := _new_state("find_lost", true, {"party": g.park.party_name(p), "place": g.park.lost_place_name(), "_note": 0}, "given")
		st["key"] = key
		_put(st)
	elif lost.is_empty() and active != "":
		var st: Dictionary = known[active]
		if int(st["counts"].get("1", 0)) == 0:
			retire(active)


func _update_job(k: String) -> void:
	var st: Dictionary = known[k]
	var d := def(k)
	if _made_pointless(k):
		_finish_half(k)
		return
	var n_steps := (d["steps"] as Array).size()
	var all := true
	for i in n_steps:
		var stp: Dictionary = d["steps"][i]
		var kind := str(stp["kind"])
		var c := check(k, i)
		var was := (st["steps_done"] as Dictionary).has(str(i)) or (st["broken"] as Dictionary).has(str(i)) == false and (st.get("live", {}) as Dictionary).has(str(i))
		var stays := _stays(kind)
		var ok := bool(c["done"])
		if kind == "open" and not _others_done(k, i):
			ok = ok and false
		# Count toasts at each quarter.
		if not ok and int(c["total"]) > 1:
			var q := int(floor(float(c["n"]) * 4.0 / float(c["total"])))
			var lastq := int(st["q"].get(str(i), 0))
			if q > lastq and q < 4:
				st["q"][str(i)] = q
				working = k
				if not _quiet:
					toast.emit(type_row(k)["icon"], type_color(d["type"]), _t("jt_count_toast", {"step": step_label(k, i), "done": c["n"], "total": c["total"]}), "")
		if not st.has("live"):
			st["live"] = {}
		var live: Dictionary = st["live"]
		if ok:
			if not live.has(str(i)) and not (st["steps_done"] as Dictionary).has(str(i)):
				live[str(i)] = true
				st["broken"].erase(str(i))
				if stays:
					st["steps_done"][str(i)] = true
				working = k
				if not _quiet and n_steps > 1:
					toast.emit("mark_tick", type_color(d["type"]), _t("jt_step_done", {"step": step_label(k, i)}), "chime")
				step_done.emit(k, i)
			elif stays:
				st["steps_done"][str(i)] = true
		else:
			all = false
			if live.has(str(i)) and not stays:
				live.erase(str(i))
				st["broken"][str(i)] = true
				if not _quiet:
					toast.emit("mark_undone", Color(0.85, 0.5, 0.15), _t("jt_step_undone", {"step": step_label(k, i)}), "low")
				step_undone.emit(k, i)
	if all:
		_finish(k)


## A template job the world has done for the ranger (a custodian cleaned the
## bathroom, the cans were emptied, the litter picked up): its need has gone
## and the ranger did none of it.
func _made_pointless(k: String) -> bool:
	var st: Dictionary = known[k]
	if not bool(st["tpl"]) or not (st["counts"] as Dictionary).is_empty() or not (st["steps_done"] as Dictionary).is_empty():
		return false
	var tid := str(st["id"])
	var check_id := str(_tpl[tid]["check"])
	if check_id not in ["bath_grubby", "cans_full", "litter_near"]:
		return false
	for b: Dictionary in candidates(tid):
		if str(b.get("_at", "")) == str(st["blanks"].get("_at", "")):
			return false
	return true


## Finishes a job done by someone else: half its money, and a line naming who.
func _finish_half(k: String) -> void:
	var g := s()
	var st: Dictionary = known[k]
	var money := 0
	for r: Dictionary in def(k).get("rewards", []):
		if str(r["kind"]) == "money":
			money += int(r["n"])
	var n := roundi(money * g.tuning.num("jobs.half_pay_share"))
	st["finished"] = true
	st["paid"] = true
	st["fin_day"] = g.clock.absolute_day()
	st["fin_season"] = g.clock.season
	if n > 0:
		g.park.money.earn(g.park.today(), "jobs", n)
	var line := _t("jt_template_retired_half", {"who": _t("jt_staff"), "n": n})
	st["given"] = [{"icon": "reward_money", "text": line}]
	if not _quiet:
		toast.emit(type_row(k)["icon"], type_color(def(k)["type"]), def(k)["name"] + ": " + line, "")
	if pinned == k:
		pinned = ""
	job_done.emit(k)


func _stays(kind: String) -> bool:
	var c := s().content
	if c.has("job_steps", kind):
		return bool(c.row("job_steps", kind)["stays_done"])
	return true


# --- finishing and rewards --------------------------------------------------------------

func _finish(k: String) -> void:
	var g := s()
	var st: Dictionary = known[k]
	st["finished"] = true
	st["fin_day"] = g.clock.absolute_day()
	st["fin_season"] = g.clock.season
	st["new"] = true
	if pinned == k:
		pinned = ""
	if working == k:
		working = ""
	var card := {"kind": "done", "key": k, "lines": [], "more": "", "unlocked": [], "map": []}
	if not bool(st["paid"]):
		st["paid"] = true
		var d := def(k)
		var before := order.duplicate()
		for r: Dictionary in d.get("rewards", []):
			var line := _give(k, r, card)
			if line != "":
				card["lines"].append({"icon": _reward_icon(str(r["kind"])), "text": line})
		# Jobs that wait on this one appear now, so the card can list them.
		_appear()
		var more_id := str(d.get("more", ""))
		if str(d.get("check", "")) == "badger_at":
			more_id = "more_badger" if not flags.has("badger_more") else ""
			flags["badger_more"] = true
		if more_id != "" and not more_given.has(more_id) and s().content.has("spoiler_more", more_id):
			more_given[more_id] = true
			card["more"] = _give_more(more_id)
		for nk: String in order:
			if not before.has(nk):
				(card["unlocked"] as Array).append(def(nk)["name"])
		st["given"] = card["lines"].duplicate(true)
		st["more_text"] = card["more"]
		if str(d.get("done_note", "")) != "":
			card["note"] = _t(d["done_note"])
	if _quiet:
		_away.append({"name": def(k)["name"], "lines": card["lines"]})
	else:
		cards.append(card)
	spots_changed.emit()
	job_done.emit(k)


func _reward_icon(kind: String) -> String:
	var c := s().content
	return str(c.row("rewards", kind)["icon"]) if c.has("rewards", kind) else "reward_things"


## Gives one reward and says what it gave. A duplicate is swapped for its
## value in money, and the line says so.
func _give(k: String, r: Dictionary, card: Dictionary) -> String:
	var g := s()
	var kind := str(r["kind"])
	var value := int(g.content.row("rewards", kind).get("value", 0)) if g.content.has("rewards", kind) else 0
	match kind:
		"money":
			var n := int(r["n"])
			if bool(known[k]["tpl"]):
				n = roundi(n * rng.randf_range(1.0 - g.tuning.num("jobs.template_money_spread"), 1.0 + g.tuning.num("jobs.template_money_spread")))
			g.park.money.earn(g.park.today(), "jobs", n)
			return _t("jt_r_money_got", {"n": n})
		"xp":
			g.skills.add_xp(str(r["skill"]), int(r["n"]))
			return _t("jt_r_xp", {"n": int(r["n"]), "skill": g._skill_name(str(r["skill"]))})
		"rumor":
			var lm := str(r["landmark"])
			var job := str(r.get("job", ""))
			if g.rumors.has(lm) or g.map.is_landmark_mapped(lm) or (job != "" and known.has(job)):
				if job != "" and not known.has(job):
					add(job, "unlocked")
				return ""
			g.rumors[lm] = true
			(card["map"] as Array).append({"kind": "rumor", "landmark": lm})
			if job != "":
				add(job, "unlocked")
			return _t("jt_r_rumor_got", {"name": _t(g.content.row("landmarks", lm)["name"])})
		"travel":
			var place := str(r.get("site", r.get("place", "")))
			if travel_open.has(place):
				return _dup(value)
			travel_open[place] = true
			(card["map"] as Array).append({"kind": "travel", "place": place})
			return _t(str(r["label"])) if r.has("label") else _t("jt_r_travel", {"name": g.travel_name(place)})
		"reveal":
			var at := Vector2.INF
			if r.has("landmark"):
				at = g.world.landmark_pos(str(r["landmark"]))
			elif r.has("point"):
				at = _point(str(r["point"]), 0)
			var rad := float(r.get("radius", 30))
			if r.has("radius_key"):
				rad = g.tuning.num(str(r["radius_key"]))
			if at != Vector2.INF:
				g.map.reveal_circle(at, rad)
				(card["map"] as Array).append({"kind": "reveal", "pos": at})
			return _t(str(r["label"]))
		"unlock":
			var what := str(r["what"])
			if unlocks.has(what):
				return _dup(value)
			unlocks[what] = true
			return _t("jt_r_unlock_" + what)
		"job":
			var id := str(r["job"])
			if not known.has(id):
				add(id, "unlocked")
			return _t("jt_r_job", {"name": def(id)["name"]}) if known.has(id) else ""
		"story":
			var text := _t(str(r["text"]))
			if bool(r.get("letter", false)):
				g.park.letters.append({"day": g.park.today(), "text": text, "read": false})
			else:
				g.park.add_note(text)
			return _t(str(r["label"]))
		"things":
			var items: Dictionary = r["items"]
			var parts: PackedStringArray = []
			var left_any := false
			for it: String in items:
				parts.append("%s x%d" % [g.content.item_name(it), int(items[it])])
				var left := g.backpack.add(it, int(items[it]))
				if left > 0:
					left_any = true
					(g.structures.chests["ranger_station"] as Inventory).add(it, left)
			var list := ", ".join(parts)
			if left_any:
				return _t("jt_r_things_chest", {"list": list, "place": _t(g.content.row("structures", "ranger_station")["name"])})
			return _t("jt_r_things_got", {"list": list})
		"card":
			g.park.cards.append({"day": g.park.today(), "text": _t("jt_thank_you_card"), "asks": false, "read": false, "pinned": false})
			return _t(str(r["label"]))
		"tip", "note":
			return _t(str(r["label"]))
	return ""


func _dup(value: int) -> String:
	if value <= 0:
		return ""
	var g := s()
	g.park.money.earn(g.park.today(), "jobs", value)
	return _t("jt_r_dup", {"n": value})


func _give_more(id: String) -> String:
	var g := s()
	var r := g.content.row("spoiler_more", id)
	var text := _t(r["text"])
	for e: Dictionary in r.get("effects", []):
		match str(e["kind"]):
			"notebook":
				g.park.add_note(text)
			"chest":
				var sid := str(e["structure"])
				if g.structures.chests.has(sid):
					for it: String in e["items"]:
						(g.structures.chests[sid] as Inventory).add(it, int(e["items"][it]))
			"stoves":
				for b in _open_buildings():
					g.structures.light_stove(b, g.tuning.integer("warmth.stove_minutes_per_firewood"))
	return text


## Takes a job off the clipboard at the season's turn (or a lost party found
## by others). Nothing done is lost: it simply goes.
func retire(k: String) -> void:
	if not known.has(k):
		return
	var st: Dictionary = known[k]
	if not bool(st["tpl"]):
		flags["retired:%s:%d" % [st["id"], s().clock.year]] = true
	known.erase(k)
	order.erase(k)
	_defs.erase(k)
	if pinned == k:
		pinned = ""
	if working == k:
		working = ""
	spots_changed.emit()
	job_retired.emit(k)


# --- mornings, seasons, templates -------------------------------------------------------

## Each morning: the season's turn on its first day, then template jobs
## topped up to their targets.
func morning(first_of_season: bool) -> void:
	var g := s()
	if first_of_season and g.clock.absolute_day() > 1:
		_season_turn()
	_draw_templates()
	update(true)


func _season_turn() -> void:
	var g := s()
	var retired := 0
	for k: String in order.duplicate():
		if not is_active(k):
			continue
		var st: Dictionary = known[k]
		var started := not (st["steps_done"] as Dictionary).is_empty() or not (st.get("live", {}) as Dictionary).is_empty()
		var d := def(k)
		var season := str(d.get("season", "until_done"))
		if started:
			continue
		if bool(st["tpl"]) and str(st["id"]) != "find_lost":
			retire(k)
			retired += 1
		elif season not in ["until_done", "template"] and season != g.clock.season_name():
			retire(k)
			retired += 1
	var before := order.size()
	_appear(true)
	cards.append({"kind": "season", "season": g.clock.season_name(), "retired": retired, "new": maxi(0, order.size() - before)})


func _draw_templates() -> void:
	var g := s()
	if not is_done("station_shipshape"):
		return
	rng.seed = hash([g.seed_value, g.clock.absolute_day()])
	for typ: String in ["upkeep", "trail"]:
		var target := g.tuning.integer("jobs.template_target_" + typ)
		var have := 0
		for k: String in order:
			if is_active(k) and bool(known[k]["tpl"]) and def(k)["type"] == typ:
				have += 1
		var per_morning := g.tuning.integer("jobs.templates_per_morning")
		var drawn := 0
		while have < target and drawn < per_morning:
			var cands := []
			for tid: String in _tpl:
				var r: Dictionary = _tpl[tid]
				if r["type"] != typ or bool(r.get("card", false)) or str(r["check"]) == "lost_party":
					continue
				for b: Dictionary in candidates(tid):
					var key := "tpl:%s:%s" % [tid, str(b.get("_at", ""))]
					if not is_active(key):
						cands.append([tid, b, key])
			if cands.is_empty():
				break
			var pick: Array = cands[rng.randi() % cands.size()]
			draw(pick[0], pick[1])
			have += 1
			drawn += 1


## Adds a template job now with its blanks. Returns its key, or "".
func draw(tid: String, blanks: Dictionary) -> String:
	var key := "tpl:%s:%s" % [tid, str(blanks.get("_at", ""))]
	if is_active(key):
		return ""
	if known.has(key):
		known.erase(key)
		order.erase(key)
	var b := blanks.duplicate()
	b["_note"] = rng.randi() % maxi(1, (_tpl[tid]["notes"] as Array).size())
	var st := _new_state(tid, true, b, "given")
	st["key"] = key
	_put(st)
	return key


## Where a template fits in the park now: a list of blanks, one per place.
func candidates(tid: String) -> Array:
	var g := s()
	var r: Dictionary = _tpl[tid]
	var out := []
	var check_id := str(r["check"])
	var open_places: Array = ["gate"]
	for id: String in g.sites_open:
		open_places.append(id)
	match check_id:
		"bath_grubby":
			for pad: String in g.park.built_pads("bathroom"):
				if g.park.bath_state(pad) in ["grubby", "filthy"]:
					var pl := str(g.park.pad_row(pad).get("place", g.park.place_of(g.park.pad_center(pad))))
					out.append(_blanks(pl, {"pad": pad}))
		"cans_full":
			for pl: String in open_places:
				if g.park.cans_need_emptying(pl, g.tuning.num("jobs.cans_full_share")):
					out.append(_blanks(pl, {}))
		"litter_near":
			for pl: String in open_places:
				var n := g.park.litter_near(g.park.place_spot(pl), 14.0)
				if n >= g.tuning.integer("jobs.litter_template_min"):
					out.append(_blanks(pl, {"count": n}))
		"few_cans":
			for pl: String in open_places:
				if pl == "gate":
					continue
				var cans := 0
				for t: Vector2i in g.park.things:
					if str(g.park.things[t]["id"]) == "trash_can" and g.park.place_of(Vector2(t)) == pl:
						cans += 1
				if cans < 2 and g.park.visits_week(pl) > 0:
					out.append(_blanks(pl, {"count": 2 - cans}))
		"no_bench":
			for pl: String in open_places:
				if pl == "gate":
					continue
				var has := false
				for t: Vector2i in g.park.things:
					if str(g.park.things[t]["id"]) == "bench" and g.park.place_of(Vector2(t)) == pl:
						has = true
				if not has:
					out.append(_blanks(pl, {}))
		"low_firewood":
			for b in _open_buildings():
				if g.structures.chests.has(b) and (g.structures.chests[b] as Inventory).count("firewood") < g.tuning.integer("jobs.restock_below"):
					var bl := _blanks("", {"structure": b, "building": _t(g.content.row("structures", b)["name"])})
					bl["_at"] = b
					out.append(bl)
		"badger_at":
			for b: Dictionary in g.park.badgers:
				if int(b["away_until"]) <= g.clock.absolute_day():
					out.append(_blanks(str(b["place"]), {}))
		"diggings":
			var seen := {}
			for t: Vector2i in g.park.diggings:
				var pl := g.park.place_of(Vector2(t))
				if pl != "" and not seen.has(pl):
					seen[pl] = true
					out.append(_blanks(pl, {}))
		"name_sign_gone":
			for id: String in g.sites_open:
				if not g.site_signed(id):
					out.append(_blanks(id, {}))
		"tree_down", "junction_no_pointer":
			pass   # needs storms that drop trees, and named junctions: not yet in the game
	return out


func _blanks(place: String, extra: Dictionary) -> Dictionary:
	var g := s()
	var b := {"site": g.park.place_name(place) if place != "" else "", "site_id": place, "_at": place}
	b.merge(extra, true)
	return b


## A suggestion card that asks for something: its template, filled. {} if
## the card's ask has none.
func card_template(card: Dictionary) -> Dictionary:
	var ev := str(card.get("event", ""))
	var map := {"want_bench": "v_bench", "want_picnic": "v_picnic", "bathroom_filthy": "v_bathroom", "lost_home": "v_sign", "no_trash_can": "v_cans"}
	if not map.has(ev) or not _tpl.has(map[ev]):
		return {}
	var g := s()
	var place := str(card.get("place", "gate"))
	var b := _blanks(place, {"card": str(card["text"])})
	if map[ev] == "v_bathroom":
		var pads := g.park.built_pads("bathroom", place)
		if pads.is_empty():
			return {}
		b["pad"] = pads[0]
	if map[ev] == "v_cans":
		b["count"] = 2
	b["_at"] = place + ":" + str(card.get("day", 0))
	b["_giver"] = _t("jt_giver_card", {"who": str(card.get("who", _t("jt_giver_visitors")))})
	return {"tid": map[ev], "blanks": b}


## Takes a card on as a job ("Take this on"). Returns the job's key or "".
func take_card(card: Dictionary) -> String:
	var t := card_template(card)
	if t.is_empty():
		return ""
	card["taken"] = true
	return draw(str(t["tid"]), t["blanks"])


# --- reading for the screens ----------------------------------------------------------

## The tab a job is on: "current", "noticed" or "done".
func tab_of(k: String) -> String:
	var st: Dictionary = known[k]
	if bool(st["finished"]):
		return "done"
	var started := not (st["steps_done"] as Dictionary).is_empty() or not (st.get("live", {}) as Dictionary).is_empty()
	if bool(st["noticed"]) and not started and pinned != k:
		return "noticed"
	return "current"


## The jobs on a tab, in the page's order: grouped by type; within a type
## pinned first, then most progress, then newest. Done: newest first.
func list(tab: String) -> Array[String]:
	var keys: Array[String] = []
	for k: String in order:
		if tab_of(k) == tab:
			keys.append(k)
	if tab == "done":
		keys.sort_custom(func(a: String, b: String) -> bool: return int(known[a]["fin_day"]) > int(known[b]["fin_day"]))
		return keys
	var idx := {}
	for i in order.size():
		idx[order[i]] = i
	keys.sort_custom(func(a: String, b: String) -> bool:
		var ta := TYPE_ORDER.find(def(a)["type"])
		var tb := TYPE_ORDER.find(def(b)["type"])
		if ta != tb:
			return ta < tb
		if (a == pinned) != (b == pinned):
			return a == pinned
		var pa := progress(a)
		var pb := progress(b)
		if pa != pb:
			return pa > pb
		return int(idx[a]) > int(idx[b]))
	return keys


## Steps done out of steps, as a share.
func progress(k: String) -> float:
	var d := def(k)
	var n := (d["steps"] as Array).size()
	return float(steps_done_count(k)) / float(maxi(1, n))


func steps_done_count(k: String) -> int:
	if is_done(k):
		return (def(k)["steps"] as Array).size()
	var d := def(k)
	var n := 0
	for i in (d["steps"] as Array).size():
		if bool(check(k, i)["done"]):
			n += 1
	return n


## The first step not done, or -1.
func next_step(k: String) -> int:
	if is_done(k):
		return -1
	var d := def(k)
	for i in (d["steps"] as Array).size():
		if not bool(check(k, i)["done"]):
			return i
	return -1


## The job the pinned note shows: pinned, else the one last worked on.
func shown_job() -> String:
	if pinned != "" and is_active(pinned):
		return pinned
	if working != "" and is_active(working):
		return working
	return ""


func active_count() -> int:
	var n := 0
	for k: String in order:
		if is_active(k):
			n += 1
	return n


func toggle_pin(k: String) -> void:
	pinned = "" if pinned == k else k


## The job a step links to, or "" (a step another job would complete).
func link_of(k: String, i: int) -> String:
	var stp: Dictionary = def(k)["steps"][i]
	var l := str(stp.get("link", ""))
	return l if known.has(l) and not bool(check(k, i)["done"]) else ""


## Where a job's next step happens, in tiles, or Vector2.INF. A place not yet
## found is never given away: those steps have no spot.
func step_pos(k: String, i: int) -> Vector2:
	var g := s()
	if i < 0:
		return Vector2.INF
	var stp: Dictionary = def(k)["steps"][i]
	match str(stp["kind"]):
		"pack":
			return g.door_front("ranger_station")
		"find":
			return Vector2.INF
		"map", "open", "sign", "join_trail":
			if stp.has("site"):
				if not g.sites_found.has(str(stp["site"])):
					return Vector2.INF
				if str(stp["kind"]) == "join_trail":
					var gp := g.trail_gap(str(stp["site"]))
					if not gp.is_empty():
						return Vector2(gp["b"]) + Vector2(0.5, 0.5)
				return g.site_door(str(stp["site"]))
			if stp.has("landmark"):
				return g.world.landmark_pos(str(stp["landmark"])) if seen_landmarks.has(str(stp["landmark"])) else Vector2.INF
			if stp.has("point"):
				return _point(str(stp["point"]), 0)
			if stp.has("at"):
				return _where(k, str(stp["at"]))
		"repair":
			if stp.has("spot"):
				return spot_pos(str(stp["spot"]))
			return g.door_front(str(stp["structure"]))
		"dig":
			if stp.has("gap"):
				var gp := gap(str(stp["gap"]))
				if not gp.is_empty():
					return Vector2(float(gp["a"][0]) + 0.5, float(gp["a"][1]) + 0.5)
		"clear":
			var tg := _clear_targets(stp)
			for sp: String in tg["spots"]:
				if not spots_done.has(sp):
					return spot_pos(sp)
			for t: Vector2i in tg["tiles"]:
				if not g.obstacle_at(t).is_empty():
					return Vector2(t) + Vector2(0.5, 0.5)
		"clean":
			if stp.has("spots"):
				for sp: String in stp["spots"]:
					if not spots_done.has(sp):
						return spot_pos(sp)
			elif str(stp.get("bathroom", "")) not in ["", "all"]:
				return g.park.pad_center(str(stp["bathroom"]))
		"place", "pick_up", "go_to", "survey":
			if str(stp.get("at", "")) == "open_buildings":
				return Vector2.INF
			return _where(k, str(stp["at"]))
		"deliver":
			if stp.has("spot"):
				return spot_pos(str(stp["spot"]))
			if str(stp["chest"]) != "open_buildings":
				return g.door_front(str(stp["chest"]))
		"empty", "shoo":
			return g.park.place_spot(str(stp["place"]))
		"talk_to":
			if str(stp["party"]) == "lost":
				return _where(k, "lost")
			return _where(k, "scout_camp")
		"light":
			return Vector2.INF
	return Vector2.INF


## The dig gaps of every active job, for the map's red flags: [{a, b}].
func dig_gaps() -> Array:
	var out := []
	for k: String in order:
		if not is_active(k):
			continue
		var d := def(k)
		for i in (d["steps"] as Array).size():
			var stp: Dictionary = d["steps"][i]
			if str(stp["kind"]) == "dig" and stp.has("gap") and not bool(check(k, i)["done"]):
				var gp := gap(str(stp["gap"]))
				if not gp.is_empty():
					out.append({"a": Vector2i(int(gp["a"][0]), int(gp["a"][1])), "b": Vector2i(int(gp["b"][0]), int(gp["b"][1]))})
			elif str(stp["kind"]) == "join_trail" and stp.has("site") and not stp.has("from_site") and not bool(check(k, i)["done"]) and s().map.is_landmark_mapped(str(s().content.row("sites", stp["site"])["landmark"])):
				var gp := s().trail_gap(str(stp["site"]))
				if not gp.is_empty() and link_of(k, i) == "":
					out.append(gp)
	return out


## The map's markers: one per active job with a known next step:
## [{pos, color, pinned, name, step}].
func map_marks() -> Array:
	var out := []
	var shown := shown_job()
	for k: String in order:
		if not is_active(k):
			continue
		var i := next_step(k)
		var p := step_pos(k, i)
		if p == Vector2.INF:
			continue
		out.append({"pos": p, "color": type_color(def(k)["type"]), "pinned": k == shown, "name": def(k)["name"], "step": step_label(k, i), "key": k})
	return out


## Takes the next card waiting to be shown, or {}.
func take_card_to_show() -> Dictionary:
	if cards.is_empty():
		return {}
	# The season's card first.
	for i in cards.size():
		if str(cards[i]["kind"]) == "season":
			var c: Dictionary = cards[i]
			cards.remove_at(i)
			return c
	var c: Dictionary = cards[0]
	cards.remove_at(0)
	return c


func mark_seen(k: String) -> void:
	if known.has(k):
		known[k]["new"] = false


func any_new(tab: String) -> bool:
	for k: String in list(tab):
		if bool(known[k]["new"]):
			return true
	return false


# --- debug --------------------------------------------------------------------------------

func debug_finish(k: String) -> void:
	if not is_active(k):
		return
	var d := def(k)
	for i in (d["steps"] as Array).size():
		known[k]["steps_done"][str(i)] = true
		if not known[k].has("live"):
			known[k]["live"] = {}
		known[k]["live"][str(i)] = true
	_finish(k)


func debug_reset(k: String) -> void:
	if not known.has(k):
		return
	var st: Dictionary = known[k]
	st["steps_done"] = {}
	st["broken"] = {}
	st["counts"] = {}
	st["q"] = {}
	st["live"] = {}
	st["finished"] = false
	st["paid"] = false


func debug_lines(spoilers: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in order:
		var d := def(k)
		if bool(known[k]["noticed"]) and not spoilers:
			out.append("(noticed job: hidden)")
			continue
		out.append("%s  %s  %d/%d" % [k, "DONE" if is_done(k) else "", steps_done_count(k), (d["steps"] as Array).size()])
	return out
