class_name Settings
extends RefCounted
## The player's own settings, kept on this computer for every game (not in a
## save): user://settings.json. The Options screen (Esc, then Options) sets
## them. For now one setting (tracker #7):
##   hover_tips  "first_week": the hover tips show for the first days of a
##               game (tuning ui.hover_tip_days), then stop;
##               "always", or "off".
##   fullscreen  true (the start, tracker #37): the game fills the screen,
##               drawn at the biggest whole-number scale that fits (4 times
##               on a 1920 x 1080 screen). F11 or Options switches it.

const PATH := "user://settings.json"
const HOVER_TIPS := ["first_week", "always", "off"]
const MUSIC := ["medium", "high", "off", "low"]

static var values: Dictionary = {"hover_tips": "first_week", "show_pinned_job": true, "show_unlocks_on_map": true, "music": "medium", "motion": true, "weather_effects": true, "fullscreen": true}
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
		var music := str((parsed as Dictionary).get("music", "medium"))
		if MUSIC.has(music):
			values["music"] = music
		for k in ["show_pinned_job", "show_unlocks_on_map", "motion", "weather_effects", "fullscreen"]:
			if (parsed as Dictionary).has(k):
				values[k] = bool(parsed[k])


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


## How loud the music plays: "off", "low", "medium" (the start) or "high".
static func music() -> String:
	load_once()
	return str(values.get("music", "medium"))


## Moves the music setting on to the next loudness, saves it and returns it.
static func next_music() -> String:
	load_once()
	var i := MUSIC.find(music())
	values["music"] = MUSIC[(i + 1) % MUSIC.size()]
	save()
	return values["music"]


## An on/off setting (the jobs spec's "Show pinned job" and "Show unlocks
## on the map"; both on unless turned off).
static func flag(key: String) -> bool:
	load_once()
	return bool(values.get(key, true))


static func toggle(key: String) -> bool:
	load_once()
	values[key] = not flag(key)
	save()
	return bool(values[key])


## Whether hover tips show on this day of the game.
static func tips_showing(day: int, first_days: int) -> bool:
	match hover_tips():
		"always":
			return true
		"off":
			return false
	return day <= first_days


## Fills the screen or shows a window, as the setting says. A window is
## sized to the biggest whole-number scale of 480 x 270 that fits the
## screen's usable area, so it is never shrunk a step by its title bar.
static func apply_window() -> void:
	load_once()
	if DisplayServer.get_name() == "headless":
		return
	if flag("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var area := DisplayServer.screen_get_usable_rect()
	var k := maxi(1, mini(int((area.size.x - 16) / 480.0), int((area.size.y - 48) / 270.0)))
	var size := Vector2i(480 * k, 270 * k)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)
