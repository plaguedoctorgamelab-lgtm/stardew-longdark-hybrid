class_name Music
extends Node
## Plays Mark's music. Which piece plays comes from data/content/music.json:
## the first row whose "when" matches the moment (title, winter, night,
## indoors, outdoors). A change of piece fades across; a piece that ends is
## played again after a little quiet. The volume is the player's own setting
## (Options: Music), kept in user://settings.json.

var content: ContentDB
var tuning: Tuning
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _file: String = ""
var _fade: float = 1.0          # 0 to 1: how far the latest fade has come
var _quiet_left: float = -1.0   # counting down the gap before a replay
var _streams: Dictionary = {}   # file -> AudioStream


func setup(c: ContentDB, t: Tuning) -> void:
	content = c
	tuning = t
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -80.0
		p.finished.connect(_on_finished.bind(i))
		add_child(p)
		_players.append(p)


## The row id that matches the moment: "title", or the game's state.
static func pick(rows: Array, on_title: bool, season: String, night: bool, indoors: bool) -> String:
	for r: Dictionary in rows:
		var ok := false
		match str(r["when"]):
			"title":
				ok = on_title
			"winter":
				ok = not on_title and season == "winter"
			"night":
				ok = not on_title and night and not indoors
			"indoors":
				ok = not on_title and indoors
			"outdoors":
				ok = not on_title and not indoors
		if ok:
			return str(r["id"])
	return ""


## Called every frame with the moment; fades to the right piece.
func update(delta: float, on_title: bool, season: String, night: bool, indoors: bool) -> void:
	if _players.is_empty():
		return
	var id := pick(content.rows("music"), on_title, season, night, indoors)
	var file := str(content.row("music", id)["file"]) if id != "" else ""
	if file != _file:
		_switch(file)
	var fade_s := maxf(0.05, tuning.num("audio.fade_seconds"))
	_fade = minf(1.0, _fade + delta / fade_s)
	var vol := volume_db()
	var cur := _players[_active]
	var old := _players[1 - _active]
	cur.volume_db = lerpf(-60.0, vol, _fade) if vol > -79.0 else -80.0
	old.volume_db = lerpf(vol, -60.0, _fade) if vol > -79.0 else -80.0
	if _fade >= 1.0 and old.playing:
		old.stop()
	if _quiet_left >= 0.0:
		_quiet_left -= delta
		if _quiet_left < 0.0 and _file != "":
			cur.play()


func _switch(file: String) -> void:
	_file = file
	_active = 1 - _active
	_fade = 0.0 if _players[1 - _active].playing else 1.0
	_quiet_left = -1.0
	var p := _players[_active]
	p.stop()
	if file == "":
		return
	if not _streams.has(file):
		_streams[file] = load(file) if ResourceLoader.exists(file) else null
	p.stream = _streams[file]
	if p.stream != null:
		p.volume_db = -60.0
		p.play()


func _on_finished(i: int) -> void:
	if i == _active:
		_quiet_left = tuning.num("audio.gap_seconds")


## The setting's loudness in decibels; -80 is off.
func volume_db() -> float:
	var level := Settings.music()
	if level == "off":
		return -80.0
	return float((tuning.value("audio.music_db") as Dictionary)[level])


## The file playing now ("" for none): for tests.
func current_file() -> String:
	return _file
