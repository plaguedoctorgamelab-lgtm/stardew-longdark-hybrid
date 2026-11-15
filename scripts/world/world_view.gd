class_name WorldView
extends Node2D
## Draws the outdoor world. Only chunks near the camera are placed on the tile
## layers; others are removed as the ranger moves, so this works for a world
## hundreds of chunks wide. Edges between ground types are made at start-up
## from the plain ground tiles, so finished ground art gets edges for free.

const TILE := 16
## Which ground spills over its neighbours: higher wins.
const GROUND_ORDER: Array[String] = ["deep_water", "shallows", "trail", "grass", "tall_grass", "forest_floor", "rock"]

var session: GameSession
var ground_layer: TileMapLayer
var edge_layer: TileMapLayer
var sort_root: Node2D
var object_layer: TileMapLayer
var building_sprites: Dictionary = {}   # structure id -> Sprite2D
var loaded: Dictionary = {}   # Vector2i chunk -> true
var max_loads_per_frame: int = 2
var _ground_source: Dictionary = {}   # ground name -> source id
var _edge_source: Dictionary = {}     # ground name -> source id (4x4 atlas of masks)
var _object_source: Dictionary = {}   # object kind -> source id
var _border_lines: Node2D


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
	return ts


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


func _process(_delta: float) -> void:
	if session == null or not visible:
		return
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


## Places wanted chunks and removes unwanted ones. With `all`, loads every
## wanted chunk now (after a teleport); otherwise a few per frame.
func update_chunks(all: bool) -> void:
	var want := wanted_chunks()
	for c: Vector2i in loaded.keys():
		if not want.has(c):
			_unload(c)
	var budget := 1000 if all else max_loads_per_frame
	# Nearest first.
	var center := session.world.chunk_of(session.ranger_tile())
	var todo: Array = want.keys().filter(func(c: Vector2i) -> bool: return not loaded.has(c))
	todo.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - center).length_squared() < (b - center).length_squared())
	for c: Vector2i in todo:
		if budget <= 0:
			break
		_load(c)
		budget -= 1
	session.world.trim_cache(center, 3)


func _ground_index(g: String) -> int:
	return GROUND_ORDER.find(g)


func _load(c: Vector2i) -> void:
	var w := session.world
	var cs := w.chunk_size
	var base := c * cs
	for ly in cs:
		for lx in cs:
			var t := base + Vector2i(lx, ly)
			var g := w.ground_at(t)
			ground_layer.set_cell(t, _ground_source[g], Vector2i.ZERO)
			# The strongest neighbouring ground spills its edge onto this tile.
			var gi := _ground_index(g)
			var best := -1
			var mask := 0
			var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
			for i in 4:
				var n := t + (dirs[i] as Vector2i)
				if not w.in_bounds(n):
					continue
				var ni := _ground_index(w.ground_at(n))
				if ni > gi:
					if ni > best:
						best = ni
						mask = 1 << i
					elif ni == best:
						mask |= 1 << i
			if best >= 0:
				edge_layer.set_cell(t, _edge_source[GROUND_ORDER[best]], Vector2i(mask % 4, mask / 4))
	for o: Array in w.objects_in_chunk(c):
		var kind: String = o[2]
		object_layer.set_cell(base + Vector2i(int(o[0]), int(o[1])), _object_source[kind], Vector2i.ZERO)
	loaded[c] = true


func _unload(c: Vector2i) -> void:
	var cs := session.world.chunk_size
	var base := c * cs
	for ly in cs:
		for lx in cs:
			var t := base + Vector2i(lx, ly)
			ground_layer.erase_cell(t)
			edge_layer.erase_cell(t)
			object_layer.erase_cell(t)
	loaded.erase(c)


func reset_chunks() -> void:
	for c: Vector2i in loaded.keys():
		_unload(c)
	update_chunks(true)


func _draw_borders() -> void:
	var cs := session.world.chunk_size * TILE
	for c: Vector2i in loaded:
		_border_lines.draw_rect(Rect2(Vector2(c * cs), Vector2(cs, cs)), Color(1, 0, 0, 0.8), false, 1.0)
	var t := session.ranger_tile()
	_border_lines.draw_rect(Rect2(Vector2(t * TILE), Vector2(TILE, TILE)), Color(1, 1, 0, 0.9), false, 1.0)
