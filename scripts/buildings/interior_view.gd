class_name InteriorView
extends Node2D
## Draws the inside of a building: floor, walls, furniture and the ranger.

const TILE := 16

var session: GameSession
var sort_root: Node2D
var _furniture_sprites: Dictionary = {}   # furniture id -> Sprite2D
var _floor: Node2D
var current: String = ""


func setup(s: GameSession) -> void:
	session = s
	_floor = Node2D.new()
	_floor.z_index = -10
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
		spr.texture = Art.texture(art_name)
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -spr.texture.get_height())


func room_center_px() -> Vector2:
	var layout: InteriorLayout = session.interiors[current]
	return Vector2(layout.size) * TILE / 2.0


func _draw_room() -> void:
	if current == "":
		return
	var layout: InteriorLayout = session.interiors[current]
	var row := session.content.row("structures", current)
	var floor_tex := Art.texture(row["interior"]["floor"])
	var wall_tex := Art.texture(row["interior"]["wall"])
	_floor.draw_rect(Rect2(-2000, -2000, 4000, 4000), Color(0.05, 0.04, 0.04))
	for y in layout.size.y:
		for x in layout.size.x:
			var t := Vector2i(x, y)
			var is_wall := x == 0 or y == 0 or x == layout.size.x - 1 or y == layout.size.y - 1
			if t == layout.door_tile:
				_floor.draw_texture(Art.texture("furniture_door"), Vector2(t * TILE))
			else:
				_floor.draw_texture(wall_tex if is_wall else floor_tex, Vector2(t * TILE))
