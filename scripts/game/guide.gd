class_name Guide
extends RefCounted
## Plain help that follows the ranger around, so it is always clear what can
## be done:
##   x_hint()     what X does here, in a few words ("" when nothing)
##   use_hint()   what C does with the held item here
##   aim()        the tile the held item would go on, and whether it may
##   markers()    where a "?" floats: something new to read or do there
##   next_steps() the one next thing for each site and job, for the book
## The hints show on hover: x_hint_at() for the thing under the mouse, and
## use_hint(item) for an item-bar slot under the mouse.
## It only reads the session; it never changes the game.

var _s: WeakRef


func _init(session: GameSession) -> void:
	_s = weakref(session)


func _t(id: String, args: Dictionary = {}) -> String:
	return (_s.get_ref() as GameSession).content.text(id, args)


# --- X -------------------------------------------------------------------------

func x_hint() -> String:
	var s: GameSession = _s.get_ref()
	if s.pending_confirm != "":
		return ""
	if s.is_indoors():
		return _x_inside(s)
	var reach := s.tuning.num("world.interact_reach_tiles")
	var sid := s.structure_at_door(s.outdoor_pos)
	if sid != "":
		var lm := s._landmark_for_structure(sid)
		if lm != "" and not s.map.is_landmark_mapped(lm):
			return _t("hint_x_map")
		var site := s.site_for_structure(sid)
		if site != "" and not s.sites_open.has(site) and s.site_ready(site):
			return _t("hint_x_open_site")
		return _t("hint_x_go_in") if s.structures.is_open(sid) else _t("hint_x_locked")
	if not s.camp.is_empty():
		if s.outdoor_pos.distance_to(Vector2(s.camp["bed"]) + Vector2(0.5, 0.5)) <= reach:
			return _t("hint_x_camp_sleep")
		if s.outdoor_pos.distance_to(Vector2(s.camp["fire"]) + Vector2(0.5, 0.5)) <= reach:
			return _t("hint_x_cook") if s.campfire_lit() else _t("hint_x_feed_fire")
	var park := _x_park(s, reach)
	if park != "":
		return park
	if s.pile_in_reach().x >= 0:
		return _t("hint_x_pile")
	if s.forage_in_reach().x >= 0:
		return _t("hint_x_gather")
	if s.object_forage_in_reach().x >= 0:
		return _t("hint_x_pick")
	if s.placed_in_reach().x >= 0:
		return _t("hint_x_read_sign")
	var obj := s.world.interactive_near(s.outdoor_pos, reach + 0.5)
	if obj.is_empty():
		return ""
	if s.seasonal_hidden.has(Vector2i(floori(obj["pos"].x), floori(obj["pos"].y))) or s._hidden_near(obj["pos"]):
		return ""
	var what: String = obj["interact"]
	if what.begins_with("find:"):
		return _t("hint_x_look")
	if what.begins_with("landmark:") and not s.map.is_landmark_mapped(what.substr(9)):
		return _t("hint_x_map")
	return ""


## What X does at a point (in tiles) the mouse is over, as if the ranger
## stood there: the thing there, and what X does with it. Pointing at a
## building counts as pointing at its door. "" when nothing is there.
func x_hint_at(p: Vector2) -> String:
	var s: GameSession = _s.get_ref()
	if s.pending_confirm != "":
		return ""
	if s.is_indoors():
		var keep_in := s.interior_pos
		s.interior_pos = p
		var hi := _x_inside(s)
		s.interior_pos = keep_in
		return hi
	for st: Dictionary in s.world.meta["structures"]:
		var r := Rect2(float(st["pos"][0]), float(st["pos"][1]), float(st["size"][0]), float(st["size"][1]))
		r = r.grow_side(SIDE_TOP, r.size.y)
		if r.has_point(p):
			p = Vector2(float(st["door"][0]) + 0.5, float(st["door"][1]) + 1.0)
	var keep := s.outdoor_pos
	s.outdoor_pos = p
	var h := x_hint()
	s.outdoor_pos = keep
	return h


func _x_inside(s: GameSession) -> String:
	var layout: InteriorLayout = s.interiors[s.location]
	var f := layout.furniture_near(s.interior_pos, s.tuning.num("world.interact_reach_tiles"))
	if f.is_empty():
		return ""
	var kind := str(f["kind"])
	if kind == "stove":
		return _t("hint_x_cook") if s.structures.stove_lit(s.location) else _t("hint_x_light_stove")
	return _t("hint_x_" + kind) if s.content.has("text", "hint_x_" + kind) else ""


func _x_park(s: GameSession, reach: float) -> String:
	var lp := s.park.lost_party()
	if not lp.is_empty() and s.outdoor_pos.distance_to(lp["pos"]) <= s.tuning.num("visitors.lost_find_reach_tiles"):
		return _t("hint_x_lost")
	if s.park.badger_near(s.outdoor_pos, s.tuning.num("badgers.reach_tiles")) >= 0:
		return _t("hint_x_badger")
	if s.litter_in_reach().x >= 0:
		return _t("hint_x_litter")
	var th := s.thing_in_reach()
	if th.x >= 0:
		match str(s.park.things[th]["id"]):
			"trash_can":
				return _t("hint_x_trash_can")
			"fire_ring":
				return _t("hint_x_fire_ring") if int(s.park.things[th]["lit"]) <= 0 else ""
		return ""
	if s.structures.is_open("test_cabin") and s.outdoor_pos.distance_to(Vector2(s.rent_sign_tile()) + Vector2(0.5, 0.5)) <= reach:
		return _t("hint_x_rent_sign")
	var pad := s.pad_in_reach(reach)
	if pad == "":
		return ""
	var fac: String = s.park.pad_row(pad)["facility"]
	match s.park.pad_state(pad):
		"":
			return _t("hint_x_pad")
		"ordered":
			return _t("hint_x_pad_ordered")
		"kit", "building":
			return _t("hint_x_pad_build")
		"built":
			if s.content.has("text", "hint_x_fac_" + fac):
				return _t("hint_x_fac_" + fac)
	return ""


# --- C -------------------------------------------------------------------------

func use_hint(item: String = "") -> String:
	var s: GameSession = _s.get_ref()
	if item == "":
		item = s.selected_item()
	if item == "" or s.pending_confirm != "":
		return ""
	var row := s.content.row("items", item)
	var kind := str(row["kind"])
	var front := s.ranger_tile() + s.facing_vector()
	if kind == "food":
		return _t("hint_c_eat")
	if kind == "park_thing":
		if s.is_indoors():
			return _t("hint_c_outdoors")
		var why := s.park.place_problem(front)
		return _t("hint_c_put", {"item": s.content.item_name(item).to_lower()}) if why == "" else _t("hint_c_cant", {"why": _t(why)})
	if kind == "placeable" and row.has("lays"):
		return _t("hint_c_boardwalk") if boardwalk_ok(front) else _t("hint_c_boardwalk_where")
	if kind == "placeable":
		if s.is_indoors():
			return _t("hint_c_outdoors")
		var why := s.place_problem(front, item)
		return _t("hint_c_put", {"item": s.content.item_name(item).to_lower()}) if why == "" else _t("hint_c_cant", {"why": _t(why)})
	if kind == "kit":
		return _t("hint_c_kit") if s.is_indoors() else _t("hint_c_kit_where")
	match item:
		"hammer":
			return _hammer_hint(s, front)
		"map":
			var why := s._survey_conditions_ok()
			return _t("hint_c_survey") if why == "" else _t("hint_c_cant", {"why": _t(why)})
		"axe":
			if not s.obstacle_in_reach("axe").is_empty():
				return _t("hint_c_clear")
			return _t("hint_c_chop") if s.tree_in_reach().x >= 0 else _t("hint_c_axe_what")
		"saw":
			return _t("hint_c_saw") if not s.obstacle_in_reach("saw").is_empty() else _t("hint_c_saw_what")
		"shovel":
			return _t("hint_c_dig") if s.can_dig(front) else _t("hint_c_dig_where")
		"firewood":
			if s.fire_ring_in_reach().x >= 0:
				return _t("hint_x_fire_ring")
			if s.is_indoors() and not (s.interiors[s.location] as InteriorLayout).find("stove").is_empty():
				return _t("hint_x_light_stove")
			return ""
	if s.family_of(item) == "bedroll":
		return _t("hint_c_camp") if not s.is_indoors() else _t("hint_c_outdoors")
	return ""


func _hammer_hint(s: GameSession, front: Vector2i) -> String:
	if not s.is_indoors():
		if s.placed.has(front):
			return _t("hint_c_take_down")
		if s.thing_in_reach().x >= 0:
			return _t("hint_c_pick_up_thing")
		var pad := s.pad_in_reach(s.tuning.num("facilities.reach_tiles"))
		if pad != "" and s.park.pad_state(pad) in ["kit", "building"]:
			return _t("hint_c_build")
	for id in s.structures.ids():
		if not s.structures.is_open(id) and s.near_structure(id, s.tuning.num("repair.reach_tiles")):
			return _t("hint_c_repair")
	return _t("hint_c_hammer_what")


func boardwalk_ok(t: Vector2i) -> bool:
	var s: GameSession = _s.get_ref()
	if s.is_indoors():
		return false
	var on: Array = s.tuning.value("trail.boardwalk_on")
	return s.world.in_bounds(t) and not s.world.is_solid(t) and not s.boardwalk.has(t) and on.has(s.world.ground_at(t)) and s.forage.magic_at(t) == ""


## The tile the held item would go on and whether it may: {tile, ok}, or {}
## when the held item is not put anywhere.
func aim() -> Dictionary:
	var s: GameSession = _s.get_ref()
	if s.is_indoors():
		return {}
	var item := s.selected_item()
	if item == "":
		return {}
	var row := s.content.row("items", item)
	var t := s.ranger_tile() + s.facing_vector()
	match str(row["kind"]):
		"placeable":
			return {"tile": t, "ok": boardwalk_ok(t) if row.has("lays") else s.place_problem(t, item) == ""}
		"park_thing":
			return {"tile": t, "ok": s.park.place_problem(t) == ""}
	if item == "shovel":
		return {"tile": t, "ok": s.can_dig(t)}
	return {}


# --- "?" markers ---------------------------------------------------------------

## Where a "?" floats, in tiles: outdoors, or in the room the ranger is in.
## The note board with unread jobs, notes or letters; the suggestion box with
## cards; the supply shelf with an order in; a site ready to open; a pad with
## its kit waiting. Outdoors, a building whose inside has one shows it over
## its door.
func markers() -> Array[Vector2]:
	var s: GameSession = _s.get_ref()
	var out: Array[Vector2] = []
	if s.is_indoors():
		var layout: InteriorLayout = s.interiors[s.location]
		for f: Dictionary in layout.furniture:
			if _furniture_new(s, s.location, str(f["kind"])):
				var r := layout.furniture_rect(f)
				out.append(Vector2(r.position.x + r.size.x / 2.0, r.position.y - 0.6))
		return out
	for id: String in s.interiors:
		for f: Dictionary in (s.interiors[id] as InteriorLayout).furniture:
			if _furniture_new(s, id, str(f["kind"])):
				out.append(s.door_front(id) + Vector2(0, -2.6))
				break
	for row: Dictionary in s.content.rows("sites"):
		var site: String = row["id"]
		if s.sites_found.has(site) and not s.sites_open.has(site) and s.site_ready(site):
			out.append(s.site_door(site) + Vector2(0, -2.6))
	for pad: String in s.park.pads:
		var st := s.park.pad_state(pad)
		var fac := str(s.park.pad_row(pad)["facility"])
		if st in ["kit", "building"] or (st == "built" and fac == "suggestion_box" and not s.park.unread_cards().is_empty()):
			var pr := s.park.pad_row(pad)
			out.append(Vector2(float(pr["pos"][0]) + float(pr["size"][0]) / 2.0, float(pr["pos"][1]) - 0.8))
	return out


func _furniture_new(s: GameSession, where: String, kind: String) -> bool:
	match kind:
		"note_board":
			if where == "ranger_station":
				for j: Dictionary in s.content.rows("jobs"):
					if not s.jobs_known.has(j["id"]):
						return true
				if not s.park.unread_letters().is_empty():
					return true
			for n: Dictionary in s.content.rows("notes"):
				if n["at"] == where and s.structures.is_open(n["needs_open"]) and not s.notes_read.has(n["id"]):
					return true
		"shelf":
			# Something on the shelf the ranger hasn't looked at yet.
			if not s.structures.shelves.has(where):
				return false
			var shelf: Inventory = s.structures.shelves[where]
			return not shelf.is_empty() and str(shelf.to_array()) != str(s.shelf_seen.get(where, ""))
	return false


# --- what's next ---------------------------------------------------------------

## The one next thing to do for each site found and not yet open, in plain
## words: what to do, and with what.
func next_steps() -> PackedStringArray:
	var s: GameSession = _s.get_ref()
	var out := PackedStringArray()
	for row: Dictionary in s.content.rows("sites"):
		var id: String = row["id"]
		if not s.sites_found.has(id) or s.sites_open.has(id):
			continue
		var name := s.content.text(row["name"])
		var step := ""
		for st in GameSession.SITE_STEPS:
			if not s.site_step_done(id, st):
				step = st
				break
		var what := _t("next_open") if step == "" else _t("next_" + step, {"n": s.tuning.integer("sites.sign_distance_tiles")})
		out.append(_t("next_line", {"name": name, "what": what}))
	return out


# --- job cards (tracker #2 and #3) ----------------------------------------------

## One card for each site the ranger knows about (found, or offered as a job
## on the note board), with its steps in order. Gathering what to bring comes
## first, counted for every step still to do, so a trip out is never wasted:
## [{id, title, open, steps: [{key, text, done}], next}]. "next" is the first
## step not done, or "".
func job_cards() -> Array:
	var s: GameSession = _s.get_ref()
	var c := s.content
	var known := {}
	for j: Dictionary in c.rows("jobs"):
		if s.jobs_known.has(j["id"]):
			known[str(j["structure"])] = j
	var out := []
	for row: Dictionary in c.rows("sites"):
		var id: String = row["id"]
		var sid := str(row["structure"])
		if not s.sites_found.has(id) and not known.has(sid):
			continue
		var name := c.text(row["name"])
		var title := c.text(known[sid]["title"]) if known.has(sid) else c.text("job_site_title", {"name": name})
		var steps := []
		var need := _bring_for(s, id, row)
		if not need.is_empty():
			var parts: PackedStringArray = []
			var all := true
			for item: String in need:
				var have := s.backpack.count(item)
				parts.append(c.text("job_item", {"name": c.item_name(item), "have": mini(have, int(need[item])), "need": need[item]}))
				all = all and have >= int(need[item])
			steps.append({"key": "gather", "text": c.text("job_step_gather", {"list": ", ".join(parts)}), "done": all})
		for st in GameSession.SITE_STEPS:
			# No building, nothing to repair; nothing strange, nothing to settle.
			if (st == "repair" and sid == "") or (st == "settle" and not bool(row.get("magic", false))):
				continue
			var done := s.site_step_done(id, st)
			var text := ""
			match st:
				"find":
					text = c.text("job_step_find")
				"map":
					text = c.text("job_step_map")
				"reach":
					var gap := s.trail_gap(id) if not done else {}
					var tiles := 0
					if not gap.is_empty():
						tiles = roundi(Vector2(gap["a"]).distance_to(Vector2(gap["b"])))
					text = c.text("job_step_reach", {"n": tiles}) if not done else c.text("job_step_reach_done")
				"repair":
					var ps: PackedStringArray = []
					for rs: Dictionary in c.row("structures", sid)["repair_steps"]:
						var pname := c.text(rs["name"])
						if s.structures.step_done(sid, rs["id"]):
							ps.append(c.text("job_part_done", {"name": pname}))
						else:
							ps.append(c.text("job_part", {"name": pname, "done": int(s.structures.progress[sid][rs["id"]]), "total": s.structures.actions_per_step()}))
					text = c.text("job_step_repair", {"list": ", ".join(ps)})
				"sign":
					text = c.text("job_step_sign", {"n": s.tuning.integer("sites.sign_distance_tiles")})
				"settle":
					text = c.text("job_step_settle")
			steps.append({"key": st, "text": text, "done": done})
		var is_open := s.sites_open.has(id)
		steps.append({"key": "open", "text": c.text("job_step_open"), "done": is_open})
		var nxt := ""
		for st: Dictionary in steps:
			if not bool(st["done"]):
				nxt = st["key"]
				break
		out.append({"id": id, "title": title, "open": is_open, "steps": steps, "next": nxt, "handy": known[sid].get("suggested", []) if known.has(sid) else []})
	return out


## What to bring for every step of a site still to do: {item: count}. The
## repair's materials for parts not yet started, the hammer, the shovel for a
## trail still to join, and a sign and the hammer for a sign still to go up.
func _bring_for(s: GameSession, id: String, row: Dictionary) -> Dictionary:
	var need := {}
	var sid := str(row["structure"])
	if sid != "" and not s.site_step_done(id, "repair"):
		for rs: Dictionary in s.content.row("structures", sid)["repair_steps"]:
			if int(s.structures.progress[sid][rs["id"]]) > 0:
				continue
			for m: String in rs["materials"]:
				need[m] = int(need.get(m, 0)) + int(rs["materials"][m])
		need["hammer"] = 1
	if not s.site_step_done(id, "reach"):
		need["shovel"] = 1
	if not s.site_step_done(id, "sign"):
		need["trail_sign"] = 1
		need["hammer"] = 1
	return need


## The book's Jobs page: the job being worked on in full, step by step; the
## other open jobs in a line each with their next step; then the lost party
## and pinned cards; then what's done (tracker #3).
func job_page_lines() -> PackedStringArray:
	var s: GameSession = _s.get_ref()
	var c := s.content
	var out := PackedStringArray()
	var cards := job_cards()
	var open_cards := cards.filter(func(k: Dictionary) -> bool: return not bool(k["open"]))
	var done_cards := cards.filter(func(k: Dictionary) -> bool: return bool(k["open"]))
	if open_cards.is_empty():
		out.append(c.text("job_none" if cards.is_empty() else "job_all_done"))
	else:
		var cur: Dictionary = open_cards[0]
		out.append(c.text("job_current", {"title": cur["title"]}))
		for st: Dictionary in cur["steps"]:
			var mark := "job_mark_done" if bool(st["done"]) else ("job_mark_now" if st["key"] == cur["next"] else "job_mark_todo")
			out.append(c.text(mark, {"text": st["text"]}))
		if not (cur["handy"] as Array).is_empty():
			var h: PackedStringArray = []
			for it: String in cur["handy"]:
				h.append(c.item_name(it))
			out.append(c.text("job_handy", {"list": ", ".join(h)}))
		if open_cards.size() > 1:
			out.append("")
			out.append(c.text("job_others"))
			for k in range(1, open_cards.size()):
				var o: Dictionary = open_cards[k]
				out.append(c.text("job_other_line", {"title": o["title"], "next": c.text("job_label_" + str(o["next"]))}))
	var extra := s.park.job_extra_lines()
	if not extra.is_empty():
		out.append("")
		out.append_array(extra)
	if not done_cards.is_empty():
		out.append("")
		var t: PackedStringArray = []
		for k: Dictionary in done_cards:
			t.append(k["title"])
		out.append(c.text("job_done_list", {"list": ", ".join(t)}))
	return out


## The gaps to dig for every open job, for the map's flags: [{a, b}].
func trail_gaps() -> Array:
	var s: GameSession = _s.get_ref()
	var out := []
	for k: Dictionary in job_cards():
		if bool(k["open"]) or not s.site_step_done(k["id"], "map"):
			continue
		var g := s.trail_gap(k["id"])
		if not g.is_empty():
			out.append(g)
	return out
