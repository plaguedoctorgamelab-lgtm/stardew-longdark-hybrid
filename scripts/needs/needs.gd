class_name Needs
extends RefCounted
## Energy and warmth. Changed once per ten-minute step by the conditions the
## ranger is in, and by actions, food, fire and sleep.

signal changed(energy: float, warmth: float)
signal ran_out(which: String)

var tuning: Tuning
var energy: float = 270.0
var warmth: float = 100.0
var energy_drain_on: bool = true
var warmth_drain_on: bool = true


func _init(t: Tuning) -> void:
	tuning = t
	energy = max_energy()
	warmth = max_warmth()


func max_energy() -> float:
	return tuning.num("energy.max")


func max_warmth() -> float:
	return tuning.num("warmth.max")


func is_exhausted() -> bool:
	return energy < tuning.num("energy.exhausted_below")


func is_chilled() -> bool:
	return warmth < tuning.num("warmth.chilled_below")


## Warmth change for one step. ctx keys: indoors, stove_lit, weather (row),
## season (name), night (bool).
func warmth_delta(ctx: Dictionary) -> float:
	if ctx.get("indoors", false):
		return tuning.num("warmth.indoors_stove") if ctx.get("stove_lit", false) else tuning.num("warmth.indoors")
	var w: Dictionary = ctx["weather"]
	var d := float(w["warmth"])
	d += tuning.num("warmth.season." + str(ctx["season"]))
	if ctx.get("night", false):
		d += tuning.num("warmth.night")
	d += tuning.num("warmth.clothing")
	if ctx.get("campfire", false):
		d += tuning.num("camp.fire_warmth")
	return d


## Energy spent walking during one step. ctx keys: indoors, walked, rough,
## weather (row).
func walk_cost(ctx: Dictionary) -> float:
	if ctx.get("indoors", false) or not ctx.get("walked", false):
		return 0.0
	var cost := tuning.num("energy.walk_per_step")
	if ctx.get("rough", false):
		cost *= tuning.num("energy.rough_ground_multiplier")
	var w: Dictionary = ctx["weather"]
	if w.get("harsh", false):
		cost *= tuning.num("energy.bad_weather_multiplier")
	if is_chilled():
		cost *= tuning.num("warmth.chilled_energy_multiplier")
	return cost


func step(ctx: Dictionary) -> void:
	if warmth_drain_on or warmth_delta(ctx) > 0.0:
		add_warmth(warmth_delta(ctx))
	if energy_drain_on:
		add_energy(-walk_cost(ctx))


func add_energy(amount: float) -> void:
	if amount < 0.0 and not energy_drain_on:
		return
	var before := energy
	energy = clampf(energy + amount, 0.0, max_energy())
	changed.emit(energy, warmth)
	if energy <= 0.0 and before > 0.0:
		ran_out.emit("energy")


func add_warmth(amount: float) -> void:
	if amount < 0.0 and not warmth_drain_on:
		return
	var before := warmth
	warmth = clampf(warmth + amount, 0.0, max_warmth())
	changed.emit(energy, warmth)
	if warmth <= 0.0 and before > 0.0:
		ran_out.emit("warmth")


func spend(amount: float) -> void:
	add_energy(-amount)


func eat(food: Dictionary) -> void:
	add_energy(float(food.get("energy", 0)))
	add_warmth(float(food.get("warmth", 0)))


func refill() -> void:
	energy = max_energy()
	warmth = max_warmth()
	changed.emit(energy, warmth)


func set_values(e: float, w: float) -> void:
	energy = clampf(e, 0.0, max_energy())
	warmth = clampf(w, 0.0, max_warmth())
	changed.emit(energy, warmth)


func to_dict() -> Dictionary:
	return {"energy": energy, "warmth": warmth}


func from_dict(d: Dictionary) -> void:
	energy = float(d["energy"])
	warmth = float(d["warmth"])
