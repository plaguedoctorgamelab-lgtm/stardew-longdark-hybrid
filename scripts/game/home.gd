class_name Home
extends RefCounted
## Phase 4b, step 13: the ranger station as a home (Phase 4 Spec, Station
## upgrades and Decorating).
##
## Upgrades are ordered from Gus at the carpentry, in order, and his crew
## finishes each in three days; the station can be slept in meanwhile.
## 1. Shipshape: the roof and shutters mended; warmer inside.
## 2. A proper kitchen: a cooking range (the cooking recipes, no fire) and a
##    pantry of 24 slots for food.
## 3. A second room: the station grows to the right, doubling the floor, with
##    a second window and a reading chair that restores energy.
##
## Decorating: furniture held in the item bar is set down with C on the floor
## in front of the ranger, or hung on the back wall when facing it; C with an
## empty hand picks a piece up again. The bed, chest, workbench and kitchen
## can be lifted and moved but never taken away, and nothing may be put
## where it blocks the way from the door to any of them. Wallpaper and floors
## cover the whole room; the old one comes back.

const STATION := "ranger_station"
## Pieces that can be moved but never taken out of the station.
const FIXED_KINDS: Array[String] = ["bed", "chest", "workbench", "range", "pantry", "reading_chair"]
## Pieces the way from the door must always reach.
const USED_KINDS: Array[String] = ["bed", "chest", "workbench", "range", "pantry", "reading_chair", "catalog", "note_board", "radio", "shelf", "staff_board", "stove"]

var _s: WeakRef
var content: ContentDB
var tuning: Tuning
var level: int = 0               # upgrades finished, in order
var building: String = ""        # the upgrade Gus's crew is on
var done_day: int = -1           # the absolute day they finish it
var placed: Array = []           # {id, item, pos: [x, y]}: furniture put in the station
var moved: Dictionary = {}       # a station piece's id -> [x, y]
var wall: String = ""            # wallpaper item put up, or "" for the station's own
var floor_item: String = ""      # flooring item put down, or ""
var carrying: Dictionary = {}    # a piece lifted to move: its furniture row
var pantry: Inventory
var _next_id: int = 1
var _base: Dictionary = {}       # the station's interior row, as built


func _init(session: GameSession) -> void:
	_s = weakref(session)
	content = session.content
	tuning = session.tuning
	pantry = Inventory.new(content, tuning.integer("home.pantry_slots"))
	# The pantry keeps food: dishes, forage and crops.
	for r: Dictionary in content.rows("items"):
		if str(r["kind"]) in ["food", "crop"]:
			pantry.only[str(r["id"])] = true
	_base = (content.row("structures", STATION)["interior"] as Dictionary).duplicate(true)


func s() -> GameSession:
	return _s.get_ref()


func upgrade(id: String) -> Dictionary:
	return content.row("home_upgrades", id)


func has(id: String) -> bool:
	return level >= int(upgrade(id)["order"])


func upgrades_in_order() -> Array:
	var out := content.rows("home_upgrades").duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return out


# --- ordering from Gus ------------------------------------------------------------

func _mats_text(m: Dictionary) -> String:
	var parts := PackedStringArray()
	for k: String in m:
		parts.append("%d %s" % [int(m[k]), content.item_name(k).to_lower()])
	return ", ".join(parts)


func order_options() -> Array:
	var out := []
	var prev := ""
	for u: Dictionary in upgrades_in_order():
		var id := str(u["id"])
		var nm := content.text("home_" + id)
		var label := ""
		var on := false
		if has(id):
			label = content.text("home_order_done", {"name": nm})
		elif building == id:
			label = content.text("home_order_building", {"name": nm, "days": maxi(1, done_day - s().clock.absolute_day())})
		elif level + 1 == int(u["order"]):
			label = content.text("home_order_line", {"name": nm, "desc": content.text("home_%s_desc" % id), "price": int(u["price"]), "mats": _mats_text(u["materials"])})
			on = building == ""
		else:
			label = content.text("home_order_later", {"name": nm, "before": content.text("home_" + prev)})
		out.append({"id": "up:" + id, "label": label, "enabled": on})
		prev = id
	out.append({"id": "back", "label": content.text("shop_back")})
	return out


## Orders the next upgrade. Returns "" or the text id of why not.
func order(id: String) -> String:
	var g := s()
	if building != "":
		return "home_busy"
	if has(id) or level + 1 != int(upgrade(id)["order"]):
		return "home_busy"
	var u := upgrade(id)
	var mats: Dictionary = u["materials"]
	var chest: Inventory = g.structures.chests[STATION]
	for k: String in mats:
		if g.backpack.count(k) + chest.count(k) < int(mats[k]):
			return "home_cant_afford"
	if not g.park.money.can_afford(int(u["price"])):
		return "home_cant_afford"
	g.park.money.spend(g.clock.absolute_day(), "catalog", int(u["price"]))
	# The materials come from the backpack first, then the station chest.
	for k: String in mats:
		var from_pack := mini(int(mats[k]), g.backpack.count(k))
		g.backpack.remove(k, from_pack)
		chest.remove(k, int(mats[k]) - from_pack)
	building = id
	done_day = g.clock.absolute_day() + tuning.integer("home.build_days")
	return ""


func order_problem_text(id: String) -> String:
	var u := upgrade(id)
	return content.text("home_cant_afford", {"price": int(u["price"]), "mats": _mats_text(u["materials"])})


## Each morning: the crew finishes on its day.
func morning() -> void:
	if building != "" and s().clock.absolute_day() >= done_day:
		finish_now()


func finish_now() -> void:
	if building == "":
		return
	var id := building
	building = ""
	done_day = -1
	level = maxi(level, int(upgrade(id)["order"]))
	apply()
	s().park.morning_lines.append(content.text("home_finished", {"name": content.text("home_" + id)}))
	s().message.emit(content.text("home_finished", {"name": content.text("home_" + id)}))


# --- the station, outside --------------------------------------------------------

func station_sprite() -> String:
	var out := str(content.row("structures", STATION)["sprite_repaired"])
	for u: Dictionary in upgrades_in_order():
		if has(str(u["id"])) and u.has("sprite") and Art.has_picture(str(u["sprite"])):
			out = str(u["sprite"])
	return out


## Extra tiles of station to the right of its footprint (the second room).
func extra_width() -> int:
	return 2 if has("second_room") else 0


## Warmth each ten minutes inside, once Shipshape.
func warmth_bonus() -> float:
	var out := 0.0
	for u: Dictionary in upgrades_in_order():
		if has(str(u["id"])):
			out += float(u.get("warmth", 0))
	return out


# --- the room -----------------------------------------------------------------------

func layout() -> InteriorLayout:
	return s().interiors[STATION]


## Builds the station's room from its row, the upgrades, the pieces moved and
## the furniture placed.
func apply() -> void:
	var lay := layout()
	var w := int(_base["size"][0]) + (int(upgrade("second_room").get("extra_width", 8)) if has("second_room") else 0)
	lay.size = Vector2i(w, int(_base["size"][1]))
	# The small things jobs put in the room, and a kit's workbench, stay.
	var furn: Array = lay.furniture.filter(func(f: Dictionary) -> bool: return str(f["kind"]) == "job_spot" or bool(f.get("from_kit", false)))
	for f: Dictionary in _base["furniture"]:
		# The small stove stands where the kitchen's range goes, until then
		# (tracker #64).
		if str(f["id"]) == "stove" and has("kitchen"):
			continue
		furn.append(f.duplicate(true))
	if has("kitchen"):
		furn.append({"id": "range", "kind": "range", "pos": [4, 5], "size": [2, 1], "sprite": "furniture_cooking_range"})
		furn.append({"id": "pantry", "kind": "pantry", "pos": [10, 8], "size": [2, 1], "sprite": "furniture_pantry"})
	if has("second_room"):
		furn.append({"id": "reading_chair", "kind": "reading_chair", "pos": [16, 4], "size": [2, 1], "sprite": "furniture_reading_chair"})
	for f: Dictionary in furn:
		if moved.has(str(f["id"])):
			f["pos"] = (moved[str(f["id"])] as Array).duplicate()
	if not carrying.is_empty():
		furn = furn.filter(func(f: Dictionary) -> bool: return str(f["id"]) != str(carrying["id"]))
	for p: Dictionary in placed:
		var r := content.row("furniture", str(p["item"]))
		if str(r["place"]) == "floor":
			furn.append({"id": str(p["id"]), "kind": "decor", "pos": (p["pos"] as Array).duplicate(), "size": (r["size"] as Array).duplicate(), "sprite": sprite_of(str(p["item"])), "item": str(p["item"])})
	lay.furniture = furn
	s()._refresh_spot_rooms()


func sprite_of(item: String) -> String:
	return str(content.row("furniture", item)["sprite"])


## The station's drawing row: walls, floor, windows and wall pieces, rugs.
func inside_row() -> Dictionary:
	var d := _base.duplicate(true)
	d["size"] = [layout().size.x, layout().size.y]
	if wall != "":
		d["wall"] = sprite_of(wall)
		d.erase("wall_base")
	if floor_item != "":
		d["floor"] = sprite_of(floor_item)
		d.erase("floor_alts")
	var decor: Array = d.get("decor", [])
	if has("second_room"):
		decor.append({"sprite": "interior_window_curtains", "pos": [15, 0]})
	var rugs: Array = d.get("rugs", [])
	for p: Dictionary in placed:
		var r := content.row("furniture", str(p["item"]))
		match str(r["place"]):
			"wall":
				decor.append({"sprite": sprite_of(str(p["item"])), "pos": (p["pos"] as Array).duplicate(), "placed": str(p["id"])})
			"rug":
				rugs.append({"sprite": sprite_of(str(p["item"])), "pos": (p["pos"] as Array).duplicate(), "placed": str(p["id"])})
	d["decor"] = decor
	d["rugs"] = rugs
	return d


# --- placing --------------------------------------------------------------------------

func _rect(pos: Vector2i, size: Vector2i) -> Rect2i:
	return Rect2i(pos, size)


## Where a piece of this size would go for the ranger at `at` facing `facing`.
func target_rect(at: Vector2, facing: int, size: Vector2i, place: String) -> Rect2i:
	var t := Vector2i(floori(at.x), floori(at.y))
	var lay := layout()
	if place == "wall":
		return Rect2i(Vector2i(t.x - size.x / 2, lay.wall_height - size.y), size)
	var f := Vector2i([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][facing])
	var n := t + f
	match facing:
		GameSession.FACING_DOWN:
			return Rect2i(Vector2i(n.x - size.x / 2, n.y), size)
		GameSession.FACING_UP:
			return Rect2i(Vector2i(n.x - size.x / 2, n.y - size.y + 1), size)
		GameSession.FACING_LEFT:
			return Rect2i(Vector2i(n.x - size.x + 1, n.y), size)
	return Rect2i(n, size)


func _floor_rect() -> Rect2i:
	var lay := layout()
	return Rect2i(1, lay.wall_height, lay.size.x - 2, lay.size.y - 1 - lay.wall_height)


## Why a floor piece can't stand at r ("" if it can): off the floor, on
## something, on the doorway, or in the way of the door, bed, chest,
## workbench or anything else the ranger uses.
func floor_problem(r: Rect2i, ignore: String = "") -> String:
	var lay := layout()
	if not _floor_rect().encloses(r):
		return "home_cant_place"
	var door := lay.door_tile
	var entry := Vector2i(floori(lay.entry.x), floori(lay.entry.y))
	if r.has_point(door) or r.has_point(entry) or r.has_point(door + Vector2i(0, -1)):
		return "home_blocks"
	var t := s().interior_pos
	if s().location == STATION and r.has_point(Vector2i(floori(t.x), floori(t.y))):
		return "home_cant_place"
	for f: Dictionary in lay.furniture:
		if str(f["kind"]) == "exit" or str(f["id"]) == ignore:
			continue
		if lay.furniture_rect(f).intersects(r):
			return "home_cant_place"
	var why := way_problem(r, ignore)
	return why


## Whether the door still reaches every piece the ranger uses with a piece at
## r: "" or "home_blocks".
func way_problem(r: Rect2i, ignore: String = "") -> String:
	var lay := layout()
	var solid := func(t: Vector2i) -> bool:
		if r.has_point(t):
			return true
		for f: Dictionary in lay.furniture:
			if str(f["kind"]) != "exit" and str(f["id"]) != ignore and lay.furniture_rect(f).has_point(t):
				return true
		return not _floor_rect().has_point(t)
	var start := Vector2i(floori(lay.entry.x), floori(lay.entry.y))
	var seen := {start: true}
	var q: Array[Vector2i] = [start]
	var h := 0
	while h < q.size():
		var c := q[h]
		h += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if not seen.has(n) and not solid.call(n):
				seen[n] = true
				q.append(n)
	for f: Dictionary in lay.furniture:
		if not USED_KINDS.has(str(f["kind"])) or str(f["id"]) == ignore:
			continue
		var fr := lay.furniture_rect(f)
		var ok := false
		for x in range(fr.position.x - 1, fr.end.x + 1):
			for y in range(fr.position.y - 1, fr.end.y + 1):
				var adj := (x >= fr.position.x and x < fr.end.x) != (y >= fr.position.y and y < fr.end.y)
				if adj and seen.has(Vector2i(x, y)):
					ok = true
		if not ok:
			return "home_blocks"
	return ""


## Why a wall piece can't hang at r: off the wall, or over a window or another
## wall piece.
func wall_problem(r: Rect2i) -> String:
	var lay := layout()
	if r.position.x < 1 or r.end.x > lay.size.x - 1 or r.position.y < 0 or r.end.y > lay.wall_height:
		return "home_cant_place"
	for dd: Dictionary in inside_row()["decor"]:
		var tex := Art.texture(str(dd["sprite"]))
		var sz := Vector2i(maxi(1, ceili(tex.get_width() / 16.0)), maxi(1, ceili(tex.get_height() / 16.0))) if tex != null else Vector2i(1, 1)
		var dr := Rect2i(Vector2i(floori(float(dd["pos"][0])), floori(float(dd["pos"][1]))), sz)
		if dr.intersects(r):
			return "home_cant_place"
	return ""


func rug_problem(r: Rect2i) -> String:
	if not _floor_rect().encloses(r):
		return "home_cant_place"
	for rr: Dictionary in inside_row()["rugs"]:
		var tex := Art.texture(str(rr["sprite"]))
		var sz := Vector2i(ceili(tex.get_width() / 16.0), ceili(tex.get_height() / 16.0)) if tex != null else Vector2i(1, 1)
		if Rect2i(Vector2i(int(rr["pos"][0]), int(rr["pos"][1])), sz).intersects(r):
			return "home_cant_place"
	return ""


## Where the held piece would go now and whether it fits, for the ghost.
func preview(item: String) -> Dictionary:
	var g := s()
	if g.location != STATION or not content.has("furniture", item):
		return {}
	var r := content.row("furniture", item)
	if bool(r.get("surface", false)):
		return {}
	var place := str(r["place"])
	if place == "wall" and (g.facing != GameSession.FACING_UP or floori(g.interior_pos.y) != layout().wall_height):
		return {"why": "home_wall_only"}
	var rect := target_rect(g.interior_pos, g.facing, Vector2i(int(r["size"][0]), int(r["size"][1])), place)
	var why := wall_problem(rect) if place == "wall" else (rug_problem(rect) if place == "rug" else floor_problem(rect))
	return {"rect": rect, "why": why, "sprite": sprite_of(item), "place": place}


## C with a furniture item held in the station: sets it down. Returns "" or
## the text id of why not.
func place_held(item: String) -> String:
	var g := s()
	if g.location != STATION:
		return "home_only_station"
	var r := content.row("furniture", item)
	if bool(r.get("surface", false)):
		return put_up_surface(item)
	var p := preview(item)
	if p.has("why") and str(p["why"]) != "":
		return str(p["why"])
	if not g.backpack.remove(item, 1):
		return "home_cant_place"
	var rect: Rect2i = p["rect"]
	placed.append({"id": "placed_%d" % _next_id, "item": item, "pos": [rect.position.x, rect.position.y]})
	_next_id += 1
	apply()
	return ""


func put_up_surface(item: String) -> String:
	var g := s()
	var r := content.row("furniture", item)
	if not g.backpack.remove(item, 1):
		return "home_cant_place"
	var is_wall := str(r["place"]) == "wall"
	var old := wall if is_wall else floor_item
	if old != "":
		if g.backpack.add(old, 1) > 0:
			(g.structures.chests[STATION] as Inventory).add(old, 1)
	if is_wall:
		wall = item
	else:
		floor_item = item
	apply()
	return ""


## The placed piece the ranger faces (floor, then rug), or the wall piece
## above when facing the back wall: its placed row, or {}.
func placed_faced() -> Dictionary:
	var g := s()
	var t := Vector2i(floori(g.interior_pos.x), floori(g.interior_pos.y))
	var f := t + Vector2i([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][g.facing])
	var lay := layout()
	var by_kind := {"floor": [], "rug": [], "wall": []}
	for p: Dictionary in placed:
		(by_kind[str(content.row("furniture", str(p["item"]))["place"])] as Array).append(p)
	for p: Dictionary in by_kind["floor"]:
		var r := content.row("furniture", str(p["item"]))
		if Rect2i(Vector2i(int(p["pos"][0]), int(p["pos"][1])), Vector2i(int(r["size"][0]), int(r["size"][1]))).has_point(f):
			return p
	if g.facing == GameSession.FACING_UP and t.y == lay.wall_height:
		for p: Dictionary in by_kind["wall"]:
			var r := content.row("furniture", str(p["item"]))
			if t.x >= int(p["pos"][0]) and t.x < int(p["pos"][0]) + int(r["size"][0]):
				return p
	for p: Dictionary in by_kind["rug"]:
		var r := content.row("furniture", str(p["item"]))
		var rr := Rect2i(Vector2i(int(p["pos"][0]), int(p["pos"][1])), Vector2i(int(r["size"][0]), int(r["size"][1])))
		if rr.has_point(f) or rr.has_point(t):
			return p
	return {}


## The station piece (bed, chest...) the ranger faces, if it can be moved.
func fixed_faced() -> Dictionary:
	var g := s()
	var t := Vector2i(floori(g.interior_pos.x), floori(g.interior_pos.y))
	var f := t + Vector2i([Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)][g.facing])
	var lay := layout()
	for fr: Dictionary in lay.furniture:
		if FIXED_KINDS.has(str(fr["kind"])) and lay.furniture_rect(fr).has_point(f):
			return fr
	return {}


## C with an empty hand in the station: picks up a placed piece, lifts a
## station piece to move it, or sets a lifted one down.
func use_empty_hand() -> String:
	var g := s()
	if not carrying.is_empty():
		return set_down()
	var p := placed_faced()
	if not p.is_empty():
		if g.backpack.room_for(str(p["item"])) < 1:
			return "home_no_room"
		placed.erase(p)
		g.backpack.add(str(p["item"]), 1)
		apply()
		g.message.emit(content.text("home_picked", {"item": content.item_name(str(p["item"])).to_lower()}))
		return "picked"
	var fx := fixed_faced()
	if not fx.is_empty():
		carrying = fx.duplicate(true)
		apply()
		g.message.emit(content.text("home_carrying", {"item": furniture_name(fx)}))
		return "lifted"
	return ""


func furniture_name(f: Dictionary) -> String:
	var k := str(f["kind"])
	for key: String in ["furn_" + k, "furniture_" + k]:
		if content.has("text", key):
			return content.text(key).to_lower()
	return k.replace("_", " ")


## Sets the lifted station piece down in front of the ranger.
func set_down() -> String:
	var g := s()
	var size := Vector2i(int(carrying["size"][0]), int(carrying["size"][1]))
	var rect := target_rect(g.interior_pos, g.facing, size, "floor")
	var why := floor_problem(rect, str(carrying["id"]))
	if why != "":
		return why
	moved[str(carrying["id"])] = [rect.position.x, rect.position.y]
	var nm := furniture_name(carrying)
	carrying = {}
	apply()
	g.message.emit(content.text("home_placed", {"item": nm}))
	return ""


## Leaving with a piece lifted puts it back where it was.
func drop_carrying() -> void:
	if not carrying.is_empty():
		carrying = {}
		apply()


## The way from the door reaches everything the ranger uses, as laid out now.
func way_ok() -> bool:
	return way_problem(Rect2i(-10, -10, 0, 0)) == ""


# --- saving ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"level": level, "building": building, "done_day": done_day, "placed": placed.duplicate(true), "moved": moved.duplicate(true), "wall": wall, "floor": floor_item, "pantry": pantry.to_array(), "next_id": _next_id}


func from_dict(d: Dictionary) -> void:
	level = int(d.get("level", 0))
	building = str(d.get("building", ""))
	done_day = int(d.get("done_day", -1))
	placed = []
	for p: Variant in d.get("placed", []):
		var pd: Dictionary = p
		if content.has("furniture", str(pd["item"])):
			placed.append({"id": str(pd["id"]), "item": str(pd["item"]), "pos": [int(pd["pos"][0]), int(pd["pos"][1])]})
	moved = {}
	for k: String in d.get("moved", {}):
		moved[k] = [int(d["moved"][k][0]), int(d["moved"][k][1])]
	wall = str(d.get("wall", ""))
	floor_item = str(d.get("floor", ""))
	pantry.from_array(d.get("pantry", []))
	_next_id = int(d.get("next_id", placed.size() + 1))
	carrying = {}
	apply()


func new_game() -> void:
	pantry.clear()
	from_dict({})
