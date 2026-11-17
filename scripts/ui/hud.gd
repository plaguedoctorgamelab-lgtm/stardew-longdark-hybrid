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
var slot_keys: Array[Label] = []
var debug_label: Label
var money_label: Label
var hint_label: Label
var _message_time: float = 0.0
var _hint_wait: float = 0.0


## The item bar: the first backpack slots (tuned, 10), one row, each marked
## with the number key that holds it. The rest of the backpack is on E.
func rebuild_slots() -> void:
	for n: Node in slot_panels + slot_icons + slot_counts + slot_keys:
		n.queue_free()
	slot_panels.clear()
	slot_icons.clear()
	slot_counts.clear()
	slot_keys.clear()
	var n := mini(session.bar_slots(), session.backpack.size())
	var x0 := (480 - SLOT * n) / 2.0
	for i in n:
		var p := Panel.new()
		p.position = Vector2(x0 + i * SLOT, 250)
		p.size = Vector2(SLOT, SLOT)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(p)
		var icon := TextureRect.new()
		icon.position = p.position + Vector2(1, 1)
		_fit_icon(icon)
		root.add_child(icon)
		var cnt := _label(p.position + Vector2(9, 7))
		var key := _label(p.position + Vector2(1, -2))
		key.text = str((i + 1) % 10)
		key.add_theme_font_size_override("font_size", 6)
		key.modulate = Color(1, 0.95, 0.8, 0.85)
		slot_panels.append(p)
		slot_icons.append(icon)
		slot_counts.append(cnt)
		slot_keys.append(key)


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
	var mbox := Panel.new()
	mbox.position = Vector2(398, 37)
	mbox.size = Vector2(80, 12)
	mbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mbox)
	money_label = _label(Vector2(402, 37))
	weather_icon = TextureRect.new()
	weather_icon.position = Vector2(458, 15)
	_fit_icon(weather_icon)
	root.add_child(weather_icon)

	energy_bar = _bar(Vector2(462, 196), Color(0.95, 0.8, 0.2))
	warmth_bar = _bar(Vector2(448, 196), Color(0.95, 0.4, 0.25))
	var el := _label(Vector2(461, 258))
	el.text = "E"
	var wl := _label(Vector2(447, 258))
	wl.text = "W"

	rebuild_slots()

	message_label = _label(Vector2(0, 226))
	message_label.size = Vector2(480, 10)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# What X and C do right here, always shown just over the item bar.
	hint_label = _label(Vector2(0, 238))
	hint_label.size = Vector2(480, 10)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	for l: Label in [message_label, hint_label]:
		l.add_theme_color_override("font_outline_color", Color(0.12, 0.08, 0.05))
		l.add_theme_constant_override("outline_size", 3)
	survey_bar = ProgressBar.new()
	survey_bar.position = Vector2(200, 218)
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
	money_label.text = session.content.text("hud_money", {"n": session.park.money.wallet})
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
	var tremble := session.compass_trembling()
	for i in mini(session.backpack.size(), slot_icons.size()):
		var s := session.backpack.slot(i)
		slot_icons[i].position = slot_panels[i].position + Vector2(1, 1)
		if s.is_empty():
			slot_icons[i].texture = null
			slot_counts[i].text = ""
		else:
			slot_icons[i].texture = Art.texture(session.content.row("items", s["item"])["icon"])
			slot_counts[i].text = str(s["count"]) if int(s["count"]) > 1 else ""
			# The compass needle trembles near something buried.
			if tremble and session.family_of(s["item"]) == "compass":
				slot_icons[i].position += Vector2(randi_range(-1, 1), 0)
		slot_panels[i].self_modulate = Color(1.6, 1.4, 0.6) if i == session.selected_slot else Color.WHITE
	_hint_wait -= delta
	if _hint_wait <= 0.0:
		_hint_wait = 0.2
		var parts: PackedStringArray = []
		for h in [session.guide.x_hint(), session.guide.use_hint()]:
			if h != "":
				parts.append(h)
		hint_label.text = "     ".join(parts)
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)
	debug_label.visible = session.debug_overlay
	if session.debug_overlay:
		var t := session.ranger_tile()
		var ch := session.world.chunk_of(t)
		debug_label.text = "tile %d,%d  chunk %d,%d  %s  %s  fps %d" % [t.x, t.y, ch.x, ch.y, session.ground_here(), session.current_weather(), Engine.get_frames_per_second()]


## Icons are drawn at 32 x 32 and shown in a 16-unit slot; the screen is
## scaled up, so all their detail still shows.
static func _fit_icon(r: TextureRect) -> void:
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size = Vector2(16, 16)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
