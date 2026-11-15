class_name MapState
extends RefCounted
## The ranger's map: what has been revealed, the dotted trace of where the
## ranger has walked, and which landmarks have been mapped. A trace walked
## while lost is held back and only drawn once the position marker returns.

signal changed

var width: int
var height: int
var revealed: PackedByteArray
var traced: PackedByteArray
var pending_trace: PackedByteArray
var mapped_landmarks: Dictionary = {}   # id -> true
var revealed_count: int = 0


func _init(w: int, h: int) -> void:
	width = w
	height = h
	wipe()


func wipe() -> void:
	revealed = PackedByteArray()
	revealed.resize(width * height)
	traced = PackedByteArray()
	traced.resize(width * height)
	pending_trace = PackedByteArray()
	pending_trace.resize(width * height)
	mapped_landmarks.clear()
	revealed_count = 0
	changed.emit()


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
	var r2 := radius * radius
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			var t := Vector2i(x, y)
			if not in_bounds(t):
				continue
			var d := Vector2(x + 0.5, y + 0.5) - center
			if d.length_squared() <= r2 and revealed[_i(t)] == 0:
				revealed[_i(t)] = 1
				added += 1
	revealed_count += added
	if added > 0:
		changed.emit()
	return added


func reveal_all() -> void:
	revealed.fill(1)
	revealed_count = width * height
	changed.emit()


## Records the ranger stepping onto a tile.
func record_trace(t: Vector2i, marker_visible: bool) -> void:
	if not in_bounds(t):
		return
	if marker_visible:
		traced[_i(t)] = 1
	else:
		pending_trace[_i(t)] = 1


## Moves the trace walked while lost onto the map.
func flush_pending() -> int:
	var moved := 0
	for i in pending_trace.size():
		if pending_trace[i] == 1:
			traced[i] = 1
			pending_trace[i] = 0
			moved += 1
	if moved > 0:
		changed.emit()
	return moved


func has_pending() -> bool:
	return pending_trace.has(1)


func percent_revealed() -> float:
	return 100.0 * float(revealed_count) / float(width * height)


func mark_landmark(id: String) -> void:
	mapped_landmarks[id] = true
	changed.emit()


func is_landmark_mapped(id: String) -> bool:
	return mapped_landmarks.has(id)


static func _pack(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes.compress(FileAccess.COMPRESSION_DEFLATE))


static func _unpack(s: String, size: int) -> PackedByteArray:
	return Marshalls.base64_to_raw(s).decompress(size, FileAccess.COMPRESSION_DEFLATE)


func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"revealed": _pack(revealed),
		"traced": _pack(traced),
		"pending": _pack(pending_trace),
		"landmarks": mapped_landmarks.keys(),
	}


func from_dict(d: Dictionary) -> void:
	var n := width * height
	revealed = _unpack(d["revealed"], n)
	traced = _unpack(d["traced"], n)
	pending_trace = _unpack(d["pending"], n)
	mapped_landmarks.clear()
	for id: String in d["landmarks"]:
		mapped_landmarks[id] = true
	revealed_count = revealed.count(1)
	changed.emit()
