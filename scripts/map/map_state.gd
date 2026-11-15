class_name MapState
extends RefCounted
## The ranger's map: what has been revealed, the dotted trace of where the
## ranger has walked, and which landmarks have been mapped. A trace walked
## while lost is held back and only drawn once the position marker returns.
##
## The sheet covers the whole region, but only ground that has been built
## (the explorable tiles) counts towards the share revealed. Changed chunks
## are remembered so the map picture only redraws what changed.

signal changed

var width: int
var height: int
var chunk_size: int = 32
var revealed: PackedByteArray
var traced: PackedByteArray
var pending_trace: PackedByteArray
var explorable: PackedByteArray
var explorable_count: int = 0
var mapped_landmarks: Dictionary = {}   # id -> true
var revealed_count: int = 0
var dirty: Dictionary = {}              # chunk -> true, changed since the picture was drawn
var all_dirty: bool = true
var _pending: Dictionary = {}           # index -> true


## `explorable_mask` marks the tiles that count (1) and those that do not (0).
## Without one, every tile counts.
func _init(w: int, h: int, explorable_mask: PackedByteArray = PackedByteArray(), chunk: int = 32) -> void:
	width = w
	height = h
	chunk_size = chunk
	if explorable_mask.size() == w * h:
		explorable = explorable_mask
	else:
		explorable = PackedByteArray()
		explorable.resize(w * h)
		explorable.fill(1)
	explorable_count = explorable.count(1)
	wipe()


func wipe() -> void:
	revealed = PackedByteArray()
	revealed.resize(width * height)
	traced = PackedByteArray()
	traced.resize(width * height)
	pending_trace = PackedByteArray()
	pending_trace.resize(width * height)
	_pending.clear()
	mapped_landmarks.clear()
	revealed_count = 0
	_mark_all()
	changed.emit()


func _mark_all() -> void:
	all_dirty = true
	dirty.clear()


func _mark(t: Vector2i) -> void:
	if not all_dirty:
		dirty[Vector2i(t.x / chunk_size, t.y / chunk_size)] = true


## The chunks changed since the last call, or every chunk; clears the record.
func take_dirty() -> Dictionary:
	var out := {"all": all_dirty, "chunks": dirty.keys()}
	all_dirty = false
	dirty.clear()
	return out


func _i(t: Vector2i) -> int:
	return t.y * width + t.x


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


func is_revealed(t: Vector2i) -> bool:
	return in_bounds(t) and revealed[_i(t)] == 1


func is_traced(t: Vector2i) -> bool:
	return in_bounds(t) and traced[_i(t)] == 1


func is_pending(t: Vector2i) -> bool:
	return in_bounds(t) and pending_trace[_i(t)] == 1


## Reveals every tile within radius of a point. Returns how many were new.
func reveal_circle(center: Vector2, radius: float) -> int:
	var added := 0
	var counted := 0
	var r2 := radius * radius
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			var t := Vector2i(x, y)
			if not in_bounds(t):
				continue
			var d := Vector2(x + 0.5, y + 0.5) - center
			var i := _i(t)
			if d.length_squared() <= r2 and revealed[i] == 0:
				revealed[i] = 1
				added += 1
				counted += explorable[i]
	revealed_count += counted
	if added > 0:
		var c0 := Vector2i(floori(center.x - radius), floori(center.y - radius))
		var c1 := Vector2i(ceili(center.x + radius), ceili(center.y + radius))
		for cy in range(maxi(0, c0.y) / chunk_size, mini(height - 1, c1.y) / chunk_size + 1):
			for cx in range(maxi(0, c0.x) / chunk_size, mini(width - 1, c1.x) / chunk_size + 1):
				_mark(Vector2i(cx * chunk_size, cy * chunk_size))
		changed.emit()
	return added


func reveal_all() -> void:
	revealed = explorable.duplicate()
	revealed_count = explorable_count
	_mark_all()
	changed.emit()


## Records the ranger stepping onto a tile.
func record_trace(t: Vector2i, marker_visible: bool) -> void:
	if not in_bounds(t):
		return
	var i := _i(t)
	if marker_visible:
		if traced[i] == 0:
			traced[i] = 1
			_mark(t)
	elif pending_trace[i] == 0:
		pending_trace[i] = 1
		_pending[i] = true


## Moves the trace walked while lost onto the map.
func flush_pending() -> int:
	var moved := 0
	for i: int in _pending:
		if pending_trace[i] == 1:
			traced[i] = 1
			pending_trace[i] = 0
			_mark(Vector2i(i % width, i / width))
			moved += 1
	_pending.clear()
	if moved > 0:
		changed.emit()
	return moved


func has_pending() -> bool:
	return not _pending.is_empty()


func percent_revealed() -> float:
	if explorable_count == 0:
		return 0.0
	return 100.0 * float(revealed_count) / float(explorable_count)


func mark_landmark(id: String) -> void:
	mapped_landmarks[id] = true
	changed.emit()


func is_landmark_mapped(id: String) -> bool:
	return mapped_landmarks.has(id)


static func pack(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))


static func unpack(s: String, size: int) -> PackedByteArray:
	return Marshalls.base64_to_raw(s).decompress(size, FileAccess.COMPRESSION_DEFLATE)


func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"revealed": pack(revealed),
		"traced": pack(traced),
		"pending": pack(pending_trace),
		"landmarks": mapped_landmarks.keys(),
	}


func from_dict(d: Dictionary) -> void:
	var n := width * height
	revealed = unpack(d["revealed"], n)
	traced = unpack(d["traced"], n)
	pending_trace = unpack(d["pending"], n)
	_pending.clear()
	var i := pending_trace.find(1)
	while i >= 0:
		_pending[i] = true
		i = pending_trace.find(1, i + 1)
	mapped_landmarks.clear()
	for id: String in d["landmarks"]:
		mapped_landmarks[id] = true
	revealed_count = _count_explorable_revealed()
	_mark_all()
	changed.emit()


func _count_explorable_revealed() -> int:
	# Fast path: when every revealed tile is explorable, a native count works.
	var r := revealed.count(1)
	if explorable_count == width * height:
		return r
	var n := 0
	var i := revealed.find(1)
	while i >= 0:
		n += explorable[i]
		i = revealed.find(1, i + 1)
	return n


## Places an old, smaller sheet into this one at an offset (save upgrades).
static func embed(packed: String, old_w: int, old_h: int, new_w: int, new_h: int, offset: Vector2i) -> String:
	var src := unpack(packed, old_w * old_h)
	var dst := PackedByteArray()
	dst.resize(new_w * new_h)
	for y in old_h:
		var row := src.slice(y * old_w, (y + 1) * old_w)
		var at := (y + offset.y) * new_w + offset.x
		for x in old_w:
			dst[at + x] = row[x]
	return pack(dst)
