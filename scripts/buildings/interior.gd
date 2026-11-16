class_name InteriorLayout
extends RefCounted
## The small separate room inside a building, built from the structure's row
## in the content table. The top wall_height rows are the back wall, seen from
## the front; the other three sides are a one-tile border drawn as thin trim.
## Furniture stands on the floor, and a door tile in the bottom border leads
## back outside.

var structure_id: String
var size: Vector2i
var furniture: Array = []   # rows from content
var entry: Vector2
var door_tile: Vector2i = Vector2i(-1, -1)
var wall_height: int = 1
var kit_spot: Dictionary = {}   # where a workbench kit is set up, if one can be




func _init(row: Dictionary) -> void:
	structure_id = row["id"]
	var inside: Dictionary = row["interior"]
	size = Vector2i(int(inside["size"][0]), int(inside["size"][1]))
	furniture = (inside["furniture"] as Array).duplicate()
	kit_spot = inside.get("kit_spot", {})
	wall_height = int(inside.get("wall_height", 1))
	entry = Vector2(float(inside["entry"][0]) + 0.5, float(inside["entry"][1]) + 0.5)
	for f: Dictionary in furniture:
		if f["kind"] == "exit":
			door_tile = Vector2i(int(f["pos"][0]), int(f["pos"][1]))


func furniture_rect(f: Dictionary) -> Rect2i:
	return Rect2i(int(f["pos"][0]), int(f["pos"][1]), int(f["size"][0]), int(f["size"][1]))


func is_solid(t: Vector2i) -> bool:
	if t == door_tile:
		return false
	if t.x <= 0 or t.y < wall_height or t.x >= size.x - 1 or t.y >= size.y - 1:
		return true
	for f: Dictionary in furniture:
		if f["kind"] != "exit" and furniture_rect(f).has_point(t):
			return true
	return false


## The piece of furniture nearest to pos within reach, or {}.
func furniture_near(pos: Vector2, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for f: Dictionary in furniture:
		var r := furniture_rect(f)
		var closest := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		var d := closest.distance_to(pos)
		if d <= best_d:
			best_d = d
			best = f
	return best


func find(kind: String) -> Dictionary:
	for f: Dictionary in furniture:
		if f["kind"] == kind:
			return f
	return {}


## Sets up a workbench from a kit at the room's kit spot. False if the room
## has no spot or already has a workbench.
func set_up_workbench() -> bool:
	if kit_spot.is_empty() or not find("workbench").is_empty():
		return false
	furniture.append({"id": "workbench", "kind": "workbench", "pos": kit_spot["pos"], "size": kit_spot["size"], "sprite": "furniture_workbench", "from_kit": true})
	return true


## Takes away a workbench set up from a kit (debug, tests and new games).
func remove_kit_workbench() -> void:
	furniture = furniture.filter(func(f: Dictionary) -> bool: return not bool(f.get("from_kit", false)))
