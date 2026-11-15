class_name Hud
extends CanvasLayer
## The plain on-screen display: date, time, weather symbol, energy and warmth
## bars, the item bar along the bottom, a line for messages and the survey
## progress.

const SLOT := 18

var session: GameSession
var root: Control
var date_label: Label
var time_label: Label
var weather_icon: TextureRect
var energy_bar: ProgressBar
var warmth_bar: ProgressBar
var status_label: Label
var message_label: Label
var survey_bar: ProgressBar
var slot_panels: Array[Panel] = []
var slot_icons: Array[TextureRect] = []
var slot_counts: Array[Label] = []
var debug_label: Label
var _message_time: float = 0.0


func setup(s: GameSession, theme: Theme) -> void:
	session = s
	layer = 5
	root = Control.new()
	root.theme = theme
	root.size = Vector2(480, 270)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var box := Panel.new()
	box.position = Vector2(398, 2)
	box.size = Vector2(80, 34)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	date_label = _label(Vector2(402, 3))
	time_label = _label(Vector2(402, 13))
	status_label = _label(Vector2(402, 23))
	weather_icon = TextureRect.new()
	weather_icon.position = Vector2(458, 15)
	weather_icon.size = Vector2(16, 16)
	root.add_child(weather_icon)

	energy_bar = _bar(Vector2(462, 196), Color(0.95, 0.8, 0.2))
	warmth_bar = _bar(Vector2(448, 196), Color(0.95, 0.4, 0.25))
	var el := _label(Vector2(461, 258))
	el.text = "E"
	var wl := _label(Vector2(447, 258))
	wl.text = "W"

	var bar_w := SLOT * session.backpack.size()
	var x0 := (480 - bar_w) / 2.0
	for i in session.backpack.size():
		var p := Panel.new()
		p.position = Vector2(x0 + i * SLOT, 250)
		p.size = Vector2(SLOT, SLOT)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		var icon := TextureRect.new()
		icon.position = p.position + Vector2(1, 1)
		icon.size = Vector2(16, 16)
		root.add_child(icon)
		var cnt := _label(p.position + Vector2(9, 7))
		slot_panels.append(p)
		slot_icons.append(icon)
		slot_counts.append(cnt)

	message_label = _label(Vector2(0, 236))
	message_label.size = Vector2(480, 10)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survey_bar = ProgressBar.new()
	survey_bar.position = Vector2(200, 226)
	survey_bar.size = Vector2(80, 6)
	survey_bar.show_percentage = false
	survey_bar.max_value = 1.0
	survey_bar.visible = false
	root.add_child(survey_bar)
	debug_label = _label(Vector2(2, 2))
	debug_label.visible = false

	session.message.connect(show_message)
	session.survey_changed.connect(func(active: bool, progress: float) -> void:
		survey_bar.visible = active
		survey_bar.value = progress)


func _label(pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func _bar(pos: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = pos
	b.size = Vector2(10, 60)
	b.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	b.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.08, 0.08, 0.85)
	bg.border_color = Color(0.3, 0.2, 0.15)
	bg.set_border_width_all(1)
	b.add_theme_stylebox_override("background", bg)
	root.add_child(b)
	return b


func show_message(text: String) -> void:
	if text.is_empty():
		return
	message_label.text = text
	_message_time = 4.0


func _process(delta: float) -> void:
	if session == null:
		return
	var c := session.clock
	date_label.text = session.content.text("hud_date", {"season": session.content.text("season_" + c.season_name()).substr(0, 3), "day": c.day, "year": c.year})
	time_label.text = c.time_text()
	weather_icon.texture = Art.texture(session.weather_icon())
	energy_bar.max_value = session.needs.max_energy()
	energy_bar.value = session.needs.energy
	warmth_bar.max_value = session.needs.max_warmth()
	warmth_bar.value = session.needs.warmth
	var st: PackedStringArray = []
	if session.needs.is_exhausted():
		st.append(session.content.text("hud_exhausted"))
	if session.needs.is_chilled():
		st.append(session.content.text("hud_chilled"))
	status_label.text = " ".join(st)
	for i in session.backpack.size():
		var s := session.backpack.slot(i)
		if s.is_empty():
			slot_icons[i].texture = null
			slot_counts[i].text = ""
		else:
			slot_icons[i].texture = Art.texture(session.content.row("items", s["item"])["icon"])
			slot_counts[i].text = str(s["count"]) if int(s["count"]) > 1 else ""
		slot_panels[i].self_modulate = Color(1.6, 1.4, 0.6) if i == session.selected_slot else Color.WHITE
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	debug_label.visible = session.debug_overlay
	if session.debug_overlay:
		var t := session.ranger_tile()
		var ch := session.world.chunk_of(t)
		debug_label.text = "tile %d,%d  chunk %d,%d  %s  %s  fps %d" % [t.x, t.y, ch.x, ch.y, session.ground_here(), session.current_weather(), Engine.get_frames_per_second()]
