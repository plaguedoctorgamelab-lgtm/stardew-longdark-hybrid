class_name FortuneScreen
extends Control
## Esme's reading (Phase 4b, step 11): her three cards on the velvet cloth,
## turned over one by one, the Sky, the Path and the Heart, each with what
## she says about it. Any key or click closes it once the cards are turned.

const CLOTH_SCALE := 1.6
const CARD_SCALE := 1.4
const TURN_SECONDS := 0.45

var session: GameSession
var reading: Dictionary = {}
var _t: float = 0.0
var _labels: Array[Label] = []
var _intro: Label
var _hint: Label


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_intro = _label(Vector2(40, 6), Vector2(400, 14), 8, HORIZONTAL_ALIGNMENT_CENTER)
	for i in 3:
		_labels.append(_label(Vector2(56 + i * 124, 156), Vector2(118, 70), 7, HORIZONTAL_ALIGNMENT_CENTER))
	_hint = _label(Vector2(40, 254), Vector2(400, 12), 7, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.text = s.content.text("fortune_close")
	visible = false


func _label(at: Vector2, sz: Vector2, fs: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = at
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", KitStyle.CREAM)
	l.add_theme_color_override("font_outline_color", KitStyle.INK)
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func open(r: Dictionary) -> void:
	reading = r
	_t = 0.0
	_intro.text = str(r.get("intro", ""))
	var cards: Array = r.get("cards", [])
	for i in 3:
		_labels[i].text = ""
		_labels[i].visible = false
		if i < cards.size():
			var c: Dictionary = cards[i]
			# The card's name heads it, so the line doesn't say it again.
			var nm := session.content.text("fortune_card_" + str(c["card"]))
			_labels[i].text = nm.to_upper() + "\n" + str(c["text"]).trim_prefix(nm + ". ")
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func turned() -> bool:
	return _t >= TURN_SECONDS * 3.0


func try_close() -> void:
	if turned():
		close()
	else:
		_t = TURN_SECONDS * 3.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		try_close()
		accept_event()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in 3:
		_labels[i].visible = _t >= TURN_SECONDS * (i + 1)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(KitStyle.INK, 0.78))
	var cloth := Art.texture("fortune_cloth")
	var csz := Vector2(cloth.get_size()) * CLOTH_SCALE if cloth != null else Vector2(384, 192)
	var cr := Rect2(((size - csz) / 2.0 + Vector2(0, 4)).round(), csz)
	if cloth != null:
		draw_texture_rect(cloth, cr, false)
	else:
		draw_rect(cr, Color8(70, 40, 92))
	var cards: Array = reading.get("cards", [])
	var back := Art.texture("fortune_card_back")
	for i in 3:
		var face := Art.texture("fortune_card_" + (str((cards[i] as Dictionary)["card"]) if i < cards.size() else "sky"))
		var tex := face if _t >= TURN_SECONDS * (i + 1) else back
		if tex == null:
			continue
		var sz := Vector2(tex.get_size()) * CARD_SCALE
		# Turning over: the card narrows to its edge, then widens face up.
		var k := clampf((_t - TURN_SECONDS * i) / TURN_SECONDS, 0.0, 1.0)
		var w := absf(cos(k * PI)) if k < 1.0 else 1.0
		var cx := 115.0 + i * 124.0
		var r := Rect2(Vector2(cx - sz.x * w / 2.0, 44), Vector2(sz.x * w, sz.y)).abs()
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
		draw_texture_rect(tex, Rect2(r.position.round(), r.size.round()), false)
