class_name WorldView
extends Node2D
## Draws the outdoor world. Only chunks near the camera are placed on the tile
## layers; others are removed as the ranger moves, so this works for a world
## hundreds of chunks wide. Edges between ground types are made at start-up
## from the plain ground tiles, so finished ground art gets edges for free.

const TILE := 16
## Which ground spills over its neighbours: higher wins.
const GROUND_ORDER: Array[String] = ["deep_water", "shallows", "boards", "trail", "dug_earth", "bog", "grass", "tall_grass", "forest_floor", "rock"]

var session: GameSession
var ground_layer: TileMapLayer
var edge_layer: TileMapLayer
var sort_root: Node2D
var object_layer: TileMapLayer
var building_sprites: Dictionary = {}   # structure id -> Sprite2D
var garden_view: GardenView
var loaded: Dictionary = {}   # Vector2i chunk -> true
var _ground_source: Dictionary = {}   # ground name -> source id
var _edge_source: Dictionary = {}     # ground name -> source id (4x4 atlas of masks)
var _object_source: Dictionary = {}   # object kind -> Array of source ids, one per version
var _object_weights: Dictionary = {}  # object kind -> running total of its versions' weights
var _ground_weights: Dictionary = {}  # ground name -> running total of its versions' weights
var _ground_details: Dictionary = {}  # ground name -> {"coords": [atlas coords], "chance": float}
var _ground_frames: Dictionary = {}   # ground name -> frames per version (water moves)
var _shore_source: int = -1           # the shore where water meets land: 16 masks in a row, frames beside each
var _shore_frames: int = 1
var _detail_source: int = -1
var detail_layer: TileMapLayer
var shadow_layer: TileMapLayer
var forage_sprites: Dictionary = {}   # key -> Sprite2D: forage, fruit on bushes, sparkles
var _forage_wait: float = 0.0
var _shadow_source: Dictionary = {}   # object kind -> source id of its ground shadow
var _border_lines: Node2D
var _stump_source: int = -1
var _camp_bed: Sprite2D
var _placed_sprites: Dictionary = {}   # tile -> Sprite2D
var _berry: Sprite2D
var _ripple: Node2D
var _camp_fire: Sprite2D
var _time: float = 0.0
var park_view: ParkView
var _pile_sprites: Array[Sprite2D] = []
var polish: Polish
var _ranger: Node2D


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
	detail_layer = TileMapLayer.new()
	detail_layer.tile_set = tileset
	detail_layer.z_index = -18
	add_child(detail_layer)
	shadow_layer = TileMapLayer.new()
	shadow_layer.tile_set = tileset
	shadow_layer.z_index = Shadow.Z
	add_child(shadow_layer)
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
		Shadow.attach(spr, size.x * TILE, session.tuning)
		building_sprites[st["id"]] = spr
	refresh_buildings()
	session.structures.changed.connect(func(_id: String) -> void: refresh_buildings())
	# The garden behind the station (Phase 4b).
	garden_view = GardenView.new()
	add_child(garden_view)
	garden_view.setup(session, sort_root)
	if ranger_node.get_parent():
		ranger_node.reparent(sort_root)
	else:
		sort_root.add_child(ranger_node)
	if not ranger_node.has_node("Shadow"):
		Shadow.attach(ranger_node, TILE, session.tuning)
	_camp_bed = Sprite2D.new()
	_camp_fire = Sprite2D.new()
	for spr in [_camp_bed, _camp_fire]:
		spr.centered = false
		spr.visible = false
		sort_root.add_child(spr)
	Shadow.attach(_camp_fire, TILE, session.tuning)
	session.camp_changed.connect(refresh_camp)
	session.tree_changed.connect(_on_tree_changed)
	session.land_changed.connect(_on_land_changed)
	refresh_camp()
	_berry = Sprite2D.new()
	_berry.centered = false
	_berry.texture = Art.texture("obj_berry_bush")
	sort_root.add_child(_berry)
	Shadow.attach(_berry, TILE, session.tuning)
	_ripple = Node2D.new()
	_ripple.z_index = -18
	_ripple.draw.connect(_draw_ripple)
	add_child(_ripple)
	session.day_began.connect(refresh_berry)
	refresh_berry()
	session.forage.changed.connect(_forage_changed)
	session.day_began.connect(_forage_changed)
	park_view = ParkView.new()
	add_child(park_view)
	park_view.setup(session, sort_root)
	session.piles_changed.connect(refresh_piles)
	refresh_piles()
	session.jobs.spots_changed.connect(refresh_job_spots)
	session.day_began.connect(refresh_job_spots)
	refresh_job_spots()
	_job_marks = Node2D.new()
	_job_marks.z_index = 45
	_job_marks.draw.connect(_draw_job_marks)
	add_child(_job_marks)
	_border_lines = Node2D.new()
	_border_lines.z_index = 50
	_border_lines.draw.connect(_draw_borders)
	add_child(_border_lines)
	_ranger = ranger_node
	polish = Polish.new()
	add_child(polish)
	polish.setup(session, self)


var _spot_sprites: Array[Sprite2D] = []


## The small things jobs ask about outdoors: a branch on the trail, a marker
## by the gate, snags in a gap. Each stands on its tiles, its foot at the
## bottom, and goes once it is done (or shows its after picture).
func refresh_job_spots() -> void:
	for spr in _spot_sprites:
		spr.queue_free()
	_spot_sprites.clear()
	var jb := session.jobs
	for id: String in jb.spot_ids():
		var r := jb.spot_row(id)
		if str(r["where"]) != "outdoor" or not jb.spot_shown(id):
			continue
		var art := jb.spot_sprite(id)
		if art == "":
			continue
		var spr := Sprite2D.new()
		spr.texture = Art.texture(art)
		spr.centered = false
		var p := jb.spot_pos(id)
		spr.position = Vector2(p.x, floorf(p.y) + 1.0) * TILE
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
		sort_root.add_child(spr)
		Shadow.attach(spr, float(r["size"][0]) * TILE, session.tuning)
		_spot_sprites.append(spr)


## Things the ranger dropped: the first item's picture, small, on the ground.
func refresh_piles() -> void:
	for spr in _pile_sprites:
		spr.queue_free()
	_pile_sprites.clear()
	for t: Vector2i in session.piles:
		var inv: Inventory = session.piles[t]
		var item := ""
		for i in inv.size():
			if inv.item_at(i) != "":
				item = inv.item_at(i)
				break
		if item == "":
			continue
		var spr := Sprite2D.new()
		spr.texture = Art.texture(session.content.row("items", item)["icon"])
		spr.scale = Vector2(0.5, 0.5)
		spr.position = (Vector2(t) + Vector2(0.5, 0.6)) * TILE
		sort_root.add_child(spr)
		_pile_sprites.append(spr)


func refresh_buildings() -> void:
	for id: String in building_sprites:
		var row := session.content.row("structures", id)
		var art_name: String = row["sprite_repaired"] if session.structures.is_open(id) else row["sprite"]
		if id == Home.STATION:
			art_name = session.home.station_sprite()
		var spr: Sprite2D = building_sprites[id]
		spr.texture = Art.texture(art_name)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
		# The station's second room is added on the right: its door stays put.
		if id == Home.STATION:
			var fw := float(session.world.structure_placement(id)["size"][0]) * TILE
			spr.offset.x = -fw / 2.0
			# Scaffolding while Gus's crew is at work (Art Request 23).
			var sc := spr.get_node_or_null("Scaffold") as Sprite2D
			if sc == null and Art.has_picture("building_station_scaffold"):
				sc = Sprite2D.new()
				sc.name = "Scaffold"
				sc.centered = false
				sc.texture = Art.texture("building_station_scaffold")
				spr.add_child(sc)
			if sc != null:
				sc.offset = Vector2(-fw / 2.0, -sc.texture.get_height())
				sc.visible = session.home.building != ""


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var details := {}   # detail picture -> atlas coords
	for r: Dictionary in session.content.rows("art_variety"):
		for d: String in r.get("details", []):
			if not details.has(d):
				details[d] = Vector2i(details.size(), 0)
	if not details.is_empty():
		var dstrip := Image.create(TILE * details.size(), TILE, false, Image.FORMAT_RGBA8)
		for d: String in details:
			var im := Art.image(d)
			im.convert(Image.FORMAT_RGBA8)
			dstrip.blit_rect(im, Rect2i(0, 0, mini(im.get_width(), TILE), mini(im.get_height(), TILE)), Vector2i((details[d] as Vector2i).x * TILE, 0))
		var dsrc := TileSetAtlasSource.new()
		dsrc.texture = ImageTexture.create_from_image(dstrip)
		dsrc.texture_region_size = Vector2i(TILE, TILE)
		for d: String in details:
			dsrc.create_tile(details[d])
		_detail_source = ts.add_source(dsrc)
	var water: Dictionary = session.tuning.value("look.water")
	var grounds: Array = session.world.ground_codes.values()
	# Ground the park can make at run time: a troll badger's diggings.
	grounds.append("dug_earth")
	for g: String in grounds:
		var look := _variety("ground_" + g)
		var pics: Array = look["pictures"]
		# Water moves: each version has its frames beside it.
		var sway: Array = water["sway"] if g in (water["grounds"] as Array) else [0]
		var nf := sway.size()
		_ground_frames[g] = nf
		# Every version of a ground sits side by side in one strip.
		var strip := Image.create(TILE * pics.size() * nf, TILE, false, Image.FORMAT_RGBA8)
		for i in pics.size():
			var im := Art.image(pics[i])
			im.convert(Image.FORMAT_RGBA8)
			for f in nf:
				var fr := im if nf == 1 else _water_frame(im, int(sway[f]), i * 16 + f, int(water["glints"]), water["glint_color"][g])
				strip.blit_rect(fr, Rect2i(0, 0, TILE, TILE), Vector2i((i * nf + f) * TILE, 0))
		var src := TileSetAtlasSource.new()
		src.texture = ImageTexture.create_from_image(strip)
		src.texture_region_size = Vector2i(TILE, TILE)
		for i in pics.size():
			var at := Vector2i(i * nf, 0)
			src.create_tile(at)
			if nf > 1:
				_animate(src, at, nf, float(water["frame_seconds"]))
		_ground_source[g] = ts.add_source(src)
		_ground_weights[g] = _running_total(look["weights"])
		if look.has("details"):
			var coords: Array[Vector2i] = []
			for d: String in look["details"]:
				coords.append(details[d])
			_ground_details[g] = {"coords": coords, "chance": float(look["detail_chance"])}
		var edge := TileSetAtlasSource.new()
		# A drawn edge sheet (edge_<ground>, laid out like _edge_atlas) wins
		# over the edge cut from the plain tile.
		if Art.has_picture("edge_" + g):
			edge.texture = Art.texture("edge_" + g)
		else:
			edge.texture = ImageTexture.create_from_image(_edge_atlas(Art.image("ground_" + g)))
		edge.texture_region_size = Vector2i(TILE, TILE)
		for m in 16:
			edge.create_tile(Vector2i(m % 4, m / 4))
		_edge_source[g] = ts.add_source(edge)
	_shore_frames = int(water["shore_frames"])
	var shore := TileSetAtlasSource.new()
	shore.texture = ImageTexture.create_from_image(_shore_atlas(water))
	shore.texture_region_size = Vector2i(TILE, TILE)
	for m in 16:
		var at := Vector2i(m * _shore_frames, 0)
		shore.create_tile(at)
		if _shore_frames > 1:
			_animate(shore, at, _shore_frames, float(water["shore_seconds"]))
	_shore_source = ts.add_source(shore)
	var types: Dictionary = session.world.meta["object_types"]
	for kind: String in types:
		var ot: Dictionary = types[kind]
		var look := _variety(ot["sprite"])
		var sources: Array[int] = []
		for pic: String in look["pictures"]:
			var tex := Art.texture(pic)
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
			sources.append(ts.add_source(src))
		_object_source[kind] = sources
		if not kind in (session.tuning.value("look.no_shadow") as Array):
			var fw := int(ot["size"][0])
			var fh := int(ot["size"][1])
			var stex := Shadow.texture(Art.texture(look["pictures"][0]).get_width(), session.tuning)
			var ssrc := TileSetAtlasSource.new()
			ssrc.texture = stex
			ssrc.texture_region_size = Vector2i(stex.get_width(), stex.get_height())
			ssrc.create_tile(Vector2i.ZERO)
			# Centre the oval on the bottom middle of the footprint.
			ssrc.get_tile_data(Vector2i.ZERO, 0).texture_origin = -Vector2i(fw * TILE / 2 - TILE / 2, fh * TILE - TILE / 2 - 2)
			_shadow_source[kind] = ts.add_source(ssrc)
		_object_weights[kind] = _running_total(look["weights"])
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
	_draw_object(t)


## Redraws a tile whose ground or obstacle changed, and its neighbours' edges.
func _on_land_changed(t: Vector2i) -> void:
	if not loaded.has(session.world.chunk_of(t)) and not _queued.has(session.world.chunk_of(t)):
		return
	for d: Vector2i in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		_draw_ground(t + d)
	_draw_object(t)
	_draw_placed(t)


func _draw_placed(t: Vector2i) -> void:
	if _placed_sprites.has(t):
		(_placed_sprites[t] as Node).queue_free()
		_placed_sprites.erase(t)
	if not session.placed.has(t):
		return
	var item: String = session.placed[t]["item"]
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(session.content.row("items", item)["sprite"])
	spr.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE)
	spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	sort_root.add_child(spr)
	Shadow.attach(spr, TILE, session.tuning)
	_placed_sprites[t] = spr


## The picture an object shows on tile t (the standing tree, with
## `standing`, even once it is chopped), or null if there is none.
func object_texture(t: Vector2i, standing: bool = false) -> Texture2D:
	var kind := session.world.object_at(t)
	if kind == "" or not _object_source.has(kind):
		return null
	if session.chopped.has(t) and not standing:
		return Art.texture(session.content.row("items", "axe")["stump_sprite"])
	var src_id: int = (_object_source[kind] as Array)[pick(t, _object_weights[kind], 1)]
	var src := object_layer.tile_set.get_source(src_id) as TileSetAtlasSource
	return src.texture


## Draws tile t's object again (after a jolt hid it a moment).
func redraw_object(t: Vector2i) -> void:
	_draw_object(t)


## Large things the ranger walks behind (the buildings) fade so the ranger
## is never lost from view (Graphics Polish, depth sorting).
func _fade_buildings(delta: float) -> void:
	if _ranger == null:
		return
	var p := _ranger.position
	var amount := float(session.tuning.value("look.polish.fade_alpha"))
	var speed := delta / maxf(0.01, float(session.tuning.value("look.polish.fade_seconds")))
	for id: String in building_sprites:
		var spr: Sprite2D = building_sprites[id]
		if spr.texture == null:
			continue
		var r := Rect2(spr.position + spr.offset, spr.texture.get_size())
		var behind := r.has_point(p + Vector2(0, -8)) and p.y < spr.position.y
		var goal := amount if behind else 1.0
		spr.modulate.a = move_toward(spr.modulate.a, goal, speed)


func _draw_object(t: Vector2i) -> void:
	var kind := session.world.object_at(t)
	if kind == "":
		return
	if session.cleared.has(t) or session.seasonal_hidden.has(t):
		object_layer.erase_cell(t)
		shadow_layer.erase_cell(t)
	elif session.chopped.has(t):
		object_layer.set_cell(t, _stump_source, Vector2i.ZERO)
		shadow_layer.erase_cell(t)
	else:
		var sources: Array = _object_source[kind]
		object_layer.set_cell(t, sources[pick(t, _object_weights[kind], 1)], Vector2i.ZERO)
		if _shadow_source.has(kind):
			shadow_layer.set_cell(t, _shadow_source[kind], Vector2i.ZERO)


const _DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]


## Draws one tile's ground, with the strongest neighbouring ground spilling
## its edge onto it.
func _draw_ground(t: Vector2i) -> void:
	var w := session.world
	if not w.in_bounds(t):
		return
	var g := w.ground_at(t)
	ground_layer.set_cell(t, _ground_source[g], Vector2i(pick(t, _ground_weights[g], 0) * int(_ground_frames.get(g, 1)), 0))
	_draw_detail(t)
	var gi := _ground_index(g)
	var best := -1
	var mask := 0
	for i in 4:
		var n := t + _DIRS[i]
		if not w.in_bounds(n):
			continue
		var ni := _ground_index(w.ground_at(n))
		if ni > gi:
			if ni > best:
				best = ni
				mask = 1 << i
			elif ni == best:
				mask |= 1 << i
	var water: Dictionary = session.tuning.value("look.water")
	if best >= 0 and g in (water["grounds"] as Array) and GROUND_ORDER[best] in (water["shore_from"] as Array):
		edge_layer.set_cell(t, _shore_source, Vector2i(mask * _shore_frames, 0))
	elif best >= 0:
		edge_layer.set_cell(t, _edge_source[GROUND_ORDER[best]], Vector2i(mask % 4, mask / 4))
	else:
		edge_layer.erase_cell(t)


## The look of one picture: its versions and their weights, and for a
## ground the small details scattered on it. A picture with no row has one
## version.
func _variety(art_name: String) -> Dictionary:
	if session.content.has("art_variety", art_name):
		return session.content.row("art_variety", art_name)
	return {"pictures": [art_name], "weights": [1]}


static func _running_total(weights: Array) -> Array[int]:
	var out: Array[int] = []
	var sum := 0
	for v: Variant in weights:
		sum += int(v)
		out.append(sum)
	return out


## A number from 0 to 9999 fixed by the tile and the purpose (salt), so a
## tile always looks the same, in every save and every visit.
static func tile_roll(t: Vector2i, salt: int) -> int:
	var h := (t.x * 73856093) ^ (t.y * 19349663) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return absi(h) % 10000


## Which version a tile shows, given the running total of the weights.
static func pick(t: Vector2i, totals: Array, salt: int) -> int:
	if totals.size() < 2:
		return 0
	var r := tile_roll(t, salt) % int(totals[-1])
	for i in totals.size():
		if r < int(totals[i]):
			return i
	return totals.size() - 1


## A small detail on some open tiles of grounds that have them. Never under
## an object or a placed sign, so it never hides something that matters.
func _draw_detail(t: Vector2i) -> void:
	var w := session.world
	var look: Dictionary = _ground_details.get(w.ground_at(t), {})
	if look.is_empty() or w.object_at(t) != "" or session.placed.has(t) or tile_roll(t, 2) >= int(float(look["chance"]) * 10000.0):
		detail_layer.erase_cell(t)
		return
	var coords: Array = look["coords"]
	detail_layer.set_cell(t, _detail_source, coords[tile_roll(t, 3) % coords.size()])


## Frames of a tile set to play in turn, each tile starting at its own
## moment so the water doesn't pulse all at once.
static func _animate(src: TileSetAtlasSource, at: Vector2i, frames: int, seconds: float) -> void:
	src.set_tile_animation_frames_count(at, frames)
	for f in frames:
		src.set_tile_animation_frame_duration(at, f, seconds)
	src.set_tile_animation_mode(at, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)


## One frame of open water: the tile's ripple marks swayed sideways by
## `shift` pixels (wrapping), and a few short glints placed by `seed`.
static func _water_frame(src: Image, shift: int, seed: int, glints: int, glint: Array) -> Image:
	var counts := {}
	for y in TILE:
		for x in TILE:
			var c := src.get_pixel(x, y)
			counts[c] = int(counts.get(c, 0)) + 1
	var base: Color = counts.keys()[0]
	for c: Color in counts:
		if int(counts[c]) > int(counts[base]):
			base = c
	var out := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	out.fill(base)
	for y in TILE:
		for x in TILE:
			var c := src.get_pixel(x, y)
			if c != base:
				out.set_pixel(posmod(x + shift, TILE), y, c)
	var gc := Color8(int(glint[0]), int(glint[1]), int(glint[2]))
	for k in glints:
		var r := tile_roll(Vector2i(seed, k), 11)
		var gx := r % TILE
		var gy := (r / TILE) % TILE
		out.set_pixel(gx, gy, gc)
		out.set_pixel((gx + 1) % TILE, gy, gc)
	return out


## The shore, laid on a water tile beside land: on the sides set in mask m
## (1 = north, 2 = east, 4 = south, 8 = west) a wet-sand rim, then a foam
## line, both a little wavy. Each mask has its frames beside it, the foam
## lapping in and out by a pixel.
static func _shore_atlas(water: Dictionary) -> Image:
	var frames := int(water["shore_frames"])
	var sand := Color8(int(water["shore_sand"][0]), int(water["shore_sand"][1]), int(water["shore_sand"][2]))
	var foam := Color8(int(water["shore_foam"][0]), int(water["shore_foam"][1]), int(water["shore_foam"][2]))
	var out := Image.create(TILE * 16 * frames, TILE, false, Image.FORMAT_RGBA8)
	for m in 16:
		for f in frames:
			var ox := (m * frames + f) * TILE
			for y in TILE:
				for x in TILE:
					var depth := 99
					# Depth from each land side, nudged by a wave along it.
					if m & 1:
						depth = mini(depth, y - _wave(x))
					if m & 2:
						depth = mini(depth, TILE - 1 - x - _wave(y))
					if m & 4:
						depth = mini(depth, TILE - 1 - y - _wave(x + 5))
					if m & 8:
						depth = mini(depth, x - _wave(y + 5))
					var c := Color(0, 0, 0, 0)
					if depth <= 1:
						c = sand
					elif depth == 2 + f:
						c = foam
					elif depth == 3 + f and (x + y) % 2 == 0:
						c = foam
					if c.a > 0.0:
						out.set_pixel(ox + x, y, c)
	return out


## A gentle wave along a shore: 0 or 1, in runs of three or four pixels.
static func _wave(p: int) -> int:
	return 1 if posmod(p, 7) < 3 else 0


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


## This save's berry patch, drawn where the save's seed put it.
func refresh_berry() -> void:
	var t := session.berry_spot()
	_berry.visible = t.x >= 0
	if t.x >= 0:
		_berry.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE)
		_berry.offset = Vector2(-_berry.texture.get_width() / 2.0, -_berry.texture.get_height())


func _draw_ripple() -> void:
	if not session.content.has("spoiler_finds", "dawn_ripple") or not session.find_moment_now("dawn_ripple"):
		return
	var w: Dictionary = session.content.row("spoiler_finds", "dawn_ripple")["when"]
	var c := session.world.landmark_pos(w["landmark"]) * TILE
	var span := float(int(w["to"]) - int(w["from"]))
	var k := clampf(float(session.clock.minute - int(w["from"])) / span, 0.0, 1.0)
	_ripple.draw_arc(c, 8.0 + k * 300.0, 0.0, TAU, 64, Color(1, 1, 1, 0.5 * (1.0 - k)), 1.0)


func _process(delta: float) -> void:
	if session == null or not visible:
		return
	_time += delta
	_ripple.queue_redraw()
	_fade_buildings(delta)
	if _camp_fire.visible and session.campfire_lit():
		_camp_fire.modulate = Color(1.0, 0.85 + 0.15 * sin(_time * 11.0), 0.8 + 0.2 * sin(_time * 7.0))
	else:
		_camp_fire.modulate = Color.WHITE
	update_chunks(false)
	# Forage comes and goes with the hour and the weather, and sparkles with
	# the lantern, so it is looked at a few times a second.
	_forage_wait -= delta
	if _forage_wait <= 0.0:
		_forage_wait = 0.25
		refresh_forage()
		_marks = session.jobs.clear_marks() if not session.is_indoors() else []
	_job_marks.queue_redraw()
	for key: String in forage_sprites:
		if key.begins_with("s"):
			(forage_sprites[key] as Sprite2D).modulate.a = 0.45 + 0.4 * sin(_time * 5.0 + float(posmod(key.hash(), 7)))
	_border_lines.visible = session.debug_overlay
	if session.debug_overlay:
		_border_lines.queue_redraw()


var _job_marks: Node2D
var _marks: Array = []


## A small bobbing gold arrow over each thing an active job
## still wants cleared.
func _draw_job_marks() -> void:
	var t := session.tuning
	var sz := t.num("look.job_marks.size_px")
	var bob := t.num("look.job_marks.bob_px") * sin(_time * t.num("look.job_marks.bob_speed")) if Settings.flag("motion") else 0.0
	var ink := Color(0.1, 0.08, 0.12)
	var c: Array = t.value("look.job_marks.color")
	var fill := Color8(int(c[0]), int(c[1]), int(c[2]))
	for m: Dictionary in _marks:
		var p: Vector2 = m["pos"] * TILE - Vector2(0, t.num("look.job_marks.lift_px") + bob)
		var pts := PackedVector2Array([p + Vector2(-sz, -sz), p + Vector2(sz, -sz), p])
		_job_marks.draw_colored_polygon(pts, ink)
		var inner := PackedVector2Array([p + Vector2(-sz + 2.0, -sz + 1.25), p + Vector2(sz - 2.0, -sz + 1.25), p + Vector2(0, -2.5)])
		_job_marks.draw_colored_polygon(inner, fill)


var _overlay_cache: Dictionary = {}   # chunk -> tiles of objects that show fruit (bushes)


## The tiles in a chunk holding an object that can show fruit, found once.
func _overlay_tiles(c: Vector2i) -> Array:
	if not _overlay_cache.has(c):
		var kinds := {}
		for r: Dictionary in session.content.rows("forage"):
			if r.has("overlay"):
				for k: String in r["objects"]:
					kinds[k] = true
		var out := []
		for o: Array in session.world.objects_in_chunk(c):
			if kinds.has(str(o[2])):
				out.append(c * session.world.chunk_size + Vector2i(int(o[0]), int(o[1])))
		_overlay_cache[c] = out
	return _overlay_cache[c]


var _chunk_forage: Dictionary = {}    # chunk -> {key: [tile, picture, lift]}: today's ground forage and fruit
var _forage_day: int = -1


## A chunk's ground forage and fruit on bushes: they change only from day to
## day, or when something is picked, so they are worked out once.
func _daily_forage(c: Vector2i) -> Dictionary:
	var out := {}
	for t: Vector2i in session.forage.by_chunk.get(c, []):
		if session.forage_showing(t):
			out["f%d,%d" % [t.x, t.y]] = [t, session.content.row("forage", session.forage.spots[t])["sprite"], 0.0]
	for ot: Vector2i in _overlay_tiles(c):
		var r := session.object_forage_ready(ot)
		if r.has("overlay"):
			out["o%d,%d" % [ot.x, ot.y]] = [ot, r["overlay"], 0.5]
	return out


func _forage_changed() -> void:
	_chunk_forage.clear()
	refresh_forage()


## Shows the forage in the loaded chunks: ground forage and magical
## ingredients that are there now, fruit on bushes, and the glowcap lantern's
## sparkles. Sprites are made and freed as they come and go.
func refresh_forage() -> void:
	var want := {}
	if session != null and not session.is_indoors():
		var w := session.world
		var today := session.clock.absolute_day()
		if today != _forage_day:
			_chunk_forage.clear()
			_forage_day = today
		for c: Vector2i in loaded:
			if not _chunk_forage.has(c):
				_chunk_forage[c] = _daily_forage(c)
			var got: Dictionary = _chunk_forage[c]
			for key: String in got:
				want[key] = got[key]
		for t: Vector2i in session.forage.magic_used:
			if loaded.has(w.chunk_of(t)) and session.forage_showing(t):
				want["f%d,%d" % [t.x, t.y]] = [t, session.content.row("forage", session.forage.magic_at(t))["sprite"], 0.0]
		for t: Vector2i in session.sparkle_tiles():
			want["s%d,%d" % [t.x, t.y]] = [t, "fx_sparkle", 1.0]
	for key: String in forage_sprites.keys():
		if not want.has(key):
			(forage_sprites[key] as Node).queue_free()
			forage_sprites.erase(key)
	for key: String in want:
		if forage_sprites.has(key):
			continue
		var t: Vector2i = want[key][0]
		var lift := float(want[key][2])
		var spr := Sprite2D.new()
		spr.centered = false
		spr.texture = Art.texture(want[key][1])
		spr.position = Vector2(t.x * TILE + TILE / 2.0, (t.y + 1) * TILE + lift)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height() - lift)
		sort_root.add_child(spr)
		forage_sprites[key] = spr


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


var _ground_rank: Dictionary = {}


func _ground_index(g: String) -> int:
	if _ground_rank.is_empty():
		for i in GROUND_ORDER.size():
			_ground_rank[GROUND_ORDER[i]] = i
	return _ground_rank.get(g, -1)


func _load_rows(c: Vector2i, row0: int, count: int) -> void:
	var w := session.world
	var cs := w.chunk_size
	var base := c * cs
	for ly in range(row0, row0 + count):
		for lx in cs:
			_draw_ground(base + Vector2i(lx, ly))
	for o: Array in w.objects_in_chunk(c):
		var oy := int(o[1])
		if oy >= row0 and oy < row0 + count:
			_draw_object(base + Vector2i(int(o[0]), oy))
	for t: Vector2i in session.placed:
		if w.chunk_of(t) == c and t.y - base.y >= row0 and t.y - base.y < row0 + count:
			_draw_placed(t)


func _unload_rows(c: Vector2i, row0: int, count: int) -> void:
	var cs := session.world.chunk_size
	var base := c * cs
	for ly in range(row0, row0 + count):
		for lx in cs:
			var t := base + Vector2i(lx, ly)
			ground_layer.erase_cell(t)
			edge_layer.erase_cell(t)
			detail_layer.erase_cell(t)
			shadow_layer.erase_cell(t)
			object_layer.erase_cell(t)
			if _placed_sprites.has(t):
				(_placed_sprites[t] as Node).queue_free()
				_placed_sprites.erase(t)


func reset_chunks() -> void:
	update_chunks(true)


func _draw_borders() -> void:
	var cs := session.world.chunk_size * TILE
	for c: Vector2i in loaded:
		_border_lines.draw_rect(Rect2(Vector2(c * cs), Vector2(cs, cs)), Color(1, 0, 0, 0.8), false, 1.0)
	var t := session.ranger_tile()
	_border_lines.draw_rect(Rect2(Vector2(t * TILE), Vector2(TILE, TILE)), Color(1, 1, 0, 0.9), false, 1.0)
