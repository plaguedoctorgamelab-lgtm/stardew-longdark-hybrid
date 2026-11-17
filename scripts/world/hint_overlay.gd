class_name HintOverlay
extends Node2D
## Drawn over the world and over rooms: the square the held item would go on
## (green where it may, red where it may not), and a "?" over anything with
## something new to read or do. Placeholder drawing until the art arrives.

const TILE := 16

var session: GameSession
var _time: float = 0.0
var _wait: float = 0.0
var _aim: Dictionary = {}
var _marks: Array[Vector2] = []


func setup(s: GameSession) -> void:
	session = s
	z_index = 40


func _process(delta: float) -> void:
	if session == null:
		return
	_time += delta
	_wait -= delta
	if _wait <= 0.0:
		_wait = 0.2
		_aim = session.guide.aim()
		_marks = session.guide.markers()
	queue_redraw()


func _draw() -> void:
	if session == null:
		return
	if not _aim.is_empty():
		var t: Vector2i = _aim["tile"]
		var c := Color(0.45, 1.0, 0.45, 0.8) if bool(_aim["ok"]) else Color(1.0, 0.35, 0.3, 0.8)
		draw_rect(Rect2(Vector2(t) * TILE + Vector2(0.5, 0.5), Vector2(TILE - 1, TILE - 1)), c, false, 1.0)
	var font := ThemeDB.fallback_font
	var bob := sin(_time * 3.0) * 1.5
	for m in _marks:
		var p := m * TILE + Vector2(0, bob)
		draw_circle(p, 5.5, Color(0.15, 0.1, 0.05, 0.9))
		draw_circle(p, 4.5, Color(1.0, 0.85, 0.3))
		draw_string(font, p + Vector2(-2.5, 3.5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.2, 0.12, 0.05))
