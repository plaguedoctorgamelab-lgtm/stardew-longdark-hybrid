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
signal cooking_opened
signal backpack_grew
signal list_requested(kind: String, title: String, options: Array)
## A survey finished: the map opens so the ranger sees what was drawn.
signal survey_finished
## Things dropped on the ground came or went.
signal piles_changed
## The ranger walked the trail somewhere in one go (trail travel).
signal traveled

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
var debug_show_visitors: bool = false
var _collapsing: bool = false

# The ranger's camp, if one is made: {"bed": Vector2i, "fire": Vector2i, "fire_minutes": int}.
var camp: Dictionary = {}
# Chopped trees: tile -> the absolute day it was chopped. They regrow.
var chopped: Dictionary = {}
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

# Phase 2b: living out there.
var forage: Forage
var skills: Skills
var recipes_known: Dictionary = {}   # recipe id -> true
var ideas_had: Dictionary = {}       # idea id -> true
var pack_frame: bool = false         # the pack frame is made: the backpack is bigger
var kits_set: Dictionary = {}        # structure id -> true: a workbench set up there from a kit
var boardwalk: Dictionary = {}       # tile -> true: boardwalk the ranger laid
var pending_wake: Array = []         # [skill id, level]: level-ups told on waking
var wake_offer: bool = false         # a specialty is to be offered once the wake-up note closes
var _trembling: bool = false
var _sensing: bool = false
var _loading: bool = false
var _hold_ideas: bool = false
var park: Park                       # phase 3: money, visitors, facilities and upkeep
var box_offer: bool = false          # pinning cards is offered once the box's note closes
var _pending_pad: String = ""
var piles: Dictionary = {}           # tile -> Inventory: things the ranger dropped on the ground
var guide: Guide                     # what X and C do here, the "?" marks
var jobs: Jobs                       # the jobs module: every job, its steps and rewards
var visits: Dictionary = {}          # travel place id -> times the ranger has arrived there
var _near_place: String = ""         # the travel place the ranger is at now, if any
var _traveling: bool = false
var _reach_cache: Dictionary = {}   # "station" -> the tiles trail joins to the station, until the land changes
var last_collapse_cause: String = ""   # why the ranger last passed out
var bench_boxes: Dictionary = {}       # structure id -> Inventory: each workbench's own small box
var recipes_new: Array[String] = []    # recipes learned since the last "you can make this now" pop-up
var shelf_seen: Dictionary = {}      # structure id -> the supply shelf as last looked at


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
	forage = Forage.new(content, tuning, world)
	skills = Skills.new(content, tuning)
	skills.levelled.connect(_on_skill_level)
	skills.specs_changed.connect(_apply_skills)
	backpack.changed.connect(func() -> void:
		if not _hold_ideas and not _loading:
			_check_ideas())
	clock.step_passed.connect(_on_step)
	clock.day_started.connect(_on_day_started)
	clock.day_end_reached.connect(_on_day_end)
	needs.ran_out.connect(_on_ran_out)
	park = Park.new(self)
	land_changed.connect(func(_t: Vector2i) -> void:
		park.net.mark_dirty()
		_reach_cache.clear())
	tree_changed.connect(func(_t: Vector2i) -> void: _reach_cache.clear())
	park.note.connect(func(text: String) -> void: message.emit(text))
	guide = Guide.new(self)
	jobs = Jobs.new(self)
	land_changed.connect(func(_t: Vector2i) -> void: jobs.mark_dirty())
	tree_changed.connect(func(_t: Vector2i) -> void: jobs.mark_dirty())
	backpack.changed.connect(func() -> void: jobs.mark_dirty())
	# The small things jobs ask about indoors stand in their rooms like furniture.
	for id: String in jobs.spot_ids():
		var sp := jobs.spot_row(id)
		if str(sp["where"]) != "outdoor" and not sp.has("furniture") and interiors.has(sp["where"]):
			(interiors[sp["where"]] as InteriorLayout).furniture.append({"id": id, "kind": "job_spot", "pos": sp["pos"], "size": sp["size"], "sprite": sp["sprite"]})
	jobs.spots_changed.connect(_refresh_spot_rooms)


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
	_loading = true
	ideas_had = {}
	_set_pack_frame(false)
	backpack.clear()
	_loading = false
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
	rumors = {}
	notes_read = {}
	sites_found = {}
	sites_open = {}
	site_overrides = {}
	finds_found = {}
	forage.start(seed_value)
	skills.reset()
	_reset_recipes()
	_set_kits({})
	pending_wake = []
	wake_offer = false
	_trembling = false
	_sensing = false
	_reset_land()
	_apply_seasons()
	_reach_cache.clear()
	bench_boxes = {}
	recipes_new.clear()
	park.new_game()
	visits = {"ranger_station": tuning.integer("travel.visits_needed")}
	_near_place = ""
	piles = {}
	piles_changed.emit()
	camp_changed.emit()
	weather.check_change(clock.minute)
	jobs.new_game()


## Rooms hide the small job things once they are done and gone.
func _refresh_spot_rooms() -> void:
	for id: String in interiors:
		var layout: InteriorLayout = interiors[id]
		layout.hidden = {}
		for f: Dictionary in layout.furniture:
			if str(f["kind"]) == "job_spot" and not jobs.spot_shown(str(f["id"])):
				layout.hidden[str(f["id"])] = true


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
			"ember": bool(camp.get("ember", false)),
		},
		"chopped": chopped.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, chopped[t]]),
		"rumors": rumors.keys(),
		"notes_read": notes_read.keys(),
		"sites": {"found": sites_found.keys(), "open": sites_open.keys()},
		"finds": finds_found.keys(),
		"land": land_to_dict(),
		"living": {
			"forage": forage.to_dict(),
			"skills": skills.to_dict(),
			"recipes": recipes_known.keys(),
			"ideas": ideas_had.keys(),
			"pack_frame": pack_frame,
			"kits": kits_set.keys(),
			"wake": pending_wake.duplicate(true),
		},
		"park": park.to_dict(),
		"visits": visits.duplicate(),
		"jobs2": jobs.to_dict(),
		"bench_boxes": bench_boxes.keys().map(func(k: String) -> Array: return [k, (bench_boxes[k] as Inventory).to_array()]),
		"piles": piles.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, (piles[t] as Inventory).to_array()]),
	}


func from_dict(d: Dictionary) -> void:
	seed_value = int(d["seed"])
	clock.from_dict(d["clock"])
	weather.from_dict(d["weather"])
	var r: Dictionary = d["ranger"]
	outdoor_pos = Vector2(float(r["outdoor_pos"][0]), float(r["outdoor_pos"][1]))
	interior_pos = Vector2(float(r["interior_pos"][0]), float(r["interior_pos"][1]))
	location = r["location"]
	# A room's layout can change between versions: never load into a wall.
	if interiors.has(location):
		var layout: InteriorLayout = interiors[location]
		if layout.is_solid(Vector2i(floori(interior_pos.x), floori(interior_pos.y))):
			interior_pos = layout.entry
		interior_pos = clear_spot(layout, interior_pos)
	facing = int(r["facing"])
	selected_slot = int(r["selected_slot"])
	needs.from_dict(d["needs"])
	# Phase 2b state; a phase 2a save has none, and starts at level 0 with the
	# starting recipes and no ideas.
	var lv: Dictionary = d.get("living", {})
	_loading = true
	ideas_had = {}
	for id: Variant in lv.get("ideas", []):
		if content.has("ideas", str(id)):
			ideas_had[str(id)] = true
	_set_pack_frame(bool(lv.get("pack_frame", false)))
	backpack.from_array(d["backpack"])
	_loading = false
	structures.from_dict(d["structures"])
	map.from_dict(d["map"])
	# Added after the first phase one saves; older saves simply have none.
	var c: Dictionary = d.get("camp", {})
	camp = {} if c.is_empty() else {
		"bed": Vector2i(int(c["bed"][0]), int(c["bed"][1])),
		"fire": Vector2i(int(c["fire"][0]), int(c["fire"][1])),
		"fire_minutes": int(c["fire_minutes"]),
		"ember": bool(c.get("ember", false)),
	}
	for t: Vector2i in chopped.keys():
		_set_chopped(t, -1)
	for e: Array in d.get("chopped", []):
		_set_chopped(Vector2i(int(e[0]), int(e[1])), int(e[2]))
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
	forage.from_dict(lv.get("forage", {}), seed_value)
	skills.from_dict(lv.get("skills", {}))
	_reset_recipes()
	for id: Variant in lv.get("recipes", []):
		if content.has("recipes", str(id)):
			recipes_known[str(id)] = true
	var kits := {}
	for id: Variant in lv.get("kits", []):
		kits[str(id)] = true
	_set_kits(kits)
	pending_wake = []
	for e: Variant in lv.get("wake", []):
		pending_wake.append([str(e[0]), int(e[1])])
	wake_offer = false
	_trembling = false
	_sensing = false
	_apply_seasons()
	park.from_dict(d.get("park", {}))
	_reach_cache.clear()
	visits = {"ranger_station": tuning.integer("travel.visits_needed")}
	for k: String in d.get("visits", {}):
		visits[k] = maxi(int(visits.get(k, 0)), int(d["visits"][k]))
	bench_boxes = {}
	for e: Array in d.get("bench_boxes", []):
		var inv := Inventory.new(content, tuning.integer("storage.bench_slots"))
		inv.from_array(e[1])
		bench_boxes[str(e[0])] = inv
	recipes_new.clear()
	_near_place = ""
	piles = {}
	for e: Array in d.get("piles", []):
		var inv := Inventory.new(content, tuning.integer("storage.pile_slots"))
		inv.from_array(e[2])
		piles[Vector2i(int(e[0]), int(e[1]))] = inv
	tidy_piles()
	piles_changed.emit()
	camp_changed.emit()
	survey_steps_left = 0
	_last_tile = Vector2i(-9999, -9999)
	weather.check_change(clock.minute)
	# Saves from before the jobs rebuild have no jobs: they are worked out
	# from the world, and those already done are finished and paid.
	jobs.from_dict(d.get("jobs2", {}), not d.has("jobs2"))


func save_game() -> bool:
	jobs.update(true)
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


## The weather symbol to show: a weather's night symbol after dark, if it has one.
func weather_icon() -> String:
	var row := weather_row()
	if is_night() and row.has("night_icon"):
		return row["night_icon"]
	return row["icon"]


func is_night() -> bool:
	return Daylight.is_night(tuning, clock.season_name(), clock.minute)


func ground_here() -> String:
	if is_indoors():
		return "indoors"
	return world.ground_at(ranger_tile())


## On trail, or on boardwalk the ranger laid (which counts as trail).
func on_trail() -> bool:
	return not is_indoors() and (world.ground_at(ranger_tile()) == "trail" or boardwalk.has(ranger_tile()))


func on_outlook() -> bool:
	if is_indoors():
		return false
	var c: Array = world.meta["outlook_center"]
	return outdoor_pos.distance_to(Vector2(float(c[0]), float(c[1]))) <= tuning.num("map.outlook_reach_tiles")


func selected_item() -> String:
	return backpack.item_at(selected_slot)


## The family of an item: a tool and its refitted versions share one.
func family_of(item: String) -> String:
	if item == "":
		return ""
	return str(content.row("items", item).get("family", item))


## The magical ingredient a refitted tool holds, or "".
func refit_of(item: String) -> String:
	if item == "":
		return ""
	return str(content.row("items", item).get("refit", ""))


## The ranger's tool of a family in the backpack (the first one), or "".
func tool_in_pack(family: String) -> String:
	var i := backpack.find_family(family)
	return backpack.item_at(i) if i >= 0 else ""


func lantern_lit() -> bool:
	return family_of(selected_item()) == "lantern"


## How far the held lantern lights, in tiles.
func lantern_radius() -> float:
	if refit_of(selected_item()) == "glowcap":
		return tuning.num("refits.glowcap_lantern_radius")
	return tuning.num("light.lantern_radius_tiles")


## The three marker rules: on revealed ground, weather that allows it, and
## daytime or on a trail. The true compass keeps the marker at night and in
## fog, off the trail too; only the weathers tuned for it hide it.
func marker_visible() -> bool:
	if is_indoors():
		var p: Dictionary = world.structure_placement(location)
		return map.is_revealed(Vector2i(int(p["door"][0]), int(p["door"][1])))
	if not map.is_revealed(ranger_tile()):
		return false
	if refit_of(tool_in_pack("compass")) == "lodestone_sliver":
		return not (tuning.value("refits.true_compass_hidden_by") as Array).has(current_weather())
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
		var gs := float(table.get(g, 1.0))
		if g == "tall_grass" and skills.flag("tall_grass_unslowed"):
			gs = float(table.get("grass", 1.0))
		s *= gs
		if not on_trail():
			s *= skills.value("offtrail_speed", 1.0)
		s *= float(weather_row().get("speed", 1.0))
	if needs.is_exhausted():
		s *= tuning.num("movement.exhausted_speed")
	return s


# --- each frame ---------------------------------------------------------------

func process(real_delta: float) -> void:
	clock.process(real_delta)
	park.advance_to(park_minute())
	jobs.process(real_delta)


## The clock's minute with the part of the current ten minutes gone by, so
## visitors walk smoothly between the clock's steps.
func park_minute() -> float:
	if clock.paused or clock.is_day_over():
		return float(clock.minute)
	var k := clampf(clock._accum / tuning.num("time.real_seconds_per_step"), 0.0, 0.999)
	return float(clock.minute) + k * clock.step_minutes()


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
		_watch_magic()
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
		"walked": _walked_this_step > 0.05 or _traveling,
		"rough": _rough_this_step,
		"campfire": near_lit_fire() or near_warm_camp(),
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
		_watch_visits()
	_check_collapse()


## Passes game time at once, as for an action that takes time.
func pass_minutes(minutes: int) -> void:
	var steps := ceili(float(minutes) / clock.step_minutes())
	for i in steps:
		if clock.is_day_over() or _collapsing:
			break
		clock.advance_step()
	park.advance_to(float(clock.minute))


func _on_day_started(_day: int, _season: int, _year: int) -> void:
	# The park finishes yesterday first, under yesterday's weather.
	park.on_new_day()
	# Yesterday's weather is still in place: remember a wet day for the
	# forage that comes up after rain.
	for w: String in weather.today:
		if ["rain", "storm"].has(w):
			forage.note_wet_day(clock.absolute_day() - 1)
			jobs.flags["rain_day"] = clock.absolute_day() - 1
			break
	weather.roll_day(clock.absolute_day())
	# Phase 3: the supply shelf is stocked by catalog orders, not for free.
	for id: String in structures.stove_minutes:
		structures.stove_minutes[id] = 0
	if not camp.is_empty():
		camp["fire_minutes"] = 0
		camp_changed.emit()
	_regrow_trees()
	_apply_seasons()
	weather.check_change(clock.minute)
	park.start_day()
	jobs.morning(clock.day == 1)
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
		if not r.get("has_bed", false) or not structures.is_open(id) or bed_taken(id):
			continue
		var p: Dictionary = world.structure_placement(id)
		var d := here.distance_to(Vector2(float(p["door"][0]) + 0.5, float(p["door"][1]) + 1.0))
		if d < best_d:
			best_d = d
			best = id
	return best


## Why the ranger is about to collapse: "warmth", "energy" or "late" (out
## past the end of the day). Cold is told first: it is the likelier killer.
func collapse_cause() -> String:
	if needs.warmth <= 0.0:
		return "warmth"
	if needs.energy <= 0.0:
		return "energy"
	return "late"


func collapse() -> void:
	var cause := collapse_cause()
	last_collapse_cause = cause
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
	# Say plainly why it happened and what to do next time (tracker #6).
	var rescued := text
	text = content.text("msg_collapse_why_" + cause) + " " + content.text("msg_collapse_tip_" + cause, {"time": GameClock.time_of(tuning.integer("time.day_end_minute"))}) + "\n\n" + text
	var fee := rescue_fee()
	if fee > 0:
		park.money.spend(clock.absolute_day(), "rescue", fee)
		text += " " + content.text("msg_rescue_fee", {"n": fee})
	var woke := wake_lines()
	save_game()
	collapsed.emit(text if woke.is_empty() else text + "\n\n" + "\n".join(woke))
	# The line over the item bar stays short: the note has the rest.
	message.emit(rescued)


## A rescue costs a share of the wallet, up to a most; nothing from an empty one.
func rescue_fee() -> int:
	return mini(floori(park.money.wallet * tuning.num("money.rescue_share")), tuning.integer("money.rescue_most"))


func _put_in_bed(structure_id: String) -> void:
	location = structure_id
	var layout: InteriorLayout = interiors[structure_id]
	var bed := layout.find("bed")
	var r := layout.furniture_rect(bed)
	interior_pos = clear_spot(layout, Vector2(r.end.x + 0.5, r.position.y + 1.0))
	facing = FACING_DOWN
	location_changed.emit(location)


## The nearest point to p where the ranger's whole body is clear of walls and
## furniture: p itself if it is. Waking beside the tower's bed used to leave
## the ranger half inside the radio, unable to take a step (tracker #5).
func clear_spot(layout: InteriorLayout, p: Vector2) -> Vector2:
	var box_arr: Array = tuning.value("movement.ranger_box_tiles")
	var half := Vector2(float(box_arr[0]), float(box_arr[1])) / 2.0
	if not Mover.box_hits(p, half, layout.is_solid):
		return p
	var best := layout.entry
	var best_d := INF
	for y in layout.size.y:
		for x in layout.size.x:
			var c := Vector2(x + 0.5, y + 0.5)
			if Mover.box_hits(c, half, layout.is_solid) or Vector2i(x, y) == layout.door_tile:
				continue
			var d := c.distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


func request_sleep() -> void:
	pending_confirm = "sleep"
	confirm_requested.emit("sleep", content.text("msg_sleep_confirm"))


func answer_confirm(yes: bool) -> void:
	var kind := pending_confirm
	pending_confirm = ""
	if kind.begins_with("take_down:"):
		if yes:
			_take_down_facility(kind.substr(10))
		return
	if kind == "rent_sign":
		if yes:
			park.rent_mode = "ranger" if park.rent_mode == "rent" else "rent"
			message.emit(content.text("msg_rent_now", {"mode": content.text("rent_for_rent" if park.rent_mode == "rent" else "rent_ranger_only")}))
		return
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
	var woke := wake_lines()
	save_game()
	message.emit(content.text("msg_saved"))
	if not woke.is_empty():
		note_read.emit("\n".join(woke))


## The level-ups since the ranger last slept, one line each (with the perk a
## level brings), told on waking. A skill that has reached its specialty level
## is offered its choice once, when the wake-up note closes.
func wake_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for e: Array in pending_wake:
		var id: String = e[0]
		var l := int(e[1])
		lines.append(content.text("msg_skill_level", {"skill": _skill_name(id), "level": l}))
		var p := skills.perk_at(id, l)
		if not p.is_empty():
			lines.append(content.text("msg_skill_perk", {"perk": content.text(p["text"])}))
	pending_wake = []
	for id in skills.waiting():
		if not skills.offered.has(id):
			wake_offer = true
	lines.append_array(park.morning_lines)
	park.morning_lines = []
	return lines


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
	if bed_taken(structure_id):
		message.emit(content.text("msg_cabin_booked_note", {"party": park.booked_by}))
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
			if campfire_lit():
				cooking_opened.emit()
			else:
				feed_campfire()
			return
	var js := jobs.spot_in_reach("x", outdoor_pos, reach)
	if js != "":
		work_job_spot(js)
		return
	if _park_interact():
		return
	var pile := pile_in_reach()
	if pile.x >= 0:
		storage_opened.emit(content.text("ui_pile"), piles[pile])
		return
	var spot := forage_in_reach()
	if spot.x >= 0:
		pick_forage_around(spot)
		return
	var source := object_forage_in_reach()
	if source.x >= 0:
		pick_object(source)
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
			return
		# A site with no building (the outlook, the pond) is declared open
		# here, at its post or cairn, as a building is at its door.
		var site := site_for_landmark(lid)
		if site != "" and not sites_open.has(site) and site_ready(site):
			_pending_site = site
			pending_confirm = "open_site"
			confirm_requested.emit("open_site", content.text("msg_open_site_confirm", {"name": content.text(content.row("sites", site)["name"])}))
			return
		message.emit(content.text(content.row("landmarks", lid)["name"]))


## The site a landmark belongs to, or "".
func site_for_landmark(landmark_id: String) -> String:
	for r: Dictionary in content.rows("sites"):
		if r["landmark"] == landmark_id:
			return r["id"]
	return ""


func _landmark_for_structure(structure_id: String) -> String:
	return structure_id if content.has("landmarks", structure_id) else ""


func _interact_inside() -> void:
	var layout: InteriorLayout = interiors[location]
	var f := layout.furniture_near(interior_pos, tuning.num("world.interact_reach_tiles"))
	if f.is_empty():
		return
	match str(f["kind"]):
		"bed":
			if bed_taken(location):
				message.emit(content.text("msg_cabin_booked_note", {"party": park.booked_by}))
				return
			request_sleep()
		"catalog":
			open_catalog()
		"staff_board":
			open_staff_board()
		"radio":
			if location == "static_tower" and not jobs.unlocks.has("tower_forecast"):
				if jobs.is_active("tower_radio") and jobs.spot_open("tower_radio") and backpack.has("radio_valve"):
					work_job_spot("tower_radio")
				else:
					message.emit(content.text("jt_radio_hiss"))
				return
			use_radio()
		"job_spot":
			work_job_spot(str(f["id"]))
		"shelf":
			shelf_seen[location] = str((structures.shelves[location] as Inventory).to_array())
			storage_opened.emit(content.text("ui_shelf"), structures.shelves[location])
		"chest":
			if bed_taken(location):
				message.emit(content.text("msg_cabin_booked_note", {"party": park.booked_by}))
				return
			storage_opened.emit(content.text("ui_chest"), structures.chests[location])
		"stove":
			if structures.stove_lit(location):
				cooking_opened.emit()
			else:
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
	var lp := park.lost_party()
	if not lp.is_empty():
		lines.append(content.text("msg_lost_radio", {"party": park.party_name(lp), "place": park.lost_place_name()}))
	radio_heard.emit(lines)
	return lines


func feed_stove() -> bool:
	if not is_indoors() or not structures.stove_minutes.has(location):
		return false
	var was_lit := structures.stove_lit(location)
	var mult := fire_burn_mult()
	if location == "test_cabin" and jobs.unlocks.has("cabin_chimney"):
		mult *= tuning.num("jobs.chimney_burn_mult")
	if not structures.feed_stove(location, backpack, mult):
		message.emit(content.text("msg_stove_no_wood"))
		return false
	message.emit(content.text("msg_stove_fed" if was_lit else "msg_stove_lit"))
	jobs.event("light", {"structure": location})
	return true


## Works a small thing a job asks about: tidies it, chops it, opens it.
func work_job_spot(id: String) -> void:
	var r := jobs.spot_row(id)
	var tool := str(r.get("action", ""))
	if tool in ["axe", "hammer"] and not backpack.has(tool):
		message.emit(content.text("jt_spot_need", {"what": content.item_name(tool).to_lower()}))
		return
	var text := jobs.work_spot(id)
	if text != "":
		message.emit(text)
	_check_collapse()


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
	elif row["kind"] == "park_thing":
		place_park_thing()
	elif row["kind"] == "placeable" and row.has("lays"):
		lay_boardwalk()
	elif row["kind"] == "placeable":
		begin_place()
	elif row["kind"] == "kit":
		set_up_kit()
	elif row["kind"] == "page":
		discover(str(row["find"]))
	elif item in ["hammer", "axe"] and not is_indoors() and jobs.spot_in_reach(item, outdoor_pos, tuning.num("clearing.reach_tiles")) != "":
		work_job_spot(jobs.spot_in_reach(item, outdoor_pos, tuning.num("clearing.reach_tiles")))
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
	elif family_of(item) == "bedroll":
		make_camp()
	elif item == "firewood" and fire_ring_in_reach().x >= 0:
		light_fire_ring(fire_ring_in_reach())
	elif item == "firewood":
		if is_indoors() and (interiors[location] as InteriorLayout).find("stove").size() > 0:
			feed_stove()
		elif not camp.is_empty() and outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= tuning.num("world.interact_reach_tiles"):
			feed_campfire()


func eat(item: String) -> bool:
	if not content.has("foods", item) or not backpack.remove(item, 1):
		return false
	var food := content.row("foods", item).duplicate()
	if bool(food.get("cooked", false)):
		var k := skills.value("cooked_food", 1.0)
		food["energy"] = float(food["energy"]) * k
		food["warmth"] = float(food["warmth"]) * k
	needs.eat(food)
	message.emit(content.text("msg_ate", {"item": content.item_name(item).to_lower()}))
	return true


func hammer() -> Dictionary:
	if not is_indoors():
		var front := ranger_tile() + facing_vector()
		if placed.has(front):
			return {"ok": take_down(front), "reason": "took_down"}
		var th := thing_in_reach()
		if th.x >= 0:
			return {"ok": pick_up_park_thing(th), "reason": "picked_up"}
		var pad := pad_in_reach(tuning.num("facilities.reach_tiles"))
		if pad != "":
			return hammer_pad(pad)
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
	needs.spend(tuning.num("energy.repair_action") * skills.energy_for("repair"))
	skills.act("repair")
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
	# The ember bedroll needs no firewood: it keeps the camp warm by itself.
	var ember := refit_of(tool_in_pack("bedroll")) == "ember_moss"
	if not ember and not backpack.remove("firewood", 1):
		message.emit(content.text("msg_camp_need_wood"))
		return false
	camp = {"bed": bed, "fire": fire, "fire_minutes": 0 if ember else fire_minutes_per_firewood(), "ember": ember}
	skills.act("make_camp")
	camp_changed.emit()
	message.emit(content.text("msg_camp_warm_bedroll" if ember else "msg_camp_made"))
	return true


## Minutes one firewood burns, in a camp fire or a stove, after skills.
func fire_minutes_per_firewood() -> int:
	return roundi(skills.value("fire_minutes_per_firewood", tuning.num("camp.fire_minutes_per_firewood")))


## How much longer than tuned a fire burns, after skills.
func fire_burn_mult() -> float:
	return float(fire_minutes_per_firewood()) / tuning.num("camp.fire_minutes_per_firewood")


## Beside a camp made with the ember bedroll, which stays warm with no fire.
func near_warm_camp() -> bool:
	if is_indoors() or camp.is_empty() or not bool(camp.get("ember", false)):
		return false
	var r := tuning.num("camp.fire_radius_tiles")
	return outdoor_pos.distance_to(Vector2(camp["bed"]) + Vector2(0.5, 0.5)) <= r or outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= r


func campfire_lit() -> bool:
	return not camp.is_empty() and int(camp["fire_minutes"]) > 0


func near_lit_fire() -> bool:
	if is_indoors():
		return false
	if park.fire_ring_lit_near(outdoor_pos, tuning.num("camp.fire_radius_tiles")):
		return true
	if not campfire_lit():
		return false
	return outdoor_pos.distance_to(Vector2(camp["fire"]) + Vector2(0.5, 0.5)) <= tuning.num("camp.fire_radius_tiles")


## Feeds the camp fire with one firewood.
func feed_campfire() -> bool:
	if camp.is_empty() or not backpack.remove("firewood", 1):
		message.emit(content.text("msg_camp_need_wood"))
		return false
	camp["fire_minutes"] = int(camp["fire_minutes"]) + fire_minutes_per_firewood()
	camp_changed.emit()
	message.emit(content.text("msg_camp_fire_fed"))
	return true


## Sleeping at camp: the next morning at 6:00, partly rested (more with the
## ember bedroll or the Camp hand specialty). The ranger packs up the bedroll
## and puts out the fire, and the game saves.
func camp_sleep() -> void:
	clock.start_next_day(tuning.integer("time.day_start_minute"))
	var ember := bool(camp.get("ember", false))
	var ef := tuning.num("refits.ember_bedroll_restore") if ember else tuning.num("camp.wake_energy_fraction")
	var wf := tuning.num("refits.ember_bedroll_restore") if ember else tuning.num("camp.wake_warmth_fraction")
	var extra := skills.value("camp_restore", 0.0)
	needs.set_values(
		maxf(needs.energy, minf(needs.max_energy(), needs.max_energy() * ef + extra)),
		maxf(needs.warmth, minf(needs.max_warmth(), needs.max_warmth() * wf + extra)))
	location = ""
	outdoor_pos = Vector2(camp["bed"]) + Vector2(0.5, 0.5)
	facing = FACING_DOWN
	camp = {}
	camp_changed.emit()
	var woke := wake_lines()
	save_game()
	message.emit(content.text("msg_camp_woke"))
	if not woke.is_empty():
		note_read.emit("\n".join(woke))


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
	var n := roundi(skills.value("chop_firewood", tuning.num("axe.firewood")))
	var left := backpack.add("firewood", n)
	needs.spend(tuning.num("axe.energy") * skills.energy_for("chop"))
	skills.act("chop")
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
	for t: Vector2i in boardwalk.keys():
		_set_boardwalk(t, false)
	clearing_progress = {}


func land_to_dict() -> Dictionary:
	return {
		"cleared": cleared.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, cleared[t]]),
		"progress": clearing_progress.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, clearing_progress[t]]),
		"dug": dug.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y]),
		"placed": placed.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y, placed[t]["item"], placed[t]["place"]]),
		"boardwalk": boardwalk.keys().map(func(t: Vector2i) -> Array: return [t.x, t.y]),
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
	for e: Array in d.get("boardwalk", []):
		_set_boardwalk(Vector2i(int(e[0]), int(e[1])), true)


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
	# Each obstacle's experience: a cut at a fallen trunk, or clearing brush.
	var action := "trunk_chop" if ob["id"] == "fallen_trunk" else "clear_brush"
	var total := tuning.integer(key + ".actions")
	if ob["id"] == "fallen_trunk":
		total = roundi(skills.value("trunk_actions", total))
	total = maxi(1, total)
	needs.spend(tuning.num(key + ".energy") * skills.energy_for(action))
	var finished := done >= total
	if ob["id"] == "fallen_trunk":
		skills.act(action)
	if finished:
		_set_cleared(origin, ob["id"], true)
		if ob["id"] != "fallen_trunk":
			skills.act(action)
		message.emit(content.text("msg_cleared", {"what": what}))
		var gives: Dictionary = row.get("gives", {})
		for item: String in gives:
			if backpack.add(item, int(gives[item])) > 0:
				message.emit(content.text("msg_backpack_full"))
	else:
		clearing_progress[origin] = done
		message.emit(content.text("msg_clear_progress", {"what": what, "done": done, "total": total}))
	var minutes := float(tuning.integer(key + ".minutes"))
	if ob["id"] == "brush":
		minutes = skills.value("brush_minutes", minutes)
	if minutes > 0.0:
		pass_minutes(roundi(minutes))
	_check_collapse()
	return {"ok": true, "id": ob["id"], "origin": origin, "done": done, "total": total, "cleared": finished}


func can_dig(t: Vector2i) -> bool:
	if not world.in_bounds(t) or world.is_solid(t) or dug.has(t):
		return false
	if jobs.spot_blocks_dig(t):
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
	if park.diggings.has(t):
		park.fill_digging(t)
		message.emit(content.text("msg_badger_dig_filled"))
		pass_minutes(tuning.integer("trail.minutes"))
		return {"ok": true, "tiles": [t]}
	# Something buried here comes up first.
	if forage.magic_at(t) != "" and forage.has_magic(t, clock.absolute_day(), forage_ctx()):
		return dig_up(t)
	for i in dig_tiles():
		if not can_dig(t):
			break
		_set_dug(t, true)
		made.append(t)
		t += facing_vector()
	if made.is_empty():
		message.emit(content.text("msg_cant_dig"))
		return {"ok": false, "reason": "here"}
	needs.spend(tuning.num("trail.energy") * skills.value("dig_energy", 1.0) * skills.energy_for("dig_tile"))
	skills.act("dig_tile", made.size())
	message.emit(content.text("msg_dug"))
	pass_minutes(tuning.integer("trail.minutes"))
	_check_collapse()
	return {"ok": true, "tiles": made}


# --- trail travel --------------------------------------------------------------

## The places trail travel can reach: the station and every site found.
## {id: door point}.
func travel_places() -> Dictionary:
	var out := {"ranger_station": door_front("ranger_station")}
	for r: Dictionary in content.rows("sites"):
		if jobs.travel_open.has(r["id"]):
			out[r["id"]] = site_door(r["id"])
	if jobs.travel_open.has("bridge"):
		out["bridge"] = world.spawn("bridge")
	return out


func travel_name(id: String) -> String:
	if id == "ranger_station":
		return content.text("ui_place_station")
	if id == "bridge":
		return content.text("ui_place_bridge_end")
	if not content.has("sites", id):
		return id
	return content.text(content.row("sites", id)["name"])


## Counts an arrival each time the ranger comes to a place after being well
## away from it.
func _watch_visits() -> void:
	var places := travel_places()
	if _near_place != "" and places.has(_near_place) and outdoor_pos.distance_to(places[_near_place]) > tuning.num("travel.leave_radius_tiles"):
		_near_place = ""
	for id: String in places:
		if id != _near_place and outdoor_pos.distance_to(places[id]) <= tuning.num("travel.arrive_radius_tiles"):
			_near_place = id
			visits[id] = int(visits.get(id, 0)) + 1
			break


## Steps along trail, boardwalk and short fords from tile a to every trail
## tile it joins: {tile: steps}. The same ground site_reached walks on.
func _trail_steps_from(a: Vector2i) -> Dictionary:
	var grounds: Array = tuning.value("sites.reach_grounds")
	var ford_max := tuning.integer("sites.ford_max_tiles")
	var steps := {a: 0}
	var run := {a: 0}
	var queue: Array[Vector2i] = [a]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var t := queue[head]
		head += 1
		for d in dirs:
			var n := t + d
			if steps.has(n) or world.is_solid(n):
				continue
			var g := world.ground_at(n)
			var r := 0
			if g == "shallows":
				r = int(run[t]) + 1
				if r > ford_max:
					continue
			elif not grounds.has(g):
				continue
			steps[n] = int(steps[t]) + 1
			run[n] = r
			queue.append(n)
	return steps


## The trail tile under or right beside the ranger, or (-1, -1).
func _trail_start() -> Vector2i:
	var grounds: Array = tuning.value("sites.reach_grounds")
	var here := ranger_tile()
	for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if grounds.has(world.ground_at(here + d)) and not world.is_solid(here + d):
			return here + d
	return Vector2i(-1, -1)


func travel_minutes_per_tile() -> float:
	var game_min_per_sec := tuning.num("time.minutes_per_step") / tuning.num("time.real_seconds_per_step")
	return game_min_per_sec / tuning.num("movement.trail_speed_tiles") * tuning.num("travel.time_mult")


## Where the ranger can walk the trail to from here, in one go:
## [{id, label, minutes}]. Only from the trail, outdoors, to places arrived at
## often enough and joined to here by trail. Empty when none.
func travel_options() -> Array:
	var out := []
	if is_indoors() or survey_steps_left > 0 or not bool(tuning.value("travel.enabled")):
		return out
	var start := _trail_start()
	if start.x < 0:
		return out
	var steps := _trail_steps_from(start)
	var places := travel_places()
	for id: String in places:
		if outdoor_pos.distance_to(places[id]) <= tuning.num("travel.arrive_radius_tiles"):
			continue
		# Trail travel reaches a place when trail comes within a few tiles of
		# its door, as a site counts as joined (tracker #15).
		var door := Vector2i(places[id])
		var best := -1
		var r := tuning.integer("sites.spot_reach_tiles")
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := door + Vector2i(dx, dy)
				if steps.has(t) and Vector2(t).distance_to(Vector2(door)) <= r and (best < 0 or int(steps[t]) < best):
					best = int(steps[t])
		if best < 0:
			continue
		var minutes := roundi(best * travel_minutes_per_tile())
		out.append({"id": id, "label": content.text("ui_travel_to", {"name": travel_name(id), "time": content.text("ui_hours_minutes", {"h": minutes / 60, "m": minutes % 60})}), "minutes": minutes})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["minutes"]) < int(b["minutes"]))
	return out


## Walks the trail to a place in one go: the time passes and the walk tires
## the ranger as walking does; the way is not seen again.
func travel_to(id: String) -> bool:
	var opt := {}
	for o: Dictionary in travel_options():
		if o["id"] == id:
			opt = o
	if opt.is_empty():
		message.emit(content.text("msg_travel_cant"))
		return false
	outdoor_pos = travel_places()[id]
	facing = FACING_DOWN
	_near_place = id
	_traveling = true
	pass_minutes(int(opt["minutes"]))
	_traveling = false
	_update_trace()
	traveled.emit()
	message.emit(content.text("msg_traveled", {"name": travel_name(id)}))
	_check_collapse()
	return true


# --- dropping and throwing away ------------------------------------------------

## Drops the stack in slot i of an inventory: on the ground where the ranger
## stands, or, indoors, into the building's chest. Returns true if it went.
func drop_slot(inv: Inventory, i: int) -> bool:
	var s := inv.slot(i)
	if s.is_empty():
		return false
	var into: Inventory = null
	if is_indoors():
		into = structures.chests.get(location, null)
		if into == null or into == inv:
			message.emit(content.text("msg_drop_indoors"))
			return false
	else:
		var t := ranger_tile()
		if not piles.has(t):
			piles[t] = Inventory.new(content, tuning.integer("storage.pile_slots"))
		into = piles[t]
		if into == inv:
			return false
	var item: String = s["item"]
	var n := int(s["count"])
	inv.take_slot(i)
	var left := into.add(item, n)
	if left > 0:
		inv.add(item, left)
	if left >= n:
		message.emit(content.text("msg_drop_full"))
		tidy_piles()
		return false
	message.emit(content.text("msg_dropped_chest" if is_indoors() else "msg_dropped", {"n": n - left, "item": content.item_name(item).to_lower()}))
	piles_changed.emit()
	return true


## Throws away the stack in slot i for good. Tools are kept: they can be
## dropped instead.
func trash_slot(inv: Inventory, i: int) -> bool:
	var s := inv.slot(i)
	if s.is_empty():
		return false
	if str(content.row("items", s["item"]).get("kind", "")) in ["tool", "page"]:
		message.emit(content.text("msg_trash_tool"))
		return false
	inv.take_slot(i)
	message.emit(content.text("msg_trashed", {"n": int(s["count"]), "item": content.item_name(s["item"]).to_lower()}))
	return true


## A pile of dropped things in reach, or (-1, -1).
func pile_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := tuning.num("world.interact_reach_tiles") + 0.5
	for t: Vector2i in piles:
		var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
		if d <= best_d and not (piles[t] as Inventory).is_empty():
			best_d = d
			best = t
	return best


## Forgets piles that are empty now, and has the rest drawn afresh.
func tidy_piles() -> void:
	for t: Vector2i in piles.keys():
		if (piles[t] as Inventory).is_empty():
			piles.erase(t)
	piles_changed.emit()


# --- crafting (phase 2b) ---------------------------------------------------------

## The recipes listed at a station: anywhere (the Crafting page), workbench
## (everything but cooking) or fire.
func recipes_at(station: String) -> Array:
	return content.rows("recipes").filter(func(r: Dictionary) -> bool:
		if station == "workbench":
			return r["station"] == "workbench" or r["station"] == "anywhere"
		return r["station"] == station)


## In a building with a workbench (the station's, or one set up from a kit).
func at_workbench() -> bool:
	return is_indoors() and not (interiors[location] as InteriorLayout).find("workbench").is_empty()


## The building's chest, when its things count for making: at a workbench or a
## lit stove inside that building. Otherwise null.
func craft_chest() -> Inventory:
	if not is_indoors() or not structures.chests.has(location):
		return null
	if at_workbench() or can_cook_here():
		return structures.chests[location]
	return null


## The workbench's own small box in this building, when the ranger is at a
## workbench; otherwise null. Made things go in it when the backpack is
## full, and what is in it counts for making (tracker #4).
func bench_box() -> Inventory:
	if not at_workbench():
		return null
	if not bench_boxes.has(location):
		bench_boxes[location] = Inventory.new(content, tuning.integer("storage.bench_slots"))
	return bench_boxes[location]


## How many of an item are at hand for making: the backpack, the chest when
## it counts, and the workbench's box.
func have(item: String) -> int:
	var n := backpack.count(item)
	var chest := craft_chest()
	if chest != null:
		n += chest.count(item)
	var box := bench_box()
	if box != null:
		n += box.count(item)
	return n


func has_tool(family: String) -> bool:
	if backpack.find_family(family) >= 0:
		return true
	var chest := craft_chest()
	if chest != null and chest.find_family(family) >= 0:
		return true
	var box := bench_box()
	return box != null and box.find_family(family) >= 0


## Takes n of an item: from the backpack first, then the workbench's box,
## then the chest.
func _take(item: String, n: int) -> void:
	var left := n
	for inv: Inventory in [backpack, bench_box(), craft_chest()]:
		if inv == null or left <= 0:
			continue
		var k := mini(left, inv.count(item))
		if k > 0:
			inv.remove(item, k)
			left -= k


## Whether the ranger can make things of this station here.
func station_ok(station: String) -> bool:
	match station:
		"anywhere":
			return true
		"workbench":
			return at_workbench()
		"fire":
			return can_cook_here()
	return false


## The magic slot a recipe shows: the variant whose ingredient the ranger has
## had the idea for, or {}. The slot is invisible until then.
func slot_variant(recipe_id: String) -> Dictionary:
	for v: Dictionary in content.rows("magic_variants"):
		if v["recipe"] == recipe_id and ideas_had.has(v["ingredient"]):
			return v
	return {}


## "" if the recipe can be made now, or the text id saying why not.
func craft_problem(recipe_id: String) -> String:
	if not recipes_known.has(recipe_id):
		return "msg_craft_missing"
	var r := content.row("recipes", recipe_id)
	if bool(r.get("once", false)) and _made_once(recipe_id):
		return "msg_craft_missing"
	if not station_ok(r["station"]):
		return "msg_cook_need_fire" if r["station"] == "fire" else "msg_craft_need_workbench"
	if r.has("tool") and not has_tool(str(r["tool"])):
		return "msg_craft_need_tool"
	if r.has("refit"):
		var v := slot_variant(recipe_id)
		if v.is_empty() or not has_tool(str(r["refit"])) or have(v["ingredient"]) < 1:
			return "msg_craft_missing"
		return ""
	for k: String in r["inputs"]:
		if have(k) < int(r["inputs"][k]):
			return "msg_craft_missing"
	var res: Dictionary = r["result"]
	if res.has("item"):
		# Room is counted after the inputs leave the backpack.
		var after := Inventory.new(content, backpack.size())
		after.from_array(backpack.to_array())
		for k: String in r["inputs"]:
			after.remove(k, mini(int(r["inputs"][k]), after.count(k)))
		var box := bench_box()
		if after.room_for(res["item"]) < int(res["count"]) and (box == null or box.room_for(res["item"]) < int(res["count"])):
			return "msg_backpack_full"
	return ""


func _made_once(recipe_id: String) -> bool:
	return recipe_id == "pack_frame" and pack_frame


## What a recipe needs and what is at hand: {name, inputs, can}.
func recipe_status(recipe_id: String) -> Dictionary:
	var r := content.row("recipes", recipe_id)
	var inputs := []
	for k: String in r["inputs"]:
		inputs.append({"item": k, "need": int(r["inputs"][k]), "have": have(k)})
	return {"name": content.text(r["name"]), "inputs": inputs, "can": craft_problem(recipe_id) == ""}


func recipe_line(recipe_id: String) -> String:
	var st := recipe_status(recipe_id)
	var parts: PackedStringArray = []
	for e: Dictionary in st["inputs"]:
		parts.append(content.text("ui_recipe_input", {"name": content.item_name(e["item"]), "have": e["have"], "need": e["need"]}))
	return content.text("ui_recipe_line", {"name": st["name"], "inputs": ", ".join(parts)})


## Makes a recipe here. A refit takes the ranger's tool and the magical
## ingredient in its slot, and gives back the changed tool in the same place.
## Making anything takes the tuned time and no energy.
func craft(recipe_id: String) -> bool:
	if not content.has("recipes", recipe_id):
		return false
	var why := craft_problem(recipe_id)
	var r := content.row("recipes", recipe_id)
	if why != "":
		message.emit(content.text(why, {"tool": content.item_name(str(r.get("tool", "saw"))).to_lower()}))
		return false
	_hold_ideas = true
	if r.has("refit"):
		var v := slot_variant(recipe_id)
		var family: String = r["refit"]
		_take(v["ingredient"], 1)
		var inv := backpack
		var i := backpack.find_family(family)
		for other: Inventory in [bench_box(), craft_chest()]:
			if i < 0 and other != null:
				inv = other
				i = inv.find_family(family)
		inv.replace_at(i, v["result"])
		message.emit(content.text("msg_refitted", {"tool": content.item_name(family).to_lower(), "ingredient": content.item_name(v["ingredient"]).to_lower()}))
	else:
		for k: String in r["inputs"]:
			_take(k, int(r["inputs"][k]))
		var res: Dictionary = r["result"]
		if str(res.get("effect", "")) == "pack_frame":
			_set_pack_frame(true)
			message.emit(content.text("msg_pack_frame"))
		else:
			var name := content.item_name(res["item"]).to_lower()
			var left := backpack.add(res["item"], int(res["count"]))
			if left > 0 and bench_box() != null:
				# The backpack is full: what is left goes in the bench's box.
				bench_box().add(res["item"], left)
				message.emit(content.text("msg_crafted_to_box", {"item": name}))
			else:
				message.emit(content.text("msg_cooked" if r["station"] == "fire" else "msg_crafted", {"item": name}))
	_hold_ideas = false
	if r["station"] == "fire":
		skills.act("cook")
	elif r["station"] == "workbench":
		skills.act("workbench")
	_check_ideas()
	pass_minutes(tuning.integer("crafting.minutes"))
	_check_collapse()
	return true


## The pack frame: the backpack grows to its tuned size, keeping every item.
## How many backpack slots the item bar shows, and number keys reach.
func bar_slots() -> int:
	return mini(tuning.integer("storage.bar_slots"), backpack.size())


func _set_pack_frame(on: bool) -> void:
	pack_frame = on
	var n := tuning.integer("crafting.pack_frame_slots") if on else tuning.integer("storage.backpack_slots")
	if backpack.size() != n:
		if n < backpack.size():
			backpack.clear()
		backpack.resize(n)
		selected_slot = mini(selected_slot, n - 1)
		backpack_grew.emit()


## The choices at a station: [{id, label, enabled}]. A refit shows its magic
## slot, marked with a question mark; the game never says what it will do.
## At a fire, adding firewood comes first.
func recipe_options(station: String) -> Array:
	var out := []
	if station == "fire":
		out.append({"id": "#firewood", "label": content.text("ui_add_firewood", {"n": backpack.count("firewood")}), "enabled": backpack.has("firewood")})
	# The Crafting page (K) lists every recipe known, wherever it is made; a
	# workbench or fire lists its own.
	var rows: Array = content.rows("recipes") if station == "anywhere" else recipes_at(station)
	if station == "workbench":
		var box := bench_box()
		out.append({"id": "#bench_box", "label": content.text("ui_bench_box", {"n": box.size() - box.slots.filter(func(x: Dictionary) -> bool: return x.is_empty()).size(), "m": box.size()}), "enabled": true})
	# Only recipes the ranger knows are shown: a new one is told in a pop-up
	# when it is learned (tracker #4).
	for r: Dictionary in rows:
		var id: String = r["id"]
		if not recipes_known.has(id):
			continue
		var can := craft_problem(id) == ""
		var label := ""
		if r.has("refit"):
			var v := slot_variant(id)
			if v.is_empty():
				continue
			var tool := content.text("ui_recipe_input", {"name": content.item_name(r["refit"]), "have": 1 if has_tool(r["refit"]) else 0, "need": 1})
			label = content.text("ui_slot_option", {"name": content.text(r["name"]), "inputs": tool, "ingredient": content.item_name(v["ingredient"]), "have": have(v["ingredient"])})
		else:
			label = recipe_line(id)
			if r.has("tool") and not has_tool(str(r["tool"])):
				label += " " + content.text("ui_needs_tool", {"tool": content.item_name(r["tool"]).to_lower()})
			if bool(r.get("once", false)) and _made_once(id):
				label += " " + content.text("ui_made_once")
		if not station_ok(r["station"]):
			label += " " + content.text("ui_made_at_" + str(r["station"]))
		if content.has("text", "recipe_use_" + id):
			label += "\n" + content.text("ui_recipe_use", {"use": content.text("recipe_use_" + id)})
		out.append({"id": id, "label": label, "enabled": can})
	return out


## How a recipe not yet known is learned, in a few words, or "" to keep it
## out of the lists (magic refits, and anything made with a magical
## ingredient, stay unseen until found).
func learn_hint(recipe_id: String) -> String:
	var r := content.row("recipes", recipe_id)
	if r.has("refit"):
		return ""
	for k: String in r["inputs"]:
		if str(content.row("items", k).get("kind", "")) == "magic":
			return ""
	match str(r["learned"]):
		"skill":
			for s: Dictionary in content.rows("skills"):
				for p: Dictionary in s.get("perks", []):
					if (p.get("recipes", []) as Array).has(recipe_id):
						return content.text("ui_learn_skill", {"skill": content.text(s["name"]), "level": int(p["level"])})
		"idea":
			for idea: Dictionary in content.rows("ideas"):
				if (idea["recipes"] as Array).has(recipe_id):
					if idea.has("item"):
						return content.text("ui_learn_idea", {"item": content.item_name(idea["item"]).to_lower()})
					return content.text("ui_learn_idea_" + str(idea["id"]))
	return ""


## Acts on one choice from recipe_options.
func choose_recipe(option_id: String) -> bool:
	if option_id == "#bench_box":
		storage_opened.emit(content.text("ui_bench_box_title"), bench_box())
		return true
	if option_id.begins_with("#") and option_id != "#firewood":
		return false
	if option_id == "#firewood":
		return feed_stove() if is_indoors() else feed_campfire()
	return craft(option_id)


## Sets up a workbench kit inside a repaired cabin or tower that has none.
func set_up_kit() -> bool:
	var ok := is_indoors() and structures.is_open(location) and ["cabin", "tower"].has(str(content.row("structures", location)["kind"]))
	if ok:
		var layout: InteriorLayout = interiors[location]
		ok = backpack.has("workbench_kit") and layout.set_up_workbench()
		if ok:
			var spot := layout.furniture_rect(layout.find("workbench"))
			if spot.has_point(Vector2i(floori(interior_pos.x), floori(interior_pos.y))):
				interior_pos = layout.entry
	if not ok:
		message.emit(content.text("msg_kit_bad_place"))
		return false
	backpack.remove("workbench_kit", 1)
	kits_set[location] = true
	location_changed.emit(location)
	message.emit(content.text("msg_kit_set_up"))
	return true


func _set_kits(kits: Dictionary) -> void:
	kits_set = {}
	for id: String in interiors:
		(interiors[id] as InteriorLayout).remove_kit_workbench()
	for id: String in kits:
		if interiors.has(id) and (interiors[id] as InteriorLayout).set_up_workbench():
			kits_set[id] = true


## Lays a stretch of boardwalk on the faced tile, on boggy ground or shallows.
## It counts as trail.
func lay_boardwalk() -> bool:
	if is_indoors():
		return false
	var t := ranger_tile() + facing_vector()
	var on: Array = tuning.value("trail.boardwalk_on")
	if not world.in_bounds(t) or world.is_solid(t) or boardwalk.has(t) or not on.has(world.ground_at(t)) or forage.magic_at(t) != "":
		message.emit(content.text("msg_boardwalk_bad_spot"))
		return false
	if not backpack.remove("boardwalk", 1):
		return false
	_set_boardwalk(t, true)
	needs.spend(tuning.num("trail.boardwalk_energy") * skills.energy_for("boardwalk"))
	skills.act("boardwalk")
	message.emit(content.text("msg_boardwalk_laid"))
	pass_minutes(tuning.integer("trail.boardwalk_minutes"))
	_check_collapse()
	return true


func _set_boardwalk(t: Vector2i, on: bool) -> void:
	if on:
		boardwalk[t] = true
		world.set_ground(t, "boards")
	else:
		boardwalk.erase(t)
		world.set_ground(t, "")
	map.touch(t)
	land_changed.emit(t)


# --- signs and trail markers -----------------------------------------------------

## Places a sign can name: the station, every site found and every place
## the ranger has mapped. The nearest come first.
func sign_places() -> Array:
	var out := [{"id": "ranger_station", "label": content.text("ui_place_station")}]
	var found := {}
	for r: Dictionary in content.rows("sites"):
		if sites_found.has(r["id"]):
			found[r["landmark"]] = true
	var rest := []
	for r: Dictionary in content.rows("landmarks"):
		if map.is_landmark_mapped(r["id"]) or found.has(r["id"]):
			rest.append({"id": r["id"], "label": content.text(r["name"]), "d": outdoor_pos.distance_to(world.landmark_pos(r["id"]))})
	rest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["d"]) < float(b["d"]))
	for e: Dictionary in rest:
		out.append({"id": e["id"], "label": e["label"]})
	return out


## On a trail or boardwalk, or right beside one (tuned), where a sign belongs.
func near_trail(t: Vector2i) -> bool:
	var r := tuning.integer("signs.beside_trail_tiles")
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if (tuning.value("sites.reach_grounds") as Array).has(world.ground_at(t + Vector2i(dx, dy))):
				return true
	return false


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
	var tool := str(row.get("needs_tool", "hammer"))
	if tool != "" and not backpack.has(tool):
		return "msg_place_need_hammer"
	if not world.in_bounds(t) or world.is_solid(t) or placed.has(t):
		return "msg_place_bad_spot"
	if world.object_at(t) != "" and not cleared.has(t) and not chopped.has(t):
		return "msg_place_bad_spot"
	if not camp.is_empty() and (camp["bed"] == t or camp["fire"] == t):
		return "msg_place_bad_spot"
	var g := world.ground_at(t)
	if row.get("on", "open") == "trail" and not near_trail(t):
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
	if kind.begins_with("specialty:") and option_id != "":
		choose_specialty(kind.split(":")[1], option_id)
		return
	if kind == "pin_card" and option_id != "":
		park.pin_card(int(option_id))
		message.emit(content.text("msg_box_pinned"))
		return
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
	var is_sign := item == "trail_sign"
	needs.spend(tuning.num("signs.put_up_energy") * (skills.energy_for("sign") if is_sign else 1.0))
	land_changed.emit(t)
	map.touch(t)
	if place_id != "":
		message.emit(content.text("msg_sign_up", {"place": place_name(place_id)}))
		# Say plainly whether it counts towards opening a site.
		for r: Dictionary in content.rows("sites"):
			if r["landmark"] == place_id and not sites_open.has(r["id"]):
				var ok := site_signed(r["id"])
				message.emit(content.text("msg_sign_counts" if ok else "msg_sign_too_far", {"name": content.text(r["name"]), "n": tuning.integer("sites.sign_distance_tiles")}))
	elif item == "cairn":
		message.emit(content.text("msg_cairn_up"))
	else:
		message.emit(content.text("msg_marker_up"))
	if is_sign:
		skills.act("sign")
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


## Whether the map shows a placed sign, marker or cairn. A cairn shows only
## once the ground it stands on is revealed.
func map_shows_placed(t: Vector2i) -> bool:
	if not placed.has(t):
		return false
	var row := content.row("items", placed[t]["item"])
	return not bool(row.get("map_when_revealed", false)) or map.is_revealed(t)


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


## Where a site is entered: its building's door, or its spot if it has none.
func site_door(site_id: String) -> Vector2:
	var r := content.row("sites", site_id)
	if str(r["structure"]) != "":
		return door_front(r["structure"])
	return Vector2(float(r["spot"][0]) + 0.5, float(r["spot"][1]) + 0.5)


func _look_for_sites() -> void:
	if is_indoors():
		return
	var r := tuning.num("sites.find_radius_tiles")
	for row: Dictionary in content.rows("sites"):
		var id: String = row["id"]
		if not sites_found.has(id) and outdoor_pos.distance_to(site_pos(id)) <= r:
			sites_found[id] = true
			jobs.mark_dirty()


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
			return str(row["structure"]) == "" or structures.is_open(row["structure"])
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
	# One search from the station answers for every site. It walks the whole
	# trail, so it is kept until the land changes: the hints and "?" marks
	# ask several times a second.
	if not _reach_cache.has("station"):
		_reach_cache["station"] = _trail_reach_from(Vector2i(door_front("ranger_station")))
	var home: Dictionary = _reach_cache["station"]
	var grounds: Array = tuning.value("sites.reach_grounds")
	var start := Vector2i(site_door(site_id))
	if str(content.row("sites", site_id)["structure"]) == "":
		# A site with no building (the outlook, the pond) is reached when the
		# station's trail comes within a few tiles of its spot: its trail ends
		# at the post or cairn, not on the spot itself.
		var r := tuning.integer("sites.spot_reach_tiles")
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := start + Vector2i(dx, dy)
				if Vector2(t).distance_to(Vector2(start)) <= r and home.has(t):
					return true
		return false
	if world.is_solid(start) or not grounds.has(world.ground_at(start)):
		return false
	return home.has(start)


## The gap still to dig between the station's trail and a site's: {a, b},
## the nearest pair of tiles, a on trail joined to the station and b on the
## site's own trail (or its door), both in tiles. {} when the site is joined.
## Kept until the land changes, like the search behind it (tracker #2).
func trail_gap(site_id: String) -> Dictionary:
	if site_reached(site_id):
		return {}
	var key := "gap:" + site_id
	if _reach_cache.has(key):
		return _reach_cache[key]
	if not _reach_cache.has("station"):
		_reach_cache["station"] = _trail_reach_from(Vector2i(door_front("ranger_station")))
	var home: Dictionary = _reach_cache["station"]
	var door := Vector2i(site_door(site_id))
	var theirs := _trail_reach_from(door)
	if theirs.is_empty():
		theirs = {door: 0}
	var a := Vector2i(door_front("ranger_station"))
	var best := INF
	for t: Vector2i in home:
		var d := Vector2(t).distance_squared_to(Vector2(door))
		if d < best:
			best = d
			a = t
	var b := door
	best = INF
	for t: Vector2i in theirs:
		var d := Vector2(t).distance_squared_to(Vector2(a))
		if d < best:
			best = d
			b = t
	var gap := {"a": a, "b": b}
	_reach_cache[key] = gap
	return gap


## Whether trail joins tile b to tile a, searching only near the two (for a
## gap a job asks to dig). margin is how far either side of the line to look.
func trail_joins(a: Vector2i, b: Vector2i, margin: int) -> bool:
	var key := "join:%d,%d:%d,%d" % [a.x, a.y, b.x, b.y]
	if _reach_cache.has(key):
		return bool(_reach_cache[key])
	var grounds: Array = tuning.value("sites.reach_grounds")
	var box := Rect2i(Vector2i(mini(a.x, b.x), mini(a.y, b.y)), Vector2i(absi(a.x - b.x) + 1, absi(a.y - b.y) + 1)).grow(margin)
	var ok := false
	if grounds.has(world.ground_at(a)) and not world.is_solid(a):
		var seen := {a: true}
		var queue: Array[Vector2i] = [a]
		var head := 0
		while head < queue.size() and not ok:
			var t := queue[head]
			head += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := t + d
				if seen.has(n) or not box.has_point(n) or world.is_solid(n):
					continue
				var g := world.ground_at(n)
				if not grounds.has(g) and g != "shallows":
					continue
				seen[n] = true
				if n == b:
					ok = true
					break
				queue.append(n)
	_reach_cache[key] = ok
	return ok


## Whether trail from near one point comes within r tiles of another: the
## same test a site uses for being joined.
func trail_reach_near(from: Vector2, to: Vector2, r: int) -> bool:
	var start := Vector2i(-1, -1)
	var grounds: Array = tuning.value("sites.reach_grounds")
	var f := Vector2i(from)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := f + Vector2i(dx, dy)
			if start.x < 0 and grounds.has(world.ground_at(t)) and not world.is_solid(t):
				start = t
	if start.x < 0:
		return false
	var key := "from:%d,%d" % [start.x, start.y]
	if not _reach_cache.has(key):
		_reach_cache[key] = _trail_reach_from(start)
	var reach: Dictionary = _reach_cache[key]
	var tt := Vector2i(to)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := tt + Vector2i(dx, dy)
			if reach.has(t) and Vector2(t).distance_to(Vector2(tt)) <= r:
				return true
	return false


## Every tile joined to a by trail, boardwalk and short fords: {tile: run}.
func _trail_reach_from(a: Vector2i) -> Dictionary:
	var grounds: Array = tuning.value("sites.reach_grounds")
	var ford_max := tuning.integer("sites.ford_max_tiles")
	if world.is_solid(a) or not grounds.has(world.ground_at(a)):
		return {}
	var best := {a: 0}   # tile -> fewest shallows waded in a row to get there
	var queue: Array = [[a, 0]]
	var head := 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var t: Vector2i = queue[head][0]
		var run: int = queue[head][1]
		head += 1
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
	return best


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
	jobs.update()
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
			if step == "repair" and str(row["structure"]) == "":
				label = content.text("site_step_repair_none")
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
	if here == "ranger_station":
		for l: Dictionary in park.unread_letters():
			texts.append(str(l["text"]))
			l["read"] = true
		if park.cabin_booked():
			texts.append(content.text("msg_cabin_booked", {"party": park.booked_by}))
		var lp := park.lost_party()
		if not lp.is_empty():
			texts.append(content.text("msg_lost_board", {"party": park.party_name(lp), "place": park.lost_place_name()}))
	if texts.is_empty():
		texts.append(content.text("msg_note_board_empty"))
	var text := "\n\n".join(texts)
	note_read.emit(text)
	if heard:
		message.emit(content.text("msg_rumor_added"))
	return text


# --- mapping ------------------------------------------------------------------

## Whether the map may show a landmark's rough hint: always, unless the hint
## is a rumor the ranger has not yet heard.
func hint_known(landmark_id: String) -> bool:
	var h: Dictionary = content.row("landmarks", landmark_id).get("hint", {})
	return not bool(h.get("rumor", false)) or rumors.has(landmark_id)


func _survey_total_steps() -> int:
	return maxi(1, ceili(skills.value("survey_minutes", tuning.num("map.survey_minutes")) / clock.step_minutes()))


## True inside a repaired fire tower, where the cab looks out over the forest.
func in_tower() -> bool:
	return is_indoors() and content.row("structures", location)["kind"] == "tower"


## Returns "" if surveying is possible now, or the text id saying why not.
func _survey_conditions_ok() -> String:
	if is_indoors() and not in_tower():
		return "msg_survey_weather"
	if not (backpack.has("map") and backpack.find_family("compass") >= 0 and backpack.has("pencil")):
		return "msg_survey_need_tools"
	if is_night():
		# Surveying 4: dawn and dusk are light enough.
		var dusk := Daylight.night_amount(tuning, clock.season_name(), clock.minute) < 1.0
		if not (dusk and skills.flag("survey_twilight")):
			return "msg_survey_dark"
	if not bool(weather_row().get("survey", false)):
		if not (current_weather() == "rain" and skills.flag("survey_rain")):
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
	var r := tuning.num("map.survey_radius")
	if in_tower():
		r = tuning.num("map.tower_radius")
	elif on_outlook():
		r = tuning.num("map.outlook_radius")
	return skills.value("survey_radius", r)


func _finish_survey() -> void:
	var outlook := on_outlook()
	var tower := in_tower()
	var at := door_front(location) if tower else outdoor_pos
	map.reveal_circle(at, survey_radius_here())
	var action := "high_survey" if tower or outlook else "survey"
	needs.spend(tuning.num("energy.survey") * skills.energy_for(action))
	skills.act(action)
	message.emit(content.text("msg_tower_survey" if tower else ("msg_outlook_survey" if outlook else "msg_survey_done")))
	survey_changed.emit(false, 1.0)
	_update_trace()
	jobs.event("survey", {"pos": at})
	survey_finished.emit()


func map_location(landmark_id: String) -> void:
	var row := content.row("landmarks", landmark_id)
	jobs.seen_landmarks[landmark_id] = true
	var radius := float(row.get("reveal_radius", tuning.num("map.location_radius")))
	map.reveal_circle(world.landmark_pos(landmark_id), radius)
	map.mark_landmark(landmark_id)
	jobs.mark_dirty()
	needs.spend(tuning.num("energy.map_location") * skills.energy_for("map_location"))
	skills.act("map_location")
	message.emit(content.text("msg_map_location", {"name": content.text(row["name"])}))
	pass_minutes(tuning.integer("map.location_minutes"))
	_update_trace()
	_check_collapse()


# --- foraging (phase 2b) ---------------------------------------------------------

func forage_ctx() -> Dictionary:
	return {"night": is_night(), "weather": current_weather()}


func magic_regrow_mult() -> float:
	return skills.value("magic_regrow", 1.0)


## True when a spot shows something to pick: ground forage grown and not yet
## picked, or a magical ingredient there under its own conditions. Buried
## things never show.
func forage_showing(t: Vector2i) -> bool:
	if is_indoors():
		return false
	var today := clock.absolute_day()
	var id := forage.magic_at(t)
	if id != "":
		if str(content.row("forage", id).get("source", "")) == "buried":
			return false
		return forage.has_magic(t, today, forage_ctx(), magic_regrow_mult())
	return forage.has_ground_now(t, today)


## The showing spot in reach: the one in front, else the nearest; (-1, -1) if none.
func forage_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var reach := tuning.num("forage.reach_tiles")
	var front := ranger_tile() + facing_vector()
	if forage_showing(front) and outdoor_pos.distance_to(Vector2(front) + Vector2(0.5, 0.5)) <= reach + 0.5:
		return front
	var best := Vector2i(-1, -1)
	var best_d := reach
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := ranger_tile() + Vector2i(dx, dy)
			if not forage.spots.has(t) and forage.magic_at(t) == "":
				continue
			var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
			if d <= best_d and forage_showing(t):
				best_d = d
				best = t
	return best


## Picks a spot: one of its item, or two on a double pick (Foraging 4 and the
## Gatherer). A magical ingredient is logged as a find the first time.
## The forage under the mouse (p, in tiles) when the ranger can reach it:
## a ground spot or a bush with fruit, within the gathering radius of the
## ranger. (-1, -1) when there is none, or it is too far (tracker #8).
func forage_at(p: Vector2) -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var t := Vector2i(floori(p.x), floori(p.y))
	if outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) > tuning.num("forage.pick_radius_tiles"):
		return Vector2i(-1, -1)
	if (forage.spots.has(t) or forage.magic_at(t) != "") and forage_showing(t):
		return t
	if not object_forage_ready(t).is_empty():
		return t
	return Vector2i(-1, -1)


## Picks the forage the mouse clicked on, by the same rules as X: a ground
## spot gathers everything close by, a bush gives its fruit.
func pick_at(t: Vector2i) -> Dictionary:
	if pending_confirm != "":
		return {"ok": false}
	if forage.spots.has(t) or forage.magic_at(t) != "":
		return pick_forage_around(t)
	return pick_object(t)


## Picks the spot in reach and every other spot showing within the tuned
## radius, nearest first, told in one line.
func pick_forage_around(first: Vector2i) -> Dictionary:
	var r := tuning.num("forage.pick_radius_tiles")
	var tiles: Array[Vector2i] = [first]
	var reach := ceili(r)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var t := ranger_tile() + Vector2i(dx, dy)
			if t == first or (not forage.spots.has(t) and forage.magic_at(t) == ""):
				continue
			if outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r and forage_showing(t):
				tiles.append(t)
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a == first or b == first:
			return a == first and b != first
		return outdoor_pos.distance_squared_to(Vector2(a)) < outdoor_pos.distance_squared_to(Vector2(b)))
	if tiles.size() == 1:
		return pick_forage(first)
	var got := {}
	var order: Array[String] = []
	var full := false
	for t in tiles:
		var res := pick_forage(t, true)
		if not bool(res["ok"]):
			full = res["reason"] == "full"
			if full:
				break
			continue
		if not got.has(res["item"]):
			order.append(res["item"])
		got[res["item"]] = int(got.get(res["item"], 0)) + int(res["count"])
	if order.is_empty():
		if full:
			message.emit(content.text("msg_backpack_full"))
		return {"ok": false, "reason": "full" if full else "nothing"}
	var parts: PackedStringArray = []
	for item in order:
		parts.append(content.text("msg_picked_part", {"n": got[item], "item": content.item_name(item).to_lower()}))
	message.emit(content.text("msg_picked_many_full" if full else "msg_picked_many", {"list": ", ".join(parts)}))
	return {"ok": true, "items": got}


func pick_forage(t: Vector2i, quiet: bool = false) -> Dictionary:
	if not forage_showing(t):
		return {"ok": false, "reason": "nothing"}
	var today := clock.absolute_day()
	var magic := forage.magic_at(t) != ""
	var id := forage.magic_at(t) if magic else str(forage.spots[t])
	var item: String = content.row("forage", id)["item"]
	var n := 1
	if not magic and _roll_double(t):
		n = 2
	_hold_ideas = true
	var left := backpack.add(item, n)
	_hold_ideas = false
	if left >= n:
		if not quiet:
			message.emit(content.text("msg_backpack_full"))
		return {"ok": false, "reason": "full"}
	if magic:
		forage.mark_picked(t, today)
	else:
		forage.take_ground(t, today)
	_after_pick(item, n - left, magic, quiet)
	return {"ok": true, "item": item, "count": n - left}


func _roll_double(t: Vector2i) -> bool:
	var chance := skills.value("double_pick_chance", 0.0)
	if chance <= 0.0:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, t, clock.absolute_day(), clock.minute, "double"])
	return rng.randf() < chance


func _after_pick(item: String, got: int, magic: bool, quiet: bool = false) -> void:
	var name := content.item_name(item).to_lower()
	if quiet:
		pass
	elif magic:
		message.emit(content.text("msg_picked_magic", {"item": name}))
	elif got > 1:
		message.emit(content.text("msg_picked_extra", {"item": name}))
	else:
		message.emit(content.text("msg_picked", {"item": name}))
	skills.act("pick_magic" if magic else "pick")
	if magic and not finds_found.has(item):
		finds_found[item] = true
		note_read.emit(content.text("find_" + item))
	_check_ideas()


## Days before a bush or pine gives again, after skills.
func object_refresh_days(r: Dictionary) -> int:
	var key := str(r["refresh"])
	var days := tuning.num(key)
	if key == "forage.bush_refruit_days":
		days = skills.value("bush_refruit_days", days)
	return maxi(1, roundi(days))


## What the bush or pine at t gives now, or {} if nothing (out of season,
## picked lately, chopped).
func object_forage_ready(t: Vector2i) -> Dictionary:
	var kind := world.object_at(t)
	if kind == "" or not forage.object_rows.has(kind) or chopped.has(t) or cleared.has(t):
		return {}
	var today := clock.absolute_day()
	var r := forage.object_row(kind, today)
	if r.is_empty() or not forage.object_ready(t, r, today, object_refresh_days(r)):
		return {}
	return r


## A bush or pine in reach with something to give: the one in front, else the
## nearest; (-1, -1) if none.
func object_forage_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var reach := tuning.num("forage.reach_tiles") + 0.5
	var front := ranger_tile() + facing_vector()
	if not object_forage_ready(front).is_empty():
		return front
	var best := Vector2i(-1, -1)
	var best_d := reach
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := ranger_tile() + Vector2i(dx, dy)
			var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
			if d <= best_d and not object_forage_ready(t).is_empty():
				best_d = d
				best = t
	return best


## Picks from a bush or pine: berries, rose hips or pine resin.
func pick_object(t: Vector2i) -> Dictionary:
	var r := object_forage_ready(t)
	if r.is_empty():
		return {"ok": false, "reason": "nothing"}
	var item: String = r["item"]
	var n := 2 if _roll_double(t) else 1
	_hold_ideas = true
	var left := backpack.add(item, n)
	_hold_ideas = false
	if left >= n:
		message.emit(content.text("msg_backpack_full"))
		return {"ok": false, "reason": "full"}
	forage.mark_object(t, r["id"], clock.absolute_day())
	if item == "pine_resin":
		message.emit(content.text("msg_resin_taken"))
		skills.act("pick")
		_check_ideas()
	else:
		_after_pick(item, n - left, false)
	return {"ok": true, "item": item, "count": n - left}


## Digs up the buried ingredient at t, for good.
func dig_up(t: Vector2i) -> Dictionary:
	var item: String = content.row("forage", forage.magic_at(t))["item"]
	_hold_ideas = true
	var left := backpack.add(item, 1)
	_hold_ideas = false
	if left > 0:
		message.emit(content.text("msg_backpack_full"))
		return {"ok": false, "reason": "full"}
	forage.mark_dug(t)
	needs.spend(tuning.num("trail.energy") * skills.energy_for("dig_tile"))
	message.emit(content.text("msg_dug_up", {"item": content.item_name(item).to_lower()}))
	skills.act("pick_magic")
	if not finds_found.has(item):
		finds_found[item] = true
		note_read.emit(content.text("find_" + item))
	_check_ideas()
	pass_minutes(tuning.integer("trail.minutes"))
	_check_collapse()
	return {"ok": true, "item": item, "dug_up": true}


## Tiles each dig lays, after skills.
func dig_tiles() -> int:
	return maxi(1, roundi(skills.value("dig_tiles", tuning.num("trail.tiles_per_action"))))


## Whether a place of an ingredient that is still there to be found lies
## within r tiles of the ranger (only: just that ingredient).
func _magic_within(r: float, only: String = "") -> bool:
	var today := clock.absolute_day()
	for t: Vector2i in forage.magic_used:
		if only != "" and forage.magic_at(t) != only:
			continue
		if outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r and forage.magic_waiting(t, today, magic_regrow_mult()):
			return true
	return false


## True while the ranger carries the compass near a buried lodestone sliver.
func compass_trembling() -> bool:
	if is_indoors() or backpack.find_family("compass") < 0:
		return false
	return _magic_within(tuning.num("magic.compass_tremble_tiles"), "lodestone_sliver")


## The compass trembling, and the Seeker's sense, each said once on coming near.
func _watch_magic() -> void:
	if is_indoors():
		return
	var tremble := compass_trembling()
	if tremble and not _trembling:
		message.emit(content.text("msg_compass_trembles"))
	_trembling = tremble
	var sense := skills.value("sense_magic_tiles", 0.0)
	var sensing := sense > 0.0 and _magic_within(sense)
	if sensing and not _sensing:
		message.emit(content.text("msg_sense_magic"))
	_sensing = sensing


## The tiles the glowcap lantern makes sparkle: finds not yet logged, inside
## its light.
func sparkle_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if is_indoors() or refit_of(selected_item()) != "glowcap":
		return out
	var r := lantern_radius()
	var finds: Dictionary = world.meta.get("finds", {})
	for id: String in finds:
		if finds_found.has(id):
			continue
		var t := Vector2i(int(finds[id][0]), int(finds[id][1]))
		if seasonal_hidden.has(t):
			continue
		if outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r:
			out.append(t)
	var today := clock.absolute_day()
	for t: Vector2i in forage.magic_used:
		if finds_found.has(forage.magic_at(t)):
			continue
		if outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5)) <= r and forage.magic_waiting(t, today, magic_regrow_mult()):
			out.append(t)
	return out


# --- recipes and ideas (phase 2b) -------------------------------------------------

## Cooking needs a lit stove indoors or a lit camp fire outdoors.
func can_cook_here() -> bool:
	if is_indoors():
		return structures.stove_minutes.has(location) and structures.stove_lit(location)
	return near_lit_fire()


func _reset_recipes() -> void:
	recipes_known = {}
	for r: Dictionary in content.rows("recipes"):
		if str(r["learned"]) == "start":
			recipes_known[r["id"]] = true


func learn_recipe(recipe_id: String) -> bool:
	if recipes_known.has(recipe_id) or not content.has("recipes", recipe_id):
		return false
	recipes_known[recipe_id] = true
	# Told in a pop-up: "you can make this now", what it is for and where.
	if not _loading:
		recipes_new.append(recipe_id)
	return true


## The pop-up for recipes just learned, and clears them; "" when none.
func take_new_recipes_text() -> String:
	if recipes_new.is_empty():
		return ""
	var lines := PackedStringArray([content.text("msg_recipes_new_title")])
	for id: String in recipes_new:
		var r := content.row("recipes", id)
		var use := content.text("recipe_use_" + id) if content.has("text", "recipe_use_" + id) else ""
		lines.append(content.text("msg_recipe_new_line", {"name": content.text(r["name"]), "where": content.text("ui_where_" + str(r["station"])), "use": use}))
	recipes_new.clear()
	return "\n".join(lines)


## Ideas: the first time an item is in the backpack, the ranger learns what it
## might make, told in one line.
func _check_ideas() -> void:
	for r: Dictionary in content.rows("ideas"):
		if ideas_had.has(r["id"]) or not r.has("item") or not backpack.has(r["item"]):
			continue
		ideas_had[r["id"]] = true
		for rid: String in r["recipes"]:
			learn_recipe(rid)
		message.emit(content.text(r["text"]))


# --- skills (phase 2b) -------------------------------------------------------------

func _skill_name(id: String) -> String:
	return content.text(content.row("skills", id)["name"])


## A level reached: its perk's recipes are learned now; the level-up is told
## on waking.
func _on_skill_level(id: String, l: int) -> void:
	pending_wake.append([id, l])
	var p := skills.perk_at(id, l)
	for rid: String in p.get("recipes", []):
		learn_recipe(rid)


## Offers the first specialty waiting to be chosen. False if none is waiting.
func offer_specialty() -> bool:
	wake_offer = false
	var waiting := skills.waiting()
	if waiting.is_empty():
		return false
	var id: String = waiting[0]
	skills.offered[id] = true
	var opts := []
	for sp: Dictionary in skills.offered_specialties(id):
		opts.append({"id": sp["id"], "label": content.text("ui_specialty_option", {"name": content.text(sp["name"]), "desc": content.text(sp["desc"])}), "enabled": true})
	choice_requested.emit("specialty:" + id, content.text("ui_specialty_title", {"skill": _skill_name(id), "level": skills.specialty_level()}), opts)
	return true


func choose_specialty(id: String, spec_id: String) -> bool:
	if not skills.choose(id, spec_id):
		return false
	message.emit(content.text("msg_specialty_chosen", {"skill": _skill_name(id), "name": content.text(content.row("specialties", spec_id)["name"])}))
	return true


## Puts skill changes that live outside the session in place.
func _apply_skills() -> void:
	structures.actions_override = roundi(skills.value("repair_actions", 0.0))
	structures.plank_mult = skills.value("repair_planks", 1.0)


## The Skills page: each skill's level and progress, what it has given so far,
## and its specialty.
func skill_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for r: Dictionary in content.rows("skills"):
		var id: String = r["id"]
		var l := skills.level(id)
		var p := skills.progress(id)
		if l >= skills.max_level():
			lines.append(content.text("ui_skill_line_max", {"name": _skill_name(id), "level": l}))
		else:
			lines.append(content.text("ui_skill_line", {"name": _skill_name(id), "level": l, "xp": int(p.x), "next": int(p.y)}))
		var got: PackedStringArray = []
		for pk: Dictionary in skills.perks_reached(id):
			got.append(content.text(pk["text"]))
		if not got.is_empty():
			lines.append(content.text("ui_skill_perks", {"list": "; ".join(got)}))
		var sp := str(skills.chosen[id])
		if sp != "":
			lines.append(content.text("ui_skill_specs", {"name": content.text(content.row("specialties", sp)["name"])}))
		elif skills.waiting().has(id):
			lines.append(content.text("ui_skill_choose"))
	lines.append("")
	lines.append(content.text("ui_known_recipes", {"n": recipes_known.size()}))
	return lines


func debug_set_skill(id: String, l: int) -> void:
	skills.set_level(id, l)


## Gives a specialty, raising the skill to its level if needed and replacing
## any earlier choice.
func debug_choose_specialty(spec_id: String) -> bool:
	if not content.has("specialties", spec_id):
		return false
	var id: String = content.row("specialties", spec_id)["skill"]
	if skills.level(id) < skills.specialty_level():
		skills.set_level(id, skills.specialty_level())
	skills.chosen[id] = ""
	return skills.choose(id, spec_id)


func debug_unlock_recipes() -> void:
	for r: Dictionary in content.rows("recipes"):
		recipes_known[r["id"]] = true
	for r: Dictionary in content.rows("ideas"):
		ideas_had[r["id"]] = true


func debug_regrow_forage() -> void:
	forage.regrow_all()


func debug_spawn_forage(t: Vector2i, forage_id: String) -> void:
	forage.add_spot(t, forage_id)


## How many places of each magical ingredient this save uses, and whether it
## has been found. Where they are is shown only with spoilers on.
func debug_magic_text(spoilers: bool) -> String:
	var lines := PackedStringArray()
	for id: String in forage.magic_places:
		var used := forage.magic_used.values().count(id)
		var line := "%s: %d places in this save, found: %s" % [id, used, "yes" if finds_found.has(id) else "no"]
		if spoilers:
			var at := []
			for t: Vector2i in forage.magic_used:
				if forage.magic_at(t) == id:
					at.append("(%d, %d)" % [t.x, t.y])
			line += "  " + ", ".join(at)
		lines.append(line)
	return "\n".join(lines)


## Stands the ranger beside the nearest place of an ingredient (spoiler debug).
func debug_go_to_magic(id: String) -> bool:
	var best := Vector2i(-1, -1)
	for t: Vector2i in forage.magic_used:
		if forage.magic_at(t) == id and (best.x < 0 or outdoor_pos.distance_to(Vector2(t)) < outdoor_pos.distance_to(Vector2(best))):
			best = t
	if best.x < 0:
		return false
	if is_indoors():
		location = ""
		location_changed.emit(location)
	var dirs: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]
	var faces: Array[int] = [FACING_UP, FACING_LEFT, FACING_RIGHT, FACING_DOWN]
	for i in dirs.size():
		if not world.is_solid(best + dirs[i]):
			outdoor_pos = Vector2(best + dirs[i]) + Vector2(0.5, 0.5)
			facing = faces[i]
			break
	_last_tile = Vector2i(-9999, -9999)
	_update_trace()
	return true


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


## Completes, or undoes, every repair step of a building.
func debug_repair_all(structure_id: String, complete: bool) -> void:
	for st: Dictionary in content.row("structures", structure_id)["repair_steps"]:
		if complete:
			structures.debug_complete_step(structure_id, st["id"])
		else:
			structures.debug_undo_step(structure_id, st["id"])


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


# --- the park (phase 3) ------------------------------------------------------------

## Whether a building's bed and chest are a renter's tonight.
func bed_taken(structure_id: String) -> bool:
	return structure_id == "test_cabin" and park.cabin_booked()


func _dist_to_rect(r: Rect2i) -> float:
	var rf := Rect2(Vector2(r.position), Vector2(r.size))
	var closest := Vector2(clampf(outdoor_pos.x, rf.position.x, rf.end.x), clampf(outdoor_pos.y, rf.position.y, rf.end.y))
	return closest.distance_to(outdoor_pos)


## The pad in reach that the ranger can see: a stake, a kit or a facility.
func pad_in_reach(reach: float) -> String:
	if is_indoors():
		return ""
	var best := ""
	var best_d := reach
	for r: Dictionary in park.pad_rows():
		var id: String = r["id"]
		if not park.pad_shown(id) and not park.built(id):
			continue
		var d := _dist_to_rect(park.pad_rect(id))
		if r["facility"] == "tower_lookout":
			d = outdoor_pos.distance_to(door_front(r["site"] if not content.has("sites", r["site"]) else content.row("sites", r["site"])["structure"]))
		if d <= best_d:
			best_d = d
			best = id
	return best


func thing_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var front := ranger_tile() + facing_vector()
	if park.things.has(front):
		return front
	var best := Vector2i(-1, -1)
	var best_d := tuning.num("world.interact_reach_tiles")
	for t: Vector2i in park.things:
		var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
		if d <= best_d:
			best_d = d
			best = t
	return best


func litter_in_reach() -> Vector2i:
	if is_indoors():
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := tuning.num("upkeep.litter_reach_tiles")
	var c := ranger_tile()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := c + Vector2i(dx, dy)
			if not park.litter.has(t):
				continue
			var d := outdoor_pos.distance_to(Vector2(t) + Vector2(0.5, 0.5))
			if d <= best_d:
				best_d = d
				best = t
	return best


func fire_ring_in_reach() -> Vector2i:
	var t := thing_in_reach()
	if t.x >= 0 and park.things[t]["id"] == "fire_ring":
		return t
	return Vector2i(-1, -1)


func rent_sign_tile() -> Vector2i:
	var r := content.row("sites", "old_cabin")
	return Vector2i(int(r["rent_sign"][0]), int(r["rent_sign"][1]))


## X near something of the park's. Returns true if it did something.
func _park_interact() -> bool:
	var reach := tuning.num("world.interact_reach_tiles")
	# A lost party first: they are what matters most.
	var lp := park.lost_party()
	if not lp.is_empty() and outdoor_pos.distance_to(lp["pos"]) <= tuning.num("visitors.lost_find_reach_tiles"):
		jobs.event("talk", {"party": "lost"})
		var tip := park.find_lost()
		skills.act("find_lost_party")
		message.emit(content.text("msg_found_party", {"n": tip}))
		return true
	var bi := park.badger_near(outdoor_pos, tuning.num("badgers.reach_tiles"))
	if bi >= 0:
		shoo_badger(bi)
		return true
	# The scouts' troop leader, for their litter badge.
	if jobs.is_active("scouts_badge"):
		for p: Dictionary in park.parties:
			if str(p["kind"]) == "scout_troop" and outdoor_pos.distance_to(p["pos"]) <= tuning.num("visitors.lost_find_reach_tiles"):
				jobs.event("talk", {"party": "scout_troop"})
				message.emit(content.text("jt_talk_scouts"))
				return true
	var lt := litter_in_reach()
	if lt.x >= 0:
		pick_litter(lt)
		return true
	var th := thing_in_reach()
	if th.x >= 0:
		var id: String = park.things[th]["id"]
		if id == "trash_can":
			empty_can(th)
		elif id == "fire_ring":
			if int(park.things[th]["lit"]) <= 0:
				light_fire_ring(th)
		elif id == "bench":
			pass
		return true
	if structures.is_open("test_cabin") and outdoor_pos.distance_to(Vector2(rent_sign_tile()) + Vector2(0.5, 0.5)) <= reach:
		pending_confirm = "rent_sign"
		confirm_requested.emit("rent_sign", content.text("msg_rent_sign", {"mode": content.text("rent_for_rent" if park.rent_mode == "rent" else "rent_ranger_only")}))
		return true
	var pad := pad_in_reach(reach)
	if pad != "":
		var fac: String = park.pad_row(pad)["facility"]
		var name := content.text(park.fac_row(pad)["name"]).to_lower()
		match park.pad_state(pad):
			"":
				message.emit(content.text("msg_pad_here", {"name": name}))
			"ordered":
				message.emit(content.text("msg_pad_ordered", {"name": name}))
			"kit", "building":
				message.emit(content.text("msg_build_progress", {"name": name, "done": int(park.pads[pad]["done"]), "total": int(park.fac_row(pad)["actions"])}))
			"built":
				if fac == "kiosk":
					open_gift_shelf()
				elif fac == "suggestion_box":
					read_box()
				elif fac == "bathroom":
					clean_bathroom(pad)
				else:
					message.emit(content.text(park.fac_row(pad)["name"]))
		return true
	return false


func open_gift_shelf() -> void:
	if park.gift_shelf.size() > 0 and not ideas_had.has("gift_shelf"):
		var empty := true
		for i in park.gift_shelf.size():
			if park.gift_shelf.item_at(i) != "":
				empty = false
		if empty:
			ideas_had["gift_shelf"] = true
			for rid: String in content.row("ideas", "gift_shelf")["recipes"]:
				learn_recipe(rid)
			message.emit(content.text("msg_gift_ideas"))
	storage_opened.emit(content.text("ui_gift_shelf"), park.gift_shelf)
	message.emit(content.text("msg_gift_shelf_how"))


func read_box() -> String:
	var got := park.read_cards()
	if got.is_empty():
		message.emit(content.text("msg_box_empty") + " " + content.text("msg_box_how"))
		return ""
	var texts: PackedStringArray = []
	for c: Dictionary in got:
		texts.append(str(c["text"]))
	var text := "\n\n".join(texts)
	box_offer = got.any(func(c: Dictionary) -> bool: return bool(c["asks"]) and not jobs.card_template(c).is_empty())
	note_read.emit(text)
	return text


## After reading the box: offers to pin cards that ask for something.
func offer_pins() -> bool:
	box_offer = false
	var opts := []
	var offered := 0
	for i in range(park.cards.size() - 1, -1, -1):
		var c: Dictionary = park.cards[i]
		if bool(c["asks"]) and not bool(c.get("taken", false)) and bool(c["read"]) and not jobs.card_template(c).is_empty() and offered < tuning.integer("jobs.cards_offer_most"):
			opts.append({"id": str(i), "label": content.text("ui_box_pin", {"text": c["text"]})})
			offered += 1
	if opts.is_empty():
		return false
	pending_confirm = "pin_card"
	choice_requested.emit("pin_card", content.text("ui_box_pin_title"), opts)
	return true


func clean_bathroom(pad: String) -> void:
	var bi := -1
	for i in park.badgers.size():
		if str(park.badgers[i].get("nap", "")) == pad and int(park.badgers[i]["away_until"]) <= clock.absolute_day():
			bi = i
	if bi >= 0:
		message.emit(content.text("msg_bathroom_badger"))
		shoo_badger(bi)
		return
	park.clean_bathroom(pad)
	jobs.event("clean", {"pad": pad})
	needs.spend(tuning.num("upkeep.clean_energy"))
	message.emit(content.text("msg_bathroom_cleaned"))
	pass_minutes(tuning.integer("upkeep.clean_minutes"))
	_check_collapse()


func empty_can(t: Vector2i) -> void:
	if int(park.things[t]["trash"]) <= 0 and not bool(park.things[t]["tipped"]):
		message.emit(content.text("msg_can_empty"))
		return
	park.empty_can(t)
	jobs.event("empty", {"place": park.place_of(Vector2(t))})
	needs.spend(tuning.num("upkeep.empty_energy"))
	message.emit(content.text("msg_can_emptied"))
	pass_minutes(tuning.integer("upkeep.empty_minutes"))
	_check_collapse()


func pick_litter(t: Vector2i) -> void:
	var found := park.pick_litter(t)
	jobs.event("pick_up", {"pos": Vector2(t) + Vector2(0.5, 0.5)})
	needs.spend(tuning.num("upkeep.litter_energy"))
	if found != "":
		message.emit(content.text("msg_belonging", {"thing": found}))
	else:
		message.emit(content.text("msg_litter_picked"))
	_check_collapse()


func shoo_badger(i: int) -> void:
	var b: Dictionary = park.badgers[i]
	if not park.met_badger:
		park.met_badger = true
		park.add_note(content.text("note_first_badger", {"place": park.place_name(b["place"])}))
		message.emit(content.text("msg_badger_first"))
	park.shoo(i)
	jobs.event("shoo", {"place": str(b["place"])})
	needs.spend(tuning.num("badgers.shoo_energy"))
	if park.met_badger:
		message.emit(content.text("msg_badger_shooed"))
	pass_minutes(tuning.integer("badgers.shoo_minutes"))
	_check_collapse()


func light_fire_ring(t: Vector2i) -> bool:
	if not backpack.remove("firewood", 1):
		message.emit(content.text("msg_fire_ring_cold"))
		return false
	park.things[t]["lit"] = int(park.things[t]["lit"]) + fire_minutes_per_firewood()
	park.changed.emit()
	message.emit(content.text("msg_fire_ring_lit"))
	return true


## Puts down the held bench, trash can, picnic table or fire ring in front.
func place_park_thing() -> bool:
	if is_indoors():
		return false
	var item := selected_item()
	var id := park.thing_for_item(item)
	var t := ranger_tile() + facing_vector()
	if not camp.is_empty() and (camp["bed"] == t or camp["fire"] == t):
		message.emit(content.text("msg_place_bad_spot"))
		return false
	var why := park.place_problem(t)
	if why != "":
		message.emit(content.text(why))
		return false
	if not backpack.remove(item, 1):
		return false
	park.put_thing(t, id)
	land_changed.emit(t)
	message.emit(content.text("msg_thing_placed", {"name": content.item_name(item).to_lower()}))
	pass_minutes(tuning.integer("signs.put_up_minutes"))
	return true


func pick_up_park_thing(t: Vector2i) -> bool:
	var id: String = park.things[t]["id"]
	var item: String = content.row("placeables", id)["item"]
	if backpack.room_for(item) < 1:
		message.emit(content.text("msg_backpack_full"))
		return false
	park.pick_up_thing(t)
	backpack.add(item, 1)
	land_changed.emit(t)
	message.emit(content.text("msg_thing_picked_up", {"name": content.item_name(item).to_lower()}))
	return true


## The hammer at a pad: build its kit, or offer to take the facility down.
func hammer_pad(pad: String) -> Dictionary:
	var name := content.text(park.fac_row(pad)["name"]).to_lower()
	var st := park.pad_state(pad)
	if st == "built":
		if bool(park.pad_row(pad).get("built", false)):
			return {"ok": false, "reason": "fixed"}
		pending_confirm = "take_down:" + pad
		confirm_requested.emit(pending_confirm, content.text("msg_take_down_confirm", {"name": name, "n": park.refund_for(pad)}))
		return {"ok": true, "reason": "confirm"}
	if st != "kit" and st != "building":
		message.emit(content.text("msg_pad_here", {"name": name}))
		return {"ok": false, "reason": "no_kit"}
	var res := park.build_action(pad)
	needs.spend(tuning.num("facilities.energy_per_action") * skills.energy_for("repair"))
	skills.act("repair")
	if res["built"]:
		message.emit(content.text("msg_built", {"name": name}))
	else:
		message.emit(content.text("msg_build_progress", {"name": name, "done": res["done"], "total": res["total"]}))
	pass_minutes(tuning.integer("facilities.minutes_per_action"))
	_check_collapse()
	return res


func _take_down_facility(pad: String) -> void:
	var name := content.text(park.fac_row(pad)["name"]).to_lower()
	var n := park.take_down(pad)
	message.emit(content.text("msg_taken_down_fac", {"name": name, "n": n}))


func open_catalog() -> void:
	if not jobs.unlocks.has("catalog"):
		message.emit(content.text("jt_catalog_locked"))
		return
	list_requested.emit("catalog", content.text("ui_catalog", {"wallet": park.money.wallet}), park.catalog_options())


func staff_options() -> Array:
	var out := []
	for st: Dictionary in park.staff:
		var pr := content.row("staff_people", st["person"])
		var role := content.text(content.row("staff_roles", st["role"])["name"])
		out.append({"id": "go:" + str(st["person"]), "label": content.text("ui_staff_hired", {"name": content.text(pr["name"]), "role": role, "status": content.text("ui_staff_off" if bool(st["off"]) else "ui_staff_working")})})
		if st["role"] == "custodian":
			out.append({"id": "assign:" + str(st["person"]), "label": content.text("ui_staff_assign", {"name": content.text(pr["name"]), "n": (st["assigned"] as Array).size(), "most": int(content.row("staff_roles", "custodian")["jobs"])})})
	for pid: String in park.board:
		var pr := content.row("staff_people", pid)
		var role := content.row("staff_roles", pr["suits"])
		out.append({"id": "hire:" + pid, "label": content.text("ui_staff_hire", {"name": content.text(pr["name"]), "role": content.text(role["name"]).to_lower(), "wage": int(role["wage"]), "line": content.text(pr["line"])})})
	if out.is_empty():
		out.append({"id": "", "label": content.text("ui_staff_none"), "enabled": false})
	return out


func open_staff_board() -> void:
	list_requested.emit("staff", content.text("ui_staff_board"), staff_options())


func assign_options(person: String) -> Array:
	var st := {}
	for o: Dictionary in park.staff:
		if o["person"] == person:
			st = o
	var out := []
	for j: Dictionary in park.jobs_for_custodian():
		var on := (st.get("assigned", []) as Array).has(j["key"])
		out.append({"id": str(j["key"]), "label": content.text("ui_assign_line", {"mark": content.text("ui_assign_on" if on else "ui_assign_off"), "name": j["label"]})})
	return out


## What a stay-open list shows now, after a pick.
func list_options(kind: String) -> Array:
	if kind == "catalog":
		return park.catalog_options()
	if kind == "staff":
		return staff_options()
	if kind.begins_with("assign:"):
		return assign_options(kind.substr(7))
	return []


func list_title(kind: String) -> String:
	if kind == "catalog":
		return content.text("ui_catalog", {"wallet": park.money.wallet})
	if kind == "staff":
		return content.text("ui_staff_board")
	if kind.begins_with("assign:"):
		var pr := content.row("staff_people", kind.substr(7))
		return content.text("ui_assign_title", {"name": content.text(pr["name"]), "most": int(content.row("staff_roles", "custodian")["jobs"])})
	return ""


## A pick from a stay-open list. Returns a new list kind to show, or "".
func answer_list(kind: String, option_id: String) -> String:
	if option_id == "":
		return ""
	if kind == "catalog":
		var why := park.order(option_id)
		if why != "":
			message.emit(content.text(why, {"name": ""}))
		else:
			var r := content.row("catalog", option_id.split("@")[0])
			message.emit(content.text("msg_ordered", {"name": content.text(r["name"])}))
		return ""
	if kind == "staff":
		if option_id.begins_with("hire:"):
			var pid := option_id.substr(5)
			if park.hire(pid):
				message.emit(content.text("msg_staff_hired", {"name": content.text(content.row("staff_people", pid)["name"])}))
		elif option_id.begins_with("go:"):
			var bye := park.let_go(option_id.substr(3))
			if bye != "":
				note_read.emit(bye)
		elif option_id.begins_with("assign:"):
			return option_id
		return ""
	if kind.begins_with("assign:"):
		park.toggle_assign(kind.substr(7), option_id)
	return ""


## The rough circle on the map around a lost party, or {}.
func lost_hint() -> Dictionary:
	if park.lost.is_empty():
		return {}
	return {"center": park.lost["center"], "radius": tuning.num("visitors.lost_rumor_radius"), "text": content.text("msg_lost_hint")}


# --- park debug tools (also used by the tests) -------------------------------------

func debug_money(n: int) -> void:
	if n >= 0:
		park.money.earn(clock.absolute_day(), "budget", n)
	else:
		park.money.spend(clock.absolute_day(), "catalog", mini(-n, park.money.wallet))


## Skips to the morning of the next seventh day.
func debug_skip_to_week_end() -> void:
	clock.start_next_day()
	while park.week_day() != tuning.integer("money.week_days"):
		clock.start_next_day()


func debug_spawn_party(kind: String) -> Dictionary:
	var r := content.row("visitor_types", kind)
	var size := int(r["party"][0])
	var nights := int(r["nights"][1])
	var home := ""
	if nights > 0:
		var homes := park.camp_homes().keys()
		if homes.is_empty():
			return {}
		home = homes[0]
	return park.spawn(kind, size, home, nights)


func debug_set_clean(pad: String, v: float) -> void:
	if park.pads.has(pad):
		park.pads[pad]["clean"] = v
		park.changed.emit()


func debug_set_can(t: Vector2i, n: int) -> void:
	if park.things.has(t):
		park.things[t]["trash"] = n
		park.changed.emit()


func debug_send_badger(place: String) -> bool:
	return park.send_badger(place)


func debug_lose_party() -> bool:
	for p: Dictionary in park.parties:
		if p["state"] == "walk":
			var t := park._cur_tile(p)
			if t.x >= 0 and park.lose(p, t):
				return true
	return false


## Builds a facility at a pad at once, kit and all.
func debug_build(pad: String) -> void:
	park.pads[pad] = {"state": "kit", "done": 0, "clean": 100.0}
	for i in int(park.fac_row(pad)["actions"]):
		park.build_action(pad)


## Runs the park for a number of days with the ranger doing nothing, and
## reports what happened.
func debug_run_unattended(days: int) -> String:
	var start_wallet := park.money.wallet
	var visitors := 0
	var low := park.money.wallet
	for i in days:
		park.advance_to(float(tuning.integer("time.day_end_minute")))
		visitors += int(park.week["visitors"]) if park.week_day() == tuning.integer("money.week_days") - 0 else 0
		clock.start_next_day()
		low = mini(low, park.money.wallet)
	park.morning_lines = []
	return "Ran %d days: wallet %dg to %dg (lowest %dg), %d parties now in the park, %d badgers, %d litter, %d cards waiting, %d letters." % [days, start_wallet, park.money.wallet, low, park.parties.size(), park.badgers.size(), park.litter.size(), park.unread_cards().size(), park.letters.size()]
