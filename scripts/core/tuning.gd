class_name Tuning
extends RefCounted
## Every number that shapes play. Read from data/tuning/tuning.json and
## reloadable while the game runs. Systems read values at the moment of use,
## so a reload changes behavior at once.

signal reloaded

const DEFAULT_PATH := "res://data/tuning/tuning.json"

var path: String = DEFAULT_PATH
var data: Dictionary = {}


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	reload()


func reload() -> bool:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Tuning: cannot read %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Tuning: %s is not a JSON object" % path)
		return false
	data = parsed
	reloaded.emit()
	return true


## Looks up a value by dotted path, such as "energy.max".
func value(key: String) -> Variant:
	var node: Variant = data
	for part in key.split("."):
		if typeof(node) != TYPE_DICTIONARY or not (node as Dictionary).has(part):
			push_error("Tuning: missing value '%s'" % key)
			return null
		node = (node as Dictionary)[part]
	return node


func num(key: String) -> float:
	return float(value(key))


func integer(key: String) -> int:
	return int(value(key))


## Overrides one value in memory. Used by tests and the debug panel.
func set_value(key: String, v: Variant) -> void:
	var parts := key.split(".")
	var node: Dictionary = data
	for i in parts.size() - 1:
		node = node[parts[i]]
	node[parts[parts.size() - 1]] = v
