class_name InventoryScreen
extends Control
## The Pack sheet (the cozy UI plan, 0.7.17): the backpack and the gear wall
## on the ranger's clipboard, at the clipboard's size like every page.
##
## On the paper, left to right:
## - The pack, opened: the hip belt's ten pockets (the item bar, numbered
##   with its keys) over the main compartment's stitched canvas.
## - The gear wall: the hat on its peg, the coat on its hanger, the boots on
##   the mat, and spare clothes on the pegs below. Drag clothes onto the
##   hat, coat or boots to wear them, or onto the spare pegs to hang them
##   up out of the pack. Click a spare piece to put it on.
##   With a chest, the shelf or the pantry open, its slots take the wall's
##   place.
## - Along the foot, the label strip: whatever is pointed at, at once (its
##   picture, name, kind and what it does). Nothing floats. With nothing
##   pointed at, it shows the wallet and the day.
## - Mark's stamps: Repack (tidies the compartment), Drop and the Leave No
##   Trace bin, which also take a dragged stack.
##
## Click a pocket to hold that item; with a chest open, click to move a
## stack across. Drag a stack onto another slot to move or swap it.

signal want_tab(id: String)

const SLOT := 22
const GAP := 2
const COLS := 10  # the first row is the item bar: the hip belt
const OTHER_COLS := 5
const PACK_X := 48.0
const PACK_W := 16.0 + COLS * SLOT + (COLS - 1) * GAP
const WALL_X := PACK_X + PACK_W + 10.0
const WALL_W := 124.0
const BELT_Y := 60.0
const BELT_H := 36.0
const MAIN_Y := 102.0
const STRIP := Rect2(46, 186, 390, 26)
const STAMP_Y := 216.0
const PAPER_TOP := 46.0
const GEAR_Y := 50.0

const CANVAS := Color8(178, 160, 104)
const CANVAS_DARK := Color8(128, 112, 68)
const BELT := Color8(86, 92, 56)
const BELT_DARK := Color8(58, 62, 38)
const BOARD := [Color8(157, 102, 62), Color8(146, 94, 57), Color8(165, 109, 67)]
const CARD := Color8(246, 236, 210)
const PARK_GREEN := Color8(40, 97, 67)

var session: GameSession
var other: Inventory = null
var other_label: Label
var hint: Label
var info: Label   # kept for older callers: the tags say it all now
var _pack_buttons: Array[Button] = []
var _other_buttons: Array[Button] = []
var drop_button: Button
var trash_button: Button
var sort_button: Button
var _numbers: Array[Label] = []
var _wear: Dictionary = {}   # slot -> Button
var _wear_names: Dictionary = {}   # slot -> Label
var _spare_drop: Control
var _spare_buttons: Array[Button] = []
var _store_icon: TextureRect
var _main_bottom: float = 0.0
var _other_top: float = 0.0
var _strip: Control
var _strip_pic: TextureRect
var _strip_name: Label
var _strip_kind: Label
var _strip_chips: HBoxContainer
var _strip_line: Label
var _strip_idle: bool = true
var _keys: HBoxContainer
var _warmth: Control
var _spare_label: Label


func setup(s: GameSession) -> void:
	session = s
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(480, 270)
	position = Vector2.ZERO
	hint = _label(Vector2(-1000, -1000), "", 7)
	hint.visible = false
	info = _label(Vector2(-1000, -1000), "", 7)
	info.visible = false
	other_label = _label(Vector2(WALL_X + 18, PAPER_TOP + 2), "", 8)
	_store_icon = KitStyle.tab_icon("chest")
	if _store_icon != null:
		add_child(_store_icon)
		_store_icon.position = Vector2(WALL_X, PAPER_TOP + 2)
	_build_strip()
	for i in COLS:
		var n := _label(Vector2(PACK_X + 8 + i * (SLOT + GAP), BELT_Y + 1), "1234567890"[i], 7, KitStyle.CREAM)
		n.size = Vector2(SLOT, 8)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_numbers.append(n)
	_pack_buttons = _make_pack_slots()
	_build_pack_bar()
	_build_gear_wall()
	_keys = HBoxContainer.new()
	_keys.position = Vector2(Sheet.FRAME.position.x + 30, Sheet.FRAME.end.y - 16)
	_keys.add_theme_constant_override("separation", 6)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_keys)
	Sheet.fill_keys(_keys, [[["Tab"], s.content.text("key_sheets")], [["E", "Esc"], s.content.text("key_close")], [["C"], s.content.text("key_use")], [[], s.content.text("key_drag")]])
	session.clothes_changed.connect(refresh)
	session.backpack.changed.connect(refresh)
	_layout()
	visible = false


func _label(pos: Vector2, text: String, fs: int = 8, col: Color = KitStyle.TEXT_DARK, parent: Control = null) -> Label:
	var l := Label.new()
	l.position = pos
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if col == KitStyle.TEXT_LIGHT or col == KitStyle.CREAM:
		l.add_theme_color_override("font_outline_color", KitStyle.INK)
		l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else self).add_child(l)
	return l


# --- slots -----------------------------------------------------------------------------

## A pocket's look: sunk into the canvas, or (gold) the one in hand.
static func pocket_style(kind: String) -> Dictionary:
	var out := {}
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		match kind:
			"held":
				sb.bg_color = Color8(236, 206, 120)
				sb.border_color = KitStyle.GOLD
			"belt":
				sb.bg_color = Color8(70, 76, 44) if st != "hover" else Color8(84, 90, 54)
				sb.border_color = BELT_DARK
			"peg":
				sb.bg_color = Color(0, 0, 0, 0) if st != "hover" else Color(1, 1, 1, 0.12)
				sb.border_color = Color(0, 0, 0, 0)
			_:
				sb.bg_color = Color8(150, 134, 84) if st != "hover" else Color8(164, 148, 96)
				sb.border_color = CANVAS_DARK
		sb.set_border_width_all(1)
		sb.border_width_top = 2 if kind != "peg" else 0
		sb.set_corner_radius_all(3)
		sb.set_content_margin_all(2)
		out[st] = sb
	return out


static func style_pocket(b: Button, kind: String) -> void:
	var st := pocket_style(kind)
	for k: String in st:
		b.add_theme_stylebox_override(k, st[k])


func _slot_button(pos: Vector2, kind: String = "") -> Button:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(SLOT, SLOT)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_constant_override("icon_max_width", SLOT - 4)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, KitStyle.TEXT_LIGHT)
	b.add_theme_color_override("font_outline_color", KitStyle.INK)
	b.add_theme_constant_override("outline_size", 3)
	style_pocket(b, kind)
	add_child(b)
	return b


func _slot_pos(i: int, first_y: float) -> Vector2:
	if i < COLS:
		return Vector2(PACK_X + 8 + i * (SLOT + GAP), BELT_Y + 10)
	var k := i - COLS
	return Vector2(PACK_X + 8 + (k % COLS) * (SLOT + GAP), first_y + (k / COLS) * (SLOT + GAP))


func _wire(b: Button, i: int, is_pack: bool) -> void:
	b.pressed.connect(_on_slot.bind(i, is_pack))
	b.mouse_entered.connect(_on_hover.bind(i, is_pack))
	b.mouse_exited.connect(_idle_strip)
	b.set_drag_forwarding(_drag_from.bind(i, is_pack, b), _can_drop, _drop_on.bind(i, is_pack))


func _make_pack_slots() -> Array[Button]:
	var out: Array[Button] = []
	for i in session.backpack.size():
		var b := _slot_button(_slot_pos(i, MAIN_Y + 10), "belt" if i < COLS else "")
		_wire(b, i, true)
		out.append(b)
	return out


func _make_other_slots() -> Array[Button]:
	var out: Array[Button] = []
	for i in other.size():
		var b := _slot_button(Vector2(WALL_X + 4 + (i % OTHER_COLS) * (SLOT + GAP), _other_top + (i / OTHER_COLS) * (SLOT + GAP)))
		_wire(b, i, false)
		out.append(b)
	return out


# --- the label strip (replaces the tag) ------------------------------------------------

func _build_strip() -> void:
	_strip = Panel.new()
	_strip.position = STRIP.position
	_strip.size = STRIP.size
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Art.has_picture("ui_label_strip"):
		# Mark's flowers sit near each end: keep the ends whole, stretch the middle.
		var st := Sheet.sb("ui_label_strip", 6, 0)
		st.texture_margin_left = 22
		st.texture_margin_right = 22
		_strip.add_theme_stylebox_override("panel", st)
	else:
		_strip.add_theme_stylebox_override("panel", KitStyle._box(Color8(251, 240, 214), Color8(201, 167, 122), 1, 3))
	add_child(_strip)
	_strip_pic = TextureRect.new()
	_strip_pic.position = Vector2(26, 3)
	_strip_pic.size = Vector2(20, 20)
	_strip_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_strip_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_strip_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_strip_pic)
	_strip_name = _label(Vector2(50, 1), "", 8, KitStyle.TEXT_DARK, _strip)
	_strip_kind = _label(Vector2(50, 13), "", 6, KitStyle.CORAL.darkened(0.2), _strip)
	_strip_chips = HBoxContainer.new()
	_strip_chips.add_theme_constant_override("separation", 3)
	_strip_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.add_child(_strip_chips)
	_strip_line = _label(Vector2(0, 0), "", 7, Color8(52, 60, 110), _strip)
	_strip_line.size = Vector2(150, 24)
	_strip_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_strip_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _clear_chips() -> void:
	for c in _strip_chips.get_children():
		_strip_chips.remove_child(c)
		c.queue_free()


## What an item is and does, as chips: energy and warmth when eaten, warmth
## when worn, what a shop gives for it.
static func item_chips(s: GameSession, item: String, with_sell: bool = true) -> Array[Control]:
	var c := s.content
	var out: Array[Control] = []
	if c.has("foods", item):
		var f := c.row("foods", item)
		if int(f.get("energy", 0)) > 0:
			out.append(Sheet.chip(Sheet.pick(["icon_energy"]), c.text("fx_energy", {"n": int(f["energy"])}), "good"))
		if int(f.get("warmth", 0)) > 0:
			out.append(Sheet.chip(Sheet.pick(["icon_warmth"]), c.text("fx_warmth", {"n": int(f["warmth"])}), "good"))
	if s.wardrobe.is_clothing(item):
		var wr := int(s.wardrobe.row(item).get("warmth", 0))
		if wr > 0:
			out.append(Sheet.chip(Sheet.pick(["icon_warmth"]), c.text("fx_warmth_worn", {"n": wr}), "good"))
	var row := c.row("items", item)
	if with_sell and int(row.get("sell", 0)) > 0:
		out.append(Sheet.chip(Sheet.pick(["icon_coin"]), c.text("fx_sells", {"gold": int(row["sell"])})))
	return out


## The strip, filled for an item ("" goes back to the wallet and the day).
## `heading` replaces the kind ("Hat").
func show_item(item: String, count: int = 1, heading: String = "") -> void:
	if item == "" or not session.content.has("items", item):
		_idle_strip()
		return
	_strip_idle = false
	var c := session.content
	var row := c.row("items", item)
	_strip_pic.texture = Art.texture(str(row["icon"])) if Art.has_picture(str(row["icon"])) else null
	_strip_name.text = c.item_name(item) + ("  ×%d" % count if count > 1 else "")
	_strip_kind.text = (heading if heading != "" else ItemTip.kind_text(session, item)).to_upper()
	_clear_chips()
	for ch in item_chips(session, item):
		_strip_chips.add_child(ch)
	var line := ""
	for key: String in ["item_desc_" + item, "item_use_" + item]:
		if c.has("text", key) and line == "":
			line = c.text(key)
	_strip_line.text = line
	_place_strip()


## The strip with nothing pointed at: the park's wallet and the day.
func _idle_strip() -> void:
	if session == null:
		return
	_strip_idle = true
	var c := session.content
	var ck := session.clock
	_strip_pic.texture = Art.texture("log_id_card") if Art.has_picture("log_id_card") else null
	_strip_name.text = c.text("ui_pack_park")
	_strip_kind.text = c.text("ui_pack_date", {"day": ck.day, "season": c.text("season_" + ck.season_name()), "year": ck.year}).to_upper()
	_clear_chips()
	_strip_chips.add_child(Sheet.chip(Sheet.pick(["icon_coin"]), c.text("ui_pack_wallet", {"gold": _thousands(session.park.money.wallet)})))
	_strip_chips.add_child(Sheet.chip(Sheet.pick(["icon_coins_up"]), c.text("ui_pack_earned", {"gold": _thousands(session.park.money.earned)})))
	_strip_line.text = c.text("ui_strip_point")
	_place_strip()


func _place_strip() -> void:
	var x := 52.0 + maxf(_strip_name.get_combined_minimum_size().x, _strip_kind.get_combined_minimum_size().x) + 8.0
	_strip_chips.position = Vector2(x, 6)
	var cw := _strip_chips.get_combined_minimum_size().x
	_strip_line.position = Vector2(x + cw + 8, 1)
	_strip_line.size = Vector2(maxf(60.0, STRIP.size.x - x - cw - 30), 24)


# --- the pack's bottom bar --------------------------------------------------------------

func _build_pack_bar() -> void:
	var c := session.content
	sort_button = Sheet.stamp_button(Sheet.pick(["icon_carry", "ui_gear_buckle"]), c.text("ui_repack"), "", true, func() -> void:
		session.backpack.sort_from(COLS)
		refresh())
	drop_button = Sheet.stamp_button(Sheet.pick(["verb_pick"]), c.text("ui_drop"), "", true, func() -> void: pass)
	drop_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.drop_slot(d["inv"], d["i"])
		refresh())
	trash_button = Sheet.stamp_button(Sheet.pick(["ui_gear_bin", "item_trash_can"]), c.text("ui_bin"), "", true, func() -> void: pass)
	trash_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.trash_slot(d["inv"], d["i"])
		refresh())
	for b: Button in [sort_button, drop_button, trash_button]:
		add_child(b)


# --- the gear wall ----------------------------------------------------------------------

func _build_gear_wall() -> void:
	var y := GEAR_Y
	for slot: String in Wardrobe.SLOTS:
		var b := _slot_button(Vector2(WALL_X + 2, y + 6), "peg")
		b.size = Vector2(26, 26)
		b.add_theme_constant_override("icon_max_width", 24)
		b.mouse_entered.connect(func() -> void: show_item(str(session.wardrobe.worn.get(slot, "")), 1, session.content.text("ui_ranger_slot_" + slot)))
		b.mouse_exited.connect(_idle_strip)
		b.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_wear.bind(slot), _wear_drop)
		_wear[slot] = b
		var name_l := _label(Vector2(WALL_X + 32, y + 8), "", 7)
		name_l.size = Vector2(WALL_W - 34, 20)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_wear_names[slot] = name_l
		y += 30.0
	_spare_label = _label(Vector2(WALL_X + 2, y + 2), session.content.text("ui_gear_spare"), 7)
	_warmth = Control.new()
	add_child(_warmth)
	_spare_drop = Control.new()
	_spare_drop.position = Vector2(WALL_X, y + 12)
	_spare_drop.size = Vector2(WALL_W, 26)
	_spare_drop.tooltip_text = session.content.text("ui_gear_spare_hint")
	_spare_drop.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_hang, _hang_drop)
	add_child(_spare_drop)


func _dragged_item(d: Variant) -> String:
	if not (d is Dictionary and (d as Dictionary).has("inv")):
		return ""
	return (d["inv"] as Inventory).item_at(int(d["i"]))


func _can_wear(_at: Vector2, d: Variant, slot: String) -> bool:
	var item := _dragged_item(d)
	return item != "" and session.wardrobe.is_clothing(item) and str(session.wardrobe.row(item)["slot"]) == slot


func _wear_drop(_at: Vector2, d: Variant) -> void:
	session.put_on(_dragged_item(d))
	refresh()


func _can_hang(_at: Vector2, d: Variant) -> bool:
	var item := _dragged_item(d)
	return item != "" and session.wardrobe.is_clothing(item)


func _hang_drop(_at: Vector2, d: Variant) -> void:
	session.hang_up(d["inv"], int(d["i"]))
	refresh()


func _refresh_spares() -> void:
	for b in _spare_buttons:
		b.queue_free()
	_spare_buttons.clear()
	var k := 0
	for id: String in session.wardrobe.spares_by_slot():
		if k >= 4:
			break
		var b := _slot_button(_spare_drop.position + Vector2(4 + (k % 4) * 26, 2 + (k / 4) * 22), "peg")
		b.icon = _icon(id)
		b.visible = other == null
		b.pressed.connect(func() -> void: session.put_on(id))
		b.mouse_entered.connect(func() -> void: show_item(id, 1, session.content.text("ui_gear_spare_tag")))
		b.mouse_exited.connect(_idle_strip)
		b.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_hang, _hang_drop)
		_spare_buttons.append(b)
		k += 1


func _icon(id: String) -> Texture2D:
	if id == "" or not session.content.has("items", id):
		return null
	var pic := str(session.content.row("items", id)["icon"])
	return Art.texture(pic) if Art.has_picture(pic) else null


# --- dragging ---------------------------------------------------------------------------

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
	_layout()
	if other != null:
		_other_buttons = _make_other_slots()
		other.changed.connect(refresh)
	visible = true
	refresh()


func close() -> void:
	visible = false
	if other != null and other.changed.is_connected(refresh):
		other.changed.disconnect(refresh)
	other = null
	if session != null:
		session.tidy_piles()


## Remakes the pack's pockets when it grows (the pack frame).
func rebuild_slots() -> void:
	for b in _pack_buttons:
		b.queue_free()
	_pack_buttons = _make_pack_slots()
	_layout()
	refresh()


func _main_rows() -> int:
	return maxi(1, ceili(float(session.backpack.size() - COLS) / COLS))


func _layout() -> void:
	_main_bottom = MAIN_Y + _main_rows() * (SLOT + GAP) + 2
	# Repack, Drop and the bin: Mark's stamps under the strip.
	sort_button.position = Vector2(PACK_X, STAMP_Y)
	drop_button.position = Vector2(PACK_X + 120, STAMP_Y)
	trash_button.position = Vector2(PACK_X + 180, STAMP_Y)
	var gear := other == null
	for slot: String in _wear:
		(_wear[slot] as Button).visible = gear
		(_wear_names[slot] as Label).visible = gear
	_spare_label.visible = gear
	_spare_drop.visible = gear
	for b in _spare_buttons:
		b.visible = gear
	other_label.visible = not gear
	if _store_icon != null:
		_store_icon.visible = not gear
	_other_top = PAPER_TOP + 16
	size = Vector2(480, 270)
	position = Vector2.ZERO
	queue_redraw()


func refresh() -> void:
	if session == null:
		return
	_fill(_pack_buttons, session.backpack, true)
	if other != null:
		_fill(_other_buttons, other, false)
	var w := session.wardrobe
	for slot: String in _wear:
		var id := str(w.worn.get(slot, ""))
		(_wear[slot] as Button).icon = _icon(id)
		(_wear_names[slot] as Label).text = session.content.item_name(id) if id != "" else "-"
	_refresh_spares()
	for ch in _warmth.get_children():
		ch.queue_free()
	if other == null:
		var wc := Sheet.chip(Sheet.pick(["icon_warmth"]), session.content.text("fx_warmth", {"n": int(w.warmth())}), "good")
		wc.position = Vector2(WALL_X + 58, GEAR_Y + 89)
		_warmth.add_child(wc)
	info.text = wearing_text()
	if _strip_idle:
		_idle_strip()
	queue_redraw()


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
			b.icon = _icon(str(s["item"]))
			b.text = str(s["count"]) if int(s["count"]) > 1 else ""
		var kind := "belt" if is_pack and i < COLS else ""
		if is_pack and i == session.selected_slot:
			kind = "held"
		style_pocket(b, kind)


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
		_idle_strip()
	else:
		show_item(str(s["item"]), int(s["count"]))


# --- drawing: the boards, the ID card, the pack, the pegs -------------------------------------

## Mark's picture by name, or null (Art Request 22).
func _pic(name: String) -> Texture2D:
	return Art.texture(name) if Art.has_picture(name) else null


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var board := _pic("ui_clipboard")
	if board != null:
		draw_texture_rect(board, Sheet.FRAME, false)
	else:
		draw_rect(Sheet.FRAME, KitStyle.WOOD)
		draw_rect(Sheet.PAPER, KitStyle.PAPER)
	var clip := _pic("clip_chest" if other != null else "clip_pack")
	if clip != null:
		draw_texture_rect(clip, Rect2(Sheet.CLIP_AT - Vector2(14, -1), Vector2(28, 28)), false)
	if session == null:
		return
	_draw_pack()
	if other == null:
		_draw_gear_wall()
	else:
		var r := Rect2(WALL_X, _other_top - 4, WALL_W, ceili(float(other.size()) / OTHER_COLS) * (SLOT + GAP) + 6)
		draw_rect(r, Color8(110, 72, 46))
		draw_rect(r.grow(-2), Color8(130, 88, 56))
	# The rule between the pack and the wall, as on the jobs sheet.
	draw_rect(Rect2(WALL_X - 5, PAPER_TOP + 14, 1, STRIP.position.y - PAPER_TOP - 20), Color(KitStyle.WOOD, 0.35))


func _stitch_rect(r: Rect2, col: Color) -> void:
	var i := 0.0
	while i < r.size.x:
		draw_rect(Rect2(r.position.x + i, r.position.y, 3, 1), col)
		draw_rect(Rect2(r.position.x + i, r.end.y - 1, 3, 1), col)
		i += 6.0
	i = 0.0
	while i < r.size.y:
		draw_rect(Rect2(r.position.x, r.position.y + i, 1, 3), col)
		draw_rect(Rect2(r.end.x - 1, r.position.y + i, 1, 3), col)
		i += 6.0


func _draw_pack() -> void:
	# The main compartment: canvas with a stitched seam.
	var main := Rect2(PACK_X, MAIN_Y - 6, PACK_W, _main_bottom - MAIN_Y + 10)
	draw_rect(Rect2(main.position + Vector2(1, 2), main.size), Color(KitStyle.INK, 0.4))
	var canvas := _pic("ui_pack_canvas")
	if canvas != null:
		draw_texture_rect(canvas, main, true)
	else:
		draw_rect(main, CANVAS)
	draw_rect(main, CANVAS_DARK, false, 1.0)
	_stitch_rect(main.grow(-3), CANVAS_DARK)
	# The hip belt: webbing over the top, with a buckle at each end.
	var belt := Rect2(PACK_X - 4, BELT_Y, PACK_W + 8, BELT_H)
	draw_rect(Rect2(belt.position + Vector2(1, 2), belt.size), Color(KitStyle.INK, 0.4))
	var webbing := _pic("ui_belt_webbing")
	if webbing != null:
		draw_texture_rect(webbing, belt, true)
	else:
		draw_rect(belt, BELT)
	draw_rect(belt, BELT_DARK, false, 1.0)
	_stitch_rect(belt.grow(-2), Color8(140, 146, 96))
	var buckle := _pic("ui_gear_buckle")
	for bx: float in [belt.position.x - 3, belt.end.x - 5]:
		if buckle != null:
			draw_texture_rect(buckle, Rect2(bx - 3, belt.position.y + 14, 14, 9), false)
		else:
			draw_rect(Rect2(bx, belt.position.y + 12, 8, 12), Color8(190, 190, 196))
			draw_rect(Rect2(bx, belt.position.y + 12, 8, 12), KitStyle.INK, false, 1.0)


func _draw_gear_wall() -> void:
	var y := GEAR_Y
	var wire := Color8(190, 190, 196)
	var peg_pic := _pic("ui_gear_peg")
	var hanger := _pic("ui_gear_hanger")
	var mat := _pic("ui_gear_mat")
	for slot: String in Wardrobe.SLOTS:
		var peg := Vector2(WALL_X + 15, y + 2)
		if slot == "boots" and mat != null:
			draw_texture_rect(mat, Rect2(WALL_X + 1, y + 22, 28, 12), false)
			y += 30.0
			continue
		if peg_pic != null:
			draw_texture_rect(peg_pic, Rect2(peg - Vector2(4, 5), Vector2(8, 9)), false)
		else:
			draw_rect(Rect2(peg - Vector2(2, 2), Vector2(5, 5)), KitStyle.WOOD_DARK)
			draw_rect(Rect2(peg - Vector2(1, 1), Vector2(3, 3)), KitStyle.WOOD_LIGHT)
		if slot == "coat" and hanger != null:
			draw_texture_rect(hanger, Rect2(peg + Vector2(-12, 1), Vector2(24, 12)), false)
		elif slot == "coat":
			# A wire hanger: the hook and the shoulders.
			draw_line(peg + Vector2(0, 2), peg + Vector2(0, 5), wire)
			draw_line(peg + Vector2(0, 5), peg + Vector2(-10, 9), wire)
			draw_line(peg + Vector2(0, 5), peg + Vector2(10, 9), wire)
		elif slot == "boots":
			# A mat under the boots.
			draw_rect(Rect2(WALL_X + 1, y + 30, 28, 3), Color8(120, 60, 50))
			draw_rect(Rect2(WALL_X + 1, y + 30, 28, 1), Color8(160, 90, 70))
		y += 30.0
	draw_line(Vector2(WALL_X + 2, y), Vector2(WALL_X + WALL_W - 2, y), Color(KitStyle.INK, 0.4))
	# A rail of spare pegs.
	for k in 4:
		var p := Vector2(WALL_X + 15 + k * 26, y + 13)
		if peg_pic != null:
			draw_texture_rect(peg_pic, Rect2(p - Vector2(3, 4), Vector2(6, 7)), false)
		else:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), KitStyle.WOOD_DARK)
	if session.wardrobe.spare.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(WALL_X + 4, y + 30), session.content.text("ui_gear_spare_none"), HORIZONTAL_ALIGNMENT_LEFT, WALL_W - 6, 6, Color(KitStyle.TEXT_DARK, 0.7))
