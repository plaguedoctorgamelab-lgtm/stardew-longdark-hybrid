class_name InventoryScreen
extends Panel
## The backpack page of the game menu (made over in 0.7.9), and the backpack
## beside a chest or the supply shelf.
##
## Top: the backpack's slots, the item bar's row numbered with its keys.
## Below a rule: the ranger standing in a little dusk-park window, the hat,
## coat and boots worn in slots beside them, and the park's name, wallet,
## everything ever earned and the date. With a chest or shelf open, its
## slots take that place instead.
## Beside the page: a trash can and a sort button, and Drop.
##
## Click a backpack slot to hold that item; with a chest open, click a slot to
## move its stack across. Drag a stack onto another slot to move it there (or
## swap), onto a clothes slot to wear it, onto the trash can to throw it away,
## or onto Drop to put it down. Point at anything for a card saying what it
## is and does.

signal want_tab(id: String)

const SLOT := 24
const GAP := 2
const COLS := 10  # the first row is the item bar
const PAD := 10
const PANEL_H := 96.0   # the ranger's half of the page

var session: GameSession
var other: Inventory = null
var title_label: Label
var other_label: Label
var hint: Label
var info: Label   # kept for older callers: the tooltip card now says it all
var _pack_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []
var drop_button: Button
var trash_button: Button
var sort_button: Button
var _numbers: Array[Label] = []
var _rule: TextureRect
var _ranger_panel: Control
var _portrait: RangerPortrait
var _wear_slots: Dictionary = {}   # slot -> Button
var _park_label: Label
var _wallet_label: Label
var _earned_label: Label
var _date_label: Label
var _warmth_label: Label
var _store_icon: TextureRect
var _tip: ItemTip


func setup(s: GameSession) -> void:
	session = s
	size = Vector2(PAD * 2 + COLS * SLOT + (COLS - 1) * GAP, 150)
	KitStyle.frame(self)
	_tip = ItemTip.new()
	_tip.setup(s)
	add_child(_tip)
	title_label = _label(Vector2(PAD, 2), s.content.text("ui_backpack"), 8)
	title_label.visible = false
	hint = _label(Vector2(PAD, 0), s.content.text("ui_close_hint"), 7)
	hint.modulate = Color(1, 1, 1, 0.6)
	info = _label(Vector2(-1000, -1000), "", 7)
	info.visible = false
	other_label = _label(Vector2(PAD + 15, 0), "", 8)
	_store_icon = KitStyle.tab_icon("chest")
	if _store_icon != null:
		add_child(_store_icon)
	for i in COLS:
		var n := _label(Vector2(PAD + i * (SLOT + GAP), 2), "1234567890"[i], 7)
		n.size = Vector2(SLOT, 8)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.modulate = Color(KitStyle.CORAL, 1.0) if i == 0 else Color(1, 1, 1, 0.55)
		_numbers.append(n)
	_pack_buttons = _grid(Vector2(PAD, 12), session.backpack.size(), true)
	_rule = TextureRect.new()
	_rule.texture = Art.texture("ui_rule") if Art.has_picture("ui_rule") else null
	_rule.stretch_mode = TextureRect.STRETCH_TILE
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_build_ranger_panel()
	_build_side()
	session.clothes_changed.connect(refresh)
	session.backpack.changed.connect(refresh)
	_layout()
	visible = false


func _label(pos: Vector2, text: String, fs: int = 8, parent: Control = null) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l


static func slot_style(kind: String) -> Dictionary:
	var pic: String = {"gold": "ui_tile_gold", "grey": "ui_tile_grey"}.get(kind, "ui_tile")
	var out := {}
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var mod := Color(1.12, 1.08, 0.95) if st == "hover" else Color.WHITE
		var sb: StyleBox = KitStyle._art(pic, 6, 2, false, mod)
		if sb == null:
			sb = KitStyle._box(KitStyle.WOOD_LIGHT if kind != "gold" else KitStyle.GOLD, KitStyle.WOOD_DARK, 1, 1)
		out[st] = sb
	return out


static func style_slot(b: Button, kind: String) -> void:
	var st := slot_style(kind)
	for k: String in st:
		b.add_theme_stylebox_override(k, st[k])


func _slot_button(pos: Vector2) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(SLOT, SLOT)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_constant_override("icon_max_width", SLOT - 6)
	# Stack counts sit over the icon's corner: light, with a dark edge.
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, KitStyle.TEXT_LIGHT)
	b.add_theme_color_override("font_outline_color", KitStyle.INK)
	b.add_theme_constant_override("outline_size", 3)
	style_slot(b, "")
	return b


func _grid(origin: Vector2, n: int, is_pack: bool) -> Array[Button]:
	var out: Array[Button] = []
	for i in n:
		var b := _slot_button(origin + Vector2((i % COLS) * (SLOT + GAP), (i / COLS) * (SLOT + GAP)))
		b.pressed.connect(_on_slot.bind(i, is_pack))
		b.mouse_entered.connect(_on_hover.bind(i, is_pack))
		b.mouse_exited.connect(_tip.hide_tip)
		b.set_drag_forwarding(_drag_from.bind(i, is_pack, b), _can_drop, _drop_on.bind(i, is_pack))
		add_child(b)
		out.append(b)
	return out


# --- the ranger's half -----------------------------------------------------------

func _build_ranger_panel() -> void:
	_ranger_panel = Control.new()
	_ranger_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ranger_panel)
	# The clothes: three slots down the left, each showing its piece.
	var y := 2.0
	for slot: String in Wardrobe.SLOTS:
		var b := _slot_button(Vector2(0, y))
		b.tooltip_text = ""
		b.pressed.connect(func() -> void: want_tab.emit("ranger"))
		b.mouse_entered.connect(func() -> void: _tip.show_item(str(session.wardrobe.worn.get(slot, "")), 1, session.content.text("ui_ranger_slot_" + slot)))
		b.mouse_exited.connect(func() -> void: _tip.hide_tip())
		b.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_wear.bind(slot), _wear_drop)
		_ranger_panel.add_child(b)
		_wear_slots[slot] = b
		y += SLOT + 6
	# The ranger in a window on the park at dusk, their title under it.
	_portrait = RangerPortrait.new()
	_portrait.position = Vector2(SLOT + 6, 2)
	_portrait.size = Vector2(60, 76)
	_ranger_panel.add_child(_portrait)
	var name_l := _label(Vector2(SLOT + 6, 80), session.content.text("ui_pack_ranger"), 8, _ranger_panel)
	name_l.size = Vector2(60, 10)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The park, the wallet, the earnings, the date.
	var x := SLOT + 6 + 60 + 10.0
	_park_label = _label(Vector2(x, 4), "", 10, _ranger_panel)
	var ix := 14.0 if _coin() != null else 0.0
	_wallet_label = _label(Vector2(x + ix, 24), "", 8, _ranger_panel)
	var coin := TextureRect.new()
	coin.texture = _coin()
	coin.position = Vector2(x, 25)
	coin.size = Vector2(10, 10)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ranger_panel.add_child(coin)
	_earned_label = _label(Vector2(x + ix, 38), "", 8, _ranger_panel)
	_warmth_label = _label(Vector2(x + ix, 52), "", 8, _ranger_panel)
	_date_label = _label(Vector2(x, 72), "", 8, _ranger_panel)
	_date_label.modulate = Color(1, 1, 1, 0.8)


func _coin() -> Texture2D:
	for pic: String in ["ui_coin", "item_gold_coin", "item_coin"]:
		if Art.has_picture(pic):
			return Art.texture(pic)
	return null


func _can_wear(_at: Vector2, d: Variant, slot: String) -> bool:
	if not (d is Dictionary and (d as Dictionary).has("inv")):
		return false
	var item := (d["inv"] as Inventory).item_at(int(d["i"]))
	return session.wardrobe.is_clothing(item) and str(session.wardrobe.row(item)["slot"]) == slot


func _wear_drop(_at: Vector2, d: Variant) -> void:
	session.put_on((d["inv"] as Inventory).item_at(int(d["i"])))
	refresh()


# --- beside the page: trash, sort, drop -----------------------------------------------

func _build_side() -> void:
	trash_button = _slot_button(Vector2.ZERO)
	trash_button.size = Vector2(SLOT + 4, SLOT + 8)
	trash_button.icon = Art.texture("item_trash_can") if Art.has_picture("item_trash_can") else null
	trash_button.add_theme_constant_override("icon_max_width", SLOT)
	trash_button.tooltip_text = session.content.text("ui_trash_hint")
	trash_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.trash_slot(d["inv"], d["i"])
		refresh())
	sort_button = _slot_button(Vector2.ZERO)
	sort_button.icon = Art.texture("ui_sort") if Art.has_picture("ui_sort") else null
	sort_button.text = "" if sort_button.icon != null else "⇅"
	sort_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	sort_button.add_theme_color_override("font_color", KitStyle.TEXT_DARK)
	sort_button.add_theme_color_override("font_hover_color", KitStyle.TEXT_DARK)
	sort_button.add_theme_constant_override("outline_size", 0)
	sort_button.add_theme_font_size_override("font_size", 12)
	sort_button.tooltip_text = session.content.text("ui_sort_hint")
	sort_button.pressed.connect(func() -> void:
		session.backpack.sort_from(COLS)
		refresh())
	drop_button = Button.new()
	drop_button.text = session.content.text("ui_drop")
	drop_button.focus_mode = Control.FOCUS_NONE
	drop_button.add_theme_font_size_override("font_size", 8)
	drop_button.size = Vector2(SLOT + 4, 14)
	drop_button.tooltip_text = session.content.text("ui_drop_hint")
	drop_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.drop_slot(d["inv"], d["i"])
		refresh())
	for b: Control in [trash_button, sort_button, drop_button]:
		add_child(b)


# --- dragging ---------------------------------------------------------------------

func _inv(is_pack: bool) -> Inventory:
	return session.backpack if is_pack else other


func _drag_from(_at: Vector2, i: int, is_pack: bool, b: Button) -> Variant:
	var inv := _inv(is_pack)
	if inv == null or inv.slot(i).is_empty():
		return null
	_tip.hide_tip()
	var pic := TextureRect.new()
	pic.texture = b.icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.size = Vector2(SLOT, SLOT)
	pic.modulate.a = 0.85
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


# --- opening and laying out ----------------------------------------------------------

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
	if other != null:
		_other_buttons = _grid(Vector2(PAD, _rows_bottom() + 18), other.size(), false)
		other.changed.connect(refresh)
	_layout()
	visible = true
	refresh()


func close() -> void:
	visible = false
	if _tip != null:
		_tip.hide_tip()
	if other != null and other.changed.is_connected(refresh):
		other.changed.disconnect(refresh)
	other = null
	if session != null:
		session.tidy_piles()


## Remakes the backpack's buttons when it grows (the pack frame).
func rebuild_slots() -> void:
	for b in _pack_buttons:
		b.queue_free()
	_pack_buttons = _grid(Vector2(PAD, 12), session.backpack.size(), true)
	_layout()
	refresh()


func _rows(n: int) -> int:
	return ceili(float(n) / COLS)


func _rows_bottom() -> float:
	return 12 + _rows(session.backpack.size()) * (SLOT + GAP) - GAP


## Sizes the page to the backpack's rows and either the ranger's half or the
## open chest's slots.
func _layout() -> void:
	var y := _rows_bottom() + 4
	_rule.position = Vector2(PAD - 4, y)
	_rule.size = Vector2(size.x - (PAD - 4) * 2, 2)
	y += 6
	_ranger_panel.visible = other == null
	other_label.visible = other != null
	if _store_icon != null:
		_store_icon.visible = other != null
		_store_icon.position = Vector2(PAD, y)
	if other == null:
		_ranger_panel.position = Vector2(PAD, y)
		y += PANEL_H
	else:
		other_label.position = Vector2(PAD + 17, y - 1)
		y += 14 + _rows(other.size()) * (SLOT + GAP)
	hint.position = Vector2(PAD, y - 1)
	size.y = y + 13
	position = ((Vector2(480, 270) - size) / 2.0).round() + Vector2(-12, 6)
	# Beside the page, on the right: sort, then the trash can and Drop.
	var sx := size.x + 10
	sort_button.position = Vector2(sx + 2, 10)
	trash_button.position = Vector2(sx, size.y - SLOT - 30)
	drop_button.position = Vector2(sx, size.y - 18)


func refresh() -> void:
	if session == null:
		return
	_fill(_pack_buttons, session.backpack, true)
	if other != null:
		_fill(_other_buttons, other, false)
	var w := session.wardrobe
	for slot: String in _wear_slots:
		var b: Button = _wear_slots[slot]
		var id := str(w.worn.get(slot, ""))
		b.icon = Art.texture(str(session.content.row("items", id)["icon"])) if id != "" and session.content.has("items", id) else null
	_portrait.queue_redraw()
	_park_label.text = session.content.text("ui_pack_park")
	_wallet_label.text = session.content.text("ui_pack_wallet", {"gold": _thousands(session.park.money.wallet)})
	_earned_label.text = session.content.text("ui_pack_earned", {"gold": _thousands(session.park.money.earned)})
	_warmth_label.text = session.content.text("ui_pack_warmth", {"warmth": int(w.warmth())})
	var c := session.clock
	_date_label.text = session.content.text("ui_pack_date", {"weekday": session.content.text("day_" + c.weekday_key()), "day": c.day, "season": session.content.text("season_" + c.season_name()), "year": c.year})
	info.text = wearing_text()


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


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
		style_slot(b, "gold" if is_pack and i == session.selected_slot else "")


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


## What the ranger is wearing, in a line.
func wearing_text() -> String:
	var w := session.wardrobe
	var n := func(slot: String) -> String: return session.content.item_name(str(w.worn.get(slot, "")))
	return session.content.text("clothing_line", {"hat": n.call("hat"), "coat": n.call("coat"), "boots": n.call("boots"), "warmth": int(w.warmth())})


func _on_hover(i: int, is_pack: bool) -> void:
	var inv := _inv(is_pack)
	if inv == null:
		return
	var s := inv.slot(i)
	if s.is_empty():
		_tip.hide_tip()
	else:
		_tip.show_item(str(s["item"]), int(s["count"]))
