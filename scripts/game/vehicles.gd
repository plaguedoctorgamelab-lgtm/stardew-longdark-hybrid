class_name Vehicles
extends RefCounted
## Phase 6a (Phase 6 Spec, sections 1 to 3): the far bank's ways and
## seasons.
##
## - The canoe, built at Dusk River Landing. It goes on any open water from
##   spring to autumn: fast downstream on the river, slow upstream, and not
##   upstream at all in the spring melt.
## - The cart, found broken at the Old Logging Camp and mended. It drives
##   only on cart trail: the old logging road, and any trail the ranger
##   widens with the shovel. Three times walking speed.
## - Troll Badger Bridge's toll box: a snack a day for the badgers below.
## - Seasons change the land: the melt floods the fords for the first week
##   of spring (from the second year: the first is the ranger's first week); summer's low water opens a ford on the river; Skull Lake
##   freezes from the 7th of winter and the river's ice crossing from the
##   14th; the high trails are snowed in all winter.

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var riding: String = ""              # "", "canoe" or "cart"
var canoe_pos: Vector2 = Vector2.INF # where the canoe waits, on the water
var cart_pos: Vector2 = Vector2.INF  # where the cart is parked
var widened: Dictionary = {}         # tiles the ranger widened to cart trail
var toll_day: int = -1               # the day the toll was last paid
var grumbled_day: int = -1
var mended_applied: bool = false
var _baked_cart: Dictionary = {}
var _flow: PackedVector2Array = PackedVector2Array()


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning
	for v: Array in session.world.meta.get("cart_trail", []):
		_baked_cart[Vector2i(int(v[0]), int(v[1]))] = true
	for v: Array in session.world.meta.get("river_flow", []):
		_flow.append(Vector2(float(v[0]), float(v[1])))


func s() -> GameSession:
	return _s.get_ref()


func _point(name: String) -> Vector2:
	var pts: Dictionary = s().world.meta.get("trail_job_points", {})
	if not pts.has(name):
		return Vector2.INF
	var v: Array = pts[name]
	return Vector2(float(v[0]) + 0.5, float(v[1]) + 0.5)


func has_canoe() -> bool:
	return s().jobs.unlocks.has("canoe")


func has_cart() -> bool:
	return s().jobs.unlocks.has("cart")


# --- the land's seasons ---------------------------------------------------------------

## What the season does to the land today.
func land_state() -> Dictionary:
	var c := s().clock
	var t: Dictionary = tuning.value("far_bank.seasons")
	return {
		# The first spring is the ranger's first week: no melt to cut them off.
		"melt": c.year >= 2 and c.season == 0 and c.day <= int(t["melt_days"]),
		"low_water": c.season == 1,
		"frozen": c.season == 3 and c.day >= int(t["freeze_day"]),
		"ice_crossing": c.season == 3 and c.day >= int(t["ice_crossing_day"]),
		"snowed": c.season == 3,
	}


## Sets the land for today. Returns whether anything changed.
func apply_land() -> bool:
	return s().world.set_land_season(land_state())


# --- Troll Badger Bridge ------------------------------------------------------------------

func bridge_mended() -> bool:
	return s().jobs.spots_done.has("bridge_mend")


## The mended bridge's gap: boards across the water, for this save.
func apply_bridge() -> void:
	var g := s()
	if not bridge_mended() or mended_applied:
		return
	mended_applied = true
	for v: Array in g.world.meta.get("bridge_gap", []):
		var t := Vector2i(int(v[0]), int(v[1]))
		g.world.set_ground(t, "boards")
		g.map.touch(t)
		g.land_changed.emit(t)


func toll_box_pos() -> Vector2:
	return _point("toll_box") if bridge_mended() else Vector2.INF


## X at the toll box: the first snack in the pack goes in, once a day.
func pay_toll() -> String:
	var g := s()
	if toll_day == g.clock.absolute_day():
		return content.text("fb_toll_paid_already")
	for i in g.backpack.slots.size():
		var item := g.backpack.item_at(i)
		if item == "":
			continue
		var kind := str(content.row("items", item).get("kind", ""))
		if kind == "food" or item in (tuning.value("far_bank.toll_trash") as Array):
			g.backpack.remove(item, 1)
			toll_day = g.clock.absolute_day()
			g.creatures.add_points("troll_badgers", tuning.integer("far_bank.toll_points"))
			return content.text("fb_toll_paid", {"item": content.item_name(item).to_lower()})
	return content.text("fb_toll_nothing")


## Crossing without paying: a badger clears its throat, once a day.
func _check_toll() -> void:
	var g := s()
	if not bridge_mended() or g.in_town or g.is_indoors():
		return
	var day := g.clock.absolute_day()
	if toll_day == day or grumbled_day == day:
		return
	var box: Array = g.world.meta.get("far_bank_box", [])
	if box.is_empty() or g.outdoor_pos.x < float(box[0]) + 24.0:
		return
	if g.outdoor_pos.distance_to(_point("toll_box")) < 12.0:
		grumbled_day = day
		g.message.emit(content.text("fb_toll_grumble"))


# --- cart trail ----------------------------------------------------------------------------

func is_cart_trail(t: Vector2i) -> bool:
	return _baked_cart.has(t) or widened.has(t)


## The shovel on trail: widens it to cart trail, the faced tile and one
## either side of it. Returns the tiles made cart trail.
func widen(t: Vector2i, facing: Vector2i) -> Array[Vector2i]:
	var g := s()
	var out: Array[Vector2i] = []
	var side := Vector2i(facing.y, facing.x)
	for d: Vector2i in [Vector2i.ZERO, side, -side]:
		var u := t + d
		if is_cart_trail(u):
			continue
		var ground := g.world.ground_at(u)
		if ground != "trail" and ground != "boards":
			if not g.can_dig(u):
				continue
			g._set_dug(u, true)
		widened[u] = true
		out.append(u)
		g.map.touch(u)
		g.land_changed.emit(u)
	return out


# --- getting in and out ------------------------------------------------------------------

func is_water(t: Vector2i) -> bool:
	return s().world.ground_at(t) in ["deep_water", "shallows", "lake"]


func canoe_season() -> bool:
	return s().clock.season != 3


## The vehicle within reach, "canoe" or "cart", or "".
func in_reach(pos: Vector2, reach: float) -> String:
	if riding != "":
		return ""
	if has_canoe() and canoe_pos != Vector2.INF and pos.distance_to(canoe_pos) <= reach + 0.8:
		return "canoe"
	if has_cart() and cart_pos != Vector2.INF and pos.distance_to(cart_pos) <= reach + 0.8:
		return "cart"
	return ""


func board(kind: String) -> String:
	var g := s()
	if kind == "canoe":
		if not canoe_season():
			return content.text("fb_canoe_winter")
		riding = "canoe"
		g.outdoor_pos = canoe_pos
		return content.text("fb_canoe_in")
	if kind == "cart":
		riding = "cart"
		g.outdoor_pos = cart_pos
		return content.text("fb_cart_in")
	return ""


## Steps out onto the nearest open ground beside the ranger. The vehicle
## stays where it is.
func leave() -> String:
	var g := s()
	var here := g.outdoor_pos
	var t := g.ranger_tile()
	var best := Vector2.INF
	var order: Array[Vector2i] = [g.facing_vector()]
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		order.append(d)
	for k in 2:
		for d: Vector2i in order:
			var u := t + d * (k + 1)
			if not g.world.is_solid(u) and not is_water(u):
				best = Vector2(u) + Vector2(0.5, 0.5)
				break
		if best != Vector2.INF:
			break
	if best == Vector2.INF:
		return content.text("fb_no_room_out")
	var was := riding
	riding = ""
	if was == "canoe":
		canoe_pos = here
	else:
		cart_pos = here
	g.outdoor_pos = best
	return content.text("fb_" + was + "_out")


## What the vehicle can't go through.
func blocks(t: Vector2i) -> bool:
	var g := s()
	if riding == "canoe":
		return not is_water(t)
	if riding == "cart":
		return g.world.is_solid(t) or not is_cart_trail(t)
	return g.world.is_solid(t)


## The river's flow where the ranger is: a unit vector, or zero away from it.
func flow_at(pos: Vector2) -> Vector2:
	var best := -1
	var bd := tuning.num("far_bank.canoe_current_reach")
	for i in _flow.size() - 1:
		var d := pos.distance_to(_flow[i])
		if d < bd:
			bd = d
			best = i
	if best < 0 or not is_water(Vector2i(floori(pos.x), floori(pos.y))):
		return Vector2.ZERO
	return (_flow[best + 1] - _flow[best]).normalized()


## Tiles a second in the vehicle, going in direction dir.
func speed(dir: Vector2) -> float:
	var g := s()
	var walk := tuning.num("movement.trail_speed_tiles")
	if riding == "cart":
		return walk * tuning.num("far_bank.cart_speed")
	var sp := walk * tuning.num("far_bank.canoe_speed")
	var f := flow_at(g.outdoor_pos)
	if f == Vector2.ZERO:
		return sp
	var along := dir.normalized().dot(f)
	var melt := bool(land_state()["melt"])
	if along > 0.3:
		return sp * tuning.num("far_bank.canoe_downstream") * (tuning.num("far_bank.melt_downstream") if melt else 1.0)
	if along < -0.3:
		return 0.0 if melt else sp * tuning.num("far_bank.canoe_upstream")
	return sp


## Once a vehicle is unlocked it waits at its place.
func place_new() -> void:
	if has_canoe() and canoe_pos == Vector2.INF:
		canoe_pos = _point("canoe_put_in")
	if has_cart() and cart_pos == Vector2.INF:
		cart_pos = _point("cart")


## Each frame.
func update() -> void:
	place_new()
	apply_bridge()
	_check_toll()
	var g := s()
	# Indoors, in town, asleep elsewhere or carried home by a rescue: the
	# vehicle stays where it was left.
	if riding != "" and (g.is_indoors() or g.in_town or blocks(g.ranger_tile())):
		riding = ""
	# The vehicle goes where the ranger drives it.
	if riding == "canoe":
		canoe_pos = g.outdoor_pos
	elif riding == "cart":
		cart_pos = g.outdoor_pos
	# The canoe is put away for winter: off the water with you.
	if riding == "canoe" and not canoe_season():
		g.message.emit(leave())


# --- saving -------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var w := []
	for t: Vector2i in widened:
		w.append([t.x, t.y])
	return {
		"riding": riding,
		"canoe": [canoe_pos.x, canoe_pos.y] if canoe_pos != Vector2.INF else [],
		"cart": [cart_pos.x, cart_pos.y] if cart_pos != Vector2.INF else [],
		"widened": w, "toll_day": toll_day,
	}


func from_dict(d: Dictionary) -> void:
	riding = str(d.get("riding", ""))
	var c: Array = d.get("canoe", [])
	canoe_pos = Vector2(float(c[0]), float(c[1])) if c.size() == 2 else Vector2.INF
	var k: Array = d.get("cart", [])
	cart_pos = Vector2(float(k[0]), float(k[1])) if k.size() == 2 else Vector2.INF
	widened = {}
	for v: Array in d.get("widened", []):
		widened[Vector2i(int(v[0]), int(v[1]))] = true
	toll_day = int(d.get("toll_day", -1))
	grumbled_day = -1
	mended_applied = false


func new_game() -> void:
	from_dict({})
