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
	return not is_night() or on_trail()


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
	var text := content.text("msg_rescue_cabin" if content.row("structures", bed)["kind"] == "cabin" else "msg_rescue_station")
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
	var obj := world.interactive_near(outdoor_pos, reach + 0.5)
	if obj.is_empty():
		return
	var what: String = obj["interact"]
	if what == "gate":
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
	elif item == "hammer":
		hammer()
	elif item == "map":
		start_survey()
	elif item == "axe":
		chop()
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


# --- jobs ------------------------------------------------------------------------

func read_note_board() -> String:
	var texts: PackedStringArray = []
	var added := false
	for j: Dictionary in content.rows("jobs"):
		texts.append(content.text(j["offer"]))
		if not jobs_known.has(j["id"]):
			jobs_known[j["id"]] = true
			added = true
	var text := "\n\n".join(texts)
	note_read.emit(text)
	if added:
		message.emit(content.text("msg_job_added"))
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


## Returns "" if surveying is possible now, or the text id saying why not.
func _survey_conditions_ok() -> String:
	if is_indoors():
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
	return tuning.num("map.outlook_radius") if on_outlook() else tuning.num("map.survey_radius")


func _finish_survey() -> void:
	var outlook := on_outlook()
	map.reveal_circle(outdoor_pos, survey_radius_here())
	needs.spend(tuning.num("energy.survey"))
	message.emit(content.text("msg_outlook_survey" if outlook else "msg_survey_done"))
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


func debug_reload_tuning() -> bool:
	return tuning.reload()
