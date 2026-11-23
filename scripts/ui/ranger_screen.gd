class_name RangerScreen
extends Panel
## The Ranger page, on C (Mark's 0.7.7 playtest): the hat, coat and boots
## being worn, each with what it does, everything added up, and the spare
## clothes. Spare clothes are kept at the station, not in the backpack:
## click one to put it on, and what comes off joins them.

const ROW_H := 30.0
const ICON := 24.0

var session: GameSession
var _rows: Control
var _spares: Control
var _totals: Label


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(340, 240)
	position = (Vector2(480, 270) - size) / 2.0
	KitStyle.frame(self)
	_label(Vector2(8, 4), s.content.text("ui_ranger_title"))
	_label(Vector2(150, 4), s.content.text("ui_ranger_hint")).modulate = Color(1, 1, 1, 0.75)
	_rows = Control.new()
	_rows.position = Vector2(8, 20)
	add_child(_rows)
	_totals = _label(Vector2(8, 20 + ROW_H * 3 + 2), "")
	_totals.add_theme_font_size_override("font_size", 8)
	_label(Vector2(8, 130), s.content.text("ui_ranger_spare")).add_theme_font_size_override("font_size", 8)
	_spares = Control.new()
	_spares.position = Vector2(8, 144)
	add_child(_spares)
	session.clothes_changed.connect(refresh)
	visible = false


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func _icon(id: String) -> Texture2D:
	if not session.content.has("items", id):
		return null
	var pic := str(session.content.row("items", id).get("icon", ""))
	return Art.texture(pic) if pic != "" and Art.has_picture(pic) else null


## What a piece does, in words: the shop's line for it.
func buff_text(id: String) -> String:
	if session.content.has("text", "item_use_" + id):
		return session.content.text("item_use_" + id)
	var w := int(session.wardrobe.row(id).get("warmth", 0))
	return "+%d warmth outdoors" % w if w > 0 else ""


func refresh() -> void:
	if session == null or not visible:
		return
	for c in _rows.get_children():
		c.queue_free()
	for c in _spares.get_children():
		c.queue_free()
	var w := session.wardrobe
	var y := 0.0
	for slot: String in Wardrobe.SLOTS:
		var id := str(w.worn.get(slot, ""))
		var box := TextureRect.new()
		box.position = Vector2(0, y)
		box.size = Vector2(ICON, ICON)
		box.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.texture = _icon(id)
		_rows.add_child(box)
		var head := Label.new()
		head.position = Vector2(ICON + 6, y - 1)
		head.text = "%s:  %s" % [session.content.text("ui_ranger_slot_" + slot), session.content.item_name(id) if id != "" else "-"]
		_rows.add_child(head)
		var what := Label.new()
		what.position = Vector2(ICON + 6, y + 12)
		what.text = buff_text(id) if id != "" else ""
		what.add_theme_font_size_override("font_size", 8)
		what.modulate = Color(1, 1, 1, 0.8)
		_rows.add_child(what)
		y += ROW_H
	_totals.text = session.content.text("ui_ranger_totals", {"warmth": int(w.warmth()), "speed": roundi(w.speed_factor() * 100.0)})
	var spares := w.spares_by_slot()
	if spares.is_empty():
		var none := Label.new()
		none.text = session.content.text("ui_ranger_none")
		none.add_theme_font_size_override("font_size", 8)
		_spares.add_child(none)
		return
	var x := 0.0
	var sy := 0.0
	for id: String in spares:
		var b := Button.new()
		b.position = Vector2(x, sy)
		b.size = Vector2(104, 26)
		b.icon = _icon(id)
		b.expand_icon = true
		b.text = session.content.item_name(id)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 8)
		b.tooltip_text = "%s: %s\n%s" % [session.content.text("ui_ranger_wear"), session.content.item_name(id), buff_text(id)]
		b.pressed.connect(func() -> void: session.put_on(id))
		_spares.add_child(b)
		x += 108
		if x > 300:
			x = 0
			sy += 30
