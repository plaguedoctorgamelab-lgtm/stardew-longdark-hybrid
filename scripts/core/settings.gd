class_name Settings
extends RefCounted
## The player's own settings, kept on this computer for every game (not in a
## save): user://settings.json. The Options screen (Esc, then Options) sets
## them. For now one setting (tracker #7):
##   hover_tips  "first_week": the hover tips show for the first days of a
##               game (tuning ui.hover_tip_days), then stop;
##               "always", or "off".

const PATH := "user://settings.json"
const HOVER_TIPS := ["first_week", "always", "off"]

static var values: Dictionary = {"hover_tips": "first_week"}
static var _loaded: bool = false


static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		var tips := str((parsed as Dictionary).get("hover_tips", "first_week"))
		if HOVER_TIPS.has(tips):
			values["hover_tips"] = tips


static func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(values, " "))


static func hover_tips() -> String:
	load_once()
	return str(values["hover_tips"])


## Moves the hover tips setting on to the next choice, saves it and returns it.
static func next_hover_tips() -> String:
	load_once()
	var i := HOVER_TIPS.find(values["hover_tips"])
	values["hover_tips"] = HOVER_TIPS[(i + 1) % HOVER_TIPS.size()]
	save()
	return values["hover_tips"]


## Whether hover tips show on this day of the game.
static func tips_showing(day: int, first_days: int) -> bool:
	match hover_tips():
		"always":
			return true
		"off":
			return false
	return day <= first_days
