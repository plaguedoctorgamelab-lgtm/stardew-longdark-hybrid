class_name TownView
extends Node2D
## Draws Humdrum: its ground, buildings, trees, lamps and benches, and its
## people walking their routines. Since Art Request 19 (0.6.7): ground edges
## where one ground meets another, flat pieces laid on the ground (the
## square's mosaic, petals, lily pads), pieces shown only in their season,
## pieces with a lit picture swapped in at night (streetlamps, string
## lights), and windows that glow at night, drawn above the night's tint. Each person is their own walk sheet if
## drawn (Wren), or built from the visitors' layered pictures in their own
## colours until their sheet comes.

const TILE := 16

var session: GameSession
var town: Town
var ground_layer: TileMapLayer
var sort_root: Node2D
var _people: Dictionary = {}   # id -> Node2D
var _time: float = 0.0
var lamps: Array[Vector2] = []  # pixel positions of the streetlamps' lights
var flat_root: Node2D            # pieces lying on the ground, under everything standing
var glow_layer: CanvasLayer      # lit windows, above the night's tint
var _seasonal: Array = []        # [sprite, seasons it shows in]
var _litable: Array = []         # [sprite, day picture, night picture]
var _night: bool = false
var _season: String = ""


func setup(s: GameSession) -> void:
	session = s
	town = s.town
	ground_layer = TileMapLayer.new()
	ground_layer.z_index = -20
	add_child(ground_layer)
	sort_root = Node2D.new()
	sort_root.y_sort_enabled = true
	add_child(sort_root)
	_build_ground()
	flat_root = Node2D.new()
	flat_root.z_index = -15
	add_child(flat_root)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 2
	glow_layer.follow_viewport_enabled = true
	glow_layer.visible = false
	add_child(glow_layer)
	for b: Dictionary in town.buildings:
		var spr := _stand(str(b["sprite"]), Vector2(float(b["pos"][0]) + float(b["size"][0]) / 2.0, float(b["pos"][1]) + float(b["size"][1])))
		Shadow.attach(spr, float(b["size"][0]) * TILE, session.tuning)
		var glow := window_glow(spr.texture.get_image(), session.tuning, str(b["sprite"]))
		if glow != null:
			var g := Sprite2D.new()
			g.centered = false
			g.texture = ImageTexture.create_from_image(glow)
			g.position = spr.position
			g.offset = spr.offset
			glow_layer.add_child(g)
	for o: Dictionary in town.objects:
		var art := str(o["sprite"])
		var spr: Sprite2D
		if bool(o.get("flat", false)):
			spr = Sprite2D.new()
			spr.centered = false
			spr.texture = Art.texture(art)
			spr.position = Vector2(float(o["pos"][0]), float(o["pos"][1])) * TILE
			flat_root.add_child(spr)
		else:
			spr = _stand(art, Vector2(float(o["pos"][0]) + 0.5, float(o["pos"][1]) + 1.0))
			spr.offset.y -= float(o.get("lift", 0))
			if not art.begins_with("town_streetlamp") and not bool(o.get("no_shadow", false)):
				Shadow.attach(spr, minf(spr.texture.get_width(), 3 * TILE), session.tuning)
		if bool(o.get("lamp", false)):
			lamps.append(spr.position + Vector2(0, -spr.texture.get_height() + 4))
		if o.has("seasons"):
			_seasonal.append([spr, o["seasons"]])
		if Art.has_picture(art + "_lit"):
			_litable.append([spr, Art.texture(art), Art.texture(art + "_lit")])
	_update_lights(true)
	for r: Dictionary in session.content.rows("townsfolk"):
		_people[str(r["id"])] = _make_person(r)


## A picture standing with its foot at `foot` (in tiles), bottom middle.
func _stand(art: String, foot: Vector2) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(art)
	spr.position = foot * TILE
	spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	sort_root.add_child(spr)
	return spr


## The town's ground: every picture it uses side by side in one atlas. Each
## tile picks its version from its position, as in the park; where a ground
## meets another its edge set says (tuning town_look.edges), the tile takes
## that set's side, corner or inner corner instead.
func _build_ground() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var looks: Dictionary = session.tuning.value("town_look.ground")
	var edges: Dictionary = session.tuning.value("town_look.edges")
	var names: Array[String] = []
	for code: String in looks:
		for n: String in looks[code]["pictures"]:
			if not names.has(n):
				names.append(n)
	for code: String in edges:
		if code == "note":
			continue
		for part: String in EDGE_PARTS:
			var n := "%s_%s" % [edges[code]["set"], part]
			if not names.has(n):
				names.append(n)
	var strip := Image.create(TILE * names.size(), TILE, false, Image.FORMAT_RGBA8)
	for i in names.size():
		var im := Art.image(names[i])
		im.convert(Image.FORMAT_RGBA8)
		strip.blit_rect(im, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(strip)
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in names.size():
		src.create_tile(Vector2i(i, 0))
	var sid := ts.add_source(src)
	ground_layer.tile_set = ts
	var weights := {}
	for code: String in looks:
		weights[code] = WorldView._running_total(looks[code]["weights"])
	for y in town.size.y:
		for x in town.size.x:
			var t := Vector2i(x, y)
			ground_layer.set_cell(t, sid, Vector2i(names.find(picture_at(t, looks, edges, weights)), 0))
	# The park road runs on past the town's east edge, toward the gate.
	var road := names.find(str(looks["c"]["pictures"][0]))
	for y in range(28, 33):
		for x in range(town.size.x, town.size.x + 12):
			ground_layer.set_cell(Vector2i(x, y), sid, Vector2i(road, 0))


const EDGE_PARTS := ["nw", "n", "ne", "w", "e", "sw", "s", "se", "inw", "ine", "isw", "ise"]


## The picture for one tile of the town's ground: its edge set's side or
## corner where it meets a ground listed as outside, else one of its code's
## own versions.
func picture_at(t: Vector2i, looks: Dictionary, edges: Dictionary, weights: Dictionary) -> String:
	var code := town.ground_at(t)
	if edges.has(code):
		var e: Dictionary = edges[code]
		var out: Array = e["outside"]
		var o := func(dx: int, dy: int) -> bool:
			var n := t + Vector2i(dx, dy)
			return town.in_bounds(n) and out.has(town.ground_at(n))
		var nn: bool = o.call(0, -1)
		var ss: bool = o.call(0, 1)
		var ww: bool = o.call(-1, 0)
		var ee: bool = o.call(1, 0)
		var part := ""
		if nn and ww:
			part = "nw"
		elif nn and ee:
			part = "ne"
		elif ss and ww:
			part = "sw"
		elif ss and ee:
			part = "se"
		elif nn:
			part = "n"
		elif ss:
			part = "s"
		elif ww:
			part = "w"
		elif ee:
			part = "e"
		elif o.call(-1, -1):
			part = "inw"
		elif o.call(1, -1):
			part = "ine"
		elif o.call(-1, 1):
			part = "isw"
		elif o.call(1, 1):
			part = "ise"
		if part != "":
			return "%s_%s" % [e["set"], part]
	var pics: Array = looks[code]["pictures"]
	return str(pics[WorldView.pick(t, weights[code], 0)])


func _make_person(r: Dictionary) -> Node2D:
	var node := person_node(session, r)
	sort_root.add_child(node)
	return node


## A townsperson's picture: their own walk sheet if drawn, or the visitors'
## layers in their colours. Also used inside the shops' rooms.
static func person_node(session: GameSession, r: Dictionary) -> Node2D:
	var node := Node2D.new()
	Shadow.attach(node, TILE, session.tuning)
	var sheet := str(r.get("sprite", ""))
	if sheet != "" and Art.has_picture(sheet):
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = Art.texture(sheet)
		spr.hframes = 4
		spr.vframes = 4
		spr.offset = Vector2(-8, -30)
		node.add_child(spr)
		return node
	var look: Dictionary = r["look"]
	var layers := [["visitor_body", look["skin"]], ["visitor_hair", look["hair"]], ["visitor_pants", look["pants"]], ["visitor_shirt", look["shirt"]]]
	if str(look.get("hat", "")) != "":
		layers.append([look["hat"], look.get("hat_color", look["shirt"])])
	for l: Array in layers:
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = Art.texture(l[0])
		spr.hframes = 4
		spr.vframes = 4
		var lift := float((session.tuning.value("look.visitor_layer_lift") as Dictionary).get(l[0], 0))
		spr.offset = Vector2(-8, -24 - lift)
		var c: Array = l[1]
		spr.modulate = Color8(int(c[0]), int(c[1]), int(c[2]))
		node.add_child(spr)
	if bool(r.get("child", false)):
		node.scale = Vector2(0.85, 0.85)
	return node


func _process(delta: float) -> void:
	glow_layer.visible = visible and _night
	if not visible:
		return
	_time += delta
	_update_lights(false)
	for id: String in _people:
		var node: Node2D = _people[id]
		node.visible = town.shown(id)
		if not node.visible:
			continue
		var p: Dictionary = town.people[id]
		node.position = ((p["pos"] as Vector2) * TILE).round()
		var walking := not (p["path"] as Array).is_empty()
		var frame := int(_time * 6.0) % 4 if walking else 0
		for c: Node in node.get_children():
			if c is Sprite2D:
				(c as Sprite2D).frame = int(p["facing"]) * 4 + frame


## Night and season: lit pictures and glowing windows at night, seasonal
## pieces in their season. Only does anything when one of them changes.
func _update_lights(force: bool) -> void:
	var n := Daylight.is_night(session.tuning, session.clock.season_name(), session.clock.minute)
	var se := session.clock.season_name()
	if not force and n == _night and se == _season:
		return
	_night = n
	_season = se
	for l: Array in _litable:
		(l[0] as Sprite2D).texture = l[2] if n else l[1]
	for e: Array in _seasonal:
		(e[0] as Sprite2D).visible = (e[1] as Array).has(se)
	glow_layer.visible = visible and n


## A building's lit windows: its window glass (pale, bluer than red, as Art
## Request 19 asked: tuning town_look.window_glass) in a warm colour, every
## other pixel clear. Null when the picture has no glass.
## A picture listed under window_glass.pictures has darker glass than the
## pale blue Art Request 19 asked for (the Percolator, Casa Luna): its glass
## is any bluish pixel inside its window boxes, within its own light range.
static func window_glow(img: Image, tuning: Tuning, art_name: String = "") -> Image:
	var wg: Dictionary = tuning.value("town_look.window_glass")
	var own: Dictionary = (wg.get("pictures", {}) as Dictionary).get(art_name, {})
	var night: Array = wg["night"]
	var warm := Color(float(night[0]), float(night[1]), float(night[2]))
	img = img.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var glass := PackedByteArray()
	glass.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var g := is_glass(c, wg) if own.is_empty() else _in_boxes(x, y, own["boxes"]) and is_dark_glass(c, own)
			glass[y * w + x] = 1 if c.a > 0.5 and g else 0
	# A pane is a patch: a glass pixel with fewer than two glass neighbours
	# is a highlight on a blue roof or trim, not a window.
	var found := false
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if glass[y * w + x] == 0:
				continue
			if glass[y * w + x - 1] + glass[y * w + x + 1] + glass[(y - 1) * w + x] + glass[(y + 1) * w + x] < 2:
				continue
			out.set_pixel(x, y, warm.lerp(Color.WHITE, clampf(img.get_pixel(x, y).get_luminance() - 0.75, 0.0, 0.25)))
			found = true
	return out if found else null


static func is_glass(c: Color, wg: Dictionary) -> bool:
	return c.get_luminance() >= float(wg["min_light"]) and c.b - c.r >= float(wg["min_blue_over_red"]) and c.b >= c.g - 0.02


static func is_dark_glass(c: Color, own: Dictionary) -> bool:
	var l := c.get_luminance()
	return l >= float(own["min_light"]) and l <= float(own["max_light"]) and c.b - c.r >= float(own["min_blue_over_red"]) and c.b >= c.g - 0.02


static func _in_boxes(x: int, y: int, boxes: Array) -> bool:
	for r: Array in boxes:
		if x >= int(r[0]) and y >= int(r[1]) and x < int(r[0]) + int(r[2]) and y < int(r[1]) + int(r[3]):
			return true
	return false


## The top middle of a person's picture, in this view's pixels, for the name
## shown over them.
func head_of(person: String) -> Vector2:
	var node: Node2D = _people.get(person)
	if node == null:
		return Vector2.ZERO
	return node.position + Vector2(0, -30)
