class_name JobNote
extends Control
## The job in view while playing (jobs spec): a small paper note pinned in the
## top left, with the job's type icon and name and its next step underneath;
## clicking it opens the Jobs page at that job. Under it, toasts slide in for
## the small moments (a job added or noticed, a step done or undone, a count
## at each quarter), stay four seconds and fade; up to three stack. A "!"
## pops over the ranger when a job is noticed.

signal note_clicked(key: String)

const NOTE_SIZE := Vector2(132, 26)

var session: GameSession
var _note: Panel
var _icon: TextureRect
var _name: Label
var _step: Label
var _toasts: Array = []        # [{panel, time}]
var _waiting: Array = []       # toasts not yet shown: [icon, color, text]
var _key: String = ""
var _last_step: String = ""
var _done_time: float = 0.0
var _morning_time: float = 0.0
var bubble_time: float = 0.0   # the "!" over the ranger
var bubble_at: Vector2 = Vector2.ZERO   # the ranger on screen (main sets it)
var _bubble: TextureRect


func setup(s: GameSession) -> void:
	session = s
	position = Vector2.ZERO
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note = Panel.new()
	_note.position = Vector2(3, 3)
	_note.size = NOTE_SIZE
	_note.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := KitStyle._box(KitStyle.PAPER, KitStyle.WOOD, 1, 1)
	paper.shadow_color = Color(KitStyle.INK, 0.35)
	paper.shadow_size = 2
	paper.shadow_offset = Vector2(1, 2)
	_note.add_theme_stylebox_override("panel", paper)
	_note.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			note_clicked.emit(_key))
	add_child(_note)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size = Vector2(11, 11)
	_icon.position = Vector2(6, 4)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(_icon)
	_name = _label(Vector2(19, 2), 7, KitStyle.TEXT_DARK)
	var pin := TextureRect.new()
	pin.texture = Art.texture("mark_pin")
	pin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pin.size = Vector2(9, 9)
	pin.position = Vector2(NOTE_SIZE.x - 11, -3)
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(pin)
	_step = _label(Vector2(8, 13), 6, Color8(52, 60, 110))
	_bubble = TextureRect.new()
	_bubble.texture = Art.texture("mark_bubble")
	_bubble.size = Vector2(12, 12)
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	s.jobs.toast.connect(_on_toast)
	s.jobs.noticed_now.connect(func(_k: String) -> void: bubble_time = 1.6)
	s.day_began.connect(func() -> void: _morning_time = 4.0)


func _label(pos: Vector2, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(NOTE_SIZE.x - pos.x - 12, 10)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_note.add_child(l)
	return l


func _on_toast(icon: String, color: Color, text: String, _sound: String) -> void:
	_waiting.append([icon, color, text])


func _process(delta: float) -> void:
	if session == null:
		return
	_update_note(delta)
	var most := session.tuning.integer("jobs.toasts_most")
	while not _waiting.is_empty() and _toasts.size() < most:
		var w: Array = _waiting.pop_front()
		_toasts.append({"panel": _make_toast(w[0], w[1], w[2]), "time": session.tuning.num("jobs.toast_seconds")})
	var y := (_note.position.y + NOTE_SIZE.y + 3) if _note.visible else 3.0
	for t: Dictionary in _toasts.duplicate():
		t["time"] = float(t["time"]) - delta
		var p: Panel = t["panel"]
		if float(t["time"]) <= 0.0:
			p.queue_free()
			_toasts.erase(t)
			continue
		var age := session.tuning.num("jobs.toast_seconds") - float(t["time"])
		# Slides in from the left edge, fades at the end.
		p.position = Vector2(lerpf(-p.size.x, 3.0, clampf(age * 4.0, 0.0, 1.0)), y)
		p.modulate.a = clampf(float(t["time"]), 0.0, 1.0)
		y += p.size.y + 2
	if bubble_time > 0.0:
		bubble_time -= delta
	_bubble.visible = bubble_time > 0.0
	if _bubble.visible:
		_bubble.position = (bubble_at + Vector2(-6, -34 - 3.0 * sin(bubble_time * 8.0))).round()


func _make_toast(icon: String, color: Color, text: String) -> Panel:
	var p := Panel.new()
	p.size = Vector2(150, 14)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Art.has_picture("ui_toast"):
		var sb := StyleBoxTexture.new()
		sb.texture = Art.texture("ui_toast")
		sb.set_texture_margin_all(5)
		p.add_theme_stylebox_override("panel", sb)
	else:
		p.add_theme_stylebox_override("panel", KitStyle.tag())
	var stripe := ColorRect.new()
	stripe.color = color
	stripe.position = Vector2(4, 3)
	stripe.size = Vector2(2, 8)
	p.add_child(stripe)
	var ic := TextureRect.new()
	ic.texture = Art.texture(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size = Vector2(10, 10)
	ic.position = Vector2(8, 2)
	p.add_child(ic)
	var l := Label.new()
	l.text = text
	l.position = Vector2(20, 0)
	l.size = Vector2(126, 12)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	p.add_child(l)
	add_child(p)
	return p


## The note follows the pinning rules: the pinned job, else the one last
## worked on, else how many are waiting; with none, "Nothing on the
## clipboard" for a moment each morning.
func _update_note(delta: float) -> void:
	var jb := session.jobs
	var c := session.content
	if not Settings.flag("show_pinned_job"):
		_note.visible = false
		return
	if _done_time > 0.0:
		_done_time -= delta
		_note.visible = true
		return
	var k := jb.shown_job()
	if _key != "" and k != _key and jb.is_done(_key):
		# The job just finished: "Done!" briefly.
		_step.text = c.text("jt_pinned_done")
		_done_time = 1.5
		_key = ""
		return
	_key = k
	if k != "":
		var d := jb.def(k)
		_note.visible = true
		_icon.texture = Art.texture(jb.type_row(k)["icon"])
		_name.text = d["name"]
		var i := jb.next_step(k)
		var step := ""
		if i >= 0:
			step = jb.step_label(k, i)
			var ck := jb.check(k, i)
			if int(ck["total"]) > 1:
				step += "  " + c.text("jt_count", {"done": ck["n"], "total": ck["total"]})
		_step.text = step
		return
	var n := jb.active_count()
	_icon.texture = Art.texture("job_kind_note")
	if n > 0:
		_note.visible = true
		_name.text = c.text("jt_waiting_one") if n == 1 else c.text("jt_waiting", {"n": n})
		_step.text = ""
		return
	if _morning_time > 0.0:
		_morning_time -= delta
		_note.visible = true
		_name.text = c.text("jt_nothing")
		_step.text = ""
		return
	_note.visible = false
