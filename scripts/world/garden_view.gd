class_name GardenView
extends Node2D
## Draws the garden behind the station (Phase 4b, step 14): the soil, dry or
## watered or under snow, flat on the ground; the crops at their stage and
## the fence and gate standing among everything else, so the ranger walks
## behind the tall ones. Looked at a few times a second.

const TILE := 16

var session: GameSession
var garden: Garden
var _sort_root: Node2D
var _crops: Dictionary = {}     # Vector2i -> Sprite2D
var _wait: float = 0.0
var _splash: Array = []         # [tile, seconds]
var _time: float = 0.0


func setup(s: GameSession, sort_root: Node2D) -> void:
	session = s
	garden = s.garden
	_sort_root = sort_root
	z_index = -15
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_fence()
	s.tool_landed.connect(func(tool: String, t: Vector2i, _kind: String) -> void:
		if tool == "watering_can":
			_splash.append([t, 0.0]))


func _stand(art: String, foot_tile: Vector2i) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = false
	spr.texture = Art.texture(art)
	spr.position = (Vector2(foot_tile) + Vector2(0.5, 1.0)) * TILE
	spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	_sort_root.add_child(spr)
	return spr


func _build_fence() -> void:
	var o := garden.origin
	var sz := garden.size
	for t: Vector2i in garden.fence_tiles():
		var corner := (t.x == o.x - 1 or t.x == o.x + sz.x) and (t.y == o.y - 1 or t.y == o.y + sz.y)
		var art := "garden_fence_post" if corner else ("garden_fence_v" if t.x == o.x - 1 or t.x == o.x + sz.x else "garden_fence_h")
		if t == garden.gate:
			art = "garden_gate"
		if Art.has_picture(art):
			_stand(art, t)


func _process(delta: float) -> void:
	if session == null or not is_visible_in_tree():
		return
	_time += delta
	for e: Array in _splash.duplicate():
		e[1] = float(e[1]) + delta
		if float(e[1]) > 0.45:
			_splash.erase(e)
	_wait -= delta
	if _wait > 0.0 and _splash.is_empty():
		return
	_wait = 0.4
	refresh()


func refresh() -> void:
	var seen := {}
	for y in garden.size.y:
		for x in garden.size.x:
			var t := garden.origin + Vector2i(x, y)
			var pics := garden.pictures(t)
			if pics[1] == "":
				continue
			seen[t] = true
			var spr: Sprite2D = _crops.get(t)
			if spr == null:
				spr = _stand(pics[1], t)
				_crops[t] = spr
			elif spr.texture != Art.texture(pics[1]):
				spr.texture = Art.texture(pics[1])
				spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())
	for t: Vector2i in _crops.keys():
		if not seen.has(t):
			(_crops[t] as Sprite2D).queue_free()
			_crops.erase(t)
	queue_redraw()


func _draw() -> void:
	if garden == null:
		return
	for y in garden.size.y:
		for x in garden.size.x:
			var t := garden.origin + Vector2i(x, y)
			var soil := garden.pictures(t)[0]
			if soil != "" and Art.has_picture(soil):
				draw_texture(Art.texture(soil), Vector2(t) * TILE)
	for e: Array in _splash:
		var f := clampi(int(float(e[1]) / 0.15), 0, 2)
		var art := "fx_water_%d" % f
		if Art.has_picture(art):
			draw_texture(Art.texture(art), Vector2(e[0] as Vector2i) * TILE)
