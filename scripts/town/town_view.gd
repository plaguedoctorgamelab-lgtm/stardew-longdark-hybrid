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
# Phase 4b: the festival's dressing in the square, all festival day.
var _fest_id: String = ""
var _fest_nodes: Array[Node2D] = []
var _animated: Array = []        # [sprite, base picture name, frames]
var _floats: Array = []          # [sprite, colour]
var _moose: Sprite2D = null      # Midsummer's wicker moose
static var _costumes: Dictionary = {}   # "sheet:kind" -> stand-in costume sheet
static var _heads: Dictionary = {}      # sheet -> top row of the head in frame 0


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
	_update_festival()
	for id: String in _people:
		var node: Node2D = _people[id]
		# Someone in a heart event is drawn by the scene instead.
		node.visible = town.shown(id) and not session.life.cast.has(id)
		var suit := node.get_node_or_null("Suit")
		if suit != null:
			(suit as Node2D).visible = session.festivals.in_suit(id)
		_dress(id, node)
		if not node.visible:
			continue
		var p: Dictionary = town.people[id]
		node.position = ((p["pos"] as Vector2) * TILE).round()
		var walking := not (p["path"] as Array).is_empty()
		var frame := int(_time * 6.0) % 4 if walking else 0
		for c: Node in node.get_children():
			if c is Sprite2D and (c as Sprite2D).hframes > 1:
				(c as Sprite2D).frame = int(p["facing"]) * 4 + frame


## The square dressed for today's festival: its tables, stalls, garlands and
## fire, the floating lanterns on the creek at Lantern Night, and the Bigfoot
## suits over the contestants at the Big Foot Supper.
func _update_festival() -> void:
	var f := session.festivals.today()
	var id := str(f.get("id", ""))
	if id != _fest_id:
		_fest_id = id
		for n: Node2D in _fest_nodes:
			n.queue_free()
		_fest_nodes.clear()
		_animated.clear()
		_floats.clear()
		_moose = null
		if id != "":
			for d: Array in f.get("decor", []):
				var art := str(d[0])
				var frames := 0
				while Art.has_picture("%s_%d" % [art, frames]):
					frames += 1
				var first := ("%s_0" % art) if frames > 0 else art
				if not Art.has_picture(first):
					continue
				var spr := _stand(first, Vector2(float(d[1]) + 0.5, float(d[2]) + 1.0))
				spr.z_index = 0
				_fest_nodes.append(spr)
				if art == "fest_wicker_moose":
					_moose = spr
				if frames > 1:
					_animated.append([spr, art, frames])
			var colours := ["red", "orange", "yellow", "green", "blue", "violet"]
			var k := 0
			for p: Array in f.get("floats", []):
				var col: String = colours[k % colours.size()]
				k += 1
				var spr := _stand("fest_lantern_float_%s_0" % col, Vector2(float(p[0]) + 0.5, float(p[1]) + 1.0))
				_fest_nodes.append(spr)
				_floats.append([spr, col])
			for who: Variant in f.get("contestants", []):
				var node: Node2D = _people.get(str(who))
				if node != null and node.get_node_or_null("Suit") == null and Art.has_picture("fest_bigfoot_suit"):
					var suit := Sprite2D.new()
					suit.name = "Suit"
					suit.centered = false
					suit.texture = Art.texture("fest_bigfoot_suit")
					suit.hframes = 4
					suit.vframes = 4
					suit.offset = Vector2(-8, -30)
					suit.visible = false
					node.add_child(suit)
	for a: Array in _animated:
		(a[0] as Sprite2D).texture = Art.texture("%s_%d" % [a[1], int(_time * 6.0) % int(a[2])])
	# Midsummer's moose: standing, then burning once the ranger has given it
	# something, then embers.
	if _moose != null and is_instance_valid(_moose):
		var art := "fest_wicker_moose"
		match session.festivals.moose_stage():
			"burning":
				art = "fest_wicker_moose_burn_%d" % (1 + int(_time * 5.0) % 2)
			"embers":
				art = "fest_wicker_moose_embers"
		if Art.has_picture(art) and _moose.texture != Art.texture(art):
			_moose.texture = Art.texture(art)
			_moose.offset = Vector2(-_moose.texture.get_width() / 2.0, -_moose.texture.get_height())
	# The lanterns float only once the walk has begun, in the festival's hours.
	var lit := session.festivals.on_now() or session.festivals.active != ""
	for e: Array in _floats:
		var spr: Sprite2D = e[0]
		spr.visible = lit
		spr.texture = Art.texture("fest_lantern_float_%s_%d" % [e[1], int(_time * 2.0 + spr.position.x) % 2])


## A townsperson's festival dress: a flower crown at Midsummer, a costume at
## Samhain (Mark's costume sheet when drawn, else a stand-in made from their
## own sheet: a bedsheet ghost or a witch's hat).
func _dress(id: String, node: Node2D) -> void:
	var base := _base_sheet(node)
	if base == null:
		return
	var crown := node.get_node_or_null("Crown") as Sprite2D
	var crowned := session.festivals.crowned()
	if crowned and crown == null and Art.has_picture("fest_flower_crown_small"):
		crown = Sprite2D.new()
		crown.name = "Crown"
		crown.centered = false
		crown.texture = Art.texture("fest_flower_crown_small")
		crown.offset = Vector2(-5.0, base.offset.y + float(head_top(base.texture)) - 2.0)
		node.add_child(crown)
	if crown != null:
		crown.visible = crowned
	var kind := session.festivals.costume_of(id)
	var cos := node.get_node_or_null("Costume") as Sprite2D
	if kind != "" and (cos == null or str(cos.get_meta("kind", "")) != kind):
		var tex := costume_texture(base.texture, kind)
		if tex != null:
			if cos == null:
				cos = Sprite2D.new()
				cos.name = "Costume"
				cos.centered = false
				cos.hframes = 4
				cos.vframes = 4
				node.add_child(cos)
			cos.texture = tex
			cos.offset = base.offset
			cos.set_meta("kind", kind)
	if cos != null:
		cos.visible = kind != "" and str(cos.get_meta("kind", "")) == kind


static func _base_sheet(node: Node2D) -> Sprite2D:
	for c: Node in node.get_children():
		if c is Sprite2D and (c as Sprite2D).hframes == 4 and c.name not in ["Suit", "Costume"]:
			return c as Sprite2D
	return null


static func _image(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	return img


## The top row of a sheet's first frame that has anything drawn on it.
static func head_top(tex: Texture2D) -> int:
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _heads.has(key):
		return int(_heads[key])
	var top := 4
	var img := _image(tex)
	if img != null:
		var fw := img.get_width() / 4
		var fh := img.get_height() / 4
		for y in fh:
			var hit := false
			for x in fw:
				if img.get_pixel(x, y).a > 0.0:
					hit = true
					break
			if hit:
				top = y
				break
	_heads[key] = top
	return top


## A costume sheet for someone: Mark's fest_costume_<kind> when drawn, else
## a stand-in (ghost or witch) shaped to their own sheet, or null.
static func costume_texture(sheet: Texture2D, kind: String) -> Texture2D:
	if Art.has_picture("fest_costume_" + kind):
		return Art.texture("fest_costume_" + kind)
	if not kind in ["ghost", "witch"]:
		return null
	var key := "%s:%s" % [sheet.resource_path if sheet.resource_path != "" else str(sheet.get_instance_id()), kind]
	if _costumes.has(key):
		return _costumes[key]
	var img := _image(sheet)
	if img == null:
		return null
	var w := img.get_width()
	var h := img.get_height()
	var fw := w / 4
	var fh := h / 4
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for fy in 4:
		for fx in 4:
			var x0 := fw
			var x1 := -1
			var y0 := fh
			var y1 := -1
			for y in fh:
				for x in fw:
					if img.get_pixel(fx * fw + x, fy * fh + y).a > 0.0:
						x0 = mini(x0, x)
						x1 = maxi(x1, x)
						y0 = mini(y0, y)
						y1 = maxi(y1, y)
			if x1 < 0:
				continue
			var cx := (x0 + x1 + 1) / 2
			if kind == "ghost":
				_ghost(out, fx * fw, fy * fh, fw, fh, x0, x1, y0, y1, cx, fy)
			else:
				_witch_hat(out, fx * fw, fy * fh, fw, y0, cx)
	var tex := ImageTexture.create_from_image(out)
	_costumes[key] = tex
	return tex


static func _put_px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


## A bedsheet over the whole person, eye holes on the side they face (rows:
## down, right, up, left).
static func _ghost(out: Image, ox: int, oy: int, fw: int, fh: int, x0: int, x1: int, y0: int, y1: int, cx: int, facing: int) -> void:
	var sheet := Color8(244, 244, 238)
	var shade := Color8(208, 212, 226)
	var edge := Color8(96, 96, 120)
	var top := maxi(0, y0 - 1)
	var bottom := mini(fh - 1, y1 - 1)
	var body := maxi(6, (x1 - x0 + 1) / 2 + 1)
	# A round head on a body that flares out to a wavy hem.
	var dome := [3, 4, 5, 6, 6, 6, 6]
	var spans := {}
	for y in range(top, bottom + 1):
		var k := y - top
		var hw: int = dome[k] if k < dome.size() else mini(body, 6 + (k - dome.size()) / 3)
		spans[y] = hw
	for y in range(top, bottom + 1):
		var hw: int = spans[y]
		for x in range(cx - hw, cx + hw):
			if x < 0 or x >= fw:
				continue
			if y == bottom and (x - cx + 64) % 3 == 1:
				continue
			var outer := x == cx - hw or x == cx + hw - 1 or y == top or y == bottom
			if not outer and y > top:
				var above: int = spans[y - 1]
				outer = x < cx - above or x >= cx + above
			var col := sheet
			if outer:
				col = edge
			elif x >= cx + hw - 2 or y >= bottom - 1:
				col = shade
			_put_px(out, ox + x, oy + y, col)
	var eye := Color8(30, 26, 40)
	var ey := top + 3
	match facing:
		0:
			for dy in 2:
				_put_px(out, ox + cx - 2, oy + ey + dy, eye)
				_put_px(out, ox + cx + 1, oy + ey + dy, eye)
		1:
			for dy in 2:
				_put_px(out, ox + cx + 2, oy + ey + dy, eye)
		3:
			for dy in 2:
				_put_px(out, ox + cx - 3, oy + ey + dy, eye)


## A pointed black witch's hat with a purple band, on top of the head.
static func _witch_hat(out: Image, ox: int, oy: int, fw: int, y0: int, cx: int) -> void:
	var hat := Color8(40, 30, 52)
	var band := Color8(126, 70, 170)
	# Pulled down low, so the point stays inside the frame.
	var brim := y0 + 4
	for x in range(cx - 6, cx + 6):
		if x >= 0 and x < fw:
			_put_px(out, ox + x, oy + brim, hat)
	var widths := [8, 6, 4, 3, 2]
	for k in widths.size():
		var wd: int = widths[k]
		var y := brim - 1 - k
		var shift := 1 if k >= 3 else 0
		for x in range(cx - wd / 2 + shift, cx - wd / 2 + wd + shift):
			if x >= 0 and x < fw:
				_put_px(out, ox + x, oy + y, band if k == 0 else hat)


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
