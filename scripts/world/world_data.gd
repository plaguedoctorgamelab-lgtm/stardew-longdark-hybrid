class_name WorldData
extends RefCounted
## The baked outdoor world. Reads data/world/world.json and the chunk files,
## loading chunks only when asked for, so it works for a world hundreds of
## chunks wide. Answers what ground and objects are at a tile, and whether a
## tile is solid. Only chunks that hold something are baked; the rest of the
## region reads as solid rock until its ring is built.

const WORLD_DIR := "res://data/world/"

var meta: Dictionary = {}
var width: int = 0
var height: int = 0
var chunk_size: int = 32
var ground_codes: Dictionary = {}
var _chunks: Dictionary = {}   # Vector2i -> {"ground": PackedStringArray, "solid": PackedStringArray, "objects": Array}
var loads: int = 0             # chunk files read, for tests and debug


func _init(dir: String = WORLD_DIR) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "world.json"))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WorldData: cannot read world.json")
		return
	meta = parsed
	width = int(meta["size"][0])
	height = int(meta["size"][1])
	chunk_size = int(meta["chunk_size"])
	ground_codes = meta["ground_codes"]
	_dir = dir
	for run: Array in meta.get("baked_runs", []):
		for cx in range(int(run[1]), int(run[2]) + 1):
			_baked[Vector2i(cx, int(run[0]))] = true


var _baked: Dictionary = {}   # chunk -> true for chunks that were baked


var _dir: String = WORLD_DIR


func chunk_count() -> Vector2i:
	return Vector2i(int(meta["chunks"][0]), int(meta["chunks"][1]))


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


func chunk_of(t: Vector2i) -> Vector2i:
	return Vector2i(floori(float(t.x) / chunk_size), floori(float(t.y) / chunk_size))


func has_chunk_file(c: Vector2i) -> bool:
	return _baked.has(c)


func baked_count() -> int:
	return _baked.size()


## A mask over the whole region: 1 on tiles of baked chunks.
func explorable_mask() -> PackedByteArray:
	var key := _dir + str(width) + "x" + str(height)
	if _mask_cache.has(key):
		return _mask_cache[key]
	var ones := PackedByteArray()
	ones.resize(chunk_size)
	ones.fill(1)
	var zeros := PackedByteArray()
	zeros.resize(chunk_size)
	var mask := PackedByteArray()
	var cc := chunk_count()
	for cy in cc.y:
		var row := PackedByteArray()
		for cx in cc.x:
			row.append_array(ones if _baked.has(Vector2i(cx, cy)) else zeros)
		for ly in chunk_size:
			mask.append_array(row)
	_mask_cache[key] = mask
	return mask


static var _mask_cache: Dictionary = {}


## The tile rectangle that holds every baked chunk.
func baked_bounds() -> Rect2i:
	var b: Array = meta.get("baked_bounds", [0, 0, width, height])
	return Rect2i(int(b[0]), int(b[1]), int(b[2]) - int(b[0]), int(b[3]) - int(b[1]))


## Where ring one, the phase one area, sits in the region.
func ring_one_offset() -> Vector2i:
	var o: Array = meta.get("ring_one_offset", [0, 0])
	return Vector2i(int(o[0]), int(o[1]))


## A ring one tile, given in ring one's own coordinates.
func r1(x: int, y: int) -> Vector2i:
	return Vector2i(x, y) + ring_one_offset()


func chunk(c: Vector2i) -> Dictionary:
	if _chunks.has(c):
		return _chunks[c]
	if not has_chunk_file(c):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir + "chunks/c_%d_%d.json" % [c.x, c.y]))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("WorldData: chunk %s did not load" % c)
		return {}
	var d: Dictionary = parsed
	var by_tile := {}
	for o: Array in d["objects"]:
		by_tile[Vector2i(int(o[0]), int(o[1]))] = str(o[2])
	var data := {
		"ground": PackedStringArray(d["ground"]),
		"solid": PackedStringArray(d["solid"]),
		"objects": d["objects"],
		"by_tile": by_tile,
	}
	_chunks[c] = data
	loads += 1
	return data


func is_chunk_cached(c: Vector2i) -> bool:
	return _chunks.has(c)


func cached_chunks() -> Array:
	return _chunks.keys()


## Drops cached chunks farther than `keep` chunks from `center`.
func trim_cache(center: Vector2i, keep: int) -> void:
	for c: Vector2i in _chunks.keys():
		if absi(c.x - center.x) > keep or absi(c.y - center.y) > keep:
			_chunks.erase(c)


func ground_at(t: Vector2i) -> String:
	if not in_bounds(t):
		return "rock"
	if _ground_override.has(t):
		return _ground_override[t]
	var d := chunk(chunk_of(t))
	if d.is_empty():
		return "rock"
	var row: String = d["ground"][t.y - chunk_of(t).y * chunk_size]
	return ground_codes[row[t.x - chunk_of(t).x * chunk_size]]


var _blocked: Dictionary = {}   # extra solid tiles added at run time
var _cleared: Dictionary = {}   # tiles whose object was removed at run time (chopped trees, cleared obstacles)
var _ground_override: Dictionary = {}   # tiles whose ground was changed at run time (dug trail)


func is_solid(t: Vector2i) -> bool:
	if not in_bounds(t):
		return true
	if _blocked.has(t):
		return true
	if _cleared.has(t):
		var g := ground_at(t)
		return g == "deep_water" or g == "rock"
	var c := chunk_of(t)
	var d := chunk(c)
	if d.is_empty():
		return true
	var row: String = d["solid"][t.y - c.y * chunk_size]
	return row[t.x - c.x * chunk_size] == "1"


func objects_in_chunk(c: Vector2i) -> Array:
	var d := chunk(c)
	if d.is_empty():
		return []
	return d["objects"]


func object_type(kind: String) -> Dictionary:
	return meta["object_types"].get(kind, {})


func spawn(spawn_name: String) -> Vector2:
	var p: Array = meta["spawns"][spawn_name]
	return Vector2(float(p[0]), float(p[1]))


func structure_placement(id: String) -> Dictionary:
	for s: Dictionary in meta["structures"]:
		if s["id"] == id:
			return s
	return {}


func landmark_pos(id: String) -> Vector2:
	var p: Array = meta["landmarks"][id]
	return Vector2(float(p[0]), float(p[1]))


func route(route_name: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Array in meta["routes"][route_name]:
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Finds an interactive object within reach of a point, in tile units.
func interactive_near(pos: Vector2, reach: float) -> Dictionary:
	var t := Vector2i(floori(pos.x), floori(pos.y))
	var best := {}
	var best_d := reach
	# Interactive objects are few; scan the ranger's chunk and its neighbours.
	var c0 := chunk_of(t)
	for cy in range(c0.y - 1, c0.y + 2):
		for cx in range(c0.x - 1, c0.x + 2):
			var cc := Vector2i(cx, cy)
			for o: Array in objects_in_chunk(cc):
				var ot := object_type(str(o[2]))
				if not ot.has("interact"):
					continue
				var size: Array = ot["size"]
				var center := Vector2(cc.x * chunk_size + int(o[0]) + float(size[0]) / 2.0, cc.y * chunk_size + int(o[1]) + float(size[1]) / 2.0)
				var d := center.distance_to(pos)
				if d <= best_d:
					best_d = d
					best = {"interact": ot["interact"], "pos": center}
	return best


## The object whose top-left tile is t, or "".
func object_at(t: Vector2i) -> String:
	if not in_bounds(t):
		return ""
	var c := chunk_of(t)
	var d := chunk(c)
	if d.is_empty():
		return ""
	return (d["by_tile"] as Dictionary).get(t - c * chunk_size, "")


func set_cleared(t: Vector2i, on: bool) -> void:
	if on:
		_cleared[t] = true
	else:
		_cleared.erase(t)


## Changes a tile's ground for this save, as digging trail does; "" undoes it.
func set_ground(t: Vector2i, ground: String) -> void:
	if ground == "":
		_ground_override.erase(t)
	else:
		_ground_override[t] = ground


func baked_ground_at(t: Vector2i) -> String:
	var keep: Variant = _ground_override.get(t)
	_ground_override.erase(t)
	var g := ground_at(t)
	if keep != null:
		_ground_override[t] = keep
	return g


func clear_runtime_changes() -> void:
	_cleared.clear()
	_blocked.clear()
	_ground_override.clear()
