class_name Screenshot
extends RefCounted
## F12: saves what's on screen to the player's Downloads folder, named with
## the game's name and the date and time, as in
## "Strange Ranger 2026-11-22 09-58-12.png". Two in the same second get
## " (2)", " (3)" and so on. Without a Downloads folder it saves to the
## game's own user folder instead.


## The file name for a picture taken at `when` (a Time datetime dictionary).
static func file_name(game: String, when: Dictionary, n: int = 1) -> String:
	var stamp := "%04d-%02d-%02d %02d-%02d-%02d" % [int(when["year"]), int(when["month"]), int(when["day"]), int(when["hour"]), int(when["minute"]), int(when["second"])]
	return "%s %s%s.png" % [game, stamp, "" if n <= 1 else " (%d)" % n]


## Where pictures go: Downloads, or the game's user folder.
static func folder() -> String:
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		dir = ProjectSettings.globalize_path("user://screenshots")
		DirAccess.make_dir_recursive_absolute(dir)
	return dir


## A path in `dir` not yet taken.
static func free_path(dir: String, game: String, when: Dictionary) -> String:
	var n := 1
	var path := dir.path_join(file_name(game, when, n))
	while FileAccess.file_exists(path):
		n += 1
		path = dir.path_join(file_name(game, when, n))
	return path


## Saves the viewport's last frame. Returns the path, or "" if it failed.
static func take(viewport: Viewport) -> String:
	var img := viewport.get_texture().get_image()
	if img == null:
		return ""
	var game := str(ProjectSettings.get_setting("application/config/name", "Game"))
	var path := free_path(folder(), game, Time.get_datetime_dict_from_system())
	return path if img.save_png(path) == OK else ""
