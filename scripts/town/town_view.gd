class_name TownView
extends Node2D
## Draws Humdrum: its ground, buildings, trees, lamps and benches, and its
## people walking their routines. Each person is their own walk sheet if
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
	for b: Dictionary in town.buildings:
		var spr := _stand(str(b["sprite"]), Vector2(float(b["pos"][0]) + float(b["size"][0]) / 2.0, float(b["pos"][1]) + float(b["size"][1])))
		Shadow.attach(spr, float(b["size"][0]) * TILE, session.tuning)
	for o: Dictionary in town.objects:
		var spr := _stand(str(o["sprite"]), Vector2(float(o["pos"][0]) + 0.5, float(o["pos"][1]) + 1.0))
		if not str(o["sprite"]).begins_with("town_streetlamp"):
			Shadow.attach(spr, TILE, session.tuning)
		if bool(o.get("lamp", false)):
			lamps.append(spr.position + Vector2(0, -spr.texture.get_height() + 4))
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


## The town's ground: each code's versions side by side in one atlas, each
## tile picking its version from its position, as in the park.
func _build_ground() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var looks: Dictionary = session.tuning.value("town_look.ground")
	var sources := {}
	var weights := {}
	for code: String in looks:
		var pics: Array = looks[code]["pictures"]
		var strip := Image.create(TILE * pics.size(), TILE, false, Image.FORMAT_RGBA8)
		for i in pics.size():
			var im := Art.image(pics[i])
			im.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(im, Rect2i(0, 0, TILE, TILE), Vector2i(i * TILE, 0))
		var src := TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(strip)
		src.texture_region_size = Vector2i(TILE, TILE)
		for i in pics.size():
			src.create_tile(Vector2i(i, 0))
		sources[code] = ts.add_source(src)
		weights[code] = WorldView._running_total(looks[code]["weights"])
	ground_layer.tile_set = ts
	for y in town.size.y:
		for x in town.size.x:
			var t := Vector2i(x, y)
			var code := town.ground_at(t)
			ground_layer.set_cell(t, sources[code], Vector2i(WorldView.pick(t, weights[code], 0), 0))
	# The park road runs on past the town's east edge, toward the gate.
	for y in range(28, 33):
		for x in range(town.size.x, town.size.x + 12):
			ground_layer.set_cell(Vector2i(x, y), sources["c"], Vector2i(0, 0))


func _make_person(r: Dictionary) -> Node2D:
	var node := Node2D.new()
	sort_root.add_child(node)
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
	if not visible:
		return
	_time += delta
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


## The top middle of a person's picture, in this view's pixels, for the name
## shown over them.
func head_of(person: String) -> Vector2:
	var node: Node2D = _people.get(person)
	if node == null:
		return Vector2.ZERO
	return node.position + Vector2(0, -30)
