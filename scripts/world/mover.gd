class_name Mover
extends RefCounted
## Moves a box through a tile grid, sliding along solid tiles. Positions and
## sizes are in tiles. The x and y moves are tried separately so the ranger
## slides along walls instead of sticking.


static func box_hits(pos: Vector2, half: Vector2, is_solid: Callable) -> bool:
	var x0 := floori(pos.x - half.x)
	var x1 := floori(pos.x + half.x - 0.0001)
	var y0 := floori(pos.y - half.y)
	var y1 := floori(pos.y + half.y - 0.0001)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if is_solid.call(Vector2i(x, y)):
				return true
	return false


static func move(pos: Vector2, motion: Vector2, size: Vector2, is_solid: Callable) -> Vector2:
	var half := size / 2.0
	# Already standing in something solid (a bathroom built or a can put
	# down on the ranger's own tile): those tiles do not hold the ranger, so
	# a step always walks out (tracker #12, #14).
	if box_hits(pos, half, is_solid):
		var stuck := {}
		for y in range(floori(pos.y - half.y), floori(pos.y + half.y - 0.0001) + 1):
			for x in range(floori(pos.x - half.x), floori(pos.x + half.x - 0.0001) + 1):
				if is_solid.call(Vector2i(x, y)):
					stuck[Vector2i(x, y)] = true
		var inner := is_solid
		is_solid = func(t: Vector2i) -> bool: return not stuck.has(t) and inner.call(t)
	# Split long moves so nothing is skipped over.
	var steps := maxi(1, ceili(motion.length() / 0.25))
	var step := motion / steps
	var p := pos
	for i in steps:
		p = _slide(p, Vector2(step.x, 0.0), half, is_solid)
		p = _slide(p, Vector2(0.0, step.y), half, is_solid)
	return p


## Moves along one axis as far as possible, up to touching a solid tile.
static func _slide(p: Vector2, d: Vector2, half: Vector2, is_solid: Callable) -> Vector2:
	if d == Vector2.ZERO:
		return p
	if not box_hits(p + d, half, is_solid):
		return p + d
	var lo := 0.0
	var hi := 1.0
	for i in 6:
		var mid := (lo + hi) / 2.0
		if box_hits(p + d * mid, half, is_solid):
			hi = mid
		else:
			lo = mid
	return p + d * lo
