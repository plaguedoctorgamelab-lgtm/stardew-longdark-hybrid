class_name InventoryScreen
extends Panel
## The backpack screen, and the backpack beside a chest or the supply shelf.
## Click a backpack slot to hold that item; with a chest open, click a slot to
## move its stack across.

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


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(300, 150)
	position = (Vector2(480, 270) - size) / 2.0
	title_label = _label(Vector2(8, 4), s.content.text("ui_backpack"))
	other_label = _label(Vector2(8, 74), "")
	info = _label(Vector2(8, 128), "")
	hint = _label(Vector2(190, 4), s.content.text("ui_close_hint"))
	_pack_buttons = _grid(Vector2(8, 18), session.backpack.size(), true)
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
		b.pressed.connect(_on_slot.bind(i, is_pack))
		b.mouse_entered.connect(_on_hover.bind(i, is_pack))
		add_child(b)
		out.append(b)
	return out


func open(storage: Inventory, storage_title: String) -> void:
	for b in _other_buttons:
		b.queue_free()
	_other_buttons.clear()
	if other != null and other.changed.is_connected(refresh):
		other.changed.disconnect(refresh)
	other = storage
	other_label.text = storage_title
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
	other_label.position.y = y
	if other != null:
		y += 14 + _rows(other.size()) * (SLOT + 2)
	info.position.y = y + 2
	size.y = y + 22
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
