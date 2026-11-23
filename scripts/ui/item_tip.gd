class_name ItemTip
extends PanelContainer
## The card that follows the pointer over a slot (0.7.9): the item's picture
## and name, what kind of thing it is, what it's for, what eating it or
## wearing it does, and what a shop would give for it.

var session: GameSession
var _pic: TextureRect
var _name: Label
var _kind: Label
var _body: Label


func setup(s: GameSession) -> void:
	session = s
	top_level = true
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", KitStyle.paper())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2(16, 16)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(_pic)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -2)
	head.add_child(names)
	_name = _label(names, 9, KitStyle.TEXT_DARK)
	_kind = _label(names, 7, Color(KitStyle.TEXT_DARK, 0.6))
	var rule := ColorRect.new()
	rule.color = Color(KitStyle.WOOD_MID, 0.6)
	rule.custom_minimum_size = Vector2(0, 1)
	v.add_child(rule)
	_body = _label(v, 7, KitStyle.TEXT_DARK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body.custom_minimum_size = Vector2(120, 0)
	visible = false


func _label(parent: Control, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## The lines of the card for an item, so tests can read them.
static func lines_for(s: GameSession, item: String) -> PackedStringArray:
	var out := PackedStringArray()
	var c := s.content
	for key: String in ["item_desc_" + item, "item_use_" + item]:
		if c.has("text", key):
			out.append(c.text(key))
	if c.has("foods", item):
		var fx: String = s.shops._effect_text(item)
		if fx != "":
			out.append(c.text("tip_when_eaten", {"what": fx}))
	if s.wardrobe.is_clothing(item):
		var slot := str(s.wardrobe.row(item)["slot"])
		out.append(c.text("tip_worn_as", {"slot": c.text("ui_ranger_slot_" + slot).to_lower()}))
	var row := c.row("items", item)
	if int(row.get("sell", 0)) > 0:
		out.append(c.text("tip_sells_for", {"gold": int(row["sell"])}))
	return out


static func kind_text(s: GameSession, item: String) -> String:
	var k := "kind_" + str(s.content.row("items", item).get("kind", ""))
	return s.content.text(k) if s.content.has("text", k) else ""


## Shows the card for an item ("" hides it). `heading` replaces the kind
## line, for a clothes slot ("Hat").
func show_item(item: String, count: int = 1, heading: String = "") -> void:
	if item == "" or not session.content.has("items", item):
		hide_tip()
		return
	var row := session.content.row("items", item)
	_pic.texture = Art.texture(str(row["icon"])) if Art.has_picture(str(row["icon"])) else null
	_name.text = session.content.item_name(item) + ("  ×%d" % count if count > 1 else "")
	_kind.text = heading if heading != "" else kind_text(session, item)
	_body.text = "\n".join(lines_for(session, item))
	_body.visible = _body.text != ""
	reset_size()
	visible = true
	_follow()


func hide_tip() -> void:
	visible = false


func _process(_delta: float) -> void:
	if visible:
		_follow()


## Sits below and right of the pointer, turned back to stay on screen.
func _follow() -> void:
	var m := get_global_mouse_position()
	var p := m + Vector2(10, 12)
	if p.x + size.x > 478:
		p.x = m.x - size.x - 6
	if p.y + size.y > 268:
		p.y = m.y - size.y - 6
	global_position = p.round()
