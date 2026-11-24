class_name Garden
extends RefCounted
## Phase 4b, step 14: the small garden behind the station (Phase 4 Spec, The
## garden). Six by six tiles, fenced, with a gate.
##
## The shovel turns a plot tile into soil; seeds from the outfitters are
## planted by hand (C); the watering can waters a tile, and rain waters
## everything. A crop grows one day for each morning after a day it was
## watered, and is picked with X when ripe; some regrow. A crop never dies:
## unwatered, it just waits. When the season turns, the old season's crops
## wither gently (X clears them). In winter the garden rests under snow.
## Small on purpose: Strange Ranger is not a farming game.

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var origin: Vector2i             # the plot's top-left tile in the park
var size: Vector2i
var gate: Vector2i               # the gate, in the fence's ring
var tiles: Dictionary = {}       # Vector2i -> {crop, grown, watered, ripe_at, withered}
var picked_ever: Dictionary = {} # crop id -> true, for the dishes' ideas


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning
	var st: Dictionary = session.world.structure_placement("ranger_station")
	var off: Array = tuning.value("garden.offset")
	var sz: Array = tuning.value("garden.size")
	size = Vector2i(int(sz[0]), int(sz[1]))
	origin = Vector2i(int(st["pos"][0]) + int(off[0]), int(st["pos"][1]) + int(off[1]))
	var gt: Array = tuning.value("garden.gate")
	gate = origin + Vector2i(int(gt[0]), int(gt[1]))
	for t in fence_tiles():
		if t != gate:
			session.world.set_blocked(t, true)


func s() -> GameSession:
	return _s.get_ref()


func in_plot(t: Vector2i) -> bool:
	return Rect2i(origin, size).has_point(t)


## The fence's ring of tiles round the plot, gate included.
func fence_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in range(origin.x - 1, origin.x + size.x + 1):
		out.append(Vector2i(x, origin.y - 1))
		out.append(Vector2i(x, origin.y + size.y))
	for y in range(origin.y, origin.y + size.y):
		out.append(Vector2i(origin.x - 1, y))
		out.append(Vector2i(origin.x + size.x, y))
	return out


func winter() -> bool:
	return s().clock.season_name() == "winter"


func crop(id: String) -> Dictionary:
	return content.row("crops", id)


func crop_for_seed(item: String) -> String:
	for r: Dictionary in content.rows("crops"):
		if str(r["seed"]) == item:
			return str(r["id"])
	return ""


## The tile the ranger faces, if it's in the plot (or under them).
func faced() -> Vector2i:
	var g := s()
	var t := g.ranger_tile() + g.facing_vector()
	if in_plot(t):
		return t
	if in_plot(g.ranger_tile()):
		return g.ranger_tile()
	return Vector2i(-1, -1)


# --- working the plot -----------------------------------------------------------

func dig(t: Vector2i) -> String:
	if not in_plot(t):
		return ""
	if winter():
		return "garden_winter"
	if tiles.has(t):
		var d: Dictionary = tiles[t]
		if bool(d.get("withered", false)):
			tiles[t] = _soil()
			return "garden_cleared"
		return "garden_occupied" if str(d["crop"]) != "" else ""
	tiles[t] = _soil()
	return "garden_dug"


func _soil() -> Dictionary:
	return {"crop": "", "grown": 0, "watered": -9999, "ripe_at": 0, "withered": false}


func plant(t: Vector2i, seed_item: String) -> String:
	var g := s()
	var cid := crop_for_seed(seed_item)
	if cid == "" or not in_plot(t):
		return ""
	if winter():
		return "garden_winter"
	if not tiles.has(t):
		return "garden_needs_soil"
	var d: Dictionary = tiles[t]
	if str(d["crop"]) != "" or bool(d["withered"]):
		return "garden_occupied"
	if str(crop(cid)["season"]) != g.clock.season_name():
		return "garden_wrong_season"
	if not g.backpack.remove(seed_item, 1):
		return ""
	d["crop"] = cid
	d["grown"] = 0
	d["ripe_at"] = int(crop(cid)["days"])
	return "garden_planted"


func water(t: Vector2i) -> String:
	if not in_plot(t) or not tiles.has(t):
		return "garden_needs_soil"
	if winter():
		return "garden_winter"
	var d: Dictionary = tiles[t]
	var today := s().clock.absolute_day()
	if int(d["watered"]) == today:
		return "garden_already_watered"
	d["watered"] = today
	return "garden_watered"


func watered_today(t: Vector2i) -> bool:
	return tiles.has(t) and int(tiles[t]["watered"]) == s().clock.absolute_day()


func ripe(t: Vector2i) -> bool:
	if not tiles.has(t):
		return false
	var d: Dictionary = tiles[t]
	return str(d["crop"]) != "" and not bool(d["withered"]) and int(d["grown"]) >= int(d["ripe_at"])


## X on a ripe crop: picks it (a regrowing one starts again from its
## regrowing picture). Returns the item picked, or "".
func pick(t: Vector2i) -> String:
	var g := s()
	if not ripe(t):
		return ""
	var d: Dictionary = tiles[t]
	var c := crop(str(d["crop"]))
	var item := str(c["item"])
	if g.backpack.room_for(item) < 1:
		g.message.emit(content.text("shop_no_room"))
		return ""
	g.backpack.add(item, 1)
	if int(c["regrow"]) > 0:
		d["ripe_at"] = int(d["grown"]) + int(c["regrow"])
		d["regrowing"] = true
	else:
		tiles[t] = _soil()
	var first := not picked_ever.has(str(c["id"]))
	picked_ever[str(c["id"])] = true
	if first:
		for r: Dictionary in content.rows("recipes"):
			if str(r.get("learned", "")) == "garden" and (r["inputs"] as Dictionary).has(item) and not g.recipes_known.has(str(r["id"])):
				g.learn_recipe(str(r["id"]))
	return item


## Each morning: crops watered yesterday (or rained on) grow a day; the old
## season's crops wither when the season turns.
func morning(rained: bool) -> void:
	var g := s()
	var yesterday := g.clock.absolute_day() - 1
	var season := g.clock.season_name()
	for t: Vector2i in tiles:
		var d: Dictionary = tiles[t]
		if str(d["crop"]) == "" or bool(d["withered"]):
			continue
		if str(crop(str(d["crop"]))["season"]) != season:
			d["withered"] = true
			continue
		if rained or int(d["watered"]) == yesterday:
			d["grown"] = int(d["grown"]) + 1


## Grows every crop a day, as if watered (debug).
func grow_all() -> void:
	for t: Vector2i in tiles:
		var d: Dictionary = tiles[t]
		if str(d["crop"]) != "" and not bool(d["withered"]):
			d["grown"] = int(d["grown"]) + 1


## The picture for a tile's soil and crop: [soil, crop or ""].
func pictures(t: Vector2i) -> Array[String]:
	if winter():
		return ["garden_soil_snow" if tiles.has(t) else "", ""]
	if not tiles.has(t):
		return ["", ""]
	var d: Dictionary = tiles[t]
	var soil := "garden_soil_wet" if watered_today(t) or s().town._rainy() else "garden_soil_dry"
	if bool(d["withered"]):
		return [soil, "crop_withered"]
	if str(d["crop"]) == "":
		return [soil, ""]
	var c := crop(str(d["crop"]))
	if bool(d.get("regrowing", false)) and not ripe(t) and str(c["regrow_sprite"]) != "":
		return [soil, str(c["regrow_sprite"])]
	var stages: Array = c["stages"]
	var total := maxi(1, int(c["days"]))
	var i := 3 if ripe(t) else clampi(int(float(d["grown"]) / total * 3.0), 0, 2)
	return [soil, str(stages[i])]


## What X says about a tile that isn't ripe.
func status_text(t: Vector2i) -> String:
	if not tiles.has(t):
		return ""
	var d: Dictionary = tiles[t]
	if str(d["crop"]) == "" or bool(d["withered"]):
		return ""
	var nm := content.item_name(str(crop(str(d["crop"]))["item"])).to_lower()
	var left := int(d["ripe_at"]) - int(d["grown"])
	if not watered_today(t):
		return content.text("garden_not_ready", {"item": nm, "n": left}) + " " + content.text("garden_dry")
	return content.text("garden_not_ready", {"item": nm, "n": left})


# --- saving ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var out := []
	for t: Vector2i in tiles:
		var d: Dictionary = tiles[t]
		out.append([t.x, t.y, str(d["crop"]), int(d["grown"]), int(d["watered"]), int(d["ripe_at"]), bool(d["withered"]), bool(d.get("regrowing", false))])
	return {"tiles": out, "picked": picked_ever.keys()}


func from_dict(d: Dictionary) -> void:
	tiles = {}
	for e: Variant in d.get("tiles", []):
		var a: Array = e
		tiles[Vector2i(int(a[0]), int(a[1]))] = {"crop": str(a[2]), "grown": int(a[3]), "watered": int(a[4]), "ripe_at": int(a[5]), "withered": bool(a[6]), "regrowing": bool(a[7]) if a.size() > 7 else false}
	picked_ever = {}
	for k: Variant in d.get("picked", []):
		picked_ever[str(k)] = true


func new_game() -> void:
	from_dict({})
