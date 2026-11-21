class_name InventoryScreen
extends Panel
## The backpack screen, and the backpack beside a chest or the supply shelf.
## Click a backpack slot to hold that item; with a chest open, click a slot to
## move its stack across. Drag a stack onto another slot to move it there (or
## swap), onto Drop to put it down, or onto Trash to throw it away.

const SLOT := 20
const COLS := 10  # the first row is the item bar

var session: GameSession
var other: Inventory = null
var title_label: Label
var other_label: Label
var hint: Label
var info: Label
var _pack_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []
var drop_button: Button
var trash_button: Button


var _pack_icon: TextureRect
var _store_icon: TextureRect


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(300, 150)
	position = (Vector2(480, 270) - size) / 2.0
	KitStyle.frame(self)
	title_label = _label(Vector2(8, 4), s.content.text("ui_backpack"))
	other_label = _label(Vector2(8, 74), "")
	# The jobs clipboard's look: a small tab picture before each title.
	_pack_icon = KitStyle.tab_icon("backpack")
	if _pack_icon != null:
		_pack_icon.position = Vector2(8, 4)
		add_child(_pack_icon)
		title_label.position.x = 23
	_store_icon = KitStyle.tab_icon("chest")
	if _store_icon != null:
		add_child(_store_icon)
	info = _label(Vector2(8, 128), "")
	hint = _label(Vector2(190, 4), s.content.text("ui_close_hint"))
	_pack_buttons = _grid(Vector2(8, 18), session.backpack.size(), true)
	drop_button = _target("ui_drop", func(d: Dictionary) -> void: session.drop_slot(d["inv"], d["i"]))
	trash_button = _target("ui_trash", func(d: Dictionary) -> void: session.trash_slot(d["inv"], d["i"]))
	_layout()
	session.backpack.changed.connect(refresh)
	visible = false


func _label(pos: Vector2, text: String) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	add_child(l)
	return l


func _grid(origin: Vector2, n: int, is_pack: bool) -> Array[Button]:
	var out: Array[Button] = []
	for i in n:
		var b := Button.new()
		b.position = origin + Vector2((i % COLS) * (SLOT + 2), (i / COLS) * (SLOT + 2))
		b.size = Vector2(SLOT, SLOT)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_NONE
		# Stack counts sit over the icon: light, with a dark edge.
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, KitStyle.TEXT_LIGHT)
		b.add_theme_color_override("font_outline_color", KitStyle.INK)
		b.add_theme_constant_override("outline_size", 2)
		b.pressed.connect(_on_slot.bind(i, is_pack))
		b.mouse_entered.connect(_on_hover.bind(i, is_pack))
		b.set_drag_forwarding(_drag_from.bind(i, is_pack, b), _can_drop, _drop_on.bind(i, is_pack))
		add_child(b)
		out.append(b)
	return out


## A place to drag a stack onto: Drop or Trash.
func _target(text_id: String, act: Callable) -> Button:
	var b := Button.new()
	b.text = session.content.text(text_id)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.custom_minimum_size = Vector2(40, 12)
	b.size = Vector2(40, 12)
	b.tooltip_text = session.content.text("ui_drag_hint")
	b.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		act.call(d)
		refresh())
	add_child(b)
	return b


func _inv(is_pack: bool) -> Inventory:
	return session.backpack if is_pack else other


func _drag_from(_at: Vector2, i: int, is_pack: bool, b: Button) -> Variant:
	var inv := _inv(is_pack)
	if inv == null or inv.slot(i).is_empty():
		return null
	var pic := TextureRect.new()
	pic.texture = b.icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(SLOT, SLOT)
	pic.modulate.a = 0.8
	b.set_drag_preview(pic)
	return {"inv": inv, "i": i}


func _can_drop(_at: Vector2, d: Variant) -> bool:
	return d is Dictionary and (d as Dictionary).has("inv")


func _drop_on(_at: Vector2, d: Variant, j: int, is_pack: bool) -> void:
	var to := _inv(is_pack)
	if to == null:
		return
	var from: Inventory = d["inv"]
	from.move_to_slot(int(d["i"]), to, j)
	refresh()


func open(storage: Inventory, storage_title: String) -> void:
	for b in _other_buttons:
		b.queue_free()
	_other_buttons.clear()
	if other != null and other.changed.is_connected(refresh):
		other.changed.disconnect(refresh)
	other = storage
	other_label.text = storage_title
	if _store_icon != null:
		var kind := "shelf" if storage_title == session.content.text("ui_shelf") else "chest"
		_store_icon.texture = Art.texture("ui_tab_" + kind)
		_store_icon.visible = other != null
	if other != null:
		_other_buttons = _grid(Vector2(8, _other_top() + 14), other.size(), false)
		other.changed.connect(refresh)
	_layout()
	visible = true
	refresh()


func close() -> void:
	visible = false
	if other != null and other.changed.is_connected(refresh):
		other.changed.disconnect(refresh)
	other = null
	if session != null:
		session.tidy_piles()


## Remakes the backpack's buttons when it grows (the pack frame).
func rebuild_slots() -> void:
	for b in _pack_buttons:
		b.queue_free()
	_pack_buttons = _grid(Vector2(8, 18), session.backpack.size(), true)
	_layout()
	refresh()


func _rows(n: int) -> int:
	return ceili(float(n) / COLS)


## Where the chest's title goes: just under the backpack's rows.
func _other_top() -> float:
	return 18 + _rows(session.backpack.size()) * (SLOT + 2) + 4


## Sizes the screen to the backpack's rows and the open chest's, if any.
func _layout() -> void:
	var y := _other_top()
	if _store_icon != null:
		_store_icon.position = Vector2(8, y)
		_store_icon.visible = other != null
		other_label.position.x = 23
	other_label.position.y = y
	if other != null:
		y += 14 + _rows(other.size()) * (SLOT + 2)
	info.position.y = y + 2
	drop_button.position = Vector2(size.x - 92, y + 3)
	trash_button.position = Vector2(size.x - 48, y + 3)
	drop_button.size = Vector2(40, 12)
	trash_button.size = Vector2(40, 12)
	size.y = y + 18
	position = (Vector2(480, 270) - size) / 2.0


func refresh() -> void:
	_fill(_pack_buttons, session.backpack, true)
	if other != null:
		_fill(_other_buttons, other, false)


func _fill(buttons: Array[Button], inv: Inventory, is_pack: bool) -> void:
	for i in buttons.size():
		var s := inv.slot(i)
		var b := buttons[i]
		if s.is_empty():
			b.icon = null
			b.text = ""
		else:
			b.icon = Art.texture(session.content.row("items", s["item"])["icon"])
			b.text = str(s["count"]) if int(s["count"]) > 1 else ""
		b.modulate = Color(1.5, 1.3, 0.6) if is_pack and i == session.selected_slot else Color.WHITE


func _on_slot(i: int, is_pack: bool) -> void:
	if other == null:
		if is_pack:
			session.selected_slot = i
			refresh()
		return
	if is_pack:
		session.backpack.move_slot_to(i, other)
	else:
		var before := other.slot(i).duplicate()
		other.move_slot_to(i, session.backpack)
		if not before.is_empty() and other.slot(i).get("count", 0) == before["count"]:
			session.message.emit(session.content.text("msg_backpack_full"))
	refresh()


func _on_hover(i: int, is_pack: bool) -> void:
	var inv := session.backpack if is_pack else other
	if inv == null:
		return
	var s := inv.slot(i)
	info.text = "" if s.is_empty() else "%s x%d" % [session.content.item_name(s["item"]), s["count"]]
