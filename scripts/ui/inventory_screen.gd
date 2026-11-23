class_name InventoryScreen
extends Control
## The pack page of the game menu: the gear wall at the trailhead (0.7.9).
##
## On a wall of boards, left to right:
## - The ranger's park ID card: their photo at dusk with the park's patch
##   stamped on its corner, the park's name, the funds, everything earned
##   so far, and the date.
## - The pack, opened: the hip belt's ten pockets (the item bar, numbered
##   with its keys) over the main compartment's stitched canvas. Under it, a
##   Repack strap (tidies the compartment), Drop, and the Leave No Trace bin.
## - The gear wall: the hat on its peg, the coat on its hanger, the boots on
##   the mat, and spare clothes on the pegs below. Drag clothes onto the
##   hat, coat or boots to wear them, or onto the spare pegs to hang them
##   up out of the pack. Click a spare piece to put it on.
## With a chest or the shelf open, its slots sit under the pack.
##
## Click a pocket to hold that item; with a chest open, click to move a
## stack across. Drag a stack onto another slot to move or swap it. Point at
## anything for its tag.

signal want_tab(id: String)

const SLOT := 22
const GAP := 2
const COLS := 10  # the first row is the item bar: the hip belt
const ID_RECT := Rect2(8, 10, 90, 132)
const PACK_X := 110.0
const PACK_W := 16.0 + COLS * SLOT + (COLS - 1) * GAP
const WALL_X := PACK_X + PACK_W + 8.0
const WALL_W := 82.0
const BELT_Y := 10.0
const BELT_H := 36.0
const MAIN_Y := 52.0

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
var _portrait: RangerPortrait
var _id_lines: Array[Label] = []
var _wear: Dictionary = {}   # slot -> Button
var _wear_names: Dictionary = {}   # slot -> Label
var _spare_drop: Control
var _spare_buttons: Array[Button] = []
var _store_icon: TextureRect
var _main_bottom: float = 0.0
var _other_top: float = 0.0
var _tip: ItemTip


func setup(s: GameSession) -> void:
	session = s
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(WALL_X + WALL_W + 8, 160)
	KitStyle.frame(self)
	_tip = ItemTip.new()
	_tip.setup(s)
	add_child(_tip)
	hint = _label(Vector2(8, 0), s.content.text("ui_pack_hint"), 7, KitStyle.TEXT_LIGHT)
	info = _label(Vector2(-1000, -1000), "", 7)
	info.visible = false
	other_label = _label(Vector2.ZERO, "", 8, KitStyle.TEXT_LIGHT)
	_store_icon = KitStyle.tab_icon("chest")
	if _store_icon != null:
		add_child(_store_icon)
	_build_id_card()
	for i in COLS:
		var n := _label(Vector2(PACK_X + 8 + i * (SLOT + GAP), BELT_Y + 1), "1234567890"[i], 7, KitStyle.CREAM)
		n.size = Vector2(SLOT, 8)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_numbers.append(n)
	_pack_buttons = _make_pack_slots()
	_build_pack_bar()
	_build_gear_wall()
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
	b.mouse_exited.connect(_tip.hide_tip)
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
		var b := _slot_button(Vector2(PACK_X + 8 + (i % COLS) * (SLOT + GAP), _other_top + 6 + (i / COLS) * (SLOT + GAP)))
		_wire(b, i, false)
		out.append(b)
	return out


# --- the ID card ---------------------------------------------------------------------

func _build_id_card() -> void:
	var o := ID_RECT.position
	_portrait = RangerPortrait.new()
	_portrait.position = o + Vector2(15, 17)
	_portrait.size = Vector2(60, 64)
	add_child(_portrait)
	var seal := TextureRect.new()
	seal.texture = Art.texture("title_emblem") if Art.has_picture("title_emblem") else null
	seal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	seal.position = o + Vector2(62, 66)
	seal.size = Vector2(20, 22)
	seal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	seal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(seal)
	for k in 4:
		var l := _label(o + Vector2(6, 84 + k * 11), "", 7 if k != 0 else 8)
		l.size = Vector2(ID_RECT.size.x - 12, 10)
		_id_lines.append(l)


# --- the pack's bottom bar --------------------------------------------------------------

func _build_pack_bar() -> void:
	sort_button = Button.new()
	sort_button.text = session.content.text("ui_repack")
	sort_button.tooltip_text = session.content.text("ui_sort_hint")
	sort_button.pressed.connect(func() -> void:
		session.backpack.sort_from(COLS)
		refresh())
	drop_button = Button.new()
	drop_button.text = session.content.text("ui_drop")
	drop_button.tooltip_text = session.content.text("ui_drop_hint")
	drop_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.drop_slot(d["inv"], d["i"])
		refresh())
	trash_button = Button.new()
	trash_button.text = session.content.text("ui_bin")
	trash_button.icon = Art.texture("ui_gear_bin") if Art.has_picture("ui_gear_bin") else (Art.texture("item_trash_can") if Art.has_picture("item_trash_can") else null)
	trash_button.expand_icon = true
	trash_button.add_theme_constant_override("icon_max_width", 12)
	trash_button.tooltip_text = session.content.text("ui_trash_hint")
	trash_button.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_drop, func(_at: Vector2, d: Variant) -> void:
		session.trash_slot(d["inv"], d["i"])
		refresh())
	for b: Button in [sort_button, drop_button, trash_button]:
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 7)
		for st in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = BELT if st != "hover" else BELT.lightened(0.12)
			sb.border_color = BELT_DARK
			sb.set_border_width_all(1)
			sb.set_corner_radius_all(2)
			sb.set_content_margin_all(1)
			b.add_theme_stylebox_override(st, sb)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(k, KitStyle.CREAM)
		add_child(b)


# --- the gear wall ----------------------------------------------------------------------

func _build_gear_wall() -> void:
	var y := 14.0
	for slot: String in Wardrobe.SLOTS:
		var b := _slot_button(Vector2(WALL_X + 2, y + 6), "peg")
		b.size = Vector2(26, 26)
		b.add_theme_constant_override("icon_max_width", 24)
		b.mouse_entered.connect(func() -> void: _tip.show_item(str(session.wardrobe.worn.get(slot, "")), 1, session.content.text("ui_ranger_slot_" + slot)))
		b.mouse_exited.connect(func() -> void: _tip.hide_tip())
		b.set_drag_forwarding(func(_at: Vector2) -> Variant: return null, _can_wear.bind(slot), _wear_drop)
		_wear[slot] = b
		var name_l := _label(Vector2(WALL_X + 30, y + 8), "", 7, KitStyle.TEXT_LIGHT)
		name_l.size = Vector2(WALL_W - 32, 20)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_wear_names[slot] = name_l
		y += 30.0
	_label(Vector2(WALL_X + 2, y + 2), session.content.text("ui_gear_spare"), 7, KitStyle.TEXT_LIGHT)
	_spare_drop = Control.new()
	_spare_drop.position = Vector2(WALL_X, y + 12)
	_spare_drop.size = Vector2(WALL_W, 40)
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
		if k >= 6:
			break
		var b := _slot_button(_spare_drop.position + Vector2(4 + (k % 3) * 26, 2 + (k / 3) * 22), "peg")
		b.icon = _icon(id)
		b.pressed.connect(func() -> void: session.put_on(id))
		b.mouse_entered.connect(func() -> void: _tip.show_item(id, 1, session.content.text("ui_gear_spare_tag")))
		b.mouse_exited.connect(func() -> void: _tip.hide_tip())
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
	_layout()
	if other != null:
		_other_buttons = _make_other_slots()
		other.changed.connect(refresh)
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
	_main_bottom = MAIN_Y + 10 + _main_rows() * (SLOT + GAP) + 2
	# Repack, Drop and the bin on a strap under the compartment.
	var by := _main_bottom + 4
	sort_button.position = Vector2(PACK_X + 8, by)
	sort_button.size = Vector2(60, 13)
	trash_button.position = Vector2(PACK_X + PACK_W - 8 - 60, by)
	trash_button.size = Vector2(60, 13)
	drop_button.position = Vector2(trash_button.position.x - 50, by)
	drop_button.size = Vector2(46, 13)
	var bottom := maxf(by + 15, ID_RECT.end.y)
	bottom = maxf(bottom, _spare_drop.position.y + _spare_drop.size.y)
	other_label.visible = other != null
	if _store_icon != null:
		_store_icon.visible = other != null
	if other != null:
		_other_top = bottom + 14
		other_label.position = Vector2(ID_RECT.position.x + 16, _other_top + 4)
		if _store_icon != null:
			_store_icon.position = Vector2(ID_RECT.position.x, _other_top + 4)
		bottom = _other_top + 6 + ceili(float(other.size()) / COLS) * (SLOT + GAP) + 4
	hint.position = Vector2(8, bottom + 1)
	size.y = bottom + 12
	position = ((Vector2(480, 270) - size) / 2.0).round() + Vector2(0, 8)
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
	_portrait.queue_redraw()
	var c := session.clock
	_id_lines[0].text = session.content.text("ui_pack_park")
	_id_lines[1].text = session.content.text("ui_pack_wallet", {"gold": _thousands(session.park.money.wallet)})
	_id_lines[2].text = session.content.text("ui_pack_earned", {"gold": _thousands(session.park.money.earned)})
	_id_lines[3].text = session.content.text("ui_pack_date", {"day": c.day, "season": session.content.text("season_" + c.season_name()), "year": c.year})
	info.text = wearing_text()
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
		_tip.hide_tip()
	else:
		_tip.show_item(str(s["item"]), int(s["count"]))


# --- drawing: the boards, the ID card, the pack, the pegs -------------------------------------

## Mark's picture by name, or null (Art Request 22).
func _pic(name: String) -> Texture2D:
	return Art.texture(name) if Art.has_picture(name) else null


func _draw() -> void:
	var boards := _pic("ui_wall_boards")
	if boards != null:
		draw_texture_rect(boards, Rect2(Vector2.ZERO, size), true)
	# The wall without Mark's boards: upright boards with dark seams.
	var x := 0.0 if boards == null else size.x
	var k := 0
	while x < size.x:
		var w := minf(18.0, size.x - x)
		draw_rect(Rect2(x, 0, w, size.y), BOARD[k % 3])
		draw_rect(Rect2(x + w - 1, 0, 1, size.y), KitStyle.WOOD_DARK)
		draw_rect(Rect2(x + 8, 4, 1, 1), KitStyle.WOOD_DARK)
		x += w
		k += 1
	if session == null:
		return
	_draw_id_card()
	_draw_pack()
	_draw_gear_wall()
	if other != null:
		var r := Rect2(PACK_X, _other_top, PACK_W, size.y - 12 - _other_top)
		draw_rect(r, KitStyle.WOOD_DARK)
		draw_rect(r.grow(-2), Color8(110, 72, 46))


func _draw_id_card() -> void:
	var r := ID_RECT
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(KitStyle.INK, 0.4))
	draw_rect(r, CARD)
	draw_rect(r, KitStyle.WOOD_DARK, false, 1.0)
	# The green band across the top, with the card's title in it.
	draw_rect(Rect2(r.position, Vector2(r.size.x, 13)), PARK_GREEN)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, 10), session.content.text("ui_pack_id_title"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 8, KitStyle.CREAM)
	# A clip at the top, as if it hangs on the wall.
	var clip_pic := _pic("ui_gear_clip")
	if clip_pic != null:
		draw_texture_rect(clip_pic, Rect2(r.position.x + 6, r.position.y - 11, 8, 15), false)
	else:
		var clip := Rect2(r.get_center().x - 6, r.position.y - 4, 12, 6)
		draw_rect(clip, Color8(170, 170, 176))
		draw_rect(clip, KitStyle.INK, false, 1.0)


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
	var main := Rect2(PACK_X, MAIN_Y - 6, PACK_W, _main_bottom - MAIN_Y + 24)
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
	var y := 14.0
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
	for k in 3:
		var p := Vector2(WALL_X + 15 + k * 26, y + 13)
		if peg_pic != null:
			draw_texture_rect(peg_pic, Rect2(p - Vector2(3, 4), Vector2(6, 7)), false)
		else:
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), KitStyle.WOOD_DARK)
	if session.wardrobe.spare.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(WALL_X + 4, y + 34), session.content.text("ui_gear_spare_none"), HORIZONTAL_ALIGNMENT_LEFT, WALL_W - 6, 7, Color(KitStyle.CREAM, 0.85))
