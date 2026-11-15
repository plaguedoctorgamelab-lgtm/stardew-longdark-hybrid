class_name WorldView
extends Node2D
## Draws the outdoor world. Only chunks near the camera are placed on the tile
## layers; others are removed as the ranger moves, so this works for a world
## hundreds of chunks wide. Edges between ground types are made at start-up
## from the plain ground tiles, so finished ground art gets edges for free.

const TILE := 16
## Which ground spills over its neighbours: higher wins.
const GROUND_ORDER: Array[String] = ["deep_water", "shallows", "boards", "trail", "bog", "grass", "tall_grass", "forest_floor", "rock"]

var session: GameSession
var ground_layer: TileMapLayer
var edge_layer: TileMapLayer
var sort_root: Node2D
var object_layer: TileMapLayer
var building_sprites: Dictionary = {}   # structure id -> Sprite2D
var loaded: Dictionary = {}   # Vector2i chunk -> true
var _ground_source: Dictionary = {}   # ground name -> source id
var _edge_source: Dictionary = {}     # ground name -> source id (4x4 atlas of masks)
var _object_source: Dictionary = {}   # object kind -> source id
var _border_lines: Node2D
var _stump_source: int = -1
var _camp_bed: Sprite2D
var _camp_fire: Sprite2D
var _time: float = 0.0


func setup(s: GameSession, ranger_node: Node2D) -> void:
	session = s
	var tileset := _build_tileset()
	ground_layer = TileMapLayer.new()
	ground_layer.tile_set = tileset
	ground_layer.z_index = -20
	add_child(ground_layer)
	edge_layer = TileMapLayer.new()
	edge_layer.tile_set = tileset
	edge_layer.z_index = -19
	add_child(edge_layer)
	sort_root = Node2D.new()
	sort_root.y_sort_enabled = true
	add_child(sort_root)
	object_layer = TileMapLayer.new()
	object_layer.tile_set = tileset
	object_layer.y_sort_enabled = true
	sort_root.add_child(object_layer)
	for st: Dictionary in session.world.meta["structures"]:
		var spr := Sprite2D.new()
		spr.centered = false
		var fp := Vector2(float(st["pos"][0]), float(st["pos"][1]))
		var size := Vector2(float(st["size"][0]), float(st["size"][1]))
		spr.position = (fp + Vector2(size.x / 2.0, size.y)) * TILE
		sort_root.add_child(spr)
		building_sprites[st["id"]] = spr
	refresh_buildings()
	session.structures.changed.connect(func(_id: String) -> void: refresh_buildings())
	if ranger_node.get_parent():
		ranger_node.reparent(sort_root)
	else:
		sort_root.add_child(ranger_node)
	_camp_bed = Sprite2D.new()
	_camp_fire = Sprite2D.new()
	for spr in [_camp_bed, _camp_fire]:
		spr.centered = false
		spr.visible = false
		sort_root.add_child(spr)
	session.camp_changed.connect(refresh_camp)
	session.tree_changed.connect(_on_tree_changed)
	refresh_camp()
	_border_lines = Node2D.new()
	_border_lines.z_index = 50
	_border_lines.draw.connect(_draw_borders)
	add_child(_border_lines)


func refresh_buildings() -> void:
	for id: String in building_sprites:
		var row := session.content.row("structures", id)
		var art_name: String = row["sprite_repaired"] if session.structures.is_open(id) else row["sprite"]
		var spr: Sprite2D = building_sprites[id]
		spr.texture = Art.texture(art_name)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	for g: String in session.world.ground_codes.values():
		var src := TileSetAtlasSource.new()
		src.texture = Art.texture("ground_" + g)
		src.texture_region_size = Vector2i(TILE, TILE)
		src.create_tile(Vector2i.ZERO)
		_ground_source[g] = ts.add_source(src)
		var edge := TileSetAtlasSource.new()
		edge.texture = ImageTexture.create_from_image(_edge_atlas(Art.image("ground_" + g)))
		edge.texture_region_size = Vector2i(TILE, TILE)
		for m in 16:
			edge.create_tile(Vector2i(m % 4, m / 4))
		_edge_source[g] = ts.add_source(edge)
	var types: Dictionary = session.world.meta["object_types"]
	for kind: String in types:
		var ot: Dictionary = types[kind]
		var tex := Art.texture(ot["sprite"])
		var src := TileSetAtlasSource.new()
		src.texture = tex
		src.texture_region_size = Vector2i(tex.get_width(), tex.get_height())
		src.create_tile(Vector2i.ZERO)
		var fw := int(ot["size"][0])
		var fh := int(ot["size"][1])
		var td := src.get_tile_data(Vector2i.ZERO, 0)
		# Stand the picture on the bottom middle of its footprint.
		var offset := Vector2i(fw * TILE / 2 - TILE / 2, fh * TILE - TILE / 2 - tex.get_height() / 2)
		td.texture_origin = -offset
		td.y_sort_origin = fh * TILE - TILE / 2
		_object_source[kind] = ts.add_source(src)
	var stump_tex := Art.texture(session.content.row("items", "axe")["stump_sprite"])
	var stump := TileSetAtlasSource.new()
	stump.texture = stump_tex
	stump.texture_region_size = Vector2i(stump_tex.get_width(), stump_tex.get_height())
	stump.create_tile(Vector2i.ZERO)
	var sd := stump.get_tile_data(Vector2i.ZERO, 0)
	sd.texture_origin = -Vector2i(0, TILE - TILE / 2 - stump_tex.get_height() / 2)
	sd.y_sort_origin = TILE / 2
	_stump_source = ts.add_source(stump)
	return ts


func _camp_sprite(key: String) -> Texture2D:
	return Art.texture(session.content.row("items", "bedroll")["camp_sprites"][key])


## Shows the camp's bedroll and fire, if there is a camp.
func refresh_camp() -> void:
	var has := not session.camp.is_empty()
	_camp_bed.visible = has
	_camp_fire.visible = has
	if not has:
		return
	_camp_bed.texture = _camp_sprite("bed")
	_camp_fire.texture = _camp_sprite("fire" if session.campfire_lit() else "fire_out")
	for pair in [[_camp_bed, session.camp["bed"]], [_camp_fire, session.camp["fire"]]]:
		var spr: Sprite2D = pair[0]
		var t: Vector2i = pair[1]
		spr.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())


func _on_tree_changed(t: Vector2i) -> void:
	if not loaded.has(session.world.chunk_of(t)):
		return
	var kind := session.world.object_at(t)
	if kind == "":
		return
	if session.chopped.has(t):
		object_layer.set_cell(t, _stump_source, Vector2i.ZERO)
	else:
		object_layer.set_cell(t, _object_source[kind], Vector2i.ZERO)


## A 4x4 atlas: tile m holds the ground's fringe on the sides set in m
## (1 = north, 2 = east, 4 = south, 8 = west), clear elsewhere.
static func _edge_atlas(src: Image) -> Image:
	src = src.duplicate()
	src.convert(Image.FORMAT_RGBA8)
	var out := Image.create(TILE * 4, TILE * 4, false, Image.FORMAT_RGBA8)
	for m in 16:
		var ox := (m % 4) * TILE
		var oy := (m / 4) * TILE
		for y in TILE:
			for x in TILE:
				var depth := 99
				if m & 1:
					depth = mini(depth, y)
				if m & 2:
					depth = mini(depth, TILE - 1 - x)
				if m & 4:
					depth = mini(depth, TILE - 1 - y)
				if m & 8:
					depth = mini(depth, x)
				var keep := depth < 2 or (depth == 2 and (x + y) % 2 == 0) or (depth == 3 and (x * 3 + y) % 4 == 0)
				if keep:
					out.set_pixel(ox + x, oy + y, src.get_pixel(x, y))
	return out


func _process(delta: float) -> void:
	if session == null or not visible:
		return
	_time += delta
	if _camp_fire.visible and session.campfire_lit():
		_camp_fire.modulate = Color(1.0, 0.85 + 0.15 * sin(_time * 11.0), 0.8 + 0.2 * sin(_time * 7.0))
	else:
		_camp_fire.modulate = Color.WHITE
	update_chunks(false)
	_border_lines.visible = session.debug_overlay
	if session.debug_overlay:
		_border_lines.queue_redraw()


func wanted_chunks() -> Dictionary:
	var w := session.world
	var cs := w.chunk_size
	var vp := Vector2(480, 270) / TILE
	var margin := session.tuning.num("world.load_margin_tiles")
	var c := session.outdoor_pos
	var x0 := floori((c.x - vp.x / 2.0 - margin) / cs)
	var x1 := floori((c.x + vp.x / 2.0 + margin) / cs)
	var y0 := floori((c.y - vp.y / 2.0 - margin) / cs)
	var y1 := floori((c.y + vp.y / 2.0 + margin) / cs)
	var out := {}
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var cc := Vector2i(cx, cy)
			if w.has_chunk_file(cc):
				out[cc] = true
	return out


## Places wanted chunks and removes unwanted ones. Work is split into rows of
## tiles and spread over frames, so no frame does too much. With `all`, every
## job is finished now (after a teleport).
func update_chunks(all: bool) -> void:
	var want := wanted_chunks()
	var center := session.world.chunk_of(session.ranger_tile())
	# Cancel or queue removals.
	for c: Vector2i in loaded.keys():
		if not want.has(c) and not _queued.has(c):
			_queue(c, false)
	for c: Vector2i in _queued.keys():
		var job: Dictionary = _queued[c]
		if job["load"] and not want.has(c):
			# Not needed any more: unload whatever rows were placed.
			job["load"] = false
			job["rows_done_load"] = job["row"]
			job["row"] = 0
	var todo: Array = want.keys().filter(func(c: Vector2i) -> bool: return not loaded.has(c) and not _queued.has(c))
	todo.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - center).length_squared() < (b - center).length_squared())
	for c: Vector2i in todo:
		_queue(c, true)
	var budget := 1 << 30 if all else rows_per_frame
	while budget > 0 and not _order.is_empty():
		var c: Vector2i = _order[0]
		var job: Dictionary = _queued[c]
		var n := mini(budget, session.world.chunk_size - int(job["row"]))
		if job["load"]:
			_load_rows(c, int(job["row"]), n)
		else:
			_unload_rows(c, int(job["row"]), n)
		job["row"] = int(job["row"]) + n
		budget -= n
		if int(job["row"]) >= session.world.chunk_size:
			if job["load"]:
				loaded[c] = true
			else:
				loaded.erase(c)
			_queued.erase(c)
			_order.pop_front()
	session.world.trim_cache(center, 3)


var rows_per_frame: int = 8
var _queued: Dictionary = {}   # chunk -> {"load": bool, "row": int}
var _order: Array = []


func _queue(c: Vector2i, load_it: bool) -> void:
	_queued[c] = {"load": load_it, "row": 0}
	if load_it:
		_order.append(c)
	else:
		_order.push_front(c)


func is_busy() -> bool:
	return not _order.is_empty()


func _ground_index(g: String) -> int:
	return GROUND_ORDER.find(g)


func _load_rows(c: Vector2i, row0: int, count: int) -> void:
	var w := session.world
	var cs := w.chunk_size
	var base := c * cs
	var codes := w.ground_codes
	var order := {}
	for g: String in codes.values():
		order[g] = _ground_index(g)
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for ly in range(row0, row0 + count):
		for lx in cs:
			var t := base + Vector2i(lx, ly)
			var g := w.ground_at(t)
			ground_layer.set_cell(t, _ground_source[g], Vector2i.ZERO)
			# The strongest neighbouring ground spills its edge onto this tile.
			var gi: int = order[g]
			var best := -1
			var mask := 0
			for i in 4:
				var n := t + dirs[i]
				if not w.in_bounds(n):
					continue
				var ni: int = order[w.ground_at(n)]
				if ni > gi:
					if ni > best:
						best = ni
						mask = 1 << i
					elif ni == best:
						mask |= 1 << i
			if best >= 0:
				edge_layer.set_cell(t, _edge_source[GROUND_ORDER[best]], Vector2i(mask % 4, mask / 4))
	for o: Array in w.objects_in_chunk(c):
		var oy := int(o[1])
		if oy >= row0 and oy < row0 + count:
			var ot := base + Vector2i(int(o[0]), oy)
			var src: int = _stump_source if session.chopped.has(ot) else _object_source[str(o[2])]
			object_layer.set_cell(ot, src, Vector2i.ZERO)


func _unload_rows(c: Vector2i, row0: int, count: int) -> void:
	var cs := session.world.chunk_size
	var base := c * cs
	for ly in range(row0, row0 + count):
		for lx in cs:
			var t := base + Vector2i(lx, ly)
			ground_layer.erase_cell(t)
			edge_layer.erase_cell(t)
			object_layer.erase_cell(t)


func reset_chunks() -> void:
	update_chunks(true)


func _draw_borders() -> void:
	var cs := session.world.chunk_size * TILE
	for c: Vector2i in loaded:
		_border_lines.draw_rect(Rect2(Vector2(c * cs), Vector2(cs, cs)), Color(1, 0, 0, 0.8), false, 1.0)
	var t := session.ranger_tile()
	_border_lines.draw_rect(Rect2(Vector2(t * TILE), Vector2(TILE, TILE)), Color(1, 1, 0, 0.9), false, 1.0)
