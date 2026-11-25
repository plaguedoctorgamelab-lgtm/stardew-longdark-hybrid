class_name Guide
extends RefCounted
## Plain help that follows the ranger around, so it is always clear what can
## be done:
##   x_hint()     what X does here, in a few words ("" when nothing)
##   use_hint()   what C does with the held item here
##   aim()        the tile the held item would go on, and whether it may
##   markers()    where a "?" floats: something new to read or do there
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
	var js := s.jobs.spot_in_reach("x", s.outdoor_pos, reach)
	if js != "":
		return _t(str(s.jobs.spot_row(js)["verb"]))
	# A landmark to map or declare open comes first, as it does for X.
	var lm0 := s.world.interactive_near(s.outdoor_pos, reach + 0.5)
	var lm_first := false
	if not lm0.is_empty() and str(lm0["interact"]).begins_with("landmark:"):
		var lid0 := str(lm0["interact"]).substr(9)
		var site0 := s.site_for_landmark(lid0)
		lm_first = not s.map.is_landmark_mapped(lid0) or (site0 != "" and not s.sites_open.has(site0) and s.site_ready(site0))
	for tool: String in ([] if lm_first else ["hammer", "axe"]):
		var ts := s.jobs.spot_in_reach(tool, s.outdoor_pos, reach)
		if ts != "":
			return _t("hint_x_spot_tool", {"verb": _t(str(s.jobs.spot_row(ts)["verb"])), "tool": s.content.item_name(tool).to_lower()})
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
	if what.begins_with("landmark:"):
		var lid := what.substr(9)
		if not s.map.is_landmark_mapped(lid):
			return _t("hint_x_map")
		var site := s.site_for_landmark(lid)
		if site != "" and not s.sites_open.has(site) and s.site_ready(site):
			return _t("hint_x_open_site")
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
	if kind == "job_spot":
		return _t(str(s.jobs.spot_row(str(f["id"]))["verb"]))
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
	if item in ["axe", "hammer"] and not s.is_indoors():
		var js := s.jobs.spot_in_reach(item, s.outdoor_pos, s.tuning.num("clearing.reach_tiles"))
		if js != "":
			return _t(str(s.jobs.spot_row(js)["verb"]))
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
		if s.camp_in_reach():
			return _t("hint_c_pack_camp")
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
			if where == "ranger_station" and not s.park.unread_letters().is_empty():
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


## Where the ranger can get an item, in a few words, or "": the chest,
## supply shelf or workbench box of a building they can get into (the station
## first), else how to make, order or gather it.
func where_to_get(item: String) -> String:
	var s: GameSession = _s.get_ref()
	var c := s.content
	var open_ids: Array[String] = []
	for id: String in s.structures.ids():
		if s.structures.is_open(id):
			if id == "ranger_station":
				open_ids.push_front(id)
			else:
				open_ids.append(id)
	for id in open_ids:
		if s.structures.chests.has(id) and (s.structures.chests[id] as Inventory).has(item):
			return c.text("where_chest", {"place": c.text(c.row("structures", id)["name"])})
	for id in open_ids:
		if s.structures.shelves.has(id) and (s.structures.shelves[id] as Inventory).has(item):
			return c.text("where_shelf", {"place": c.text(c.row("structures", id)["name"])})
	for id: String in s.bench_boxes:
		if (s.bench_boxes[id] as Inventory).has(item):
			return c.text("where_bench", {"place": c.text(c.row("structures", id)["name"])})
	for r: Dictionary in c.rows("recipes"):
		if s.recipes_known.has(r["id"]) and str((r["result"] as Dictionary).get("item", "")) == item:
			return c.text("where_make", {"where": c.text("ui_where_" + str(r["station"]))})
	for r: Dictionary in c.rows("catalog"):
		if str(r.get("item", "")) == item:
			return c.text("where_order")
	for r: Dictionary in c.rows("forage"):
		if str(r.get("item", "")) == item and not bool(r.get("magic", false)):
			return c.text("where_gather")
	return ""


## The gaps to dig for every open job, for the map's flags: [{a, b}].
func trail_gaps() -> Array:
	var s: GameSession = _s.get_ref()
	return s.jobs.dig_gaps()
