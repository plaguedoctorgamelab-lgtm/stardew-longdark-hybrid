class_name JobCardScreen
extends Control
## The finishing card (jobs spec, "Medium"): play pauses and a card rises in
## the middle of the screen with the job's type icon, its name and a "DONE"
## stamp that thumps on; the rewards land one by one, each saying where it
## went; Something more comes last, and any jobs it unlocked are listed at
## the foot. It cannot be closed before the stamp lands. Also shows the
## season's card on the first morning of a season, and "While you were
## away..." for an older save.

signal finished(card: Dictionary)

# Mark's card picture (250 x 170) is stretched as a nine-patch to this
# size: the corners (bolts, the leaves in the top right) stay as drawn and
# the paper between grows, so a big job's rewards fit on it (tracker #38).
const CARD_SIZE := Vector2(330, 196)
const CARD_MARGINS := [84, 80, 122, 48]   # left, top, right, bottom, of the picture
# Where the words go on the card, clear of its frame, bolts and leaves.
const ICON_AT := Vector2(44, 32)
const TITLE_AT := Vector2(56, 31)
const TITLE_W := 150.0         # stops short of the leaves
const LINES_AT := Vector2(44, 48)
const LINES_W := 192.0         # left of the DONE stamp
const STAMP_AT := Vector2(244, 92)
const FOOT_W := 196.0          # left of the stamp, between the bottom bolts
const FOOT_MAX_Y := 148.0      # the foot's top, at most

var session: GameSession
var card: Dictionary = {}
var _panel: Panel
var _season_pic: TextureRect
var _icon: TextureRect
var _title: Label
var _stamp: Control
var _stamp_label: Label
var _lines: VBoxContainer
var _foot: Label
var _close_hint: Label
var _age: float = 0.0
var _shown_lines: int = 0
var _all_lines: Array = []


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = Panel.new()
	_panel.size = CARD_SIZE
	_panel.position = ((size - _panel.size) / 2.0).round()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	if Art.has_picture("ui_job_card"):
		var sb := StyleBoxTexture.new()
		sb.texture = Art.texture("ui_job_card")
		sb.texture_margin_left = CARD_MARGINS[0]
		sb.texture_margin_top = CARD_MARGINS[1]
		sb.texture_margin_right = CARD_MARGINS[2]
		sb.texture_margin_bottom = CARD_MARGINS[3]
		# The frame's wood repeats along the longer sides rather than stretching.
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		_panel.add_theme_stylebox_override("panel", sb)
	_season_pic = TextureRect.new()
	_season_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_season_pic.stretch_mode = TextureRect.STRETCH_SCALE
	_season_pic.size = Vector2(150, 150)
	_season_pic.position = ((size - _season_pic.size) / 2.0).round()
	_season_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_season_pic)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = ICON_AT
	_icon.size = Vector2(10, 10)
	_panel.add_child(_icon)
	_title = Label.new()
	_title.position = TITLE_AT
	_title.size = Vector2(TITLE_W, 12)
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_title.add_theme_font_size_override("font_size", 8)
	_panel.add_child(_title)
	_stamp = Control.new()
	_stamp.size = Vector2(56, 26)
	_stamp.position = STAMP_AT
	_stamp.pivot_offset = _stamp.size / 2.0
	_stamp.rotation = -0.18
	_panel.add_child(_stamp)
	var stamp_bg := TextureRect.new()
	stamp_bg.texture = Art.texture("ui_stamp") if Art.has_picture("ui_stamp") else null
	stamp_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stamp_bg.stretch_mode = TextureRect.STRETCH_SCALE
	stamp_bg.size = _stamp.size
	_stamp.add_child(stamp_bg)
	_stamp_label = Label.new()
	_stamp_label.size = _stamp.size
	_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stamp_label.add_theme_font_size_override("font_size", 11)
	_stamp_label.add_theme_color_override("font_color", Color8(178, 34, 40))
	_stamp.add_child(_stamp_label)
	_lines = VBoxContainer.new()
	_lines.position = LINES_AT
	_lines.custom_minimum_size = Vector2(LINES_W, 0)
	_lines.add_theme_constant_override("separation", 0)
	_panel.add_child(_lines)
	_foot = Label.new()
	_foot.size = Vector2(FOOT_W, 20)
	_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_foot.add_theme_font_size_override("font_size", 6)
	_foot.add_theme_color_override("font_color", KitStyle.PINE)
	_panel.add_child(_foot)
	_close_hint = Label.new()
	_close_hint.text = s.content.text("jt_card_close")
	_close_hint.add_theme_font_size_override("font_size", 6)
	_close_hint.add_theme_color_override("font_color", Color(KitStyle.TEXT_DARK, 0.6))
	_panel.add_child(_close_hint)


func open(c: Dictionary) -> void:
	card = c
	visible = true
	_age = 0.0
	_shown_lines = 0
	_all_lines = []
	for ch in _lines.get_children():
		ch.queue_free()
	var cs := session.content
	var kind := str(c["kind"])
	_season_pic.visible = kind == "season"
	_panel.visible = true
	_stamp.visible = kind == "done"
	_stamp.scale = Vector2(2.2, 2.2)
	_stamp.modulate.a = 0.0
	_stamp_label.text = cs.text("jt_done_stamp")
	_foot.text = ""
	match kind:
		"done":
			var k := str(c["key"])
			var jb := session.jobs
			_icon.texture = Art.texture(jb.type_row(k)["icon"]) if jb.known.has(k) else null
			_title.text = jb.def(k)["name"] if jb.known.has(k) else ""
			for e: Dictionary in c["lines"]:
				_all_lines.append([str(e["icon"]), str(e["text"])])
			if str(c.get("note", "")) != "":
				_all_lines.append(["job_kind_note", str(c["note"])])
			if str(c.get("more", "")) != "":
				_all_lines.append(["reward_more_flip", str(c["more"])])
			if not (c["unlocked"] as Array).is_empty():
				_foot.text = cs.text("jt_new_on_clipboard", {"list": ", ".join(PackedStringArray(c["unlocked"]))})
		"season":
			var sn := str(c["season"])
			_icon.texture = null
			_title.text = cs.text("season_" + sn)
			_season_pic.texture = Art.texture("ui_season_" + sn) if Art.has_picture("ui_season_" + sn) else null
			_panel.visible = _season_pic.texture == null
			if int(c["retired"]) == 0 and int(c["new"]) == 0:
				_all_lines.append(["mark_leaf", cs.text("jt_season_none")])
			else:
				_all_lines.append(["mark_leaf", cs.text("jt_season_retired", {"n": c["retired"]})])
				_all_lines.append(["job_kind_note", cs.text("jt_season_new", {"n": c["new"]})])
		"away":
			_icon.texture = Art.texture("job_kind_note")
			_title.text = cs.text("jt_away_title")
			for j: Dictionary in c["jobs"]:
				_all_lines.append(["mark_tick", cs.text("jt_away_line", {"name": j["name"]})])
				for e: Dictionary in j["lines"]:
					_all_lines.append([str(e["icon"]), "   " + str(e["text"])])
	_layout_season()


## The season's card is Mark's card picture, with the words on its paper.
func _layout_season() -> void:
	if str(card.get("kind", "")) == "season" and _season_pic.texture != null:
		_lines.reparent(self)
		_lines.position = _season_pic.position + Vector2(20, 92)
		_lines.custom_minimum_size = Vector2(112, 0)
		_title.reparent(self)
		_title.position = _season_pic.position + Vector2(20, 76)
		_title.size = Vector2(112, 16)
		_close_hint.reparent(self)
		_close_hint.position = _season_pic.position + Vector2(20, 130)
		_close_hint.add_theme_color_override("font_color", Color(KitStyle.TEXT_DARK, 0.6))
	else:
		for n: Control in [_lines, _title, _close_hint]:
			if n.get_parent() != _panel:
				n.reparent(_panel)
		_lines.position = LINES_AT
		_lines.custom_minimum_size = Vector2(LINES_W, 0)
		_title.position = TITLE_AT
		_title.size = Vector2(TITLE_W, 12)
		_close_hint.position = Vector2(LINES_AT.x, _panel.size.y + 2)
		_close_hint.add_theme_color_override("font_color", KitStyle.TEXT_LIGHT)


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	# The stamp thumps on in its first moments.
	if _stamp.visible:
		var t := clampf(_age / 0.35, 0.0, 1.0)
		_stamp.scale = Vector2.ONE * lerpf(2.2, 1.0, t * t)
		_stamp.modulate.a = t
	# Rewards land one by one.
	var due := int(floor((_age - 0.5) / 0.35)) + 1
	while _shown_lines < mini(due, _all_lines.size()):
		var e: Array = _all_lines[_shown_lines]
		_lines.add_child(_line(e[0], e[1]))
		_shown_lines += 1
	_foot.position = Vector2(LINES_AT.x, minf(_lines.position.y + _lines.get_combined_minimum_size().y + 2, FOOT_MAX_Y))
	_close_hint.visible = can_close()


func _line(icon: String, text: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.texture = Art.texture(icon)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(10, 10)
	h.add_child(ic)
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(_lines.custom_minimum_size.x - 16, 0)
	# Many lines (a big job's rewards) shrink a size so they stay on the paper.
	var small := str(card.get("kind", "")) == "season" or _all_lines.size() > 7
	l.add_theme_font_size_override("font_size", 6 if small else 7)
	h.add_child(l)
	return h


func can_close() -> bool:
	return _age >= session.tuning.num("jobs.card_close_wait_seconds")


## Closes the card, if the stamp has landed. True when it closed.
func try_close() -> bool:
	if not can_close():
		return false
	# Show every line before going, so nothing is missed.
	if _shown_lines < _all_lines.size():
		_age = 999.0
		return false
	visible = false
	finished.emit(card)
	return true


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		try_close()
