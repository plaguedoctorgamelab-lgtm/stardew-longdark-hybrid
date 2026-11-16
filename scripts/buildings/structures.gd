class_name Structures
extends RefCounted
## Buildings: repair progress, storage chests, the station's supply shelf and
## the cabin's wood stove.

signal changed(structure_id: String)
signal opened(structure_id: String)

var content: ContentDB
var tuning: Tuning
var progress: Dictionary = {}   # structure id -> {step id -> actions done}
var chests: Dictionary = {}     # structure id -> Inventory
var shelves: Dictionary = {}    # structure id -> Inventory
var stove_minutes: Dictionary = {}   # structure id -> minutes of burn left


func _init(c: ContentDB, t: Tuning) -> void:
	content = c
	tuning = t
	for r: Dictionary in content.rows("structures"):
		var id: String = r["id"]
		progress[id] = {}
		for st: Dictionary in r["repair_steps"]:
			progress[id][st["id"]] = 0
		chests[id] = Inventory.new(content, tuning.integer("storage.chest_slots"))
		if not (r.get("shelf_stock", []) as Array).is_empty():
			shelves[id] = Inventory.new(content, (r["shelf_stock"] as Array).size())
		stove_minutes[id] = 0


func row(id: String) -> Dictionary:
	return content.row("structures", id)


func ids() -> Array[String]:
	return content.ids("structures")


## Skills can change repairs: the actions each step takes (0 keeps the tuned
## number) and the share of planks a step uses.
var actions_override: int = 0
var plank_mult: float = 1.0


func actions_per_step() -> int:
	if actions_override > 0:
		return actions_override
	return maxi(1, tuning.integer("repair.actions_per_step"))


## What a repair step uses, after skills.
func step_materials(id: String, step: String) -> Dictionary:
	var m: Dictionary = (step_row(id, step)["materials"] as Dictionary).duplicate()
	if m.has("planks") and plank_mult != 1.0:
		m["planks"] = maxi(1, roundi(int(m["planks"]) * plank_mult))
	return m


func step_done(id: String, step: String) -> bool:
	return int(progress[id][step]) >= actions_per_step()


func steps_remaining(id: String) -> Array[String]:
	var out: Array[String] = []
	for st: Dictionary in row(id)["repair_steps"]:
		if not step_done(id, st["id"]):
			out.append(st["id"])
	return out


func is_open(id: String) -> bool:
	if row(id).get("starts_repaired", false):
		return true
	return steps_remaining(id).is_empty()


func step_row(id: String, step: String) -> Dictionary:
	for st: Dictionary in row(id)["repair_steps"]:
		if st["id"] == step:
			return st
	return {}


## Picks the step a hammer action would work on: a step already started, or
## else the first unfinished step whose materials are in the backpack.
func choose_step(id: String, backpack: Inventory) -> String:
	for st: Dictionary in row(id)["repair_steps"]:
		var n := int(progress[id][st["id"]])
		if n > 0 and n < actions_per_step():
			return st["id"]
	for st: Dictionary in row(id)["repair_steps"]:
		if not step_done(id, st["id"]) and backpack.can_pay(step_materials(id, st["id"])):
			return st["id"]
	return ""


## One hammer action. Materials are used when a step is begun. Returns a
## result: {ok, reason, step, done, total, step_finished, opened}.
func repair_action(id: String, backpack: Inventory) -> Dictionary:
	var tool: String = row(id).get("repair_tool", "hammer")
	if not backpack.has(tool):
		return {"ok": false, "reason": "no_tool"}
	var step := choose_step(id, backpack)
	if step == "":
		return {"ok": false, "reason": "no_materials"}
	var was_open := is_open(id)
	if int(progress[id][step]) == 0:
		backpack.pay(step_materials(id, step))
	progress[id][step] = int(progress[id][step]) + 1
	var finished := step_done(id, step)
	var now_open := is_open(id)
	changed.emit(id)
	if now_open and not was_open:
		opened.emit(id)
	return {"ok": true, "step": step, "done": progress[id][step], "total": actions_per_step(), "step_finished": finished, "opened": now_open and not was_open}


func debug_complete_step(id: String, step: String) -> void:
	var was_open := is_open(id)
	progress[id][step] = actions_per_step()
	changed.emit(id)
	if is_open(id) and not was_open:
		opened.emit(id)


func debug_undo_step(id: String, step: String) -> void:
	progress[id][step] = 0
	changed.emit(id)


func restock_shelves() -> void:
	for id: String in shelves:
		var shelf: Inventory = shelves[id]
		shelf.clear()
		for s: Dictionary in row(id)["shelf_stock"]:
			shelf.add(s["item"], int(s["count"]))


## Fills chests with the supplies found in them, drawn from the save's seed.
func place_found_supplies(seed_value: int) -> void:
	for id in ids():
		(chests[id] as Inventory).clear()
		for s: Dictionary in row(id).get("starting_chest", []):
			(chests[id] as Inventory).add(s["item"], int(s["count"]))
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, id, "supplies"])
		for s: Dictionary in row(id).get("found_supplies", []):
			var n := rng.randi_range(int(s["min"]), int(s["max"]))
			if n > 0:
				(chests[id] as Inventory).add(s["item"], n)


func stove_lit(id: String) -> bool:
	return int(stove_minutes.get(id, 0)) > 0


## Puts one firewood from the backpack in the stove.
func feed_stove(id: String, backpack: Inventory, burn_mult: float = 1.0) -> bool:
	if not backpack.remove("firewood", 1):
		return false
	stove_minutes[id] = int(stove_minutes[id]) + roundi(tuning.integer("warmth.stove_minutes_per_firewood") * burn_mult)
	changed.emit(id)
	return true


func burn(minutes: int) -> void:
	for id: String in stove_minutes:
		if int(stove_minutes[id]) > 0:
			stove_minutes[id] = maxi(0, int(stove_minutes[id]) - minutes)
			if int(stove_minutes[id]) == 0:
				changed.emit(id)


func to_dict() -> Dictionary:
	var c := {}
	for id: String in chests:
		c[id] = (chests[id] as Inventory).to_array()
	var s := {}
	for id: String in shelves:
		s[id] = (shelves[id] as Inventory).to_array()
	return {"progress": progress.duplicate(true), "chests": c, "shelves": s, "stoves": stove_minutes.duplicate()}


func from_dict(d: Dictionary) -> void:
	for id: String in d["progress"]:
		if progress.has(id):
			for step: String in d["progress"][id]:
				progress[id][step] = int(d["progress"][id][step])
	for id: String in d["chests"]:
		if chests.has(id):
			(chests[id] as Inventory).from_array(d["chests"][id])
	for id: String in d["shelves"]:
		if shelves.has(id):
			(shelves[id] as Inventory).from_array(d["shelves"][id])
	for id: String in d["stoves"]:
		stove_minutes[id] = int(d["stoves"][id])
