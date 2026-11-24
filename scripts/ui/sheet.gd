class_name Sheet
extends Control
## One sheet on the ranger's clipboard (the cozy UI plan, 0.7.15). Every
## menu page is a sheet: the same board, the same place, the same size, laid
## out the jobs way. A list of picture cards on the left, the chosen one in
## full on the right under ribbons, with picture tiles, chips (an icon and a
## few words), stamps for what you can do, and key caps along the board's
## foot. A page builds itself from these pieces; nothing floats over it.
##
## Pieces from Art Request 24 (the mount, the badge, the stamp, the key cap,
## the red tile, the picture tabs and the clips) are used when they're in
## art/; until then each has a stand-in drawn here.

signal closed

const FRAME := Rect2(12, 6, 456, 258)
const PAPER := Rect2(42, 44, 396, 192)      # inside the frame's border
const LIST_W := 112.0
const DETAIL_X := PAPER.position.x + LIST_W + 8.0
const DETAIL_W := PAPER.end.x - DETAIL_X - 4.0
const CLIP_AT := Vector2(232, 14)           # the clip's middle, for a sheet's picture
const STAMP_Y := PAPER.end.y - 18.0

var session: GameSession
var list_scroll: ScrollContainer
var list: VBoxContainer
var detail_scroll: ScrollContainer
var detail: VBoxContainer
var stamps: HBoxContainer
var empty_label: Label
var _tabs: HBoxContainer
var _keys: HBoxContainer
var _clip_pic: TextureRect


func setup_sheet(s: GameSession) -> void:
	session = s
	size = Vector2(480, 270)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	if Art.has_picture("ui_clipboard"):
		var frame := TextureRect.new()
		frame.texture = Art.texture("ui_clipboard")
		frame.position = FRAME.position
		frame.size = FRAME.size
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frame)
	else:
		var p := Panel.new()
		p.position = FRAME.position
		p.size = FRAME.size
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
	_clip_pic = TextureRect.new()
	_clip_pic.position = CLIP_AT - Vector2(8, 0)
	_clip_pic.size = Vector2(16, 16)
	_clip_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_clip_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_clip_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip_pic)
	_tabs = HBoxContainer.new()
	_tabs.position = PAPER.position + Vector2(2, 0)
	_tabs.add_theme_constant_override("separation", 2)
	add_child(_tabs)
	var rule := ColorRect.new()
	rule.color = Color(KitStyle.WOOD, 0.35)
	rule.position = Vector2(PAPER.position.x + LIST_W + 3, PAPER.position.y + 16)
	rule.size = Vector2(1, PAPER.size.y - 18)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	list_scroll = ScrollContainer.new()
	list_scroll.position = PAPER.position + Vector2(2, 16)
	list_scroll.size = Vector2(LIST_W, PAPER.size.y - 18)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(list_scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(LIST_W - 8, 0)
	list.add_theme_constant_override("separation", 2)
	list_scroll.add_child(list)
	detail_scroll = ScrollContainer.new()
	detail_scroll.position = Vector2(DETAIL_X, PAPER.position.y + 14)
	detail_scroll.size = Vector2(DETAIL_W, STAMP_Y - PAPER.position.y - 16)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(detail_scroll)
	detail = VBoxContainer.new()
	detail.custom_minimum_size = Vector2(DETAIL_W - 8, 0)
	detail.add_theme_constant_override("separation", 3)
	detail_scroll.add_child(detail)
	stamps = HBoxContainer.new()
	stamps.position = Vector2(DETAIL_X, STAMP_Y)
	stamps.add_theme_constant_override("separation", 4)
	add_child(stamps)
	empty_label = Label.new()
	empty_label.position = PAPER.position + Vector2(8, 26)
	empty_label.size = Vector2(LIST_W - 8, 80)
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	empty_label.add_theme_font_size_override("font_size", 7)
	empty_label.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(empty_label)
	_keys = HBoxContainer.new()
	_keys.position = Vector2(FRAME.position.x + 30, FRAME.end.y - 14)
	_keys.add_theme_constant_override("separation", 6)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)


## The first of these pictures that's in the game, or "".
static func pick(names: Array) -> String:
	for n: Variant in names:
		if Art.has_picture(str(n)):
			return str(n)
	return ""


static func sb(art: String, margin: int, content: float) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = Art.texture(art)
	b.set_texture_margin_all(margin)
	b.set_content_margin_all(content)
	return b


func close() -> void:
	visible = false
	closed.emit()


## The sheet's picture on the clip (Art Request 24's clip_*), when drawn.
func set_clip(pictures: Array) -> void:
	var p := pick(pictures)
	_clip_pic.texture = Art.texture(p) if p != "" else null


func clear(box: Container) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


# --- index tabs -------------------------------------------------------------------

## Paper tabs along the top of the sheet: [{id, label, icon}] (icon may be "").
func set_index_tabs(entries: Array, open_id: String, on_pick: Callable) -> void:
	clear(_tabs)
	for e: Dictionary in entries:
		var open := str(e["id"]) == open_id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(40, 13)
		b.add_theme_font_size_override("font_size", 6)
		b.text = str(e.get("label", ""))
		var icon := str(e.get("icon", ""))
		if icon != "" and Art.has_picture(icon):
			b.icon = Art.texture(icon)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 9)
		var art := pick(["ui_itab_open", "ui_jtab_open"] if open else ["ui_itab", "ui_jtab"])
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb(art, 4, 1) if art != "" else KitStyle.tab(open))
		b.add_theme_color_override("font_color", KitStyle.TEXT_LIGHT if open else KitStyle.TEXT_DARK)
		b.add_theme_color_override("font_hover_color", KitStyle.TEXT_LIGHT if open else KitStyle.INK)
		var id := str(e["id"])
		b.pressed.connect(func() -> void: on_pick.call(id))
		_tabs.add_child(b)


# --- the list side ------------------------------------------------------------------

## A ribbon over a group of cards, in the group's colour, with its picture.
func ribbon(text: String, icon: String, color: Color) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(LIST_W - 10, 12)
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(2)
	p.add_theme_stylebox_override("panel", b)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon != "" and Art.has_picture(icon):
		p.add_child(_pic(icon, Vector2(1, 0), Vector2(11, 11)))
	var l := Label.new()
	l.text = text
	l.position = Vector2(14, -1)
	l.add_theme_font_size_override("font_size", 7)
	KitStyle.over_world(l)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)
	return p


## A card in the list: a picture, a name, and one line drawn below it
## (`foot`, a Control, or null). Pointing at it or clicking it chooses it.
func card(picture: String, name: String, foot: Control, chosen: bool, on_choose: Callable, dim: bool = false) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(LIST_W - 10, 26)
	var art := pick(["ui_jcard_selected"] if chosen else ["ui_jcard"])
	if art != "":
		p.add_theme_stylebox_override("panel", sb(art, 6, 2))
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(KitStyle.PAPER, KitStyle.CORAL if chosen else KitStyle.WOOD, 1, 2))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			on_choose.call())
	p.mouse_entered.connect(func() -> void: on_choose.call())
	if picture != "" and Art.has_picture(picture):
		var pic := _pic(picture, Vector2(3, 3), Vector2(19, 19))
		if dim:
			pic.modulate = Color(1, 1, 1, 0.5)
		p.add_child(pic)
	var l := Label.new()
	l.text = name
	l.position = Vector2(24, 0)
	l.size = Vector2(LIST_W - 36, 12)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.add_theme_font_size_override("font_size", 7)
	l.add_theme_color_override("font_color", Color(KitStyle.TEXT_DARK, 0.6) if dim else KitStyle.TEXT_DARK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	if foot != null:
		foot.position = Vector2(24, 13)
		_ignore_mouse(foot)
		p.add_child(foot)
	return p


## A small dot and a word or two: green when ready, grey when not.
func status_line(text: String, ok: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(5, 5)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var b := StyleBoxFlat.new()
	b.bg_color = Color8(79, 174, 71) if ok else Color8(169, 162, 154)
	b.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", b)
	h.add_child(dot)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", Color8(61, 122, 53) if ok else Color8(150, 70, 50))
	h.add_child(l)
	return h


# --- the detail side ----------------------------------------------------------------

## The top of a detail: the big picture in its mount, the name, and a row
## of chips beneath it.
func header(picture: String, title: String, chips: Array[Control]) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(mount(picture))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(text(title, 10, KitStyle.TEXT_DARK, DETAIL_W - 60))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 3)
	row.add_theme_constant_override("v_separation", 2)
	row.custom_minimum_size = Vector2(DETAIL_W - 60, 0)
	for c in chips:
		row.add_child(c)
	v.add_child(row)
	h.add_child(v)
	return h


## The frame the big picture sits in (Art Request 24's ui_mount).
func mount(picture: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(40, 40)
	if Art.has_picture("ui_mount"):
		p.add_theme_stylebox_override("panel", sb("ui_mount", 6, 0))
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(Color8(251, 243, 223), Color8(201, 167, 122), 2, 1))
	if picture != "" and Art.has_picture(picture):
		p.add_child(_pic(picture, Vector2(4, 4), Vector2(32, 32)))
	return p


## A section ribbon in the detail: "You'll need", "Makes", "Does".
func heading(t: String) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(72, 10)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if Art.has_picture("ui_ribbon_green"):
		p.add_theme_stylebox_override("panel", sb("ui_ribbon_green", 4, 0))
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(KitStyle.PINE, KitStyle.INK, 1, 3, 0))
	var l := Label.new()
	l.text = t
	l.position = Vector2(5, -2)
	l.add_theme_font_size_override("font_size", 7)
	KitStyle.over_world(l)
	l.add_theme_constant_override("outline_size", 2)
	p.add_child(l)
	return p


func text(t: String, sz: int, col: Color, w: float) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	return l


## A line in the game's own voice (a description, a note): handwriting blue.
func voice(t: String) -> Label:
	return text(t, 7, Color8(52, 60, 110), DETAIL_W - 10)


## A row of tiles that wraps.
func tile_row() -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", 3)
	f.add_theme_constant_override("v_separation", 3)
	f.custom_minimum_size = Vector2(DETAIL_W - 10, 0)
	return f


## A 24 x 24 tile: a picture, a number badge in the corner, and a frame:
## "gold" (enough, or a reward), "plain", "grey" (done or not yet) or "red"
## (short). `tip` is kept for the label strip and tests; nothing floats.
func tile(picture: String, badge: String, frame: String = "gold", tip: String = "") -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(24, 24)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.tooltip_text = ""
	p.set_meta("tip", tip)
	var art := ""
	match frame:
		"gold":
			art = pick(["ui_tile_gold", "ui_tile"])
		"grey":
			art = pick(["ui_tile_grey", "ui_tile"])
		"red":
			art = pick(["ui_tile_red", "ui_tile_grey", "ui_tile"])
		_:
			art = pick(["ui_tile"])
	if art != "":
		p.add_theme_stylebox_override("panel", sb(art, 5, 0))
		if frame == "red" and art != "ui_tile_red":
			p.self_modulate = Color(1.0, 0.62, 0.55)
	else:
		p.add_theme_stylebox_override("panel", KitStyle._box(KitStyle.PAPER, KitStyle.CORAL if frame == "red" else KitStyle.WOOD, 1, 2))
	if picture != "" and Art.has_picture(picture):
		p.add_child(_pic(picture, Vector2(4, 4), Vector2(16, 16)))
	if badge != "":
		p.add_child(_badge(badge, frame == "red"))
	return p


func _badge(t: String, short: bool) -> Control:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 5)
	l.add_theme_color_override("font_color", Color.WHITE)
	if Art.has_picture("ui_badge"):
		l.add_theme_stylebox_override("normal", sb("ui_badge", 3, 1))
	else:
		var b := StyleBoxFlat.new()
		b.bg_color = Color8(150, 48, 36) if short else Color8(58, 42, 30)
		b.set_corner_radius_all(3)
		b.content_margin_left = 1.5
		b.content_margin_right = 1.5
		l.add_theme_stylebox_override("normal", b)
	l.position = Vector2(24 - 4 * t.length() - 3, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A chip: an icon (when drawn) and a few words, on a little paper patch.
## `tone` is "" or "good" (green) or "bad" (red).
func chip(icon: String, t: String, tone: String = "") -> Control:
	var pc := PanelContainer.new()
	var b := StyleBoxFlat.new()
	b.bg_color = {"good": Color8(220, 239, 207), "bad": Color8(244, 214, 204)}.get(tone, Color8(239, 220, 184))
	b.set_corner_radius_all(3)
	b.content_margin_left = 1
	b.content_margin_right = 3
	b.content_margin_top = 0
	b.content_margin_bottom = 0
	pc.add_theme_stylebox_override("panel", b)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	if icon != "" and Art.has_picture(icon):
		var r := TextureRect.new()
		r.texture = Art.texture(icon)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(9, 9)
		h.add_child(r)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", {"good": Color8(44, 90, 30), "bad": Color8(150, 48, 36)}.get(tone, KitStyle.TEXT_DARK))
	h.add_child(l)
	pc.add_child(h)
	return pc


# --- stamps and keys -----------------------------------------------------------------

## A stamp at the foot of the detail: an icon, a word, and the key that
## does the same. Greyed when it can't be used.
func add_stamp(icon: String, t: String, key: String, enabled: bool, action: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 16)
	b.text = t + ("  [" + key + "]" if key != "" else "")
	b.add_theme_font_size_override("font_size", 7)
	if icon != "" and Art.has_picture(icon):
		b.icon = Art.texture(icon)
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 11)
	for st in ["normal", "hover", "pressed", "disabled"]:
		if Art.has_picture("ui_stamp_round"):
			b.add_theme_stylebox_override(st, sb("ui_stamp_round_" + st if Art.has_picture("ui_stamp_round_" + st) else "ui_stamp_round", 5, 2))
		else:
			var bx := KitStyle._box(Color8(246, 227, 196) if st != "hover" else Color8(252, 238, 212), Color8(165, 64, 44), 1, 3, 3)
			b.add_theme_stylebox_override(st, bx)
	b.add_theme_color_override("font_color", Color8(165, 64, 44))
	b.add_theme_color_override("font_hover_color", Color8(140, 44, 28))
	b.add_theme_color_override("font_disabled_color", Color(Color8(165, 64, 44), 0.4))
	b.disabled = not enabled
	b.pressed.connect(action)
	stamps.add_child(b)
	return b


## The key caps along the board's foot: [[["Q", "E"], "sheets"], ...].
func set_keys(pairs: Array) -> void:
	clear(_keys)
	for pr: Array in pairs:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 1)
		for k: Variant in pr[0]:
			h.add_child(key_cap(str(k)))
		var l := Label.new()
		l.text = " " + str(pr[1])
		l.add_theme_font_size_override("font_size", 6)
		l.add_theme_color_override("font_color", KitStyle.TEXT_LIGHT)
		l.add_theme_color_override("font_outline_color", KitStyle.INK)
		l.add_theme_constant_override("outline_size", 2)
		h.add_child(l)
		_keys.add_child(h)


## A keyboard key with its letter (Art Request 24's ui_key when drawn).
func key_cap(k: String) -> Control:
	var l := Label.new()
	l.text = k
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(maxf(9.0, 4.0 * k.length() + 5.0), 9)
	l.add_theme_font_size_override("font_size", 5)
	l.add_theme_color_override("font_color", KitStyle.INK)
	var art := pick(["ui_key_wide"] if k.length() > 1 else ["ui_key"])
	if art != "":
		l.add_theme_stylebox_override("normal", sb(art, 3, 0))
	else:
		var b := StyleBoxFlat.new()
		b.bg_color = Color8(243, 230, 204)
		b.border_color = KitStyle.INK
		b.set_border_width_all(1)
		b.border_width_bottom = 2
		b.set_corner_radius_all(2)
		l.add_theme_stylebox_override("normal", b)
	return l


# --- helpers ------------------------------------------------------------------------

func _pic(picture: String, at: Vector2, sz: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.texture(picture)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.position = at
	r.size = sz
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ignore_mouse(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in c.get_children():
		if k is Control:
			_ignore_mouse(k as Control)


func _gui_input(event: InputEvent) -> void:
	# A click outside the board closes the sheet.
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not FRAME.has_point((event as InputEventMouseButton).position):
			close()
