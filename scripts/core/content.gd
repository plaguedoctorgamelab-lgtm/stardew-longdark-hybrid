class_name ContentDB
extends RefCounted
## The content database. One JSON table per kind of thing in data/content/,
## loaded into memory. The rest of the game reaches content only through
## these lookup functions, so storage can change without touching callers.

const CONTENT_DIR := "res://data/content/"
const TABLES: Array[String] = ["items", "foods", "weather_types", "weather_odds", "structures", "landmarks", "jobs", "obstacles", "text"]

var tables: Dictionary = {}   # table name -> Array of row dictionaries
var index: Dictionary = {}    # table name -> {id: row}
var errors: Array[String] = []


func _init(dir: String = CONTENT_DIR) -> void:
	for table in TABLES:
		_load_table(dir, table)


func _load_table(dir: String, table: String) -> void:
	var file_path := dir + table + ".json"
	var text := FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("rows"):
		errors.append("table %s did not load" % table)
		tables[table] = []
		index[table] = {}
		return
	var rows: Array = parsed["rows"]
	tables[table] = rows
	var by_id := {}
	for row: Dictionary in rows:
		var id := str(row.get("id", ""))
		if id.is_empty():
			errors.append("table %s has a row with no id" % table)
		elif by_id.has(id):
			errors.append("table %s has duplicate id %s" % [table, id])
		by_id[id] = row
	index[table] = by_id


func rows(table: String) -> Array:
	return tables.get(table, [])


func has(table: String, id: String) -> bool:
	return (index.get(table, {}) as Dictionary).has(id)


func row(table: String, id: String) -> Dictionary:
	var d: Dictionary = index.get(table, {})
	if not d.has(id):
		push_error("Content: no row '%s' in table '%s'" % [id, table])
		return {}
	return d[id]


func ids(table: String) -> Array[String]:
	var out: Array[String] = []
	for r: Dictionary in rows(table):
		out.append(str(r["id"]))
	return out


## Player-facing text, with {name} fields filled from args.
func text(id: String, args: Dictionary = {}) -> String:
	var d: Dictionary = index.get("text", {})
	if not d.has(id):
		push_error("Content: no text '%s'" % id)
		return id
	var s: String = d[id]["text"]
	return s.format(args)


func item_name(item_id: String) -> String:
	return text(row("items", item_id).get("name", item_id))
