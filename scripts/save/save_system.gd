class_name SaveSystem
extends RefCounted
## Save files. Each slot is one JSON file in the player's data folder with a
## version number. Older versions are upgraded step by step; anything that
## cannot be read fails with a clear message and is never overwritten.

const VERSION := 1
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
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": {}, "error": "msg_save_broken"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("version"):
		return {"ok": false, "data": {}, "error": "msg_save_broken"}
	var data: Dictionary = parsed
	var v := int(data["version"])
	if v > VERSION:
		return {"ok": false, "data": {}, "error": "msg_save_too_new"}
	data = migrate(data)
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return {"ok": false, "data": {}, "error": "msg_save_broken"}
	return {"ok": true, "data": data, "error": ""}


## Upgrades an older save one version at a time. Phase one has only version 1;
## each later version adds one step here.
static func migrate(data: Dictionary) -> Dictionary:
	var v := int(data["version"])
	while v < VERSION:
		v += 1
	data["version"] = VERSION
	return data
