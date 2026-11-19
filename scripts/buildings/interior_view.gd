class_name InteriorView
extends Node2D
## Draws the inside of a building: the back wall seen from the front, with its
## windows and other wall pieces; the floor and rugs; thin trim round the room;
## furniture with its shadows; and the ranger.

const TILE := 16

var session: GameSession
var sort_root: Node2D
var _furniture_sprites: Dictionary = {}   # furniture id -> {"sprite", "row"}
var _floor: Node2D
var current: String = ""


func setup(s: GameSession) -> void:
	session = s
	_floor = Node2D.new()
	_floor.z_index = -20
	_floor.draw.connect(_draw_room)
	add_child(_floor)
	sort_root = Node2D.new()
	sort_root.y_sort_enabled = true
	add_child(sort_root)


func show_room(structure_id: String, ranger_node: Node2D) -> void:
	current = structure_id
	for c in sort_root.get_children():
		if c != ranger_node:
			c.queue_free()
	_furniture_sprites.clear()
	var layout: InteriorLayout = session.interiors[structure_id]
	for f: Dictionary in layout.furniture:
		if f["kind"] == "exit":
			continue
		var spr := Sprite2D.new()
		spr.centered = false
		var r := layout.furniture_rect(f)
		spr.position = Vector2(r.position.x + r.size.x / 2.0, r.end.y) * TILE
		sort_root.add_child(spr)
		Shadow.attach(spr, r.size.x * TILE, session.tuning)
		_furniture_sprites[f["id"]] = {"sprite": spr, "row": f}
	ranger_node.reparent(sort_root)
	refresh()
	_floor.queue_redraw()


func refresh() -> void:
	for id: String in _furniture_sprites:
		var spr: Sprite2D = _furniture_sprites[id]["sprite"]
		var f: Dictionary = _furniture_sprites[id]["row"]
		var art_name: String = f["sprite"]
		if f["kind"] == "stove" and session.structures.stove_lit(current):
			art_name = "furniture_stove_lit"
		if f["kind"] == "job_spot":
			art_name = session.jobs.spot_sprite(id)
			spr.visible = art_name != "" and not session.interiors[current].hidden.has(id)
			if not spr.visible:
				continue
		spr.texture = Art.texture(art_name)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())


func room_center_px() -> Vector2:
	var layout: InteriorLayout = session.interiors[current]
	return Vector2(layout.size) * TILE / 2.0


func _draw_room() -> void:
	if current == "":
		return
	var layout: InteriorLayout = session.interiors[current]
	var inside: Dictionary = session.content.row("structures", current)["interior"]
	var floor_tex := Art.texture(inside["floor"])
	var wall_tex := Art.texture(inside["wall"])
	var base_tex := Art.texture(inside.get("wall_base", inside["wall"]))
	var w := layout.size.x
	var h := layout.size.y
	var wh := layout.wall_height
	_floor.draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.05, 0.04, 0.04))
	# Back wall: the bottom row of it carries the skirting board.
	for y in wh:
		for x in range(1, w - 1):
			_floor.draw_texture(base_tex if y == wh - 1 else wall_tex, Vector2(x, y) * TILE)
	for y in range(wh, h - 1):
		for x in range(1, w - 1):
			_floor.draw_texture(floor_tex, Vector2(x, y) * TILE)
	for d: Dictionary in inside.get("decor", []):
		_floor.draw_texture(Art.texture(d["sprite"]), Vector2(float(d["pos"][0]), float(d["pos"][1])) * TILE)
	for r: Dictionary in inside.get("rugs", []):
		_floor.draw_texture(Art.texture(r["sprite"]), Vector2(float(r["pos"][0]), float(r["pos"][1])) * TILE)
	# Thin trim round the room, on the inside edge of the border tiles.
	if inside.has("trim"):
		var trim := Art.texture(inside["trim"])
		var k := float(trim.get_width())
		var left := TILE - k
		var right := float((w - 1) * TILE)
		var bottom := float((h - 1) * TILE)
		_floor.draw_texture_rect(trim, Rect2(left, -k, k, bottom + 2 * k), true)
		_floor.draw_texture_rect(trim, Rect2(right, -k, k, bottom + 2 * k), true)
		_floor.draw_texture_rect(trim, Rect2(left, -k, right - left + k, k), true)
		_floor.draw_texture_rect(trim, Rect2(left, bottom, right - left + k, k), true)
	if layout.door_tile.x >= 0:
		_floor.draw_texture(Art.texture("furniture_door"), Vector2(layout.door_tile * TILE))
