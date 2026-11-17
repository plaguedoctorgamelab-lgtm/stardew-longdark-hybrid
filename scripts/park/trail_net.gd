class_name TrailNet
extends RefCounted
## The trail network visitors walk on: every trail, stone step and boardwalk
## tile joined to the park gate, plus the short fords where a trail wades a
## stream. It is rebuilt the moment it is next asked about after any change
## to the land (trail dug or filled, an obstacle cleared or put back), so it
## is never out of date. Travel times come from distance fields, worked out
## once per destination and kept until the network changes.

var world: WorldData
var tuning: Tuning
var start: Vector2i            # the tile visitors enter from
var version: int = 0           # goes up on every rebuild
var _dirty: bool = true
var _idx: Dictionary = {}      # tile -> node index
var _pts: Array[Vector2i] = []
var _nbr: Array = []           # node index -> PackedInt32Array of neighbours
var _cost: Array = []          # node index -> PackedFloat32Array of step lengths
var _fields: Dictionary = {}   # target node -> PackedFloat32Array of distances
var _junctions: Array = []     # [Vector2i], worked out when first asked for
var _junctions_done: bool = false

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


func _init(w: WorldData, t: Tuning, start_tile: Vector2i) -> void:
	world = w
	tuning = t
	start = start_tile


func mark_dirty() -> void:
	_dirty = true


func _walk_ground(t: Vector2i) -> bool:
	if world.is_solid(t):
		return false
	return (tuning.value("visitors.walk_grounds") as Array).has(world.ground_at(t))


func _ensure() -> void:
	if not _dirty:
		return
	_dirty = false
	version += 1
	_idx = {}
	_pts = []
	_nbr = []
	_cost = []
	_fields = {}
	_junctions = []
	_junctions_done = false
	var s := _nearest_walk(start, 6)
	if s.x < 0:
		return
	var ford_max := tuning.integer("sites.ford_max_tiles")
	var fords := {}
	var queue: Array[Vector2i] = [s]
	_add(s)
	var head := 0
	while head < queue.size():
		var t: Vector2i = queue[head]
		head += 1
		for i in 4:
			var d := DIRS[i]
			var n := t + d
			if _idx.has(n):
				continue
			if _walk_ground(n) or fords.has(n):
				_add(n)
				queue.append(n)
			elif world.ground_at(n) == "shallows" and not world.is_solid(n) and not fords.has(n):
				# A ford: a straight wade over shallows to trail on the far side.
				var run: Array[Vector2i] = []
				var p := n
				while run.size() <= ford_max and world.ground_at(p) == "shallows" and not world.is_solid(p):
					run.append(p)
					p += d
				if run.size() <= ford_max and _walk_ground(p):
					for f in run:
						fords[f] = true
					_add(n)
					queue.append(n)
	# Links: straight steps, and diagonal steps that cut no corner.
	for i in _pts.size():
		var t := _pts[i]
		var ns := PackedInt32Array()
		var cs := PackedFloat32Array()
		for k in 8:
			var d := DIRS[k]
			var n := t + d
			if not _idx.has(n):
				continue
			if k >= 4 and not (_idx.has(Vector2i(t.x + d.x, t.y)) and _idx.has(Vector2i(t.x, t.y + d.y))):
				continue
			ns.append(_idx[n])
			cs.append(1.0 if k < 4 else 1.41421356)
		_nbr[i] = ns
		_cost[i] = cs


func _add(t: Vector2i) -> void:
	_idx[t] = _pts.size()
	_pts.append(t)
	_nbr.append(PackedInt32Array())
	_cost.append(PackedFloat32Array())


func _nearest_walk(t: Vector2i, r: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var n := t + Vector2i(dx, dy)
			if _walk_ground(n):
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best_d = d
					best = n
	return best


func size() -> int:
	_ensure()
	return _pts.size()


func has(t: Vector2i) -> bool:
	_ensure()
	return _idx.has(t)


func tiles() -> Array[Vector2i]:
	_ensure()
	return _pts


## The network tile nearest a point, within r tiles, or (-1, -1).
func nearest(p: Vector2, r: float) -> Vector2i:
	_ensure()
	var c := Vector2i(floori(p.x), floori(p.y))
	var ri := ceili(r)
	var best := Vector2i(-1, -1)
	var best_d := r + 0.001
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var n := c + Vector2i(dx, dy)
			if _idx.has(n):
				var d := (Vector2(n) + Vector2(0.5, 0.5)).distance_to(p)
				if d < best_d:
					best_d = d
					best = n
	return best


## Distance from any network tile to the target, in tiles walked.
func _field(target: Vector2i) -> PackedFloat32Array:
	_ensure()
	var ti: int = _idx[target]
	if _fields.has(ti):
		return _fields[ti]
	var n := _pts.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	dist[ti] = 0.0
	# A binary heap of [distance, node].
	var heap: Array = [[0.0, ti]]
	while not heap.is_empty():
		var top: Array = heap[0]
		var last: Array = heap.pop_back()
		if not heap.is_empty():
			heap[0] = last
			_sift_down(heap, 0)
		var d: float = top[0]
		var u: int = top[1]
		# Distances are kept in single precision: allow for the rounding.
		if d > dist[u] + 0.001:
			continue
		var ns: PackedInt32Array = _nbr[u]
		var cs: PackedFloat32Array = _cost[u]
		for k in ns.size():
			var v := ns[k]
			var nd := d + cs[k]
			if nd < dist[v] - 0.0001:
				dist[v] = nd
				heap.append([nd, v])
				_sift_up(heap, heap.size() - 1)
	_fields[ti] = dist
	return dist


static func _sift_up(h: Array, i: int) -> void:
	while i > 0:
		var p := (i - 1) / 2
		if float(h[p][0]) <= float(h[i][0]):
			return
		var tmp: Array = h[p]
		h[p] = h[i]
		h[i] = tmp
		i = p


static func _sift_down(h: Array, i: int) -> void:
	var n := h.size()
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and float(h[l][0]) < float(h[m][0]):
			m = l
		if r < n and float(h[r][0]) < float(h[m][0]):
			m = r
		if m == i:
			return
		var tmp: Array = h[m]
		h[m] = h[i]
		h[i] = tmp
		i = m


## Tiles walked between two network tiles, or INF if they are not joined.
func distance(a: Vector2i, b: Vector2i) -> float:
	_ensure()
	if not _idx.has(a) or not _idx.has(b):
		return INF
	return _field(b)[_idx[a]]


## The shortest way from a to b, as tile centres, a first and b last.
## Empty if they are not joined.
func path(a: Vector2i, b: Vector2i) -> PackedVector2Array:
	var out := PackedVector2Array()
	if distance(a, b) == INF:
		return out
	var dist := _field(b)
	var u: int = _idx[a]
	var goal: int = _idx[b]
	out.append(Vector2(_pts[u]) + Vector2(0.5, 0.5))
	var guard := _pts.size()
	while u != goal and guard > 0:
		guard -= 1
		var ns: PackedInt32Array = _nbr[u]
		var cs: PackedFloat32Array = _cost[u]
		var best := -1
		var best_d := dist[u]
		for k in ns.size():
			var v := ns[k]
			if dist[v] + cs[k] <= dist[u] + 0.0001 and dist[v] < best_d:
				best_d = dist[v]
				best = v
		if best < 0:
			break
		u = best
		out.append(Vector2(_pts[u]) + Vector2(0.5, 0.5))
	return out


## Game minutes to walk between two tiles at a speed in tiles per minute.
func minutes(a: Vector2i, b: Vector2i, tiles_per_minute: float) -> float:
	var d := distance(a, b)
	return INF if d == INF else d / tiles_per_minute


## Places where three or more trails meet: tiles whose surroundings split
## into three or more separate runs of trail at the tuned radius. Close ones
## are merged into one.
func junctions() -> Array:
	_ensure()
	if _junctions_done:
		return _junctions
	_junctions_done = true
	var r := tuning.integer("visitors.junction_radius")
	var ring: Array[Vector2i] = []
	for x in range(-r, r + 1):
		ring.append(Vector2i(x, -r))
	for y in range(-r + 1, r + 1):
		ring.append(Vector2i(r, y))
	for x in range(r - 1, -r - 1, -1):
		ring.append(Vector2i(x, r))
	for y in range(r - 1, -r, -1):
		ring.append(Vector2i(-r, y))
	var found: Array[Vector2i] = []
	for i in _pts.size():
		var t := _pts[i]
		if (t.x + t.y) % 2 != 0:
			continue
		var runs := 0
		var prev := _idx.has(t + ring[ring.size() - 1])
		for o in ring:
			var on := _idx.has(t + o)
			if on and not prev:
				runs += 1
			prev = on
		if runs >= 3:
			var near := false
			for f in found:
				if absi(f.x - t.x) <= r * 2 and absi(f.y - t.y) <= r * 2:
					near = true
					break
			if not near:
				found.append(t)
	_junctions = found
	return _junctions
