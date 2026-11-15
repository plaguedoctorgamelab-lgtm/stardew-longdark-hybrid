class_name GameSession
extends RefCounted
## One running game. Owns every system and wires them together through their
## signals. Holds the game rules that span systems: what happens each ten
## minutes, collapse and rescue, sleeping, repairs, surveys and saving.
## It draws nothing, so the automated tests drive it directly; the scene tree
## only shows it. Every debug action is a method here.

signal message(text: String)
signal storage_opened(title: String, inventory: Inventory)
signal radio_heard(lines: PackedStringArray)
signal confirm_requested(kind: String, text: String)
signal location_changed(location: String)
signal collapsed(text: String)
signal saved(ok: bool)
signal day_began
signal survey_changed(active: bool, progress: float)
signal camp_changed
signal tree_changed(tile: Vector2i)
signal note_read(text: String)
signal land_changed(tile: Vector2i)
signal workbench_opened
signal choice_requested(kind: String, title: String, options: Array)

const FACING_DOWN := 0
const FACING_RIGHT := 1
const FACING_UP := 2
const FACING_LEFT := 3

var tuning: Tuning
var content: ContentDB
var world: WorldData
var clock: GameClock
var weather: WeatherSystem
var needs: Needs
var backpack: Inventory
var structures: Structures
var map: MapState
var interiors: Dictionary = {}   # structure id -> InteriorLayout

var seed_value: int = 0
var save_path: String = SaveSystem.slot_path(1)

# Ranger state. Positions are in tiles; the point is the middle of the feet.
var outdoor_pos: Vector2 = Vector2.ZERO
var interior_pos: Vector2 = Vector2.ZERO
var location: String = ""        # "" outdoors, or the structure id when inside
var facing: int = FACING_DOWN
var selected_slot: int = 0
var moving: bool = false

# Within the current ten-minute step.
var _walked_this_step: float = 0.0
var _rough_this_step: bool = false
var _last_tile: Vector2i = Vector2i(-9999, -9999)

var survey_steps_left: int = 0
var pending_confirm: String = ""
var collapse_count: int = 0
var save_count: int = 0
var debug_overlay: bool = false
var _collapsing: bool = false

# The ranger's camp, if one is made: {"bed": Vector2i, "fire": Vector2i, "fire_minutes": int}.
var camp: Dictionary = {}
# Chopped trees: tile -> the absolute day it was chopped. They regrow.
var chopped: Dictionary = {}
# Jobs the ranger has read about: id -> true.
var jobs_known: Dictionary = {}
# Rumored places the ranger has heard of: landmark id -> true.
var rumors: Dictionary = {}
# Notes from the last ranger already read: note id -> true.
var notes_read: Dictionary = {}
# Changes to the land in this save. The baked world never changes.
var cleared: Dictionary = {}            # obstacle's top-left tile -> obstacle id, cleared for good
var clearing_progress: Dictionary = {}  # obstacle's top-left tile -> actions done so far
var dug: Dictionary = {}                # tile -> true, trail dug by the ranger
var placed: Dictionary = {}             # tile -> {"item": id, "place": id}, signs and markers put up
var _pending_place: Vector2i = Vector2i(-1, -1)
# Sites: places to open. Found and opened sites, and debug overrides.
var sites_found: Dictionary = {}       # site id -> true
var sites_open: Dictionary = {}        # site id -> true
var site_overrides: Dictionary = {}    # "site:step" -> bool, debug only
var _pending_site: String = ""
# Hidden things noticed: id -> true. Objects away for the season: tile -> true.
var finds_found: Dictionary = {}
var seasonal_hidden: Dictionary = {}
var _pending_item: String = ""


func _init(tuning_path: String = Tuning.DEFAULT_PATH, content_dir: String = ContentDB.CONTENT_DIR, world_dir: String = WorldData.WORLD_DIR) -> void:
	tuning = Tuning.new(tuning_path)
	content = ContentDB.new(content_dir)
	world = WorldData.new(world_dir)
	clock = GameClock.new(tuning)
	weather = WeatherSystem.new(tuning, content)
	needs = Needs.new(tuning)
	backpack = Inventory.new(content, tuning.integer("storage.backpack_slots"))
	structures = Structures.new(content, tuning)
	map = MapState.new(world.width, world.height, world.explorable_mask(), world.chunk_size)
	for r: Dictionary in content.rows("structures"):
		interiors[r["id"]] = InteriorLayout.new(r)
	clock.step_passed.connect(_on_step)
	clock.day_started.connect(_on_day_started)
	clock.day_end_reached.connect(_on_day_end)
	needs.ran_out.connect(_on_ran_out)


# --- starting and loading ---------------------------------------------------

func new_game(new_seed: int = -1) -> void:
	if new_seed < 0:
		new_seed = randi()
	seed_value = new_seed
	clock.day = 1
	clock.season = 0
	clock.year = 1
	clock.set_minute(tuning.integer("time.day_start_minute"))
	weather.new_game(seed_value, clock.absolute_day())
	needs.refill()
	backpack.clear()
	for item in ["hammer", "lantern", "map", "compass", "pencil"]:
		backpack.add(item)
	structures.place_found_supplies(seed_value)
	structures.restock_shelves()
	map.wipe()
	# The ground around the station starts mapped, so home is never lost.
	map.reveal_circle(door_front("ranger_station"), tuning.num("map.home_reveal_radius"))
	location = ""
	outdoor_pos = world.spawn("station")
	facing = FACING_DOWN
	selected_slot = 0
	survey_steps_left = 0
	_last_tile = Vector2i(-9999, -9999)
	camp = {}
	for t: Vector2i in chopped.keys():
		_set_chopped(t, -1)
	jobs_known = {}
	rumors = {}
	notes_read = {}
	sites_found = {}
	sites_open = {}
	site_overrides = {}
	finds_found = {}
	_reset_land()
	_apply_seasons()
	camp_changed.emit()
	weather.check_change(clock.minute)


func to_dict() -> Dictionary:
	return {
		"seed": seed_value,
		"clock": clock.to_dict(),
		"weather": weather.to_dict(),
		"ranger": {
			"outdoor_pos": [outdoor_pos.x, outdoor_pos.y],
			"interior_pos": [interior_pos.x, interior_pos.y],
			"location": location,
			"facing": facing,
			"selected_slot": selected_slot,
		},
		"needs": needs.to_dict(),
		"backpack": backpack.to_array(),
		"structures": structures.to_dict(),
		"map": map.to_dict(),
		"camp": {} if camp.is_empty() else {
			"bed": [camp["bed"].x, camp["bed"].y],
			"fire": [camp["fire"].x, camp["fire"].y],
			"fire_minutes": camp["fire_minutes"],
		},
		"chopped": chopped.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, chopped[t]]),
		"jobs_known": jobs_known.keys(),
		"rumors": rumors.keys(),
		"notes_read": notes_read.keys(),
		"sites": {"found": sites_found.keys(), "open": sites_open.keys()},
		"finds": finds_found.keys(),
		"land": land_to_dict(),
	}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	clock.from_dict(d["clock"])
	weather.from_dict(d["weather"])
	var r: Dictionary = d["ranger"]
	outdoor_pos = Vector2(float(r["outdoor_pos"][0]), float(r["outdoor_pos"][1]))
	interior_pos = Vector2(float(r["interior_pos"][0]), float(r["interior_pos"][1]))
	location = r["location"]
	facing = int(r["facing"])
	selected_slot = int(r["selected_slot"])
	needs.from_dict(d["needs"])
	backpack.from_array(d["backpack"])
	structures.from_dict(d["structures"])
	map.from_dict(d["map"])
	# Added after the first phase one saves; older saves simply have none.
	var c: Dictionary = d.get("camp", {})
	camp = {} if c.is_empty() else {
		"bed": Vector2i(int(c["bed"][0]), int(c["bed"][1])),
		"fire": Vector2i(int(c["fire"][0]), int(c["fire"][1])),
		"fire_minutes": int(c["fire_minutes"]),
	}
	for t: Vector2i in chopped.keys():
		_set_chopped(t, -1)
	for e: Array in d.get("chopped", []):
		_set_chopped(Vector2i(int(e[0]), int(e[1])), int(e[2]))
	jobs_known = {}
	for id: String in d.get("jobs_known", []):
		jobs_known[id] = true
	rumors = {}
	for id: String in d.get("rumors", []):
		rumors[id] = true
	notes_read = {}
	for id: String in d.get("notes_read", []):
		notes_read[id] = true
	land_from_dict(d.get("land", {}))
	var sd: Dictionary = d.get("sites", {})
	sites_found = {}
	sites_open = {}
	site_overrides = {}
	for id: String in sd.get("found", []):
		sites_found[id] = true
	for id: String in sd.get("open", []):
		sites_open[id] = true
	finds_found = {}
	for id: String in d.get("finds", []):
		finds_found[id] = true
	_apply_seasons()
	camp_changed.emit()
	survey_steps_left = 0
	_last_tile = Vector2i(-9999, -9999)
	weather.check_change(clock.minute)


func save_game() -> bool:
	var ok := SaveSystem.write(save_path, to_dict())
	if ok:
		save_count += 1
	saved.emit(ok)
	return ok


## Loads the save. Returns "" on success or the text id of the problem.
func load_game() -> String:
	var res := SaveSystem.read(save_path, {"size": Vector2i(world.width, world.height), "ring_one_offset": world.ring_one_offset()})
	if not res["ok"]:
		return res["error"]
	from_dict(res["data"])
	return ""


# --- facts about the moment -------------------------------------------------

func is_indoors() -> bool:
	return location != ""


func ranger_pos() -> Vector2:
	return interior_pos if is_indoors() else outdoor_pos


func ranger_tile() -> Vector2i:
	var p := outdoor_pos
	return Vector2i(floori(p.x), floori(p.y))


func current_weather() -> String:
	return weather.current(clock.minute)


func weather_row() -> Dictionary:
	return weather.current_row(clock.minute)


func is_night() -> bool:
	return Daylight.is_night(tuning, clock.season_name(), clock.minute)


func ground_here() -> String:
	if is_indoors():
		return "indoors"
	return world.ground_at(ranger_tile())


func on_trail() -> bool:
	return not is_indoors() and world.ground_at(ranger_tile()) == "trail"


func on_outlook() -> bool:
	if is_indoors():
		return false
	var c: Array = world.meta["outlook_center"]
	return outdoor_pos.distance_to(Vector2(float(c[0]), float(c[1]))) <= tuning.num("map.outlook_reach_tiles")


func selected_item() -> String:
	return backpack.item_at(selected_slot)


func lantern_lit() -> bool:
	return selected_item() == "lantern"


## The three marker rules: on revealed ground, weather that allows it, and
## daytime or on a trail.
func marker_visible() -> bool:
	if is_indoors():
		var p: Dictionary = world.structure_placement(location)
		return map.is_revealed(Vector2i(int(p["door"][0]), int(p["door"][1])))
	if not map.is_revealed(ranger_tile()):
		return false
	if bool(weather_row().get("hides_marker", false)):
		return false
	return not is_night() or on_trail() or near_marker()


func speed_tiles_per_second() -> float:
	var s := tuning.num("movement.trail_speed_tiles")
	if is_indoors():
		s *= float(tuning.value("movement.ground_speed.grass"))
	else:
		var g := ground_here()
		var table: Dictionary = tuning.value("movement.ground_speed")
		s *= float(table.get(g, 1.0))
		s *= float(weather_row().get("speed", 1.0))
	if needs.is_exhausted():
		s *= tuning.num("movement.exhausted_speed")
	return s


# --- each frame ---------------------------------------------------------------

func process(real_delta: float) -> void:
	clock.process(real_delta)


## Moves the ranger by an input direction for real_delta seconds.
func move(direction: Vector2, real_delta: float) -> void:
	moving = direction.length() > 0.01
	if not moving:
		return
	var dir := direction.normalized()
	if absf(dir.x) > absf(dir.y):
		facing = FACING_RIGHT if dir.x > 0.0 else FACING_LEFT
	else:
		facing = FACING_DOWN if dir.y > 0.0 else FACING_UP
	if survey_steps_left > 0:
		_cancel_survey()
	var box_arr: Array = tuning.value("movement.ranger_box_tiles")
	var box := Vector2(float(box_arr[0]), float(box_arr[1]))
	var motion := dir * speed_tiles_per_second() * real_delta
	if is_indoors():
		var layout: InteriorLayout = interiors[location]
		interior_pos = Mover.move(interior_pos, motion, box, layout.is_solid)
		var t := Vector2i(floori(interior_pos.x), floori(interior_pos.y))
		if t == layout.door_tile:
			leave_building()
		return
	var before := outdoor_pos
	outdoor_pos = Mover.move(outdoor_pos, motion, box, world.is_solid)
	var moved := before.distance_to(outdoor_pos)
	_walked_this_step += moved
	var tuned_rough: Array = tuning.value("energy.rough_grounds")
	if moved > 0.0 and tuned_rough.has(ground_here()):
		_rough_this_step = true
	_update_trace()


func _update_trace() -> void:
	var t := ranger_tile()
	var visible := marker_visible()
	if t != _last_tile:
		_last_tile = t
		map.record_trace(t, visible)
		_look_for_sites()
		_watch_for_finds()
	if visible and map.has_pending():
		map.flush_pending()


# --- each ten minutes ---------------------------------------------------------

func needs_context() -> Dictionary:
	return {
		"indoors": is_indoors(),
		"stove_lit": is_indoors() and structures.stove_lit(location),
		"weather": weather_row(),
		"season": clock.season_name(),
		"night": is_night(),
		"walked": _walked_this_step > 0.05,
		"rough": _rough_this_step,
		"campfire": near_lit_fire(),
	}


func _on_step(_minute: int) -> void:
	var step_minutes := clock.step_minutes()
	needs.step(needs_context())
	_walked_this_step = 0.0
	_rough_this_step = false
	structures.burn(step_minutes)
	if not camp.is_empty() and int(camp["fire_minutes"]) > 0:
		camp["fire_minutes"] = maxi(0, int(camp["fire_minutes"]) - step_minutes)
		if int(camp["fire_minutes"]) == 0:
			camp_changed.emit()
	weather.check_change(clock.minute)
	if survey_steps_left > 0:
		if not _survey_conditions_ok().is_empty():
			_cancel_survey()
		else:
			survey_steps_left -= 1
			survey_changed.emit(survey_steps_left > 0, 1.0 - float(survey_steps_left) / float(_survey_total_steps()))
			if survey_steps_left == 0:
				_finish_survey()
	if not is_indoors():
		_update_trace()
		_watch_for_finds()
	_check_collapse()


## Passes game time at once, as for an action that takes time.
func pass_minutes(minutes: int) -> void:
	var steps := ceili(float(minutes) / clock.step_minutes())
	for i in steps:
		if clock.is_day_over() or _collapsing:
			break
		clock.advance_step()


func _on_day_started(_day: int, _season: int, _year: int) -> void:
	weather.roll_day(clock.absolute_day())
	structures.restock_shelves()
	for id: String in structures.stove_minutes:
		structures.stove_minutes[id] = 0
	if not camp.is_empty():
		camp["fire_minutes"] = 0
		camp_changed.emit()
	_regrow_trees()
	_apply_seasons()
	weather.check_change(clock.minute)
	day_began.emit()


func _on_day_end() -> void:
	_check_collapse()


func _on_ran_out(_which: String) -> void:
	pass   # handled in _check_collapse after the change settles


# --- collapse, rescue and sleep ---------------------------------------------

func _check_collapse() -> void:
	if _collapsing:
		return
	if needs.energy <= 0.0 or needs.warmth <= 0.0 or clock.is_day_over():
		collapse()


## Which bed the ranger is carried to: the station, or the repaired cabin if
## that is nearer.
func nearest_bed() -> String:
	var here := outdoor_pos
	if is_indoors():
		var p: Dictionary = world.structure_placement(location)
		here = Vector2(float(p["door"][0]) + 0.5, float(p["door"][1]) + 1.0)
	var best := ""
	var best_d := INF
	for r: Dictionary in content.rows("structures"):
		var id: String = r["id"]
		if not r.get("has_bed", false) or not structures.is_open(id):
			continue
		var p: Dictionary = world.structure_placement(id)
		var d := here.distance_to(Vector2(float(p["door"][0]) + 0.5, float(p["door"][1]) + 1.0))
		if d < best_d:
			best_d = d
			best = id
	return best


func collapse() -> void:
	_collapsing = true
	collapse_count += 1
	survey_steps_left = 0
	pending_confirm = ""
	var bed := nearest_bed()
	clock.start_next_day(tuning.integer("collapse.wake_minute"))
	needs.set_values(needs.max_energy() * tuning.num("energy.collapse_wake_fraction"), needs.max_warmth())
	_put_in_bed(bed)
	_collapsing = false
	var kind: String = content.row("structures", bed)["kind"]
	var text := content.text({"cabin": "msg_rescue_cabin", "tower": "msg_rescue_tower"}.get(kind, "msg_rescue_station"))
	save_game()
	collapsed.emit(text)
	message.emit(text)


func _put_in_bed(structure_id: String) -> void:
	location = structure_id
	var layout: InteriorLayout = interiors[structure_id]
	var bed := layout.find("bed")
	var r := layout.furniture_rect(bed)
	interior_pos = Vector2(r.end.x + 0.5, r.position.y + 1.0)
	facing = FACING_DOWN
	location_changed.emit(location)


func request_sleep() -> void:
	pending_confirm = "sleep"
	confirm_requested.emit("sleep", content.text("msg_sleep_confirm"))


func answer_confirm(yes: bool) -> void:
	var kind := pending_confirm
	pending_confirm = ""
	if yes and kind == "sleep":
		sleep()
	elif yes and kind == "camp_sleep":
		camp_sleep()
	elif kind == "open_site":
		var site := _pending_site
		_pending_site = ""
		if yes:
			open_site(site)
		else:
			enter_building(content.row("sites", site)["structure"])


func sleep() -> void:
	clock.start_next_day(tuning.integer("time.day_start_minute"))
	needs.refill()
	save_game()
	message.emit(content.text("msg_saved"))


# --- buildings ----------------------------------------------------------------

func door_front(structure_id: String) -> Vector2:
	var p: Dictionary = world.structure_placement(structure_id)
	return Vector2(float(p["door"][0]) + 0.5, float(p["door"][1]) + 1.5)


func structure_at_door(pos: Vector2) -> String:
	var reach := tuning.num("world.interact_reach_tiles")
	for s: Dictionary in world.meta["structures"]:
		var door := Vector2(float(s["door"][0]) + 0.5, float(s["door"][1]) + 1.0)
		if pos.distance_to(door) <= reach:
			return s["id"]
	return ""


func near_structure(structure_id: String, reach: float) -> bool:
	if is_indoors():
		return false
	var p: Dictionary = world.structure_placement(structure_id)
	var r := Rect2(float(p["pos"][0]), float(p["pos"][1]), float(p["size"][0]), float(p["size"][1]))
	var closest := Vector2(clampf(outdoor_pos.x, r.position.x, r.end.x), clampf(outdoor_pos.y, r.position.y, r.end.y))
	return closest.distance_to(outdoor_pos) <= reach


func enter_building(structure_id: String) -> bool:
	if not structures.is_open(structure_id):
		var names: PackedStringArray = []
		for step in structures.steps_remaining(structure_id):
			names.append(content.text(structures.step_row(structure_id, step)["name"]))
		message.emit(content.text("msg_cabin_locked", {"steps": ", ".join(names)}))
		return false
	_cancel_survey()
	location = structure_id
	interior_pos = (interiors[structure_id] as InteriorLayout).entry
	facing = FACING_UP
	location_changed.emit(location)
	return true


func leave_building() -> void:
	if not is_indoors():
		return
	outdoor_pos = door_front(location)
	location = ""
	facing = FACING_DOWN
	_last_tile = Vector2i(-9999, -9999)
	location_changed.emit(location)
	_update_trace()


# --- interacting and using items -------------------------------------------

func interact() -> void:
	if pending_confirm != "":
		return
	if is_indoors():
		_interact_inside()
		return
	var reach := tuning.num("world.interact_reach_tiles")
	var sid := structure_at_door(outdoor_pos)
	if sid != "":
		if _landmark_for_structure(sid) != "" and not map.is_landmark_mapped(_landmark_for_structure(sid)):
			map_location(_landmark_for_structure(sid))
			return
		var site := site_for_structure(sid)
		if site != "" and not sites_open.has(site) and site_ready(site):
			_pending_site = site
			pending_confirm = "open_site"
			confirm_requested.emit("open_site", content.text("msg_open_site_confirm", {"name": content.text(content.row("sites", site)["name"])}))
			return
		enter_building(sid)
		return
	if not camp.is_empty():
		if outdoor_pos.distance_to(Vector2(camp["bed"]) + Vector2(0.5, 0.5)) <= reach:
			pending_confirm = "camp_sleep"
			confirm_requested.emit("camp_sleep", content.text("msg_camp_sleep_confirm"))
			return
		if outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= reach:
			feed_campfire()
			return
	var sign_t := placed_in_reach()
	if sign_t.x >= 0:
		read_placed(sign_t)
		return
	var obj := world.interactive_near(outdoor_pos, reach + 0.5)
	if obj.is_empty():
		return
	var what: String = obj["interact"]
	if seasonal_hidden.has(Vector2i(floori(obj["pos"].x), floori(obj["pos"].y))) or _hidden_near(obj["pos"]):
		return
	if what.begins_with("find:"):
		discover(what.substr(5))
	elif what == "gate":
		message.emit(content.text("msg_gate_closed"))
	elif what.begins_with("landmark:"):
		var lid := what.substr(9)
		if not map.is_landmark_mapped(lid):
			map_location(lid)
		else:
			message.emit(content.text(content.row("landmarks", lid)["name"]))


func _landmark_for_structure(structure_id: String) -> String:
	return structure_id if content.has("landmarks", structure_id) else ""


func _interact_inside() -> void:
	var layout: InteriorLayout = interiors[location]
	var f := layout.furniture_near(interior_pos, tuning.num("world.interact_reach_tiles"))
	if f.is_empty():
		return
	match str(f["kind"]):
		"bed":
			request_sleep()
		"radio":
			use_radio()
		"shelf":
			storage_opened.emit(content.text("ui_shelf"), structures.shelves[location])
		"chest":
			storage_opened.emit(content.text("ui_chest"), structures.chests[location])
		"stove":
			feed_stove()
		"note_board":
			read_note_board()
		"workbench":
			workbench_opened.emit()
		"find":
			discover(str(f["find"]))
		"exit":
			leave_building()


func use_radio() -> PackedStringArray:
	var fc := weather.forecast(clock.absolute_day())
	var names := []
	for w: String in fc["blocks"]:
		names.append(content.text(weather.row(w)["name"]))
	var lines := PackedStringArray([
		content.text("radio_header"),
		content.text("radio_block_morning", {"weather": names[0]}),
		content.text("radio_block_afternoon", {"weather": names[1]}),
		content.text("radio_block_evening", {"weather": names[2]}),
		content.text("radio_tomorrow", {"weather": content.text(weather.row(fc["tomorrow"])["name"]).to_lower()}),
	])
	radio_heard.emit(lines)
	return lines


func feed_stove() -> bool:
	if not is_indoors() or not structures.stove_minutes.has(location):
		return false
	var was_lit := structures.stove_lit(location)
	if not structures.feed_stove(location, backpack):
		message.emit(content.text("msg_stove_no_wood"))
		return false
	message.emit(content.text("msg_stove_fed" if was_lit else "msg_stove_lit"))
	return true


## Uses the held item.
func use_item() -> void:
	if pending_confirm != "":
		return
	var item := selected_item()
	if item == "":
		return
	var row := content.row("items", item)
	if row["kind"] == "food":
		eat(item)
	elif row["kind"] == "placeable":
		begin_place()
	elif row["kind"] == "page":
		discover(str(row["find"]))
	elif item == "hammer":
		hammer()
	elif item == "map":
		start_survey()
	elif item == "axe":
		if not obstacle_in_reach("axe").is_empty():
			clear_obstacle()
		else:
			chop()
	elif item == "saw":
		clear_obstacle()
	elif item == "shovel":
		dig()
	elif item == "bedroll":
		make_camp()
	elif item == "firewood":
		if is_indoors() and (interiors[location] as InteriorLayout).find("stove").size() > 0:
			feed_stove()
		elif not camp.is_empty() and outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= tuning.num("world.interact_reach_tiles"):
			feed_campfire()


func eat(item: String) -> bool:
	if not content.has("foods", item) or not backpack.remove(item, 1):
		return false
	needs.eat(content.row("foods", item))
	message.emit(content.text("msg_ate", {"item": content.item_name(item).to_lower()}))
	return true


func hammer() -> Dictionary:
	if not is_indoors():
		var front := ranger_tile() + facing_vector()
		if placed.has(front):
			return {"ok": take_down(front), "reason": "took_down"}
	var target := ""
	for id in structures.ids():
		if not structures.is_open(id) and near_structure(id, tuning.num("repair.reach_tiles")):
			target = id
	if target == "":
		return {"ok": false, "reason": "nothing"}
	var res := structures.repair_action(target, backpack)
	if not res["ok"]:
		message.emit(content.text("msg_repair_need_hammer" if res["reason"] == "no_tool" else "msg_repair_need_materials"))
		return res
	needs.spend(tuning.num("energy.repair_action"))
	var step_name := content.text(structures.step_row(target, res["step"])["name"])
	if res["opened"]:
		message.emit(content.text("msg_cabin_repaired"))
	elif res["step_finished"]:
		message.emit(content.text("msg_repair_step_done", {"step": step_name}))
	else:
		message.emit(content.text("msg_repair_progress", {"step": step_name, "done": res["done"], "total": res["total"]}))
	pass_minutes(tuning.integer("repair.minutes_per_action"))
	_check_collapse()
	return res


# --- camping ------------------------------------------------------------------

func facing_vector() -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
	return dirs[facing]


func _camp_spot_ok(t: Vector2i) -> bool:
	if not world.in_bounds(t) or world.is_solid(t):
		return false
	var g := world.ground_at(t)
	return g != "shallows" and g != "deep_water" and g != "rock"


## Lays out the bedroll where the ranger stands and lights a small fire in
## front, using one firewood. One camp at a time: making a new one moves it.
func make_camp() -> bool:
	if is_indoors():
		message.emit(content.text("msg_camp_bad_spot"))
		return false
	var bed := ranger_tile()
	var fire := bed + facing_vector()
	if not _camp_spot_ok(bed) or not _camp_spot_ok(fire):
		message.emit(content.text("msg_camp_bad_spot"))
		return false
	if not backpack.remove("firewood", 1):
		message.emit(content.text("msg_camp_need_wood"))
		return false
	camp = {"bed": bed, "fire": fire, "fire_minutes": tuning.integer("camp.fire_minutes_per_firewood")}
	camp_changed.emit()
	message.emit(content.text("msg_camp_made"))
	return true


func campfire_lit() -> bool:
	return not camp.is_empty() and int(camp["fire_minutes"]) > 0


func near_lit_fire() -> bool:
	if is_indoors() or not campfire_lit():
		return false
	return outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= tuning.num("camp.fire_radius_tiles")


func feed_campfire() -> bool:
	if camp.is_empty() or not backpack.remove("firewood", 1):
		message.emit(content.text("msg_camp_need_wood"))
		return false
	camp["fire_minutes"] = int(camp["fire_minutes"]) + tuning.integer("camp.fire_minutes_per_firewood")
	camp_changed.emit()
	message.emit(content.text("msg_camp_fire_fed"))
	return true


## Sleeping at camp: the next morning at 6:00, partly rested, and the game saves.
func camp_sleep() -> void:
	clock.start_next_day(tuning.integer("time.day_start_minute"))
	needs.set_values(
		maxf(needs.energy, needs.max_energy() * tuning.num("camp.wake_energy_fraction")),
		maxf(needs.warmth, needs.max_warmth() * tuning.num("camp.wake_warmth_fraction")))
	location = ""
	outdoor_pos = Vector2(camp["bed"]) + Vector2(0.5, 0.5)
	facing = FACING_DOWN
	save_game()
	message.emit(content.text("msg_camp_woke"))


# --- chopping trees -------------------------------------------------------------

func _is_choppable(t: Vector2i) -> bool:
	var trees: Array = tuning.value("axe.trees")
	return trees.has(world.object_at(t)) and not chopped.has(t)


## The tree the axe would hit: the one in front if any, else the nearest in reach.
func tree_in_reach() -> Vector2i:
	var reach := tuning.num("axe.reach_tiles")
	var front := ranger_tile() + facing_vector()
	if _is_choppable(front) and outdoor_pos.distance_to(Vector2(front) + Vector2(0.5, 0.5)) <= reach + 0.5:
		return front
	var best := Vector2i(-1, -1)
	var best_d := reach
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := ranger_tile() + Vector2i(dx, dy)
			var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
			if d <= best_d and _is_choppable(t):
				best_d = d
				best = t
	return best


func _set_chopped(t: Vector2i, day: int) -> void:
	if day < 0:
		chopped.erase(t)
		world.set_cleared(t, false)
	else:
		chopped[t] = day
		world.set_cleared(t, true)
	tree_changed.emit(t)


func chop() -> Dictionary:
	if is_indoors():
		return {"ok": false}
	if not backpack.has("axe"):
		message.emit(content.text("msg_chop_need_axe"))
		return {"ok": false}
	var t := tree_in_reach()
	if t.x < 0:
		message.emit(content.text("msg_no_tree"))
		return {"ok": false}
	_set_chopped(t, clock.absolute_day())
	var n := tuning.integer("axe.firewood")
	var left := backpack.add("firewood", n)
	needs.spend(tuning.num("axe.energy"))
	message.emit(content.text("msg_chopped", {"n": n - left}))
	if left > 0:
		message.emit(content.text("msg_backpack_full"))
	pass_minutes(tuning.integer("axe.minutes"))
	_check_collapse()
	return {"ok": true, "tile": t, "firewood": n - left}


func _regrow_trees() -> void:
	var days := tuning.integer("axe.regrow_days")
	var box: Array = tuning.value("movement.ranger_box_tiles")
	var size := Vector2(float(box[0]), float(box[1]))
	for t: Vector2i in chopped.keys():
		if clock.absolute_day() - int(chopped[t]) < days:
			continue
		# Never grow a tree where the ranger stands or the camp is.
		var here := Rect2(outdoor_pos - size / 2.0, size)
		if not is_indoors() and here.intersects(Rect2(Vector2(t), Vector2.ONE)):
			continue
		if not camp.is_empty() and (camp["bed"] == t or camp["fire"] == t):
			continue
		_set_chopped(t, -1)


# --- clearing and building trail ---------------------------------------------

func _reset_land() -> void:
	for t: Vector2i in cleared.keys():
		_set_cleared(t, "", false)
	for t: Vector2i in dug.keys():
		_set_dug(t, false)
	for t: Vector2i in placed.keys():
		placed.erase(t)
		land_changed.emit(t)
	clearing_progress = {}


func land_to_dict() -> Dictionary:
	return {
		"cleared": cleared.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, cleared[t]]),
		"progress": clearing_progress.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, clearing_progress[t]]),
		"dug": dug.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y]),
		"placed": placed.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, placed[t]["item"], placed[t]["place"]]),
	}


func land_from_dict(d: Dictionary) -> void:
	_reset_land()
	for e: Array in d.get("cleared", []):
		_set_cleared(Vector2i(int(e[0]), int(e[1])), str(e[2]), true)
	for e: Array in d.get("progress", []):
		clearing_progress[Vector2i(int(e[0]), int(e[1]))] = int(e[2])
	for e: Array in d.get("dug", []):
		_set_dug(Vector2i(int(e[0]), int(e[1])), true)
	for e: Array in d.get("placed", []):
		var t := Vector2i(int(e[0]), int(e[1]))
		placed[t] = {"item": str(e[2]), "place": str(e[3])}
		land_changed.emit(t)


func _obstacle_row_for(kind: String) -> Dictionary:
	for r: Dictionary in content.rows("obstacles"):
		if r["object"] == kind:
			return r
	return {}


## The obstacle covering a tile: {"origin", "id"}, or empty.
func obstacle_at(t: Vector2i) -> Dictionary:
	for dx in range(0, 3):
		var o := t - Vector2i(dx, 0)
		var kind := world.object_at(o)
		if kind == "" or cleared.has(o):
			continue
		var row := _obstacle_row_for(kind)
		if row.is_empty():
			continue
		var size: Array = world.object_type(kind)["size"]
		if dx < int(size[0]):
			return {"origin": o, "id": row["id"]}
	return {}


## The obstacle a tool would work on: the one in front, else the nearest in
## reach. With a tool given, only obstacles that tool clears.
func obstacle_in_reach(tool: String = "") -> Dictionary:
	if is_indoors():
		return {}
	var reach := tuning.num("clearing.reach_tiles")
	var front := ranger_tile() + facing_vector()
	var best := {}
	var best_d := INF
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := ranger_tile() + Vector2i(dx, dy)
			var ob := obstacle_at(t)
			if ob.is_empty():
				continue
			if tool != "" and content.row("obstacles", ob["id"])["tool"] != tool:
				continue
			var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
			if d > reach + 0.5:
				continue
			if t == front:
				d -= 1.0
			if d < best_d:
				best_d = d
				best = ob
	return best


func _set_cleared(origin: Vector2i, id: String, on: bool) -> void:
	var kind := world.object_at(origin)
	var size: Array = world.object_type(kind).get("size", [1, 1]) if kind != "" else [1, 1]
	for dy in int(size[1]):
		for dx in int(size[0]):
			world.set_cleared(origin + Vector2i(dx, dy), on)
	if on:
		cleared[origin] = id
	else:
		cleared.erase(origin)
	clearing_progress.erase(origin)
	land_changed.emit(origin)


## One action on the obstacle in reach. Each obstacle needs its own tool and
## takes its set number of actions, each costing time and energy.
func clear_obstacle() -> Dictionary:
	var ob := obstacle_in_reach()
	if ob.is_empty():
		message.emit(content.text("msg_nothing_to_clear"))
		return {"ok": false, "reason": "nothing"}
	var row := content.row("obstacles", ob["id"])
	var what := content.text(row["name"])
	var tool: String = row["tool"]
	if not backpack.has(tool):
		message.emit(content.text("msg_clear_need_tool", {"tool": content.item_name(tool).to_lower(), "what": what}))
		return {"ok": false, "reason": "no_tool"}
	var key := "clearing." + str(ob["id"])
	var origin: Vector2i = ob["origin"]
	var done := int(clearing_progress.get(origin, 0)) + 1
	var total := tuning.integer(key + ".actions")
	needs.spend(tuning.num(key + ".energy"))
	var finished := done >= total
	if finished:
		_set_cleared(origin, ob["id"], true)
		message.emit(content.text("msg_cleared", {"what": what}))
	else:
		clearing_progress[origin] = done
		message.emit(content.text("msg_clear_progress", {"what": what, "done": done, "total": total}))
	pass_minutes(tuning.integer(key + ".minutes"))
	_check_collapse()
	return {"ok": true, "id": ob["id"], "origin": origin, "done": done, "total": total, "cleared": finished}


func can_dig(t: Vector2i) -> bool:
	if not world.in_bounds(t) or world.is_solid(t) or dug.has(t):
		return false
	var diggable: Array = tuning.value("trail.diggable")
	if not diggable.has(world.ground_at(t)):
		return false
	if not camp.is_empty() and (camp["bed"] == t or camp["fire"] == t):
		return false
	return true


func _set_dug(t: Vector2i, on: bool) -> void:
	if on:
		dug[t] = true
		world.set_ground(t, "trail")
	else:
		dug.erase(t)
		world.set_ground(t, "")
	map.touch(t)
	land_changed.emit(t)


## Digs the faced tile (and more, if tuned) into trail.
func dig() -> Dictionary:
	if is_indoors():
		return {"ok": false}
	if not backpack.has("shovel"):
		message.emit(content.text("msg_dig_need_shovel"))
		return {"ok": false, "reason": "no_tool"}
	var made: Array[Vector2i] = []
	var t := ranger_tile() + facing_vector()
	for i in tuning.integer("trail.tiles_per_action"):
		if not can_dig(t):
			break
		_set_dug(t, true)
		made.append(t)
		t += facing_vector()
	if made.is_empty():
		message.emit(content.text("msg_cant_dig"))
		return {"ok": false, "reason": "here"}
	needs.spend(tuning.num("trail.energy"))
	message.emit(content.text("msg_dug"))
	pass_minutes(tuning.integer("trail.minutes"))
	_check_collapse()
	return {"ok": true, "tiles": made}


# --- the workbench ------------------------------------------------------------

func recipes_at(station: String) -> Array:
	return content.rows("recipes").filter(func(r: Dictionary) -> bool: return r["station"] == station)


## What a recipe needs and what the backpack holds: {name, inputs, can}.
func recipe_status(recipe_id: String) -> Dictionary:
	var r := content.row("recipes", recipe_id)
	var inputs := []
	for k: String in r["inputs"]:
		inputs.append({"item": k, "need": int(r["inputs"][k]), "have": backpack.count(k)})
	return {"name": content.text(r["name"]), "inputs": inputs, "can": backpack.has_all(r["inputs"])}


func recipe_line(recipe_id: String) -> String:
	var st := recipe_status(recipe_id)
	var parts: PackedStringArray = []
	for e: Dictionary in st["inputs"]:
		parts.append(content.text("ui_recipe_input", {"name": content.item_name(e["item"]), "have": e["have"], "need": e["need"]}))
	return content.text("ui_recipe_line", {"name": st["name"], "inputs": ", ".join(parts)})


func craft(recipe_id: String) -> bool:
	var r := content.row("recipes", recipe_id)
	var res: Dictionary = r["result"]
	if not backpack.has_all(r["inputs"]) or backpack.room_for(res["item"]) < int(res["count"]):
		message.emit(content.text("msg_craft_missing"))
		return false
	backpack.remove_all(r["inputs"])
	backpack.add(res["item"], int(res["count"]))
	message.emit(content.text("msg_crafted", {"item": content.item_name(res["item"]).to_lower()}))
	return true


# --- signs and trail markers -----------------------------------------------------

## Places a sign can name: the station, and every place the ranger has mapped.
func sign_places() -> Array:
	var out := [{"id": "ranger_station", "label": content.text("ui_place_station")}]
	for r: Dictionary in content.rows("landmarks"):
		if map.is_landmark_mapped(r["id"]):
			out.append({"id": r["id"], "label": content.text(r["name"])})
	return out


func place_name(place_id: String) -> String:
	if place_id == "ranger_station":
		return content.text("ui_place_station")
	return content.text(content.row("landmarks", place_id)["name"])


func place_pos(place_id: String) -> Vector2:
	if place_id == "ranger_station":
		return door_front("ranger_station")
	return world.landmark_pos(place_id)


## "" if the item can go on tile t, or the text id saying why not.
func place_problem(t: Vector2i, item: String) -> String:
	var row := content.row("items", item)
	if not backpack.has(str(row.get("needs_tool", "hammer"))):
		return "msg_place_need_hammer"
	if not world.in_bounds(t) or world.is_solid(t) or placed.has(t):
		return "msg_place_bad_spot"
	if world.object_at(t) != "" and not cleared.has(t) and not chopped.has(t):
		return "msg_place_bad_spot"
	if not camp.is_empty() and (camp["bed"] == t or camp["fire"] == t):
		return "msg_place_bad_spot"
	var g := world.ground_at(t)
	if row.get("on", "open") == "trail" and g != "trail":
		return "msg_sign_need_trail"
	if g in ["shallows", "deep_water", "rock", "boards"]:
		return "msg_place_bad_spot"
	return ""


## Starts putting up the held sign or marker on the faced tile. A sign asks
## which place it should name first.
func begin_place() -> bool:
	if is_indoors():
		return false
	var item := selected_item()
	var t := ranger_tile() + facing_vector()
	var why := place_problem(t, item)
	if why != "":
		message.emit(content.text(why))
		return false
	if content.row("items", item).get("names_place", false):
		_pending_place = t
		_pending_item = item
		pending_confirm = "sign_place"
		choice_requested.emit("sign_place", content.text("ui_sign_where"), sign_places())
		return true
	return put_up(t, item, "")


## The answer to a choice: the place a sign should name, or "" to cancel.
func answer_choice(kind: String, option_id: String) -> void:
	if pending_confirm == kind:
		pending_confirm = ""
	if kind == "sign_place" and option_id != "" and _pending_place.x >= 0:
		put_up(_pending_place, _pending_item, option_id)
	_pending_place = Vector2i(-1, -1)
	_pending_item = ""


func put_up(t: Vector2i, item: String, place_id: String) -> bool:
	var why := place_problem(t, item)
	if why != "" or not backpack.remove(item, 1):
		message.emit(content.text(why if why != "" else "msg_place_bad_spot"))
		return false
	placed[t] = {"item": item, "place": place_id}
	needs.spend(tuning.num("signs.put_up_energy"))
	land_changed.emit(t)
	map.touch(t)
	if place_id != "":
		message.emit(content.text("msg_sign_up", {"place": place_name(place_id)}))
	else:
		message.emit(content.text("msg_marker_up"))
	pass_minutes(tuning.integer("signs.put_up_minutes"))
	_check_collapse()
	return true


## A sign or marker in reach: the one in front, else the nearest.
func placed_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var front := ranger_tile() + facing_vector()
	if placed.has(front):
		return front
	var best := Vector2i(-1, -1)
	var best_d := tuning.num("signs.reach_tiles") + 0.5
	for t: Vector2i in placed:
		var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
		if d <= best_d:
			best_d = d
			best = t
	return best


## Which way a sign at t points to its place, as a text id.
func sign_direction(t: Vector2i, place_id: String) -> String:
	var v := place_pos(place_id) - (Vector2(t) + Vector2(0.5, 0.5))
	if v.length() < 3.0:
		return "dir_here"
	var names := ["dir_e", "dir_se", "dir_s", "dir_sw", "dir_w", "dir_nw", "dir_n", "dir_ne"]
	var i := posmod(int(round(v.angle() / (PI / 4.0))), 8)
	return names[i]


func read_placed(t: Vector2i) -> String:
	var p: Dictionary = placed[t]
	var text := content.text("msg_marker_reads")
	if str(p["place"]) != "":
		text = content.text("msg_sign_reads", {"place": place_name(p["place"]), "dir": content.text(sign_direction(t, p["place"]))})
	message.emit(text)
	return text


func take_down(t: Vector2i) -> bool:
	if not placed.has(t):
		return false
	var item: String = placed[t]["item"]
	if backpack.room_for(item) < 1:
		message.emit(content.text("msg_backpack_full"))
		return false
	placed.erase(t)
	backpack.add(item, 1)
	needs.spend(tuning.num("signs.take_down_energy"))
	land_changed.emit(t)
	map.touch(t)
	message.emit(content.text("msg_taken_down", {"item": content.item_name(item).to_lower()}))
	pass_minutes(tuning.integer("signs.take_down_minutes"))
	return true


## A trail marker within reach counts as trail for the map marker at night.
func near_marker() -> bool:
	if is_indoors():
		return false
	var r := tuning.num("signs.marker_radius_tiles")
	for t: Vector2i in placed:
		if placed[t]["item"] == "trail_marker" and outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r:
			return true
	return false


## Puts up a sign or marker anywhere, for tests and the debug panel.
func debug_put_up(t: Vector2i, item: String, place_id: String = "") -> bool:
	if backpack.count(item) == 0:
		backpack.add(item, 1)
	if not backpack.has("hammer"):
		backpack.add("hammer", 1)
	return put_up(t, item, place_id)


# --- hidden things -----------------------------------------------------------------

## Notices a hidden thing. The first time, its text is shown as a note and it
## is recorded; any gift it holds is given once.
func discover(find_id: String) -> bool:
	if not content.has("spoiler_finds", find_id):
		return false
	var row := content.row("spoiler_finds", find_id)
	var text := content.text(row["text"])
	if finds_found.has(find_id):
		message.emit(text)
		return false
	finds_found[find_id] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, find_id])
	for g: Dictionary in row.get("gives", []):
		var n := rng.randi_range(int(g["min"]), int(g["max"]))
		if n > 0:
			var left := backpack.add(g["item"], n)
			if left > 0:
				message.emit(content.text("msg_backpack_full"))
	note_read.emit(text)
	return true


## Hidden things noticed by being in the right place at the right time.
func _watch_for_finds() -> void:
	if is_indoors():
		return
	for row: Dictionary in content.rows("spoiler_finds"):
		if not row.has("when") or finds_found.has(row["id"]):
			continue
		var w: Dictionary = row["when"]
		if clock.minute < int(w["from"]) or clock.minute >= int(w["to"]):
			continue
		if current_weather() != str(w["weather"]):
			continue
		if outdoor_pos.distance_to(world.landmark_pos(w["landmark"])) <= float(w["within"]):
			discover(row["id"])


## Whether a hidden thing's moment is happening now, for drawing it.
func find_moment_now(find_id: String) -> bool:
	var w: Dictionary = content.row("spoiler_finds", find_id).get("when", {})
	if w.is_empty():
		return false
	return clock.minute >= int(w["from"]) and clock.minute < int(w["to"]) and current_weather() == str(w["weather"])


## Some things are only there in some seasons.
func _apply_seasons() -> void:
	var season := clock.season_name()
	var spots: Dictionary = world.meta.get("finds", {})
	for row: Dictionary in content.rows("spoiler_finds"):
		if not row.has("absent_in") or not spots.has(row["id"]):
			continue
		var p: Array = spots[row["id"]]
		var t := Vector2i(int(p[0]), int(p[1]))
		var away := (row["absent_in"] as Array).has(season)
		if away == seasonal_hidden.has(t):
			continue
		var size: Array = world.object_type(world.object_at(t))["size"]
		for dy in int(size[1]):
			for dx in int(size[0]):
				world.set_cleared(t + Vector2i(dx, dy), away)
		if away:
			seasonal_hidden[t] = true
		else:
			seasonal_hidden.erase(t)
		land_changed.emit(t)


func _hidden_near(pos: Vector2) -> bool:
	for t: Vector2i in seasonal_hidden:
		var size: Array = world.object_type(world.object_at(t))["size"]
		var r := Rect2(Vector2(t), Vector2(float(size[0]), float(size[1])))
		if r.grow(0.01).has_point(pos):
			return true
	return false


## Where this save's berry patch grows: one of a few spots, by the save's seed.
func berry_spot() -> Vector2i:
	var spots: Array = world.meta.get("berry_spots", [])
	if spots.is_empty():
		return Vector2i(-1, -1)
	var p: Array = spots[posmod(hash([seed_value, "berries"]), spots.size())]
	return Vector2i(int(p[0]), int(p[1]))


func debug_finds_text() -> String:
	return content.text("msg_found_count", {"n": finds_found.size()}) + " " + ", ".join(finds_found.keys())


# --- sites -----------------------------------------------------------------------

const SITE_STEPS: Array[String] = ["find", "map", "reach", "repair", "sign", "settle"]


func site_for_structure(structure_id: String) -> String:
	for r: Dictionary in content.rows("sites"):
		if r["structure"] == structure_id:
			return r["id"]
	return ""


func site_pos(site_id: String) -> Vector2:
	return world.landmark_pos(content.row("sites", site_id)["landmark"])


func _look_for_sites() -> void:
	if is_indoors():
		return
	var r := tuning.num("sites.find_radius_tiles")
	for row: Dictionary in content.rows("sites"):
		var id: String = row["id"]
		if not sites_found.has(id) and outdoor_pos.distance_to(site_pos(id)) <= r:
			sites_found[id] = true
			message.emit(content.text("msg_site_found", {"name": content.text(row["name"])}))


## Whether a step of opening a site is done.
func site_step_done(site_id: String, step: String) -> bool:
	var key := site_id + ":" + step
	if site_overrides.has(key):
		return bool(site_overrides[key])
	var row := content.row("sites", site_id)
	match step:
		"find":
			return sites_found.has(site_id)
		"map":
			return map.is_landmark_mapped(row["landmark"])
		"reach":
			return site_reached(site_id)
		"repair":
			return structures.is_open(row["structure"])
		"sign":
			return site_signed(site_id)
		"settle":
			return not bool(row.get("magic", false))
	return false


## True when the first five steps are done and the site can be declared open.
func site_ready(site_id: String) -> bool:
	for step in SITE_STEPS:
		if not site_step_done(site_id, step):
			return false
	return true


## Whether unbroken trail, cleared of obstacles, joins the site's door to the
## station's door. A trail may ford water: a short wade through shallows
## between trail on both banks counts, a walk along a stream does not.
func site_reached(site_id: String) -> bool:
	var grounds: Array = tuning.value("sites.reach_grounds")
	var ford_max := tuning.integer("sites.ford_max_tiles")
	var start := Vector2i(door_front(content.row("sites", site_id)["structure"]))
	var goal := Vector2i(door_front("ranger_station"))
	if world.is_solid(start) or not grounds.has(world.ground_at(start)):
		return false
	var best := {start: 0}   # tile -> fewest shallows waded in a row to get there
	var queue: Array = [[start, 0]]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var t: Vector2i = queue[head][0]
		var run: int = queue[head][1]
		head += 1
		if t == goal:
			return true
		for d in dirs:
			var n := t + d
			if world.is_solid(n):
				continue
			var g := world.ground_at(n)
			var r := 0
			if g == "shallows":
				r = run + 1
				if r > ford_max:
					continue
			elif not grounds.has(g):
				continue
			if not best.has(n) or int(best[n]) > r:
				best[n] = r
				queue.append([n, r])
	return false


## Whether a sign naming the site stands on trail near it.
func site_signed(site_id: String) -> bool:
	var landmark: String = content.row("sites", site_id)["landmark"]
	var r := tuning.num("sites.sign_distance_tiles")
	for t: Vector2i in placed:
		if str(placed[t]["place"]) == landmark and site_pos(site_id).distance_to(Vector2(t)) <= r:
			return true
	return false


func open_site(site_id: String) -> bool:
	if not site_ready(site_id):
		return false
	sites_open[site_id] = true
	map.mark_landmark(content.row("sites", site_id)["landmark"])
	message.emit(content.text("msg_site_opened", {"name": content.text(content.row("sites", site_id)["name"])}))
	return true


func site_lines() -> PackedStringArray:
	var out := PackedStringArray([content.text("site_list_title")])
	if sites_found.is_empty():
		out.append(content.text("site_none"))
		return out
	for row: Dictionary in content.rows("sites"):
		var id: String = row["id"]
		if not sites_found.has(id):
			continue
		var name := content.text(row["name"])
		if sites_open.has(id):
			out.append(content.text("site_open", {"name": name}))
			continue
		var parts: PackedStringArray = []
		for step in SITE_STEPS:
			var label := content.text("site_step_" + step)
			parts.append(content.text("site_step_done", {"name": label}) if site_step_done(id, step) else label)
		out.append(content.text("site_line", {"name": name, "steps": ", ".join(parts)}))
	return out


func debug_site_step(site_id: String, step: String, done: bool) -> void:
	site_overrides[site_id + ":" + step] = done


func debug_open_site(site_id: String) -> void:
	for step in SITE_STEPS:
		site_overrides[site_id + ":" + step] = true
	open_site(site_id)


# --- jobs ------------------------------------------------------------------------

## Reads the note board where the ranger stands: the station's jobs, and any
## notes from the last ranger pinned up here. A note can add rumors: rough
## circles on the map around places not yet found.
func read_note_board() -> String:
	var here := location if is_indoors() else "ranger_station"
	var texts: PackedStringArray = []
	var added := false
	if here == "ranger_station":
		for j: Dictionary in content.rows("jobs"):
			texts.append(content.text(j["offer"]))
			if not jobs_known.has(j["id"]):
				jobs_known[j["id"]] = true
				added = true
	var heard := false
	for n: Dictionary in content.rows("notes"):
		if n["at"] != here or not structures.is_open(n["needs_open"]):
			continue
		texts.append(content.text(n["text"]))
		if not notes_read.has(n["id"]):
			notes_read[n["id"]] = true
			for lm: String in n["rumors"]:
				if not rumors.has(lm):
					rumors[lm] = true
					heard = true
	if texts.is_empty():
		texts.append(content.text("msg_note_board_empty"))
	var text := "\n\n".join(texts)
	note_read.emit(text)
	if added:
		message.emit(content.text("msg_job_added"))
	if heard:
		message.emit(content.text("msg_rumor_added"))
	return text


## What a job still needs, worked out from the structure and the backpack.
func job_status(job_id: String) -> Dictionary:
	var j := content.row("jobs", job_id)
	var sid: String = j["structure"]
	var need := {}
	var steps := []
	for st: Dictionary in content.row("structures", sid)["repair_steps"]:
		var started := int(structures.progress[sid][st["id"]]) > 0
		steps.append({"name": content.text(st["name"]), "done": structures.step_done(sid, st["id"])})
		if not started:
			for m: String in st["materials"]:
				need[m] = int(need.get(m, 0)) + int(st["materials"][m])
	for tool: String in j["tools"]:
		need[tool] = maxi(1, int(need.get(tool, 0)))
	var bring := []
	for m: String in need:
		bring.append({"item": m, "need": int(need[m]), "have": backpack.count(m)})
	return {"title": content.text(j["title"]), "done": structures.is_open(sid), "bring": bring, "steps": steps, "also": j["suggested"]}


func job_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if jobs_known.is_empty():
		out.append(content.text("job_none"))
		return out
	for id: String in jobs_known:
		var st := job_status(id)
		out.append(st["title"] + ("  -  " + content.text("job_done") if st["done"] else ""))
		if st["done"]:
			continue
		var b: PackedStringArray = []
		for e: Dictionary in st["bring"]:
			b.append(content.text("job_have", {"name": content.item_name(e["item"]), "have": e["have"], "need": e["need"]}))
		out.append(content.text("job_bring", {"list": ", ".join(b)}))
		var s: PackedStringArray = []
		for e: Dictionary in st["steps"]:
			s.append(content.text("job_step_done", {"name": e["name"]}) if e["done"] else e["name"])
		out.append(content.text("job_steps", {"list": ", ".join(s)}))
		var a: PackedStringArray = []
		for it: String in st["also"]:
			a.append(content.item_name(it))
		out.append(content.text("job_also", {"list": ", ".join(a)}))
	return out


# --- mapping ------------------------------------------------------------------

## Whether the map may show a landmark's rough hint: always, unless the hint
## is a rumor the ranger has not yet heard.
func hint_known(landmark_id: String) -> bool:
	var h: Dictionary = content.row("landmarks", landmark_id).get("hint", {})
	return not bool(h.get("rumor", false)) or rumors.has(landmark_id)


func _survey_total_steps() -> int:
	return ceili(tuning.num("map.survey_minutes") / clock.step_minutes())


## True inside a repaired fire tower, where the cab looks out over the forest.
func in_tower() -> bool:
	return is_indoors() and content.row("structures", location)["kind"] == "tower"


## Returns "" if surveying is possible now, or the text id saying why not.
func _survey_conditions_ok() -> String:
	if is_indoors() and not in_tower():
		return "msg_survey_weather"
	if not (backpack.has("map") and backpack.has("compass") and backpack.has("pencil")):
		return "msg_survey_need_tools"
	if is_night():
		return "msg_survey_dark"
	if not bool(weather_row().get("survey", false)):
		return "msg_survey_weather"
	return ""


func start_survey() -> bool:
	var why := _survey_conditions_ok()
	if why != "":
		message.emit(content.text(why))
		return false
	survey_steps_left = _survey_total_steps()
	message.emit(content.text("msg_survey_start"))
	survey_changed.emit(true, 0.0)
	return true


func _cancel_survey() -> void:
	if survey_steps_left > 0:
		survey_steps_left = 0
		message.emit(content.text("msg_survey_cancelled"))
		survey_changed.emit(false, 0.0)


func survey_radius_here() -> float:
	if in_tower():
		return tuning.num("map.tower_radius")
	return tuning.num("map.outlook_radius") if on_outlook() else tuning.num("map.survey_radius")


func _finish_survey() -> void:
	var outlook := on_outlook()
	var tower := in_tower()
	var at := door_front(location) if tower else outdoor_pos
	map.reveal_circle(at, survey_radius_here())
	needs.spend(tuning.num("energy.survey"))
	message.emit(content.text("msg_tower_survey" if tower else ("msg_outlook_survey" if outlook else "msg_survey_done")))
	survey_changed.emit(false, 1.0)
	_update_trace()


func map_location(landmark_id: String) -> void:
	var row := content.row("landmarks", landmark_id)
	var radius := float(row.get("reveal_radius", tuning.num("map.location_radius")))
	map.reveal_circle(world.landmark_pos(landmark_id), radius)
	map.mark_landmark(landmark_id)
	needs.spend(tuning.num("energy.map_location"))
	message.emit(content.text("msg_map_location", {"name": content.text(row["name"])}))
	pass_minutes(tuning.integer("map.location_minutes"))
	_update_trace()
	_check_collapse()


# --- debug tools (also used by the tests) ---------------------------------

func debug_set_time(minute: int) -> void:
	clock.set_minute(minute)
	weather.check_change(clock.minute)


func debug_skip_block() -> void:
	var starts: Array = tuning.value("weather.blocks")
	var b := weather.block_index(clock.minute)
	if b + 1 < starts.size():
		debug_set_time(int(starts[b + 1]))
	else:
		debug_skip_day()


func debug_skip_day() -> void:
	clock.start_next_day()


func debug_skip_season() -> void:
	var target := (clock.season + 1) % 4
	while clock.season != target:
		clock.start_next_day()


func debug_fast(on: bool) -> void:
	clock.speed_multiplier = tuning.num("time.debug_fast_multiplier") if on else 1.0


func debug_force_weather(id: String) -> void:
	weather.force_now(clock.minute, id)
	weather.check_change(clock.minute)


func debug_set_next_weather(id: String) -> void:
	weather.set_next_block(clock.minute, id)


func debug_set_needs(energy: float, warmth: float) -> void:
	needs.set_values(energy, warmth)


func debug_drain(energy_on: bool, warmth_on: bool) -> void:
	needs.energy_drain_on = energy_on
	needs.warmth_drain_on = warmth_on


func debug_teleport(spawn_name: String) -> void:
	if is_indoors():
		location = ""
		location_changed.emit(location)
	outdoor_pos = world.spawn(spawn_name)
	_last_tile = Vector2i(-9999, -9999)
	_update_trace()


func debug_add_item(item: String, n: int = 1) -> int:
	return backpack.add(item, n)


func debug_cabin_step(step: String, complete: bool) -> void:
	if complete:
		structures.debug_complete_step("test_cabin", step)
	else:
		structures.debug_undo_step("test_cabin", step)


func debug_reveal_map() -> void:
	map.reveal_all()


func debug_wipe_map() -> void:
	map.wipe()


## Clears or restores the obstacle covering a tile.
func debug_clear_obstacle(t: Vector2i, on: bool = true) -> bool:
	if on:
		var ob := obstacle_at(t)
		if ob.is_empty():
			return false
		_set_cleared(ob["origin"], ob["id"], true)
		return true
	for dx in range(0, 3):
		var o := t - Vector2i(dx, 0)
		if cleared.has(o):
			_set_cleared(o, "", false)
			return true
	return false


## Digs, or undoes the digging of, one tile of trail.
func debug_dig(t: Vector2i, on: bool = true) -> void:
	if on and can_dig(t):
		_set_dug(t, true)
	elif not on and dug.has(t):
		_set_dug(t, false)


func debug_reload_tuning() -> bool:
	return tuning.reload()
