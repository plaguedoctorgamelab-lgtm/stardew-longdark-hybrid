class_name SaveSystem
extends RefCounted
## Save files. Each slot is one JSON file in the player's data folder with a
## version number. Older versions are upgraded step by step; anything that
## cannot be read fails with a clear message and is never overwritten.

const VERSION := 2
const DEFAULT_DIR := "user://saves/"
const REQUIRED_KEYS: Array[String] = ["clock", "weather", "ranger", "needs", "backpack", "structures", "map", "seed"]


static func slot_path(slot: int, dir: String = DEFAULT_DIR) -> String:
	return dir + "slot_%d.json" % slot


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)


static func write(path: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	data["version"] = VERSION
	# Write to a temporary file first, then swap it in, so a failed write
	# never leaves a half-written save.
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, " "))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


## Returns {"ok": bool, "data": Dictionary, "error": text id}.
## `world` tells the upgrade steps about the current world: its size and
## where ring one sits in it ({"size": Vector2i, "ring_one_offset": Vector2i}).
static func read(path: String, world: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "msg_save_broken"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("version"):
		return {"ok": false, "data": {}, "error": "msg_save_broken"}
	var data: Dictionary = parsed
	var v := int(data["version"])
	if v > VERSION:
		return {"ok": false, "data": {}, "error": "msg_save_too_new"}
	data = migrate(data, world)
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return {"ok": false, "data": {}, "error": "msg_save_broken"}
	return {"ok": true, "data": data, "error": ""}


## Upgrades an older save one version at a time; each version adds one step.
static func migrate(data: Dictionary, world: Dictionary = {}) -> Dictionary:
	var v := int(data["version"])
	while v < VERSION:
		if v == 1:
			data = _v1_to_v2(data, world)
		v += 1
	data["version"] = VERSION
	return data


## Version 2: the world grew from the phase one test area to the whole
## forest region, with the test area (ring one) placed inside it. Every saved
## position moves by ring one's offset, and the map sheet is placed into the
## larger sheet. Changes to the land gain their own record.
static func _v1_to_v2(data: Dictionary, world: Dictionary) -> Dictionary:
	var off: Vector2i = world.get("ring_one_offset", Vector2i.ZERO)
	var size: Vector2i = world.get("size", Vector2i.ZERO)
	if data.has("ranger"):
		var r: Dictionary = data["ranger"]
		r["outdoor_pos"] = [float(r["outdoor_pos"][0]) + off.x, float(r["outdoor_pos"][1]) + off.y]
	var c: Dictionary = data.get("camp", {})
	if not c.is_empty():
		c["bed"] = [int(c["bed"][0]) + off.x, int(c["bed"][1]) + off.y]
		c["fire"] = [int(c["fire"][0]) + off.x, int(c["fire"][1]) + off.y]
	var moved := []
	for e: Array in data.get("chopped", []):
		moved.append([int(e[0]) + off.x, int(e[1]) + off.y, int(e[2])])
	data["chopped"] = moved
	if data.has("map") and size != Vector2i.ZERO:
		var m: Dictionary = data["map"]
		var ow := int(m["width"])
		var oh := int(m["height"])
		if ow != size.x or oh != size.y:
			for key in ["revealed", "traced", "pending"]:
				m[key] = MapState.embed(m[key], ow, oh, size.x, size.y, off)
			m["width"] = size.x
			m["height"] = size.y
	if not data.has("land"):
		data["land"] = {}
	return data
