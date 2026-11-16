class_name Skills
extends RefCounted
## Four skills that rise by doing, in Stardew's manner. Each action named in a
## skill's xp gives it experience; levels come at the totals in tuning. Every
## level cuts the energy of that skill's actions; some levels also give a perk
## (effects and recipes, from the skills table); at the specialty level the
## ranger picks one of two specialties (the specialties table).
##
## The game asks for a changed value by key: value(key, base) applies every
## effect the ranger has earned to the game's own base value.

signal levelled(skill_id: String, level: int)
signal specs_changed

var content: ContentDB
var tuning: Tuning
var xp: Dictionary = {}       # skill id -> experience
var chosen: Dictionary = {}   # skill id -> specialty id, or "" if none yet
var offered: Dictionary = {}  # skill id -> true once the specialty has been offered


func _init(c: ContentDB, t: Tuning) -> void:
	content = c
	tuning = t
	reset()


func reset() -> void:
	xp = {}
	chosen = {}
	offered = {}
	for id: String in content.ids("skills"):
		xp[id] = 0
		chosen[id] = ""
	specs_changed.emit()


func thresholds() -> Array:
	return tuning.value("skills.xp_levels")


func max_level() -> int:
	return thresholds().size()


## Total experience needed to reach level n (0 for level 0).
func xp_for_level(n: int) -> int:
	if n <= 0:
		return 0
	return int(thresholds()[mini(n, max_level()) - 1])


func level(id: String) -> int:
	var l := 0
	var have := int(xp.get(id, 0))
	for need: Variant in thresholds():
		if have >= int(need):
			l += 1
	return l


## The skill that earns experience from an action, or "".
func skill_for(action: String) -> String:
	for r: Dictionary in content.rows("skills"):
		if (r["xp"] as Dictionary).has(action):
			return r["id"]
	return ""


## Gives the experience for an action, times count.
func act(action: String, count: int = 1) -> void:
	for r: Dictionary in content.rows("skills"):
		var gives: Dictionary = r["xp"]
		if gives.has(action):
			add_xp(r["id"], int(gives[action]) * count)


func add_xp(id: String, amount: int) -> void:
	var before := level(id)
	xp[id] = int(xp.get(id, 0)) + amount
	var after := level(id)
	for l in range(before + 1, after + 1):
		levelled.emit(id, l)
	if after != before:
		specs_changed.emit()


## How much of an action's energy is left after this skill's levels.
func energy_mult(id: String) -> float:
	if id == "":
		return 1.0
	return maxf(0.0, 1.0 - tuning.num("skills.energy_saved_per_level") * level(id))


func energy_for(action: String) -> float:
	return energy_mult(skill_for(action))


func perks(id: String) -> Array:
	return content.row("skills", id)["perks"]


## The perk rows reached so far in a skill.
func perks_reached(id: String) -> Array:
	var l := level(id)
	return perks(id).filter(func(p: Dictionary) -> bool: return int(p["level"]) <= l)


func perk_at(id: String, l: int) -> Dictionary:
	for p: Dictionary in perks(id):
		if int(p["level"]) == l:
			return p
	return {}


## Every effect earned: perks first, then specialties.
func _effects() -> Array:
	var out := []
	for r: Dictionary in content.rows("skills"):
		for p: Dictionary in perks_reached(r["id"]):
			out.append_array(p.get("effects", []))
	for r: Dictionary in content.rows("skills"):
		var sp := str(chosen.get(r["id"], ""))
		if sp != "":
			out.append_array(content.row("specialties", sp)["effects"])
	return out


## The game's base value for key with every earned effect applied: sets
## (the last one wins), then adds, then multiplies.
func value(key: String, base: float) -> float:
	var effects := _effects().filter(func(e: Dictionary) -> bool: return e["key"] == key)
	var v := base
	for e: Dictionary in effects:
		if e.has("set"):
			v = float(e["set"])
	for e: Dictionary in effects:
		if e.has("add"):
			v += float(e["add"])
	for e: Dictionary in effects:
		if e.has("mult"):
			v *= float(e["mult"])
	return v


func flag(key: String) -> bool:
	return value(key, 0.0) > 0.0


# --- specialties ------------------------------------------------------------------

func specialty_level() -> int:
	return tuning.integer("skills.specialty_level")


func offered_specialties(id: String) -> Array:
	return content.rows("specialties").filter(func(s: Dictionary) -> bool: return s["skill"] == id)


## Skills at the specialty level with no specialty chosen yet.
func waiting() -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in content.rows("skills"):
		var id: String = r["id"]
		if level(id) >= specialty_level() and str(chosen.get(id, "")) == "":
			out.append(id)
	return out


## Chooses a specialty. The choice is permanent: false if one is chosen.
func choose(id: String, spec_id: String) -> bool:
	if level(id) < specialty_level() or str(chosen.get(id, "")) != "":
		return false
	if not offered_specialties(id).any(func(s: Dictionary) -> bool: return s["id"] == spec_id):
		return false
	chosen[id] = spec_id
	specs_changed.emit()
	return true


## Sets a skill to the start of a level (debug and tests).
func set_level(id: String, l: int) -> void:
	var before := level(id)
	xp[id] = xp_for_level(clampi(l, 0, max_level()))
	if level(id) < specialty_level():
		chosen[id] = ""
		offered.erase(id)
	for n in range(before + 1, level(id) + 1):
		levelled.emit(id, n)
	specs_changed.emit()


## Experience so far in this level and the size of the level: (have, need).
func progress(id: String) -> Vector2:
	var l := level(id)
	if l >= max_level():
		return Vector2(0, 0)
	var start := xp_for_level(l)
	return Vector2(int(xp[id]) - start, xp_for_level(l + 1) - start)


func to_dict() -> Dictionary:
	return {"xp": xp.duplicate(), "chosen": chosen.duplicate(), "offered": offered.keys()}


func from_dict(d: Dictionary) -> void:
	reset()
	var x: Dictionary = d.get("xp", {})
	for id: String in x:
		if xp.has(id):
			xp[id] = int(x[id])
	var c: Variant = d.get("chosen", {})
	for id: String in xp:
		var v: Variant = (c as Dictionary).get(id, "") if typeof(c) == TYPE_DICTIONARY else ""
		var s := str(v) if typeof(v) == TYPE_STRING else ""
		chosen[id] = s if s != "" and content.has("specialties", s) else ""
	for id: Variant in d.get("offered", []):
		offered[str(id)] = true
	specs_changed.emit()
